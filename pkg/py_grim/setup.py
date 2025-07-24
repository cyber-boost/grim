#!/usr/bin/env python3
"""
Grim Reaper Python Package
The Ultimate Backup, Monitoring, and Security System
"""

from setuptools import setup, find_packages, Command
import os
import subprocess
import sys

# Read the README file
def read_readme():
    with open("README.md", "r", encoding="utf-8") as fh:
        return fh.read()

# Read requirements
def read_requirements():
    """Read requirements from requirements.txt"""
    try:
        with open("requirements.txt") as f:
            return [line.strip() for line in f if line.strip() and not line.startswith("#")]
    except FileNotFoundError:
        # Return basic requirements if file doesn't exist
        return [
            "requests>=2.25.0",
            "aiohttp>=3.8.0", 
            "click>=8.0.0",
            "pyyaml>=6.0",
            "psutil>=5.8.0",
            "pathlib>=1.0.0",
            "typing-extensions>=4.0.0",
        ]

class InstallDependencies(Command):
    """Custom command to install system dependencies"""
    description = "Install system dependencies for Grim Reaper"
    user_options = []
    
    def initialize_options(self):
        pass
    
    def finalize_options(self):
        pass
    
    def run(self):
        print("Installing Grim Reaper system dependencies...")
        
        # Get the installation directory
        install_dir = os.path.join(sys.prefix, 'share', 'grim-reaper')
        
        # Run the dependency installation script
        install_script = os.path.join(install_dir, 'install_dependencies.sh')
        if os.path.exists(install_script):
            try:
                subprocess.run(['bash', install_script], check=True)
                print("✅ System dependencies installed successfully!")
            except subprocess.CalledProcessError as e:
                print(f"⚠️  Warning: Some dependencies may not have installed correctly: {e}")
        else:
            print("⚠️  Warning: install_dependencies.sh not found")

# Post-install hook
def run_post_install():
    """Run post-installation tasks"""
    # Post-install tasks handled by package manager
    pass

setup(
    name="grim-reaper",
    version="1.0.7",
    author="Bernie Gengel and his beagle Buddy", 
    author_email="zoo@phptu.sk",
    description="Grim: Unified Data Protection Ecosystem. When data death comes knocking, Grim ensures resurrection is just a command away. License management, auto backups, highly compressed backups, multi-algorithm compression, content-based deduplication, smart storage tiering save up to 60% space, military-grade encryption, license protection, security surveillance, and automated threat response.",
    long_description=read_readme(),
    long_description_content_type="text/markdown",
    url="https://grim.so",
    project_urls={
        "Bug Reports": "https://github.com/cyber-boost/grim/issues",
        "Source": "https://github.com/cyber-boost/grim/tree/main",
        "Documentation": "https://grim.so",
    },
    packages=find_packages(include=["grim_reaper*"]),
    classifiers=[
        "Development Status :: 5 - Production/Stable",
        "Intended Audience :: Developers",
        "Intended Audience :: System Administrators",
        "Operating System :: OS Independent",
        "Programming Language :: Python :: 3",
        "Programming Language :: Python :: 3.8",
        "Programming Language :: Python :: 3.9",
        "Programming Language :: Python :: 3.10",
        "Programming Language :: Python :: 3.11",
        "Programming Language :: Python :: 3.12",
        "Topic :: System :: Systems Administration",
        "Topic :: System :: Monitoring",
        "Topic :: System :: Archiving :: Backup",
        "Topic :: Security",
        "Topic :: Software Development :: Libraries :: Python Modules",
    ],
    python_requires=">=3.8",
    install_requires=read_requirements(),
    extras_require={
        "dev": [
            "pytest>=6.0",
            "pytest-cov>=2.0",
            "black>=21.0",
            "flake8>=3.8",
            "mypy>=0.800",
        ],
        "full": [
            "flask>=2.0",
            "fastapi>=0.68",
            "uvicorn>=0.15",
            "websockets>=10.0",
            "aiofiles>=0.7",
            "psycopg2-binary>=2.9",
            "pymongo>=4.0",
            "redis>=4.0",
            "celery>=5.2",
        ],
    },
    entry_points={
        "console_scripts": [
            "grim=grim_reaper:main",
        ],
    },
    include_package_data=True,
    package_data={
        "": ["*.txt", "*.md"],
        "grim_reaper": ["*.py"],
    },
    cmdclass={
        'install_deps': InstallDependencies,
    },
    zip_safe=False,
    keywords=[
        "grim",
        "backup",
        "monitoring", 
        "security",
        "cli",
        "orchestration",
        "system-management",
        "compression",
        "encryption",
        "ai",
        "machine-learning",
        "grim-reaper",
    ],
    license="BBL",
    platforms=["any"],
)

# Run post-install hook
if __name__ == "__main__":
    run_post_install() 