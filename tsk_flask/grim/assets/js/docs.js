// Docs-specific JavaScript

// Search functionality
const searchInput = document.getElementById('searchInput');
const commandItems = document.querySelectorAll('.command-item');
const categories = document.querySelectorAll('.command-category');

if (searchInput) {
    searchInput.addEventListener('input', (e) => {
    const searchTerm = e.target.value.toLowerCase();
    
    commandItems.forEach(item => {
        const syntax = item.querySelector('.command-syntax').textContent.toLowerCase();
        const description = item.querySelector('.command-description').textContent.toLowerCase();
        const tags = Array.from(item.querySelectorAll('.tag')).map(tag => tag.textContent.toLowerCase());
        
        if (syntax.includes(searchTerm) || 
            description.includes(searchTerm) || 
            tags.some(tag => tag.includes(searchTerm))) {
            item.classList.remove('hidden');
        } else {
            item.classList.add('hidden');
        }
    });

    // Hide empty categories
    categories.forEach(category => {
        const visibleItems = category.querySelectorAll('.command-item:not(.hidden)');
        if (visibleItems.length === 0 && searchTerm !== '') {
            category.classList.add('hidden');
        } else {
            category.classList.remove('hidden');
        }
    });
});
}
}

// Category filter
const categoryBtns = document.querySelectorAll('.category-btn');
if (categoryBtns.length > 0) {
    categoryBtns.forEach(btn => {
    btn.addEventListener('click', () => {
        const selectedCategory = btn.dataset.category;
        
        // Update active button
        categoryBtns.forEach(b => b.classList.remove('active'));
        btn.classList.add('active');
        
        // Show/hide categories
        categories.forEach(category => {
            if (selectedCategory === 'all' || category.dataset.category === selectedCategory) {
                category.classList.remove('hidden');
            } else {
                category.classList.add('hidden');
            }
        });
    });
});

// Copy command functionality
function copyCommand(command) {
    navigator.clipboard.writeText(command).then(() => {
        event.target.textContent = 'Copied!';
        event.target.classList.add('copied');
        setTimeout(() => {
            event.target.textContent = 'Copy';
            event.target.classList.remove('copied');
        }, 2000);
    });
}

// Quick reference panel
function toggleQuickRef() {
    const quickRef = document.getElementById('quickRef');
    quickRef.classList.toggle('open');
}

// Add keyboard shortcuts
document.addEventListener('keydown', (e) => {
    // Ctrl/Cmd + K for search
    if ((e.ctrlKey || e.metaKey) && e.key === 'k') {
        e.preventDefault();
        searchInput.focus();
    }
    
    // Escape to close quick ref
    if (e.key === 'Escape') {
        const quickRef = document.getElementById('quickRef');
        if (quickRef.classList.contains('open')) {
            quickRef.classList.remove('open');
        }
    }
});

// Add hover effects
document.addEventListener('DOMContentLoaded', function() {
    commandItems.forEach(item => {
        item.addEventListener('mouseenter', () => {
            item.style.boxShadow = '0 5px 15px rgba(139, 69, 19, 0.2)';
        });
        
        item.addEventListener('mouseleave', () => {
            item.style.boxShadow = 'none';
        });
    });
}); 