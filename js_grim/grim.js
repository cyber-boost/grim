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
        this.config = {
            sh_grim_path: './mock_install/sh_grim',
            scyth_path: './mock_install/scyth',
            py_grim_path: './mock_install/py_grim',
            go_grim_path: './mock_install/go_grim',
            verbose: false,
            timeout: 30000
        };
        this.rl = readline.createInterface({
            input: process.stdin,
            output: process.stdout
        });
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
        console.log('🔍 Checking all Grim systems health...\n');
        
        const systems = [
            { name: 'sh_grim', path: path.join(this.config.sh_grim_path, 'grim.sh') },
            { name: 'scyth', path: path.join(this.config.scyth_path, 'scyth.sh') },
            { name: 'py_grim', path: path.join(this.config.py_grim_path, 'grim.py') },
            { name: 'go_grim', path: path.join(this.config.go_grim_path, 'grim.go') }
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
        console.log('📊 Overall Grim system status...\n');
        
        // Check system resources
        try {
            const cpuUsage = await this.executeBashScript('./sh_grim/system-status.sh', [], { silent: true });
            console.log('System Status:', cpuUsage.stdout);
        } catch (error) {
            console.log('System status check failed');
        }
    }

    async backup(targetPath) {
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
     * Main CLI interface
     */
    async run() {
        const command = process.argv[2];
        const args = process.argv.slice(3);

        // Show banner on startup
        if (!command || command === 'help') {
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
            switch (command) {
                // Core Operations
                case 'health':
                    await this.health();
                    break;
                case 'status':
                    await this.status();
                    break;
                case 'backup':
                    await this.backup(args[0]);
                    break;
                case 'restore':
                    await this.restore(args[0]);
                    break;
                case 'scan':
                    await this.scan(args[0]);
                    break;
                case 'monitor':
                    await this.monitor(args[0]);
                    break;
                case 'web':
                    await this.web();
                    break;

                // Security Operations
                case 'security-audit':
                    await this.securityAudit();
                    break;
                case 'security-encrypt':
                    await this.encryptFile(args[0]);
                    break;

                // System Maintenance
                case 'optimize-all':
                    await this.optimizeAll();
                    break;
                case 'heal':
                    await this.heal();
                    break;
                case 'cleanup-all':
                    await this.cleanupAll();
                    break;

                // AI Operations
                case 'ai-analyze':
                    await this.aiAnalyze(args[0]);
                    break;

                // Reporting
                case 'report-daily':
                    await this.reportDaily();
                    break;

                // Emergency Operations
                case 'emergency-heal':
                    await this.emergencyHeal();
                    break;

                default:
                    console.log(`❌ Unknown command: ${command}`);
                    this.showHelp();
                    process.exit(1);
            }
        } catch (error) {
            console.error('❌ Command failed:', error.message);
            process.exit(1);
        }
    }

    showHelp() {
        console.log(`
🗡️  GRIM CLI - Unified Command Interface

Core Operations:
  grim health                              # Check all systems health
  grim status                              # Overall system status
  grim backup <path>                       # Orchestrated backup
  grim restore <backup>                    # Coordinated restore
  grim scan <path>                         # Unified file scanning
  grim monitor <path>                      # Start monitoring
  grim web                                 # Start web interface

Security & Compliance:
  grim security-audit                      # Run security audit
  grim security-encrypt <file>             # Encrypt file

System Maintenance:
  grim optimize-all                        # Optimize entire system
  grim heal                                # Self-healing system
  grim cleanup-all                         # Complete system cleanup

AI & Machine Learning:
  grim ai-analyze <path>                   # AI analysis of data

Reporting & Analytics:
  grim report-daily                        # Daily system report

Emergency Commands:
  grim emergency-heal                      # Emergency auto-fix

Examples:
  grim backup /data                        # Backup directory
  grim restore backup.tar.gz               # Restore backup
  grim scan /path                          # Scan directory
  grim security-audit                      # Security check
  grim optimize-all                        # Optimize system

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