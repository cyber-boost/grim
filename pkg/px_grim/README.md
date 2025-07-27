# Grim Reaper - pipx Package

**Isolated Python CLI App Installation via pipx**

When data death comes knocking, Grim ensures resurrection is just a command away. pipx provides isolated, clean installations perfect for CLI tools like Grim Reaper.

## 🚀 Quick Install

```bash
pipx install grim-reaper
```

## 📦 What is pipx?

pipx installs Python CLI applications in isolated environments, preventing dependency conflicts while making them globally available.

**Benefits for Grim Reaper:**
- ✅ Clean, isolated installation
- ✅ No conflicts with system Python
- ✅ Automatic PATH management
- ✅ Easy upgrades and uninstalls

## 🛠️ Installation Options

### Standard Installation
```bash
# Install latest version
pipx install grim-reaper

# Verify installation
grim --version
```

### Development Installation
```bash
# Install from git
pipx install git+https://github.com/cyber-boost/grim.git

# Install specific version
pipx install grim-reaper==1.0.36
```

### Virtual Environment Control
```bash
# Install with specific Python version
pipx install grim-reaper --python python3.11

# Install with extra dependencies
pipx install grim-reaper[dev]
```

## 🔧 Management Commands

```bash
# Upgrade to latest
pipx upgrade grim-reaper

# Reinstall if corrupted
pipx reinstall grim-reaper

# Uninstall completely
pipx uninstall grim-reaper

# List installed apps
pipx list
```

## 🎯 Why pipx for Grim Reaper?

- **Isolation**: No dependency conflicts with other Python tools
- **Clean**: Separate virtual environment for Grim's dependencies
- **Global**: `grim` command available system-wide
- **Maintained**: pipx handles Python environment management
- **Professional**: Industry standard for Python CLI tools

## 📥 Auto-Download & Installation

Grim Reaper automatically downloads and installs the complete ecosystem:

```bash
pipx install grim-reaper
# Automatically downloads latest.tar.gz from get.grim.so
# Extracts with proper graveyard/reaper/ structure handling
# Sets environment variables: GRIM_ROOT, GRIM_LICENSE=FREE
# Makes all scripts executable across all components
```

## 🔗 Links

- **pipx**: https://pypa.github.io/pipx/
- **PyPI Package**: https://pypi.org/project/grim-reaper/
- **Grim Documentation**: https://grim.so
- **Support**: https://github.com/cyber-boost/grim/issues

## 📋 Requirements

- Python 3.8+
- pipx installed (`pip install pipx` or use system package manager)

---

**🗡️ Grim Reaper via pipx - Death-defying data protection in an isolated environment!** 