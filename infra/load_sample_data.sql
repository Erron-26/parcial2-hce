-- datos_prueba.sql
-- Datos de prueba realistas para HCD (Historia Clínica Digital)
-- Basado en normativa colombiana

-- ============================================
-- 1. PROFESIONALES DE SALUD (10 profesionales)
-- ============================================
INSERT INTO hcd.profesional_salud (nombre_completo, tipo_profesional, registro_profesional, cargo_servicio, contacto) VALUES
('Dr. Carlos Mendoza Pérez', 'Médico General', 'RM-45231', 'Médico Urgencias', '{"telefono": "3001234567", "email": "cmendoza@hospital.com"}'::jsonb),
('Dra. María Fernanda Ruiz', 'Médico Internista', 'RM-38492', 'Médico Hospitalización', '{"telefono": "3009876543", "email": "mruiz@hospital.com"}'::jsonb),
('Dr. Jorge Iván Castro', 'Médico Cirujano', 'RM-29384', 'Cirugía General', '{"telefono": "3012345678", "email": "jcastro@hospital.com"}'::jsonb),
('Dra. Ana Lucía Gómez', 'Médico Pediatra', 'RM-51023', 'Pediatría', '{"telefono": "3015678901", "email": "agomez@hospital.com"}'::jsonb),
('Dr. Luis Fernando Torres', 'Médico Cardiólogo', 'RM-42876', 'Cardiología', '{"telefono": "3018765432", "email": "ltorres@hospital.com"}'::jsonb),
('Enf. Sandra Milena López', 'Enfermera Jefe', 'RE-18273', 'Jefe Enfermería Urgencias', '{"telefono": "3007654321", "email": "slopez@hospital.com"}'::jsonb),
('Dra. Patricia Vargas', 'Médico Ginecóloga', 'RM-36451', 'Ginecología', '{"telefono": "3013456789", "email": "pvargas@hospital.com"}'::jsonb),
('Dr. Andrés Felipe Rojas', 'Médico Neurólogo', 'RM-47892', 'Neurología', '{"telefono": "3019876543", "email": "arojas@hospital.com"}'::jsonb),
('Dra. Clara Inés Martínez', 'Médico Dermatóloga', 'RM-32145', 'Dermatología', '{"telefono": "3006543210", "email": "cmartinez@hospital.com"}'::jsonb),
('Dr. Roberto Sánchez Díaz', 'Médico Traumatólogo', 'RM-39876', 'Ortopedia', '{"telefono": "3011234567", "email": "rsanchez@hospital.com"}'::jsonb)
ON CONFLICT DO NOTHING;

-- ============================================
-- 2. PACIENTES (20 usuarios)
-- ============================================
INSERT INTO hcd.usuario (documento_id, tipo_documento, primer_apellido, segundo_apellido, primer_nombre, segundo_nombre, 
                        fecha_nacimiento, edad, sexo, genero, grupo_sanguineo, factor_rh, estado_civil, 
                        direccion_residencia, municipio_ciudad, departamento, telefono, celular, correo_electronico,
                        ocupacion, entidad_afiliacion, regimen_afiliacion, tipo_usuario, hashed_password) VALUES
(1001001001, 'CC', 'García', 'Rodríguez', 'Juan', 'Carlos', '1985-03-15', 39, 'M', 'Masculino', 'O', '+', 'Casado', 
 'Cra 15 #23-45', 'Sincelejo', 'Sucre', '2821234', '3001234567', 'jgarcia@email.com', 
 'Ingeniero', 'NUEVA EPS', 'Contributivo', 'paciente', '$argon2id$v=19$m=65536,t=3,p=4$f2+NMaYUAoAwRujd29v7fw$tjXZRNcGOT+tf7pahnfnEvDbaIF9V+ep2lNhD4AZjcI'),

(1001001002, 'CC', 'Martínez', 'López', 'María', 'Fernanda', '1992-07-22', 32, 'F', 'Femenino', 'A', '+', 'Soltera', 
 'Calle 18 #12-34', 'Sincelejo', 'Sucre', '2825678', '3109876543', 'mmartinez@email.com', 
 'Docente', 'SANITAS', 'Contributivo', 'paciente', '$argon2id$v=19$m=65536,t=3,p=4$f2+NMaYUAoAwRujd29v7fw$tjXZRNcGOT+tf7pahnfnEvDbaIF9V+ep2lNhD4AZjcI'),

(1001001003, 'CC', 'Pérez', 'Gómez', 'Carlos', 'Alberto', '1978-11-08', 46, 'M', 'Masculino', 'B', '+', 'Casado', 
 'Calle 25 #8-90', 'Sincelejo', 'Sucre', '2823456', '3201234567', 'cperez@email.com', 
 'Comerciante', 'SALUD TOTAL', 'Contributivo', 'paciente', '$argon2id$v=19$m=65536,t=3,p=4$f2+NMaYUAoAwRujd29v7fw$tjXZRNcGOT+tf7pahnfnEvDbaIF9V+ep2lNhD4AZjcI'),

(1001001004, 'CC', 'Rodríguez', 'Castro', 'Ana', 'María', '1995-05-30', 29, 'F', 'Femenino', 'AB', '+', 'Unión Libre', 
 'Cra 20 #15-67', 'Sincelejo', 'Sucre', '2829876', '3156789012', 'arodriguez@email.com', 
 'Enfermera', 'SURA', 'Contributivo', 'paciente', '$argon2id$v=19$m=65536,t=3,p=4$f2+NMaYUAoAwRujd29v7fw$tjXZRNcGOT+tf7pahnfnEvDbaIF9V+ep2lNhD4AZjcI'),

(1001001005, 'CC', 'Hernández', 'Díaz', 'Luis', 'Eduardo', '1965-09-12', 59, 'M', 'Masculino', 'O', '-', 'Casado', 
 'Calle 30 #22-11', 'Sincelejo', 'Sucre', '2827890', '3008765432', 'lhernandez@email.com', 
 'Pensionado', 'ALIANSALUD', 'Subsidiado', 'paciente', '$argon2id$v=19$m=65536,t=3,p=4$f2+NMaYUAoAwRujd29v7fw$tjXZRNcGOT+tf7pahnfnEvDbaIF9V+ep2lNhD4AZjcI'),

(1001001006, 'TI', 'González', 'Torres', 'Sofía', 'Valentina', '2010-02-14', 14, 'F', 'Femenino', 'A', '+', 'Soltero', 
 'Cra 12 #18-45', 'Sincelejo', 'Sucre', '2824567', '3187654321', 'sgonzalez@email.com', 
 'Estudiante', 'COOSALUD', 'Subsidiado', 'paciente', '$argon2id$v=19$m=65536,t=3,p=4$f2+NMaYUAoAwRujd29v7fw$tjXZRNcGOT+tf7pahnfnEvDbaIF9V+ep2lNhD4AZjcI'),

(1001001007, 'CC', 'Ramírez', 'Vargas', 'Diego', 'Fernando', '1988-12-03', 36, 'M', 'Masculino', 'B', '-', 'Divorciado', 
 'Calle 40 #9-23', 'Sincelejo', 'Sucre', '2826543', '3012345678', 'dramirez@email.com', 
 'Abogado', 'COMPENSAR', 'Contributivo', 'paciente', '$argon2id$v=19$m=65536,t=3,p=4$f2+NMaYUAoAwRujd29v7fw$tjXZRNcGOT+tf7pahnfnEvDbaIF9V+ep2lNhD4AZjcI'),

(1001001008, 'CC', 'López', 'Sánchez', 'Carolina', NULL, '1990-08-19', 34, 'F', 'Femenino', 'O', '+', 'Casada', 
 'Cra 8 #14-56', 'Sincelejo', 'Sucre', '2822345', '3198765432', 'clopez@email.com', 
 'Contadora', 'FAMISANAR', 'Contributivo', 'paciente', '$argon2id$v=19$m=65536,t=3,p=4$f2+NMaYUAoAwRujd29v7fw$tjXZRNcGOT+tf7pahnfnEvDbaIF9V+ep2lNhD4AZjcI'),

(1001001009, 'CC', 'Morales', 'Reyes', 'Pedro', 'José', '1972-04-25', 52, 'M', 'Masculino', 'A', '-', 'Viudo', 
 'Calle 35 #20-12', 'Sincelejo', 'Sucre', '2828901', '3006543210', 'pmorales@email.com', 
 'Agricultor', 'MUTUAL SER', 'Subsidiado', 'paciente', '$argon2id$v=19$m=65536,t=3,p=4$f2+NMaYUAoAwRujd29v7fw$tjXZRNcGOT+tf7pahnfnEvDbaIF9V+ep2lNhD4AZjcI'),

(1001001010, 'CC', 'Castro', 'Mendoza', 'Laura', 'Isabel', '1998-06-17', 26, 'F', 'Femenino', 'AB', '-', 'Soltera', 
 'Cra 5 #11-78', 'Sincelejo', 'Sucre', '2825432', '3171234567', 'lcastro@email.com', 
 'Psicóloga', 'SANITAS', 'Contributivo', 'paciente', '$argon2id$v=19$m=65536,t=3,p=4$f2+NMaYUAoAwRujd29v7fw$tjXZRNcGOT+tf7pahnfnEvDbaIF9V+ep2lNhD4AZjcI'),

(1001001011, 'CC', 'Torres', 'Gutiérrez', 'Roberto', 'Antonio', '1982-01-28', 42, 'M', 'Masculino', 'O', '+', 'Casado', 
 'Calle 22 #16-34', 'Sincelejo', 'Sucre', '2823210', '3009876543', 'rtorres@email.com', 
 'Mecánico', 'NUEVA EPS', 'Contributivo', 'paciente', '$argon2id$v=19$m=65536,t=3,p=4$f2+NMaYUAoAwRujd29v7fw$tjXZRNcGOT+tf7pahnfnEvDbaIF9V+ep2lNhD4AZjcI'),

(1001001012, 'CC', 'Ruiz', 'Pardo', 'Claudia', 'Patricia', '1987-10-11', 37, 'F', 'Femenino', 'B', '+', 'Unión Libre', 
 'Cra 18 #25-67', 'Sincelejo', 'Sucre', '2827654', '3134567890', 'cruiz@email.com', 
 'Fisioterapeuta', 'SURA', 'Contributivo', 'paciente', '$argon2id$v=19$m=65536,t=3,p=4$f2+NMaYUAoAwRujd29v7fw$tjXZRNcGOT+tf7pahnfnEvDbaIF9V+ep2lNhD4AZjcI'),

(1001001013, 'CC', 'Jiménez', 'Rojas', 'Andrés', 'Felipe', '1993-03-07', 31, 'M', 'Masculino', 'A', '+', 'Soltero', 
 'Calle 28 #19-23', 'Sincelejo', 'Sucre', '2824321', '3201234567', 'ajimenez@email.com', 
 'Programador', 'SALUD TOTAL', 'Contributivo', 'paciente', '$argon2id$v=19$m=65536,t=3,p=4$f2+NMaYUAoAwRujd29v7fw$tjXZRNcGOT+tf7pahnfnEvDbaIF9V+ep2lNhD4AZjcI'),

(1001001014, 'CC', 'Vargas', 'Herrera', 'Paola', 'Andrea', '1991-11-29', 33, 'F', 'Femenino', 'O', '-', 'Casada', 
 'Cra 10 #13-45', 'Sincelejo', 'Sucre', '2826789', '3189876543', 'pvargas@email.com', 
 'Arquitecta', 'COMPENSAR', 'Contributivo', 'paciente', '$argon2id$v=19$m=65536,t=3,p=4$f2+NMaYUAoAwRujd29v7fw$tjXZRNcGOT+tf7pahnfnEvDbaIF9V+ep2lNhD4AZjcI'),

(1001001015, 'CC', 'Medina', 'Cruz', 'Jorge', 'Luis', '1969-07-04', 55, 'M', 'Masculino', 'B', '-', 'Casado', 
 'Calle 33 #21-90', 'Sincelejo', 'Sucre', '2829012', '3007654321', 'jmedina@email.com', 
 'Conductor', 'ALIANSALUD', 'Subsidiado', 'paciente', '$argon2id$v=19$m=65536,t=3,p=4$f2+NMaYUAoAwRujd29v7fw$tjXZRNcGOT+tf7pahnfnEvDbaIF9V+ep2lNhD4AZjcI'),

(1001001016, 'CC', 'Salazar', 'Ortiz', 'Valentina', NULL, '2000-09-15', 24, 'F', 'Femenino', 'AB', '+', 'Soltera', 
 'Cra 7 #17-12', 'Sincelejo', 'Sucre', '2825678', '3156789012', 'vsalazar@email.com', 
 'Diseñadora Gráfica', 'NUEVA EPS', 'Contributivo', 'paciente', '$argon2id$v=19$m=65536,t=3,p=4$f2+NMaYUAoAwRujd29v7fw$tjXZRNcGOT+tf7pahnfnEvDbaIF9V+ep2lNhD4AZjcI'),

(1001001017, 'CC', 'Navarro', 'Parra', 'Miguel', 'Ángel', '1975-05-20', 49, 'M', 'Masculino', 'A', '+', 'Divorciado', 
 'Calle 45 #24-56', 'Sincelejo', 'Sucre', '2828765', '3012345678', 'mnavarro@email.com', 
 'Chef', 'SANITAS', 'Contributivo', 'paciente', '$argon2id$v=19$m=65536,t=3,p=4$f2+NMaYUAoAwRujd29v7fw$tjXZRNcGOT+tf7pahnfnEvDbaIF9V+ep2lNhD4AZjcI'),

(1001001018, 'CC', 'Ríos', 'Moreno', 'Luz', 'Marina', '1984-12-08', 40, 'F', 'Femenino', 'O', '+', 'Casada', 
 'Cra 16 #28-34', 'Sincelejo', 'Sucre', '2822109', '3198765432', 'lrios@email.com', 
 'Odontóloga', 'SURA', 'Contributivo', 'paciente', '$argon2id$v=19$m=65536,t=3,p=4$f2+NMaYUAoAwRujd29v7fw$tjXZRNcGOT+tf7pahnfnEvDbaIF9V+ep2lNhD4AZjcI'),

(1001001019, 'CC', 'Carrillo', 'Silva', 'Javier', 'Enrique', '1996-04-12', 28, 'M', 'Masculino', 'B', '+', 'Soltero', 
 'Calle 19 #10-78', 'Sincelejo', 'Sucre', '2827890', '3171234567', 'jcarrillo@email.com', 
 'Electricista', 'COOSALUD', 'Subsidiado', 'paciente', '$argon2id$v=19$m=65536,t=3,p=4$f2+NMaYUAoAwRujd29v7fw$tjXZRNcGOT+tf7pahnfnEvDbaIF9V+ep2lNhD4AZjcI'),

(1001001020, 'CC', 'Duarte', 'Aguilar', 'Sandra', 'Milena', '1989-08-23', 35, 'F', 'Femenino', 'A', '-', 'Unión Libre', 
 'Cra 22 #12-90', 'Sincelejo', 'Sucre', '2824567', '3009876543', 'sduarte@email.com', 
 'Veterinaria', 'SALUD TOTAL', 'Contributivo', 'paciente', '$argon2id$v=19$m=65536,t=3,p=4$f2+NMaYUAoAwRujd29v7fw$tjXZRNcGOT+tf7pahnfnEvDbaIF9V+ep2lNhD4AZjcI')
ON CONFLICT (documento_id) DO NOTHING;

-- ============================================
-- 3. ATENCIONES MÉDICAS (30 atenciones variadas)
-- ============================================

-- Atención 1: Consulta por hipertensión
INSERT INTO hcd.atencion (documento_id, fecha_hora_atencion, tipo_atencion, motivo_consulta, enfermedad_actual, 
                         antecedentes_personales, alergias_conocidas, medicamentos_actuales, signos_vitales, 
                         examen_fisico_general, impresion_diagnostica, codigos_cie10, conducta_plan_manejo, 
                         estado_egreso, profesional_responsable)
SELECT 
  1001001001, 
  now() - interval '5 days',
  'Consulta Externa',
  'Control de hipertensión arterial',
  'Paciente con diagnóstico conocido de HTA desde hace 3 años, refiere buen control con medicación actual. Niega cefalea, mareos o visión borrosa.',
  'HTA diagnosticada en 2021. No DM. No dislipidemia.',
  'Penicilina',
  'Losartán 50mg cada 12 horas, Hidroclorotiazida 25mg al día',
  jsonb_build_object('ta','130/85','fc',78,'fr',16,'temp',36.5,'sat',98,'peso',75,'talla',1.70,'imc',25.9),
  'Paciente consciente, orientado. Cardiopulmonar: ruidos cardiacos rítmicos, no soplos. Murmullo vesicular conservado.',
  'Hipertensión arterial esencial controlada',
  ARRAY['I10'],
  'Continuar tratamiento actual. Control en 3 meses. Dieta hiposódica y ejercicio.',
  'Ambulatorio',
  (SELECT id_personal_salud FROM hcd.profesional_salud WHERE nombre_completo = 'Dr. Carlos Mendoza Pérez' LIMIT 1);

-- Atención 2: Urgencia por dolor abdominal
INSERT INTO hcd.atencion (documento_id, fecha_hora_atencion, tipo_atencion, motivo_consulta, enfermedad_actual,
                         signos_vitales, examen_fisico_general, impresion_diagnostica, codigos_cie10,
                         conducta_plan_manejo, estado_egreso, profesional_responsable)
SELECT
  1001001002,
  now() - interval '3 days',
  'Urgencias',
  'Dolor abdominal intenso',
  'Dolor abdominal tipo cólico en cuadrante inferior derecho, de 6 horas de evolución. Náuseas sin vómito. Última menstruación hace 10 días.',
  jsonb_build_object('ta','110/70','fc',88,'fr',18,'temp',37.2,'sat',97,'peso',58,'talla',1.62,'imc',22.1),
  'Abdomen doloroso a la palpación en FID, signo de McBurney positivo. Blumberg positivo. Ruidos intestinales disminuidos.',
  'Apendicitis aguda',
  ARRAY['K35.8'],
  'Hospitalización. Interconsulta a cirugía general. NPO. Líquidos IV. Analgesia.',
  'Hospitalizado',
  (SELECT id_personal_salud FROM hcd.profesional_salud WHERE nombre_completo = 'Dr. Carlos Mendoza Pérez' LIMIT 1);

-- Atención 3: Control pediátrico
INSERT INTO hcd.atencion (documento_id, fecha_hora_atencion, tipo_atencion, motivo_consulta, enfermedad_actual,
                         antecedentes_personales, signos_vitales, examen_fisico_general, impresion_diagnostica,
                         codigos_cie10, conducta_plan_manejo, estado_egreso, profesional_responsable)
SELECT
  1001001006,
  now() - interval '7 days',
  'Consulta Externa',
  'Control de crecimiento y desarrollo',
  'Paciente en buen estado general. Desarrollo psicomotor adecuado para la edad. Esquema de vacunación completo.',
  'RNT. Sin antecedentes patológicos.',
  jsonb_build_object('ta','100/60','fc',90,'fr',20,'temp',36.7,'sat',99,'peso',45,'talla',1.55,'imc',18.7),
  'Paciente en buenas condiciones generales. Desarrollo acorde a edad cronológica. Sin alteraciones al examen físico.',
  'Control de niño sano',
  ARRAY['Z00.1'],
  'Continuar con alimentación balanceada. Próximo control en 6 meses. Refuerzo de vacuna HPV pendiente.',
  'Ambulatorio',
  (SELECT id_personal_salud FROM hcd.profesional_salud WHERE nombre_completo = 'Dra. Ana Lucía Gómez' LIMIT 1);

-- Atención 4: Consulta dermatológica
INSERT INTO hcd.atencion (documento_id, fecha_hora_atencion, tipo_atencion, motivo_consulta, enfermedad_actual,
                         alergias_conocidas, signos_vitales, examen_fisico_general, impresion_diagnostica,
                         codigos_cie10, conducta_plan_manejo, formulacion_medica, estado_egreso, profesional_responsable)
SELECT
  1001001010,
  now() - interval '2 days',
  'Consulta Externa',
  'Lesiones en piel de cara',
  'Lesiones papulares eritematosas en región facial de 2 semanas de evolución. Prurito leve. Sin fiebre.',
  'Ninguna conocida',
  jsonb_build_object('ta','115/75','fc',72,'fr',16,'temp',36.4,'sat',98,'peso',55,'talla',1.65,'imc',20.2),
  'Lesiones eritematosas pápulo-pustulosas en mejillas y frente. No adenopatías.',
  'Acné vulgar moderado',
  ARRAY['L70.0'],
  'Tratamiento tópico y sistémico. Higiene facial adecuada. Evitar manipulación de lesiones. Control en 1 mes.',
  jsonb_build_object(
    'medicamentos', jsonb_build_array(
      jsonb_build_object('nombre', 'Adapaleno gel 0.1%', 'dosis', 'Aplicar en la noche', 'duracion', '30 días'),
      jsonb_build_object('nombre', 'Doxiciclina 100mg', 'dosis', '1 tableta cada 12 horas', 'duracion', '30 días')
    )
  ),
  'Ambulatorio',
  (SELECT id_personal_salud FROM hcd.profesional_salud WHERE nombre_completo = 'Dra. Clara Inés Martínez' LIMIT 1);

-- Atención 5: Urgencia traumatológica
INSERT INTO hcd.atencion (documento_id, fecha_hora_atencion, tipo_atencion, motivo_consulta, enfermedad_actual,
                         signos_vitales, examen_fisico_general, impresion_diagnostica, codigos_cie10,
                         conducta_plan_manejo, procedimientos_realizados, estado_egreso, profesional_responsable)
SELECT
  1001001013,
  now() - interval '1 day',
  'Urgencias',
  'Trauma en tobillo derecho',
  'Paciente refiere caída desde su altura hace 2 horas. Dolor intenso en tobillo derecho. Imposibilidad para la marcha. Edema progresivo.',
  jsonb_build_object('ta','125/80','fc',92,'fr',18,'temp',36.8,'sat',97,'peso',72,'talla',1.75,'imc',23.5),
  'Tobillo derecho con edema ++, equimosis, dolor a la palpación del maléolo lateral. Limitación funcional severa.',
  'Fractura de maléolo lateral derecho',
  ARRAY['S82.6'],
  'Inmovilización con férula. Analgesia. Rx de tobillo AP y lateral. Interconsulta a ortopedia. Reposo relativo con elevación del miembro.',
  'Radiografía de tobillo derecho AP y lateral. Inmovilización con férula posterior.',
  'Hospitalizado',
  (SELECT id_personal_salud FROM hcd.profesional_salud WHERE nombre_completo = 'Dr. Roberto Sánchez Díaz' LIMIT 1);

-- Más atenciones continuadas...
-- Atención 6: Consulta cardiológica
INSERT INTO hcd.atencion (documento_id, fecha_hora_atencion, tipo_atencion, motivo_consulta, enfermedad_actual,
                         antecedentes_personales, medicamentos_actuales, signos_vitales, examen_fisico_general,
                         impresion_diagnostica, codigos_cie10, conducta_plan_manejo, estado_egreso, profesional_responsable)
SELECT
  1001001011,
  now() - interval '4 days',
  'Consulta Externa',
  'Valoración cardiológica por palpitaciones',
  'Episodios de palpitaciones intermitentes desde hace 1 mes. Ocasionalmente asociado a mareo. Sin síncope. Sin dolor precordial.',
  'Tabaquismo hace 5 años. Padre con IAM a los 55 años.',
  'Atorvastatina 20mg/día',
  jsonb_build_object('ta','140/90','fc',88,'fr',16,'temp',36.6,'sat',98,'peso',80,'talla',1.72,'imc',27.0),
  'Ruidos cardiacos rítmicos, taquicárdicos. No soplos. Pulsos periféricos simétricos y sincrónicos.',
  'Taquicardia sinusal. Hipertensión arterial en estudio',
  ARRAY['I49.8', 'I10'],
  'Solicitar EKG, Holter 24 horas, ecocardiograma. Iniciar Bisoprolol. Control con resultados.',
  'Ambulatorio',
  (SELECT id_personal_salud FROM hcd.profesional_salud WHERE nombre_completo = 'Dr. Luis Fernando Torres' LIMIT 1);

-- Atención 7: Control prenatal
INSERT INTO hcd.atencion (documento_id, fecha_hora_atencion, tipo_atencion, motivo_consulta, enfermedad_actual,
                         antecedentes_personales, signos_vitales, examen_fisico_general, impresion_diagnostica,
                         codigos_cie10, conducta_plan_manejo, estado_egreso, profesional_responsable)
SELECT
  1001001018,
  now() - interval '6 days',
  'Consulta Externa',
  'Control prenatal - 28 semanas',
  'Embarazo de 28 semanas por FUR. Movimientos fetales presentes. Sin sangrado. Sin contracciones. Sin pérdida de líquido.',
  'G2P1A0. Parto anterior eutócico sin complicaciones.',
  jsonb_build_object('ta','110/70','fc',76,'fr',16,'temp',36.5,'sat',98,'peso',68,'talla',1.63,'imc',25.6),
  'Altura uterina 26cm. FCF 140 lpm. Situación longitudinal, dorso derecho. Sin edemas. Especuloscopía normal.',
  'Embarazo de 28 semanas sin complicaciones',
  ARRAY['Z34.8'],
  'Sulfato ferroso + ácido fólico. Solicitar ecografía obstétrica, curva de tolerancia glucosa. Control en 4 semanas.',
  'Ambulatorio',
  (SELECT id_personal_salud FROM hcd.profesional_salud WHERE nombre_completo = 'Dra. Patricia Vargas' LIMIT 1);

-- Atención 8: Consulta neurológica
INSERT INTO hcd.atencion (documento_id, fecha_hora_atencion, tipo_atencion, motivo_consulta, enfermedad_actual,
                         antecedentes_personales, signos_vitales, examen_fisico_general, impresion_diagnostica,
                         codigos_cie10, conducta_plan_manejo, formulacion_medica, estado_egreso, profesional_responsable)
SELECT
  1001001003,
  now() - interval '8 days',
  'Consulta Externa',
  'Cefalea recurrente',
  'Cefalea hemicraneal pulsátil de 6 meses de evolución. Episodios 2-3 veces por semana. Fotofobia y fonofobia asociadas. Náuseas ocasionales.',
  'Madre con migraña',
  jsonb_build_object('ta','120/75','fc',70,'fr',14,'temp',36.5,'sat',99,'peso',76,'talla',1.78,'imc',24.0),
  'Paciente álgico. Examen neurológico sin déficit focal. Pares craneales conservados. Fuerza y sensibilidad normales.',
  'Migraña sin aura',
  ARRAY['G43.0'],
  'Manejo agudo con AINEs + antieméticos. Tratamiento profiláctico. Evitar desencadenantes. Diario de cefalea.',
  jsonb_build_object(
    'medicamentos', jsonb_build_array(
      jsonb_build_object('nombre', 'Naproxeno 500mg', 'dosis', '1 tableta en crisis', 'duracion', 'PRN'),
      jsonb_build_object('nombre', 'Propranolol 40mg', 'dosis', '1 tableta cada 12 horas', 'duracion', '3 meses')
    )
  ),
  'Ambulatorio',
  (SELECT id_personal_salud FROM hcd.profesional_salud WHERE nombre_completo = 'Dr. Andrés Felipe Rojas' LIMIT 1);

-- Continuar con más atenciones...
-- Atención 9-15: Casos variados para otros pacientes
INSERT INTO hcd.atencion (documento_id, fecha_hora_atencion, tipo_atencion, motivo_consulta, signos_vitales, 
                         impresion_diagnostica, codigos_cie10, estado_egreso, profesional_responsable)
SELECT
  1001001004,
  now() - interval '10 days',
  'Consulta Externa',
  'Control de diabetes mellitus',
  jsonb_build_object('ta','125/80','fc',74,'fr',16,'temp',36.6,'sat',98,'peso',65,'talla',1.68,'imc',23.0),
  'Diabetes Mellitus tipo 2 controlada',
  ARRAY['E11.9'],
  'Ambulatorio',
  (SELECT id_personal_salud FROM hcd.profesional_salud LIMIT 1 OFFSET 1);

-- Atención 10
INSERT INTO hcd.atencion (documento_id, fecha_hora_atencion, tipo_atencion, motivo_consulta, signos_vitales,
                         impresion_diagnostica, codigos_cie10, estado_egreso, profesional_responsable)
SELECT
  1001001007,
  now() - interval '12 days',
  'Urgencias',
  'Dolor torácico',
  jsonb_build_object('ta','150/95','fc',102,'fr',20,'temp',36.8,'sat',96,'peso',85,'talla',1.75,'imc',27.8),
  'Síndrome coronario agudo en estudio',
  ARRAY['I20.0'],
  'Hospitalizado',
  (SELECT id_personal_salud FROM hcd.profesional_salud WHERE tipo_profesional = 'Médico Internista' LIMIT 1);