#!/usr/bin/env node

const https = require('https');
const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');
const { createReadStream, createWriteStream } = require('fs');
const { pipeline } = require('stream');
const { promisify } = require('util');
const zlib = require('zlib');
const tar = require('tar');

const streamPipeline = promisify(pipeline);

class GrimInstaller {
    constructor() {
        this.installDir = path.join(process.env.HOME || '/root', '.grim-reaper');
        this.downloadUrl = 'https://get.grim.so/latest.tar.gz';
        this.tempFile = path.join(process.env.HOME || '/tmp', 'grim-latest.tar.gz');
    }

    /**
     * Check if Grim is already installed
     */
    isInstalled() {
        const possiblePaths = [
            path.join(this.installDir, 'throne', 'grim_throne.sh'),
            path.join(this.installDir, 'sh_grim', 'backup.sh'),
            path.join(this.installDir, 'py_grim', 'grim_web', 'server.py'),
            path.join(this.installDir, 'go_grim', 'build', 'grim-compression')
        ];

        return possiblePaths.some(p => fs.existsSync(p));
    }

    /**
     * Download Grim tarball from get.grim.so
     */
    async download() {
        console.log('📥 Downloading Grim Reaper from get.grim.so...');
        
        return new Promise((resolve, reject) => {
            const file = fs.createWriteStream(this.tempFile);
            
            https.get(this.downloadUrl, (response) => {
                if (response.statusCode === 302 || response.statusCode === 301) {
                    // Follow redirect
                    https.get(response.headers.location, (redirectResponse) => {
                        redirectResponse.pipe(file);
                        file.on('finish', () => {
                            file.close();
                            console.log('✅ Download complete');
                            resolve();
                        });
                    }).on('error', reject);
                } else if (response.statusCode === 200) {
                    response.pipe(file);
                    file.on('finish', () => {
                        file.close();
                        console.log('✅ Download complete');
                        resolve();
                    });
                } else {
                    reject(new Error(`Failed to download: ${response.statusCode}`));
                }
            }).on('error', reject);
        });
    }

    /**
     * Extract the downloaded tarball
     */
    async extract() {
        console.log('📦 Extracting Grim Reaper...');
        
        // Create install directory
        if (!fs.existsSync(this.installDir)) {
            fs.mkdirSync(this.installDir, { recursive: true });
        }

        // Extract tarball
        await tar.x({
            file: this.tempFile,
            cwd: this.installDir,
            strip: 2 // Remove graveyard/reaper/ directories from tarball
        });

        console.log('✅ Extraction complete');
    }

    /**
     * Make scripts executable
     */
    makeExecutable() {
        console.log('🔧 Making scripts executable...');
        
        const scripts = [
            'throne/grim_throne.sh',
            'throne/sh_grim_throne.sh',
            'throne/py_grim_throne.sh',
            'throne/go_grim_throne.sh',
            'sh_grim/*.sh',
            'go_grim/build/*',
            'install.sh',
            'master-install.sh'
        ];

        scripts.forEach(pattern => {
            const fullPattern = path.join(this.installDir, pattern);
            try {
                if (pattern.includes('*')) {
                    // Handle glob patterns
                    const dir = path.dirname(fullPattern);
                    const filePattern = path.basename(fullPattern);
                    
                    if (fs.existsSync(dir)) {
                        fs.readdirSync(dir).forEach(file => {
                            if (filePattern === '*.sh' && file.endsWith('.sh')) {
                                const filePath = path.join(dir, file);
                                fs.chmodSync(filePath, 0o755);
                            } else if (filePattern === '*') {
                                const filePath = path.join(dir, file);
                                if (fs.statSync(filePath).isFile()) {
                                    fs.chmodSync(filePath, 0o755);
                                }
                            }
                        });
                    }
                } else {
                    // Handle specific files
                    if (fs.existsSync(fullPattern)) {
                        fs.chmodSync(fullPattern, 0o755);
                    }
                }
            } catch (error) {
                // Ignore permission errors
            }
        });

        console.log('✅ Scripts made executable');
    }

    /**
     * Install system dependencies
     */
    async installDependencies() {
        console.log('📦 Checking system dependencies...');
        
        const deps = ['rsync', 'tar', 'gzip', 'python3', 'pip3'];
        const missing = [];

        deps.forEach(dep => {
            try {
                execSync(`which ${dep}`, { stdio: 'ignore' });
            } catch {
                missing.push(dep);
            }
        });

        if (missing.length > 0) {
            console.log(`⚠️  Missing dependencies: ${missing.join(', ')}`);
            console.log('💡 Please install them using your package manager');
        }

        console.log('✅ Dependency check complete');
    }

    /**
     * Setup .scythe directory structure
     */ 
    setupScytheDirectories() {
        console.log('🗡️  Setting up .scythe directory structure...');
        
        const scytheDir = path.join(this.installDir, '.graveyard', '.rip', '.scythe');
        const directories = ['config', 'db', 'logs', 'run', 'integrations'];
        
        // Create directory structure
        directories.forEach(dir => {
            const dirPath = path.join(scytheDir, dir);
            if (!fs.existsSync(dirPath)) {
                fs.mkdirSync(dirPath, { recursive: true });
            }
        });
        
        // Create scythe configuration file
        const configFile = path.join(scytheDir, 'config', 'scythe.yaml');
        if (!fs.existsSync(configFile)) {
            const configContent = `# Scythe Configuration
# Central orchestrator settings for Grim Reaper System

scythe:
  version: "1.0.5"
  install_date: ${new Date().toISOString()}
  
database:
  path: "../db/scythe.db"
  auto_backup: true
  backup_interval: "24h"
  
logging:
  level: "info"
  path: "../logs"
  max_size: "100MB"
  max_files: 10
  
orchestration:
  enabled: true
  heartbeat_interval: "30s"
  max_concurrent_jobs: 5
  
integrations:
  enabled: true
  scan_interval: "5m"
  auto_discover: true
  
security:
  encryption: true
  key_rotation: "30d"
  audit_logs: true
`;
            fs.writeFileSync(configFile, configContent);
            console.log('✅ Created scythe configuration');
        }
        
        // Initialize scythe database using shell script if available
        const setupScript = path.join(this.installDir, 'scripts', 'setup_scythe_dirs.sh');
        if (fs.existsSync(setupScript)) {
            try {
                execSync(`bash "${setupScript}" setup "${this.installDir}" no`, { stdio: 'ignore' });
                console.log('✅ Initialized scythe database');
            } catch (error) {
                console.log('⚠️  Could not initialize scythe database - will create basic structure');
                // Create basic directories as fallback
                fs.mkdirSync(path.join(scytheDir, 'logs', 'orchestration'), { recursive: true });
                fs.mkdirSync(path.join(scytheDir, 'logs', 'components'), { recursive: true });
                fs.mkdirSync(path.join(scytheDir, 'logs', 'integrations'), { recursive: true });
                fs.mkdirSync(path.join(scytheDir, 'logs', 'security'), { recursive: true });
                fs.mkdirSync(path.join(scytheDir, 'integrations', 'discovered'), { recursive: true });
                fs.mkdirSync(path.join(scytheDir, 'integrations', 'configs'), { recursive: true });
                fs.mkdirSync(path.join(scytheDir, 'integrations', 'scripts'), { recursive: true });
            }
        }
        
        console.log('✅ .scythe directory structure created');
    }

    /**
     * Setup environment variables
     */
    setupEnvironment() {
        console.log('🌍 Setting up environment...');
        
        const scytheDir = path.join(this.installDir, '.graveyard', '.rip', '.scythe');
        
        // Determine GRIM_ROOT - try different paths with proper permissions check
        let grimRoot = this.installDir;
        if (!this.canWrite('/root/')) {
            if (!this.canWrite(process.env.HOME || '/tmp')) {
                if (!this.canWrite('.')) {
                    console.error('❌ Cannot write to any directory. Please run with proper permissions or chmod +x install.sh');
                    throw new Error('No writable directory found for installation');
                }
                grimRoot = path.resolve('.');
            } else {
                grimRoot = process.env.HOME + '/.grim-reaper';
            }
        }
        
        this.installDir = grimRoot; // Update install directory based on permissions
        
        const envContent = `# Grim Reaper Environment
export GRIM_ROOT="${grimRoot}"
export GRIM_LICENSE="FREE"
export GRIM_REAPER="FALSE"
export SCYTHE_DIR="${scytheDir}"
export PATH="$GRIM_ROOT/throne:$PATH"
`;

        // Add to shell profile
        const shellProfiles = [
            path.join(process.env.HOME, '.bashrc'),
            path.join(process.env.HOME, '.zshrc'),
            path.join(process.env.HOME, '.profile')
        ];

        shellProfiles.forEach(profile => {
            if (fs.existsSync(profile)) {
                const content = fs.readFileSync(profile, 'utf8');
                if (!content.includes('GRIM_ROOT')) {
                    fs.appendFileSync(profile, '\n' + envContent);
                    console.log(`✅ Updated ${profile}`);
                }
            }
        });

        // Set for current session
        process.env.GRIM_ROOT = grimRoot;
        process.env.GRIM_LICENSE = "FREE";
        process.env.GRIM_REAPER = "FALSE";
        process.env.SCYTHE_DIR = scytheDir;
        console.log('✅ Environment setup complete');
    }

    /**
     * Check if directory is writable
     */
    canWrite(dirPath) {
        try {
            if (!fs.existsSync(dirPath)) {
                return false;
            }
            fs.accessSync(dirPath, fs.constants.W_OK);
            return true;
        } catch {
            return false;
        }
    }

    /**
     * Handle GRIM_REAPER="TRUE" mode - selective update preserving sensitive data
     */
    async updateReaperMode() {
        console.log('☠️  GRIM_REAPER mode detected - performing selective update...');
        
        // Sensitive files/directories to preserve
        const preservePaths = [
            'grim.db',
            'grim_error_tracking.db', 
            'mother_db',
            '.grim',
            'data',
            'logs',
            'config',
            'summaries',
            '.graveyard/.rip/.scythe/db',
            '.graveyard/.rip/.scythe/config',
            'license.key',
            'api_keys.json',
            '.env',
            '.credentials'
        ];
        
        // Create backup of sensitive data
        const backupDir = path.join(this.installDir, '.reaper-backup-' + Date.now());
        fs.mkdirSync(backupDir, { recursive: true });
        
        console.log('🔒 Backing up sensitive data...');
        preservePaths.forEach(preservePath => {
            const sourcePath = path.join(this.installDir, preservePath);
            const backupPath = path.join(backupDir, preservePath);
            
            if (fs.existsSync(sourcePath)) {
                console.log(`🔒 Backing up ${preservePath}...`);
                if (fs.statSync(sourcePath).isDirectory()) {
                    this.copyDirectory(sourcePath, backupPath);
                } else {
                    fs.mkdirSync(path.dirname(backupPath), { recursive: true });
                    fs.copyFileSync(sourcePath, backupPath);
                }
            }
        });
        
        // Download and extract new version
        await this.download();
        await this.extract();
        
        // Restore sensitive data
        console.log('🔒 Restoring sensitive data...');
        preservePaths.forEach(preservePath => {
            const backupPath = path.join(backupDir, preservePath);
            const targetPath = path.join(this.installDir, preservePath);
            
            if (fs.existsSync(backupPath)) {
                console.log(`🔒 Restoring ${preservePath}...`);
                if (fs.existsSync(targetPath)) {
                    fs.rmSync(targetPath, { recursive: true, force: true });
                }
                if (fs.statSync(backupPath).isDirectory()) {
                    this.copyDirectory(backupPath, targetPath);
                } else {
                    fs.mkdirSync(path.dirname(targetPath), { recursive: true });
                    fs.copyFileSync(backupPath, targetPath);
                }
            }
        });
        
        // Get version from manifest.tsk if available
        const manifestPath = path.join(this.installDir, 'builds', 'latest', 'manifest.tsk');
        if (fs.existsSync(manifestPath)) {
            try {
                const manifestContent = fs.readFileSync(manifestPath, 'utf8');
                const versionMatch = manifestContent.match(/version[:\s]+(.+)/i);
                if (versionMatch) {
                    process.env.GRIM_VERSION = versionMatch[1].trim();
                    console.log(`📋 Set GRIM_VERSION=${process.env.GRIM_VERSION} from manifest`);
                }
            } catch (error) {
                console.log('⚠️  Could not read version from manifest.tsk');
            }
        }
        
        // Clean up backup
        fs.rmSync(backupDir, { recursive: true, force: true });
        
        // Make executable
        this.makeExecutable();
        
        console.log('✅ Reaper mode update complete - sensitive data preserved');
    }

    /**
     * Run post-install script if available
     */
    async runPostInstall() {
        const postInstallScript = path.join(this.installDir, 'install.sh');
        
        if (fs.existsSync(postInstallScript)) {
            console.log('🚀 Running post-install script...');
            try {
                execSync(`cd "${this.installDir}" && bash install.sh`, { 
                    stdio: 'inherit',
                    env: { ...process.env, GRIM_ROOT: this.installDir }
                });
                console.log('✅ Post-install complete');
            } catch (error) {
                console.log('⚠️  Post-install script failed, but Grim should still work');
            }
        }
    }

    /**
     * Cleanup temporary files
     */
    cleanup() {
        if (fs.existsSync(this.tempFile)) {
            fs.unlinkSync(this.tempFile);
        }
    }

    /**
     * Main installation process
     */
    async install() {
        console.log('🗡️  Grim Reaper Installer');
        console.log('========================\n');

        try {
            // Check if already installed
            if (this.isInstalled()) {
                console.log('✅ Grim Reaper is already installed at:', this.installDir);
                return this.installDir;
            }

            // Download
            await this.download();

            // Extract
            await this.extract();

            // Make executable
            this.makeExecutable();

            // Install dependencies
            await this.installDependencies();

            // Setup .scythe directories
            this.setupScytheDirectories();

            // Setup environment
            this.setupEnvironment();

            // Run post-install
            await this.runPostInstall();

            // Cleanup
            this.cleanup();

            console.log('\n✅ Grim Reaper installation complete!');
            console.log(`📁 Installed to: ${this.installDir}`);
            console.log('💡 Restart your shell or run: source ~/.bashrc');
            console.log('🗡️  Then use: grim <command>\n');

            return this.installDir;

        } catch (error) {
            console.error('❌ Installation failed:', error.message);
            this.cleanup();
            throw error;
        }
    }

    /**
     * Update Grim to latest version (preserves databases and configs)
     */
    async update() {
        console.log('🔄 Updating Grim Reaper to latest version...');
        
        try {
            // Check if GRIM_REAPER mode is enabled
            if (process.env.GRIM_REAPER === "TRUE") {
                return await this.updateReaperMode();
            }
            
            // Normal update mode - preserves databases and configs
            const backupDir = path.join(this.installDir, '.update-backup-' + Date.now());
            
            console.log('📦 Backing up critical data...');
            if (fs.existsSync(this.installDir)) {
                fs.mkdirSync(backupDir, { recursive: true });
                
                // Backup critical directories/files that should not be overwritten
                const criticalPaths = [
                    'data',
                    'logs', 
                    'config',
                    'grim.db',
                    'grim_error_tracking.db',
                    'mother_db',
                    '.grim',
                    'summaries'
                ];
                
                criticalPaths.forEach(criticalPath => {
                    const sourcePath = path.join(this.installDir, criticalPath);
                    const backupPath = path.join(backupDir, criticalPath);
                    
                    if (fs.existsSync(sourcePath)) {
                        console.log(`📦 Backing up ${criticalPath}...`);
                        if (fs.statSync(sourcePath).isDirectory()) {
                            this.copyDirectory(sourcePath, backupPath);
                        } else {
                            fs.mkdirSync(path.dirname(backupPath), { recursive: true });
                            fs.copyFileSync(sourcePath, backupPath);
                        }
                    }
                });
            }
            
            // Download latest version
            await this.download();
            
            // Extract new version 
            await this.extract();
            
            // Restore critical data
            console.log('🔄 Restoring critical data...');
            if (fs.existsSync(backupDir)) {
                const criticalPaths = ['data', 'logs', 'config', 'grim.db', 'grim_error_tracking.db', 'mother_db', '.grim', 'summaries'];
                
                criticalPaths.forEach(criticalPath => {
                    const backupPath = path.join(backupDir, criticalPath);
                    const targetPath = path.join(this.installDir, criticalPath);
                    
                    if (fs.existsSync(backupPath)) {
                        console.log(`🔄 Restoring ${criticalPath}...`);
                        // Remove new version of this path first
                        if (fs.existsSync(targetPath)) {
                            fs.rmSync(targetPath, { recursive: true, force: true });
                        }
                        // Restore from backup
                        if (fs.statSync(backupPath).isDirectory()) {
                            this.copyDirectory(backupPath, targetPath);
                        } else {
                            fs.mkdirSync(path.dirname(targetPath), { recursive: true });
                            fs.copyFileSync(backupPath, targetPath);
                        }
                    }
                });
                
                // Clean up backup
                fs.rmSync(backupDir, { recursive: true, force: true });
            }
            
            // Make executable
            this.makeExecutable();
            
            // Update dependencies  
            await this.installDependencies();
            
            console.log('✅ Update complete! Databases and configurations preserved.');
            return this.installDir;
            
        } catch (error) {
            console.error('❌ Update failed:', error.message);
            throw error;
        }
    }
    
    /**
     * Copy directory recursively
     */
    copyDirectory(source, destination) {
        if (!fs.existsSync(destination)) {
            fs.mkdirSync(destination, { recursive: true });
        }
        
        const items = fs.readdirSync(source);
        
        items.forEach(item => {
            const sourcePath = path.join(source, item);
            const destPath = path.join(destination, item);
            
            if (fs.statSync(sourcePath).isDirectory()) {
                this.copyDirectory(sourcePath, destPath);
            } else {
                fs.copyFileSync(sourcePath, destPath);
            }
        });
    }

    /**
     * Get install directory
     */
    getInstallDir() {
        return this.installDir;
    }
}

module.exports = GrimInstaller;

// Run installer if called directly
if (require.main === module) {
    const installer = new GrimInstaller();
    installer.install().catch(console.error);
}