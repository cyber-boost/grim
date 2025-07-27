# frozen_string_literal: true

require "open3"

module GrimReaper
  # Python module wrapper for py_grim operations
  class PythonModule
    attr_reader :config, :grim_root

    def initialize(config, grim_root)
      @config = config
      @grim_root = grim_root
    end

    def execute(command, *args)
      case command
      when "health"
        execute_health
      when "status"
        execute_status
      when "backup"
        execute_backup(*args)
      when "monitor"
        execute_monitor(*args)
      when "security"
        execute_security(*args)
      when "ai"
        execute_ai(*args)
      else
        execute_generic(command, *args)
      end
    end

    def status
      {
        status: "ready",
        module: "python",
        available_commands: %w[health status backup monitor security ai],
        grim_root: @grim_root
      }
    end

    private

    def execute_health
      script_path = File.join(@grim_root, "scythe", "scythe.py")
      
      if File.exist?(script_path)
        stdout, stderr, status = Open3.capture3("python3", script_path, "health", chdir: @grim_root)
        {
          command: "health",
          stdout: stdout,
          stderr: stderr,
          success: status.success?,
          module: "python"
        }
      else
        { error: "Scythe script not found", module: "python" }
      end
    end

    def execute_status
      script_path = File.join(@grim_root, "scythe", "scythe.py")
      
      if File.exist?(script_path)
        stdout, stderr, status = Open3.capture3("python3", script_path, "status", chdir: @grim_root)
        {
          command: "status",
          stdout: stdout,
          stderr: stderr,
          success: status.success?,
          module: "python"
        }
      else
        { error: "Scythe script not found", module: "python" }
      end
    end

    def execute_backup(*args)
      path = args.first || "/"
      script_path = File.join(@grim_root, "scythe", "scythe.py")
      
      if File.exist?(script_path)
        stdout, stderr, status = Open3.capture3("python3", script_path, "backup", path, chdir: @grim_root)
        {
          command: "backup",
          path: path,
          stdout: stdout,
          stderr: stderr,
          success: status.success?,
          module: "python"
        }
      else
        { error: "Scythe script not found", module: "python" }
      end
    end

    def execute_monitor(*args)
      path = args.first || "/"
      script_path = File.join(@grim_root, "py_grim", "grim_web", "app.py")
      
      if File.exist?(script_path)
        # Start monitoring in background
        pid = spawn("python3", script_path, chdir: @grim_root)
        Process.detach(pid)
        {
          command: "monitor",
          path: path,
          pid: pid,
          success: true,
          module: "python"
        }
      else
        { error: "Python web app not found", module: "python" }
      end
    end

    def execute_security(*args)
      script_path = File.join(@grim_root, "scythe", "scythe.py")
      
      if File.exist?(script_path)
        stdout, stderr, status = Open3.capture3("python3", script_path, "security", *args, chdir: @grim_root)
        {
          command: "security",
          args: args,
          stdout: stdout,
          stderr: stderr,
          success: status.success?,
          module: "python"
        }
      else
        { error: "Scythe script not found", module: "python" }
      end
    end

    def execute_ai(*args)
      script_path = File.join(@grim_root, "py_grim", "ai_decision_engine.py")
      
      if File.exist?(script_path)
        stdout, stderr, status = Open3.capture3("python3", script_path, *args, chdir: @grim_root)
        {
          command: "ai",
          args: args,
          stdout: stdout,
          stderr: stderr,
          success: status.success?,
          module: "python"
        }
      else
        { error: "AI script not found", module: "python" }
      end
    end

    def execute_generic(command, *args)
      script_path = File.join(@grim_root, "py_grim", "#{command}.py")
      
      if File.exist?(script_path)
        stdout, stderr, status = Open3.capture3("python3", script_path, *args, chdir: @grim_root)
        {
          command: command,
          args: args,
          stdout: stdout,
          stderr: stderr,
          success: status.success?,
          module: "python"
        }
      else
        { error: "Python script not found: #{command}.py", module: "python" }
      end
    end
  end
end 