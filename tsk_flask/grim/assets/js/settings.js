// Settings-specific JavaScript
document.addEventListener('DOMContentLoaded', function() {
    // Auto-save settings on change
    const inputs = document.querySelectorAll('.setting-input, .setting-select');
    inputs.forEach(input => {
        input.addEventListener('change', function() {
            console.log('Setting changed:', this.name || this.id, this.value);
            // Here you would typically save to backend
        });
    });

    // Toggle switch functionality
    const toggles = document.querySelectorAll('.toggle-switch input');
    toggles.forEach(toggle => {
        toggle.addEventListener('change', function() {
            console.log('Toggle changed:', this.id, this.checked);
            // Here you would typically save to backend
        });
    });
});

function saveConfiguration() {
    // Collect all form data and save
    console.log('Saving configuration...');
    // Implementation would send data to backend
}

function exportSettings() {
    // Export current settings as JSON
    console.log('Exporting settings...');
    // Implementation would generate and download JSON file
}

function importSettings() {
    // Import settings from file
    console.log('Importing settings...');
    // Implementation would show file picker and import
}

function resetToDefaults() {
    if (confirm('Are you sure you want to reset all settings to defaults?')) {
        console.log('Resetting to defaults...');
        // Implementation would reset all settings
    }
} 