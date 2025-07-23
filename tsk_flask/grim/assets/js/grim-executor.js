/**
 * Grim Command Executor - Web Interface
 * Handles command execution from the web UI
 */

class GrimExecutor {
    constructor(baseUrl = '') {
        this.baseUrl = baseUrl;
        this.pollingInterval = 1000; // 1 second
        this.activeCommands = new Map();
        this.commandCallbacks = new Map();
    }

    /**
     * Execute a command and return a promise
     */
    async executeCommand(commandType, commandArgs = {}) {
        try {
            const response = await fetch(`${this.baseUrl}/api/execute`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify({
                    type: commandType,
                    args: commandArgs
                })
            });

            const data = await response.json();
            
            if (data.success) {
                const commandId = data.command_id;
                this.activeCommands.set(commandId, {
                    type: commandType,
                    args: commandArgs,
                    status: 'running',
                    startTime: Date.now()
                });
                
                // Start polling for result
                this.pollCommandResult(commandId);
                
                return commandId;
            } else {
                throw new Error(data.error || 'Command execution failed');
            }
        } catch (error) {
            console.error('Command execution error:', error);
            throw error;
        }
    }

    /**
     * Poll for command result
     */
    async pollCommandResult(commandId) {
        const pollInterval = setInterval(async () => {
            try {
                const result = await this.getCommandResult(commandId);
                
                if (result) {
                    // Command completed
                    clearInterval(pollInterval);
                    this.activeCommands.delete(commandId);
                    
                    // Update command status
                    const command = this.activeCommands.get(commandId);
                    if (command) {
                        command.status = result.success ? 'completed' : 'failed';
                        command.result = result;
                        command.endTime = Date.now();
                    }
                    
                    // Trigger callbacks
                    const callbacks = this.commandCallbacks.get(commandId) || [];
                    callbacks.forEach(callback => callback(result));
                    this.commandCallbacks.delete(commandId);
                    
                }
            } catch (error) {
                console.error('Polling error:', error);
                clearInterval(pollInterval);
            }
        }, this.pollingInterval);
    }

    /**
     * Get command result
     */
    async getCommandResult(commandId) {
        try {
            const response = await fetch(`${this.baseUrl}/api/command/${commandId}`);
            
            if (response.status === 404) {
                return null; // Command still running
            }
            
            const data = await response.json();
            
            if (data.success) {
                return data.result;
            } else {
                throw new Error(data.error || 'Failed to get command result');
            }
        } catch (error) {
            console.error('Get command result error:', error);
            throw error;
        }
    }

    /**
     * Get command history
     */
    async getCommandHistory(limit = 50) {
        try {
            const response = await fetch(`${this.baseUrl}/api/commands/history?limit=${limit}`);
            const data = await response.json();
            
            if (data.success) {
                return data.history;
            } else {
                throw new Error(data.error || 'Failed to get command history');
            }
        } catch (error) {
            console.error('Get command history error:', error);
            throw error;
        }
    }

    /**
     * Get executor status
     */
    async getExecutorStatus() {
        try {
            const response = await fetch(`${this.baseUrl}/api/executor/status`);
            const data = await response.json();
            
            if (data.success) {
                return data.status;
            } else {
                throw new Error(data.error || 'Failed to get executor status');
            }
        } catch (error) {
            console.error('Get executor status error:', error);
            throw error;
        }
    }

    /**
     * Add callback for command completion
     */
    onCommandComplete(commandId, callback) {
        if (!this.commandCallbacks.has(commandId)) {
            this.commandCallbacks.set(commandId, []);
        }
        this.commandCallbacks.get(commandId).push(callback);
    }

    /**
     * Get active commands
     */
    getActiveCommands() {
        return Array.from(this.activeCommands.entries()).map(([id, command]) => ({
            id,
            ...command
        }));
    }

    /**
     * Cancel a command (if possible)
     */
    cancelCommand(commandId) {
        this.activeCommands.delete(commandId);
        this.commandCallbacks.delete(commandId);
    }

    /**
     * Convenience methods for common operations
     */
    
    // Backup operations
    async backup(sourcePath, backupName = null, type = 'grim') {
        const args = {
            type: type,
            source: sourcePath,
            name: backupName || `backup_${Date.now()}`
        };
        return this.executeCommand('backup', args);
    }

    // License operations
    async checkLicenseStatus() {
        return this.executeCommand('license', { action: 'status' });
    }

    async validateLicense(licenseKey) {
        return this.executeCommand('license', { action: 'validate', key: licenseKey });
    }

    async generateLicenseReport() {
        return this.executeCommand('license', { action: 'report' });
    }

    // System operations
    async checkSystemHealth() {
        return this.executeCommand('system', { action: 'health' });
    }

    async getSystemStatus() {
        return this.executeCommand('system', { action: 'status' });
    }

    async viewLogs(logFile = 'scythe/logs/orchestrator.log', lines = 100) {
        return this.executeCommand('logs', { 
            action: 'view', 
            file: logFile, 
            lines: lines 
        });
    }

    async searchLogs(searchTerm, logFile = 'scythe/logs/orchestrator.log') {
        return this.executeCommand('logs', { 
            action: 'search', 
            term: searchTerm, 
            file: logFile 
        });
    }

    async clearLogs(logFile = 'scythe/logs/orchestrator.log') {
        return this.executeCommand('logs', { 
            action: 'clear', 
            file: logFile 
        });
    }

    // File operations
    async listFiles(path = '.') {
        return this.executeCommand('files', { action: 'list', path: path });
    }

    async copyFile(source, dest) {
        return this.executeCommand('files', { 
            action: 'copy', 
            source: source, 
            dest: dest 
        });
    }

    async moveFile(source, dest) {
        return this.executeCommand('files', { 
            action: 'move', 
            source: source, 
            dest: dest 
        });
    }

    async deleteFile(path) {
        return this.executeCommand('files', { action: 'delete', path: path });
    }

    async changePermissions(path, mode = '755') {
        return this.executeCommand('files', { 
            action: 'chmod', 
            path: path, 
            mode: mode 
        });
    }
}

/**
 * UI Helper for command execution
 */
class GrimExecutorUI {
    constructor(executor, outputElement = null) {
        this.executor = executor;
        this.outputElement = outputElement;
        this.commandHistory = [];
    }

    /**
     * Set output element for displaying results
     */
    setOutputElement(element) {
        this.outputElement = element;
    }

    /**
     * Display command result
     */
    displayResult(result) {
        if (!this.outputElement) return;

        const timestamp = new Date(result.timestamp).toLocaleString();
        const status = result.success ? '✅ SUCCESS' : '❌ FAILED';
        const executionTime = result.execution_time.toFixed(3);

        const html = `
            <div class="command-result ${result.success ? 'success' : 'error'}">
                <div class="command-header">
                    <span class="command-status">${status}</span>
                    <span class="command-time">${executionTime}s</span>
                    <span class="command-timestamp">${timestamp}</span>
                </div>
                <div class="command-details">
                    <strong>Command:</strong> ${result.command}
                </div>
                ${result.output ? `
                    <div class="command-output">
                        <strong>Output:</strong>
                        <pre>${this.escapeHtml(result.output)}</pre>
                    </div>
                ` : ''}
                ${result.error ? `
                    <div class="command-error">
                        <strong>Error:</strong>
                        <pre>${this.escapeHtml(result.error)}</pre>
                    </div>
                ` : ''}
            </div>
        `;

        this.outputElement.insertAdjacentHTML('beforeend', html);
        this.outputElement.scrollTop = this.outputElement.scrollHeight;
    }

    /**
     * Execute command and display result
     */
    async executeAndDisplay(commandType, commandArgs = {}) {
        try {
            const commandId = await this.executor.executeCommand(commandType, commandArgs);
            
            // Add to history
            this.commandHistory.push({
                id: commandId,
                type: commandType,
                args: commandArgs,
                timestamp: new Date()
            });

            // Set up callback to display result
            this.executor.onCommandComplete(commandId, (result) => {
                this.displayResult(result);
            });

            return commandId;
        } catch (error) {
            console.error('Execute and display error:', error);
            this.displayError(error.message);
        }
    }

    /**
     * Display error message
     */
    displayError(message) {
        if (!this.outputElement) return;

        const html = `
            <div class="command-result error">
                <div class="command-header">
                    <span class="command-status">❌ ERROR</span>
                    <span class="command-timestamp">${new Date().toLocaleString()}</span>
                </div>
                <div class="command-error">
                    <strong>Error:</strong> ${this.escapeHtml(message)}
                </div>
            </div>
        `;

        this.outputElement.insertAdjacentHTML('beforeend', html);
        this.outputElement.scrollTop = this.outputElement.scrollHeight;
    }

    /**
     * Clear output
     */
    clearOutput() {
        if (this.outputElement) {
            this.outputElement.innerHTML = '';
        }
    }

    /**
     * Escape HTML for safe display
     */
    escapeHtml(text) {
        const div = document.createElement('div');
        div.textContent = text;
        return div.innerHTML;
    }

    /**
     * Get command history
     */
    getCommandHistory() {
        return this.commandHistory;
    }

    /**
     * Load command history from server
     */
    async loadCommandHistory(limit = 50) {
        try {
            const history = await this.executor.getCommandHistory(limit);
            return history;
        } catch (error) {
            console.error('Load command history error:', error);
            return [];
        }
    }
}

// Export for use in other modules
if (typeof module !== 'undefined' && module.exports) {
    module.exports = { GrimExecutor, GrimExecutorUI };
} else {
    // Browser environment
    window.GrimExecutor = GrimExecutor;
    window.GrimExecutorUI = GrimExecutorUI;
} 