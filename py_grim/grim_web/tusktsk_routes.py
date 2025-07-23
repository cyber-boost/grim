#!/usr/bin/env python3
"""
TuskLang API Routes for Grim Web Application
Provides REST API endpoints for TuskLang configuration and operations
"""

from fastapi import APIRouter, HTTPException, Depends, Query, Body
from fastapi.responses import JSONResponse
from typing import Any, Dict, List, Optional, Union
from pydantic import BaseModel, Field
import asyncio

from grim_core.tusktsk import get_tusk_api, GrimTuskAPI

# Create router
router = APIRouter(prefix="/tusktsk", tags=["TuskLang Integration"])


# Pydantic models for request/response
class ConfigRequest(BaseModel):
    section: str = Field(..., description="Configuration section")
    key: Optional[str] = Field(None, description="Configuration key (optional for section requests)")
    value: Optional[Any] = Field(None, description="Value to set (for set operations)")

class FunctionRequest(BaseModel):
    section: str = Field(..., description="Function section")
    key: str = Field(..., description="Function key")
    args: List[Any] = Field(default=[], description="Function arguments")
    kwargs: Dict[str, Any] = Field(default={}, description="Function keyword arguments")

class OperatorRequest(BaseModel):
    operator: str = Field(..., description="TuskLang operator")
    expression: str = Field(..., description="Expression to evaluate")
    context: Dict[str, Any] = Field(default={}, description="Execution context")

class ConfigResponse(BaseModel):
    success: bool = Field(..., description="Operation success status")
    data: Dict[str, Any] = Field(..., description="Response data")
    error: Optional[str] = Field(None, description="Error message if any")


# Dependency to get TuskLang API instance
def get_tusk_api_dependency() -> GrimTuskAPI:
    """Dependency to get TuskLang API instance"""
    return get_tusk_api()


@router.get("/status", response_model=ConfigResponse)
async def get_tusk_status(
    tusk_api: GrimTuskAPI = Depends(get_tusk_api_dependency)
) -> ConfigResponse:
    """Get TuskLang integration status"""
    try:
        status = tusk_api.get_status()
        return ConfigResponse(
            success=True,
            data=status
        )
    except Exception as e:
        return ConfigResponse(
            success=False,
            data={},
            error=str(e)
        )


@router.get("/config/{section}", response_model=ConfigResponse)
async def get_config_section(
    section: str,
    tusk_api: GrimTuskAPI = Depends(get_tusk_api_dependency)
) -> ConfigResponse:
    """Get entire configuration section"""
    try:
        result = await tusk_api.get_config(section)
        return ConfigResponse(
            success=True,
            data=result
        )
    except Exception as e:
        return ConfigResponse(
            success=False,
            data={},
            error=str(e)
        )


@router.get("/config/{section}/{key}", response_model=ConfigResponse)
async def get_config_value(
    section: str,
    key: str,
    tusk_api: GrimTuskAPI = Depends(get_tusk_api_dependency)
) -> ConfigResponse:
    """Get specific configuration value"""
    try:
        result = await tusk_api.get_config(section, key)
        return ConfigResponse(
            success=True,
            data=result
        )
    except Exception as e:
        return ConfigResponse(
            success=False,
            data={},
            error=str(e)
        )


@router.post("/config/{section}/{key}", response_model=ConfigResponse)
async def set_config_value(
    section: str,
    key: str,
    value: Any = Body(...),
    tusk_api: GrimTuskAPI = Depends(get_tusk_api_dependency)
) -> ConfigResponse:
    """Set configuration value"""
    try:
        result = await tusk_api.set_config(section, key, value)
        return ConfigResponse(
            success=result['success'],
            data=result
        )
    except Exception as e:
        return ConfigResponse(
            success=False,
            data={},
            error=str(e)
        )


@router.post("/function", response_model=ConfigResponse)
async def execute_function(
    request: FunctionRequest,
    tusk_api: GrimTuskAPI = Depends(get_tusk_api_dependency)
) -> ConfigResponse:
    """Execute TuskLang function"""
    try:
        result = await tusk_api.execute_function(
            request.section,
            request.key,
            request.args,
            request.kwargs
        )
        return ConfigResponse(
            success=True,
            data=result
        )
    except Exception as e:
        return ConfigResponse(
            success=False,
            data={},
            error=str(e)
        )


@router.post("/operator", response_model=ConfigResponse)
async def execute_operator(
    request: OperatorRequest,
    tusk_api: GrimTuskAPI = Depends(get_tusk_api_dependency)
) -> ConfigResponse:
    """Execute TuskLang operator"""
    try:
        result = await tusk_api.execute_operator(
            request.operator,
            request.expression,
            request.context
        )
        return ConfigResponse(
            success=True,
            data=result
        )
    except Exception as e:
        return ConfigResponse(
            success=False,
            data={},
            error=str(e)
        )


@router.get("/database", response_model=ConfigResponse)
async def get_database_config(
    tusk_api: GrimTuskAPI = Depends(get_tusk_api_dependency)
) -> ConfigResponse:
    """Get database configuration from TuskLang"""
    try:
        tusk_integration = tusk_api.tusk
        db_config = tusk_integration.get_database_config()
        return ConfigResponse(
            success=True,
            data={'database_config': db_config}
        )
    except Exception as e:
        return ConfigResponse(
            success=False,
            data={},
            error=str(e)
        )


@router.get("/security", response_model=ConfigResponse)
async def get_security_config(
    tusk_api: GrimTuskAPI = Depends(get_tusk_api_dependency)
) -> ConfigResponse:
    """Get security configuration from TuskLang"""
    try:
        tusk_integration = tusk_api.tusk
        security_config = tusk_integration.get_security_config()
        return ConfigResponse(
            success=True,
            data={'security_config': security_config}
        )
    except Exception as e:
        return ConfigResponse(
            success=False,
            data={},
            error=str(e)
        )


@router.get("/ui", response_model=ConfigResponse)
async def get_ui_config(
    tusk_api: GrimTuskAPI = Depends(get_tusk_api_dependency)
) -> ConfigResponse:
    """Get UI configuration from TuskLang"""
    try:
        tusk_integration = tusk_api.tusk
        ui_config = tusk_integration.get_ui_config()
        return ConfigResponse(
            success=True,
            data={'ui_config': ui_config}
        )
    except Exception as e:
        return ConfigResponse(
            success=False,
            data={},
            error=str(e)
        )


@router.post("/save", response_model=ConfigResponse)
async def save_config(
    filepath: str = Body(..., embed=True),
    tusk_api: GrimTuskAPI = Depends(get_tusk_api_dependency)
) -> ConfigResponse:
    """Save TuskLang configuration to file"""
    try:
        tusk_integration = tusk_api.tusk
        success = tusk_integration.save_tusk_config(filepath)
        return ConfigResponse(
            success=success,
            data={'filepath': filepath, 'saved': success}
        )
    except Exception as e:
        return ConfigResponse(
            success=False,
            data={},
            error=str(e)
        )


@router.post("/load", response_model=ConfigResponse)
async def load_config(
    filepath: str = Body(..., embed=True),
    tusk_api: GrimTuskAPI = Depends(get_tusk_api_dependency)
) -> ConfigResponse:
    """Load TuskLang configuration from file"""
    try:
        tusk_integration = tusk_api.tusk
        success = tusk_integration.load_tusk_config(filepath)
        return ConfigResponse(
            success=success,
            data={'filepath': filepath, 'loaded': success}
        )
    except Exception as e:
        return ConfigResponse(
            success=False,
            data={},
            error=str(e)
        )


@router.get("/sections", response_model=ConfigResponse)
async def list_sections(
    tusk_api: GrimTuskAPI = Depends(get_tusk_api_dependency)
) -> ConfigResponse:
    """List all available configuration sections"""
    try:
        tusk_integration = tusk_api.tusk
        if tusk_integration.tsk_instance:
            sections = list(tusk_integration.tsk_instance.data.keys())
            return ConfigResponse(
                success=True,
                data={'sections': sections}
            )
        else:
            return ConfigResponse(
                success=False,
                data={},
                error="TuskLang not initialized"
            )
    except Exception as e:
        return ConfigResponse(
            success=False,
            data={},
            error=str(e)
        )


@router.get("/info", response_model=ConfigResponse)
async def get_tusk_info(
    tusk_api: GrimTuskAPI = Depends(get_tusk_api_dependency)
) -> ConfigResponse:
    """Get detailed TuskLang package information"""
    try:
        info = tusk_api.get_info()
        return ConfigResponse(
            success=True,
            data=info
        )
    except Exception as e:
        return ConfigResponse(
            success=False,
            data={},
            error=str(e)
        )


@router.get("/health", response_model=ConfigResponse)
async def tusk_health_check(
    tusk_api: GrimTuskAPI = Depends(get_tusk_api_dependency)
) -> ConfigResponse:
    """Health check for TuskLang integration"""
    try:
        status = tusk_api.get_status()
        is_healthy = status.get('available', False) and status.get('initialized', False)
        
        return ConfigResponse(
            success=is_healthy,
            data={
                'status': 'healthy' if is_healthy else 'unhealthy',
                'tusk_status': status
            }
        )
    except Exception as e:
        return ConfigResponse(
            success=False,
            data={'status': 'error'},
            error=str(e)
        ) 