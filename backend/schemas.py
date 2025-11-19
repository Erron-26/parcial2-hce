from pydantic import BaseModel, ConfigDict
from datetime import date, datetime
from typing import Optional, List, Any

# Esquema para una atención médica
class Atencion(BaseModel):
    atencion_id: Any  # UUID puede ser complejo para Pydantic, Any es más simple
    fecha_hora_atencion: datetime
    tipo_atencion: Optional[str] = None
    motivo_consulta: Optional[str] = None
    impresion_diagnostica: Optional[str] = None

    model_config = ConfigDict(from_attributes=True)

# Esquema para la creación de una nueva atención
class AtencionCreate(BaseModel):
    documento_id: int
    tipo_atencion: str
    motivo_consulta: str
    enfermedad_actual: str
    impresion_diagnostica: str
    conducta_plan_manejo: str
    codigos_cie10: Optional[str] = None # Se enviará como un string separado por comas


# Esquema base para el usuario (sin contraseña)
class UsuarioBase(BaseModel):
    documento_id: int
    tipo_documento: Optional[str] = None
    primer_apellido: Optional[str] = None
    segundo_apellido: Optional[str] = None
    primer_nombre: Optional[str] = None
    segundo_nombre: Optional[str] = None
    fecha_nacimiento: Optional[date] = None
    edad: Optional[int] = None # Añadido para consistencia con models.Usuario
    sexo: Optional[str] = None
    genero: Optional[str] = None
    grupo_sanguineo: Optional[str] = None
    factor_rh: Optional[str] = None
    estado_civil: Optional[str] = None
    direccion_residencia: Optional[str] = None
    municipio_ciudad: Optional[str] = None
    departamento: Optional[str] = None
    telefono: Optional[str] = None
    celular: Optional[str] = None
    correo_electronico: Optional[str] = None
    ocupacion: Optional[str] = None
    entidad_afiliacion: Optional[str] = None
    regimen_afiliacion: Optional[str] = None
    tipo_usuario: Optional[str] = None # Define un tipo por defecto si es necesario (ej. "paciente")
    
    model_config = ConfigDict(from_attributes=True)

# Esquema para la creación de usuario (incluye contraseña)
class UsuarioCreate(UsuarioBase):
    password: str

# Esquema completo para el usuario (para respuestas de API, sin contraseña hash)
class Usuario(UsuarioBase):
    atenciones: List[Atencion] = []

# Esquema para el token de autenticación
class Token(BaseModel):
    access_token: str
    token_type: str

class TokenData(BaseModel):
    username: Optional[str] = None
