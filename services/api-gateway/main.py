"""Aegis Trader - API Gateway service."""

from fastapi import FastAPI

app = FastAPI(title="Aegis Trader API", version="0.1.0")


@app.get("/health")
async def health():
    return {"status": "ok"}
