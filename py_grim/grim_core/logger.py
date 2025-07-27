"""
Grim Core Logger - Simple logging functionality
"""
import logging
import sys
import time
import json

_initialized = False
_loggers = {}

def init_logger(level="INFO", log_file=None):
    """Initialize the logging system"""
    global _initialized
    if _initialized:
        return
    
    logging.basicConfig(
        level=getattr(logging, level.upper()),
        format='%(asctime)s [%(levelname)s] %(name)s: %(message)s',
        handlers=[
            logging.StreamHandler(sys.stdout),
            *([] if log_file is None else [logging.FileHandler(log_file)])
        ]
    )
    _initialized = True

def get_logger(name="grim"):
    """Get or create a logger instance"""
    if not _initialized:
        init_logger()
    
    if name not in _loggers:
        _loggers[name] = logging.getLogger(name)
    
    return _loggers[name]

def setup_logger(name="grim", level="INFO"):
    """Setup basic logger (legacy compatibility)"""
    if not _initialized:
        init_logger(level)
    return get_logger(name)

def log_event(event_type, data=None, logger_name="grim"):
    """Log a structured event"""
    logger = get_logger(logger_name)
    event_data = {
        "timestamp": time.time(),
        "event_type": event_type,
        "data": data or {}
    }
    logger.info(f"EVENT: {json.dumps(event_data)}")

def log_metric(metric_name, value, logger_name="grim"):
    """Log a metric"""
    logger = get_logger(logger_name)
    metric_data = {
        "timestamp": time.time(),
        "metric": metric_name,
        "value": value
    }
    logger.info(f"METRIC: {json.dumps(metric_data)}")