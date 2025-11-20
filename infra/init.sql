-- 1) Extensiones necesarias
CREATE EXTENSION IF NOT EXISTS citus;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 2) Schema
CREATE SCHEMA IF NOT EXISTS hcd;

-- 3) Tabla usuario: datos de identificación del paciente
CREATE TABLE IF NOT EXISTS hcd.usuario (
  documento_id BIGINT PRIMARY KEY,
  tipo_documento VARCHAR(30),
  primer_apellido VARCHAR(120),
  segundo_apellido VARCHAR(120),
  primer_nombre VARCHAR(120),
  segundo_nombre VARCHAR(120),
  fecha_nacimiento DATE,
  edad INT,
  sexo VARCHAR(20),
  genero VARCHAR(60),
  grupo_sanguineo VARCHAR(10),
  factor_rh VARCHAR(5),
  estado_civil VARCHAR(50),
  direccion_residencia TEXT,
  municipio_ciudad VARCHAR(120),
  departamento VARCHAR(120),
  telefono VARCHAR(50),
  celular VARCHAR(50),
  correo_electronico VARCHAR(255),
  hashed_password VARCHAR(255) NOT NULL,
  ocupacion VARCHAR(150),
  entidad_afiliacion VARCHAR(255),
  regimen_afiliacion VARCHAR(80),
  tipo_usuario VARCHAR(80),
  datos_adicionales JSONB,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

COMMENT ON TABLE hcd.usuario IS 'Tabla de identificación del paciente (Resolución 1995/1999, Ley 1581/2012 - datos sensibles)';

CREATE INDEX IF NOT EXISTS idx_usuario_correo ON hcd.usuario (correo_electronico);
CREATE INDEX IF NOT EXISTS idx_usuario_celular ON hcd.usuario (celular);

-- 4) Tabla profesional_salud (será tabla de referencia)
CREATE TABLE IF NOT EXISTS hcd.profesional_salud (
  id_personal_salud UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  nombre_completo VARCHAR(255),
  tipo_profesional VARCHAR(80),
  registro_profesional VARCHAR(80),
  cargo_servicio VARCHAR(120),
  firma_path TEXT,
  contacto JSONB,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

COMMENT ON TABLE hcd.profesional_salud IS 'Datos del profesional que atiende';

-- 5) Tabla atencion: CLAVE COMPUESTA (documento_id, atencion_id)
-- Para cumplir con requisito de Citus: PK debe incluir columna de distribución
CREATE TABLE IF NOT EXISTS hcd.atencion (
  atencion_id UUID DEFAULT uuid_generate_v4(),
  documento_id BIGINT NOT NULL,
  fecha_hora_atencion TIMESTAMP WITH TIME ZONE NOT NULL,
  tipo_atencion VARCHAR(80),
  motivo_consulta TEXT,
  enfermedad_actual TEXT,
  antecedentes_personales TEXT,
  antecedentes_familiares TEXT,
  alergias_conocidas TEXT,
  habitos JSONB,
  medicamentos_actuales TEXT,
  signos_vitales JSONB,
  examen_fisico_general TEXT,
  examen_fisico_por_sistemas TEXT,
  impresion_diagnostica TEXT,
  codigos_cie10 TEXT[],
  conducta_plan_manejo TEXT,
  recomendaciones_paciente TEXT,
  medicos_interconsultados TEXT,
  procedimientos_realizados TEXT,
  resultados_paraclinicos JSONB,
  diagnostico_definitivo TEXT,
  evolucion_medica TEXT,
  tratamiento_instaurado TEXT,
  formulacion_medica JSONB,
  educacion_consejeria TEXT,
  referencia_contrarreferencia TEXT,
  estado_egreso VARCHAR(80),
  profesional_responsable UUID,
  firma_paciente_path TEXT,
  fecha_hora_cierre TIMESTAMP WITH TIME ZONE,
  responsable_registro VARCHAR(120),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  PRIMARY KEY (documento_id, atencion_id)  -- Clave compuesta incluyendo columna de distribución
);

COMMENT ON TABLE hcd.atencion IS 'Tabla con datos administrativos y clínicos por episodio de atención';

-- Índices de consulta rápida
CREATE INDEX IF NOT EXISTS idx_atencion_atencion_id ON hcd.atencion (atencion_id);
CREATE INDEX IF NOT EXISTS idx_atencion_fecha ON hcd.atencion (documento_id, fecha_hora_atencion);
CREATE INDEX IF NOT EXISTS idx_atencion_estado_egreso ON hcd.atencion (estado_egreso);

-- 6) Tabla diagnostico: CLAVE COMPUESTA
CREATE TABLE IF NOT EXISTS hcd.diagnostico (
  diagnostico_id UUID DEFAULT uuid_generate_v4(),
  atencion_id UUID NOT NULL,
  documento_id BIGINT NOT NULL,  -- Necesario para co-localización
  tipo_diagnostico VARCHAR(80),
  diagnostico_text TEXT,
  codigo_cie10 VARCHAR(30),
  gravedad VARCHAR(50),
  registro_medico JSONB,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  PRIMARY KEY (documento_id, diagnostico_id)
);

CREATE INDEX IF NOT EXISTS idx_diag_atencion ON hcd.diagnostico (atencion_id);

-- 7) Tabla tecnologia_salud: CLAVE COMPUESTA
CREATE TABLE IF NOT EXISTS hcd.tecnologia_salud (
  tecnologia_id UUID DEFAULT uuid_generate_v4(),
  atencion_id UUID NOT NULL,
  documento_id BIGINT NOT NULL,  -- Necesario para co-localización
  descripcion_medicamento TEXT,
  dosis VARCHAR(80),
  via_administracion VARCHAR(80),
  frecuencia VARCHAR(80),
  dias_tratamiento INT,
  unidades_aplicadas INT DEFAULT 0,
  id_personal_salud UUID,
  finalidad_tecnologia TEXT,
  registro_administracion JSONB,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  PRIMARY KEY (documento_id, tecnologia_id)
);

CREATE INDEX IF NOT EXISTS idx_tec_atencion ON hcd.tecnologia_salud (atencion_id);

-- 8) Tabla egreso: CLAVE COMPUESTA
CREATE TABLE IF NOT EXISTS hcd.egreso (
  egreso_id UUID DEFAULT uuid_generate_v4(),
  atencion_id UUID NOT NULL,
  documento_id BIGINT NOT NULL,  -- Necesario para co-localización
  estado_egreso VARCHAR(80),
  causas_egreso TEXT,
  recomendaciones_al_egreso TEXT,
  fecha_egreso TIMESTAMP WITH TIME ZONE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  PRIMARY KEY (documento_id, egreso_id)
);

-- 9) PRIMERO: Crear tabla de referencia (debe hacerse ANTES de distribuir otras tablas)
-- SELECT create_reference_table('hcd.profesional_salud');

-- 10) DISTRIBUIR TABLAS CON CITUS
-- COMENTADAS: Se ejecutarán después de registrar los workers
-- SELECT create_distributed_table('hcd.usuario', 'documento_id');
-- SELECT create_distributed_table('hcd.atencion', 'documento_id');

-- Co-localizar tablas relacionadas (todas por documento_id para mantener datos juntos)
-- SELECT create_distributed_table('hcd.diagnostico', 'documento_id', colocate_with => 'hcd.atencion');
-- SELECT create_distributed_table('hcd.tecnologia_salud', 'documento_id', colocate_with => 'hcd.atencion');
-- SELECT create_distributed_table('hcd.egreso', 'documento_id', colocate_with => 'hcd.atencion');

-- 11) AGREGAR FOREIGN KEYS (después de distribuir)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'fk_atencion_usuario'
  ) THEN
    ALTER TABLE hcd.atencion
      ADD CONSTRAINT fk_atencion_usuario 
      FOREIGN KEY (documento_id) 
      REFERENCES hcd.usuario (documento_id) 
      ON DELETE CASCADE;
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'fk_diag_atencion'
  ) THEN
    ALTER TABLE hcd.diagnostico
      ADD CONSTRAINT fk_diag_atencion 
      FOREIGN KEY (documento_id, atencion_id) 
      REFERENCES hcd.atencion(documento_id, atencion_id) 
      ON DELETE CASCADE;
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'fk_tec_atencion'
  ) THEN
    ALTER TABLE hcd.tecnologia_salud
      ADD CONSTRAINT fk_tec_atencion 
      FOREIGN KEY (documento_id, atencion_id) 
      REFERENCES hcd.atencion(documento_id, atencion_id) 
      ON DELETE CASCADE;
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'fk_tec_profesional'
  ) THEN
    ALTER TABLE hcd.tecnologia_salud
      ADD CONSTRAINT fk_tec_profesional 
      FOREIGN KEY (id_personal_salud) 
      REFERENCES hcd.profesional_salud(id_personal_salud);
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'fk_atencion_profesional'
  ) THEN
    ALTER TABLE hcd.atencion
      ADD CONSTRAINT fk_atencion_profesional 
      FOREIGN KEY (profesional_responsable) 
      REFERENCES hcd.profesional_salud(id_personal_salud);
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'fk_egreso_atencion'
  ) THEN
    ALTER TABLE hcd.egreso
      ADD CONSTRAINT fk_egreso_atencion 
      FOREIGN KEY (documento_id, atencion_id) 
      REFERENCES hcd.atencion(documento_id, atencion_id) 
      ON DELETE CASCADE;
  END IF;
END $$;

-- 12) Privilegios
GRANT USAGE ON SCHEMA hcd TO public;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA hcd TO public;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA hcd TO public;

-- 13) Verificación final - Se mostrará después de distribuir tablas
SELECT 'Esquema HCD creado exitosamente. Distribución de tablas se hará en el setup.sh' AS status;
