# Usamos la versión slim "normal" (Bookworm), que es moderna y estable
FROM python:3.11-slim

WORKDIR /app

# Instalar dependencias del sistema para WeasyPrint y compilación
# (libcairo2 y libpangocairo son las que te faltaban)
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    python3-dev \
    python3-cffi \
    python3-brotli \
    libpango-1.0-0 \
    libpangoft2-1.0-0 \
    libpangocairo-1.0-0 \
    libcairo2 \
    libgdk-pixbuf-2.0-0 \
    libffi-dev \
    shared-mime-info \
    tzdata \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Instalar dependencias de Python
COPY backend/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copiar el código fuente
# NOTA: Copiamos todo el contexto actual al contenedor
COPY . .

# Ajustar PYTHONPATH para que Python encuentre el módulo 'backend'
ENV PYTHONPATH=/app

CMD ["uvicorn", "backend.app:app", "--host", "0.0.0.0", "--port", "8000"]