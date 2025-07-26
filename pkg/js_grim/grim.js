#!/usr/bin/env node
/**
 * 🗡️ GRIM - The Ultimate Backup, Monitoring, and Security System
 * JavaScript CLI that unifies sh_grim, scyth, py_grim, and go_grim
 * 
 * Built by Bernie Gengel and his beagle Buddy in July 2025
 * Grim started as archive system called graveyard
 */

const { spawn, exec, execSync } = require('child_process');
const fs = require('fs');
const path = require('path');
const readline = require('readline');
const GrimReaper = require('./lib/grim-reaper');

// ASCII Art Collection
const ASCII_ART = {
    grim1: `⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⣴⡆
⠀⠀⠀⠀⠀⢀⣶⣆⢀⠔⠁⠀⣷
⠀⠀⠀⠀⠀⠚⣿⣿⣷⡄⠀⠀⢸
⠀⠀⠀⠀⠀⣠⣺⣿⣿⡇⠀⠀⠸
⠀⠀⠀⠀⡸⣿⣿⣿⣿⡇⠀⠀⠀
⠀⠀⠀⡔⠁⢸⣿⣿⣿⣿⠀⠀⠀
⠀⠀⠌⠀⠀⠀⣿⣿⣿⣿⠀⠀⠀
⠀⡌⠀⠀⠀⠀⢸⣿⣿⣿⡇⠀⠀
⠈⠀⠀⠀⠀⠀⢸⣿⣿⣿⡇⠀⠀
⠀⠀⠀⠀⠀⠀⣾⣿⣿⣿⣷⠀⠀
⠀⠀⠀⠀⠀⠀⣿⣿⣿⣿⣿⣷⣄
⠀⠀⠀⠀⠀⠀⠛⠛⠛⠛⠛⠛⠉`,

    grim2: `⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣀⣀⣀⣀⣀⣀⣀⣀⣀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⢀⣠⣴⣶⣿⣿⣿⣿⣿⣿⡿⠿⠿⠿⠿⠿⠷⠶⢤⡀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠘⣿⣿⣿⡿⠟⠋⠉⠀⠀⠀⠀⣠⣦⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠘⣿⡅⠀⠀⠀⠀⠀⠀⢀⣾⣿⣿⣿⣦⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠈⢿⣆⠀⠀⠀⠀⢠⣿⣿⣿⣿⣿⣿⣷⡀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠙⣷⣄⠀⣴⣿⣿⣿⣿⣿⣿⠿⠛⠁⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣷⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠉⢻⣿⣿⣿⣿⣿⣿⣿⣷⡀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣼⣿⣿⣿⣿⣿⣿⣿⠟⠁⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢰⣿⣿⣿⣿⣿⣿⣿⡿⣧⡀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣼⣿⣿⣿⣿⣿⣿⣿⣇⠘⢿⣄⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⣿⣿⣿⣿⣿⣿⣿⣿⣿⡀⠈⢻⣆⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣸⣿⣿⣿⣿⣿⣿⣿⣿⣿⣇⠀⠀⠉⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⠀⠀⠀⠀⠀⠀⠀⠀⠀`,

    scythe: `⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⣀⣀⣀⣀⣀⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⣀⣠⣤⣴⣶⣶⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣷⣶⣤⡀⠀⠀⠀⠀
⠀⠀⣿⣷⠀⣿⣿⣿⣿⣿⣿⣿⡿⠟⠛⠛⠉⠉⠉⠉⠉⠉⠙⠛⠻⢿⣷⡀⠀⠀
⠀⠀⢿⣿⠀⢹⣿⣿⡿⠛⠉⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠈⠙⠄⠀
⠀⠀⠸⣿⡇⠈⠟⠁⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⢻⣿⡄⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⢻⣿⡄⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⣀⣠⣴⡿⣿⣦⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠈⠛⠛⠉⠀⠈⠛⢿⣦⣄⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠙⠻⣿⣶⣤⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠙⠻⣿⣷⣦⣀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠈⠙⢿⣿⣷⣄⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠉⠻⣿⣷⣄⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠙⢿⣿⣷⡀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠈⠉⠉⠁⠀⠀⠀⠀⠀⠀`,

    skull: `            _,.-------------.._
         ,-'        j          '-.
       ,'        .-'               '.
      /          |                   '
     /         ,-'                    '
    .         j                         \\
   .          |                          \\
   : ._       |   _....._                 .
   |   -.     L-''       '.               :
   | '.  \\  .'             '.             |
  /.\\  ', Y'                 :           ,|
 /.  :  | \\                  |         ,' |
\\.    " :  '\\                |      ,--   |
 \\    .'     '-..___,..      |    _/      :
  \\  '.      ___   ...._     '-../        '
.-'    \\    /| \\_/ | | |      ,'         /
|       '--' |    '' |'|     /         .'
|            |      /. |    /       _,'
|-.-.....__..|     Y-dp'...:...--'''
|_|_|_L.L.T._/     |
\\_|_|_L.T-''/      |
 |                /
/             _.-'
:         _..'
\\__...--''`
};

class GrimCLI {
    constructor() {
        this.grim = new GrimReaper();
        this.config = {
            sh_grim_path: null,
            scyth_path: null,
            py_grim_path: null,
            go_grim_path: null,
            verbose: false,
            timeout: 30000
        };
        this.rl = readline.createInterface({
            input: process.stdin,
            output: process.stdout
        });
    }

    /**
     * Initialize paths after GrimReaper is ready
     */
    async initializePaths() {
        await this.grim.initialize();
        this.config.sh_grim_path = path.join(this.grim.grimRoot, 'sh_grim');
        this.config.scyth_path = path.join(this.grim.grimRoot, 'scythe');
        this.config.py_grim_path = path.join(this.grim.grimRoot, 'py_grim');
        this.config.go_grim_path = path.join(this.grim.grimRoot, 'go_grim');
    }

    /**
     * Display ASCII art with optional message
     */
    displayArt(type = 'grim1', message = '') {
        const art = ASCII_ART[type] || ASCII_ART.grim1;
        console.log('\n' + art);
        if (message) {
            console.log('\n' + message);
        }
        console.log('\n');
    }

    /**
     * Execute bash script with spawn
     */
    async executeBashScript(scriptPath, args = [], options = {}) {
        return new Promise((resolve, reject) => {
            const child = spawn('bash', [scriptPath, ...args], {
                stdio: options.silent ? 'pipe' : 'inherit',
                env: { ...process.env, ...options.env }
            });

            let stdout = '';
            let stderr = '';

            if (options.silent) {
                child.stdout.on('data', (data) => {
                    stdout += data.toString();
                });
                child.stderr.on('data', (data) => {
                    stderr += data.toString();
                });
            }

            child.on('close', (code) => {
                if (code === 0) {
                    resolve({ success: true, stdout, stderr, code });
                } else {
                    reject({ success: false, stdout, stderr, code });
                }
            });

            child.on('error', (error) => {
                reject({ success: false, error: error.message });
            });
        });
    }

    /**
     * Execute Python script
     */
    async executePythonScript(scriptPath, args = [], options = {}) {
        return new Promise((resolve, reject) => {
            const child = spawn('python3', [scriptPath, ...args], {
                stdio: options.silent ? 'pipe' : 'inherit',
                env: { ...process.env, ...options.env }
            });

            let stdout = '';
            let stderr = '';

            if (options.silent) {
                child.stdout.on('data', (data) => {
                    stdout += data.toString();
                });
                child.stderr.on('data', (data) => {
                    stderr += data.toString();
                });
            }

            child.on('close', (code) => {
                if (code === 0) {
                    resolve({ success: true, stdout, stderr, code });
                } else {
                    reject({ success: false, stdout, stderr, code });
                }
            });

            child.on('error', (error) => {
                reject({ success: false, error: error.message });
            });
        });
    }

    /**
     * Execute Go binary
     */
    async executeGoBinary(binaryPath, args = [], options = {}) {
        return new Promise((resolve, reject) => {
            const child = spawn(binaryPath, args, {
                stdio: options.silent ? 'pipe' : 'inherit',
                env: { ...process.env, ...options.env }
            });

            let stdout = '';
            let stderr = '';

            if (options.silent) {
                child.stdout.on('data', (data) => {
                    stdout += data.toString();
                });
                child.stderr.on('data', (data) => {
                    stderr += data.toString();
                });
            }

            child.on('close', (code) => {
                if (code === 0) {
                    resolve({ success: true, stdout, stderr, code });
                } else {
                    reject({ success: false, stdout, stderr, code });
                }
            });

            child.on('error', (error) => {
                reject({ success: false, error: error.message });
            });
        });
    }

    /**
     * Core Operations
     */
    async health() {
        await this.initializePaths();
        console.log('🔍 Checking all Grim systems health...\n');
        
        const systems = [
            { name: 'sh_grim', path: path.join(this.config.sh_grim_path, 'health.sh') },
            { name: 'scythe', path: path.join(this.config.scyth_path, 'scythe.py') },
            { name: 'py_grim', path: path.join(this.config.py_grim_path, 'grim_web', 'server.py') },
            { name: 'go_grim', path: path.join(this.config.go_grim_path, 'build', 'grim-compression') }
        ];

        for (const system of systems) {
            try {
                const exists = fs.existsSync(system.path);
                console.log(`${exists ? '✅' : '❌'} ${system.name}: ${exists ? 'Available' : 'Not found'}`);
            } catch (error) {
                console.log(`❌ ${system.name}: Error checking`);
            }
        }
    }

    async status() {
        await this.initializePaths();
        console.log('📊 Overall Grim system status...\n');
        
        // Check system resources
        try {
            const cpuUsage = await this.executeBashScript(path.join(this.config.sh_grim_path, 'system-status.sh'), [], { silent: true });
            console.log('System Status:', cpuUsage.stdout);
        } catch (error) {
            console.log('System status check failed');
        }
    }

    async check() {
        await this.initializePaths();
        
        // Check if auto-recovery mode is enabled
        const autoRecovery = process.argv.includes('--auto-recovery') || process.argv.includes('--auto');
        const maxAttempts = 5;
        let attempt = 1;
        
        while (attempt <= maxAttempts) {
            console.log(`🔍 Grim System Integrity Check (Attempt ${attempt}/${maxAttempts})\n`);
            console.log('='.repeat(50));
            
            const checks = {
                critical: [],
                important: [],
                optional: []
            };

        // Critical files and directories
        const criticalPaths = [
            { name: 'Grim Root Directory', path: this.grim.grimRoot, type: 'dir' },
            { name: 'Graveyard Directory', path: path.join(this.grim.grimRoot, '.graveyard'), type: 'dir' },
            { name: 'RIP Directory', path: path.join(this.grim.grimRoot, '.graveyard', '.rip'), type: 'dir' },
            { name: 'Mother Database', path: path.join(this.grim.grimRoot, '.graveyard', '.rip', 'mother.db'), type: 'file' },
            { name: 'Init Info JSON', path: path.join(this.grim.grimRoot, '.graveyard', '.rip', 'init-info.json'), type: 'file' },
            { name: 'Scythe Directory', path: path.join(this.grim.grimRoot, '.graveyard', '.rip', '.scythe'), type: 'dir' },
            { name: 'SH Grim Directory', path: this.config.sh_grim_path, type: 'dir' },
            { name: 'SH Grim Main Script', path: path.join(this.config.sh_grim_path, 'grim.sh'), type: 'file' },
            { name: 'Backup Directory', path: path.join(this.grim.grimRoot, 'backups'), type: 'dir' },
            { name: 'Logs Directory', path: path.join(this.grim.grimRoot, 'logs'), type: 'dir' },
            { name: 'Database Directory', path: path.join(this.grim.grimRoot, 'db'), type: 'dir' }
        ];

        // Important throne files
        const thronePaths = [
            { name: 'Grim Throne Script', path: path.join(this.grim.grimRoot, 'throne', 'grim_throne.sh'), type: 'file' },
            { name: 'JS Grim Throne', path: path.join(this.grim.grimRoot, 'throne', 'js_grim_throne.sh'), type: 'file' },
            { name: 'PY Grim Throne', path: path.join(this.grim.grimRoot, 'throne', 'py_grim_throne.sh'), type: 'file' },
            { name: 'PHP Grim Throne', path: path.join(this.grim.grimRoot, 'throne', 'php_grim_throne.sh'), type: 'file' },
            { name: 'GO Grim Throne', path: path.join(this.grim.grimRoot, 'throne', 'go_grim_throne.sh'), type: 'file' },
            { name: 'RS Grim Throne', path: path.join(this.grim.grimRoot, 'throne', 'rs_grim_throne.sh'), type: 'file' },
            { name: 'RB Grim Throne', path: path.join(this.grim.grimRoot, 'throne', 'rb_grim_throne.sh'), type: 'file' }
        ];

        // Optional components
        const optionalPaths = [
            { name: 'Scythe Path', path: this.config.scyth_path, type: 'dir' },
            { name: 'PY Grim Path', path: this.config.py_grim_path, type: 'dir' },
            { name: 'GO Grim Path', path: this.config.go_grim_path, type: 'dir' },
            { name: 'Package Directory', path: path.join(this.grim.grimRoot, 'pkg'), type: 'dir' },
            { name: 'Services Directory', path: path.join(this.grim.grimRoot, 'services'), type: 'dir' },
            { name: 'Config Directory', path: path.join(this.grim.grimRoot, 'config'), type: 'dir' }
        ];

        // Check critical paths
        console.log('\n🔴 CRITICAL COMPONENTS:');
        console.log('-'.repeat(30));
        for (const item of criticalPaths) {
            const exists = this.checkPath(item.path, item.type);
            const status = exists ? '✅' : '❌';
            console.log(`${status} ${item.name}: ${exists ? 'OK' : 'MISSING'}`);
            
            if (!exists) {
                checks.critical.push(item.name);
            }
        }

        // Check throne files
        console.log('\n🟡 THRONE COMPONENTS:');
        console.log('-'.repeat(30));
        for (const item of thronePaths) {
            const exists = this.checkPath(item.path, item.type);
            const status = exists ? '✅' : '⚠️';
            console.log(`${status} ${item.name}: ${exists ? 'OK' : 'MISSING'}`);
            
            if (!exists) {
                checks.important.push(item.name);
            }
        }

        // Check optional components
        console.log('\n🟢 OPTIONAL COMPONENTS:');
        console.log('-'.repeat(30));
        for (const item of optionalPaths) {
            const exists = this.checkPath(item.path, item.type);
            const status = exists ? '✅' : 'ℹ️';
            console.log(`${status} ${item.name}: ${exists ? 'OK' : 'NOT FOUND'}`);
            
            if (!exists) {
                checks.optional.push(item.name);
            }
        }

        // Summary and recommendations
        console.log('\n📋 SUMMARY:');
        console.log('='.repeat(50));
        
        if (checks.critical.length === 0) {
            console.log('✅ All critical components are present');
        } else {
            console.log(`❌ ${checks.critical.length} critical component(s) missing:`);
            checks.critical.forEach(item => console.log(`   - ${item}`));
        }

        if (checks.important.length > 0) {
            console.log(`⚠️  ${checks.important.length} throne component(s) missing:`);
            checks.important.forEach(item => console.log(`   - ${item}`));
        }

        if (checks.optional.length > 0) {
            console.log(`ℹ️  ${checks.optional.length} optional component(s) not found:`);
            checks.optional.forEach(item => console.log(`   - ${item}`));
        }

        // Backup system check
        console.log('\n🗄️  BACKUP SYSTEM CHECK:');
        console.log('-'.repeat(30));
        this.checkBackupSystem();

        // Recommendations
        console.log('\n💡 RECOMMENDATIONS:');
        console.log('-'.repeat(30));
        this.provideRecommendations(checks);

        console.log('\n' + '='.repeat(50));
    }

    checkPath(path, type) {
        try {
            if (type === 'dir') {
                return fs.existsSync(path) && fs.statSync(path).isDirectory();
            } else {
                return fs.existsSync(path) && fs.statSync(path).isFile();
            }
        } catch (error) {
            return false;
        }
    }

    checkBackupSystem() {
        const backupDir = path.join(this.grim.grimRoot, 'backups');
        const graveyardDir = path.join(this.grim.grimRoot, '.graveyard');
        
        const backupExists = this.checkPath(backupDir, 'dir');
        const graveyardExists = this.checkPath(graveyardDir, 'dir');
        
        console.log(`${backupExists ? '✅' : '❌'} Backup Directory: ${backupExists ? 'OK' : 'MISSING'}`);
        console.log(`${graveyardExists ? '✅' : '❌'} Graveyard Directory: ${graveyardExists ? 'OK' : 'MISSING'}`);
        
        if (!backupExists) {
            console.log('   ⚠️  Auto-backup and manual backup will fail without backup directory');
        }
        
        if (!graveyardExists) {
            console.log('   ⚠️  Grim throne operations may fail without graveyard directory');
        }
        
        if (backupExists && graveyardExists) {
            console.log('   ✅ Backup system appears to be properly configured');
        }
    }

    provideRecommendations(checks) {
        if (checks.critical.length > 0) {
            console.log('🔴 CRITICAL ISSUES:');
            console.log('   - Run "grim init" to reinitialize missing critical components');
            console.log('   - Check file permissions and disk space');
            console.log('   - Verify Grim installation integrity');
        }
        
        if (checks.important.length > 0) {
            console.log('🟡 THRONE ISSUES:');
            console.log('   - Multiple thrones missing may indicate incomplete installation');
            console.log('   - As long as grim_throne.sh exists in bin, core functionality should work');
            console.log('   - Consider running throne build scripts to restore missing components');
        }
        
        if (checks.critical.length === 0 && checks.important.length === 0) {
            console.log('✅ System appears healthy - no immediate action required');
        }
        
        // Specific backup recommendations
        const backupDir = path.join(this.grim.grimRoot, 'backups');
        const graveyardDir = path.join(this.grim.grimRoot, '.graveyard');
        
        if (!this.checkPath(backupDir, 'dir')) {
            console.log('🗄️  BACKUP RECOMMENDATION:');
            console.log('   - Create backup directory: mkdir -p backups');
            console.log('   - Without .graveyard, backup operations will fail');
        }
        
        if (!this.checkPath(graveyardDir, 'dir')) {
            console.log('⚰️  GRAVEYARD RECOMMENDATION:');
            console.log('   - Run "grim init" to create graveyard structure');
            console.log('   - Graveyard is essential for Grim throne operations');
        }
    }

    async backup(targetPath) {
        await this.initializePaths();
        console.log(`🗄️  Starting orchestrated backup of: ${targetPath}\n`);
        
        try {
            // Use sh_grim for backup
            const result = await this.executeBashScript(
                path.join(this.config.sh_grim_path, 'grim.sh'),
                ['backup', targetPath]
            );
            console.log('✅ Backup completed successfully');
            return result;
        } catch (error) {
            console.error('❌ Backup failed:', error);
            throw error;
        }
    }

    async restore(backupPath) {
        await this.initializePaths();
        console.log(`🔄 Starting coordinated restore from: ${backupPath}\n`);
        
        try {
            const result = await this.executeBashScript(
                path.join(this.config.sh_grim_path, 'grim.sh'),
                ['restore', backupPath]
            );
            console.log('✅ Restore completed successfully');
            return result;
        } catch (error) {
            console.error('❌ Restore failed:', error);
            throw error;
        }
    }

    async scan(targetPath) {
        await this.initializePaths();
        console.log(`🔍 Starting unified file scan of: ${targetPath}\n`);
        
        try {
            // Use scyth for scanning
            const result = await this.executeBashScript(
                path.join(this.config.scyth_path, 'scyth.sh'),
                ['scan', targetPath]
            );
            console.log('✅ Scan completed successfully');
            return result;
        } catch (error) {
            console.error('❌ Scan failed:', error);
            throw error;
        }
    }

    async monitor(targetPath) {
        await this.initializePaths();
        console.log(`👁️  Starting monitoring of: ${targetPath}\n`);
        
        try {
            // Use py_grim for monitoring
            const result = await this.executePythonScript(
                path.join(this.config.py_grim_path, 'grim.py'),
                ['monitor', targetPath]
            );
            console.log('✅ Monitoring started successfully');
            return result;
        } catch (error) {
            console.error('❌ Monitoring failed:', error);
            throw error;
        }
    }

    async web() {
        console.log('🌐 Starting Grim web interface...\n');
        
        try {
            // Use go_grim for web interface
            const result = await this.executeGoBinary(
                path.join(this.config.go_grim_path, 'grim'),
                ['web']
            );
            console.log('✅ Web interface started successfully');
            return result;
        } catch (error) {
            console.error('❌ Web interface failed:', error);
            throw error;
        }
    }

    /**
     * Security Operations
     */
    async securityAudit() {
        console.log('🔒 Running security audit...\n');
        
        try {
            const result = await this.executeBashScript(
                path.join(this.config.sh_grim_path, 'grim.sh'),
                ['security-audit']
            );
            console.log('✅ Security audit completed');
            return result;
        } catch (error) {
            console.error('❌ Security audit failed:', error);
            throw error;
        }
    }

    async encryptFile(filePath) {
        console.log(`🔐 Encrypting file: ${filePath}\n`);
        
        try {
            const result = await this.executeBashScript(
                path.join(this.config.sh_grim_path, 'grim.sh'),
                ['security-encrypt', filePath]
            );
            console.log('✅ File encrypted successfully');
            return result;
        } catch (error) {
            console.error('❌ Encryption failed:', error);
            throw error;
        }
    }

    /**
     * System Maintenance
     */
    async optimizeAll() {
        console.log('⚡ Optimizing entire system...\n');
        
        try {
            const result = await this.executeBashScript(
                path.join(this.config.sh_grim_path, 'grim.sh'),
                ['optimize-all']
            );
            console.log('✅ System optimization completed');
            return result;
        } catch (error) {
            console.error('❌ Optimization failed:', error);
            throw error;
        }
    }

    async heal() {
        console.log('🩹 Starting self-healing system...\n');
        
        try {
            const result = await this.executePythonScript(
                path.join(this.config.py_grim_path, 'grim.py'),
                ['heal']
            );
            console.log('✅ Self-healing completed');
            return result;
        } catch (error) {
            console.error('❌ Self-healing failed:', error);
            throw error;
        }
    }

    async cleanupAll() {
        console.log('🧹 Starting complete system cleanup...\n');
        
        try {
            const result = await this.executeBashScript(
                path.join(this.config.sh_grim_path, 'grim.sh'),
                ['cleanup-all']
            );
            console.log('✅ System cleanup completed');
            return result;
        } catch (error) {
            console.error('❌ Cleanup failed:', error);
            throw error;
        }
    }

    /**
     * AI & Machine Learning
     */
    async aiAnalyze(targetPath) {
        console.log(`🤖 Starting AI analysis of: ${targetPath}\n`);
        
        try {
            const result = await this.executePythonScript(
                path.join(this.config.py_grim_path, 'grim.py'),
                ['ai-analyze', targetPath]
            );
            console.log('✅ AI analysis completed');
            return result;
        } catch (error) {
            console.error('❌ AI analysis failed:', error);
            throw error;
        }
    }

    /**
     * Reporting
     */
    async reportDaily() {
        console.log('📋 Generating daily system report...\n');
        
        try {
            const result = await this.executeBashScript(
                path.join(this.config.sh_grim_path, 'grim.sh'),
                ['report-daily']
            );
            console.log('✅ Daily report generated');
            return result;
        } catch (error) {
            console.error('❌ Report generation failed:', error);
            throw error;
        }
    }

    /**
     * Emergency Operations
     */
    async emergencyHeal() {
        console.log('🚨 Starting emergency auto-fix...\n');
        this.displayArt('skull', 'EMERGENCY HEALING IN PROGRESS');
        
        try {
            const result = await this.executeBashScript(
                path.join(this.config.sh_grim_path, 'grim.sh'),
                ['emergency-heal']
            );
            console.log('✅ Emergency healing completed');
            return result;
        } catch (error) {
            console.error('❌ Emergency healing failed:', error);
            throw error;
        }
    }

    /**
     * Initialize Grim Reaper system using unified sh_grim/init.sh
     */
    async init() {
        console.log('🏗️  Initializing Grim Reaper system...\n');
        
        try {
            await this.grim.initialize();
            
            // Use the unified init.sh script from sh_grim
            const initScript = path.join(this.grim.grimRoot, 'sh_grim', 'init.sh');
            if (!fs.existsSync(initScript)) {
                throw new Error('sh_grim/init.sh not found - Grim installation may be incomplete');
            }
            
            const result = await this.executeBashScript(initScript, ['setup'], { silent: false });
            console.log('✅ Grim system initialization completed via sh_grim/init.sh');
            
            return result;
        } catch (error) {
            console.error('❌ Initialization failed:', error.message);
            throw error;
        }
    }

    /**
     * Comprehensive command router - routes to all existing components
     */
    async routeCommand(command, args) {
        // Initialize paths for all commands that use config paths
        await this.initializePaths();
        
        const commandMap = {
            // Core Operations (existing)
            'init': () => this.init(),
            'health': () => this.health(),
            'status': () => this.status(),
            'check': () => this.check(),
            'backup': () => this.backup(args[0]),
            'restore': () => this.restore(args[0]),
            'scan': () => this.scan(args[0]),
            'monitor': () => this.monitor(args[0]),
            'web': () => this.web(),
            'security-audit': () => this.securityAudit(),
            'security-encrypt': () => this.encryptFile(args[0]),
            'optimize-all': () => this.optimizeAll(),
            'heal': () => this.heal(),
            'cleanup-all': () => this.cleanupAll(),
            'ai-analyze': () => this.aiAnalyze(args[0]),
            'report-daily': () => this.reportDaily(),
            'emergency-heal': () => this.emergencyHeal(),

            // Backup Operations
            'backup-create': () => this.executeBashScript(path.join(this.config.sh_grim_path, 'backup.sh'), ['create', ...args]),
            'backup-list': () => this.executeBashScript(path.join(this.config.sh_grim_path, 'backup.sh'), ['list']),
            'backup-verify': () => this.executeBashScript(path.join(this.config.sh_grim_path, 'backup.sh'), ['verify', args[0]]),
            'backup-schedule': () => this.executeBashScript(path.join(this.config.sh_grim_path, 'backup.sh'), ['schedule', ...args]),
            'backup-full': () => this.executeBashScript(path.join(this.config.sh_grim_path, 'backup_core.sh'), ['full', args[0]]),
            'backup-incremental': () => this.executeBashScript(path.join(this.config.sh_grim_path, 'backup_core.sh'), ['incremental', args[0]]),
            'backup-differential': () => this.executeBashScript(path.join(this.config.sh_grim_path, 'backup_core.sh'), ['differential', args[0]]),

            // Monitoring & Surveillance
            'monitor-start': () => this.executeBashScript(path.join(this.config.sh_grim_path, 'monitor.sh'), ['start', ...args]),
            'monitor-stop': () => this.executeBashScript(path.join(this.config.sh_grim_path, 'monitor.sh'), ['stop', ...args]),
            'monitor-status': () => this.executeBashScript(path.join(this.config.sh_grim_path, 'monitor.sh'), ['status']),
            'monitor-events': () => this.executeBashScript(path.join(this.config.sh_grim_path, 'monitor.sh'), ['events', ...args]),
            'monitor-performance': () => this.executeBashScript(path.join(this.config.sh_grim_path, 'performance.sh'), ['monitor']),
            'lookouts-start': () => this.executeBashScript(path.join(this.config.sh_grim_path, 'lookouts.sh'), ['start']),
            'lookouts-scan': () => this.executeBashScript(path.join(this.config.sh_grim_path, 'lookouts.sh'), ['scan', ...args]),

            // Security & Compliance
            'security-scan': () => this.executeBashScript(path.join(this.config.sh_grim_path, 'security.sh'), ['scan']),
            'security-decrypt': () => this.executeBashScript(path.join(this.config.sh_grim_path, 'encrypt.sh'), ['--decrypt', args[0]]),
            'quarantine-isolate': () => this.executeBashScript(path.join(this.config.sh_grim_path, 'quarantine.sh'), ['isolate', args[0]]),
            'quarantine-analyze': () => this.executeBashScript(path.join(this.config.sh_grim_path, 'quarantine.sh'), ['analyze', args[0]]),
            'quarantine-restore': () => this.executeBashScript(path.join(this.config.sh_grim_path, 'quarantine.sh'), ['restore', args[0]]),
            'quarantine-list': () => this.executeBashScript(path.join(this.config.sh_grim_path, 'quarantine.sh'), ['list']),

            // License Protection (Scythe)
            'license-install': () => this.executeBashScript(path.join(this.config.sh_grim_path, 'scythe.sh'), ['install', ...args]),
            'license-start': () => this.executeBashScript(path.join(this.config.sh_grim_path, 'scythe.sh'), ['start', args[0]]),
            'license-stop': () => this.executeBashScript(path.join(this.config.sh_grim_path, 'scythe.sh'), ['stop']),
            'license-status': () => this.executeBashScript(path.join(this.config.sh_grim_path, 'scythe.sh'), ['status']),
            'license-check': () => this.executeBashScript(path.join(this.config.sh_grim_path, 'scythe.sh'), ['check']),
            'license-report': () => this.executeBashScript(path.join(this.config.sh_grim_path, 'scythe.sh'), ['report']),

            // AI & Machine Learning
            'ai-recommend': () => this.executeBashScript(path.join(this.config.sh_grim_path, 'ai_decision_engine.sh'), ['recommend']),
            'ai-train': () => this.executeBashScript(path.join(this.config.sh_grim_path, 'ai_train.sh'), ['train', ...args]),
            'ai-predict': () => this.executeBashScript(path.join(this.config.sh_grim_path, 'ai_decision_engine.sh'), ['predict', args[0]]),
            'ai-setup': () => this.executeBashScript(path.join(this.config.sh_grim_path, 'ai_integration.sh'), ['setup']),
            'ai-optimize': () => this.executeBashScript(path.join(this.config.sh_grim_path, 'ai_decision_engine.sh'), ['optimize']),
            'smart-suggestions': () => this.executeBashScript(path.join(this.config.sh_grim_path, 'smart_suggestions.sh'), ['analyze']),

            // System Maintenance
            'optimize-storage': () => this.executeBashScript(path.join(this.config.sh_grim_path, 'blacksmith.sh'), ['optimize', 'storage']),
            'optimize-performance': () => this.executeBashScript(path.join(this.config.sh_grim_path, 'blacksmith.sh'), ['optimize', 'performance']),
            'heal-diagnose': () => this.executeBashScript(path.join(this.config.sh_grim_path, 'healer.sh'), ['diagnose']),
            'heal-monitor': () => this.executeBashScript(path.join(this.config.sh_grim_path, 'healer.sh'), ['monitor']),
            'cleanup-logs': () => this.executeBashScript(path.join(this.config.sh_grim_path, 'cleanup.sh'), ['logs']),
            'cleanup-temp': () => this.executeBashScript(path.join(this.config.sh_grim_path, 'cleanup.sh'), ['temp']),
            'cleanup-backups': () => this.executeBashScript(path.join(this.config.sh_grim_path, 'cleanup.sh'), ['backups', args[0]]),

            // Compression Operations (Go binaries)
            'compress': () => this.executeGoBinary(path.join(this.config.go_grim_path, 'build', 'grim-compression'), ['-input', args[0], '-algorithm', args[1] || 'zstd']),
            'compress-benchmark': () => this.executeBashScript(path.join(this.config.sh_grim_path, 'compress.sh'), ['benchmark', args[0]]),
            'compress-optimize': () => this.executeBashScript(path.join(this.config.sh_grim_path, 'compress.sh'), ['optimize', args[0]]),
            'decompress': () => this.executeBashScript(path.join(this.config.sh_grim_path, 'compress.sh'), ['decompress', args[0]]),

            // Reporting & Analytics
            'report-backup': () => this.executeBashScript(path.join(this.config.sh_grim_path, 'report.sh'), ['backup']),
            'report-security': () => this.executeBashScript(path.join(this.config.sh_grim_path, 'report.sh'), ['security']),
            'report-performance': () => this.executeBashScript(path.join(this.config.sh_grim_path, 'report.sh'), ['performance']),
            'report-compliance': () => this.executeBashScript(path.join(this.config.sh_grim_path, 'report.sh'), ['compliance']),
            'audit-start': () => this.executeBashScript(path.join(this.config.sh_grim_path, 'audit.sh'), ['start']),
            'audit-report': () => this.executeBashScript(path.join(this.config.sh_grim_path, 'audit.sh'), ['report']),
            'audit-search': () => this.executeBashScript(path.join(this.config.sh_grim_path, 'audit.sh'), ['search', ...args]),

            // Notifications & Alerts
            'notify-send': () => this.executeBashScript(path.join(this.config.sh_grim_path, 'notify.sh'), ['send', ...args]),
            'notify-setup-email': () => this.executeBashScript(path.join(this.config.sh_grim_path, 'notify.sh'), ['setup', 'email']),
            'notify-setup-slack': () => this.executeBashScript(path.join(this.config.sh_grim_path, 'notify.sh'), ['setup', 'slack']),
            'notify-test': () => this.executeBashScript(path.join(this.config.sh_grim_path, 'notify.sh'), ['test']),
            'alert-configure': () => this.executeBashScript(path.join(this.config.sh_grim_path, 'notify.sh'), ['configure', ...args]),

            // Remote Operations
            'remote-setup': () => this.executeBashScript(path.join(this.config.sh_grim_path, 'remote.sh'), ['setup', ...args]),
            'remote-sync': () => this.executeBashScript(path.join(this.config.sh_grim_path, 'remote.sh'), ['sync', ...args]),
            'remote-download': () => this.executeBashScript(path.join(this.config.sh_grim_path, 'remote.sh'), ['download', args[0]]),
            'remote-status': () => this.executeBashScript(path.join(this.config.sh_grim_path, 'remote.sh'), ['status']),
            'remote-list': () => this.executeBashScript(path.join(this.config.sh_grim_path, 'remote.sh'), ['list']),

            // Scheduling & Automation
            'schedule-add': () => this.executeBashScript(path.join(this.config.sh_grim_path, 'schedule.sh'), ['add', ...args]),
            'schedule-list': () => this.executeBashScript(path.join(this.config.sh_grim_path, 'schedule.sh'), ['list']),
            'schedule-enable': () => this.executeBashScript(path.join(this.config.sh_grim_path, 'schedule.sh'), ['enable', args[0]]),
            'schedule-disable': () => this.executeBashScript(path.join(this.config.sh_grim_path, 'schedule.sh'), ['disable', args[0]]),
            'schedule-remove': () => this.executeBashScript(path.join(this.config.sh_grim_path, 'schedule.sh'), ['remove', args[0]]),

            // Configuration Management
            'config-get': () => this.executeBashScript(path.join(this.config.sh_grim_path, 'settings.sh'), ['get', args[0]]),
            'config-set': () => this.executeBashScript(path.join(this.config.sh_grim_path, 'settings.sh'), ['set', ...args]),
            'config-export': () => this.executeBashScript(path.join(this.config.sh_grim_path, 'settings.sh'), ['export']),
            'config-import': () => this.executeBashScript(path.join(this.config.sh_grim_path, 'settings.sh'), ['import', args[0]]),
            'config-reset': () => this.executeBashScript(path.join(this.config.sh_grim_path, 'settings.sh'), ['reset']),

            // Verification & Integrity
            'verify': () => this.executeBashScript(path.join(this.config.sh_grim_path, 'verify.sh'), [args[0]]),
            'verify-backup': () => this.executeBashScript(path.join(this.config.sh_grim_path, 'verify.sh'), ['--check-backup', args[0]]),
            'verify-system': () => this.executeBashScript(path.join(this.config.sh_grim_path, 'verify.sh'), ['--system']),
            'hash-create': () => this.executeBashScript(path.join(this.config.sh_grim_path, 'verify.sh'), ['--hash', args[0]]),
            'hash-check': () => this.executeBashScript(path.join(this.config.sh_grim_path, 'verify.sh'), ['--check-hash', args[0]]),

            // System Information
            'info-system': () => this.executeBashScript(path.join(this.config.sh_grim_path, 'health.sh'), ['system']),
            'info-storage': () => this.executeBashScript(path.join(this.config.sh_grim_path, 'health.sh'), ['storage']),
            'info-network': () => this.executeBashScript(path.join(this.config.sh_grim_path, 'health.sh'), ['network']),
            'info-performance': () => this.executeBashScript(path.join(this.config.sh_grim_path, 'performance.sh'), ['info']),
            'info-logs': () => this.executeBashScript(path.join(this.config.sh_grim_path, 'health.sh'), ['logs']),
            'info-version': () => this.executeBashScript(path.join(this.config.sh_grim_path, 'health.sh'), ['version']),

            // Emergency Commands
            'emergency-isolate': () => this.executeBashScript(path.join(this.config.sh_grim_path, 'quarantine.sh'), ['isolate', args[0]]),
            'emergency-restore': () => this.executeBashScript(path.join(this.config.sh_grim_path, 'restore.sh'), ['recover', args[0]]),
            'emergency-encrypt': () => this.executeBashScript(path.join(this.config.sh_grim_path, 'encrypt.sh'), [args[0]]),
            'emergency-shutdown': () => this.executeBashScript(path.join(this.config.sh_grim_path, 'blacksmith.sh'), ['shutdown']),

            // Advanced Workflows
            'workflow-backup': () => this.executeBashScript(path.join(this.config.sh_grim_path, 'backup_core.sh'), ['workflow', ...args]),
            'workflow-security': () => this.executeBashScript(path.join(this.config.sh_grim_path, 'security.sh'), ['workflow']),
            'workflow-optimization': () => this.executeBashScript(path.join(this.config.sh_grim_path, 'blacksmith.sh'), ['workflow']),
            'workflow-monitoring': () => this.executeBashScript(path.join(this.config.sh_grim_path, 'monitor.sh'), ['workflow', ...args]),
            'workflow-disaster-recovery': () => this.executeBashScript(path.join(this.config.sh_grim_path, 'healer.sh'), ['disaster-recovery']),

            // Go Binary Operations
            'scan-go': () => this.executeGoBinary(path.join(this.config.go_grim_path, 'build', 'grim-scanner'), args),
            'transfer': () => this.executeGoBinary(path.join(this.config.go_grim_path, 'build', 'grim-transfer'), args),

            // Python Services
            'web-python': () => this.executePythonScript(path.join(this.config.py_grim_path, 'grim_web', 'app.py'), args),
            'ai-python': () => this.executePythonScript(path.join(this.config.py_grim_path, 'analyze_decisions.py'), args),

            // Scythe Orchestration
            'scythe-status': () => this.executePythonScript(path.join(this.config.scyth_path, 'scythe.py'), ['status']),
            'scythe-orchestrate': () => this.executePythonScript(path.join(this.config.scyth_path, 'scythe.py'), ['orchestrate', ...args]),

            // Build & Deployment
            'build': () => this.executeBashScript(path.join(this.grim.grimRoot, 'admin', 'build.sh'), ['build']),
            'build-list': () => this.executeBashScript(path.join(this.grim.grimRoot, 'admin', 'build.sh'), ['list']),
            'deploy': () => this.executeBashScript(path.join(this.grim.grimRoot, 'admin', 'deploy.sh'), args),
            'deploy-latest': () => this.executeBashScript(path.join(this.grim.grimRoot, 'admin', 'deploy.sh'), ['latest']),
            'deploy-rollback': () => this.executeBashScript(path.join(this.grim.grimRoot, 'admin', 'deploy.sh'), ['rollback', args[0]]),
            'deploy-status': () => this.executeBashScript(path.join(this.grim.grimRoot, 'admin', 'deploy.sh'), ['status']),

            // Help Commands
            'help-all': () => this.showAllCommands()
        };

        const handler = commandMap[command];
        if (handler) {
            await handler();
        } else {
            console.log(`❌ Unknown command: ${command}`);
            console.log(`💡 Run 'grim' for help or 'grim help-all' for full command list`);
            process.exit(1);
        }
    }

    /**
     * Show all available commands
     */
    showAllCommands() {
        console.log(`
🗡️  GRIM CLI - COMPLETE COMMAND REFERENCE
==================================================

CORE OPERATIONS:
  grim init                                # Initialize Grim system with .graveyard/.rip
  grim health                              # Check all systems health
  grim status                              # Overall system status
  grim check                               # Comprehensive system integrity check
  grim backup <path>                       # Orchestrated backup
  grim restore <backup>                    # Coordinated restore
  grim scan <path>                         # Unified file scanning
  grim monitor <path>                      # Start monitoring
  grim web                                 # Start web interface

BACKUP OPERATIONS:
  grim backup-create <type> <path>         # Create backup (daily/hourly/weekly)
  grim backup-list                         # List all backups
  grim backup-verify <backup>              # Verify backup integrity
  grim backup-schedule <freq> <path>       # Schedule automated backups
  grim backup-full <path>                  # Full system backup
  grim backup-incremental <path>           # Incremental backup
  grim backup-differential <path>          # Differential backup

MONITORING & SURVEILLANCE:
  grim monitor-start <path>                # Start real-time monitoring
  grim monitor-stop <path>                 # Stop monitoring
  grim monitor-status                      # Show monitoring status
  grim monitor-events <path>               # Show recent events
  grim monitor-performance                 # Performance monitoring
  grim lookouts-start                      # Start security surveillance
  grim lookouts-scan <path>                # Scan for threats

SECURITY & COMPLIANCE:
  grim security-audit                      # Run security audit
  grim security-encrypt <file>             # Encrypt file
  grim security-decrypt <file>             # Decrypt file
  grim security-scan                       # Vulnerability scan
  grim quarantine-isolate <file>           # Isolate suspicious file
  grim quarantine-analyze <file>           # Analyze quarantined file
  grim quarantine-restore <file>           # Restore from quarantine
  grim quarantine-list                     # List quarantined files

LICENSE PROTECTION:
  grim license-install <path> <id> <name>  # Install license protection
  grim license-start <id>                  # Start license monitoring
  grim license-stop                        # Stop license monitoring
  grim license-status                      # Show license compliance
  grim license-check                       # Check for violations
  grim license-report                      # Generate compliance report

AI & MACHINE LEARNING:
  grim ai-analyze <path>                   # AI analysis of data
  grim ai-recommend                        # Get AI recommendations
  grim ai-train <model>                    # Train ML models
  grim ai-predict <file>                   # Predict file importance
  grim ai-setup                            # Setup AI environment
  grim ai-optimize                         # AI-powered optimization
  grim smart-suggestions                   # Intelligent recommendations

SYSTEM MAINTENANCE:
  grim optimize-all                        # Optimize entire system
  grim optimize-storage                    # Storage optimization
  grim optimize-performance                # Performance optimization
  grim heal                                # Self-healing system
  grim heal-diagnose                       # Diagnose system issues
  grim heal-monitor                        # Start healing monitoring
  grim cleanup-all                         # Complete system cleanup
  grim cleanup-logs                        # Clean log files
  grim cleanup-temp                        # Clean temporary files
  grim cleanup-backups <days>              # Clean old backups

COMPRESSION OPERATIONS:
  grim compress <file> --algorithm <algo>  # Compress with specific algorithm
  grim compress-benchmark <path>           # Test compression algorithms
  grim compress-optimize <path>            # Optimize compression settings
  grim decompress <file>                   # Decompress file

REPORTING & ANALYTICS:
  grim report-daily                        # Daily system report
  grim report-backup                       # Backup status report
  grim report-security                     # Security audit report
  grim report-performance                  # Performance analysis
  grim report-compliance                   # Compliance report
  grim audit-start                         # Start audit logging
  grim audit-report                        # Generate audit report
  grim audit-search <query>                # Search audit logs

NOTIFICATIONS & ALERTS:
  grim notify-send <title> <message>       # Send notification
  grim notify-setup-email                  # Setup email notifications
  grim notify-setup-slack                  # Setup Slack integration
  grim notify-test                         # Test notification system
  grim alert-configure <type> <threshold>  # Configure alerts

REMOTE OPERATIONS:
  grim remote-setup <provider>             # Setup remote storage (s3/azure/gcp)
  grim remote-sync <path>                  # Sync to remote storage
  grim remote-download <backup>            # Download from remote
  grim remote-status                       # Remote storage status
  grim remote-list                         # List remote backups

SCHEDULING & AUTOMATION:
  grim schedule-add <cron> <command>       # Add scheduled task
  grim schedule-list                       # List scheduled tasks
  grim schedule-enable <id>                # Enable scheduled task
  grim schedule-disable <id>               # Disable scheduled task
  grim schedule-remove <id>                # Remove scheduled task

CONFIGURATION MANAGEMENT:
  grim config-get <key>                    # Get configuration value
  grim config-set <key> <value>            # Set configuration value
  grim config-export                       # Export all settings
  grim config-import <file>                # Import settings
  grim config-reset                        # Reset to defaults

VERIFICATION & INTEGRITY:
  grim verify <file>                       # Verify file integrity
  grim verify-backup <backup>              # Verify backup integrity
  grim verify-system                       # Verify system integrity
  grim hash-create <file>                  # Create integrity hash
  grim hash-check <file>                   # Check file hash

SYSTEM INFORMATION:
  grim info-system                         # System information
  grim info-storage                        # Storage information
  grim info-network                        # Network information
  grim info-performance                    # Performance metrics
  grim info-logs                           # Recent logs
  grim info-version                        # Version information

EMERGENCY COMMANDS:
  grim emergency-heal                      # Emergency auto-fix
  grim emergency-isolate <file>            # Emergency quarantine
  grim emergency-restore <backup>          # Emergency recovery
  grim emergency-encrypt <path>            # Emergency encryption
  grim emergency-shutdown                  # Emergency system shutdown

ADVANCED WORKFLOWS:
  grim workflow-backup <path>              # Complete backup workflow
  grim workflow-security                   # Security workflow
  grim workflow-optimization              # Performance optimization workflow
  grim workflow-monitoring <path>          # Monitoring workflow
  grim workflow-disaster-recovery          # Disaster recovery workflow

GO BINARY OPERATIONS:
  grim scan-go <path>                      # Go-powered scanning
  grim transfer <args>                     # Go transfer operations

PYTHON SERVICES:
  grim web-python <args>                   # Python web services
  grim ai-python <args>                    # Python AI services

SCYTHE ORCHESTRATION:
  grim scythe-status                       # Scythe status
  grim scythe-orchestrate <args>           # Scythe orchestration

HELP COMMANDS:
  grim help                                # Show basic help
  grim help-all                            # Show all commands (this list)

==================================================
💀 Total Commands Available: 100+
🗡️  Built by Bernie Gengel and his beagle Buddy
        `);
    }

    /**
     * Main CLI interface
     */
    async run() {
        const command = process.argv[2];
        const args = process.argv.slice(3);

        // Show banner on startup
        if (!command || command === 'help' || command === '--help' || command === '-h') {
            this.displayArt('grim2', 'GRIM - The Ultimate Backup, Monitoring, and Security System');
            this.showHelp();
            return;
        }

        // Show appropriate art for different commands
        if (command.startsWith('emergency')) {
            this.displayArt('skull');
        } else if (command.includes('security') || command.includes('audit')) {
            this.displayArt('scythe');
        } else {
            this.displayArt('grim1');
        }

        try {
            // Route commands to appropriate components
            await this.routeCommand(command, args);
        } catch (error) {
            console.error('❌ Command failed:', error.message);
            process.exit(1);
        }
    }

    showHelp() {
        console.log(`
🗡️  GRIM CLI - Unified Command Interface

Core Operations:
  grim init                                # Initialize Grim system with .graveyard/.rip
  grim health                              # Check all systems health
  grim status                              # Overall system status
  grim check                               # Comprehensive system integrity check
  grim backup <path>                       # Orchestrated backup
  grim restore <backup>                    # Coordinated restore
  grim scan <path>                         # Unified file scanning
  grim monitor <path>                      # Start monitoring
  grim web                                 # Start web interface

Backup Operations:
  grim backup-create <type> <path>         # Create backup (daily/hourly/weekly)
  grim backup-list                         # List all backups
  grim backup-verify <backup>              # Verify backup integrity
  grim backup-full <path>                  # Full system backup
  grim backup-incremental <path>           # Incremental backup

Monitoring & Surveillance:
  grim monitor-start <path>                # Start real-time monitoring
  grim monitor-stop <path>                 # Stop monitoring
  grim lookouts-start                      # Start security surveillance
  grim monitor-performance                 # Performance monitoring

Security & Compliance:
  grim security-audit                      # Run security audit
  grim security-encrypt <file>             # Encrypt file
  grim security-scan                       # Vulnerability scan
  grim quarantine-isolate <file>           # Isolate suspicious file
  grim license-status                      # Show license compliance

AI & Machine Learning:
  grim ai-analyze <path>                   # AI analysis of data
  grim ai-recommend                        # Get AI recommendations
  grim ai-train <model>                    # Train ML models
  grim smart-suggestions                   # Intelligent recommendations

System Maintenance:
  grim optimize-all                        # Optimize entire system
  grim heal                                # Self-healing system
  grim cleanup-all                         # Complete system cleanup
  grim compress <file> --algorithm <algo>  # Compress with specific algorithm

Reporting & Analytics:
  grim report-daily                        # Daily system report
  grim report-backup                       # Backup status report
  grim report-security                     # Security audit report
  grim audit-search "query"                # Search audit logs

Emergency Commands:
  grim emergency-heal                      # Emergency auto-fix
  grim emergency-isolate <file>            # Emergency quarantine
  grim emergency-restore <backup>          # Emergency recovery

Examples:
  grim backup /data                        # Backup directory
  grim restore backup.tar.gz               # Restore backup
  grim scan /path                          # Scan directory
  grim security-audit                      # Security check
  grim optimize-all                        # Optimize system

💡 Run 'grim help-all' for complete command list (100+ commands)

Built by Bernie Gengel and his beagle Buddy in July 2025
Grim started as archive system called graveyard
        `);
    }
}

// Run CLI if this file is executed directly
if (require.main === module) {
    const grim = new GrimCLI();
    grim.run().catch(console.error);
}

module.exports = GrimCLI; 