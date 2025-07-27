"""
Grim Reaper Python Package
The Ultimate Backup, Monitoring, and Security System

Install with: pip install grim-reaper
"""

__version__ = "1.0.6"
__author__ = "Bernie Gengel and his beagle Buddy"
__email__ = "packages@tuskt.sk"
__url__ = "https://grim.so"
__license__ = "MIT"

# Import and run dependency check on first import
from .grim_gateway import GrimGateway, check_and_install_dependencies

# Run dependency check on import (but only once) - non-blocking
try:
    check_and_install_dependencies()
except Exception as e:
    # Don't let dependency check break the package
    pass

from .backup import GrimBackup
from .monitor import GrimMonitor
from .scanner import GrimScanner
from .health import GrimHealth

__all__ = [
    "GrimGateway",
    "GrimBackup", 
    "GrimMonitor",
    "GrimScanner",
    "GrimHealth",
    "__version__",
    "__author__",
    "__email__",
    "__url__",
    "__license__",
]

def main():
    """Main entry point for the grim-reaper package"""
    from .grim_gateway import main as gateway_main
    gateway_main()

if __name__ == "__main__":
    main() 