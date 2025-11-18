#!/usr/bin/env python3
"""
Script para crear un usuario de prueba con rol de MÉDICO.

Crea usuario médico con credenciales:
- Email: medico@hce.com
- Contraseña: password123
- Documento: 2000000001
- Rol: medico
"""

import sys
from pathlib import Path

# Agregar el directorio padre al path
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from backend.db.session import SessionLocal
from backend.db import models
from backend.core.security import get_password_hash


def create_medico_user():
    """Crea un usuario médico de prueba en la base de datos."""
    db = SessionLocal()
    
    try:
        # Verificar si el usuario ya existe
        email = "medico@hce.com"
        existing = db.query(models.Usuario).filter(
            models.Usuario.correo_electronico == email
        ).first()
        
        if existing:
            print(f"✓ Usuario {email} ya existe")
            db.close()
            return True
        
        # Crear nuevo usuario
        medico_user = models.Usuario(
            documento_id=2000000001,
            correo_electronico=email,
            hashed_password=get_password_hash("password123"),
            primer_nombre="Doctor",
            primer_apellido="Prueba",
            tipo_usuario="medico", # Rol específico
        )
        
        db.add(medico_user)
        db.commit()
        
        print("✓ Usuario MÉDICO de prueba creado exitosamente")
        print(f"  Email: {email}")
        print(f"  Contraseña: password123")
        print(f"  Rol: medico")
        
        db.close()
        return True
        
    except Exception as e:
        print(f"✗ Error al crear usuario médico: {e}")
        db.rollback()
        db.close()
        return False


if __name__ == "__main__":
    success = create_medico_user()
    sys.exit(0 if success else 1)
