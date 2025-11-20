import json
from datetime import timedelta, datetime
from zoneinfo import ZoneInfo
from typing import Optional, Any
from io import BytesIO

from fastapi import FastAPI, Depends, HTTPException, status, Request
from fastapi.responses import HTMLResponse, RedirectResponse, Response, StreamingResponse
from fastapi.templating import Jinja2Templates
from fastapi.security import OAuth2PasswordRequestForm
from sqlalchemy.orm import Session, joinedload
from sqlalchemy.exc import IntegrityError

from weasyprint import HTML

from .db import models
from .db.session import SessionLocal, engine
from .db.base import Base
from . import schemas
from .core.security import (
    authenticate_user,
    create_access_token,
    get_password_hash,
    oauth2_scheme,
    check_role,
    get_current_user, # Necesario para validación manual en PDF
    ACCESS_TOKEN_EXPIRE_MINUTES,
)

# ==========================================
# CONFIGURACIÓN GLOBAL
# ==========================================
COLOMBIA_TZ = ZoneInfo("America/Bogota")

app = FastAPI(
    title="API para Sistema de Historias Clínicas Electrónicas",
    description="Middleware para la gestión de HCE con FastAPI y Citus",
    version="1.0.0",
)

@app.on_event("startup")
async def startup_event():
    """Intenta crear tablas si no existen."""
    try:
        Base.metadata.create_all(bind=engine)
    except Exception as e:
        print(f"[ADVERTENCIA] No se pudieron crear tablas en startup: {e}")

templates = Jinja2Templates(directory="backend/templates", autoescape=True)

# ==========================================
# UTILIDADES
# ==========================================
def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

def calcular_edad_real(fecha_nacimiento):
    """Calcula la edad precisa basada en la fecha actual de Colombia."""
    if not fecha_nacimiento:
        return None
    hoy = datetime.now(COLOMBIA_TZ).date()
    return hoy.year - fecha_nacimiento.year - ((hoy.month, hoy.day) < (fecha_nacimiento.month, fecha_nacimiento.day))

# ==========================================
# ENDPOINTS API (JSON)
# ==========================================

@app.get("/api/pacientes/{documento_id}", response_model=schemas.Usuario, tags=["API Médicos"])
def buscar_paciente_por_id(
    documento_id: int,
    db: Session = Depends(get_db),
    current_user: Any = Depends(check_role("medico"))
):
    paciente = db.query(models.Usuario).options(
        joinedload(models.Usuario.atenciones)
    ).filter(models.Usuario.documento_id == documento_id).first()
    
    if not paciente:
        raise HTTPException(status_code=404, detail="Paciente no encontrado")
    
    # Calcular edad al vuelo
    if paciente.fecha_nacimiento:
        paciente.edad = calcular_edad_real(paciente.fecha_nacimiento)
    
    # Procesar nombres de profesionales en el historial
    for atencion in paciente.atenciones:
        # Corrección de Zona Horaria para la vista del médico
        if atencion.fecha_hora_atencion:
             if atencion.fecha_hora_atencion.tzinfo is None:
                atencion.fecha_hora_atencion = atencion.fecha_hora_atencion.replace(tzinfo=ZoneInfo("UTC")).astimezone(COLOMBIA_TZ)
             else:
                atencion.fecha_hora_atencion = atencion.fecha_hora_atencion.astimezone(COLOMBIA_TZ)

        if atencion.profesional_responsable:
            profesional = db.query(models.ProfesionalSalud).filter(
                models.ProfesionalSalud.id_personal_salud == atencion.profesional_responsable
            ).first()
            atencion.profesional_responsable_nombre = profesional.nombre_completo if profesional else "Desconocido"
            # También inyectamos este campo para usarlo en el frontend si es necesario
            atencion.responsable_registro = atencion.profesional_responsable_nombre
        else:
            atencion.profesional_responsable_nombre = "No especificado"

    return paciente

@app.get("/api/admision/pacientes/{documento_id}", response_model=schemas.Usuario, tags=["API Admisionistas"])
def buscar_paciente_para_admision(
    documento_id: int,
    db: Session = Depends(get_db),
    current_user: Any = Depends(check_role("admisionista"))
):
    paciente = db.query(models.Usuario).filter(models.Usuario.documento_id == documento_id).first()
    if not paciente:
        raise HTTPException(status_code=404, detail="Paciente no encontrado")
    return paciente

@app.post("/api/pacientes/", response_model=schemas.Usuario, tags=["API Admisionistas"])
async def crear_paciente(
    paciente_in: schemas.UsuarioCreate,
    db: Session = Depends(get_db),
    current_user: Any = Depends(check_role("admisionista"))
):
    # Validaciones de existencia
    if db.query(models.Usuario).filter(models.Usuario.documento_id == paciente_in.documento_id).first():
        raise HTTPException(status_code=409, detail="Ya existe un paciente con este documento.")
    
    if db.query(models.Usuario).filter(models.Usuario.correo_electronico == paciente_in.correo_electronico).first():
        raise HTTPException(status_code=409, detail="Ya existe un paciente con este correo.")

    hashed_password = get_password_hash(paciente_in.password)
    
    # Calcular edad inicial para guardar en DB (aunque se recalcula al leer)
    edad_inicial = None
    if paciente_in.fecha_nacimiento:
        try:
            edad_inicial = calcular_edad_real(paciente_in.fecha_nacimiento)
        except:
            pass

    db_paciente = models.Usuario(
        **paciente_in.model_dump(exclude={"password", "tipo_usuario"}, exclude_none=True),
        hashed_password=hashed_password,
        tipo_usuario="paciente",
        edad=edad_inicial
    )
    
    try:
        db.add(db_paciente)
        db.commit()
        db.refresh(db_paciente)
    except IntegrityError:
        db.rollback()
        raise HTTPException(status_code=409, detail="Error de integridad al guardar.")
    
    return db_paciente

@app.put("/api/pacientes/{documento_id}", response_model=schemas.Usuario, tags=["API Admisionistas"])
async def actualizar_paciente(
    documento_id: int,
    paciente_in: schemas.UsuarioUpdate,
    db: Session = Depends(get_db),
    current_user: Any = Depends(check_role("admisionista"))
):
    db_paciente = db.query(models.Usuario).filter(models.Usuario.documento_id == documento_id).first()
    if not db_paciente:
        raise HTTPException(status_code=404, detail="Paciente no encontrado")

    update_data = paciente_in.model_dump(exclude_unset=True)
    for field, value in update_data.items():
        setattr(db_paciente, field, value)
    
    # Recalcular edad si cambió la fecha de nacimiento
    if 'fecha_nacimiento' in update_data and update_data['fecha_nacimiento']:
        db_paciente.edad = calcular_edad_real(db_paciente.fecha_nacimiento)

    try:
        db.add(db_paciente)
        db.commit()
        db.refresh(db_paciente)
    except IntegrityError:
        db.rollback()
        raise HTTPException(status_code=409, detail="Error al actualizar.")
        
    return db_paciente

@app.post("/api/atenciones/", response_model=schemas.Atencion, tags=["API Médicos"])
async def crear_atencion(
    atencion_in: schemas.AtencionCreate,
    db: Session = Depends(get_db),
    current_user: Any = Depends(check_role("medico"))
):
    paciente = db.query(models.Usuario).filter(models.Usuario.documento_id == atencion_in.documento_id).first()
    if not paciente:
        raise HTTPException(status_code=404, detail="El paciente no existe.")

    atencion_data = atencion_in.model_dump(exclude_none=True)
    
    # Registrar con HORA COLOMBIANA
    db_atencion = models.Atencion(
        **atencion_data,
        fecha_hora_atencion=datetime.now(COLOMBIA_TZ),
        profesional_responsable=current_user.id_personal_salud if hasattr(current_user, 'id_personal_salud') else None,
        responsable_registro=f"Dr. {current_user.primer_nombre} {current_user.primer_apellido}" # Guardamos nombre legible también
    )
    
    try:
        db.add(db_atencion)
        db.commit()
        db.refresh(db_atencion)
    except IntegrityError as e:
        db.rollback()
        raise HTTPException(status_code=409, detail=f"Error al guardar atención: {e}")
        
    return db_atencion

# ==========================================
# ENDPOINTS VISTAS (HTML)
# ==========================================

@app.get("/", response_class=RedirectResponse, include_in_schema=False)
def read_root():
    return RedirectResponse(url="/login")

@app.get("/dashboard", response_class=HTMLResponse, tags=["Frontend"])
async def dashboard_page(request: Request, current_user: Any = Depends(get_current_user)):
    return templates.TemplateResponse("dashboard.html", {"request": request, "user": current_user})

@app.get("/login", response_class=HTMLResponse, tags=["Frontend"])
async def login_page(request: Request):
    return templates.TemplateResponse("login.html", {"request": request})

@app.get("/logout", tags=["Autenticación"])
async def logout():
    response = RedirectResponse(url="/login")
    response.delete_cookie("hce_access_token")
    return response

@app.get("/medico", response_class=HTMLResponse, tags=["Frontend Roles"])
async def medico_page(request: Request, current_user: Any = Depends(check_role("medico"))):
    return templates.TemplateResponse("vista_medico.html", {"request": request, "user": current_user})

@app.get("/admisionista", response_class=HTMLResponse, tags=["Frontend Roles"])
async def admisionista_page(request: Request, current_user: Any = Depends(check_role("admisionista"))):
    return templates.TemplateResponse("vista_admisionista.html", {"request": request, "user": current_user})

@app.get("/paciente/me", response_class=HTMLResponse, tags=["Frontend Roles"])
async def paciente_page(
    request: Request, 
    current_user: Any = Depends(check_role("paciente")),
    db: Session = Depends(get_db)
):
    # Calcular edad al vuelo
    if current_user.fecha_nacimiento:
        current_user.edad = calcular_edad_real(current_user.fecha_nacimiento)

    for atencion in current_user.atenciones:
        # 1. Corrección Zona Horaria
        if atencion.fecha_hora_atencion:
            if atencion.fecha_hora_atencion.tzinfo is None:
                atencion.fecha_hora_atencion = atencion.fecha_hora_atencion.replace(tzinfo=ZoneInfo("UTC")).astimezone(COLOMBIA_TZ)
            else:
                atencion.fecha_hora_atencion = atencion.fecha_hora_atencion.astimezone(COLOMBIA_TZ)
        
        # 2. Parsear JSON de signos vitales
        if atencion.signos_vitales and isinstance(atencion.signos_vitales, str):
            try:
                atencion.signos_vitales = json.loads(atencion.signos_vitales)
            except:
                atencion.signos_vitales = {}

        # 3. Obtener nombre real del médico
        if atencion.profesional_responsable:
            profesional = db.query(models.ProfesionalSalud).filter(
                models.ProfesionalSalud.id_personal_salud == atencion.profesional_responsable
            ).first()
            atencion.profesional_nombre_temp = profesional.nombre_completo if profesional else "Desconocido"
        else:
            atencion.profesional_nombre_temp = atencion.responsable_registro or "Profesional de Staff"

    return templates.TemplateResponse("vista_paciente.html", {"request": request, "user": current_user})

@app.get("/exportar_pdf/{documento_id}", tags=["PDF"], response_class=StreamingResponse)
async def exportar_historia_pdf(
    request: Request,
    documento_id: int,
    db: Session = Depends(get_db),
    current_user: Any = Depends(get_current_user) # Usamos get_current_user genérico
):
    # Validación manual de roles para permitir Medico Y Paciente
    if current_user.tipo_usuario not in ["medico", "paciente"]:
         raise HTTPException(status_code=403, detail="No tiene permisos para exportar.")
    
    # Si es paciente, solo puede ver su propia historia
    if current_user.tipo_usuario == "paciente" and int(current_user.documento_id) != int(documento_id):
         raise HTTPException(status_code=403, detail="No puede acceder a historias de otros pacientes.")

    paciente = db.query(models.Usuario).filter(models.Usuario.documento_id == documento_id).first()
    if not paciente:
        raise HTTPException(status_code=404, detail="Paciente no encontrado")
    
    # Calcular edad para el PDF
    if paciente.fecha_nacimiento:
        paciente.edad = calcular_edad_real(paciente.fecha_nacimiento)

    atenciones = db.query(models.Atencion).filter(models.Atencion.documento_id == documento_id).all()

    for atencion in atenciones:
        # Corrección Hora
        if atencion.fecha_hora_atencion:
            if atencion.fecha_hora_atencion.tzinfo is None:
                atencion.fecha_hora_atencion = atencion.fecha_hora_atencion.replace(tzinfo=ZoneInfo("UTC")).astimezone(COLOMBIA_TZ)
            else:
                atencion.fecha_hora_atencion = atencion.fecha_hora_atencion.astimezone(COLOMBIA_TZ)
        
        # Nombre Médico
        if atencion.profesional_responsable:
            profesional = db.query(models.ProfesionalSalud).filter(
                models.ProfesionalSalud.id_personal_salud == atencion.profesional_responsable
            ).first()
            atencion.profesional_nombre_temp = profesional.nombre_completo if profesional else "Firma Pendiente"
        else:
            atencion.profesional_nombre_temp = atencion.responsable_registro or "Profesional de Turno"

        # Parsear Signos Vitales
        if atencion.signos_vitales and isinstance(atencion.signos_vitales, str):
            try:
                atencion.signos_vitales = json.loads(atencion.signos_vitales)
            except:
                atencion.signos_vitales = {}

    fecha_impresion = datetime.now(COLOMBIA_TZ).strftime("%d/%m/%Y %H:%M")

    html_content = templates.TemplateResponse(
        "pdf_template.html", 
        {
            "request": request, 
            "paciente": paciente, 
            "atenciones": atenciones,
            "fecha_impresion": fecha_impresion
        }
    ).body.decode("utf-8")

    pdf_buffer = BytesIO()
    HTML(string=html_content).write_pdf(pdf_buffer)
    pdf_buffer.seek(0)

    filename = f"HC_{paciente.documento_id}_{datetime.now(COLOMBIA_TZ).strftime('%Y%m%d')}.pdf"
    return StreamingResponse(
        pdf_buffer,
        media_type="application/pdf",
        headers={"Content-Disposition": f"attachment; filename={filename}"}
    )

@app.post("/token", tags=["Autenticación"])
async def login_for_access_token(response: Response, form_data: OAuth2PasswordRequestForm = Depends(), db: Session = Depends(get_db)):
    try:
        user = authenticate_user(db, form_data.username, form_data.password)
        if not user:
            raise HTTPException(status_code=401, detail="Email o contraseña incorrectos")
    except Exception as e:
        raise HTTPException(status_code=401, detail=f"Error de autenticación: {e}")

    access_token_expires = timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    access_token = create_access_token(
        data={"sub": user.correo_electronico, "role": user.tipo_usuario}, expires_delta=access_token_expires
    )
    
    response.set_cookie(
        key="hce_access_token",
        value=access_token,
        httponly=True,
        samesite="lax",
        secure=False,
    )
    return {"message": "Login successful"}

@app.get("/hash-password/{password}", tags=["Utilidades"])
def hash_password_endpoint(password: str):
    return {"hashed_password": get_password_hash(password)}