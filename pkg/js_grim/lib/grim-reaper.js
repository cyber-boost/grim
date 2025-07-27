#!/usr/bin/env node

const { execSync } = require('child_process');
const path = require('path');
const fs = require('fs');
const fetch = require('node-fetch');
const GrimInstaller = require('./installer');

/**
 * Grim Reaper Node.js Integration
 * Proper integration with core sh_grim, py_grim, and go_grim components
 */
class GrimReaper {
    constructor() {
        this.grimRoot = null;
        this.installer = new GrimInstaller();
        this.apiBase = 'http://localhost:8000';
        this.initialized = false;
    }

    /**
     * Initialize and ensure Grim is installed
     */
    async initialize() {
        if (this.initialized) return;
        
        try {
            // Try to find existing installation
            this.grimRoot = this.findGrimRoot();
        } catch (error) {
            console.log('🔍 Grim Reaper not found locally, installing...');
            
            // Install Grim automatically
            try {
                this.grimRoot = await this.installer.install();
            } catch (installError) {
                // Show error ASCII
                try {
                    execSync(`bash ${__dirname}/../grim-ascii.sh -e "Grim installation failed"`, { stdio: 'inherit' });
                } catch (e) {
                    console.error('❌ Failed to install Grim Reaper');
                    console.error('It seems like you are missing the needed dependencies');
                    console.error('Please run: curl -fsSL https://get.grim.so | sudo bash');
                }
                throw new Error(`Failed to install Grim Reaper: ${installError.message}`);
            }
        }
        
        this.initialized = true;
    }

    /**
     * Find Grim Reaper root directory
     */
    findGrimRoot() {
        // Check environment variable first
        if (process.env.GRIM_ROOT) {
            const envPath = process.env.GRIM_ROOT;
            if (fs.existsSync(envPath) && (
                fs.existsSync(path.join(envPath, 'throne', 'grim_throne.sh')) ||
                fs.existsSync(path.join(envPath, 'tsk_flask', 'grim_admin_server.py'))
            )) {
                return envPath;
            }
        }

        let currentDir = process.cwd();
        const maxDepth = 10;
        let depth = 0;

        // Search up directory tree
        while (depth < maxDepth) {
            // Check for throne scripts
            if (fs.existsSync(path.join(currentDir, 'throne', 'grim_throne.sh')) ||
                fs.existsSync(path.join(currentDir, 'tsk_flask', 'grim_admin_server.py'))) {
                return currentDir;
            }

            const parentDir = path.dirname(currentDir);
            if (parentDir === currentDir) break;
            currentDir = parentDir;
            depth++;
        }

        // Try common installation paths
        const possiblePaths = [
            // User's home directory
            path.join(process.env.HOME || '/root', 'reaper'),
            path.join(process.env.HOME || '/root', '.reaper'),
            // System-wide installations
            '/usr/local/reaper',
            '/usr/local/share/reaper',
            '/usr/share/reaper',
            '/opt/reaper',
            // Package manager installations
            '/usr/local/lib/grim-reaper',
            '/usr/lib/grim-reaper',
            // Current working directory as fallback
            process.cwd()
        ];

        for (const grimPath of possiblePaths) {
            if (fs.existsSync(grimPath) && (
                fs.existsSync(path.join(grimPath, 'throne', 'grim_throne.sh')) ||
                fs.existsSync(path.join(grimPath, 'tsk_flask', 'grim_admin_server.py'))
            )) {
                return grimPath;
            }
        }

        throw new Error(`Could not find Grim Reaper root directory. 
Searched paths: ${possiblePaths.join(', ')}

Please ensure Grim Reaper is properly installed using one of:
  • curl -fsSL https://get.grim.so | sudo bash
  • wget -qO- https://get.grim.so | sudo bash
  • Manual installation to a standard path

Or set GRIM_ROOT environment variable:
  export GRIM_ROOT=/path/to/your/grim/installation`);
    }

    /**
     * Execute sh_grim module
     */
    async executeShModule(module, args = []) {
        await this.initialize();
        
        const modulePath = path.join(this.grimRoot, 'sh_grim', `${module}.sh`);
        if (!fs.existsSync(modulePath)) {
            throw new Error(`Module not found: ${module}`);
        }

        const cmd = `"${modulePath}" ${args.map(arg => `"${arg}"`).join(' ')}`;
        try {
            return execSync(cmd, { 
                encoding: 'utf8', 
                cwd: this.grimRoot,
                stdio: ['pipe', 'pipe', 'pipe']
            });
        } catch (error) {
            throw new Error(`Module ${module} failed: ${error.message}`);
        }
    }

    /**
     * Execute go_grim binary
     */
    executeGoBinary(binary, args = []) {
        const binaryPath = path.join(this.grimRoot, 'go_grim', 'build', binary);
        if (!fs.existsSync(binaryPath)) {
            throw new Error(`Go binary not found: ${binary}`);
        }

        const cmd = `"${binaryPath}" ${args.map(arg => `"${arg}"`).join(' ')}`;
        try {
            return execSync(cmd, { 
                encoding: 'utf8',
                cwd: this.grimRoot,
                stdio: ['pipe', 'pipe', 'pipe']
            });
        } catch (error) {
            throw new Error(`Go binary ${binary} failed: ${error.message}`);
        }
    }

    /**
     * Call py_grim FastAPI service
     */
    async callPyAPI(endpoint, method = 'GET', data = null) {
        const url = `${this.apiBase}${endpoint}`;
        const options = {
            method,
            headers: { 'Content-Type': 'application/json' }
        };
        
        if (data) {
            options.body = JSON.stringify(data);
        }

        try {
            const response = await fetch(url, options);
            return await response.json();
        } catch (error) {
            throw new Error(`API call failed: ${error.message}`);
        }
    }

    // ============================================================================
    // BACKUP OPERATIONS (via sh_grim)
    // ============================================================================

    /**
     * Create backup using sh_grim/backup.sh
     */
    backup(source, options = {}) {
        const args = [source];
        
        if (options.name) args.push('--name', options.name);
        if (options.compress) args.push('--compress', options.compress);
        if (options.exclude) args.push('--exclude', options.exclude);
        if (options.incremental) args.push('--incremental');
        
        return this.executeShModule('backup', args);
    }

    /**
     * Restore from backup using sh_grim/restore.sh
     */
    restore(backup, destination, options = {}) {
        const args = [backup, destination];
        
        if (options.overwrite) args.push('--overwrite');
        if (options.verify) args.push('--verify');
        
        return this.executeShModule('restore', args);
    }

    /**
     * List available backups
     */
    listBackups() {
        return this.executeShModule('backup', ['--list']);
    }

    // ============================================================================
    // COMPRESSION OPERATIONS (via go_grim)
    // ============================================================================

    /**
     * Compress file using go_grim compression engine
     */
    compress(file, options = {}) {
        const args = [];
        
        if (options.algorithm) args.push('-a', options.algorithm);
        if (options.level) args.push('-l', options.level.toString());
        if (options.output) args.push('-o', options.output);
        
        args.push(file);
        
        return this.executeGoBinary('grim-compression', args);
    }

    /**
     * Decompress file using go_grim
     */
    decompress(file, options = {}) {
        const args = ['-d'];
        
        if (options.output) args.push('-o', options.output);
        args.push(file);
        
        return this.executeGoBinary('grim-compression', args);
    }

    /**
     * Get compression benchmarks
     */
    benchmarkCompression(file) {
        return this.executeGoBinary('grim-compression', ['-benchmark', file]);
    }

    // ============================================================================
    // MONITORING OPERATIONS (via sh_grim)
    // ============================================================================

    /**
     * Start monitoring using sh_grim/monitor.sh
     */
    startMonitoring(path, options = {}) {
        const args = ['start', path];
        
        if (options.interval) args.push('--interval', options.interval.toString());
        if (options.events) args.push('--events', options.events);
        
        return this.executeShModule('monitor', args);
    }

    /**
     * Stop monitoring
     */
    stopMonitoring() {
        return this.executeShModule('monitor', ['stop']);
    }

    /**
     * Get monitoring status
     */
    getMonitoringStatus() {
        return this.executeShModule('monitor', ['status']);
    }

    // ============================================================================
    // SCANNING OPERATIONS (via sh_grim)
    // ============================================================================

    /**
     * Scan directory using sh_grim/scan.sh
     */
    scan(path, options = {}) {
        const args = [path];
        
        if (options.recursive) args.push('--recursive');
        if (options.types) args.push('--types', options.types);
        if (options.output) args.push('--output', options.output);
        
        return this.executeShModule('scan', args);
    }

    /**
     * Security scan using sh_grim/security.sh
     */
    securityScan(path, options = {}) {
        const args = [path];
        
        if (options.deep) args.push('--deep');
        if (options.report) args.push('--report', options.report);
        
        return this.executeShModule('security', args);
    }

    // ============================================================================
    // SYSTEM OPERATIONS (via sh_grim)
    // ============================================================================

    /**
     * System health check using sh_grim/health.sh
     */
    healthCheck() {
        return this.executeShModule('health', ['check']);
    }

    /**
     * Get system status
     */
    getStatus() {
        return this.executeShModule('health', ['status']);
    }

    /**
     * Optimize system using sh_grim/blacksmith.sh
     */
    optimize(target = 'all') {
        return this.executeShModule('blacksmith', ['optimize', target]);
    }

    // ============================================================================
    // API INTEGRATION (via py_grim FastAPI)
    // ============================================================================

    /**
     * Get system status via API
     */
    async getAPIStatus() {
        return await this.callPyAPI('/api/status');
    }

    /**
     * Get backup information via API
     */
    async getBackupInfo() {
        return await this.callPyAPI('/api/backups');
    }

    /**
     * Start backup via API
     */
    async startAPIBackup(source, options = {}) {
        return await this.callPyAPI('/api/backup', 'POST', { source, ...options });
    }

    /**
     * Get monitoring data via API
     */
    async getMonitoringData() {
        return await this.callPyAPI('/api/monitoring');
    }

    // ============================================================================
    // UTILITY METHODS
    // ============================================================================

    /**
     * Execute raw grim command via throne script
     */
    executeCommand(command, args = []) {
        const thronePath = path.join(this.grimRoot, 'throne', 'grim_throne.sh');
        const cmd = `"${thronePath}" ${command} ${args.map(arg => `"${arg}"`).join(' ')}`;
        
        return execSync(cmd, { 
            encoding: 'utf8', 
            cwd: this.grimRoot,
            stdio: ['pipe', 'pipe', 'pipe']
        });
    }

    /**
     * Get Grim version and build info
     */
    getVersion() {
        try {
            const manifestPath = path.join(this.grimRoot, 'builds', 'latest', 'manifest.tsk');
            if (fs.existsSync(manifestPath)) {
                return fs.readFileSync(manifestPath, 'utf8');
            }
        } catch (error) {
            // Fallback to throne script
        }
        
        return this.executeCommand('version');
    }

    /**
     * Check if Grim services are running
     */
    checkServices() {
        const services = {
            api: false,
            monitoring: false,
            admin: false
        };

        try {
            // Check FastAPI service
            execSync('pgrep -f "grim_web"', { stdio: 'pipe' });
            services.api = true;
        } catch (e) {}

        try {
            // Check monitoring service
            execSync('pgrep -f "monitor.sh"', { stdio: 'pipe' });
            services.monitoring = true;
        } catch (e) {}

        try {
            // Check admin server
            execSync('pgrep -f "grim_admin_server.py"', { stdio: 'pipe' });
            services.admin = true;
        } catch (e) {}

        return services;
    }
}

module.exports = GrimReaper;