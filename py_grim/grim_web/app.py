"""
Simple FastAPI Web Application for Grim with TuskLang Integration
"""
from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
import time
import logging

from grim_core.tusktsk import get_tusk_integration
from .tusktsk_routes import router as tusktsk_router

# Initialize TuskLang integration
tusk_integration = get_tusk_integration()

app = FastAPI(
    title="Grim Web API with TuskLang Integration",
    description="Grim web application with integrated TuskLang configuration system",
    version="1.0.0"
)

# Add CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include TuskLang routes
app.include_router(tusktsk_router)

@app.get("/health")
async def health_check():
    """Health check endpoint"""
    tusk_status = tusk_integration.get_tusk_status()
    return {
        "status": "healthy",
        "timestamp": time.time(),
        "version": "1.0.0",
        "tusk_integration": tusk_status
    }

@app.get("/")
async def root():
    """Root endpoint"""
    return {
        "message": "Grim Web API is operational with TuskLang integration",
        "tusk_available": tusk_integration.is_tusk_available(),
        "endpoints": {
            "health": "/health",
            "tusk_status": "/tusktsk/status",
            "tusk_info": "/tusktsk/info",
            "tusk_health": "/tusktsk/health",
            "config": "/tusktsk/config/{section}",
            "function": "/tusktsk/function",
            "operator": "/tusktsk/operator"
        }
    }

@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    """Global exception handler"""
    logging.error(f"Unhandled exception: {exc}")
    return JSONResponse(
        status_code=500,
        content={
            "error": "Internal server error",
            "message": str(exc),
            "timestamp": time.time()
        }
    )