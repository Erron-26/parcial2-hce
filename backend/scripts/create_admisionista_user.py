#!/usr/bin/env python3
"""
Script para crear un usuario de prueba con rol de ADMISIONISTA.

Crea usuario admisionista con credenciales:
- Email: admisionista@hce.com
- Contraseña: password123
- Documento: 3000000001
- Rol: admisionista
"""

import sys
from pathlib import Path

# Agregar el directorio padre al path
sys.path.insert(0, str(Path(__file__).resolve().parent.parent.parent))

from backend.db.session import SessionLocal
from backend.db import models
from backend.core.security import get_password_hash


def create_admisionista_user():
    """Crea un usuario admisionista de prueba en la base de datos."""
    db = SessionLocal()
    
    try:
        # Verificar si el usuario ya existe
        email = "admisionista@hce.com"
        existing = db.query(models.Usuario).filter(
            models.Usuario.correo_electronico == email
        ).first()
        
        if existing:
            print(f"✓ Usuario {email} ya existe")
            db.close()
            return True
        
        # Crear nuevo usuario
        admisionista_user = models.Usuario(
            documento_id=3000000001,
            correo_electronico=email,
            hashed_password=get_password_hash("password123"),
            primer_nombre="Admisionista",
            primer_apellido="HCE",
            tipo_usuario="admisionista", # Rol específico
        )
        
        db.add(admisionista_user)
        db.commit()
        
        print("✓ Usuario ADMISIONISTA de prueba creado exitosamente")
        print(f"  Email: {email}")
        print(f"  Contraseña: password123")
        print(f"  Rol: admisionista")
        
        db.close()
        return True
        
    except Exception as e:
        print(f"✗ Error al crear usuario admisionista: {e}")
        db.rollback()
        db.close()
        return False


if __name__ == "__main__":
    success = create_admisionista_user()
    sys.exit(0 if success else 1)
