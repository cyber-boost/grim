# frozen_string_literal: true

require "open3"

module GrimReaper
  # Shell module wrapper for sh_grim operations
  class ShellModule
    attr_reader :config, :grim_root

    def initialize(config, grim_root)
      @config = config
      @grim_root = grim_root
    end

    def execute(command, *args)
      case command
      when "backup"
        execute_backup(*args)
      when "restore"
        execute_restore(*args)
      when "monitor"
        execute_monitor(*args)
      when "scan"
        execute_scan(*args)
      when "security"
        execute_security(*args)
      else
        execute_generic(command, *args)
      end
    end

    def status
      {
        status: "ready",
        module: "shell",
        available_commands: %w[backup restore monitor scan security],
        grim_root: @grim_root
      }
    end

    private

    def execute_backup(*args)
      path = args.first || "/"
      script_path = File.join(@grim_root, "sh_grim", "backup.sh")
      
      if File.exist?(script_path)
        stdout, stderr, status = Open3.capture3(script_path, "create", path, chdir: @grim_root)
        {
          command: "backup",
          path: path,
          stdout: stdout,
          stderr: stderr,
          success: status.success?,
          module: "shell"
        }
      else
        { error: "Backup script not found", module: "shell" }
      end
    end

    def execute_restore(*args)
      backup = args.first
      return { error: "Backup path required", module: "shell" } unless backup

      script_path = File.join(@grim_root, "sh_grim", "restore.sh")
      
      if File.exist?(script_path)
        stdout, stderr, status = Open3.capture3(script_path, "recover", backup, chdir: @grim_root)
        {
          command: "restore",
          backup: backup,
          stdout: stdout,
          stderr: stderr,
          success: status.success?,
          module: "shell"
        }
      else
        { error: "Restore script not found", module: "shell" }
      end
    end

    def execute_monitor(*args)
      path = args.first || "/"
      script_path = File.join(@grim_root, "sh_grim", "monitor.sh")
      
      if File.exist?(script_path)
        stdout, stderr, status = Open3.capture3(script_path, "start", path, chdir: @grim_root)
        {
          command: "monitor",
          path: path,
          stdout: stdout,
          stderr: stderr,
          success: status.success?,
          module: "shell"
        }
      else
        { error: "Monitor script not found", module: "shell" }
      end
    end

    def execute_scan(*args)
      path = args.first || "/"
      script_path = File.join(@grim_root, "sh_grim", "scan.sh")
      
      if File.exist?(script_path)
        stdout, stderr, status = Open3.capture3(script_path, "full", path, chdir: @grim_root)
        {
          command: "scan",
          path: path,
          stdout: stdout,
          stderr: stderr,
          success: status.success?,
          module: "shell"
        }
      else
        { error: "Scan script not found", module: "shell" }
      end
    end

    def execute_security(*args)
      script_path = File.join(@grim_root, "sh_grim", "security.sh")
      
      if File.exist?(script_path)
        stdout, stderr, status = Open3.capture3(script_path, "audit", chdir: @grim_root)
        {
          command: "security",
          stdout: stdout,
          stderr: stderr,
          success: status.success?,
          module: "shell"
        }
      else
        { error: "Security script not found", module: "shell" }
      end
    end

    def execute_generic(command, *args)
      script_path = File.join(@grim_root, "sh_grim", "#{command}.sh")
      
      if File.exist?(script_path)
        stdout, stderr, status = Open3.capture3(script_path, *args, chdir: @grim_root)
        {
          command: command,
          args: args,
          stdout: stdout,
          stderr: stderr,
          success: status.success?,
          module: "shell"
        }
      else
        { error: "Script not found: #{command}.sh", module: "shell" }
      end
    end
  end
end 