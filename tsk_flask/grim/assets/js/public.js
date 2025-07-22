// Public Pages - Shared JavaScript
// Extracted from grim-api-docs.html

document.addEventListener('DOMContentLoaded', function() {
    initPublicPages();
});

function initPublicPages() {
    // Toggle endpoint details
    initEndpointToggles();
    
    // Code tab switching
    initCodeTabs();
    
    // Smooth scrolling for navigation
    initSmoothScrolling();
    
    // Highlight current section on scroll
    initScrollHighlighting();
}

// Toggle endpoint details
function toggleDetails(element) {
    const card = element.parentElement;
    card.classList.toggle('expanded');
}

function initEndpointToggles() {
    document.querySelectorAll('.endpoint-summary').forEach(summary => {
        summary.addEventListener('click', function() {
            toggleDetails(this);
        });
    });
}

// Code tab switching
function initCodeTabs() {
    document.querySelectorAll('.code-tab').forEach(tab => {
        tab.addEventListener('click', function() {
            const tabs = this.parentElement.querySelectorAll('.code-tab');
            tabs.forEach(t => t.classList.remove('active'));
            this.classList.add('active');
        });
    });
}

// Smooth scrolling for navigation
function initSmoothScrolling() {
    document.querySelectorAll('.nav-link').forEach(link => {
        link.addEventListener('click', function(e) {
            e.preventDefault();
            const target = document.querySelector(this.getAttribute('href'));
            if (target) {
                target.scrollIntoView({ behavior: 'smooth', block: 'start' });
                
                // Update active state
                document.querySelectorAll('.nav-link').forEach(l => l.classList.remove('active'));
                this.classList.add('active');
            }
        });
    });
}

// Highlight current section on scroll
function initScrollHighlighting() {
    const sections = document.querySelectorAll('.endpoint-section');
    const navLinks = document.querySelectorAll('.nav-link');

    window.addEventListener('scroll', () => {
        let current = '';
        sections.forEach(section => {
            const sectionTop = section.offsetTop;
            const sectionHeight = section.clientHeight;
            if (scrollY >= (sectionTop - 200)) {
                current = section.getAttribute('id');
            }
        });

        navLinks.forEach(link => {
            link.classList.remove('active');
            if (link.getAttribute('href') === '#' + current) {
                link.classList.add('active');
            }
        });
    });
}

// Copy to clipboard functionality
function copyToClipboard(text) {
    navigator.clipboard.writeText(text).then(() => {
        // Show success feedback
        console.log('Copied to clipboard:', text);
    }).catch(err => {
        console.error('Failed to copy:', err);
    });
}

// Command Reference Specific Functions
function initCommandReference() {
    // Search functionality
    const searchInput = document.getElementById('searchInput');
    const commandItems = document.querySelectorAll('.command-item');
    const categories = document.querySelectorAll('.command-category');
    
    if (searchInput) {
        searchInput.addEventListener('input', (e) => {
            const searchTerm = e.target.value.toLowerCase();
            
            commandItems.forEach(item => {
                const commandName = item.querySelector('.command-name').textContent.toLowerCase();
                const commandDesc = item.querySelector('.command-desc').textContent.toLowerCase();
                
                if (commandName.includes(searchTerm) || commandDesc.includes(searchTerm)) {
                    item.style.display = 'block';
                } else {
                    item.style.display = 'none';
                }
            });
            
            // Show/hide categories based on visible commands
            categories.forEach(category => {
                const visibleCommands = category.querySelectorAll('.command-item[style="display: block"]');
                if (visibleCommands.length > 0) {
                    category.style.display = 'block';
                } else {
                    category.style.display = 'none';
                }
            });
        });
    }
    
    // Category filter
    const categoryBtns = document.querySelectorAll('.category-btn');
    categoryBtns.forEach(btn => {
        btn.addEventListener('click', () => {
            const category = btn.getAttribute('data-category');
            
            // Update active button
            categoryBtns.forEach(b => b.classList.remove('active'));
            btn.classList.add('active');
            
            // Show/hide categories
            categories.forEach(cat => {
                if (category === 'all' || cat.getAttribute('data-category') === category) {
                    cat.style.display = 'block';
                } else {
                    cat.style.display = 'none';
                }
            });
        });
    });
    
    // Copy command functionality
    document.querySelectorAll('.copy-btn').forEach(btn => {
        btn.addEventListener('click', (e) => {
            e.stopPropagation();
            const command = btn.getAttribute('data-command');
            copyToClipboard(command);
            
            // Visual feedback
            btn.textContent = 'Copied!';
            setTimeout(() => {
                btn.textContent = 'Copy';
            }, 2000);
        });
    });
    
    // Quick reference panel
    const fab = document.querySelector('.fab');
    const quickRefPanel = document.querySelector('.quick-ref-panel');
    const closeBtn = document.querySelector('.close-btn');
    
    if (fab && quickRefPanel) {
        fab.addEventListener('click', () => {
            quickRefPanel.classList.add('show');
            fab.style.display = 'none';
        });
    }
    
    if (closeBtn && quickRefPanel) {
        closeBtn.addEventListener('click', () => {
            quickRefPanel.classList.remove('show');
            fab.style.display = 'block';
        });
    }
    
    // Add keyboard shortcuts
    document.addEventListener('keydown', (e) => {
        if (e.ctrlKey && e.key === 'k') {
            e.preventDefault();
            searchInput.focus();
        }
    });
    
    // Add hover effects
    commandItems.forEach(item => {
        item.addEventListener('mouseenter', () => {
            item.style.transform = 'translateY(-2px)';
        });
        
        item.addEventListener('mouseleave', () => {
            item.style.transform = 'translateY(0)';
        });
    });
}

// Initialize command reference if on that page
if (document.querySelector('.command-category')) {
    initCommandReference();
}

// Export functions for global access
window.publicPages = {
    toggleDetails,
    copyToClipboard,
    initCommandReference
}; 