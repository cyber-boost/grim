# frozen_string_literal: true

require "json"
require "yaml"
require "open3"

module GrimReaper
  # Main Grim Reaper class that orchestrates all modules
  class Core
    attr_reader :config, :modules, :grim_root

    def initialize(config = {})
      @config = config
      @grim_root = find_grim_root
      @modules = {}
      load_modules
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

    # Load all available Grim Reaper modules
    def load_modules
      @modules[:shell] = ShellModule.new(@config, @grim_root)
      @modules[:python] = PythonModule.new(@config, @grim_root)
      @modules[:go] = GoModule.new(@config, @grim_root)
      @modules[:security] = SecurityModule.new(@config, @grim_root)
      @modules[:otp] = OtpModule.new(@config, @grim_root)
    rescue LoadError => e
      warn "Warning: Could not load module: #{e.message}"
    end

    # Get OTP module instance
    def get_otp_module
      @modules[:otp] || OtpModule.new(@config, @grim_root)
    end

    # Validate OTP access if provided
    def validate_otp_access(otp_code)
      return true unless otp_code
      
      otp_module = get_otp_module
      return otp_module.verify_otp(otp_code)
    end

    # Execute a command across all modules
    def execute(command, *args)
      results = {}
      @modules.each do |name, module_instance|
        begin
          results[name] = module_instance.execute(command, *args)
        rescue => e
          results[name] = { error: e.message, module: name.to_s }
        end
      end
      results
    end

    # Get status from all modules
    def status
      status_data = {}
      @modules.each do |name, module_instance|
        begin
          status_data[name] = module_instance.status
        rescue => e
          status_data[name] = { status: "error", error: e.message, module: name.to_s }
        end
      end
      status_data
    end

    # Execute a Ruby-specific command
    def execute_ruby_command(command, *args)
      ruby_throne_path = File.join(@grim_root, "throne", "rb_grim_throne.sh")
      
      unless File.exist?(ruby_throne_path)
        raise Error, "Ruby throne script not found at #{ruby_throne_path}"
      end

      unless File.executable?(ruby_throne_path)
        File.chmod(0o755, ruby_throne_path)
      end

      cmd = [ruby_throne_path, command, *args].compact
      stdout, stderr, status = Open3.capture3(*cmd, chdir: @grim_root)

      {
        command: command,
        args: args,
        stdout: stdout,
        stderr: stderr,
        exit_code: status.exitstatus,
        success: status.success?
      }
    end

    # Get backup directory
    def backup_dir
      ENV["HOME"] + "/.graveyard"
    end

    # Get installation directory
    def install_dir
      ENV["HOME"] + "/reaper"
    end
  end
end 