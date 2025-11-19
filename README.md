# Arquitectura y Diseño de Sistemas Distribuidos Seguros para la Gestión de Historias Clínicas Electrónicas

## Resumen

Este proyecto implementa un sistema distribuido de historia clínica electrónica (HCE) diseñado para la gestión segura, eficiente y escalable de datos de pacientes. La arquitectura se basa en microservicios y tecnologías de código abierto, con un backend en Python (FastAPI), una base de datos distribuida PostgreSQL + Citus, y un despliegue orquestado sobre Kubernetes (Minikube).

El sistema ofrece una solución robusta para la interoperabilidad en el sector salud, permitiendo el acceso a la información desde diferentes dispositivos y roles de usuario, y garantizando la integridad y confidencialidad de los datos mediante un sólido sistema de autenticación y autorización basado en OAuth2 y JWT.

## Características Principales

-   **Base de Datos Distribuida:** Utiliza PostgreSQL con la extensión Citus para fragmentar y distribuir las tablas a lo largo de un clúster, permitiendo una alta escalabilidad y rendimiento en las consultas.
-   **Middleware y API REST:** Un backend desarrollado en FastAPI que sirve como intermediario entre los clientes y la base de datos, exponiendo una API RESTful para todas las operaciones.
-   **Interfaces de Usuario por Rol:** Cuatro interfaces gráficas interactivas diseñadas a medida para los roles de:
    -   **Paciente:** Consulta de su propia historia clínica.
    -   **Admisionista:** Gestión de datos demográficos de los pacientes.
    -   **Médico:** Acceso y registro de información clínica en las atenciones.
    -   **Dashboard/Resultados:** Vista general de la actividad del sistema.
-   **Seguridad Integral:**
    -   **Autenticación:** Implementación del flujo de autorización OAuth2 para un inicio de sesión seguro.
    -   **Autorización:** Uso de JSON Web Tokens (JWT) para proteger las rutas y garantizar que los usuarios solo accedan a los recursos permitidos para su rol.
-   **Exportación Segura de PDFs:** Generación de documentos PDF con la historia clínica de un paciente, una funcionalidad protegida que solo usuarios autenticados y autorizados pueden utilizar.
-   **Despliegue Automatizado en Kubernetes:** Todo el sistema, desde la base de datos hasta el middleware, está containerizado con Docker y se despliega de forma automatizada en un clúster de Kubernetes.

## Arquitectura del Sistema

El sistema sigue una arquitectura de microservicios distribuida, diseñada para ser resiliente y escalable.

1.  **Capa de Orquestación (Kubernetes):** Orquesta todos los componentes del sistema, gestionando los despliegues, servicios y la red interna.
2.  **Capa de Datos (PostgreSQL + Citus):** Un clúster de base de datos compuesto por:
    -   Un **nodo coordinador**, que gestiona los metadatos de la distribución y enruta las consultas.
    -   Dos **nodos trabajadores**, que almacenan los fragmentos de datos (shards).
3.  **Capa de Lógica de Negocio (FastAPI Middleware):** La aplicación principal escrita en Python, que contiene la lógica de negocio, se conecta a la base de datos y sirve la API REST y las interfaces de usuario.
4.  **Capa de Presentación (Jinja2 Templates):** Vistas HTML renderizadas del lado del servidor con Jinja2, lo que permite una integración sencilla y rápida con el backend de FastAPI.
5.  **Capa de Seguridad (OAuth2 + JWT):** Integrada en el middleware, gestiona la autenticación de usuarios y la validación de tokens para el control de acceso.

## Stack Tecnológico

| Componente      | Tecnología                                                                                             |
| --------------- | ------------------------------------------------------------------------------------------------------ |
| **Backend**     | Python 3.11, FastAPI, SQLAlchemy, Pydantic, Uvicorn, python-jose, passlib, argon2-cffi                  |
| **Base de Datos** | PostgreSQL, Citus Data                                                                                 |
| **Vistas**      | Jinja2, HTML5, CSS3                                                                                      |
| **PDF**         | WeasyPrint                                                                                             |
| **Infraestructura** | Docker, Kubernetes (Minikube)                                                                          |
| **Scripts**     | Bash                                                                                                   |

## Primeros Pasos: Instalación y Despliegue

Este proyecto incluye un script de automatización (`setup.sh`) que configura todo el entorno de desarrollo local.

### Prerrequisitos

-   **Docker:** Para la construcción de imágenes de contenedor.
-   **Minikube:** Para crear un clúster local de Kubernetes.
-   **kubectl:** Para interactuar con el clúster de Kubernetes.

### Guía de Instalación Automatizada

El script `setup.sh` se encarga de todo el proceso. Para ejecutarlo, abre una terminal y corre el siguiente comando desde la raíz del proyecto:

```bash
bash setup.sh
```

El script realizará los siguientes pasos:
1.  Verificará que Docker y Minikube estén instalados y en ejecución.
2.  Construirá la imagen Docker del middleware y la cargará en el entorno de Minikube.
3.  Desplegará todos los recursos de Kubernetes definidos en `infra/k8s/`, incluyendo el clúster de Citus (coordinador y workers) y la aplicación FastAPI.
4.  Esperará a que todos los componentes estén listos y saludables.
5.  Configurará la base de datos: creará las tablas, registrará los workers en el coordinador y distribuirá las tablas.
6.  Opcionalmente, te preguntará si deseas insertar datos de prueba.
7.  Generará un archivo `backend/.env` con las credenciales de conexión a la base de datos.
8.  Al finalizar, te proporcionará la URL para acceder a la aplicación.

## Ejecutando la Aplicación

Una vez que el script `setup.sh` ha finalizado, la aplicación estará disponible en la URL que se muestra en la terminal. Típicamente será algo como:

`http://<IP_DE_MINIKUBE>:<PUERTO_ASIGNADO>`

### Creación de Usuarios de Prueba

Para poder interactuar con la aplicación, necesitas crear usuarios con diferentes roles. Puedes hacerlo ejecutando los scripts de Python que se encuentran en `backend/scripts/`:

```bash
# Activa tu entorno virtual si lo tienes
# source venv/bin/activate

# Crea los usuarios (ejecuta desde la raíz del proyecto)
python3 backend/scripts/create_admisionista_user.py
python3 backend/scripts/create_medico_user.py
python3 backend/scripts/create_test_user.py
```

## Acceso Remoto para Presentaciones

El script `remote_access.sh` facilita el acceso a la aplicación desde otros dispositivos en la misma red local (por ejemplo, un teléfono móvil para una demostración).

Para usarlo, ejecútalo con:

```bash
bash remote_access.sh
```

El script:
1.  Detectará la IP local de tu máquina.
2.  Abrirá temporalmente el puerto necesario en el firewall de tu sistema operativo.
3.  Mostrará una **URL y un código QR** que puedes escanear con tu teléfono para acceder directamente a la página de login.
4.  Creará un túnel `kubectl port-forward` para redirigir el tráfico del puerto local a la aplicación dentro de Minikube.

**Importante:** Cuando termines tu presentación, simplemente presiona `Ctrl+C` en la terminal donde se ejecuta el script. Este se encargará de cerrar el túnel y la regla del firewall automáticamente, dejando tu sistema seguro.

## Estructura del Proyecto

```
.
├── backend/            # Código fuente del middleware FastAPI
│   ├── core/           # Configuración principal y seguridad
│   ├── db/             # Modelos SQLAlchemy y sesión de BD
│   ├── schemas.py      # Esquemas Pydantic para validación
│   ├── templates/      # Plantillas HTML de Jinja2
│   ├── app.py          # Aplicación principal FastAPI
│   ├── Dockerfile      # Define la imagen del backend
│   └── requirements.txt# Dependencias de Python
├── infra/              # Configuración de infraestructura
│   ├── k8s/            # Archivos YAML de Kubernetes para despliegues
│   ├── init.sql        # Script de inicialización de la BD
│   └── load_sample_data.sql # Datos de prueba
├── venv/               # Entorno virtual de Python
├── remote_access.sh    # Script para acceso remoto y presentaciones
├── setup.sh            # Script de instalación automatizada
└── README.md           # Este archivo
```

## Seguridad

-   **OAuth2 Password Flow:** La autenticación se maneja mediante el flujo "Password Flow" de OAuth2, donde el usuario envía sus credenciales y recibe un `access_token`.
-   **JWT Tokens:** El `access_token` es un JWT que contiene información del usuario (como su rol). Este token debe ser enviado en la cabecera `Authorization` de cada petición a rutas protegidas.
-   **Hashing de Contraseñas:** Las contraseñas se almacenan de forma segura en la base de datos utilizando el algoritmo **Argon2**, gracias a la librería `passlib`.
-   **CORS:** Configurado para permitir peticiones solo desde los orígenes esperados.

¡Gracias por usar nuestro sistema!