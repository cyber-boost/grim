/**
 * Grim Scythe Page - License Management & Validation
 * Handles license tracking, validation, and management operations
 */

class GrimScythe {
    constructor() {
        this.executor = new GrimExecutor();
        this.licenses = [];
        this.licenseConfig = {
            autoValidation: true,
            notificationThreshold: 30,
            strictMode: false,
            cloudSync: true
        };
        
        this.init();
    }

    init() {
        this.setupEventListeners();
        this.loadLicenseConfig();
        this.loadLicenses();
        this.updateStats();
        this.startLiveUpdates();
        
        console.log('Grim Scythe initialized');
    }

    setupEventListeners() {
        // License management buttons
        document.getElementById('add-license-btn')?.addEventListener('click', () => this.addLicense());
        document.getElementById('validate-all-btn')?.addEventListener('click', () => this.validateAllLicenses());
        
        // License actions
        document.querySelectorAll('.license-action-btn').forEach(btn => {
            btn.addEventListener('click', (e) => {
                const action = e.currentTarget.getAttribute('data-action');
                this.performLicenseAction(action);
            });
        });

        // Configuration controls
        document.querySelectorAll('.license-config-toggle').forEach(toggle => {
            toggle.addEventListener('change', (e) => this.updateConfig(e.target));
        });
    }

    /**
     * Add a new license
     */
    async addLicense() {
        const licenseKey = document.getElementById('license-key')?.value;
        const licenseType = document.getElementById('license-type')?.value;
        const licenseUser = document.getElementById('license-user')?.value;
        
        if (!licenseKey || !licenseType) {
            alert('Please provide license key and type');
            return;
        }
        
        try {
            this.updateLicenseStatus('Adding license...', 0);
            
            const command = `grim license --add --key "${licenseKey}" --type "${licenseType}" --user "${licenseUser || 'default'}"`;
            const result = await this.executor.executeCommand(command);
            
            if (result.status === 'completed') {
                this.updateLicenseStatus('License added successfully!', 100);
                this.loadLicenses(); // Refresh list
                this.updateStats();
                this.addActivityItem('🔑', `License added: ${licenseType}`);
                
                // Clear form
                document.getElementById('license-key').value = '';
                document.getElementById('license-type').value = '';
                document.getElementById('license-user').value = '';
            }
            
        } catch (error) {
            console.error('Error adding license:', error);
            this.updateLicenseStatus('Failed to add license: ' + error.message, 0);
        }
    }

    /**
     * Load existing licenses
     */
    async loadLicenses() {
        try {
            const command = 'grim license --list --json';
            const result = await this.executor.executeCommand(command);
            
            if (result.status === 'completed') {
                this.parseLicenseList(result.output);
                this.updateLicenseDisplay();
            }
            
        } catch (error) {
            console.error('Error loading licenses:', error);
        }
    }

    /**
     * Parse license list from Grim output
     */
    parseLicenseList(output) {
        try {
            const lines = output.split('\n');
            this.licenses = [];
            
            lines.forEach(line => {
                if (line.trim()) {
                    const license = this.parseLicenseLine(line);
                    if (license) {
                        this.licenses.push(license);
                    }
                }
            });
            
        } catch (error) {
            console.error('Error parsing license list:', error);
        }
    }

    /**
     * Parse individual license line
     */
    parseLicenseLine(line) {
        // Example: "GRIM-ENTERPRISE-2024 admin@grim.so 2024-12-31 valid 100 seats"
        const match = line.match(/(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)/);
        if (match) {
            return {
                key: match[1],
                user: match[2],
                expiry: match[3],
                status: match[4],
                seats: match[5]
            };
        }
        return null;
    }

    /**
     * Update license display
     */
    updateLicenseDisplay() {
        const container = document.querySelector('.license-list');
        if (!container) return;
        
        if (this.licenses.length === 0) {
            container.innerHTML = '<div class="no-licenses">No licenses found</div>';
            return;
        }
        
        container.innerHTML = this.licenses.map(license => `
            <div class="license-item ${license.status}" data-license-key="${license.key}">
                <div class="license-info">
                    <div class="license-key">${license.key}</div>
                    <div class="license-details">
                        <span class="license-user">${license.user}</span>
                        <span class="license-expiry">${license.expiry}</span>
                        <span class="license-seats">${license.seats} seats</span>
                    </div>
                </div>
                <div class="license-status ${license.status}">${license.status}</div>
                <div class="license-actions">
                    <button class="btn btn-secondary" onclick="grimScythe.validateLicense('${license.key}')">
                        <span>✅</span> Validate
                    </button>
                    <button class="btn btn-secondary" onclick="grimScythe.renewLicense('${license.key}')">
                        <span>🔄</span> Renew
                    </button>
                    <button class="btn btn-danger" onclick="grimScythe.revokeLicense('${license.key}')">
                        <span>🚫</span> Revoke
                    </button>
                </div>
            </div>
        `).join('');
    }

    /**
     * Validate a specific license
     */
    async validateLicense(licenseKey) {
        try {
            this.updateLicenseStatus('Validating license...', 0);
            
            const command = `grim license --validate "${licenseKey}"`;
            const result = await this.executor.executeCommand(command);
            
            if (result.status === 'completed') {
                this.updateLicenseStatus('License validated successfully!', 100);
                this.addActivityItem('✅', `License validated: ${licenseKey}`);
                
                // Refresh license list
                this.loadLicenses();
            }
            
        } catch (error) {
            console.error('Error validating license:', error);
            this.updateLicenseStatus('License validation failed: ' + error.message, 0);
        }
    }

    /**
     * Validate all licenses
     */
    async validateAllLicenses() {
        try {
            this.updateLicenseStatus('Validating all licenses...', 0);
            
            const command = 'grim license --validate-all';
            const result = await this.executor.executeCommand(command);
            
            if (result.status === 'completed') {
                this.updateLicenseStatus('All licenses validated!', 100);
                this.addActivityItem('✅', 'All licenses validated successfully');
                
                // Refresh license list
                this.loadLicenses();
                this.updateStats();
            }
            
        } catch (error) {
            console.error('Error validating all licenses:', error);
            this.updateLicenseStatus('License validation failed: ' + error.message, 0);
        }
    }

    /**
     * Renew a license
     */
    async renewLicense(licenseKey) {
        try {
            this.updateLicenseStatus('Renewing license...', 0);
            
            const command = `grim license --renew "${licenseKey}"`;
            const result = await this.executor.executeCommand(command);
            
            if (result.status === 'completed') {
                this.updateLicenseStatus('License renewed successfully!', 100);
                this.addActivityItem('🔄', `License renewed: ${licenseKey}`);
                
                // Refresh license list
                this.loadLicenses();
            }
            
        } catch (error) {
            console.error('Error renewing license:', error);
            this.updateLicenseStatus('License renewal failed: ' + error.message, 0);
        }
    }

    /**
     * Revoke a license
     */
    async revokeLicense(licenseKey) {
        if (!confirm(`Are you sure you want to revoke license ${licenseKey}? This action cannot be undone.`)) {
            return;
        }
        
        try {
            this.updateLicenseStatus('Revoking license...', 0);
            
            const command = `grim license --revoke "${licenseKey}" --confirm`;
            const result = await this.executor.executeCommand(command);
            
            if (result.status === 'completed') {
                this.updateLicenseStatus('License revoked successfully!', 100);
                this.addActivityItem('🚫', `License revoked: ${licenseKey}`);
                
                // Refresh license list
                this.loadLicenses();
                this.updateStats();
            }
            
        } catch (error) {
            console.error('Error revoking license:', error);
            this.updateLicenseStatus('License revocation failed: ' + error.message, 0);
        }
    }

    /**
     * Perform specific license actions
     */
    async performLicenseAction(action) {
        const actions = {
            'license-audit': 'grim license --audit --comprehensive',
            'license-report': 'grim license --report --format html',
            'license-export': 'grim license --export --json',
            'license-sync': 'grim license --sync --cloud',
            'license-cleanup': 'grim license --cleanup --expired',
            'license-stats': 'grim license --statistics',
            'license-health': 'grim license --health-check',
            'license-backup': 'grim license --backup --encrypted'
        };

        const command = actions[action];
        if (!command) {
            console.error('Unknown action:', action);
            return;
        }

        try {
            this.updateLicenseStatus(`Starting ${action}...`, 0);
            const result = await this.executor.executeCommand(command);
            
            if (result.status === 'completed') {
                this.handleActionComplete(action, result);
            }
            
        } catch (error) {
            console.error(`${action} failed:`, error);
            this.updateLicenseStatus(`${action} failed: ${error.message}`, 0);
        }
    }

    /**
     * Handle action completion
     */
    handleActionComplete(action, result) {
        this.updateLicenseStatus(`${action} completed successfully!`, 100);
        
        // Add to activity feed
        const actionNames = {
            'license-audit': 'License Audit',
            'license-report': 'License Report Generated',
            'license-export': 'License Data Exported',
            'license-sync': 'License Cloud Sync',
            'license-cleanup': 'License Cleanup',
            'license-stats': 'License Statistics',
            'license-health': 'License Health Check',
            'license-backup': 'License Backup'
        };
        
        this.addActivityItem('🔑', `${actionNames[action]} completed`);
        
        // Refresh data if needed
        if (['license-audit', 'license-cleanup', 'license-sync'].includes(action)) {
            this.loadLicenses();
            this.updateStats();
        }
    }

    /**
     * Update license progress display
     */
    updateLicenseProgress(percentage, currentOperation) {
        const progressBar = document.getElementById('license-progress');
        const percentageSpan = document.querySelector('.license-percentage');
        const currentOperationSpan = document.getElementById('license-current-operation');
        
        if (progressBar) progressBar.style.width = percentage + '%';
        if (percentageSpan) percentageSpan.textContent = percentage + '%';
        if (currentOperationSpan) currentOperationSpan.textContent = currentOperation;
    }

    /**
     * Update license status
     */
    updateLicenseStatus(message, percentage) {
        this.updateLicenseProgress(percentage, message);
    }

    /**
     * Update statistics
     */
    updateStats() {
        const totalLicenses = this.licenses.length;
        const validLicenses = this.licenses.filter(l => l.status === 'valid').length;
        const expiredLicenses = this.licenses.filter(l => l.status === 'expired').length;
        const totalSeats = this.licenses.reduce((sum, license) => {
            const seats = parseInt(license.seats) || 0;
            return sum + seats;
        }, 0);
        
        // Update stats cards
        this.updateStatCard('total-licenses', totalLicenses.toString());
        this.updateStatCard('valid-licenses', validLicenses.toString());
        this.updateStatCard('expired-licenses', expiredLicenses.toString());
        this.updateStatCard('total-seats', totalSeats.toString());
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
            <div class="activity-icon" style="background: #6f42c1;">${icon}</div>
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
     * Load license configuration
     */
    loadLicenseConfig() {
        const saved = localStorage.getItem('grim-license-config');
        if (saved) {
            this.licenseConfig = { ...this.licenseConfig, ...JSON.parse(saved) };
        }
        
        this.updateConfigDisplay();
    }

    /**
     * Save license configuration
     */
    saveLicenseConfig() {
        localStorage.setItem('grim-license-config', JSON.stringify(this.licenseConfig));
    }

    /**
     * Update configuration display
     */
    updateConfigDisplay() {
        // Update toggles
        Object.keys(this.licenseConfig).forEach(key => {
            const toggle = document.querySelector(`[data-config="${key}"]`);
            if (toggle) {
                toggle.checked = this.licenseConfig[key];
            }
        });
    }

    /**
     * Update configuration
     */
    updateConfig(element) {
        const key = element.getAttribute('data-config');
        this.licenseConfig[key] = element.checked;
        this.saveLicenseConfig();
    }

    /**
     * Start live updates
     */
    startLiveUpdates() {
        // Update stats every 30 seconds
        setInterval(() => {
            this.updateStats();
        }, 30000);
        
        // Auto-validate licenses every hour if enabled
        if (this.licenseConfig.autoValidation) {
            setInterval(() => {
                this.validateAllLicenses();
            }, 3600000); // 1 hour
        }
    }
}

// Initialize scythe functionality when page loads
document.addEventListener('DOMContentLoaded', () => {
    window.grimScythe = new GrimScythe();
});

// Global functions for HTML onclick handlers
window.addLicense = () => window.grimScythe?.addLicense();
window.validateAllLicenses = () => window.grimScythe?.validateAllLicenses();
window.performLicenseAction = (action) => window.grimScythe?.performLicenseAction(action); 