"""JWT authentication, password hashing, and FastAPI dependencies."""

from __future__ import annotations

import uuid
from datetime import datetime, timedelta, timezone

from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from jose import JWTError, jwt
from passlib.context import CryptContext
from sqlalchemy.orm import Session

from app.config import settings
from app.database import get_db

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")
bearer_scheme = HTTPBearer()

VALID_ROLES = {
    "PLATFORM_ADMIN",
    "TENANT_ADMIN",
    "TRADER",
    "RESEARCHER",
    "RISK_MANAGER",
    "VIEWER",
}
VALID_TENANT_STATUSES = {"ACTIVE", "SUSPENDED", "READ_ONLY", "DISABLED"}
VALID_TRADING_MODES = {"BACKTEST", "REPLAY", "PAPER", "SHADOW", "LIVE"}


def hash_password(password: str) -> str:
    """Hash a plaintext password."""
    return pwd_context.hash(password)


def verify_password(plain: str, hashed: str) -> bool:
    """Verify a plaintext password against a hash."""
    return pwd_context.verify(plain, hashed)


def create_access_token(
    user_id: uuid.UUID, tenant_id: uuid.UUID | None, role: str
) -> str:
    """Create a signed JWT access token."""
    expire = datetime.now(timezone.utc) + timedelta(minutes=settings.jwt_expire_minutes)
    payload = {
        "sub": str(user_id),
        "tenant_id": str(tenant_id) if tenant_id else None,
        "role": role,
        "exp": expire,
    }
    return jwt.encode(payload, settings.jwt_secret, algorithm=settings.jwt_algorithm)


def get_current_user(
    creds: HTTPAuthorizationCredentials = Depends(bearer_scheme),
    db: Session = Depends(get_db),
):
    """FastAPI dependency: decode JWT and return the User row."""
    from app.models import User

    try:
        payload = jwt.decode(
            creds.credentials, settings.jwt_secret, algorithms=[settings.jwt_algorithm]
        )
    except JWTError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid token"
        )

    user_id = payload.get("sub")
    if not user_id:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid token payload"
        )

    user = (
        db.query(User)
        .filter(User.id == uuid.UUID(user_id), User.is_active.is_(True))
        .first()
    )
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="User not found or inactive",
        )
    return user


def require_role(*allowed_roles: str):
    """FastAPI dependency factory: restrict endpoint to specific roles."""

    def checker(current_user=Depends(get_current_user)):
        if current_user.role not in allowed_roles:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN, detail="Insufficient permissions"
            )
        return current_user

    return checker


def require_tenant_access(tenant_id: uuid.UUID, current_user=Depends(get_current_user)):
    """FastAPI dependency: ensure the user belongs to the requested tenant (or is platform admin)."""
    if current_user.role == "PLATFORM_ADMIN":
        return current_user
    if current_user.tenant_id != tenant_id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN, detail="Access denied to this tenant"
        )
    return current_user
