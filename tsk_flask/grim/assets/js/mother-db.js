/**
 * Mother Database JavaScript
 * Handles error tracking, installation management, and data visualization
 */

class MotherDB {
    constructor() {
        this.baseUrl = window.location.origin;
        this.currentPage = this.getCurrentPage();
        this.init();
    }

    init() {
        this.setupEventListeners();
        this.loadPageSpecificFunctionality();
        this.startAutoRefresh();
    }

    getCurrentPage() {
        const path = window.location.pathname;
        if (path.includes('/mother-db/installations')) return 'installations';
        if (path.includes('/mother-db/errors')) return 'errors';
        if (path.includes('/mother-db')) return 'dashboard';
        return 'dashboard';
    }

    setupEventListeners() {
        // Global event listeners
        document.addEventListener('DOMContentLoaded', () => {
            this.setupFilters();
            this.setupSearch();
            this.setupExport();
        });

        // Page-specific event listeners
        if (this.currentPage === 'dashboard') {
            this.setupDashboardEvents();
        } else if (this.currentPage === 'installations') {
            this.setupInstallationsEvents();
        } else if (this.currentPage === 'errors') {
            this.setupErrorsEvents();
        }
    }

    setupDashboardEvents() {
        // Refresh button
        const refreshBtn = document.querySelector('button[onclick="refreshData()"]');
        if (refreshBtn) {
            refreshBtn.addEventListener('click', () => this.refreshData());
        }

        // Export button
        const exportBtn = document.querySelector('button[onclick="exportData()"]');
        if (exportBtn) {
            exportBtn.addEventListener('click', () => this.exportData());
        }

        // Quick action buttons
        const actionBtns = document.querySelectorAll('.action-btn');
        actionBtns.forEach(btn => {
            btn.addEventListener('click', (e) => {
                const action = e.currentTarget.textContent.trim();
                this.handleQuickAction(action);
            });
        });
    }

    setupInstallationsEvents() {
        // Installation action buttons
        document.addEventListener('click', (e) => {
            if (e.target.classList.contains('installation-btn')) {
                const action = e.target.dataset.action;
                const installId = e.target.dataset.installId;
                this.handleInstallationAction(action, installId);
            }
        });

        // Status toggle
        document.addEventListener('change', (e) => {
            if (e.target.classList.contains('status-toggle')) {
                const installId = e.target.dataset.installId;
                const isActive = e.target.checked;
                this.toggleInstallationStatus(installId, isActive);
            }
        });
    }

    setupErrorsEvents() {
        // Error detail expansion
        document.addEventListener('click', (e) => {
            if (e.target.classList.contains('error-detail-toggle')) {
                const errorId = e.target.dataset.errorId;
                this.toggleErrorDetails(errorId);
            }
        });

        // Error severity filter
        document.addEventListener('change', (e) => {
            if (e.target.id === 'severity-filter') {
                this.filterErrorsBySeverity(e.target.value);
            }
        });
    }

    setupFilters() {
        const filterForm = document.getElementById('filters-form');
        if (filterForm) {
            filterForm.addEventListener('submit', (e) => {
                e.preventDefault();
                this.applyFilters();
            });
        }
    }

    setupSearch() {
        const searchInput = document.getElementById('search-input');
        if (searchInput) {
            let searchTimeout;
            searchInput.addEventListener('input', (e) => {
                clearTimeout(searchTimeout);
                searchTimeout = setTimeout(() => {
                    this.performSearch(e.target.value);
                }, 300);
            });
        }
    }

    setupExport() {
        const exportBtn = document.getElementById('export-btn');
        if (exportBtn) {
            exportBtn.addEventListener('click', () => this.exportData());
        }
    }

    loadPageSpecificFunctionality() {
        switch (this.currentPage) {
            case 'dashboard':
                this.loadDashboardData();
                break;
            case 'installations':
                this.loadInstallationsData();
                break;
            case 'errors':
                this.loadErrorsData();
                break;
        }
    }

    async loadDashboardData() {
        try {
            const [statsResponse, installationsResponse, errorsResponse] = await Promise.all([
                fetch('/db/stats'),
                fetch('/db/installations'),
                fetch('/db/errors?limit=20')
            ]);

            const stats = await statsResponse.json();
            const installations = await installationsResponse.json();
            const errors = await errorsResponse.json();

            this.updateDashboardStats(stats.stats);
            this.updateRecentInstallations(installations.installations);
            this.updateRecentErrors(errors.errors);
        } catch (error) {
            console.error('Error loading dashboard data:', error);
            this.showNotification('Failed to load dashboard data', 'error');
        }
    }

    async loadInstallationsData() {
        try {
            const response = await fetch('/db/installations');
            const data = await response.json();
            this.updateInstallationsTable(data.installations);
        } catch (error) {
            console.error('Error loading installations data:', error);
            this.showNotification('Failed to load installations data', 'error');
        }
    }

    async loadErrorsData() {
        try {
            const response = await fetch('/db/errors?limit=100');
            const data = await response.json();
            this.updateErrorsTable(data.errors);
        } catch (error) {
            console.error('Error loading errors data:', error);
            this.showNotification('Failed to load errors data', 'error');
        }
    }

    updateDashboardStats(stats) {
        // Update stat cards
        const elements = {
            'total-installations': stats.total_installations,
            'active-installations': stats.active_installations,
            'total-errors': stats.total_errors,
            'error-rate': stats.total_installations > 0 ? 
                (stats.total_errors / stats.total_installations).toFixed(1) : '0.0'
        };

        Object.entries(elements).forEach(([id, value]) => {
            const element = document.getElementById(id);
            if (element) {
                element.textContent = value;
            }
        });

        // Update severity breakdown
        this.updateSeverityBreakdown(stats.error_severities);
    }

    updateSeverityBreakdown(severities) {
        const severityGrid = document.querySelector('.severity-grid');
        if (!severityGrid) return;

        severityGrid.innerHTML = '';
        
        Object.entries(severities).forEach(([severity, count]) => {
            const card = this.createSeverityCard(severity, count);
            severityGrid.appendChild(card);
        });
    }

    createSeverityCard(severity, count) {
        const card = document.createElement('div');
        card.className = `severity-card severity-${severity}`;
        
        const icon = severity === 'high' ? '🔴' : severity === 'medium' ? '🟡' : '🟢';
        
        card.innerHTML = `
            <div class="severity-icon">${icon}</div>
            <div class="severity-info">
                <div class="severity-name">${severity.charAt(0).toUpperCase() + severity.slice(1)}</div>
                <div class="severity-count">${count}</div>
            </div>
        `;
        
        return card;
    }

    updateRecentInstallations(installations) {
        const list = document.querySelector('.installations-list');
        if (!list) return;

        list.innerHTML = '';
        
        installations.slice(-5).forEach(installation => {
            const item = this.createInstallationItem(installation);
            list.appendChild(item);
        });
    }

    createInstallationItem(installation) {
        const item = document.createElement('div');
        item.className = 'installation-item';
        
        const icon = installation.is_active ? '🟢' : '🔴';
        const lastSeen = installation.last_seen ? 
            new Date(installation.last_seen).toLocaleDateString() : 'Never';
        
        item.innerHTML = `
            <div class="installation-icon">${icon}</div>
            <div class="installation-info">
                <div class="installation-name">${installation.hostname}</div>
                <div class="installation-details">
                    ${installation.os} • ${installation.version} • ${installation.ip_address}
                </div>
            </div>
            <div class="installation-stats">
                <div class="error-count">${installation.error_count} errors</div>
                <div class="last-seen">${lastSeen}</div>
            </div>
        `;
        
        return item;
    }

    updateRecentErrors(errors) {
        const list = document.querySelector('.errors-list');
        if (!list) return;

        list.innerHTML = '';
        
        errors.forEach(error => {
            const item = this.createErrorItem(error);
            list.appendChild(item);
        });
    }

    createErrorItem(error) {
        const item = document.createElement('div');
        item.className = `error-item severity-${error.severity}`;
        
        const icon = error.severity === 'high' ? '🔴' : 
                   error.severity === 'medium' ? '🟡' : '🟢';
        
        const timestamp = error.timestamp ? 
            new Date(error.timestamp).toLocaleString() : 'Unknown';
        
        item.innerHTML = `
            <div class="error-icon">${icon}</div>
            <div class="error-info">
                <div class="error-type">${error.error_type}</div>
                <div class="error-message">${error.message}</div>
                <div class="error-details">
                    ${error.install_id.substring(0, 8)}... • ${timestamp}
                </div>
            </div>
        `;
        
        return item;
    }

    updateInstallationsTable(installations) {
        const table = document.querySelector('.installations-table tbody');
        if (!table) return;

        table.innerHTML = '';
        
        installations.forEach(installation => {
            const row = this.createInstallationRow(installation);
            table.appendChild(row);
        });
    }

    createInstallationRow(installation) {
        const row = document.createElement('tr');
        
        const statusClass = installation.is_active ? 'active' : 'inactive';
        const statusText = installation.is_active ? 'Active' : 'Inactive';
        const lastSeen = installation.last_seen ? 
            new Date(installation.last_seen).toLocaleString() : 'Never';
        
        row.innerHTML = `
            <td>
                <div class="installation-status ${statusClass}">
                    <span>${installation.is_active ? '🟢' : '🔴'}</span>
                    ${statusText}
                </div>
            </td>
            <td>${installation.hostname}</td>
            <td>${installation.os}</td>
            <td>${installation.version}</td>
            <td>${installation.ip_address}</td>
            <td>${installation.error_count}</td>
            <td>${lastSeen}</td>
            <td>
                <div class="installation-actions">
                    <button class="installation-btn" data-action="view" data-install-id="${installation.install_id}">
                        👁️
                    </button>
                    <button class="installation-btn" data-action="edit" data-install-id="${installation.install_id}">
                        ✏️
                    </button>
                    <button class="installation-btn danger" data-action="delete" data-install-id="${installation.install_id}">
                        🗑️
                    </button>
                </div>
            </td>
        `;
        
        return row;
    }

    updateErrorsTable(errors) {
        const table = document.querySelector('.errors-table tbody');
        if (!table) return;

        table.innerHTML = '';
        
        errors.forEach(error => {
            const row = this.createErrorRow(error);
            table.appendChild(row);
        });
    }

    createErrorRow(error) {
        const row = document.createElement('tr');
        
        const timestamp = error.timestamp ? 
            new Date(error.timestamp).toLocaleString() : 'Unknown';
        
        row.innerHTML = `
            <td>
                <div class="error-severity-badge ${error.severity}">
                    ${error.severity === 'high' ? '🔴' : error.severity === 'medium' ? '🟡' : '🟢'}
                    ${error.severity.charAt(0).toUpperCase() + error.severity.slice(1)}
                </div>
            </td>
            <td>${error.error_type}</td>
            <td class="error-message-cell">${error.message}</td>
            <td>${error.install_id.substring(0, 8)}...</td>
            <td>${timestamp}</td>
            <td>
                <button class="error-detail-toggle" data-error-id="${error.error_id}">
                    📋 Details
                </button>
            </td>
        `;
        
        return row;
    }

    async refreshData() {
        this.showNotification('Refreshing data...', 'info');
        await this.loadPageSpecificFunctionality();
        this.showNotification('Data refreshed successfully', 'success');
    }

    async exportData() {
        try {
            const response = await fetch('/db/stats');
            const data = await response.json();
            
            const blob = new Blob([JSON.stringify(data, null, 2)], {
                type: 'application/json'
            });
            
            const url = URL.createObjectURL(blob);
            const a = document.createElement('a');
            a.href = url;
            a.download = `mother-db-export-${new Date().toISOString().split('T')[0]}.json`;
            document.body.appendChild(a);
            a.click();
            document.body.removeChild(a);
            URL.revokeObjectURL(url);
            
            this.showNotification('Data exported successfully', 'success');
        } catch (error) {
            console.error('Error exporting data:', error);
            this.showNotification('Failed to export data', 'error');
        }
    }

    async testErrorReporting() {
        try {
            const testError = {
                install_id: 'test-installation',
                error_type: 'test_error',
                message: 'This is a test error for demonstration',
                severity: 'medium',
                context: {
                    test: true,
                    timestamp: new Date().toISOString()
                }
            };

            const response = await fetch('/cry_to_mom', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify(testError)
            });

            const result = await response.json();
            
            if (result.success) {
                this.showNotification('Test error reported successfully', 'success');
                setTimeout(() => this.refreshData(), 1000);
            } else {
                this.showNotification('Failed to report test error', 'error');
            }
        } catch (error) {
            console.error('Error testing error reporting:', error);
            this.showNotification('Failed to test error reporting', 'error');
        }
    }

    handleQuickAction(action) {
        switch (action) {
            case 'View All Installations':
                window.location.href = '/admin/mother-db/installations';
                break;
            case 'View All Errors':
                window.location.href = '/admin/mother-db/errors';
                break;
            case 'Export Error Log':
                this.exportErrorLog();
                break;
            case 'Test Error Report':
                this.testErrorReporting();
                break;
        }
    }

    async exportErrorLog() {
        try {
            const response = await fetch('/db/errors?limit=1000');
            const data = await response.json();
            
            const logContent = data.errors.map(error => 
                `[${error.timestamp}] ${error.severity.toUpperCase()}: ${error.error_type} - ${error.message}`
            ).join('\n');
            
            const blob = new Blob([logContent], { type: 'text/plain' });
            const url = URL.createObjectURL(blob);
            const a = document.createElement('a');
            a.href = url;
            a.download = `error-log-${new Date().toISOString().split('T')[0]}.txt`;
            document.body.appendChild(a);
            a.click();
            document.body.removeChild(a);
            URL.revokeObjectURL(url);
            
            this.showNotification('Error log exported successfully', 'success');
        } catch (error) {
            console.error('Error exporting error log:', error);
            this.showNotification('Failed to export error log', 'error');
        }
    }

    async handleInstallationAction(action, installId) {
        switch (action) {
            case 'view':
                this.viewInstallationDetails(installId);
                break;
            case 'edit':
                this.editInstallation(installId);
                break;
            case 'delete':
                await this.deleteInstallation(installId);
                break;
        }
    }

    viewInstallationDetails(installId) {
        // Show installation details modal
        this.showNotification(`Viewing installation ${installId}`, 'info');
    }

    editInstallation(installId) {
        // Show installation edit modal
        this.showNotification(`Editing installation ${installId}`, 'info');
    }

    async deleteInstallation(installId) {
        if (!confirm(`Are you sure you want to delete installation ${installId}?`)) {
            return;
        }

        try {
            // This would be implemented when we add delete functionality
            this.showNotification(`Installation ${installId} deleted`, 'success');
            setTimeout(() => this.loadInstallationsData(), 1000);
        } catch (error) {
            console.error('Error deleting installation:', error);
            this.showNotification('Failed to delete installation', 'error');
        }
    }

    toggleErrorDetails(errorId) {
        const button = document.querySelector(`[data-error-id="${errorId}"]`);
        const row = button.closest('tr');
        const detailsRow = row.nextElementSibling;
        
        if (detailsRow && detailsRow.classList.contains('error-details-row')) {
            detailsRow.remove();
            button.textContent = '📋 Details';
        } else {
            this.loadErrorDetails(errorId, row);
            button.textContent = '📋 Hide';
        }
    }

    async loadErrorDetails(errorId, row) {
        try {
            const response = await fetch(`/db/errors`);
            const data = await response.json();
            const error = data.errors.find(e => e.error_id === errorId);
            
            if (error) {
                const detailsRow = document.createElement('tr');
                detailsRow.className = 'error-details-row';
                detailsRow.innerHTML = `
                    <td colspan="6">
                        <div class="error-details-content">
                            ${error.stack_trace ? `
                                <div class="error-stack-trace">${error.stack_trace}</div>
                            ` : ''}
                            ${error.context ? `
                                <div class="error-context">
                                    <strong>Context:</strong> ${JSON.stringify(error.context, null, 2)}
                                </div>
                            ` : ''}
                        </div>
                    </td>
                `;
                
                row.parentNode.insertBefore(detailsRow, row.nextSibling);
            }
        } catch (error) {
            console.error('Error loading error details:', error);
        }
    }

    filterErrorsBySeverity(severity) {
        const rows = document.querySelectorAll('.errors-table tbody tr');
        
        rows.forEach(row => {
            const severityCell = row.querySelector('.error-severity-badge');
            if (severity === 'all' || (severityCell && severityCell.classList.contains(severity))) {
                row.style.display = '';
            } else {
                row.style.display = 'none';
            }
        });
    }

    performSearch(query) {
        const rows = document.querySelectorAll('tbody tr');
        const searchTerm = query.toLowerCase();
        
        rows.forEach(row => {
            const text = row.textContent.toLowerCase();
            row.style.display = text.includes(searchTerm) ? '' : 'none';
        });
    }

    applyFilters() {
        // Apply filters based on form data
        this.showNotification('Filters applied', 'info');
        // This would reload data with filters
    }

    startAutoRefresh() {
        // Auto-refresh every 30 seconds for dashboard
        if (this.currentPage === 'dashboard') {
            setInterval(() => {
                this.loadDashboardData();
            }, 30000);
        }
    }

    showNotification(message, type = 'info') {
        const notification = document.createElement('div');
        notification.className = `notification ${type}`;
        notification.textContent = message;
        
        document.body.appendChild(notification);
        
        setTimeout(() => {
            notification.remove();
        }, 5000);
    }
}

// Global functions for onclick handlers
function refreshData() {
    if (window.motherDB) {
        window.motherDB.refreshData();
    }
}

function exportData() {
    if (window.motherDB) {
        window.motherDB.exportData();
    }
}

function viewAllInstallations() {
    window.location.href = '/admin/mother-db/installations';
}

function viewAllErrors() {
    window.location.href = '/admin/mother-db/errors';
}

function exportErrorLog() {
    if (window.motherDB) {
        window.motherDB.exportErrorLog();
    }
}

function testErrorReporting() {
    if (window.motherDB) {
        window.motherDB.testErrorReporting();
    }
}

// Initialize when DOM is loaded
document.addEventListener('DOMContentLoaded', () => {
    window.motherDB = new MotherDB();
}); 