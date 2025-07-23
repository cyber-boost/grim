"""
Simple FastAPI Web Application for Grim with TuskLang Integration
"""
from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
import time
import logging

# Try to import grim_core modules with fallback
try:
    from grim_core.tusktsk import get_tusk_integration
    from grim_web.tusktsk_routes import router as tusktsk_router
    TUSK_AVAILABLE = True
except ImportError as e:
    logging.warning(f"Failed to import TuskLang integration: {e}")
    TUSK_AVAILABLE = False
    tusktsk_router = None

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

# Initialize TuskLang integration with fallback
if TUSK_AVAILABLE:
    try:
        tusk_integration = get_tusk_integration()
        # Include TuskLang routes
        app.include_router(tusktsk_router)
    except Exception as e:
        logging.error(f"Failed to initialize TuskLang integration: {e}")
        tusk_integration = None
else:
    tusk_integration = None

@app.get("/health")
async def health_check():
    """Health check endpoint"""
    if tusk_integration:
        try:
            tusk_status = tusk_integration.get_tusk_status()
        except Exception as e:
            tusk_status = {"error": str(e)}
    else:
        tusk_status = {"status": "unavailable"}
    
    return {
        "status": "healthy",
        "timestamp": time.time(),
        "version": "1.0.0",
        "tusk_integration": tusk_status
    }

@app.get("/")
async def root():
    """Root endpoint"""
    tusk_available = tusk_integration and tusk_integration.is_tusk_available() if tusk_integration else False
    
    return {
        "message": "Grim Web API is operational with TuskLang integration",
        "tusk_available": tusk_available,
        "endpoints": {
            "health": "/health",
            "tusk_status": "/tusktsk/status" if TUSK_AVAILABLE else "unavailable",
            "tusk_info": "/tusktsk/info" if TUSK_AVAILABLE else "unavailable",
            "tusk_health": "/tusktsk/health" if TUSK_AVAILABLE else "unavailable",
            "config": "/tusktsk/config/{section}" if TUSK_AVAILABLE else "unavailable",
            "function": "/tusktsk/function" if TUSK_AVAILABLE else "unavailable",
            "operator": "/tusktsk/operator" if TUSK_AVAILABLE else "unavailable"
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