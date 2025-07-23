# 🗡️ GRIM NPM Package

## Overview
Grim is the ultimate backup, monitoring, and security system that unifies multiple components:
- **sh_grim**: Bash-based backup and system operations
- **scyth**: File scanning and analysis
- **py_grim**: Python-based monitoring and AI
- **go_grim**: Go-based web interface and performance

## Installation
```bash
npm install -g grim
```

## Usage
```bash
grim --help          # Show help
grim health          # Check system health
grim backup /path    # Backup a directory
grim monitor         # Start monitoring
grim web             # Start web interface
```

## Components
Each component is installed to `/opt/grim-reaper/` and can be used independently or through the unified CLI.

## Configuration
Configuration files are stored in `/etc/grim-reaper/` and can be customized for your environment.

## Support
- Documentation: https://grim-reaper.org
- Issues: https://github.com/grim-reaper/grim/issues
