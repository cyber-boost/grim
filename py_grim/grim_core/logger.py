"""
Grim Core Logger - Simple logging functionality
"""
import logging
import sys

def setup_logger(name="grim", level="INFO"):
    """Setup basic logger"""
    logger = logging.getLogger(name)
    logger.setLevel(getattr(logging, level))
    
    handler = logging.StreamHandler(sys.stdout)
    formatter = logging.Formatter('%(asctime)s [%(levelname)s] %(name)s: %(message)s')
    handler.setFormatter(formatter)
    
    logger.addHandler(handler)
    return logger

def get_logger(name="grim"):
    """Get logger instance"""
    return logging.getLogger(name)