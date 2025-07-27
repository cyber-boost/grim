# frozen_string_literal: true

require "open3"

module GrimReaper
  # Security module wrapper for scythe operations
  class SecurityModule
    attr_reader :config, :grim_root

    def initialize(config, grim_root)
      @config = config
      @grim_root = grim_root
    end

    def execute(command, *args)
      case command
      when "audit"
        execute_audit
      when "scan"
        execute_scan(*args)
      when "encrypt"
        execute_encrypt(*args)
      when "decrypt"
        execute_decrypt(*args)
      when "quarantine"
        execute_quarantine(*args)
      when "threat"
        execute_threat(*args)
      else
        execute_generic(command, *args)
      end
    end

    def status
      {
        status: "ready",
        module: "security",
        available_commands: %w[audit scan encrypt decrypt quarantine threat],
        grim_root: @grim_root
      }
    end

    private

    def execute_audit
      script_path = File.join(@grim_root, "sh_grim", "security.sh")
      
      if File.exist?(script_path)
        stdout, stderr, status = Open3.capture3(script_path, "audit", chdir: @grim_root)
        {
          command: "audit",
          stdout: stdout,
          stderr: stderr,
          success: status.success?,
          module: "security"
        }
      else
        { error: "Security script not found", module: "security" }
      end
    end

    def execute_scan(*args)
      path = args.first || "/"
      script_path = File.join(@grim_root, "sh_grim", "security.sh")
      
      if File.exist?(script_path)
        stdout, stderr, status = Open3.capture3(script_path, "scan-vulnerabilities", path, chdir: @grim_root)
        {
          command: "scan",
          path: path,
          stdout: stdout,
          stderr: stderr,
          success: status.success?,
          module: "security"
        }
      else
        { error: "Security script not found", module: "security" }
      end
    end

    def execute_encrypt(*args)
      file = args.first
      return { error: "File path required", module: "security" } unless file

      script_path = File.join(@grim_root, "sh_grim", "security.sh")
      
      if File.exist?(script_path)
        stdout, stderr, status = Open3.capture3(script_path, "encrypt", file, chdir: @grim_root)
        {
          command: "encrypt",
          file: file,
          stdout: stdout,
          stderr: stderr,
          success: status.success?,
          module: "security"
        }
      else
        { error: "Security script not found", module: "security" }
      end
    end

    def execute_decrypt(*args)
      file = args.first
      return { error: "File path required", module: "security" } unless file

      script_path = File.join(@grim_root, "sh_grim", "security.sh")
      
      if File.exist?(script_path)
        stdout, stderr, status = Open3.capture3(script_path, "decrypt", file, chdir: @grim_root)
        {
          command: "decrypt",
          file: file,
          stdout: stdout,
          stderr: stderr,
          success: status.success?,
          module: "security"
        }
      else
        { error: "Security script not found", module: "security" }
      end
    end

    def execute_quarantine(*args)
      file = args.first
      return { error: "File path required", module: "security" } unless file

      script_path = File.join(@grim_root, "sh_grim", "quarantine.sh")
      
      if File.exist?(script_path)
        stdout, stderr, status = Open3.capture3(script_path, "isolate", file, chdir: @grim_root)
        {
          command: "quarantine",
          file: file,
          stdout: stdout,
          stderr: stderr,
          success: status.success?,
          module: "security"
        }
      else
        { error: "Quarantine script not found", module: "security" }
      end
    end

    def execute_threat(*args)
      script_path = File.join(@grim_root, "scythe", "scythe.py")
      
      if File.exist?(script_path)
        stdout, stderr, status = Open3.capture3("python3", script_path, "threat", *args, chdir: @grim_root)
        {
          command: "threat",
          args: args,
          stdout: stdout,
          stderr: stderr,
          success: status.success?,
          module: "security"
        }
      else
        { error: "Scythe script not found", module: "security" }
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
          module: "security"
        }
      else
        { error: "Security script not found: #{command}.sh", module: "security" }
      end
    end
  end
end 