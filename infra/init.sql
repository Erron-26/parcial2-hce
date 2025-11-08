-- init_extended.sql
-- Inicialización ampliada del esquema 'hcd' para el parcial
-- Diseñado para PostgreSQL + Citus (distribución por documento_id / atencion_id)
-- NOTA: ejecutar esto en el POD coordinador (psql). El script es idempotente en la mayoría de objetos.

-- 0) Crear la base de datos si no existe (robusto en psql)
DO $$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_database WHERE datname = 'interop_db') THEN
    PERFORM dblink_exec('dbname=postgres', $$CREATE DATABASE interop_db$$);
  END IF;
EXCEPTION WHEN undefined_function THEN
  -- dblink_exec puede no estar disponible; intentar crear de forma simple y capturar error
  BEGIN
    CREATE DATABASE interop_db;
  EXCEPTION WHEN others THEN
    RAISE NOTICE 'CREATE DATABASE interop_db falló o ya existe: %', SQLERRM;
  END;
END;
$$ LANGUAGE plpgsql;

-- Conectar a la base de datos (si estás en psql esto funcionará)
\connect interop_db

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

-- 4) Tabla profesional_salud
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

-- 5) Tabla atencion: datos administrativos y clínicos por episodio
CREATE TABLE IF NOT EXISTS hcd.atencion (
  atencion_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
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
  profesional_responsable UUID REFERENCES hcd.profesional_salud(id_personal_salud),
  firma_paciente_path TEXT,
  fecha_hora_cierre TIMESTAMP WITH TIME ZONE,
  responsable_registro VARCHAR(120),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

COMMENT ON TABLE hcd.atencion IS 'Tabla con datos administrativos y clínicos por episodio de atención';

-- 6) FK lógico entre atencion y usuario (se puede usar como constraint)
ALTER TABLE IF EXISTS hcd.atencion
  ADD CONSTRAINT IF NOT EXISTS fk_atencion_usuario FOREIGN KEY (documento_id) REFERENCES hcd.usuario (documento_id) ON DELETE CASCADE;

-- Índices de consulta rápida
CREATE INDEX IF NOT EXISTS idx_atencion_doc_fecha ON hcd.atencion (documento_id, fecha_hora_atencion);
CREATE INDEX IF NOT EXISTS idx_atencion_estado_egreso ON hcd.atencion (estado_egreso);

-- 7) Tabla diagnostico (por atencion)
CREATE TABLE IF NOT EXISTS hcd.diagnostico (
  diagnostico_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  atencion_id UUID NOT NULL,
  tipo_diagnostico VARCHAR(80),
  diagnostico_text TEXT,
  codigo_cie10 VARCHAR(30),
  gravedad VARCHAR(50),
  registro_medico JSONB,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  CONSTRAINT fk_diag_atencion FOREIGN KEY (atencion_id) REFERENCES hcd.atencion(atencion_id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_diag_atencion ON hcd.diagnostico (atencion_id);

-- 8) Tabla tecnologia_salud (medicamentos/procedimientos aplicados)
CREATE TABLE IF NOT EXISTS hcd.tecnologia_salud (
  tecnologia_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  atencion_id UUID NOT NULL,
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
  CONSTRAINT fk_tec_atencion FOREIGN KEY (atencion_id) REFERENCES hcd.atencion(atencion_id) ON DELETE CASCADE,
  CONSTRAINT fk_tec_profesional FOREIGN KEY (id_personal_salud) REFERENCES hcd.profesional_salud(id_personal_salud)
);

CREATE INDEX IF NOT EXISTS idx_tec_atencion ON hcd.tecnologia_salud (atencion_id);

-- 9) Tabla egreso (resumen de salida)
CREATE TABLE IF NOT EXISTS hcd.egreso (
  egreso_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  atencion_id UUID NOT NULL,
  estado_egreso VARCHAR(80),
  causas_egreso TEXT,
  recomendaciones_al_egreso TEXT,
  fecha_egreso TIMESTAMP WITH TIME ZONE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  CONSTRAINT fk_egreso_atencion FOREIGN KEY (atencion_id) REFERENCES hcd.atencion(atencion_id) ON DELETE CASCADE
);

-- 10) Triggers para actualizar updated_at en tablas principales
CREATE OR REPLACE FUNCTION hcd.trigger_set_timestamp()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_usuario_updated_at ON hcd.usuario;
CREATE TRIGGER trg_usuario_updated_at BEFORE UPDATE ON hcd.usuario FOR EACH ROW EXECUTE FUNCTION hcd.trigger_set_timestamp();

DROP TRIGGER IF EXISTS trg_atencion_updated_at ON hcd.atencion;
CREATE TRIGGER trg_atencion_updated_at BEFORE UPDATE ON hcd.atencion FOR EACH ROW EXECUTE FUNCTION hcd.trigger_set_timestamp();

-- 11) Distribuir tablas con Citus (ejecutar en el coordinator)
-- Se recomienda ejecutar las líneas siguientes en el coordinador, una vez que los workers estén añadidos.
SELECT create_distributed_table('hcd.usuario', 'documento_id');
SELECT create_distributed_table('hcd.atencion', 'documento_id');
SELECT create_distributed_table('hcd.diagnostico', 'atencion_id');
SELECT create_distributed_table('hcd.tecnologia_salud', 'atencion_id');
SELECT create_distributed_table('hcd.profesional_salud', 'id_personal_salud');
SELECT create_distributed_table('hcd.egreso', 'atencion_id');

-- 12) Datos de prueba mínimos (INSERT)
INSERT INTO hcd.usuario(documento_id, tipo_documento, primer_apellido, primer_nombre, fecha_nacimiento, sexo, correo_electronico)
VALUES (1001001001,'CC','Reyes','Jaider','1990-05-12','M','jaider@example.com')
ON CONFLICT (documento_id) DO NOTHING;

INSERT INTO hcd.atencion(documento_id, fecha_hora_atencion, tipo_atencion, motivo_consulta, signos_vitales, estado_egreso)
VALUES (1001001001, now(), 'consulta externa', 'Dolor de cabeza', jsonb_build_object('ta','120/80','fc',72,'fr',16,'temp',36.6,'sat',98,'peso',70,'talla',1.75,'imc',22.9), 'activo')
RETURNING atencion_id;

-- 13) Privilegios (ejemplo mínimo)
GRANT USAGE ON SCHEMA hcd TO public;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA hcd TO public;