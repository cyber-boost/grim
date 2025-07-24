// Create particle background
const particlesContainer = document.getElementById('particles-bg');
for (let i = 0; i < 50; i++) {
    const particle = document.createElement('div');
    particle.className = 'particle';
    particle.style.left = Math.random() * 100 + '%';
    particle.style.animationDelay = Math.random() * 20 + 's';
    particle.style.animationDuration = (20 + Math.random() * 10) + 's';
    particlesContainer.appendChild(particle);
}

// Intersection Observer for animations
const observerOptions = {
    threshold: 0.1,
    rootMargin: '0px 0px -50px 0px'
};

const observer = new IntersectionObserver((entries) => {
    entries.forEach(entry => {
        if (entry.isIntersecting) {
            entry.target.classList.add('visible');
        }
    });
}, observerOptions);

// Observe all animated elements
document.querySelectorAll('.fade-in').forEach(el => {
    observer.observe(el);
});

// Smooth scrolling for anchor links
document.querySelectorAll('a[href^="#"]').forEach(anchor => {
    anchor.addEventListener('click', function (e) {
        e.preventDefault();
        const target = document.querySelector(this.getAttribute('href'));
        if (target) {
            target.scrollIntoView({
                behavior: 'smooth',
                block: 'start'
            });
        }
    });
});

// Dynamic nav background on scroll
window.addEventListener('scroll', () => {
    const nav = document.querySelector('.nav');
    if (window.scrollY > 100) {
        nav.style.background = 'rgba(10, 10, 10, 0.98)';
        nav.style.boxShadow = '0 5px 20px rgba(0, 0, 0, 0.5)';
    } else {
        nav.style.background = 'rgba(10, 10, 10, 0.95)';
        nav.style.boxShadow = 'none';
    }
});

// Terminal typing animation
const terminalLines = document.querySelectorAll('.terminal-line, .terminal-output, .terminal-success');
terminalLines.forEach((line, index) => {
    line.style.opacity = '0';
    line.style.transform = 'translateX(-10px)';
    setTimeout(() => {
        line.style.transition = 'all 0.3s ease';
        line.style.opacity = '1';
        line.style.transform = 'translateX(0)';
    }, index * 200);
});

// Feature card hover effects
document.querySelectorAll('.feature-card').forEach(card => {
    card.addEventListener('mouseenter', function() {
        this.style.transform = 'translateY(-8px) scale(1.02)';
    });
    
    card.addEventListener('mouseleave', function() {
        this.style.transform = 'translateY(0) scale(1)';
    });
});

// Command category hover effects
document.querySelectorAll('.command-item').forEach(item => {
    item.addEventListener('mouseenter', function() {
        const icon = document.createElement('span');
        icon.textContent = ' ←';
        icon.style.color = '#b8860b';
        this.appendChild(icon);
    });
    
    item.addEventListener('mouseleave', function() {
        const icon = this.querySelector('span');
        if (icon && icon.textContent === ' ←') {
            icon.remove();
        }
    });
});

