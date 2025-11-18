from sqlalchemy import (
    Column,
    BigInteger,
    String,
    Date,
    Integer,
    Text,
    TIMESTAMP,
    ForeignKey,
)
from sqlalchemy.dialects.postgresql import UUID, JSONB, ARRAY
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
import uuid

from backend.db.base import Base


class Usuario(Base):
    __tablename__ = "usuario"
    __table_args__ = {"schema": "hcd"}

    documento_id = Column(BigInteger, primary_key=True)
    tipo_documento = Column(String(30))
    primer_apellido = Column(String(120))
    segundo_apellido = Column(String(120))
    primer_nombre = Column(String(120))
    segundo_nombre = Column(String(120))
    fecha_nacimiento = Column(Date)
    edad = Column(Integer)
    sexo = Column(String(20))
    genero = Column(String(60))
    grupo_sanguineo = Column(String(10))
    factor_rh = Column(String(5))
    estado_civil = Column(String(50))
    direccion_residencia = Column(Text)
    municipio_ciudad = Column(String(120))
    departamento = Column(String(120))
    telefono = Column(String(50))
    celular = Column(String(50), index=True)
    correo_electronico = Column(String(255), index=True)
    hashed_password = Column(String, nullable=False)
    ocupacion = Column(String(150))
    entidad_afiliacion = Column(String(255))
    regimen_afiliacion = Column(String(80))
    tipo_usuario = Column(String(80))
    datos_adicionales = Column(JSONB)
    created_at = Column(TIMESTAMP(timezone=True), server_default=func.now())
    updated_at = Column(
        TIMESTAMP(timezone=True), server_default=func.now(), onupdate=func.now()
    )

    atenciones = relationship("Atencion", back_populates="usuario")


class ProfesionalSalud(Base):
    __tablename__ = "profesional_salud"
    __table_args__ = {"schema": "hcd"}

    id_personal_salud = Column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    nombre_completo = Column(String(255))
    tipo_profesional = Column(String(80))
    registro_profesional = Column(String(80))
    cargo_servicio = Column(String(120))
    firma_path = Column(Text)
    contacto = Column(JSONB)
    created_at = Column(TIMESTAMP(timezone=True), server_default=func.now())


class Atencion(Base):
    __tablename__ = "atencion"
    __table_args__ = {"schema": "hcd"}

    atencion_id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    documento_id = Column(
        BigInteger, ForeignKey("hcd.usuario.documento_id"), primary_key=True
    )
    fecha_hora_atencion = Column(TIMESTAMP(timezone=True), nullable=False)
    tipo_atencion = Column(String(80))
    motivo_consulta = Column(Text)
    enfermedad_actual = Column(Text)
    antecedentes_personales = Column(Text)
    antecedentes_familiares = Column(Text)
    alergias_conocidas = Column(Text)
    habitos = Column(JSONB)
    medicamentos_actuales = Column(Text)
    signos_vitales = Column(JSONB)
    examen_fisico_general = Column(Text)
    examen_fisico_por_sistemas = Column(Text)
    impresion_diagnostica = Column(Text)
    codigos_cie10 = Column(ARRAY(String))
    conducta_plan_manejo = Column(Text)
    recomendaciones_paciente = Column(Text)
    medicos_interconsultados = Column(Text)
    procedimientos_realizados = Column(Text)
    resultados_paraclinicos = Column(JSONB)
    diagnostico_definitivo = Column(Text)
    evolucion_medica = Column(Text)
    tratamiento_instaurado = Column(Text)
    formulacion_medica = Column(JSONB)
    educacion_consejeria = Column(Text)
    referencia_contrarreferencia = Column(Text)
    estado_egreso = Column(String(80), index=True)
    profesional_responsable = Column(
        UUID(as_uuid=True), ForeignKey("hcd.profesional_salud.id_personal_salud")
    )
    firma_paciente_path = Column(Text)
    fecha_hora_cierre = Column(TIMESTAMP(timezone=True))
    responsable_registro = Column(String(120))
    created_at = Column(TIMESTAMP(timezone=True), server_default=func.now())
    updated_at = Column(
        TIMESTAMP(timezone=True), server_default=func.now(), onupdate=func.now()
    )

    usuario = relationship("Usuario", back_populates="atenciones")
    # diagnosticos, tecnologias_salud y egreso tienen foreign keys complejas
    # Se comentan por ahora para evitar errores de ambigüedad
    # diagnosticos = relationship("Diagnostico", back_populates="atencion")
    # tecnologias_salud = relationship("TecnologiaSalud", back_populates="atencion")
    # egreso = relationship("Egreso", back_populates="atencion")


class Diagnostico(Base):
    __tablename__ = "diagnostico"
    __table_args__ = {"schema": "hcd"}

    atencion_id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    documento_id = Column(BigInteger, ForeignKey("hcd.atencion.documento_id"), nullable=False)
    atencion_id_fk = Column(UUID(as_uuid=True), ForeignKey("hcd.atencion.atencion_id"), nullable=False)
    tipo_diagnostico = Column(String(80))
    diagnostico_text = Column(Text)
    codigo_cie10 = Column(String(30))
    gravedad = Column(String(50))
    registro_medico = Column(JSONB)
    created_at = Column(TIMESTAMP(timezone=True), server_default=func.now())

    # atencion = relationship("Atencion", back_populates="diagnosticos")


class TecnologiaSalud(Base):
    __tablename__ = "tecnologia_salud"
    __table_args__ = {"schema": "hcd"}

    tecnologia_id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    documento_id = Column(BigInteger, ForeignKey("hcd.atencion.documento_id"), nullable=False)
    atencion_id = Column(UUID(as_uuid=True), ForeignKey("hcd.atencion.atencion_id"), nullable=False)
    descripcion_medicamento = Column(Text)
    dosis = Column(String(80))
    via_administracion = Column(String(80))
    frecuencia = Column(String(80))
    dias_tratamiento = Column(Integer)
    unidades_aplicadas = Column(Integer, default=0)
    id_personal_salud = Column(
        UUID(as_uuid=True), ForeignKey("hcd.profesional_salud.id_personal_salud")
    )
    finalidad_tecnologia = Column(Text)
    registro_administracion = Column(JSONB)
    created_at = Column(TIMESTAMP(timezone=True), server_default=func.now())

    # atencion = relationship("Atencion", back_populates="tecnologias_salud")


class Egreso(Base):
    __tablename__ = "egreso"
    __table_args__ = {"schema": "hcd"}

    egreso_id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    documento_id = Column(BigInteger, ForeignKey("hcd.atencion.documento_id"), nullable=False)
    atencion_id = Column(UUID(as_uuid=True), ForeignKey("hcd.atencion.atencion_id"), nullable=False)
    estado_egreso = Column(String(80))
    causas_egreso = Column(Text)
    recomendaciones_al_egreso = Column(Text)
    fecha_egreso = Column(TIMESTAMP(timezone=True))
    created_at = Column(TIMESTAMP(timezone=True), server_default=func.now())

    # atencion = relationship("Atencion", back_populates="egreso")
