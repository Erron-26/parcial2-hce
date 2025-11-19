from datetime import timedelta, datetime
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
    ACCESS_TOKEN_EXPIRE_MINUTES,
)

Base.metadata.create_all(bind=engine)

app = FastAPI(
    title="API para Sistema de Historias Clínicas Electrónicas",
    description="Middleware para la gestión de HCE con FastAPI y Citus",
    version="1.0.0",
)

templates = Jinja2Templates(directory="backend/templates")

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

async def get_current_user(token: str = Depends(oauth2_scheme), db: Session = Depends(get_db)) -> Any:
    from jose import jwt, JWTError
    from .core.security import SECRET_KEY, ALGORITHM
    
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="No se pudieron validar las credenciales",
        headers={"WWW-Authenticate": "Bearer"},
    )
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        username: str = payload.get("sub")
        if username is None:
            raise credentials_exception
        token_data = schemas.TokenData(username=username)
    except JWTError:
        raise credentials_exception
    user = db.query(models.Usuario).options(
        joinedload(models.Usuario.atenciones)
    ).filter(models.Usuario.correo_electronico == token_data.username).first()
    if user is None:
        raise credentials_exception
    return user

# --- Endpoints de API (devuelven JSON) ---

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
    
    return paciente

@app.post("/api/pacientes/", response_model=schemas.Usuario, tags=["API Admisionistas"])
async def crear_paciente(
    paciente_in: schemas.UsuarioCreate,
    db: Session = Depends(get_db),
    current_user: Any = Depends(check_role("admisionista"))
):
    existing_user_doc = db.query(models.Usuario).filter(models.Usuario.documento_id == paciente_in.documento_id).first()
    if existing_user_doc:
        raise HTTPException(status_code=409, detail="Ya existe un paciente con este número de documento.")
    
    existing_user_email = db.query(models.Usuario).filter(models.Usuario.correo_electronico == paciente_in.correo_electronico).first()
    if existing_user_email:
        raise HTTPException(status_code=409, detail="Ya existe un paciente con este correo electrónico.")

    hashed_password = get_password_hash(paciente_in.password)
    
    db_paciente = models.Usuario(
        **paciente_in.model_dump(exclude={"password", "tipo_usuario"}),
        hashed_password=hashed_password,
        tipo_usuario="paciente"
    )
    
    try:
        db.add(db_paciente)
        db.commit()
        db.refresh(db_paciente)
    except IntegrityError:
        db.rollback()
        raise HTTPException(
            status_code=409,
            detail="Error de integridad de la base de datos. El documento o email podrían ya existir.",
        )
    
    return db_paciente

@app.post("/api/atenciones/", response_model=schemas.Atencion, tags=["API Médicos"])
async def crear_atencion(
    atencion_in: schemas.AtencionCreate,
    db: Session = Depends(get_db),
    current_user: Any = Depends(check_role("medico"))
):
    """
    Registra una nueva atención para un paciente.
    Requiere rol 'medico'.
    """
    # Verificar que el paciente existe
    paciente = db.query(models.Usuario).filter(models.Usuario.documento_id == atencion_in.documento_id).first()
    if not paciente:
        raise HTTPException(status_code=404, detail="El paciente especificado no existe.")

    # El médico actual es el profesional responsable
    # NOTA: Esto asume que el médico está registrado en la tabla `profesional_salud`
    # y que su `documento_id` en `usuario` coincide de alguna manera.
    # Por simplicidad, aquí asumimos que el `current_user` tiene una clave
    # que puede ser usada como `profesional_responsable`.
    # en un sistema real, se necesitaría un mapeo más robusto.
    # Por ahora, dejamos el campo profesional_responsable nulo.

    atencion_data = atencion_in.model_dump()
    
    # Procesar la cadena de codigos_cie10 en una lista
    codigos_str = atencion_data.pop("codigos_cie10", None)
    if codigos_str:
        codigos_list = [code.strip() for code in codigos_str.split(',')]
        atencion_data['codigos_cie10'] = codigos_list
    else:
        atencion_data['codigos_cie10'] = None
    
    db_atencion = models.Atencion(
        **atencion_data,
        fecha_hora_atencion=datetime.now(),
        # profesional_responsable=current_user.id_personal_salud # Descomentar si se implementa el mapeo
    )
    
    try:
        db.add(db_atencion)
        db.commit()
        db.refresh(db_atencion)
    except IntegrityError:
        db.rollback()
        raise HTTPException(
            status_code=409,
            detail="Error de integridad al guardar la atención.",
        )
        
    return db_atencion

# --- Endpoints de la Aplicación (devuelven HTML o respuestas directas) ---

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

@app.get("/paciente/me", response_class=HTMLResponse, tags=["Frontend Roles"])
async def paciente_page(request: Request, current_user: Any = Depends(check_role("paciente"))):
    return templates.TemplateResponse("vista_paciente.html", {"request": request, "user": current_user})

@app.get("/admisionista", response_class=HTMLResponse, tags=["Frontend Roles"])
async def admisionista_page(request: Request, current_user: Any = Depends(check_role("admisionista"))):
    return templates.TemplateResponse("vista_admisionista.html", {"request": request, "user": current_user})

@app.get("/exportar_pdf/{documento_id}", tags=["PDF"], response_class=StreamingResponse)
async def exportar_historia_pdf(
    documento_id: int,
    db: Session = Depends(get_db),
    current_user: Any = Depends(check_role("medico"))
):
    paciente = db.query(models.Usuario).filter(models.Usuario.documento_id == documento_id).first()
    if not paciente:
        raise HTTPException(status_code=404, detail="Paciente no encontrado")

    atenciones = db.query(models.Atencion).filter(models.Atencion.documento_id == documento_id).all()

    for atencion in atenciones:
        if atencion.profesional_responsable:
            profesional = db.query(models.ProfesionalSalud).filter(
                models.ProfesionalSalud.id_personal_salud == atencion.profesional_responsable
            ).first()
            atencion.profesional_responsable_nombre = profesional.nombre_completo if profesional else "Desconocido"
        else:
            atencion.profesional_responsable_nombre = "No especificado"

    html_content = templates.TemplateResponse(
        "pdf_template.html", 
        {"request": Request, "paciente": paciente, "atenciones": atenciones}
    ).body.decode("utf-8")

    pdf_buffer = BytesIO()
    HTML(string=html_content).write_pdf(pdf_buffer)
    pdf_buffer.seek(0)

    filename = f"historia_clinica_{paciente.documento_id}.pdf"
    return StreamingResponse(
        pdf_buffer,
        media_type="application/pdf",
        headers={"Content-Disposition": f"attachment; filename={filename}"}
    )

@app.post("/token", tags=["Autenticación"])
async def login_for_access_token(response: Response, form_data: OAuth2PasswordRequestForm = Depends(), db: Session = Depends(get_db)):
    user = authenticate_user(db, form_data.username, form_data.password)
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Email o contraseña incorrectos",
            headers={"WWW-Authenticate": "Bearer"},
        )
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

@app.get("/hash-password/{password}", tags=["Utilidades (Temporal)"])
def hash_password_endpoint(password: str):
    return {"hashed_password": get_password_hash(password)}
