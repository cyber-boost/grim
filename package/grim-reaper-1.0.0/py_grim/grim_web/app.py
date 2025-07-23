"""
Simple FastAPI Web Application for Grim
"""
from fastapi import FastAPI
import time

app = FastAPI(title="Grim Web API")

@app.get("/health")
async def health_check():
    """Health check endpoint"""
    return {
        "status": "healthy",
        "timestamp": time.time(),
        "version": "1.0.0"
    }

@app.get("/")
async def root():
    """Root endpoint"""
    return {"message": "Grim Web API is operational"}