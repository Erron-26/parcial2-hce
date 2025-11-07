CREATE SCHEMA IF NOT EXISTS hcd;

CREATE TABLE IF NOT EXISTS hcd.usuario (
  documento_id BIGINT PRIMARY KEY,
  pais_nacionalidad VARCHAR(10),
  nombre_completo VARCHAR(255),
  fecha_nacimiento DATE,
  sexo VARCHAR(10),
  genero VARCHAR(50),
  ocupacion VARCHAR(100)
);

-- en coordinator:
SELECT create_distributed_table('hcd.usuario', 'documento_id');
