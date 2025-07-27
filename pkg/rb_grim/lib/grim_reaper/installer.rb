# frozen_string_literal: true

require "open3"
require "fileutils"

module GrimReaper
  # Ruby-specific installer and dependency manager
  class Installer
    attr_reader :grim_root, :backup_dir, :install_dir

    def initialize
      @grim_root = find_grim_root
      @backup_dir = ENV["HOME"] + "/.graveyard"
      @install_dir = ENV["HOME"] + "/reaper"
    end

    # Find Grim Reaper root directory
    def find_grim_root
      # Try to find from current directory
      current_dir = Dir.pwd
      10.times do
        if File.exist?(File.join(current_dir, "throne", "grim_throne.sh")) ||
           File.exist?(File.join(current_dir, "throne", "rb_grim_throne.sh")) ||
           File.exist?(File.join(current_dir, "tsk_flask", "grim_admin_server.py"))
          return current_dir
        end

        parent_dir = File.dirname(current_dir)
        break if parent_dir == current_dir
        current_dir = parent_dir
      end

      # Try common installation paths
      possible_paths = [
        ENV["HOME"] + "/reaper",
        ENV["HOME"] + "/.reaper",
        "/root/reaper",
        "/root/.reaper",
        "/usr/local/reaper",
        "/usr/share/reaper",
        Dir.pwd
      ]

      possible_paths.each do |path|
        if Dir.exist?(path) && (
          File.exist?(File.join(path, "throne", "grim_throne.sh")) ||
          File.exist?(File.join(path, "throne", "rb_grim_throne.sh")) ||
          File.exist?(File.join(path, "tsk_flask", "grim_admin_server.py"))
        )
          return path
        end
      end

      raise Error, "Could not find Grim Reaper root directory"
    end

    # Setup complete Grim Reaper environment (like npm/pip packages)
    def setup_complete_environment
      puts "🗡️  Setting up complete Grim Reaper environment..."
      
      # Setup Ruby environment
      setup_ruby_environment
      
      # Install Python components
      install_python_components
      
      # Install Go components
      install_go_components
      
      # Install Shell components
      install_shell_components
      
      # Install Scythe components
      install_scythe_components
      
      # Create necessary directories
      create_directories
      
      # Setup environment file
      setup_environment_file
      
      puts "✅ Complete Grim Reaper environment setup finished"
    end

    # Setup Ruby environment
    def setup_ruby_environment
      puts "💎 Setting up Ruby environment..."

      # Check Ruby version
      check_ruby_version

      # Install Bundler if not present
      install_bundler

      # Install common Ruby gems
      install_ruby_gems

      # Setup RVM/rbenv if available
      setup_ruby_version_manager

      puts "✅ Ruby environment setup complete"
    end

    # Install Python components (like pip package)
    def install_python_components
      puts "🐍 Installing Python components..."
      
      # Check if Python is available
      unless system("python3 --version > /dev/null 2>&1")
        puts "⚠️  Python3 not found, skipping Python components"
        return
      end
      
      # Install pip if not available
      unless system("pip3 --version > /dev/null 2>&1")
        puts "📦 Installing pip3..."
        unless system("apt-get update && apt-get install -y python3-pip") || 
               system("yum install -y python3-pip")
          puts "⚠️  Could not install pip3"
        end
      end
      
      # Install Python dependencies
      python_packages = %w[flask requests psutil cryptography]
      python_packages.each do |package|
        unless system("pip3 list | grep -q #{package}")
          puts "📦 Installing Python package: #{package}"
          unless system("pip3 install #{package}")
            puts "⚠️  Failed to install #{package}"
          end
        end
      end
      
      # Create Python virtual environment if needed
      venv_path = File.join(@grim_root, "py_grim", "venv")
      unless Dir.exist?(venv_path)
        puts "🐍 Creating Python virtual environment..."
        unless system("python3 -m venv #{venv_path}")
          puts "⚠️  Failed to create virtual environment"
        end
      end
      
      puts "✅ Python components setup complete"
    end

    # Install Go components
    def install_go_components
      puts "🐹 Installing Go components..."
      
      # Check if Go is available
      unless system("go version > /dev/null 2>&1")
        puts "📦 Installing Go..."
        unless system("apt-get update && apt-get install -y golang-go") ||
               system("yum install -y golang")
          puts "⚠️  Could not install Go"
        end
        return
      end
      
      # Create Go build directory
      go_build_dir = File.join(@grim_root, "go_grim", "build")
      FileUtils.mkdir_p(go_build_dir) unless Dir.exist?(go_build_dir)
      
      # Build Go binaries if source exists
      go_src_dir = File.join(@grim_root, "go_grim")
      if Dir.exist?(go_src_dir) && File.exist?(File.join(go_src_dir, "go.mod"))
        puts "🐹 Building Go binaries..."
        Dir.chdir(go_src_dir) do
          unless system("go mod tidy")
            puts "⚠️  Failed to tidy Go modules"
          end
          unless system("go build -o build/grim-compression .")
            puts "⚠️  Failed to build Go binary"
          end
        end
      end
      
      puts "✅ Go components setup complete"
    end

    # Install Shell components
    def install_shell_components
      puts "🐚 Installing Shell components..."
      
      # Make shell scripts executable
      shell_scripts = [
        "sh_grim/backup.sh",
        "sh_grim/restore.sh", 
        "sh_grim/monitor.sh",
        "sh_grim/scan.sh",
        "sh_grim/security.sh",
        "throne/grim_throne.sh",
        "throne/rb_grim_throne.sh"
      ]
      
      shell_scripts.each do |script|
        script_path = File.join(@grim_root, script)
        if File.exist?(script_path)
          File.chmod(0o755, script_path)
          puts "🔧 Made executable: #{script}"
        end
      end
      
      # Install system dependencies
      system_deps = %w[rsync tar gzip bzip2 xz-utils]
      system_deps.each do |dep|
        unless system("which #{dep} > /dev/null 2>&1")
          puts "📦 Installing system dependency: #{dep}"
          unless system("apt-get update && apt-get install -y #{dep}") ||
                 system("yum install -y #{dep}")
            puts "⚠️  Could not install #{dep}"
          end
        end
      end
      
      puts "✅ Shell components setup complete"
    end

    # Install Scythe components
    def install_scythe_components
      puts "🗡️  Installing Scythe components..."
      
      # Check if scythe directory exists
      scythe_dir = File.join(@grim_root, "scythe")
      unless Dir.exist?(scythe_dir)
        puts "⚠️  Scythe directory not found, creating..."
        FileUtils.mkdir_p(scythe_dir)
      end
      
      # Install Python dependencies for scythe
      if system("python3 --version > /dev/null 2>&1")
        scythe_packages = %w[flask requests cryptography psutil]
        scythe_packages.each do |package|
          unless system("pip3 list | grep -q #{package}")
            puts "📦 Installing Scythe dependency: #{package}"
            unless system("pip3 install #{package}")
              puts "⚠️  Failed to install #{package}"
            end
          end
        end
      end
      
      puts "✅ Scythe components setup complete"
    end

    # Check Ruby version
    def check_ruby_version
      ruby_version = `ruby -e "puts RUBY_VERSION"`.strip
      puts "💎 Ruby Version: #{ruby_version}"

      major, minor = ruby_version.split(".").map(&:to_i)
      if major < 2 || (major == 2 && minor < 7)
        raise Error, "Ruby 2.7+ required, found #{ruby_version}"
      end
    end

    # Install Bundler
    def install_bundler
      unless system("gem list bundler -i > /dev/null 2>&1")
        puts "📦 Installing Bundler..."
        unless system("gem install bundler")
          raise Error, "Failed to install Bundler"
        end
      end
    end

    # Install common Ruby gems
    def install_ruby_gems
      gems = %w[rake rspec rubocop yard reek brakeman bundle-audit]
      
      gems.each do |gem_name|
        unless system("gem list #{gem_name} -i > /dev/null 2>&1")
          puts "📦 Installing #{gem_name}..."
          unless system("gem install #{gem_name}")
            warn "Failed to install #{gem_name}"
          end
        end
      end
    end

    # Setup Ruby version manager
    def setup_ruby_version_manager
      if system("which rvm > /dev/null 2>&1")
        puts "🔄 RVM detected, setting up..."
        system("rvm use --default")
      elsif system("which rbenv > /dev/null 2>&1")
        puts "🔄 rbenv detected, setting up..."
        system("rbenv rehash")
      end
    end

    # Setup .scythe directory structure
    def setup_scythe_directories
      puts "🗡️  Setting up .scythe directory structure..."
      
      scythe_dir = File.join(@grim_root, ".graveyard", ".rip", ".scythe")
      
      # Create main scythe directories
      scythe_subdirs = [
        "config",
        "db", 
        "logs",
        "run",
        "integrations"
      ]
      
      scythe_subdirs.each do |subdir|
        dir_path = File.join(scythe_dir, subdir)
        FileUtils.mkdir_p(dir_path) unless Dir.exist?(dir_path)
      end
      
      # Create log subdirectories
      log_subdirs = ["orchestration", "components", "integrations", "security"]
      log_subdirs.each do |subdir|
        dir_path = File.join(scythe_dir, "logs", subdir)
        FileUtils.mkdir_p(dir_path) unless Dir.exist?(dir_path)
      end
      
      # Create integration subdirectories
      integration_subdirs = ["discovered", "configs", "scripts"]
      integration_subdirs.each do |subdir|
        dir_path = File.join(scythe_dir, "integrations", subdir)
        FileUtils.mkdir_p(dir_path) unless Dir.exist?(dir_path)
      end
      
      # Create scythe configuration file
      config_file = File.join(scythe_dir, "config", "scythe.yaml")
      unless File.exist?(config_file)
        config_content = <<~CONFIG
          # Scythe Configuration
          # Central orchestrator settings for Grim Reaper System

          scythe:
            version: "1.0.5"
            install_date: #{Time.now.iso8601}
            
          database:
            path: "../db/scythe.db"
            auto_backup: true
            backup_interval: "24h"
            
          logging:
            level: "info"
            path: "../logs"
            max_size: "100MB"
            max_files: 10
            
          orchestration:
            enabled: true
            heartbeat_interval: "30s"
            max_concurrent_jobs: 5
            
          integrations:
            enabled: true
            scan_interval: "5m"
            auto_discover: true
            
          security:
            encryption: true
            key_rotation: "30d"
            audit_logs: true
        CONFIG
        
        File.write(config_file, config_content)
        puts "✅ Created scythe configuration: #{config_file}"
      end
      
      # Try to run the universal setup script if available
      setup_script = File.join(@grim_root, "scripts", "setup_scythe_dirs.sh")
      if File.exist?(setup_script)
        begin
          system("bash '#{setup_script}' setup '#{@grim_root}' auto")
          puts "✅ Initialized scythe database"
        rescue
          puts "⚠️  Could not initialize scythe database - basic structure created"
        end
      end
      
      puts "✅ .scythe directory structure created at: #{scythe_dir}"
    end

    # Create necessary directories
    def create_directories
      # Setup .scythe structure first
      setup_scythe_directories
      
      dirs = [
        File.join(@grim_root, "logs"),
        File.join(@grim_root, "cache"),
        @backup_dir,
        File.join(@grim_root, "temp"),
        File.join(@grim_root, "py_grim", "venv"),
        File.join(@grim_root, "go_grim", "build"),
        File.join(@grim_root, "scythe", "logs")
      ]

      dirs.each do |dir|
        FileUtils.mkdir_p(dir) unless Dir.exist?(dir)
        puts "📁 Created directory: #{dir}"
      end
    end

    # Setup environment file
    def setup_environment_file
      env_file = File.join(@grim_root, ".env")
      scythe_dir = File.join(@grim_root, ".graveyard", ".rip", ".scythe")
      env_content = <<~ENV
        # Grim Reaper Environment Configuration
        GRIM_ROOT=#{@grim_root}
        SCYTHE_DIR=#{scythe_dir}
        GRIM_BACKUP_DIR=#{@backup_dir}
        GRIM_HOME=#{@install_dir}
        GRIM_RUBY_VERSION=#{`ruby -e "puts RUBY_VERSION"`.strip}
        GRIM_PYTHON_VERSION=#{`python3 --version 2>/dev/null | cut -d' ' -f2` || 'Not installed'}
        GRIM_GO_VERSION=#{`go version 2>/dev/null | cut -d' ' -f3` || 'Not installed'}
      ENV

      File.write(env_file, env_content)
      puts "📄 Created environment file: #{env_file}"
    end

    # Verify installation
    def verify_installation
      puts "🔍 Verifying installation..."

      checks = [
        { name: "Ruby", check: -> { system("ruby --version > /dev/null 2>&1") } },
        { name: "Bundler", check: -> { system("bundle --version > /dev/null 2>&1") } },
        { name: "Python3", check: -> { system("python3 --version > /dev/null 2>&1") } },
        { name: "Go", check: -> { system("go version > /dev/null 2>&1") } },
        { name: "Grim Root", check: -> { Dir.exist?(@grim_root) } },
        { name: "Ruby Throne", check: -> { File.exist?(File.join(@grim_root, "throne", "rb_grim_throne.sh")) } },
        { name: "Python Throne", check: -> { File.exist?(File.join(@grim_root, "throne", "py_grim_throne.sh")) } },
        { name: "Go Throne", check: -> { File.exist?(File.join(@grim_root, "throne", "go_grim_throne.sh")) } },
        { name: "Shell Throne", check: -> { File.exist?(File.join(@grim_root, "throne", "sh_grim_throne.sh")) } },
        { name: "Backup Directory", check: -> { Dir.exist?(@backup_dir) } }
      ]

      checks.each do |check|
        if check[:check].call
          puts "✅ #{check[:name]}: OK"
        else
          puts "❌ #{check[:name]}: FAILED"
        end
      end
    end

    # Get installation status
    def status
      {
        ruby_version: `ruby -e "puts RUBY_VERSION"`.strip,
        bundler_version: `bundle --version 2>/dev/null`.strip,
        python_version: `python3 --version 2>/dev/null | cut -d' ' -f2` || 'Not installed',
        go_version: `go version 2>/dev/null | cut -d' ' -f3` || 'Not installed',
        grim_root: @grim_root,
        backup_dir: @backup_dir,
        install_dir: @install_dir,
        ruby_throne_exists: File.exist?(File.join(@grim_root, "throne", "rb_grim_throne.sh")),
        python_throne_exists: File.exist?(File.join(@grim_root, "throne", "py_grim_throne.sh")),
        go_throne_exists: File.exist?(File.join(@grim_root, "throne", "go_grim_throne.sh")),
        shell_throne_exists: File.exist?(File.join(@grim_root, "throne", "sh_grim_throne.sh")),
        backup_dir_exists: Dir.exist?(@backup_dir)
      }
    end

    # Cleanup temporary files
    def cleanup
      temp_dir = File.join(@grim_root, "temp")
      if Dir.exist?(temp_dir)
        FileUtils.rm_rf(temp_dir)
        puts "🧹 Cleaned temporary directory"
      end
    end

    # Post-install hook
    def self.post_install
      new.setup_complete_environment
    end

    # Post-update hook
    def self.post_update
      new.verify_installation
    end
  end
end 