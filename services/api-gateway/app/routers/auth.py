"""Authentication endpoints: login and platform admin bootstrap."""
from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.auth import create_access_token, hash_password, verify_password
from app.audit import record_audit
from app.database import get_db
from app.models import User
from app.schemas import BootstrapRequest, LoginRequest, TokenResponse

router = APIRouter(prefix="/auth", tags=["auth"])


@router.post("/login", response_model=TokenResponse)
def login(body: LoginRequest, db: Session = Depends(get_db)):
    """Authenticate a user and return a JWT."""
    user = db.query(User).filter(User.email == body.email).first()
    if not user or not verify_password(body.password, user.password_hash):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid credentials")
    if not user.is_active:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Account disabled")

    token = create_access_token(user.id, user.tenant_id, user.role)
    record_audit(db, action="user_login", tenant_id=user.tenant_id, user_id=user.id)
    db.commit()
    return TokenResponse(access_token=token)


@router.post("/bootstrap", response_model=TokenResponse, status_code=status.HTTP_201_CREATED)
def bootstrap(body: BootstrapRequest, db: Session = Depends(get_db)):
    """Create the first platform admin. Only works when no users exist."""
    if db.query(User).first() is not None:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Platform already bootstrapped")

    admin = User(
        email=body.email,
        password_hash=hash_password(body.password),
        role="PLATFORM_ADMIN",
        tenant_id=None,
    )
    db.add(admin)
    db.flush()

    record_audit(db, action="platform_bootstrap", user_id=admin.id)
    db.commit()

    token = create_access_token(admin.id, None, admin.role)
    return TokenResponse(access_token=token)