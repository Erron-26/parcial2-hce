"""
Módulo de seguridad para autenticación OAuth2 + JWT.
Implementa generación de tokens, validación y manejo de contraseñas.
"""

from datetime import timedelta, datetime
from typing import Optional
from jose import JWTError, jwt
from passlib.context import CryptContext
from fastapi.security import OAuth2PasswordBearer
from fastapi import Depends, HTTPException, status
from sqlalchemy.orm import Session

from backend.db import models
from backend.core.config import settings

# ============================================
# CONFIGURACIÓN DE SEGURIDAD
# ============================================

# Contexto para hash de contraseñas con argon2
pwd_context = CryptContext(schemes=["argon2"], deprecated="auto")

# Esquema OAuth2
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="token")

# Configuración de JWT
SECRET_KEY = settings.SECRET_KEY if hasattr(settings, 'SECRET_KEY') else "tu-clave-secreta-cambiar-en-produccion"
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 30

# ============================================
# FUNCIONES DE HASH Y CONTRASEÑAS
# ============================================

def get_password_hash(password: str) -> str:
    """Genera el hash de una contraseña usando bcrypt."""
    return pwd_context.hash(password)


def verify_password(plain_password: str, hashed_password: str) -> bool:
    """Verifica si una contraseña coincide con su hash."""
    return pwd_context.verify(plain_password, hashed_password)


# ============================================
# FUNCIONES DE JWT
# ============================================

def create_access_token(
    data: dict,
    expires_delta: Optional[timedelta] = None,
) -> str:
    """
    Crea un JWT token.
    
    Args:
        data: Datos a incluir en el token (ej: {"sub": usuario_email})
        expires_delta: Tiempo de expiración (si None, usa valor por defecto)
    
    Returns:
        Token JWT encriptado
    """
    to_encode = data.copy()
    
    if expires_delta:
        expire = datetime.utcnow() + expires_delta
    else:
        expire = datetime.utcnow() + timedelta(minutes=15)
    
    to_encode.update({"exp": expire})
    encoded_jwt = jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)
    
    return encoded_jwt


# ============================================
# FUNCIONES DE AUTENTICACIÓN
# ============================================

def authenticate_user(db: Session, username: str, password: str) -> Optional[models.Usuario]:
    """
    Autentica un usuario verificando email y contraseña.
    
    Args:
        db: Sesión de base de datos
        username: Email del usuario
        password: Contraseña en texto plano
    
    Returns:
        Usuario si las credenciales son válidas, None en caso contrario
    """
    user = db.query(models.Usuario).filter(
        models.Usuario.correo_electronico == username
    ).first()
    
    if not user:
        return None
    
    if not verify_password(password, user.hashed_password):
        return None
    
    return user


async def get_current_user(
    token: str = Depends(oauth2_scheme),
    db: Session = None,
) -> models.Usuario:
    """
    Valida el token JWT y retorna el usuario actual.
    
    Args:
        token: Token JWT del header Authorization
        db: Sesión de base de datos (inyectada por FastAPI)
    
    Returns:
        Usuario autenticado
    
    Raises:
        HTTPException: Si el token es inválido o el usuario no existe
    """
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
    except JWTError:
        raise credentials_exception
    
    # Si db es None, significa que no fue inyectada correctamente
    if db is None:
        raise credentials_exception
    
    user = db.query(models.Usuario).filter(
        models.Usuario.correo_electronico == username
    ).first()
    
    if user is None:
        raise credentials_exception
    
    return user


# ============================================
# FUNCIONES DE AUTORIZACIÓN POR ROL
# ============================================

def check_role(required_role: str):
    """
    Crea una función decoradora para verificar el rol del usuario.
    
    Args:
        required_role: Rol requerido (ej: "medico", "paciente", "admisionista")
    
    Returns:
        Función decoradora que valida el rol
    """
    async def verify_role(current_user: models.Usuario = Depends(get_current_user)):
        if current_user.tipo_usuario != required_role:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"Se requiere rol '{required_role}' para acceder a este recurso",
            )
        return current_user
    
    return verify_role
