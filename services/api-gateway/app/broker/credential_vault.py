"""Credential vault: Fernet encryption for broker credentials."""

from __future__ import annotations

import base64
import hashlib
import json
import logging
import os

from cryptography.fernet import Fernet, InvalidToken

logger = logging.getLogger(__name__)


def _get_key() -> bytes:
    """Return the Fernet key used to encrypt/decrypt credentials.

    Reads CREDENTIAL_VAULT_KEY from the environment. If not set, falls back
    to a deterministic development-only key derived from a fixed seed.
    """
    key = os.environ.get("CREDENTIAL_VAULT_KEY")
    if key:
        return key.encode()
    logger.warning(
        "CREDENTIAL_VAULT_KEY is not set; using a deterministic "
        "development-only fallback key. Do NOT use this in production."
    )
    return base64.urlsafe_b64encode(
        hashlib.sha256(b"aegis-dev-credential-key").digest()
    )


def encrypt_credentials(data: dict) -> bytes:
    """Serialize a credential dict to JSON and encrypt it with Fernet."""
    payload = json.dumps(data).encode()
    return Fernet(_get_key()).encrypt(payload)


def decrypt_credentials(encrypted: bytes) -> dict:
    """Decrypt a Fernet-encrypted credential blob back into a dict."""
    try:
        payload = Fernet(_get_key()).decrypt(encrypted)
    except InvalidToken as exc:
        raise ValueError(
            "Failed to decrypt credentials — wrong key or corrupted data"
        ) from exc
    return json.loads(payload)
