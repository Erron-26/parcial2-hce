from pydantic import BaseModel, ConfigDict, Field
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
    tipo_atencion: str = Field(..., max_length=80)
    motivo_consulta: str
    enfermedad_actual: str
    antecedentes_personales: Optional[str] = None
    antecedentes_familiares: Optional[str] = None
    alergias_conocidas: Optional[str] = None
    medicamentos_actuales: Optional[str] = None
    signos_vitales: Optional[Any] = None # Acepta un JSON para signos vitales
    examen_fisico_general: Optional[str] = None
    examen_fisico_por_sistemas: Optional[str] = None
    impresion_diagnostica: str
    conducta_plan_manejo: str
    codigos_cie10: Optional[str] = None # Se enviará como un string separado por comas


# Esquema base para el usuario (sin contraseña)
class UsuarioBase(BaseModel):
    documento_id: int
    tipo_documento: Optional[str] = Field(None, max_length=30)
    primer_apellido: Optional[str] = Field(None, max_length=120)
    segundo_apellido: Optional[str] = Field(None, max_length=120)
    primer_nombre: Optional[str] = Field(None, max_length=120)
    segundo_nombre: Optional[str] = Field(None, max_length=120)
    fecha_nacimiento: Optional[date] = None
    edad: Optional[int] = None # Añadido para consistencia con models.Usuario
    sexo: Optional[str] = Field(None, max_length=20)
    genero: Optional[str] = Field(None, max_length=60)
    grupo_sanguineo: Optional[str] = Field(None, max_length=10)
    factor_rh: Optional[str] = Field(None, max_length=5)
    estado_civil: Optional[str] = Field(None, max_length=50)
    direccion_residencia: Optional[str] = None
    municipio_ciudad: Optional[str] = Field(None, max_length=120)
    departamento: Optional[str] = Field(None, max_length=120)
    telefono: Optional[str] = Field(None, max_length=50)
    celular: Optional[str] = Field(None, max_length=50)
    correo_electronico: Optional[str] = Field(None, max_length=255)
    ocupacion: Optional[str] = Field(None, max_length=150)
    entidad_afiliacion: Optional[str] = Field(None, max_length=255)
    regimen_afiliacion: Optional[str] = Field(None, max_length=80)
    tipo_usuario: Optional[str] = Field(None, max_length=80)
    
    model_config = ConfigDict(from_attributes=True)

# Esquema para la creación de usuario (incluye contraseña)
class UsuarioCreate(UsuarioBase):
    password: str

# Esquema completo para el usuario (para respuestas de API, sin contraseña hash)
class Usuario(UsuarioBase):
    atenciones: List[Atencion] = []

# Esquema para la actualización de un usuario existente (todos los campos son opcionales)
class UsuarioUpdate(BaseModel):
    tipo_documento: Optional[str] = Field(None, max_length=30)
    primer_apellido: Optional[str] = Field(None, max_length=120)
    segundo_apellido: Optional[str] = Field(None, max_length=120)
    primer_nombre: Optional[str] = Field(None, max_length=120)
    segundo_nombre: Optional[str] = Field(None, max_length=120)
    fecha_nacimiento: Optional[date] = None
    edad: Optional[int] = None
    sexo: Optional[str] = Field(None, max_length=20)
    genero: Optional[str] = Field(None, max_length=60)
    grupo_sanguineo: Optional[str] = Field(None, max_length=10)
    factor_rh: Optional[str] = Field(None, max_length=5)
    estado_civil: Optional[str] = Field(None, max_length=50)
    direccion_residencia: Optional[str] = None
    municipio_ciudad: Optional[str] = Field(None, max_length=120)
    departamento: Optional[str] = Field(None, max_length=120)
    telefono: Optional[str] = Field(None, max_length=50)
    celular: Optional[str] = Field(None, max_length=50)
    correo_electronico: Optional[str] = Field(None, max_length=255)
    ocupacion: Optional[str] = Field(None, max_length=150)
    entidad_afiliacion: Optional[str] = Field(None, max_length=255)
    regimen_afiliacion: Optional[str] = Field(None, max_length=80)

    model_config = ConfigDict(from_attributes=True)

# Esquema para el token de autenticación
class Token(BaseModel):
    access_token: str
    token_type: str

class TokenData(BaseModel):
    username: Optional[str] = None
