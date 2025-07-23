// Log-specific JavaScript
let autoRefreshInterval;

document.addEventListener('DOMContentLoaded', function() {
    // Initialize log controls
    initLogControls();
    
    // Start auto-refresh if enabled
    if (document.getElementById('auto-refresh').checked) {
        startAutoRefresh();
    }
});

function initLogControls() {
    // Log level filter
    const logLevel = document.getElementById('log-level');
    if (logLevel) {
        logLevel.addEventListener('change', function() {
            filterLogs();
        });
    }
    
    // Time range filter
    const timeRange = document.getElementById('time-range');
    if (timeRange) {
        timeRange.addEventListener('change', function() {
            filterLogs();
        });
    }
    
    // Search functionality
    const logSearch = document.getElementById('log-search');
    if (logSearch) {
        logSearch.addEventListener('input', function() {
            filterLogs();
        });
    }
    
    // Auto-refresh toggle
    const autoRefresh = document.getElementById('auto-refresh');
    if (autoRefresh) {
        autoRefresh.addEventListener('change', function() {
            if (this.checked) {
                startAutoRefresh();
            } else {
                stopAutoRefresh();
            }
        });
    }
}

function filterLogs() {
    const level = document.getElementById('log-level').value;
    const search = document.getElementById('log-search').value.toLowerCase();
    
    const logEntries = document.querySelectorAll('.log-entry');
    
    logEntries.forEach(entry => {
        const entryLevel = entry.querySelector('.log-level').textContent.toLowerCase();
        const entryMessage = entry.querySelector('.log-message').textContent.toLowerCase();
        
        const levelMatch = level === 'all' || entryLevel === level;
        const searchMatch = search === '' || entryMessage.includes(search);
        
        if (levelMatch && searchMatch) {
            entry.style.display = 'grid';
        } else {
            entry.style.display = 'none';
        }
    });
}

function startAutoRefresh() {
    autoRefreshInterval = setInterval(() => {
        refreshLogs();
    }, 5000); // Refresh every 5 seconds
}

function stopAutoRefresh() {
    if (autoRefreshInterval) {
        clearInterval(autoRefreshInterval);
        autoRefreshInterval = null;
    }
}

function refreshLogs() {
    // Simulate log refresh
    console.log('Refreshing logs...');
    // Implementation would fetch new logs from backend
}

function clearLogs() {
    if (confirm('Are you sure you want to clear all logs? This action cannot be undone.')) {
        document.getElementById('log-container').innerHTML = '';
        console.log('Logs cleared');
    }
}

function exportLogs() {
    console.log('Exporting logs...');
    // Implementation would export logs to file
}

function downloadLogs() {
    console.log('Downloading logs...');
    // Implementation would download log files
} 