-- load_sample_data.sql
-- Inserta datos de prueba: 10 usuarios, 5 profesionales, ~20 atenciones, diagnósticos y medicaciones

-- Profesionales
INSERT INTO hcd.profesional_salud(id_personal_salud, nombre_completo, tipo_profesional, registro_profesional, cargo_servicio)
VALUES
  (uuid_generate_v4(), 'Dra. Laura Martinez', 'medico', 'MP-1001', 'Consulta externa'),
  (uuid_generate_v4(), 'Dr. Carlos Pérez', 'medico', 'MP-1002', 'Urgencias'),
  (uuid_generate_v4(), 'Enf. Maria Lopez', 'enfermero', 'ENF-2001', 'Hospitalización'),
  (uuid_generate_v4(), 'Dr. Andres Gomez', 'medico', 'MP-1003', 'Consulta especializada'),
  (uuid_generate_v4(), 'Tecn. Laura Ruiz', 'tecnico', 'TEC-3001', 'Laboratorio')
ON CONFLICT DO NOTHING;

-- Usuarios (pacientes) - 10 ejemplos
INSERT INTO hcd.usuario(documento_id, tipo_documento, primer_apellido, segundo_apellido, primer_nombre, segundo_nombre, fecha_nacimiento, edad, sexo, correo_electronico, municipio_ciudad, departamento)
VALUES
  (1001001001,'CC','Reyes','Herazo','Jaider',NULL,'1990-05-12', 35, 'M','jaider@example.com','Sincelejo','Sucre'),
  (1001001002,'CC','Gomez',NULL,'Ana',NULL,'1985-03-20', 40, 'F','ana@example.com','Cali','Valle'),
  (1001001003,'CC','Lopez','Diaz','Luis',NULL,'1978-11-02', 46, 'M','luis@example.com','Bogota','Cundinamarca'),
  (1001001004,'CC','Martinez','Suarez','Carolina',NULL,'1995-07-15', 28, 'F','caro@example.com','Medellin','Antioquia'),
  (1001001005,'CC','Ramirez',NULL,'Pedro',NULL,'2000-01-10', 24, 'M','pedro@example.com','Cartagena','Bolivar'),
  (1001001006,'CC','Sanchez',NULL,'Lucia',NULL,'1992-08-08', 32, 'F','lucia@example.com','Bucaramanga','Santander'),
  (1001001007,'CC','Torres',NULL,'David',NULL,'1980-12-30', 43, 'M','david@example.com','Pereira','Risaralda'),
  (1001001008,'CC','Vargas',NULL,'Marta',NULL,'1970-04-01', 54, 'F','marta@example.com','Sincelejo','Sucre'),
  (1001001009,'CC','Herrera',NULL,'Andres',NULL,'2003-09-09', 21, 'M','andres@example.com','Neiva','Huila'),
  (1001001010,'CC','Cortes',NULL,'Sandra',NULL,'1988-06-06', 36, 'F','sandra@example.com','Pasto','Nariño')
ON CONFLICT (documento_id) DO NOTHING;

-- Atenciones: 2 por paciente (si existe user), con signos_vitales de ejemplo
DO $$
DECLARE
  doc BIGINT;
  aid UUID;
  prof UUID;
BEGIN
  FOR doc IN SELECT documento_id FROM hcd.usuario LOOP
    -- insertar 2 atenciones por paciente
    INSERT INTO hcd.atencion(documento_id, fecha_hora_atencion, tipo_atencion, motivo_consulta, signos_vitales, estado_egreso, profesional_responsable)
    VALUES (doc, now() - (INTERVAL '10 days'), 'consulta externa', 'Control general', jsonb_build_object('ta','120/80','fc',78,'fr',16,'temp',36.7,'sat',98,'peso',70,'talla',1.7,'imc',24.1), 'activo',
      (SELECT id_personal_salud FROM hcd.profesional_salud ORDER BY random() LIMIT 1)
    );

    INSERT INTO hcd.atencion(documento_id, fecha_hora_atencion, tipo_atencion, motivo_consulta, signos_vitales, estado_egreso, profesional_responsable)
    VALUES (doc, now() - (INTERVAL '3 days'), 'consulta externa', 'Síntomas respiratorios', jsonb_build_object('ta','118/76','fc',82,'fr',18,'temp',37.1,'sat',96,'peso',71,'talla',1.7,'imc',24.6), 'activo',
      (SELECT id_personal_salud FROM hcd.profesional_salud ORDER BY random() LIMIT 1)
    );
  END LOOP;
END;
$$;

-- Diagnósticos asociados a algunas atenciones (aleatorio)
INSERT INTO hcd.diagnostico(atencion_id, tipo_diagnostico, diagnostico_text, codigo_cie10)
SELECT a.atencion_id, 'ingreso', 'Infección respiratoria aguda', 'J06.9'
FROM hcd.atencion a
WHERE a.motivo_consulta ILIKE '%respir%';

-- Tecnología / medicación: aplicar a las atenciones con motivo respiratorio
INSERT INTO hcd.tecnologia_salud(atencion_id, descripcion_medicamento, dosis, via_administracion, frecuencia, dias_tratamiento, unidades_aplicadas, id_personal_salud)
SELECT a.atencion_id, 'Paracetamol 500 mg', '500 mg', 'oral', 'cada 8 horas', 3, 6, (SELECT id_personal_salud FROM hcd.profesional_salud ORDER BY random() LIMIT 1)
FROM hcd.atencion a
WHERE a.motivo_consulta ILIKE '%respir%';

-- Ejemplo: egreso para algunas atenciones
INSERT INTO hcd.egreso(atencion_id, estado_egreso, causas_egreso, recomendaciones_al_egreso, fecha_egreso)
SELECT a.atencion_id, 'mejorado', 'Tratamiento ambulatorio', 'Reposo y control en 3 días', a.fecha_hora_atencion + INTERVAL '1 day'
FROM hcd.atencion a
WHERE a.motivo_consulta ILIKE '%Control general%';

