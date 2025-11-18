from datetime import timedelta
from typing import Optional

from fastapi import FastAPI, Depends, HTTPException, status
from fastapi.security import OAuth2PasswordRequestForm
from sqlalchemy.orm import Session

from .db import models
from .db.session import SessionLocal, engine
from .db.base import Base
from . import schemas
from .core.security import (
    authenticate_user,
    create_access_token,
    get_password_hash,
    oauth2_scheme,
    ACCESS_TOKEN_EXPIRE_MINUTES,
)

# This will create the tables in the database if they don't exist.
# In a production environment, you might want to use Alembic for migrations.
Base.metadata.create_all(bind=engine)

app = FastAPI(
    title="API para Sistema de Historias Clínicas Electrónicas",
    description="Middleware para la gestión de HCE con FastAPI y Citus",
    version="1.0.0",
)

# Dependency to get a DB session
def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


# --- Dependencia personalizada para obtener usuario actual ---
async def get_current_user(
    token: str = Depends(oauth2_scheme),
    db: Session = Depends(get_db),
) -> models.Usuario:
    """
    Valida el JWT token y retorna el usuario actual.
    
    Requiere:
    - Token JWT válido en header Authorization
    - Usuario debe existir en base de datos
    """
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
    user = db.query(models.Usuario).filter(models.Usuario.correo_electronico == token_data.username).first()
    if user is None:
        raise credentials_exception
    return user

# --- Endpoints ---

@app.get("/", tags=["Health Check"])
def read_root():
    """
    Endpoint de verificación para confirmar que la API está funcionando.
    """
    return {"status": "API funcionando correctamente"}

@app.post("/token", response_model=schemas.Token, tags=["Autenticación"])
async def login_for_access_token(form_data: OAuth2PasswordRequestForm = Depends(), db: Session = Depends(get_db)):
    """
    Login endpoint - Genera JWT token.
    
    Usa OAuth2PasswordRequestForm que espera:
    - username: Email del usuario
    - password: Contraseña
    
    Retorna JWT token si credenciales son válidas.
    """
    user = authenticate_user(db, form_data.username, form_data.password)
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Email o contraseña incorrectos",
            headers={"WWW-Authenticate": "Bearer"},
        )
    access_token_expires = timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    access_token = create_access_token(
        data={"sub": user.correo_electronico}, expires_delta=access_token_expires
    )
    return {"access_token": access_token, "token_type": "bearer"}

@app.get("/paciente/{documento_id}", response_model=schemas.Usuario, tags=["Pacientes"])
def read_paciente(documento_id: int, db: Session = Depends(get_db), current_user: models.Usuario = Depends(get_current_user)):
    """
    Obtiene la información de un paciente por su número de documento.
    Requiere autenticación JWT.
    """
    # Aquí podrías añadir lógica de autorización basada en el rol del current_user
    # Por ahora, solo verifica que el usuario esté autenticado.
    db_paciente = db.query(models.Usuario).filter(models.Usuario.documento_id == documento_id).first()
    if db_paciente is None:
        raise HTTPException(status_code=404, detail="Paciente no encontrado")
    return db_paciente

@app.get("/hash-password/{password}", tags=["Utilidades (Temporal)"])
def hash_password_endpoint(password: str):
    """
    Endpoint temporal para generar el hash de una contraseña.
    ¡ELIMINAR EN PRODUCCIÓN!
    
    Usa bcrypt via passlib (seguro, no reversible).
    """
    return {"hashed_password": get_password_hash(password)}