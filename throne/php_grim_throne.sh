#!/bin/bash
# Grim Reaper PHP-Specific Command Router
# Enhanced with special PHP commands and features

set -euo pipefail

GRIM_ROOT="/opt/reaper"
cd "$GRIM_ROOT"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
NC='\033[0m'

error() {
    echo -e "${RED}❌ $1${NC}" >&2
    exit 1
}

success() {
    echo -e "${GREEN}✅ $1${NC}"
}

info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

php_info() {
    echo -e "${PURPLE}🐘 $1${NC}"
}

# PHP-specific functions
check_php_installation() {
    if ! command -v php &> /dev/null; then
        error "PHP is not installed. Please install PHP 8.1+ first."
    fi
    
    PHP_VERSION=$(php -r "echo PHP_VERSION;")
    php_info "PHP Version: $PHP_VERSION"
}

check_composer() {
    if ! command -v composer &> /dev/null; then
        warning "Composer not found. Installing Composer..."
        curl -sS https://getcomposer.org/installer | php
        mv composer.phar /usr/local/bin/composer
        chmod +x /usr/local/bin/composer
        success "Composer installed successfully"
    fi
}

# Show help if no arguments
if [[ $# -eq 0 ]]; then
    echo -e "${CYAN}🗡️  Grim Reaper PHP-Specific Command Interface${NC}"
    echo ""
    echo "Usage: grim <command> [options]"
    echo ""
    echo "🐘 PHP-Specific Commands:"
    echo "  php-setup                 Setup PHP environment and dependencies"
    echo "  php-analyze <path>        Analyze PHP code quality and security"
    echo "  php-optimize <path>       Optimize PHP performance and memory"
    echo "  php-security <path>       Security audit for PHP applications"
    echo "  php-test <path>           Run PHPUnit tests"
    echo "  php-lint <path>           PHP syntax and style checking"
    echo "  php-deps <path>           Analyze and update dependencies"
    echo "  php-deploy <path>         Deploy PHP application"
    echo "  php-monitor <path>        Monitor PHP application performance"
    echo "  php-backup <path>         Backup PHP application and database"
    echo "  php-restore <backup>      Restore PHP application from backup"
    echo "  php-cache <action>        Manage PHP opcache and caches"
    echo "  php-logs <action>         Manage PHP error logs"
    echo "  php-composer <command>    Composer operations"
    echo "  php-extensions            Manage PHP extensions"
    echo "  php-versions              Manage multiple PHP versions"
    echo "  php-fpm <action>          PHP-FPM management"
    echo "  php-nginx <action>        Nginx + PHP configuration"
    echo "  php-apache <action>       Apache + PHP configuration"
    echo "  php-docker <action>       Docker PHP operations"
    echo "  php-k8s <action>          Kubernetes PHP operations"
    echo ""
    echo "🔧 Core Commands:"
    echo "  health                    Check all systems health"
    echo "  status                    Overall system status"
    echo "  backup <path>             Orchestrated backup"
    echo "  restore <backup>          Coordinated restore"
    echo "  scan <path>               Unified file scanning"
    echo "  monitor <path>            Start monitoring"
    echo "  web                       Start web interface"
    echo ""
    echo "Examples:"
    echo "  grim php-setup            # Setup PHP environment"
    echo "  grim php-analyze /app     # Analyze PHP code"
    echo "  grim php-deploy /app      # Deploy PHP app"
    echo "  grim php-monitor /app     # Monitor PHP app"
    echo ""
    echo "For full command list: grim help-all"
    exit 0
fi

COMMAND="$1"
shift || true

# Check PHP installation for PHP-specific commands
if [[ "$COMMAND" == php-* ]]; then
    check_php_installation
fi

case "$COMMAND" in
    # PHP-Specific Commands
    php-setup)
        php_info "Setting up PHP environment..."
        check_composer
        
        # Install common PHP extensions
        php_info "Installing PHP extensions..."
        if command -v apt-get &> /dev/null; then
            sudo apt-get update
            sudo apt-get install -y php-curl php-mbstring php-xml php-zip php-opcache php-mysql php-pgsql php-redis php-gd php-imagick
        elif command -v yum &> /dev/null; then
            sudo yum install -y php-curl php-mbstring php-xml php-zip php-opcache php-mysql php-pgsql php-redis php-gd php-imagick
        fi
        
        # Configure PHP
        php_info "Configuring PHP..."
        sudo sed -i 's/upload_max_filesize = 2M/upload_max_filesize = 100M/' /etc/php/*/apache2/php.ini 2>/dev/null || true
        sudo sed -i 's/post_max_size = 8M/post_max_size = 100M/' /etc/php/*/apache2/php.ini 2>/dev/null || true
        sudo sed -i 's/memory_limit = 128M/memory_limit = 512M/' /etc/php/*/apache2/php.ini 2>/dev/null || true
        
        success "PHP environment setup complete"
        ;;
    
    php-analyze)
        if [[ $# -eq 0 ]]; then
            error "Usage: grim php-analyze <path>"
        fi
        local path="$1"
        php_info "Analyzing PHP code in: $path"
        
        # Install PHP analysis tools if not present
        if ! command -v phpstan &> /dev/null; then
            composer global require phpstan/phpstan
        fi
        if ! command -v psalm &> /dev/null; then
            composer global require vimeo/psalm
        fi
        
        # Run analysis
        echo "Running PHPStan analysis..."
        phpstan analyse "$path" --level=8 || warning "PHPStan found issues"
        
        echo "Running Psalm analysis..."
        psalm --init "$path" 2>/dev/null || true
        psalm "$path" || warning "Psalm found issues"
        
        echo "Running PHP Mess Detector..."
        if command -v phpmd &> /dev/null; then
            phpmd "$path" text cleancode,codesize,controversial,design,naming,unusedcode
        else
            composer global require phpmd/phpmd
            phpmd "$path" text cleancode,codesize,controversial,design,naming,unusedcode
        fi
        
        success "PHP analysis complete"
        ;;
    
    php-optimize)
        if [[ $# -eq 0 ]]; then
            error "Usage: grim php-optimize <path>"
        fi
        local path="$1"
        php_info "Optimizing PHP application in: $path"
        
        # Composer optimization
        if [[ -f "$path/composer.json" ]]; then
            cd "$path"
            composer install --optimize-autoloader --no-dev
            composer dump-autoload --optimize
        fi
        
        # OpCache optimization
        php_info "Optimizing OpCache..."
        php -r "opcache_reset();" 2>/dev/null || true
        
        # Clear caches
        find "$path" -name "cache" -type d -exec rm -rf {} + 2>/dev/null || true
        find "$path" -name "tmp" -type d -exec rm -rf {} + 2>/dev/null || true
        
        success "PHP optimization complete"
        ;;
    
    php-security)
        if [[ $# -eq 0 ]]; then
            error "Usage: grim php-security <path>"
        fi
        local path="$1"
        php_info "Running security audit for: $path"
        
        # Install security tools
        if ! command -v security-checker &> /dev/null; then
            composer global require enlightn/security-checker
        fi
        
        # Check for known vulnerabilities
        if [[ -f "$path/composer.lock" ]]; then
            security-checker security:check "$path/composer.lock"
        fi
        
        # Check file permissions
        find "$path" -type f -name "*.php" -exec chmod 644 {} \;
        find "$path" -type d -exec chmod 755 {} \;
        
        # Check for sensitive files
        find "$path" -name ".env" -o -name "config.php" -o -name "database.php" | while read file; do
            if [[ $(stat -c %a "$file") != "600" ]]; then
                warning "Sensitive file $file has incorrect permissions"
                chmod 600 "$file"
            fi
        done
        
        success "Security audit complete"
        ;;
    
    php-test)
        if [[ $# -eq 0 ]]; then
            error "Usage: grim php-test <path>"
        fi
        local path="$1"
        php_info "Running PHPUnit tests in: $path"
        
        if [[ -f "$path/phpunit.xml" ]] || [[ -f "$path/phpunit.xml.dist" ]]; then
            cd "$path"
            if command -v phpunit &> /dev/null; then
                phpunit
            else
                ./vendor/bin/phpunit
            fi
        else
            warning "No PHPUnit configuration found"
        fi
        
        success "PHP tests complete"
        ;;
    
    php-lint)
        if [[ $# -eq 0 ]]; then
            error "Usage: grim php-lint <path>"
        fi
        local path="$1"
        php_info "Linting PHP code in: $path"
        
        # Syntax check
        find "$path" -name "*.php" -exec php -l {} \;
        
        # PSR-12 style check
        if command -v phpcs &> /dev/null; then
            phpcs --standard=PSR12 "$path"
        else
            composer global require squizlabs/php_codesniffer
            phpcs --standard=PSR12 "$path"
        fi
        
        success "PHP linting complete"
        ;;
    
    php-deps)
        if [[ $# -eq 0 ]]; then
            error "Usage: grim php-deps <path>"
        fi
        local path="$1"
        php_info "Analyzing dependencies in: $path"
        
        if [[ -f "$path/composer.json" ]]; then
            cd "$path"
            
            # Check for outdated packages
            composer outdated
            
            # Update dependencies
            echo "Updating dependencies..."
            composer update --dry-run
            
            # Check for security issues
            composer audit
        else
            warning "No composer.json found"
        fi
        
        success "Dependency analysis complete"
        ;;
    
    php-deploy)
        if [[ $# -eq 0 ]]; then
            error "Usage: grim php-deploy <path>"
        fi
        local path="$1"
        php_info "Deploying PHP application: $path"
        
        # Create backup
        grim backup "$path" --name "pre-deploy-$(date +%Y%m%d-%H%M%S)"
        
        # Optimize for production
        grim php-optimize "$path"
        
        # Set proper permissions
        find "$path" -type f -exec chmod 644 {} \;
        find "$path" -type d -exec chmod 755 {} \;
        
        # Restart web server
        if systemctl is-active --quiet apache2; then
            sudo systemctl reload apache2
        elif systemctl is-active --quiet nginx; then
            sudo systemctl reload nginx
        fi
        
        success "PHP deployment complete"
        ;;
    
    php-monitor)
        if [[ $# -eq 0 ]]; then
            error "Usage: grim php-monitor <path>"
        fi
        local path="$1"
        php_info "Monitoring PHP application: $path"
        
        # Monitor PHP-FPM
        if systemctl is-active --quiet php*-fpm; then
            systemctl status php*-fpm
        fi
        
        # Monitor error logs
        tail -f /var/log/php*.log 2>/dev/null || tail -f "$path/logs/error.log" 2>/dev/null || true
        
        # Monitor memory usage
        ps aux | grep php | grep -v grep
        
        success "PHP monitoring active"
        ;;
    
    php-backup)
        if [[ $# -eq 0 ]]; then
            error "Usage: grim php-backup <path>"
        fi
        local path="$1"
        php_info "Backing up PHP application: $path"
        
        # Application backup
        grim backup "$path" --name "php-app-$(date +%Y%m%d-%H%M%S)"
        
        # Database backup (if Laravel/Symfony)
        if [[ -f "$path/.env" ]]; then
            source "$path/.env"
            if [[ -n "$DB_DATABASE" ]]; then
                mysqldump -u "$DB_USERNAME" -p"$DB_PASSWORD" "$DB_DATABASE" > "$path/database_backup.sql"
                success "Database backup created"
            fi
        fi
        
        success "PHP backup complete"
        ;;
    
    php-restore)
        if [[ $# -eq 0 ]]; then
            error "Usage: grim php-restore <backup>"
        fi
        local backup="$1"
        php_info "Restoring PHP application from: $backup"
        
        grim restore "$backup"
        
        # Restore database if backup exists
        if [[ -f "database_backup.sql" ]]; then
            source .env
            mysql -u "$DB_USERNAME" -p"$DB_PASSWORD" "$DB_DATABASE" < database_backup.sql
            success "Database restored"
        fi
        
        success "PHP restore complete"
        ;;
    
    php-cache)
        if [[ $# -eq 0 ]]; then
            error "Usage: grim php-cache <clear|status|optimize>"
        fi
        local action="$1"
        
        case "$action" in
            clear)
                php_info "Clearing PHP caches..."
                php -r "opcache_reset();" 2>/dev/null || true
                find . -name "cache" -type d -exec rm -rf {} + 2>/dev/null || true
                success "PHP caches cleared"
                ;;
            status)
                php_info "PHP OpCache status:"
                php -r "var_dump(opcache_get_status());"
                ;;
            optimize)
                php_info "Optimizing PHP OpCache..."
                php -r "opcache_compile_file('*.php');" 2>/dev/null || true
                success "PHP OpCache optimized"
                ;;
            *)
                error "Unknown cache action: $action"
                ;;
        esac
        ;;
    
    php-logs)
        if [[ $# -eq 0 ]]; then
            error "Usage: grim php-logs <show|clear|analyze>"
        fi
        local action="$1"
        
        case "$action" in
            show)
                php_info "Showing PHP error logs:"
                tail -n 50 /var/log/php*.log 2>/dev/null || echo "No PHP error logs found"
                ;;
            clear)
                php_info "Clearing PHP error logs..."
                sudo truncate -s 0 /var/log/php*.log 2>/dev/null || true
                success "PHP error logs cleared"
                ;;
            analyze)
                php_info "Analyzing PHP error logs:"
                grep -E "(Fatal|Error|Warning)" /var/log/php*.log 2>/dev/null | tail -n 20
                ;;
            *)
                error "Unknown logs action: $action"
                ;;
        esac
        ;;
    
    php-composer)
        if [[ $# -eq 0 ]]; then
            error "Usage: grim php-composer <install|update|require|remove> [package]"
        fi
        local action="$1"
        shift || true
        
        case "$action" in
            install)
                composer install "$@"
                ;;
            update)
                composer update "$@"
                ;;
            require)
                if [[ $# -eq 0 ]]; then
                    error "Usage: grim php-composer require <package>"
                fi
                composer require "$@"
                ;;
            remove)
                if [[ $# -eq 0 ]]; then
                    error "Usage: grim php-composer remove <package>"
                fi
                composer remove "$@"
                ;;
            *)
                error "Unknown composer action: $action"
                ;;
        esac
        ;;
    
    php-extensions)
        php_info "Managing PHP extensions..."
        
        # List installed extensions
        php -m
        
        # Check for common missing extensions
        local missing_extensions=()
        for ext in curl mbstring xml zip opcache mysql pgsql redis gd imagick; do
            if ! php -m | grep -q "^$ext$"; then
                missing_extensions+=("$ext")
            fi
        done
        
        if [[ ${#missing_extensions[@]} -gt 0 ]]; then
            warning "Missing extensions: ${missing_extensions[*]}"
            echo "Install with: sudo apt-get install php-${missing_extensions[*]}"
        else
            success "All common extensions are installed"
        fi
        ;;
    
    php-versions)
        php_info "Available PHP versions:"
        
        # List installed PHP versions
        ls /usr/bin/php* 2>/dev/null | grep -E "php[0-9]+\.[0-9]+$" || true
        
        # Show current version
        php -v
        
        # Show alternatives
        if command -v update-alternatives &> /dev/null; then
            update-alternatives --list php
        fi
        ;;
    
    php-fpm)
        if [[ $# -eq 0 ]]; then
            error "Usage: grim php-fpm <start|stop|restart|status|reload>"
        fi
        local action="$1"
        
        case "$action" in
            start)
                sudo systemctl start php*-fpm
                success "PHP-FPM started"
                ;;
            stop)
                sudo systemctl stop php*-fpm
                success "PHP-FPM stopped"
                ;;
            restart)
                sudo systemctl restart php*-fpm
                success "PHP-FPM restarted"
                ;;
            status)
                sudo systemctl status php*-fpm
                ;;
            reload)
                sudo systemctl reload php*-fpm
                success "PHP-FPM reloaded"
                ;;
            *)
                error "Unknown PHP-FPM action: $action"
                ;;
        esac
        ;;
    
    php-nginx)
        if [[ $# -eq 0 ]]; then
            error "Usage: grim php-nginx <start|stop|restart|status|reload|config>"
        fi
        local action="$1"
        
        case "$action" in
            start)
                sudo systemctl start nginx
                success "Nginx started"
                ;;
            stop)
                sudo systemctl stop nginx
                success "Nginx stopped"
                ;;
            restart)
                sudo systemctl restart nginx
                success "Nginx restarted"
                ;;
            status)
                sudo systemctl status nginx
                ;;
            reload)
                sudo systemctl reload nginx
                success "Nginx reloaded"
                ;;
            config)
                sudo nginx -t
                ;;
            *)
                error "Unknown Nginx action: $action"
                ;;
        esac
        ;;
    
    php-apache)
        if [[ $# -eq 0 ]]; then
            error "Usage: grim php-apache <start|stop|restart|status|reload|config>"
        fi
        local action="$1"
        
        case "$action" in
            start)
                sudo systemctl start apache2
                success "Apache started"
                ;;
            stop)
                sudo systemctl stop apache2
                success "Apache stopped"
                ;;
            restart)
                sudo systemctl restart apache2
                success "Apache restarted"
                ;;
            status)
                sudo systemctl status apache2
                ;;
            reload)
                sudo systemctl reload apache2
                success "Apache reloaded"
                ;;
            config)
                sudo apache2ctl configtest
                ;;
            *)
                error "Unknown Apache action: $action"
                ;;
        esac
        ;;
    
    php-docker)
        if [[ $# -eq 0 ]]; then
            error "Usage: grim php-docker <build|run|stop|logs|exec>"
        fi
        local action="$1"
        shift || true
        
        case "$action" in
            build)
                if [[ -f "Dockerfile" ]]; then
                    docker build -t php-app .
                    success "Docker image built"
                else
                    error "No Dockerfile found"
                fi
                ;;
            run)
                docker run -d -p 8080:80 --name php-app php-app
                success "PHP Docker container started"
                ;;
            stop)
                docker stop php-app
                docker rm php-app
                success "PHP Docker container stopped"
                ;;
            logs)
                docker logs php-app
                ;;
            exec)
                docker exec -it php-app bash
                ;;
            *)
                error "Unknown Docker action: $action"
                ;;
        esac
        ;;
    
    php-k8s)
        if [[ $# -eq 0 ]]; then
            error "Usage: grim php-k8s <deploy|scale|logs|exec>"
        fi
        local action="$1"
        shift || true
        
        case "$action" in
            deploy)
                if [[ -f "k8s-deployment.yaml" ]]; then
                    kubectl apply -f k8s-deployment.yaml
                    success "Kubernetes deployment applied"
                else
                    error "No k8s-deployment.yaml found"
                fi
                ;;
            scale)
                if [[ $# -eq 0 ]]; then
                    error "Usage: grim php-k8s scale <replicas>"
                fi
                kubectl scale deployment php-app --replicas="$1"
                success "Scaled to $1 replicas"
                ;;
            logs)
                kubectl logs -l app=php-app
                ;;
            exec)
                kubectl exec -it deployment/php-app -- bash
                ;;
            *)
                error "Unknown Kubernetes action: $action"
                ;;
        esac
        ;;
    
    # Core Commands (delegated to original throne)
    health|status|backup|restore|scan|monitor|web|backup-*|monitor-*|security-*|ai-*|optimize-*|config-*|emergency-*|build|deploy|help-all)
        # Delegate to the main throne script
        ./throne/grim_throne.sh "$COMMAND" "$@"
        ;;
    
    *)
        error "Unknown command: $COMMAND\nRun 'grim' for help or 'grim help-all' for full command list"
        ;;
esac
