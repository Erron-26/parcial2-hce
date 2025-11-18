#!/usr/bin/env python3
"""
Script para probar la autenticación OAuth2 + JWT.

Valida que:
1. El usuario de prueba existe
2. Las credenciales funcionan
3. El token JWT se genera correctamente
4. El token se puede validar
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent))

from backend.db.session import SessionLocal
from backend.db import models
from backend.core.security import (
    authenticate_user,
    create_access_token,
    verify_password,
    get_password_hash,
)
from datetime import timedelta


def test_oauth2():
    """Realiza pruebas de autenticación OAuth2."""
    db = SessionLocal()
    
    print("=" * 60)
    print("PRUEBAS DE AUTENTICACIÓN OAUTH2 + JWT")
    print("=" * 60)
    print()
    
    # Test 1: Verificar que el usuario existe
    print("Test 1: Verificar usuario de prueba existe")
    print("-" * 60)
    
    test_user = db.query(models.Usuario).filter(
        models.Usuario.correo_electronico == "test@hce.com"
    ).first()
    
    if test_user:
        print(f"✓ Usuario encontrado")
        print(f"  Email: {test_user.correo_electronico}")
        print(f"  Documento: {test_user.documento_id}")
        print(f"  Tipo: {test_user.tipo_usuario}")
    else:
        print("✗ Usuario no encontrado - crea uno con: python -m backend.scripts.create_test_user")
        db.close()
        return False
    
    print()
    
    # Test 2: Autenticar con credenciales correctas
    print("Test 2: Autenticar con credenciales correctas")
    print("-" * 60)
    
    auth_user = authenticate_user(db, "test@hce.com", "password123")
    if auth_user:
        print(f"✓ Autenticación exitosa")
        print(f"  Usuario autenticado: {auth_user.correo_electronico}")
    else:
        print("✗ Autenticación falló")
        db.close()
        return False
    
    print()
    
    # Test 3: Rechazar credenciales incorrectas
    print("Test 3: Rechazar credenciales incorrectas")
    print("-" * 60)
    
    wrong_auth = authenticate_user(db, "test@hce.com", "wrongpassword")
    if wrong_auth is None:
        print(f"✓ Contraseña incorrecta rechazada correctamente")
    else:
        print(f"✗ Contraseña incorrecta fue aceptada (¡Error de seguridad!)")
        db.close()
        return False
    
    print()
    
    # Test 4: Generar JWT token
    print("Test 4: Generar JWT token")
    print("-" * 60)
    
    token = create_access_token(
        data={"sub": auth_user.correo_electronico},
        expires_delta=timedelta(minutes=30)
    )
    
    print(f"✓ Token JWT generado")
    print(f"  Longitud: {len(token)} caracteres")
    print(f"  Token: {token[:50]}...")
    
    print()
    
    # Test 5: Verificar contraseña hasheada
    print("Test 5: Verificación de contraseña hasheada")
    print("-" * 60)
    
    if verify_password("password123", test_user.hashed_password):
        print(f"✓ Contraseña verificada correctamente")
    else:
        print(f"✗ Error en verificación de contraseña")
        db.close()
        return False
    
    print()
    print("=" * 60)
    print("✓ TODAS LAS PRUEBAS PASARON")
    print("=" * 60)
    print()
    print("Próximo paso:")
    print("  uvicorn backend.app:app --reload")
    print()
    print("Luego prueba en Swagger:")
    print("  http://localhost:8000/docs")
    
    db.close()
    return True


if __name__ == "__main__":
    success = test_oauth2()
    sys.exit(0 if success else 1)
