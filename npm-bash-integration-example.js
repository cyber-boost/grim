#!/usr/bin/env node
/**
 * NPM JavaScript CLI with Bash Script Integration Examples
 * 
 * This demonstrates various ways a Node.js CLI can utilize bash scripts:
 * 1. Direct execution via child_process
 * 2. Package.json scripts
 * 3. Shell script execution with arguments
 * 4. Background process management
 * 5. File system operations
 * 6. Environment variable passing
 */

const { spawn, exec, execSync } = require('child_process');
const fs = require('fs');
const path = require('path');

class NpmBashCLI {
    constructor() {
        this.scriptsDir = './scripts';
        this.config = {
            verbose: false,
            timeout: 30000
        };
    }

    /**
     * Method 1: Direct bash script execution with spawn
     * Best for long-running processes and real-time output
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
     * Method 2: Execute bash script with exec
     * Good for simple commands with output capture
     */
    async executeBashCommand(command, options = {}) {
        return new Promise((resolve, reject) => {
            exec(command, {
                timeout: options.timeout || this.config.timeout,
                env: { ...process.env, ...options.env }
            }, (error, stdout, stderr) => {
                if (error) {
                    reject({ success: false, error: error.message, stdout, stderr });
                } else {
                    resolve({ success: true, stdout, stderr });
                }
            });
        });
    }

    /**
     * Method 3: Execute bash script synchronously
     * Use sparingly - blocks the event loop
     */
    executeBashSync(scriptPath, args = []) {
        try {
            const result = execSync(`bash ${scriptPath} ${args.join(' ')}`, {
                encoding: 'utf8',
                stdio: 'pipe'
            });
            return { success: true, output: result };
        } catch (error) {
            return { success: false, error: error.message };
        }
    }

    /**
     * Method 4: Create and execute dynamic bash scripts
     */
    async createAndExecuteScript(scriptContent, scriptName = 'temp_script.sh') {
        const scriptPath = path.join(this.scriptsDir, scriptName);
        
        try {
            // Ensure scripts directory exists
            if (!fs.existsSync(this.scriptsDir)) {
                fs.mkdirSync(this.scriptsDir, { recursive: true });
            }

            // Write script content
            fs.writeFileSync(scriptPath, scriptContent, { mode: 0o755 });
            
            // Execute the script
            const result = await this.executeBashScript(scriptPath);
            
            // Clean up
            fs.unlinkSync(scriptPath);
            
            return result;
        } catch (error) {
            // Clean up on error
            if (fs.existsSync(scriptPath)) {
                fs.unlinkSync(scriptPath);
            }
            throw error;
        }
    }

    /**
     * Method 5: Execute npm scripts that call bash scripts
     */
    async executeNpmScript(scriptName, args = []) {
        const npmCommand = `npm run ${scriptName} ${args.join(' ')}`;
        return this.executeBashCommand(npmCommand);
    }

    /**
     * Method 6: Background process management
     */
    async startBackgroundProcess(scriptPath, args = [], pidFile = null) {
        const child = spawn('bash', [scriptPath, ...args], {
            detached: true,
            stdio: 'ignore'
        });

        child.unref();

        if (pidFile) {
            fs.writeFileSync(pidFile, child.pid.toString());
        }

        return {
            pid: child.pid,
            success: true
        };
    }

    async stopBackgroundProcess(pidFile) {
        if (fs.existsSync(pidFile)) {
            const pid = fs.readFileSync(pidFile, 'utf8').trim();
            try {
                execSync(`kill ${pid}`);
                fs.unlinkSync(pidFile);
                return { success: true, message: `Process ${pid} stopped` };
            } catch (error) {
                return { success: false, error: error.message };
            }
        }
        return { success: false, error: 'PID file not found' };
    }

    /**
     * Method 7: File system operations via bash
     */
    async performFileOperations(operations) {
        const scriptContent = `#!/bin/bash
set -e

${operations.map(op => {
    switch (op.type) {
        case 'copy':
            return `cp "${op.source}" "${op.destination}"`;
        case 'move':
            return `mv "${op.source}" "${op.destination}"`;
        case 'delete':
            return `rm -rf "${op.path}"`;
        case 'create_dir':
            return `mkdir -p "${op.path}"`;
        case 'chmod':
            return `chmod ${op.permissions} "${op.path}"`;
        default:
            return `echo "Unknown operation: ${op.type}"`;
    }
}).join('\n')}
`;

        return this.createAndExecuteScript(scriptContent);
    }

    /**
     * Method 8: Environment-specific script execution
     */
    async executeWithEnvironment(scriptPath, environment = 'production', args = []) {
        const envVars = {
            NODE_ENV: environment,
            ENVIRONMENT: environment,
            TIMESTAMP: new Date().toISOString()
        };

        return this.executeBashScript(scriptPath, args, { env: envVars });
    }

    /**
     * Method 9: Conditional script execution
     */
    async executeConditionalScript(condition, scriptPath, args = []) {
        const checkScript = `#!/bin/bash
if ${condition}; then
    bash "${scriptPath}" ${args.join(' ')}
    exit $?
else
    echo "Condition not met: ${condition}"
    exit 1
fi
`;

        return this.createAndExecuteScript(checkScript);
    }

    /**
     * Method 10: Script with input/output redirection
     */
    async executeWithIO(scriptPath, input = null, outputFile = null, args = []) {
        return new Promise((resolve, reject) => {
            const child = spawn('bash', [scriptPath, ...args], {
                stdio: input ? ['pipe', 'pipe', 'pipe'] : 'inherit'
            });

            if (input) {
                child.stdin.write(input);
                child.stdin.end();
            }

            let stdout = '';
            let stderr = '';

            child.stdout.on('data', (data) => {
                stdout += data.toString();
            });

            child.stderr.on('data', (data) => {
                stderr += data.toString();
            });

            child.on('close', (code) => {
                if (outputFile) {
                    fs.writeFileSync(outputFile, stdout);
                }

                if (code === 0) {
                    resolve({ success: true, stdout, stderr, code });
                } else {
                    reject({ success: true, stdout, stderr, code });
                }
            });
        });
    }
}

// CLI Interface
class CLI {
    constructor() {
        this.npmBash = new NpmBashCLI();
    }

    async run() {
        const command = process.argv[2];
        const args = process.argv.slice(3);

        switch (command) {
            case 'execute':
                await this.executeScript(args[0], args.slice(1));
                break;
            case 'npm-run':
                await this.runNpmScript(args[0], args.slice(1));
                break;
            case 'background':
                await this.startBackground(args[0], args.slice(1));
                break;
            case 'stop':
                await this.stopBackground(args[0]);
                break;
            case 'files':
                await this.fileOperations(args);
                break;
            case 'conditional':
                await this.conditionalExecution(args[0], args[1], args.slice(2));
                break;
            case 'env':
                await this.environmentExecution(args[0], args[1], args.slice(2));
                break;
            case 'io':
                await this.ioExecution(args[0], args[1], args[2], args.slice(3));
                break;
            default:
                this.showHelp();
        }
    }

    async executeScript(scriptPath, args) {
        try {
            console.log(`Executing bash script: ${scriptPath}`);
            const result = await this.npmBash.executeBashScript(scriptPath, args);
            console.log('Script executed successfully:', result);
        } catch (error) {
            console.error('Script execution failed:', error);
            process.exit(1);
        }
    }

    async runNpmScript(scriptName, args) {
        try {
            console.log(`Running npm script: ${scriptName}`);
            const result = await this.npmBash.executeNpmScript(scriptName, args);
            console.log('NPM script result:', result);
        } catch (error) {
            console.error('NPM script failed:', error);
            process.exit(1);
        }
    }

    async startBackground(scriptPath, args) {
        try {
            const pidFile = './background.pid';
            const result = await this.npmBash.startBackgroundProcess(scriptPath, args, pidFile);
            console.log('Background process started:', result);
        } catch (error) {
            console.error('Failed to start background process:', error);
            process.exit(1);
        }
    }

    async stopBackground(pidFile) {
        try {
            const result = await this.npmBash.stopBackgroundProcess(pidFile || './background.pid');
            console.log('Background process result:', result);
        } catch (error) {
            console.error('Failed to stop background process:', error);
            process.exit(1);
        }
    }

    async fileOperations(operations) {
        try {
            // Parse operations from command line
            const ops = [];
            for (let i = 0; i < operations.length; i += 3) {
                if (operations[i + 2]) {
                    ops.push({
                        type: operations[i],
                        source: operations[i + 1],
                        destination: operations[i + 2]
                    });
                }
            }
            
            const result = await this.npmBash.performFileOperations(ops);
            console.log('File operations completed:', result);
        } catch (error) {
            console.error('File operations failed:', error);
            process.exit(1);
        }
    }

    async conditionalExecution(condition, scriptPath, args) {
        try {
            const result = await this.npmBash.executeConditionalScript(condition, scriptPath, args);
            console.log('Conditional execution result:', result);
        } catch (error) {
            console.error('Conditional execution failed:', error);
            process.exit(1);
        }
    }

    async environmentExecution(environment, scriptPath, args) {
        try {
            const result = await this.npmBash.executeWithEnvironment(scriptPath, environment, args);
            console.log('Environment execution result:', result);
        } catch (error) {
            console.error('Environment execution failed:', error);
            process.exit(1);
        }
    }

    async ioExecution(scriptPath, input, outputFile, args) {
        try {
            const result = await this.npmBash.executeWithIO(scriptPath, input, outputFile, args);
            console.log('I/O execution result:', result);
        } catch (error) {
            console.error('I/O execution failed:', error);
            process.exit(1);
        }
    }

    showHelp() {
        console.log(`
NPM Bash Integration CLI

Usage: node npm-bash-integration-example.js <command> [options]

Commands:
  execute <script> [args...]     Execute a bash script with arguments
  npm-run <script> [args...]     Run an npm script that calls bash
  background <script> [args...]  Start a background bash process
  stop [pid-file]               Stop a background process
  files <type> <source> <dest>  Perform file operations
  conditional <condition> <script> [args...]  Execute script if condition is met
  env <environment> <script> [args...]  Execute script with environment variables
  io <script> <input> <output> [args...]  Execute with input/output redirection

Examples:
  node npm-bash-integration-example.js execute ./scripts/backup.sh /path/to/backup
  node npm-bash-integration-example.js npm-run build
  node npm-bash-integration-example.js background ./scripts/monitor.sh
  node npm-bash-integration-example.js files copy source.txt dest.txt
  node npm-bash-integration-example.js conditional "[ -f file.txt ]" ./scripts/process.sh
  node npm-bash-integration-example.js env production ./scripts/deploy.sh
  node npm-bash-integration-example.js io ./scripts/process.sh "input data" output.txt
        `);
    }
}

// Run CLI if this file is executed directly
if (require.main === module) {
    const cli = new CLI();
    cli.run().catch(console.error);
}

module.exports = { NpmBashCLI, CLI }; 