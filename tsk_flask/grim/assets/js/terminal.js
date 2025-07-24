/**
 * Grim Terminal Page - Web-based Terminal Interface
 * Provides direct server access through the web UI
 */

class GrimTerminal {
    constructor() {
        this.executor = new GrimExecutor();
        this.commandHistory = [];
        this.historyIndex = -1;
        this.currentDirectory = '/opt/reaper/tsk_flask';
        this.commandsExecuted = 0;
        this.sessionStartTime = new Date();
        this.terminalConfig = {
            autoComplete: true,
            commandTimeout: 30000,
            maxHistory: 100,
            showTimestamps: true,
            syntaxHighlighting: true,
            dangerousCommands: ['rm -rf', 'dd', 'mkfs', 'fdisk', 'shutdown', 'reboot']
        };
        this.dangerousCommands = [
            'rm -rf', 'dd', 'mkfs', 'fdisk', 'shutdown', 'reboot', 
            'halt', 'poweroff', 'init 0', 'init 6', 'killall', 'pkill'
        ];
        this.init();
    }

    /**
     * Initialize terminal interface
     */
    init() {
        this.setupEventListeners();
        this.loadTerminalConfig();
        this.displayWelcomeMessage();
        this.updateTerminalInfo();
        
        console.log('Grim Terminal initialized');
    }

    /**
     * Setup event listeners for terminal interactions
     */
    setupEventListeners() {
        const terminalInput = document.getElementById('terminal-input');
        const terminalOutput = document.getElementById('terminal-output');
        const quickCommands = document.querySelectorAll('.quick-command');
        const clearBtn = document.getElementById('clear-terminal');
        const configBtn = document.getElementById('terminal-config');

        if (terminalInput) {
            terminalInput.addEventListener('keydown', (e) => this.handleKeyPress(e));
            terminalInput.addEventListener('input', (e) => this.handleInput(e));
        }

        if (clearBtn) {
            clearBtn.addEventListener('click', () => this.clearTerminal());
        }

        if (configBtn) {
            configBtn.addEventListener('click', () => this.showTerminalConfig());
        }

        // Quick command buttons
        quickCommands.forEach(btn => {
            btn.addEventListener('click', (e) => {
                const command = e.target.dataset.command;
                if (command) {
                    this.executeCommand(command);
                }
            });
        });

        // Auto-resize terminal output
        if (terminalOutput) {
            const resizeObserver = new ResizeObserver(() => {
                this.scrollToBottom();
            });
            resizeObserver.observe(terminalOutput);
        }
    }

    /**
     * Handle key press events in terminal input
     */
    handleKeyPress(e) {
        const input = e.target;
        const command = input.value.trim();

        switch (e.key) {
            case 'Enter':
                e.preventDefault();
                if (command) {
                    this.executeCommand(command);
                    input.value = '';
                }
                break;

            case 'ArrowUp':
                e.preventDefault();
                this.navigateHistory('up');
                break;

            case 'ArrowDown':
                e.preventDefault();
                this.navigateHistory('down');
                break;

            case 'Tab':
                e.preventDefault();
                if (this.terminalConfig.autoComplete) {
                    this.autoComplete(command);
                }
                break;

            case 'Escape':
                e.preventDefault();
                input.value = '';
                this.historyIndex = -1;
                break;
        }
    }

    /**
     * Handle input changes for auto-completion
     */
    handleInput(e) {
        const command = e.target.value;
        
        if (this.terminalConfig.autoComplete && command.length > 2) {
            this.showAutoCompleteSuggestions(command);
        } else {
            this.hideAutoCompleteSuggestions();
        }
    }

    /**
     * Execute a command in the terminal
     */
    async executeCommand(command) {
        if (!command.trim()) return;

        // Check for dangerous commands
        if (this.isDangerousCommand(command)) {
            const confirmed = await this.confirmDangerousCommand(command);
            if (!confirmed) {
                this.addTerminalOutput(`❌ Command cancelled: ${command}`, 'error');
                return;
            }
        }

        // Add to history
        this.addToHistory(command);
        
        // Display command
        this.addTerminalOutput(`$ ${command}`, 'command');
        
        // Execute command
        try {
            const result = await this.executor.executeCommand(command);
            this.handleCommandResult(result, command);
        } catch (error) {
            this.addTerminalOutput(`Error: ${error.message}`, 'error');
        }

        // Update stats
        this.commandsExecuted++;
        this.updateTerminalInfo();
    }

    /**
     * Handle command execution result
     */
    handleCommandResult(result, command) {
        if (result.success) {
            if (result.output) {
                this.addTerminalOutput(result.output, 'output');
            }
            if (result.error) {
                this.addTerminalOutput(result.error, 'error');
            }
        } else {
            this.addTerminalOutput(`Command failed: ${result.error || 'Unknown error'}`, 'error');
        }

        // Update current directory if cd command
        if (command.startsWith('cd ')) {
            this.updateCurrentDirectory(command);
        }
    }

    /**
     * Add output to terminal display
     */
    addTerminalOutput(content, type = 'output') {
        const terminalOutput = document.getElementById('terminal-output');
        if (!terminalOutput) return;

        const timestamp = this.terminalConfig.showTimestamps ? 
            `[${new Date().toLocaleTimeString()}] ` : '';
        
        const outputLine = document.createElement('div');
        outputLine.className = `terminal-line terminal-${type}`;
        
        if (type === 'command') {
            outputLine.innerHTML = `<span class="prompt">${timestamp}$</span> <span class="command">${content}</span>`;
        } else {
            outputLine.innerHTML = `<span class="output-content">${timestamp}${content}</span>`;
        }

        terminalOutput.appendChild(outputLine);
        this.scrollToBottom();
    }

    /**
     * Navigate command history
     */
    navigateHistory(direction) {
        const input = document.getElementById('terminal-input');
        if (!input) return;

        if (direction === 'up' && this.historyIndex < this.commandHistory.length - 1) {
            this.historyIndex++;
        } else if (direction === 'down' && this.historyIndex > -1) {
            this.historyIndex--;
        }

        if (this.historyIndex >= 0) {
            input.value = this.commandHistory[this.commandHistory.length - 1 - this.historyIndex];
        } else {
            input.value = '';
        }
    }

    /**
     * Add command to history
     */
    addToHistory(command) {
        // Remove if already exists
        const index = this.commandHistory.indexOf(command);
        if (index > -1) {
            this.commandHistory.splice(index, 1);
        }
        
        // Add to beginning
        this.commandHistory.unshift(command);
        
        // Limit history size
        if (this.commandHistory.length > this.terminalConfig.maxHistory) {
            this.commandHistory.pop();
        }

        this.saveTerminalConfig();
    }

    /**
     * Auto-complete command
     */
    autoComplete(command) {
        const suggestions = this.getAutoCompleteSuggestions(command);
        if (suggestions.length > 0) {
            const input = document.getElementById('terminal-input');
            input.value = suggestions[0];
            input.setSelectionRange(command.length, suggestions[0].length);
        }
    }

    /**
     * Get auto-complete suggestions
     */
    getAutoCompleteSuggestions(command) {
        const commonCommands = [
            'ls', 'cd', 'pwd', 'cat', 'grep', 'find', 'ps', 'top', 'htop',
            'df', 'du', 'free', 'uptime', 'whoami', 'date', 'echo', 'clear',
            'vim', 'nano', 'less', 'more', 'head', 'tail', 'wc', 'sort',
            'uniq', 'cut', 'awk', 'sed', 'tar', 'gzip', 'gunzip', 'zip',
            'unzip', 'scp', 'rsync', 'ssh', 'wget', 'curl', 'git', 'docker',
            'systemctl', 'service', 'journalctl', 'logrotate', 'crontab'
        ];

        return commonCommands.filter(cmd => 
            cmd.startsWith(command.toLowerCase())
        );
    }

    /**
     * Show auto-complete suggestions
     */
    showAutoCompleteSuggestions(command) {
        const suggestions = this.getAutoCompleteSuggestions(command);
        if (suggestions.length === 0) return;

        let suggestionsDiv = document.getElementById('auto-complete-suggestions');
        if (!suggestionsDiv) {
            suggestionsDiv = document.createElement('div');
            suggestionsDiv.id = 'auto-complete-suggestions';
            suggestionsDiv.className = 'auto-complete-suggestions';
            document.getElementById('terminal-container').appendChild(suggestionsDiv);
        }

        suggestionsDiv.innerHTML = suggestions
            .slice(0, 5)
            .map(suggestion => `<div class="suggestion">${suggestion}</div>`)
            .join('');

        suggestionsDiv.style.display = 'block';
    }

    /**
     * Hide auto-complete suggestions
     */
    hideAutoCompleteSuggestions() {
        const suggestionsDiv = document.getElementById('auto-complete-suggestions');
        if (suggestionsDiv) {
            suggestionsDiv.style.display = 'none';
        }
    }

    /**
     * Check if command is dangerous
     */
    isDangerousCommand(command) {
        return this.dangerousCommands.some(dangerous => 
            command.toLowerCase().includes(dangerous.toLowerCase())
        );
    }

    /**
     * Confirm dangerous command execution
     */
    async confirmDangerousCommand(command) {
        return new Promise((resolve) => {
            const modal = document.createElement('div');
            modal.className = 'dangerous-command-modal';
            modal.innerHTML = `
                <div class="modal-content">
                    <h3>⚠️ Dangerous Command Warning</h3>
                    <p>The command <code>${command}</code> could be dangerous and may cause data loss or system damage.</p>
                    <p>Are you sure you want to execute this command?</p>
                    <div class="modal-actions">
                        <button class="btn btn-danger" id="confirm-dangerous">Yes, Execute</button>
                        <button class="btn btn-secondary" id="cancel-dangerous">Cancel</button>
                    </div>
                </div>
            `;

            document.body.appendChild(modal);

            modal.querySelector('#confirm-dangerous').addEventListener('click', () => {
                document.body.removeChild(modal);
                resolve(true);
            });

            modal.querySelector('#cancel-dangerous').addEventListener('click', () => {
                document.body.removeChild(modal);
                resolve(false);
            });
        });
    }

    /**
     * Update current directory
     */
    updateCurrentDirectory(command) {
        const match = command.match(/cd\s+(.+)/);
        if (match) {
            const path = match[1].trim();
            if (path === '~' || path === '$HOME') {
                this.currentDirectory = process.env.HOME || '/root';
            } else if (path.startsWith('/')) {
                this.currentDirectory = path;
            } else {
                this.currentDirectory = `${this.currentDirectory}/${path}`;
            }
            this.updateTerminalInfo();
        }
    }

    /**
     * Clear terminal output
     */
    clearTerminal() {
        const terminalOutput = document.getElementById('terminal-output');
        if (terminalOutput) {
            terminalOutput.innerHTML = '';
            this.displayWelcomeMessage();
        }
    }

    /**
     * Display welcome message
     */
    displayWelcomeMessage() {
        this.addTerminalOutput('Welcome to Grim Terminal - Web-based Server Access', 'info');
        this.addTerminalOutput(`Current directory: ${this.currentDirectory}`, 'info');
        this.addTerminalOutput('Type "help" for available commands or use the quick command buttons above.', 'info');
        this.addTerminalOutput('', 'output');
    }

    /**
     * Update terminal information display
     */
    updateTerminalInfo() {
        const sessionTime = document.getElementById('session-time');
        const commandsExecuted = document.getElementById('commands-executed');
        const currentDir = document.getElementById('current-directory');

        if (sessionTime) {
            const elapsed = Math.floor((new Date() - this.sessionStartTime) / 1000);
            const hours = Math.floor(elapsed / 3600);
            const minutes = Math.floor((elapsed % 3600) / 60);
            const seconds = elapsed % 60;
            sessionTime.textContent = `${hours}h ${minutes}m ${seconds}s`;
        }

        if (commandsExecuted) {
            commandsExecuted.textContent = this.commandsExecuted.toString();
        }

        if (currentDir) {
            currentDir.textContent = this.currentDirectory;
        }
    }

    /**
     * Show terminal configuration modal
     */
    showTerminalConfig() {
        const modal = document.createElement('div');
        modal.className = 'terminal-config-modal';
        modal.innerHTML = `
            <div class="modal-content">
                <h3>Terminal Configuration</h3>
                <div class="config-option">
                    <label>
                        <input type="checkbox" id="auto-complete" ${this.terminalConfig.autoComplete ? 'checked' : ''}>
                        Enable Auto-completion
                    </label>
                </div>
                <div class="config-option">
                    <label>
                        <input type="checkbox" id="show-timestamps" ${this.terminalConfig.showTimestamps ? 'checked' : ''}>
                        Show Timestamps
                    </label>
                </div>
                <div class="config-option">
                    <label>
                        <input type="checkbox" id="syntax-highlighting" ${this.terminalConfig.syntaxHighlighting ? 'checked' : ''}>
                        Syntax Highlighting
                    </label>
                </div>
                <div class="config-option">
                    <label>Command Timeout (ms):</label>
                    <input type="number" id="command-timeout" value="${this.terminalConfig.commandTimeout}">
                </div>
                <div class="config-option">
                    <label>Max History:</label>
                    <input type="number" id="max-history" value="${this.terminalConfig.maxHistory}">
                </div>
                <div class="modal-actions">
                    <button class="btn btn-primary" id="save-config">Save Configuration</button>
                    <button class="btn btn-secondary" id="cancel-config">Cancel</button>
                </div>
            </div>
        `;

        document.body.appendChild(modal);

        modal.querySelector('#save-config').addEventListener('click', () => {
            this.saveTerminalConfigFromModal();
            document.body.removeChild(modal);
        });

        modal.querySelector('#cancel-config').addEventListener('click', () => {
            document.body.removeChild(modal);
        });
    }

    /**
     * Save terminal configuration from modal
     */
    saveTerminalConfigFromModal() {
        this.terminalConfig.autoComplete = document.getElementById('auto-complete').checked;
        this.terminalConfig.showTimestamps = document.getElementById('show-timestamps').checked;
        this.terminalConfig.syntaxHighlighting = document.getElementById('syntax-highlighting').checked;
        this.terminalConfig.commandTimeout = parseInt(document.getElementById('command-timeout').value);
        this.terminalConfig.maxHistory = parseInt(document.getElementById('max-history').value);

        this.saveTerminalConfig();
    }

    /**
     * Load terminal configuration from localStorage
     */
    loadTerminalConfig() {
        const saved = localStorage.getItem('grim_terminal_config');
        if (saved) {
            try {
                const config = JSON.parse(saved);
                this.terminalConfig = { ...this.terminalConfig, ...config };
            } catch (error) {
                console.warn('Failed to load terminal config:', error);
            }
        }
    }

    /**
     * Save terminal configuration to localStorage
     */
    saveTerminalConfig() {
        try {
            localStorage.setItem('grim_terminal_config', JSON.stringify(this.terminalConfig));
            localStorage.setItem('grim_terminal_history', JSON.stringify(this.commandHistory));
        } catch (error) {
            console.warn('Failed to save terminal config:', error);
        }
    }

    /**
     * Scroll terminal output to bottom
     */
    scrollToBottom() {
        const terminalOutput = document.getElementById('terminal-output');
        if (terminalOutput) {
            terminalOutput.scrollTop = terminalOutput.scrollHeight;
        }
    }

    /**
     * Get terminal statistics
     */
    getTerminalStats() {
        return {
            commandsExecuted: this.commandsExecuted,
            sessionDuration: new Date() - this.sessionStartTime,
            currentDirectory: this.currentDirectory,
            historySize: this.commandHistory.length,
            config: this.terminalConfig
        };
    }
}

// Initialize terminal when page loads
document.addEventListener('DOMContentLoaded', () => {
    new GrimTerminal();
}); 