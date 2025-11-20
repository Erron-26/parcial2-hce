# Arquitectura y Diseño de Sistemas Distribuidos Seguros para la Gestión de Historias Clínicas Electrónicas

## Resumen

Este proyecto implementa un sistema distribuido de historia clínica electrónica (HCE) diseñado para la gestión segura, eficiente y escalable de datos de pacientes. La arquitectura se basa en microservicios y tecnologías de código abierto, con un backend en Python (FastAPI), una base de datos distribuida PostgreSQL + Citus, y un despliegue orquestado sobre Kubernetes (Minikube).

El sistema ofrece una solución robusta para la interoperabilidad en el sector salud, permitiendo el acceso a la información desde diferentes dispositivos y roles de usuario, y garantizando la integridad y confidencialidad de los datos mediante un sólido sistema de autenticación y autorización basado en OAuth2 y JWT.

## Características Principales

-   **Base de Datos Distribuida:** Utiliza PostgreSQL con la extensión Citus para fragmentar y distribuir las tablas a lo largo de un clúster, permitiendo una alta escalabilidad y rendimiento en las consultas.
-   **Middleware y API REST:** Un backend desarrollado en FastAPI que sirve como intermediario entre los clientes y la base de datos, exponiendo una API RESTful para todas las operaciones.
-   **Interfaces de Usuario por Rol:** Interfaces gráficas interactivas, modernas y responsivas diseñadas a medida para los roles de:
    -   **Paciente:** Consulta de su propia historia clínica y exportación de la misma.
    -   **Admisionista:** Creación, búsqueda y actualización de datos demográficos de los pacientes.
    -   **Médico:** Acceso completo al historial del paciente, registro de nuevas atenciones clínicas y exportación de HCE.
-   **Seguridad Integral:**
    -   Autenticación segura basada en el estándar industrial **OAuth2**.
    -   Autorización por roles mediante **JSON Web Tokens (JWT)** para proteger las rutas y los datos.
    -   Almacenamiento seguro de contraseñas con hashing **Argon2**.
-   **Exportación de PDFs:** Generación de documentos PDF con la historia clínica completa y unificada del paciente.
-   **Despliegue Automatizado en Kubernetes:** Todo el sistema está containerizado con Docker y se despliega de forma automatizada en un clúster de Kubernetes local (Minikube) mediante un único script.

## Arquitectura del Sistema

El sistema sigue una arquitectura de microservicios distribuida, diseñada para ser resiliente y escalable.

1.  **Capa de Orquestación (Kubernetes):** Orquesta todos los componentes del sistema, gestionando los despliegues, la persistencia de datos y la red interna.
2.  **Capa de Datos (PostgreSQL + Citus):** Un clúster de base de datos compuesto por un **nodo coordinador** (que enruta las consultas) y múltiples **nodos trabajadores** (que almacenan los fragmentos de datos).
3.  **Capa de Lógica de Negocio (FastAPI Middleware):** La aplicación principal escrita en Python. Contiene la lógica de negocio, se conecta a la base de datos, gestiona la seguridad y sirve tanto la API REST como las interfaces de usuario.
4.  **Capa de Presentación (Jinja2 Templates):** Vistas HTML renderizadas del lado del servidor con Jinja2, lo que permite una integración sencilla y rápida con el backend de FastAPI.

## Stack Tecnológico

| Componente        | Tecnología                                                                       |
| ----------------- | -------------------------------------------------------------------------------- |
| **Backend**       | Python 3.11, FastAPI, SQLAlchemy, Pydantic, Uvicorn, python-jose, passlib, argon2-cffi |
| **Base de Datos**   | PostgreSQL 16, Citus Data                                                        |
| **Vistas**        | Jinja2, HTML5, Bootstrap 5, CSS3                                                 |
| **PDF**           | WeasyPrint                                                                       |
| **Infraestructura** | Docker, Kubernetes (Minikube)                                                    |
| **Scripts**       | Bash                                                                             |

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
3.  Desplegará todos los recursos de Kubernetes definidos en `infra/k8s/`.
4.  Esperará a que todos los componentes estén listos y saludables.
5.  Configurará la base de datos distribuida (creará tablas, registrará workers, etc.).
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
**Credenciales de prueba:**
- **Admisionista:** `admisionista@hce.com` / `password123`
- **Médico:** `medico@hce.com` / `password123`
- **Paciente:** `test@hce.com` / `password123`


## Acceso Remoto para Presentaciones

El script `remote_access.sh` facilita el acceso a la aplicación desde otros dispositivos en la misma red local (por ejemplo, un teléfono móvil para una demostración).

Para usarlo, ejecútalo con:

```bash
bash remote_access.sh
```

El script:
1.  Detectará la IP local de tu máquina.
2.  Abrirá temporalmente el puerto necesario en el firewall de tu sistema operativo.
3.  Creará un túnel `kubectl port-forward` para redirigir el tráfico.
4.  Mostrará una **URL y un código QR** que puedes escanear con tu teléfono para acceder directamente a la página de login.

**Importante:** Cuando termines tu presentación, simplemente presiona `Ctrl+C` en la terminal donde se ejecuta el script. Este se encargará de cerrar el túnel y la regla del firewall automáticamente.

## Estructura del Proyecto

```
.
├── backend/            # Código fuente del middleware FastAPI
│   ├── core/           # Configuración principal y seguridad
│   ├── db/             # Modelos SQLAlchemy y sesión de BD
│   ├── scripts/        # Scripts para crear usuarios de prueba
│   ├── templates/      # Plantillas HTML de Jinja2
│   ├── app.py          # Aplicación principal FastAPI
│   ├── Dockerfile      # Define la imagen del backend
│   └── requirements.txt# Dependencias de Python
├── infra/              # Configuración de infraestructura
│   ├── k8s/            # Archivos YAML de Kubernetes para despliegues
│   ├── init.sql        # Script de inicialización de la BD
│   └── load_sample_data.sql # Datos de prueba
├── remote_access.sh    # Script para acceso remoto y presentaciones
├── setup.sh            # Script de instalación automatizada
└── README.md           # Este archivo
```

## Seguridad

-   **Autenticación:** Se maneja mediante el flujo "Password Flow" de OAuth2, donde el usuario envía sus credenciales y recibe un `access_token` almacenado en una cookie `HttpOnly`.
-   **Autorización:** El `access_token` es un JWT que contiene el rol del usuario. Es validado en cada petición a rutas protegidas para garantizar el control de acceso adecuado.
-   **Hashing de Contraseñas:** Las contraseñas se almacenan de forma segura en la base de datos utilizando el algoritmo **Argon2**.

¡Gracias por usar nuestro sistema!
