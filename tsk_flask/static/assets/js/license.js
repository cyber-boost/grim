// License Management - Specific JavaScript
// Extracted from scythe_license_manager.html

document.addEventListener('DOMContentLoaded', function() {
    initLicenseManagement();
});

function initLicenseManagement() {
    // Toggle switch functionality
    initToggleSwitches();
    
    // Report generation functionality
    initReportGeneration();
    
    // Action buttons functionality
    initActionButtons();
    
    // Auto-update functionality
    initAutoUpdates();
    
    // Table row hover effects
    initTableHoverEffects();
}

// Toggle switch functionality
function toggleSwitch(element) {
    element.classList.toggle('active');
    
    // Add visual feedback
    element.classList.add('glow');
    setTimeout(() => {
        element.classList.remove('glow');
    }, 1000);
    
    // Add activity to feed
    const isActive = element.classList.contains('active');
    const action = isActive ? 'enabled' : 'disabled';
    addActivityItem('⚙️', `Silent Mode ${action}`, 'Just now');
}

function initToggleSwitches() {
    document.querySelectorAll('.toggle-switch').forEach(switch_ => {
        switch_.addEventListener('click', function() {
            toggleSwitch(this);
        });
    });
}

// Generate report functionality
function generateReport(type) {
    const reportTypes = {
        'executive': 'Executive Summary',
        'detailed': 'Detailed Audit',
        'risk': 'Risk Assessment',
        'cost': 'Cost Analysis',
        'trend': 'Trend Analysis',
        'compliance': 'Compliance Export'
    };
    
    // Add visual feedback
    event.target.closest('.report-item').classList.add('glow');
    setTimeout(() => {
        event.target.closest('.report-item').classList.remove('glow');
    }, 2000);
    
    // Add activity to feed
    addActivityItem('📊', `Generated ${reportTypes[type]} report`, 'Just now');
    
    // Simulate report generation
    console.log(`Generating ${reportTypes[type]} report...`);
}

function initReportGeneration() {
    document.querySelectorAll('.report-item').forEach(item => {
        item.addEventListener('click', function() {
            const type = this.getAttribute('onclick').match(/'([^']+)'/)[1];
            generateReport(type);
        });
    });
}

// Perform action functionality
function performAction(action) {
    const actions = {
        'deep-scan': 'Deep License Scan initiated',
        'add-protection': 'New software protection added',
        'generate-report': 'Compliance report generated',
        'test-notifications': 'Notification test sent',
        'configure-rules': 'Protection rules configured',
        'sync-mother-db': 'Mother DB sync completed',
        'emergency-protect': 'Emergency protection activated',
        'export-licenses': 'License data exported'
    };
    
    // Add visual feedback
    event.target.classList.add('glow');
    setTimeout(() => {
        event.target.classList.remove('glow');
    }, 1000);
    
    // Add activity to feed
    const icons = {
        'deep-scan': '🔍',
        'add-protection': '➕',
        'generate-report': '📊',
        'test-notifications': '🔔',
        'configure-rules': '⚙️',
        'sync-mother-db': '🗄️',
        'emergency-protect': '🛡️',
        'export-licenses': '📤'
    };
    
    addActivityItem(icons[action], actions[action], 'Just now');
    
    // Simulate action execution
    console.log(`Executing action: ${action}`);
}

function initActionButtons() {
    document.querySelectorAll('.action-btn').forEach(btn => {
        btn.addEventListener('click', function() {
            const action = this.getAttribute('onclick').match(/'([^']+)'/)[1];
            performAction(action);
        });
    });
}

// Add activity item to feed
function addActivityItem(icon, title, time) {
    const activityFeed = document.querySelector('.activity-feed');
    const activityItem = document.createElement('div');
    activityItem.className = 'activity-item';
    activityItem.innerHTML = `
        <div class="activity-icon">${icon}</div>
        <div class="activity-content">
            <div class="activity-title">${title}</div>
            <div class="activity-time">${time}</div>
        </div>
    `;
    
    // Insert at the top (after the h3)
    const firstActivity = activityFeed.querySelector('.activity-item');
    if (firstActivity) {
        activityFeed.insertBefore(activityItem, firstActivity);
    } else {
        activityFeed.appendChild(activityItem);
    }
    
    // Remove the last item if there are too many
    const allItems = activityFeed.querySelectorAll('.activity-item');
    if (allItems.length > 6) {
        allItems[allItems.length - 1].remove();
    }
}

// Auto-update functionality
function initAutoUpdates() {
    // Auto-update stats every 30 seconds
    setInterval(() => {
        // Update compliance percentage occasionally
        const complianceCard = document.querySelector('.stat-value:contains("100%")');
        if (Math.random() < 0.1) { // 10% chance
            const newValue = Math.floor(Math.random() * 5) + 96; // 96-100%
            if (complianceCard && complianceCard.textContent === '100%') {
                complianceCard.textContent = newValue + '%';
                if (newValue < 100) {
                    complianceCard.parentElement.querySelector('.stat-label').textContent = 'Needs attention';
                }
            }
        }
    }, 30000);

    // Simulate license checks
    setInterval(() => {
        const checkingStatuses = document.querySelectorAll('.license-status.checking');
        checkingStatuses.forEach(status => {
            if (Math.random() < 0.3) { // 30% chance to complete check
                status.className = 'license-status valid';
                status.innerHTML = '✅ Valid';
                addActivityItem('✅', `${status.closest('tr').querySelector('td').textContent.trim()} license verified`, 'Just now');
            }
        });
    }, 15000);
}

// Table row hover effects
function initTableHoverEffects() {
    document.querySelectorAll('.software-table tr').forEach(row => {
        row.addEventListener('mouseenter', function() {
            this.style.transform = 'scale(1.02)';
            this.style.transition = 'transform 0.2s ease';
        });
        
        row.addEventListener('mouseleave', function() {
            this.style.transform = 'scale(1)';
        });
    });
}

// Table button functionality
function initTableButtons() {
    document.querySelectorAll('.table-btn').forEach(btn => {
        btn.addEventListener('click', function() {
            const action = this.textContent.toLowerCase();
            const row = this.closest('tr');
            const softwareName = row.querySelector('td').textContent.trim();
            
            // Add visual feedback
            this.classList.add('glow');
            setTimeout(() => {
                this.classList.remove('glow');
            }, 500);
            
            // Add activity to feed
            addActivityItem('⚙️', `${action} action for ${softwareName}`, 'Just now');
            
            console.log(`Table action: ${action} for ${softwareName}`);
        });
    });
}

// Initialize table buttons when DOM is ready
document.addEventListener('DOMContentLoaded', function() {
    initTableButtons();
});

// Export functions for global access
window.licenseManagement = {
    toggleSwitch,
    generateReport,
    performAction,
    addActivityItem
}; 