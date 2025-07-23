/**
 * Grim Audit Page - Security & System Auditing
 * Handles security scanning, audit trails, and compliance monitoring
 */

class GrimAudit {
    constructor() {
        this.executor = new GrimExecutor();
        this.auditResults = {
            securityIssues: [],
            complianceViolations: [],
            accessLogs: [],
            systemEvents: []
        };
        this.auditConfig = {
            securityLevel: 'high',
            complianceStandards: ['PCI', 'SOX', 'HIPAA'],
            retentionDays: 90,
            realTimeMonitoring: true
        };
        
        this.init();
    }

    init() {
        this.setupEventListeners();
        this.loadAuditConfig();
        this.startSecurityScan();
        this.updateStats();
        this.startLiveUpdates();
        
        console.log('Grim Audit initialized');
    }

    setupEventListeners() {
        // Security scan buttons
        document.getElementById('security-scan-btn')?.addEventListener('click', () => this.startSecurityScan());
        
        // Audit actions
        document.querySelectorAll('.audit-action-btn').forEach(btn => {
            btn.addEventListener('click', (e) => {
                const action = e.currentTarget.getAttribute('data-action');
                this.performAuditAction(action);
            });
        });

        // Configuration controls
        document.querySelectorAll('.audit-config-toggle').forEach(toggle => {
            toggle.addEventListener('change', (e) => this.updateConfig(e.target));
        });
    }

    /**
     * Start security scan
     */
    async startSecurityScan() {
        try {
            this.updateAuditStatus('Starting security scan...', 0);
            this.disableAuditControls();
            
            const command = `grim security-scan --level ${this.auditConfig.securityLevel} --comprehensive`;
            this.currentScan = await this.executor.executeCommand(command);
            
            this.monitorSecurityScan();
            
        } catch (error) {
            console.error('Security scan failed:', error);
            this.updateAuditStatus('Security scan failed: ' + error.message, 0);
            this.enableAuditControls();
        }
    }

    /**
     * Monitor security scan progress
     */
    async monitorSecurityScan() {
        if (!this.currentScan) return;
        
        const pollInterval = setInterval(async () => {
            try {
                const result = await this.executor.getCommandResult(this.currentScan.id);
                
                if (result && result.success) {
                    clearInterval(pollInterval);
                    this.handleSecurityScanComplete(result);
                } else if (result && !result.success) {
                    clearInterval(pollInterval);
                    this.handleSecurityScanError(result.error || 'Scan failed');
                } else {
                    // Command still running, update progress
                    this.updateAuditProgress(50, 'Scanning...');
                }
                
            } catch (error) {
                console.error('Error monitoring security scan:', error);
            }
        }, 1000);
    }

    /**
     * Handle security scan completion
     */
    handleSecurityScanComplete(result) {
        this.updateAuditStatus('Security scan completed!', 100);
        this.enableAuditControls();
        
        // Parse security results
        this.parseSecurityResults(result);
        this.updateSecurityDisplay();
        this.updateStats();
        
        // Add to activity feed
        this.addActivityItem('🔒', `Security scan completed: ${this.auditResults.securityIssues.length} issues found`);
    }

    /**
     * Parse security scan results
     */
    parseSecurityResults(result) {
        // Reset results
        this.auditResults.securityIssues = [];
        
        try {
            const lines = result.output.split('\n');
            
            lines.forEach(line => {
                if (line.includes('CRITICAL:') || line.includes('HIGH:') || line.includes('MEDIUM:') || line.includes('LOW:')) {
                    this.auditResults.securityIssues.push(this.parseSecurityIssue(line));
                }
            });
        } catch (error) {
            console.error('Error parsing security results:', error);
        }
    }

    /**
     * Parse security issue from scan output
     */
    parseSecurityIssue(line) {
        // Example: "CRITICAL: Weak password policy detected in /etc/passwd"
        const match = line.match(/(CRITICAL|HIGH|MEDIUM|LOW):\s+(.+)/);
        if (match) {
            return {
                severity: match[1].toLowerCase(),
                description: match[2],
                timestamp: new Date().toISOString(),
                status: 'open'
            };
        }
        return null;
    }

    /**
     * Update security issues display
     */
    updateSecurityDisplay() {
        const container = document.querySelector('.security-issues');
        if (!container) return;
        
        // Group issues by severity
        const critical = this.auditResults.securityIssues.filter(i => i.severity === 'critical');
        const high = this.auditResults.securityIssues.filter(i => i.severity === 'high');
        const medium = this.auditResults.securityIssues.filter(i => i.severity === 'medium');
        const low = this.auditResults.securityIssues.filter(i => i.severity === 'low');
        
        container.innerHTML = `
            <div class="security-category critical">
                <h4>🚨 Critical Issues (${critical.length})</h4>
                ${this.renderSecurityIssues(critical)}
            </div>
            <div class="security-category high">
                <h4>⚠️ High Priority (${high.length})</h4>
                ${this.renderSecurityIssues(high)}
            </div>
            <div class="security-category medium">
                <h4>⚡ Medium Priority (${medium.length})</h4>
                ${this.renderSecurityIssues(medium)}
            </div>
            <div class="security-category low">
                <h4>ℹ️ Low Priority (${low.length})</h4>
                ${this.renderSecurityIssues(low)}
            </div>
        `;
    }

    /**
     * Render security issues for a category
     */
    renderSecurityIssues(issues) {
        if (issues.length === 0) {
            return '<div class="no-issues">No issues found</div>';
        }
        
        return issues.map(issue => `
            <div class="security-issue ${issue.severity}">
                <div class="issue-content">
                    <div class="issue-description">${issue.description}</div>
                    <div class="issue-timestamp">${this.formatDate(issue.timestamp)}</div>
                </div>
                <div class="issue-actions">
                    <button class="btn btn-secondary" onclick="grimAudit.fixIssue('${issue.description}')">
                        <span>🔧</span> Fix
                    </button>
                    <button class="btn btn-secondary" onclick="grimAudit.ignoreIssue('${issue.description}')">
                        <span>👁️</span> Ignore
                    </button>
                </div>
            </div>
        `).join('');
    }

    /**
     * Fix a security issue
     */
    async fixIssue(issueDescription) {
        try {
            this.updateAuditStatus('Fixing security issue...', 0);
            
            const command = `grim security-scan --fix "${issueDescription}"`;
            const result = await this.executor.executeCommand(command);
            
            if (result.status === 'completed') {
                this.updateAuditStatus('Issue fixed successfully!', 100);
                this.addActivityItem('🔧', `Security issue fixed: ${issueDescription}`);
                
                // Refresh security scan
                setTimeout(() => this.startSecurityScan(), 2000);
            }
            
        } catch (error) {
            console.error('Error fixing issue:', error);
            this.updateAuditStatus('Failed to fix issue: ' + error.message, 0);
        }
    }

    /**
     * Ignore a security issue
     */
    async ignoreIssue(issueDescription) {
        try {
            const command = `grim security-scan --ignore "${issueDescription}"`;
            const result = await this.executor.executeCommand(command);
            
            if (result.status === 'completed') {
                this.addActivityItem('👁️', `Security issue ignored: ${issueDescription}`);
                
                // Remove from display
                this.auditResults.securityIssues = this.auditResults.securityIssues.filter(
                    issue => issue.description !== issueDescription
                );
                this.updateSecurityDisplay();
            }
            
        } catch (error) {
            console.error('Error ignoring issue:', error);
        }
    }

    /**
     * Start compliance audit
     */
    async startComplianceAudit() {
        try {
            this.updateAuditStatus('Starting compliance audit...', 0);
            
            const standards = this.auditConfig.complianceStandards.join(',');
            const command = `grim audit --compliance --standards "${standards}"`;
            const result = await this.executor.executeCommand(command);
            
            if (result.status === 'completed') {
                this.handleComplianceAuditComplete(result);
            }
            
        } catch (error) {
            console.error('Compliance audit failed:', error);
            this.updateAuditStatus('Compliance audit failed: ' + error.message, 0);
        }
    }

    /**
     * Handle compliance audit completion
     */
    handleComplianceAuditComplete(result) {
        this.updateAuditStatus('Compliance audit completed!', 100);
        
        // Parse compliance results
        this.parseComplianceResults(result);
        this.updateComplianceDisplay();
        
        this.addActivityItem('📋', 'Compliance audit completed');
    }

    /**
     * Parse compliance results
     */
    parseComplianceResults(result) {
        this.auditResults.complianceViolations = [];
        
        try {
            const lines = result.output.split('\n');
            
            lines.forEach(line => {
                if (line.includes('VIOLATION:') || line.includes('NON-COMPLIANT:')) {
                    this.auditResults.complianceViolations.push(this.parseComplianceViolation(line));
                }
            });
        } catch (error) {
            console.error('Error parsing compliance results:', error);
        }
    }

    /**
     * Parse compliance violation
     */
    parseComplianceViolation(line) {
        // Example: "VIOLATION: PCI-DSS 3.4 - Encryption not enabled for sensitive data"
        const match = line.match(/(VIOLATION|NON-COMPLIANT):\s+(.+)/);
        if (match) {
            return {
                type: match[1].toLowerCase(),
                description: match[2],
                timestamp: new Date().toISOString(),
                status: 'open'
            };
        }
        return null;
    }

    /**
     * Update compliance display
     */
    updateComplianceDisplay() {
        const container = document.querySelector('.compliance-violations');
        if (!container) return;
        
        if (this.auditResults.complianceViolations.length === 0) {
            container.innerHTML = '<div class="no-violations">✅ All compliance standards met</div>';
            return;
        }
        
        container.innerHTML = this.auditResults.complianceViolations.map(violation => `
            <div class="compliance-violation">
                <div class="violation-content">
                    <div class="violation-description">${violation.description}</div>
                    <div class="violation-timestamp">${this.formatDate(violation.timestamp)}</div>
                </div>
                <div class="violation-actions">
                    <button class="btn btn-secondary" onclick="grimAudit.remediateViolation('${violation.description}')">
                        <span>🔧</span> Remediate
                    </button>
                </div>
            </div>
        `).join('');
    }

    /**
     * Remediate compliance violation
     */
    async remediateViolation(violationDescription) {
        try {
            this.updateAuditStatus('Remediating compliance violation...', 0);
            
            const command = `grim audit --remediate "${violationDescription}"`;
            const result = await this.executor.executeCommand(command);
            
            if (result.status === 'completed') {
                this.updateAuditStatus('Violation remediated successfully!', 100);
                this.addActivityItem('🔧', `Compliance violation remediated: ${violationDescription}`);
                
                // Remove from display
                this.auditResults.complianceViolations = this.auditResults.complianceViolations.filter(
                    violation => violation.description !== violationDescription
                );
                this.updateComplianceDisplay();
            }
            
        } catch (error) {
            console.error('Error remediating violation:', error);
            this.updateAuditStatus('Failed to remediate violation: ' + error.message, 0);
        }
    }

    /**
     * Load access logs
     */
    async loadAccessLogs() {
        try {
            const command = `grim audit --access-logs --limit 100`;
            const result = await this.executor.executeCommand(command);
            
            if (result.status === 'completed') {
                this.parseAccessLogs(result.output);
                this.updateAccessLogsDisplay();
            }
            
        } catch (error) {
            console.error('Error loading access logs:', error);
        }
    }

    /**
     * Parse access logs
     */
    parseAccessLogs(output) {
        this.auditResults.accessLogs = [];
        
        try {
            const lines = output.split('\n');
            
            lines.forEach(line => {
                if (line.trim()) {
                    const logEntry = this.parseLogEntry(line);
                    if (logEntry) {
                        this.auditResults.accessLogs.push(logEntry);
                    }
                }
            });
        } catch (error) {
            console.error('Error parsing access logs:', error);
        }
    }

    /**
     * Parse log entry
     */
    parseLogEntry(line) {
        // Example: "2024-01-15 10:30:00 192.168.1.100 admin@grim.so LOGIN_SUCCESS"
        const match = line.match(/(\S+\s+\S+)\s+(\S+)\s+(\S+)\s+(\S+)/);
        if (match) {
            return {
                timestamp: match[1],
                ip: match[2],
                user: match[3],
                action: match[4]
            };
        }
        return null;
    }

    /**
     * Update access logs display
     */
    updateAccessLogsDisplay() {
        const container = document.querySelector('.access-logs');
        if (!container) return;
        
        container.innerHTML = this.auditResults.accessLogs.map(log => `
            <div class="log-entry ${this.getLogEntryClass(log.action)}">
                <div class="log-timestamp">${log.timestamp}</div>
                <div class="log-ip">${log.ip}</div>
                <div class="log-user">${log.user}</div>
                <div class="log-action">${log.action}</div>
            </div>
        `).join('');
    }

    /**
     * Get CSS class for log entry based on action
     */
    getLogEntryClass(action) {
        if (action.includes('SUCCESS')) return 'success';
        if (action.includes('FAILED') || action.includes('ERROR')) return 'error';
        if (action.includes('WARNING')) return 'warning';
        return 'info';
    }

    /**
     * Perform specific audit actions
     */
    async performAuditAction(action) {
        const actions = {
            'compliance-audit': 'grim audit --compliance --full',
            'access-audit': 'grim audit --access --detailed',
            'system-audit': 'grim audit --system --comprehensive',
            'generate-report': 'grim audit --report --format html',
            'export-audit': 'grim audit --export --json',
            'audit-health': 'grim audit --health-check',
            'audit-stats': 'grim audit --statistics',
            'audit-cleanup': 'grim audit --cleanup --older-than 90'
        };

        const command = actions[action];
        if (!command) {
            console.error('Unknown action:', action);
            return;
        }

        try {
            this.updateAuditStatus(`Starting ${action}...`, 0);
            const result = await this.executor.executeCommand(command);
            
            if (result.status === 'completed') {
                this.handleActionComplete(action, result);
            }
            
        } catch (error) {
            console.error(`${action} failed:`, error);
            this.updateAuditStatus(`${action} failed: ${error.message}`, 0);
        }
    }

    /**
     * Handle action completion
     */
    handleActionComplete(action, result) {
        this.updateAuditStatus(`${action} completed successfully!`, 100);
        
        // Add to activity feed
        const actionNames = {
            'compliance-audit': 'Compliance Audit',
            'access-audit': 'Access Audit',
            'system-audit': 'System Audit',
            'generate-report': 'Audit Report Generated',
            'export-audit': 'Audit Data Exported',
            'audit-health': 'Audit Health Check',
            'audit-stats': 'Audit Statistics',
            'audit-cleanup': 'Audit Cleanup'
        };
        
        this.addActivityItem('📊', `${actionNames[action]} completed`);
        
        // Refresh data if needed
        if (action === 'access-audit') {
            this.loadAccessLogs();
        }
    }

    /**
     * Update audit progress display
     */
    updateAuditProgress(percentage, currentCheck) {
        const progressBar = document.getElementById('audit-progress');
        const percentageSpan = document.querySelector('.audit-percentage');
        const currentCheckSpan = document.getElementById('audit-current-check');
        
        if (progressBar) progressBar.style.width = percentage + '%';
        if (percentageSpan) percentageSpan.textContent = percentage + '%';
        if (currentCheckSpan) currentCheckSpan.textContent = currentCheck;
    }

    /**
     * Update audit status
     */
    updateAuditStatus(message, percentage) {
        this.updateAuditProgress(percentage, message);
    }

    /**
     * Disable audit controls during operation
     */
    disableAuditControls() {
        const scanBtn = document.getElementById('security-scan-btn');
        if (scanBtn) scanBtn.disabled = true;
    }

    /**
     * Enable audit controls after operation
     */
    enableAuditControls() {
        const scanBtn = document.getElementById('security-scan-btn');
        if (scanBtn) scanBtn.disabled = false;
    }

    /**
     * Update statistics
     */
    updateStats() {
        const criticalIssues = this.auditResults.securityIssues.filter(i => i.severity === 'critical').length;
        const totalIssues = this.auditResults.securityIssues.length;
        const complianceViolations = this.auditResults.complianceViolations.length;
        const accessLogs = this.auditResults.accessLogs.length;
        
        // Update stats cards
        this.updateStatCard('critical-issues', criticalIssues.toString());
        this.updateStatCard('total-issues', totalIssues.toString());
        this.updateStatCard('compliance-violations', complianceViolations.toString());
        this.updateStatCard('access-logs', accessLogs.toString());
    }

    /**
     * Update individual stat card
     */
    updateStatCard(statId, value) {
        const statElement = document.querySelector(`[data-stat="${statId}"] .stat-value`);
        if (statElement) {
            statElement.textContent = value;
        }
    }

    /**
     * Add activity item to timeline
     */
    addActivityItem(icon, title) {
        const activityFeed = document.querySelector('.activity-feed');
        if (!activityFeed) return;
        
        const activityItem = document.createElement('div');
        activityItem.className = 'activity-item';
        activityItem.innerHTML = `
            <div class="activity-icon" style="background: #dc3545;">${icon}</div>
            <div class="activity-content">
                <div class="activity-title">${title}</div>
                <div class="activity-time">Just now</div>
            </div>
        `;
        
        activityFeed.insertBefore(activityItem, activityFeed.firstChild);
        
        // Remove old items if too many
        const items = activityFeed.querySelectorAll('.activity-item');
        if (items.length > 10) {
            items[items.length - 1].remove();
        }
    }

    /**
     * Load audit configuration
     */
    loadAuditConfig() {
        const saved = localStorage.getItem('grim-audit-config');
        if (saved) {
            this.auditConfig = { ...this.auditConfig, ...JSON.parse(saved) };
        }
        
        this.updateConfigDisplay();
    }

    /**
     * Save audit configuration
     */
    saveAuditConfig() {
        localStorage.setItem('grim-audit-config', JSON.stringify(this.auditConfig));
    }

    /**
     * Update configuration display
     */
    updateConfigDisplay() {
        // Update toggles
        Object.keys(this.auditConfig).forEach(key => {
            const toggle = document.querySelector(`[data-config="${key}"]`);
            if (toggle) {
                toggle.checked = this.auditConfig[key];
            }
        });
    }

    /**
     * Update configuration
     */
    updateConfig(element) {
        const key = element.getAttribute('data-config');
        this.auditConfig[key] = element.checked;
        this.saveAuditConfig();
    }

    /**
     * Format date for display
     */
    formatDate(dateStr) {
        const date = new Date(dateStr);
        return date.toLocaleDateString() + ' ' + date.toLocaleTimeString();
    }

    /**
     * Start live updates
     */
    startLiveUpdates() {
        // Update stats every 30 seconds
        setInterval(() => {
            this.updateStats();
        }, 30000);
        
        // Load access logs every 5 minutes
        setInterval(() => {
            this.loadAccessLogs();
        }, 300000);
    }
}

// Initialize audit functionality when page loads
document.addEventListener('DOMContentLoaded', () => {
    window.grimAudit = new GrimAudit();
});

// Global functions for HTML onclick handlers
window.startSecurityScan = () => window.grimAudit?.startSecurityScan();
window.performAuditAction = (action) => window.grimAudit?.performAuditAction(action); 