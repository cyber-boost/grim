/**
 * System-wide JavaScript functionality for Grim Admin
 */

class GrimSystem {
    constructor() {
        this.baseUrl = window.location.origin;
        this.currentPage = this.getCurrentPage();
        this.init();
    }

    init() {
        this.setupEventListeners();
        this.initializeComponents();
        this.startSystemMonitoring();
    }

    getCurrentPage() {
        const path = window.location.pathname;
        if (path.includes('/admin/scan')) return 'scan';
        if (path.includes('/admin/backup')) return 'backup';
        if (path.includes('/admin/audit')) return 'audit';
        if (path.includes('/admin/logs')) return 'logs';
        if (path.includes('/admin/license')) return 'license';
        if (path.includes('/admin/settings')) return 'settings';
        if (path.includes('/admin/scythe')) return 'scythe';
        if (path.includes('/admin/mother-db')) return 'mother-db';
        return 'dashboard';
    }

    setupEventListeners() {
        // Global event listeners
        document.addEventListener('DOMContentLoaded', () => {
            this.initializePageSpecific();
        });

        // Handle navigation
        document.addEventListener('click', (e) => {
            if (e.target.matches('.nav-link')) {
                this.handleNavigation(e.target.href);
            }
        });
    }

    initializeComponents() {
        // Initialize common components
        this.initializeNotifications();
        this.initializeLoadingStates();
        this.initializeErrorHandling();
    }

    initializePageSpecific() {
        // Initialize page-specific functionality
        switch (this.currentPage) {
            case 'scan':
                if (window.GrimScan) {
                    new window.GrimScan();
                }
                break;
            case 'backup':
                if (window.GrimBackup) {
                    new window.GrimBackup();
                }
                break;
            case 'audit':
                if (window.GrimAudit) {
                    new window.GrimAudit();
                }
                break;
            case 'logs':
                this.initializeLogsPage();
                break;
            case 'license':
                this.initializeLicensePage();
                break;
            case 'mother-db':
                if (window.GrimMotherDB) {
                    new window.GrimMotherDB();
                }
                break;
            default:
                if (window.GrimAdmin) {
                    new window.GrimAdmin();
                }
        }
    }

    initializeNotifications() {
        // Create notification system
        this.notificationContainer = document.createElement('div');
        this.notificationContainer.id = 'notification-container';
        this.notificationContainer.style.cssText = `
            position: fixed;
            top: 20px;
            right: 20px;
            z-index: 9999;
            max-width: 400px;
        `;
        document.body.appendChild(this.notificationContainer);
    }

    initializeLoadingStates() {
        // Add loading states to buttons
        document.addEventListener('click', (e) => {
            if (e.target.matches('.btn[data-loading]')) {
                this.setButtonLoading(e.target, true);
            }
        });
    }

    initializeErrorHandling() {
        // Global error handler
        window.addEventListener('error', (e) => {
            console.error('Global error:', e.error);
            this.showNotification('An error occurred', 'error');
        });

        // Unhandled promise rejection handler
        window.addEventListener('unhandledrejection', (e) => {
            console.error('Unhandled promise rejection:', e.reason);
            this.showNotification('An error occurred', 'error');
        });
    }

    initializeLogsPage() {
        const logControls = document.getElementById('log-controls');
        if (logControls) {
            this.setupLogControls();
        }
    }

    initializeLicensePage() {
        const licenseTable = document.getElementById('license-table');
        if (licenseTable) {
            this.setupLicenseTable();
        }
    }

    setupLogControls() {
        const refreshBtn = document.getElementById('refresh-logs');
        const clearBtn = document.getElementById('clear-logs');
        const exportBtn = document.getElementById('export-logs');

        if (refreshBtn) {
            refreshBtn.addEventListener('click', () => this.refreshLogs());
        }
        if (clearBtn) {
            clearBtn.addEventListener('click', () => this.clearLogs());
        }
        if (exportBtn) {
            exportBtn.addEventListener('click', () => this.exportLogs());
        }
    }

    setupLicenseTable() {
        const table = document.getElementById('license-table');
        if (table) {
            // Add hover effects
            const rows = table.querySelectorAll('tbody tr');
            rows.forEach(row => {
                row.addEventListener('mouseenter', () => {
                    row.style.backgroundColor = '#f8f9fa';
                });
                row.addEventListener('mouseleave', () => {
                    row.style.backgroundColor = '';
                });
            });
        }
    }

    startSystemMonitoring() {
        // Monitor system health
        setInterval(() => {
            this.checkSystemHealth();
        }, 30000); // Every 30 seconds
    }

    async checkSystemHealth() {
        try {
            const response = await fetch(`${this.baseUrl}/health`);
            const data = await response.json();
            
            if (data.status !== 'healthy') {
                this.showNotification('System health check failed', 'warning');
            }
        } catch (error) {
            console.error('Health check failed:', error);
        }
    }

    showNotification(message, type = 'info') {
        const notification = document.createElement('div');
        notification.className = `notification notification-${type}`;
        notification.style.cssText = `
            background: ${type === 'error' ? '#dc3545' : type === 'warning' ? '#ffc107' : '#28a745'};
            color: white;
            padding: 12px 16px;
            border-radius: 4px;
            margin-bottom: 8px;
            box-shadow: 0 2px 8px rgba(0,0,0,0.1);
            animation: slideIn 0.3s ease;
        `;
        notification.textContent = message;

        this.notificationContainer.appendChild(notification);

        // Auto-remove after 5 seconds
        setTimeout(() => {
            notification.style.animation = 'slideOut 0.3s ease';
            setTimeout(() => {
                if (notification.parentNode) {
                    notification.parentNode.removeChild(notification);
                }
            }, 300);
        }, 5000);
    }

    setButtonLoading(button, loading) {
        if (loading) {
            button.disabled = true;
            button.dataset.originalText = button.textContent;
            button.innerHTML = '<span class="spinner"></span> Loading...';
        } else {
            button.disabled = false;
            button.textContent = button.dataset.originalText || 'Submit';
        }
    }

    async refreshLogs() {
        // Implementation for refreshing logs
        this.showNotification('Refreshing logs...', 'info');
    }

    async clearLogs() {
        if (confirm('Are you sure you want to clear all logs?')) {
            this.showNotification('Clearing logs...', 'info');
        }
    }

    async exportLogs() {
        this.showNotification('Exporting logs...', 'info');
    }

    handleNavigation(url) {
        // Handle navigation with loading states
        this.showNotification('Loading...', 'info');
    }
}

// Initialize system when DOM is ready
document.addEventListener('DOMContentLoaded', () => {
    window.grimSystem = new GrimSystem();
});

// Add CSS animations
const style = document.createElement('style');
style.textContent = `
    @keyframes slideIn {
        from { transform: translateX(100%); opacity: 0; }
        to { transform: translateX(0); opacity: 1; }
    }
    
    @keyframes slideOut {
        from { transform: translateX(0); opacity: 1; }
        to { transform: translateX(100%); opacity: 0; }
    }
    
    .spinner {
        display: inline-block;
        width: 16px;
        height: 16px;
        border: 2px solid #ffffff;
        border-radius: 50%;
        border-top-color: transparent;
        animation: spin 1s ease-in-out infinite;
    }
    
    @keyframes spin {
        to { transform: rotate(360deg); }
    }
`;
document.head.appendChild(style); 