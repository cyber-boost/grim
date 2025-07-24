/**
 * Security Audit System
 * Real-time security monitoring and audit trail management
 */

class AuditManager {
    constructor() {
        this.auditLogs = [];
        this.vulnerabilities = [];
        this.currentPage = 1;
        this.itemsPerPage = 20;
        this.filters = {
            type: 'all',
            user: 'all',
            timeRange: '24h',
            search: ''
        };
        this.init();
    }

    init() {
        this.setupEventListeners();
        this.loadSecurityScore();
        this.loadAuditLogs();
        this.loadVulnerabilities();
        this.loadRecommendations();
        this.startAutoRefresh();
    }

    setupEventListeners() {
        // Control buttons
        document.getElementById('run-audit-btn')?.addEventListener('click', () => this.runFullAudit());
        document.getElementById('export-report-btn')?.addEventListener('click', () => this.exportReport());
        document.getElementById('refresh-audit-btn')?.addEventListener('click', () => this.refresh());

        // Filters
        document.getElementById('audit-type-filter')?.addEventListener('change', (e) => {
            this.filters.type = e.target.value;
            this.currentPage = 1;
            this.loadAuditLogs();
        });

        document.getElementById('audit-user-filter')?.addEventListener('change', (e) => {
            this.filters.user = e.target.value;
            this.currentPage = 1;
            this.loadAuditLogs();
        });

        document.getElementById('audit-time-filter')?.addEventListener('change', (e) => {
            this.filters.timeRange = e.target.value;
            this.currentPage = 1;
            this.loadAuditLogs();
        });

        document.getElementById('audit-search')?.addEventListener('input', (e) => {
            this.filters.search = e.target.value;
            this.currentPage = 1;
            this.debounceSearch();
        });

        // Pagination
        document.getElementById('audit-prev')?.addEventListener('click', () => {
            if (this.currentPage > 1) {
                this.currentPage--;
                this.loadAuditLogs();
            }
        });

        document.getElementById('audit-next')?.addEventListener('click', () => {
            this.currentPage++;
            this.loadAuditLogs();
        });

        // Scanner buttons
        document.getElementById('quick-scan-btn')?.addEventListener('click', () => this.runQuickScan());
        document.getElementById('deep-scan-btn')?.addEventListener('click', () => this.runDeepScan());
        document.getElementById('schedule-scan-btn')?.addEventListener('click', () => this.showScheduleModal());
    }

    async loadSecurityScore() {
        try {
            const response = await fetch('/api/audit/security-score');
            const data = await response.json();

            if (data.success) {
                this.updateSecurityScore(data);
            }
        } catch (error) {
            console.error('Error loading security score:', error);
        }
    }

    updateSecurityScore(data) {
        document.getElementById('security-score').textContent = data.score + '%';
        document.getElementById('security-rating').textContent = this.getSecurityRating(data.score);
        document.getElementById('vulnerabilities-count').textContent = data.vulnerabilities || '0';
        document.getElementById('vulnerabilities-label').textContent = this.getVulnerabilityLabel(data.vulnerabilities);
        document.getElementById('last-audit-time').textContent = this.formatTimeAgo(data.lastAudit);
        document.getElementById('last-audit-type').textContent = data.lastAuditType || 'Manual scan';
        document.getElementById('threats-blocked').textContent = data.threatsBlocked || '0';

        // Update security assessment grid
        this.updateSecurityAssessment(data.assessments);
    }

    getSecurityRating(score) {
        if (score >= 90) return 'Excellent';
        if (score >= 75) return 'Good';
        if (score >= 60) return 'Fair';
        return 'Poor';
    }

    getVulnerabilityLabel(count) {
        if (count === 0) return 'No vulnerabilities';
        if (count === 1) return '1 vulnerability';
        return `${count} vulnerabilities`;
    }

    updateSecurityAssessment(assessments) {
        const grid = document.getElementById('security-assessment-grid');
        if (!grid || !assessments) return;

        grid.innerHTML = assessments.map(item => `
            <div class="security-item ${this.getScoreClass(item.score)}">
                <div class="security-header">
                    <span class="security-icon">${item.icon}</span>
                    <span class="security-title">${item.title}</span>
                    <span class="security-score">${item.score}%</span>
                </div>
                <div class="security-details">${item.details}</div>
                <div class="progress-bar">
                    <div class="progress-fill" style="width: ${item.score}%"></div>
                </div>
            </div>
        `).join('');
    }

    getScoreClass(score) {
        if (score >= 90) return 'excellent';
        if (score >= 70) return 'good';
        return 'poor';
    }

    async loadAuditLogs() {
        try {
            const params = new URLSearchParams({
                type: this.filters.type,
                user: this.filters.user,
                timeRange: this.filters.timeRange,
                search: this.filters.search,
                page: this.currentPage,
                limit: this.itemsPerPage
            });

            const response = await fetch(`/api/audit/logs?${params}`);
            const data = await response.json();

            if (data.success) {
                this.auditLogs = data.logs;
                this.renderAuditLogs();
                this.updatePagination(data.totalPages);
                this.updateUserFilter(data.users);
            }
        } catch (error) {
            console.error('Error loading audit logs:', error);
        }
    }

    renderAuditLogs() {
        const tbody = document.getElementById('audit-tbody');
        if (!tbody) return;

        if (this.auditLogs.length === 0) {
            tbody.innerHTML = '<tr><td colspan="7" class="loading-message">No audit logs found</td></tr>';
            return;
        }

        tbody.innerHTML = this.auditLogs.map(log => `
            <tr>
                <td>${this.formatDateTime(log.timestamp)}</td>
                <td>${log.user || 'System'}</td>
                <td>${log.action}</td>
                <td>${log.resource || '-'}</td>
                <td>${log.ip_address || '-'}</td>
                <td><span class="status-badge ${log.status}">${log.status}</span></td>
                <td>
                    <button class="btn btn-small" onclick="auditManager.showDetails('${log.id}')">
                        Details
                    </button>
                </td>
            </tr>
        `).join('');
    }

    updatePagination(totalPages) {
        document.getElementById('audit-page-info').textContent = `Page ${this.currentPage} of ${totalPages}`;
        document.getElementById('audit-prev').disabled = this.currentPage === 1;
        document.getElementById('audit-next').disabled = this.currentPage === totalPages;
    }

    updateUserFilter(users) {
        const select = document.getElementById('audit-user-filter');
        if (!select || !users) return;

        const currentValue = select.value;
        select.innerHTML = '<option value="all">All Users</option>' + 
            users.map(user => `<option value="${user}">${user}</option>`).join('');
        select.value = currentValue;
    }

    async loadVulnerabilities() {
        try {
            const response = await fetch('/api/audit/vulnerabilities');
            const data = await response.json();

            if (data.success) {
                this.vulnerabilities = data.vulnerabilities;
                this.renderVulnerabilities();
            }
        } catch (error) {
            console.error('Error loading vulnerabilities:', error);
        }
    }

    renderVulnerabilities() {
        const container = document.getElementById('vulnerabilities-list');
        if (!container) return;

        if (this.vulnerabilities.length === 0) {
            container.innerHTML = '<div class="no-vulnerabilities">No vulnerabilities detected</div>';
            return;
        }

        container.innerHTML = this.vulnerabilities.map(vuln => `
            <div class="vulnerability-item ${vuln.severity}">
                <div class="vulnerability-header">
                    <span class="vulnerability-severity">${vuln.severity.toUpperCase()}</span>
                    <span class="vulnerability-type">${vuln.type}</span>
                </div>
                <div class="vulnerability-title">${vuln.title}</div>
                <div class="vulnerability-description">${vuln.description}</div>
                <div class="vulnerability-actions">
                    <button class="btn btn-small" onclick="auditManager.fixVulnerability('${vuln.id}')">
                        Fix Now
                    </button>
                    <button class="btn btn-small" onclick="auditManager.ignoreVulnerability('${vuln.id}')">
                        Ignore
                    </button>
                </div>
            </div>
        `).join('');
    }

    async loadRecommendations() {
        try {
            const response = await fetch('/api/audit/recommendations');
            const data = await response.json();

            if (data.success) {
                this.renderRecommendations(data.recommendations);
            }
        } catch (error) {
            console.error('Error loading recommendations:', error);
        }
    }

    renderRecommendations(recommendations) {
        const container = document.getElementById('recommendations-list');
        if (!container) return;

        container.innerHTML = recommendations.map(rec => `
            <div class="recommendation-item">
                <div class="recommendation-icon">${rec.icon}</div>
                <div class="recommendation-content">
                    <div class="recommendation-title">${rec.title}</div>
                    <div class="recommendation-description">${rec.description}</div>
                </div>
            </div>
        `).join('');
    }

    async runFullAudit() {
        const btn = document.getElementById('run-audit-btn');
        btn.disabled = true;
        btn.innerHTML = '<span>⏳</span> Running...';

        try {
            const response = await fetch('/api/audit/run-full', { method: 'POST' });
            const data = await response.json();

            if (data.success) {
                this.showNotification('Full audit completed successfully', 'success');
                this.refresh();
            } else {
                this.showNotification('Audit failed: ' + data.error, 'error');
            }
        } catch (error) {
            console.error('Error running audit:', error);
            this.showNotification('Failed to run audit', 'error');
        } finally {
            btn.disabled = false;
            btn.innerHTML = '<span>🔍</span> Run Full Audit';
        }
    }

    async runQuickScan() {
        const btn = document.getElementById('quick-scan-btn');
        btn.disabled = true;
        btn.textContent = 'Scanning...';

        try {
            const response = await fetch('/api/audit/scan-quick', { method: 'POST' });
            const data = await response.json();

            if (data.success) {
                this.showNotification('Quick scan completed', 'success');
                this.loadVulnerabilities();
            }
        } catch (error) {
            console.error('Error running quick scan:', error);
        } finally {
            btn.disabled = false;
            btn.textContent = 'Quick Scan';
        }
    }

    async runDeepScan() {
        if (!confirm('Deep scan may take several minutes. Continue?')) return;

        const btn = document.getElementById('deep-scan-btn');
        btn.disabled = true;
        btn.textContent = 'Scanning...';

        try {
            const response = await fetch('/api/audit/scan-deep', { method: 'POST' });
            const data = await response.json();

            if (data.success) {
                this.showNotification('Deep scan completed', 'success');
                this.loadVulnerabilities();
            }
        } catch (error) {
            console.error('Error running deep scan:', error);
        } finally {
            btn.disabled = false;
            btn.textContent = 'Deep Scan';
        }
    }

    async exportReport() {
        try {
            const response = await fetch('/api/audit/export-report');
            const blob = await response.blob();
            
            const url = window.URL.createObjectURL(blob);
            const a = document.createElement('a');
            a.href = url;
            a.download = `security-audit-${new Date().toISOString().split('T')[0]}.pdf`;
            a.click();
            
            this.showNotification('Report exported successfully', 'success');
        } catch (error) {
            console.error('Error exporting report:', error);
            this.showNotification('Failed to export report', 'error');
        }
    }

    showDetails(logId) {
        const log = this.auditLogs.find(l => l.id === logId);
        if (log) {
            alert(`Audit Log Details:\n\n${JSON.stringify(log, null, 2)}`);
        }
    }

    async fixVulnerability(vulnId) {
        if (!confirm('Apply automatic fix for this vulnerability?')) return;

        try {
            const response = await fetch(`/api/audit/vulnerability/${vulnId}/fix`, { method: 'POST' });
            const data = await response.json();

            if (data.success) {
                this.showNotification('Vulnerability fixed', 'success');
                this.loadVulnerabilities();
            }
        } catch (error) {
            console.error('Error fixing vulnerability:', error);
        }
    }

    async ignoreVulnerability(vulnId) {
        try {
            const response = await fetch(`/api/audit/vulnerability/${vulnId}/ignore`, { method: 'POST' });
            const data = await response.json();

            if (data.success) {
                this.loadVulnerabilities();
            }
        } catch (error) {
            console.error('Error ignoring vulnerability:', error);
        }
    }

    refresh() {
        this.loadSecurityScore();
        this.loadAuditLogs();
        this.loadVulnerabilities();
        this.loadRecommendations();
    }

    formatDateTime(timestamp) {
        return new Date(timestamp).toLocaleString();
    }

    formatTimeAgo(timestamp) {
        if (!timestamp) return 'Never';
        
        const date = new Date(timestamp);
        const now = new Date();
        const diff = now - date;
        
        if (diff < 60000) return 'Just now';
        if (diff < 3600000) return `${Math.floor(diff / 60000)}m ago`;
        if (diff < 86400000) return `${Math.floor(diff / 3600000)}h ago`;
        return `${Math.floor(diff / 86400000)}d ago`;
    }

    debounceSearch() {
        clearTimeout(this.searchTimeout);
        this.searchTimeout = setTimeout(() => {
            this.loadAuditLogs();
        }, 300);
    }

    showNotification(message, type = 'info') {
        // Simple notification - could be replaced with a better notification system
        const notification = document.createElement('div');
        notification.className = `notification ${type}`;
        notification.textContent = message;
        notification.style.cssText = `
            position: fixed;
            top: 20px;
            right: 20px;
            padding: 1rem 2rem;
            background: ${type === 'success' ? '#28a745' : type === 'error' ? '#dc3545' : '#17a2b8'};
            color: white;
            border-radius: 4px;
            z-index: 1000;
        `;
        document.body.appendChild(notification);
        
        setTimeout(() => {
            notification.remove();
        }, 3000);
    }

    showScheduleModal() {
        // This would open a modal to schedule scans
        alert('Schedule scan feature coming soon!');
    }

    startAutoRefresh() {
        // Refresh security score every 5 minutes
        setInterval(() => {
            this.loadSecurityScore();
        }, 300000);
    }
}

// Initialize audit manager when page loads
let auditManager;
document.addEventListener('DOMContentLoaded', () => {
    auditManager = new AuditManager();
});

// Style for status badges
const style = document.createElement('style');
style.textContent = `
.status-badge {
    padding: 0.25rem 0.5rem;
    border-radius: 3px;
    font-size: 0.75rem;
    font-weight: bold;
    text-transform: uppercase;
}

.status-badge.success {
    background: #28a745;
    color: white;
}

.status-badge.failed {
    background: #dc3545;
    color: white;
}

.status-badge.pending {
    background: #ffc107;
    color: black;
}

.vulnerability-severity {
    padding: 0.25rem 0.5rem;
    border-radius: 3px;
    font-size: 0.75rem;
    font-weight: bold;
    text-transform: uppercase;
    color: white;
}

.vulnerability-item.critical .vulnerability-severity {
    background: #dc3545;
}

.vulnerability-item.high .vulnerability-severity {
    background: #fd7e14;
}

.vulnerability-item.medium .vulnerability-severity {
    background: #ffc107;
    color: black;
}

.vulnerability-item.low .vulnerability-severity {
    background: #28a745;
}

.no-vulnerabilities {
    text-align: center;
    padding: 2rem;
    color: #666;
}
`;
document.head.appendChild(style);