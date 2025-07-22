# 🗡️ GRIM JavaScript CLI

**The Ultimate Backup, Monitoring, and Security System**

A unified JavaScript CLI that orchestrates all Grim components: `sh_grim`, `scyth`, `py_grim`, and `go_grim` into a single, powerful interface.

## 🎯 Overview

Grim started as an archive system called "graveyard" with the goal of making backups more secure, faster, and easier to revert if needed. This JavaScript CLI provides a unified interface to all Grim components, making it easy to manage your entire backup, monitoring, and security infrastructure.

## 🚀 Features

- **Unified CLI Interface** - Single command interface for all Grim operations
- **Multi-Language Integration** - Seamlessly orchestrates Bash, Python, and Go components
- **Beautiful ASCII Art** - Dynamic ASCII art displays for different operations
- **Comprehensive Operations** - Backup, restore, monitoring, security, AI analysis
- **Emergency Operations** - Quick emergency response capabilities
- **Real-time Status** - Health checks and system status monitoring

## 📦 Installation

### Local Installation
```bash
cd js_grim
npm install
```

### Global Installation
```bash
cd js_grim
npm run install-global
```

### Direct Usage
```bash
node js_grim/grim.js [command]
```

## 🎮 Usage

### Core Operations

```bash
# Check all systems health
grim health

# Overall system status
grim status

# Orchestrated backup
grim backup /path/to/backup

# Coordinated restore
grim restore backup.tar.gz

# Unified file scanning
grim scan /path/to/scan

# Start monitoring
grim monitor /path/to/monitor

# Start web interface
grim web
```

### Security & Compliance

```bash
# Run security audit
grim security-audit

# Encrypt file
grim security-encrypt /path/to/file
```

### System Maintenance

```bash
# Optimize entire system
grim optimize-all

# Self-healing system
grim heal

# Complete system cleanup
grim cleanup-all
```

### AI & Machine Learning

```bash
# AI analysis of data
grim ai-analyze /path/to/data
```

### Reporting & Analytics

```bash
# Daily system report
grim report-daily
```

### Emergency Commands

```bash
# Emergency auto-fix
grim emergency-heal
```

## 🏗️ Architecture

The JavaScript Grim CLI acts as an orchestrator for four main components:

### 1. **sh_grim** (Bash)
- Primary backup and restore operations
- System maintenance and optimization
- Security operations and encryption
- File system operations

### 2. **scyth** (Bash)
- File scanning and analysis
- Threat detection
- System reconnaissance
- Performance monitoring

### 3. **py_grim** (Python)
- AI and machine learning operations
- Advanced monitoring and analytics
- Self-healing capabilities
- Data analysis and reporting

### 4. **go_grim** (Go)
- High-performance web interface
- Real-time monitoring dashboard
- API endpoints
- System performance optimization

## 🎨 ASCII Art

The CLI features dynamic ASCII art displays:

- **grim1/grim2** - Standard Grim logo for general operations
- **scythe** - Security and audit operations
- **skull** - Emergency operations

## 🔧 Configuration

The CLI automatically detects and uses existing Grim components:

```javascript
{
    sh_grim_path: './sh_grim',
    scyth_path: './scyth', 
    py_grim_path: './py_grim',
    go_grim_path: './go_grim'
}
```

## 📋 Command Reference

### Core Commands
| Command | Description | Component |
|---------|-------------|-----------|
| `health` | Check all systems health | All |
| `status` | Overall system status | All |
| `backup <path>` | Orchestrated backup | sh_grim |
| `restore <backup>` | Coordinated restore | sh_grim |
| `scan <path>` | Unified file scanning | scyth |
| `monitor <path>` | Start monitoring | py_grim |
| `web` | Start web interface | go_grim |

### Security Commands
| Command | Description | Component |
|---------|-------------|-----------|
| `security-audit` | Run security audit | sh_grim |
| `security-encrypt <file>` | Encrypt file | sh_grim |

### Maintenance Commands
| Command | Description | Component |
|---------|-------------|-----------|
| `optimize-all` | Optimize entire system | sh_grim |
| `heal` | Self-healing system | py_grim |
| `cleanup-all` | Complete system cleanup | sh_grim |

### AI Commands
| Command | Description | Component |
|---------|-------------|-----------|
| `ai-analyze <path>` | AI analysis of data | py_grim |

### Emergency Commands
| Command | Description | Component |
|---------|-------------|-----------|
| `emergency-heal` | Emergency auto-fix | sh_grim |

## 🛠️ Development

### Project Structure
```
js_grim/
├── grim.js          # Main CLI application
├── package.json     # Node.js package configuration
├── README.md        # This file
└── scripts/         # Additional scripts (if needed)
```

### Adding New Commands

To add a new command, extend the `GrimCLI` class:

```javascript
async newCommand(args) {
    console.log('🆕 Executing new command...\n');
    
    try {
        const result = await this.executeBashScript(
            path.join(this.config.sh_grim_path, 'grim.sh'),
            ['new-command', ...args]
        );
        console.log('✅ New command completed successfully');
        return result;
    } catch (error) {
        console.error('❌ New command failed:', error);
        throw error;
    }
}
```

Then add it to the `run()` method switch statement.

## 🔍 Troubleshooting

### Common Issues

1. **Component not found**
   - Ensure all Grim components are installed and accessible
   - Check file permissions on component scripts

2. **Permission denied**
   - Run with appropriate permissions for system operations
   - Ensure Grim user/group is properly configured

3. **Component execution failed**
   - Check component-specific logs
   - Verify dependencies are installed for each component

### Debug Mode

Enable verbose logging by setting the `verbose` flag in the configuration:

```javascript
this.config.verbose = true;
```

## 📄 License

MIT License - see LICENSE file for details.

## 👥 Authors

- **Bernie Gengel** - Primary developer
- **Buddy** - Beagle companion and moral support

## 🏛️ History

Grim was built by Bernie Gengel and his beagle Buddy in July 2025. It started as an archive system called "graveyard" with the original goal of making backups more secure, faster and easier to revert if needed.

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

## 📞 Support

- **Issues**: [GitHub Issues](https://github.com/grim-reaper/grim-js/issues)
- **Documentation**: [Grim Documentation](https://grim-reaper.org/docs)
- **Community**: [Grim Community](https://grim-reaper.org/community)

---

**Built with ❤️ by Bernie Gengel and his beagle Buddy**

*Grim started as archive system called graveyard. The original goal was to make backups more secure, faster and easier to revert if needed.* 