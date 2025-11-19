#!/usr/bin/env python3
"""
Script para crear un usuario de prueba en la base de datos HCE.

Crea usuario paciente con credenciales:
- Email: test@hce.com
- Contraseña: password123
- Documento: 1000000001
"""

import sys
from pathlib import Path

# Agregar el directorio padre al path
sys.path.insert(0, str(Path(__file__).resolve().parent.parent.parent))

from backend.db.session import SessionLocal
from backend.db import models
from backend.core.security import get_password_hash


def create_test_user():
    """Crea un usuario de prueba en la base de datos."""
    db = SessionLocal()
    
    try:
        # Verificar si el usuario ya existe
        existing = db.query(models.Usuario).filter(
            models.Usuario.correo_electronico == "test@hce.com"
        ).first()
        
        if existing:
            print("✓ Usuario test@hce.com ya existe")
            print(f"  Documento: {existing.documento_id}")
            print(f"  Email: {existing.correo_electronico}")
            db.close()
            return True
        
        # Crear nuevo usuario
        test_user = models.Usuario(
            documento_id=1000000001,
            correo_electronico="test@hce.com",
            hashed_password=get_password_hash("password123"),
            primer_nombre="Usuario",
            primer_apellido="Test",
            tipo_usuario="paciente",
        )
        
        db.add(test_user)
        db.commit()
        
        print("✓ Usuario de prueba creado exitosamente")
        print(f"  Email: test@hce.com")
        print(f"  Contraseña: password123")
        print(f"  Documento: 1000000001")
        
        db.close()
        return True
        
    except Exception as e:
        print(f"✗ Error al crear usuario: {e}")
        db.rollback()
        db.close()
        return False


if __name__ == "__main__":
    success = create_test_user()
    sys.exit(0 if success else 1)
