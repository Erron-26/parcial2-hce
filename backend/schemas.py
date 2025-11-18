from pydantic import BaseModel
from datetime import date
from typing import Optional, List

class UsuarioBase(BaseModel):
    documento_id: int
    tipo_documento: Optional[str] = None
    primer_apellido: Optional[str] = None
    segundo_apellido: Optional[str] = None
    primer_nombre: Optional[str] = None
    segundo_nombre: Optional[str] = None
    fecha_nacimiento: Optional[date] = None
    correo_electronico: Optional[str] = None
    password: str # Añadido para autenticación

class Usuario(UsuarioBase):
    class Config:
        from_attributes = True

class Token(BaseModel):
    access_token: str
    token_type: str

class TokenData(BaseModel):
    username: Optional[str] = None