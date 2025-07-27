# frozen_string_literal: true

require "open3"

module GrimReaper
  # Go module wrapper for go_grim operations
  class GoModule
    attr_reader :config, :grim_root

    def initialize(config, grim_root)
      @config = config
      @grim_root = grim_root
    end

    def execute(command, *args)
      case command
      when "compress"
        execute_compress(*args)
      when "decompress"
        execute_decompress(*args)
      when "build"
        execute_build(*args)
      when "test"
        execute_test(*args)
      when "benchmark"
        execute_benchmark(*args)
      else
        execute_generic(command, *args)
      end
    end

    def status
      {
        status: "ready",
        module: "go",
        available_commands: %w[compress decompress build test benchmark],
        grim_root: @grim_root
      }
    end

    private

    def execute_compress(*args)
      binary_path = File.join(@grim_root, "go_grim", "build", "grim-compression")
      
      if File.exist?(binary_path)
        stdout, stderr, status = Open3.capture3(binary_path, "-input", *args, chdir: @grim_root)
        {
          command: "compress",
          args: args,
          stdout: stdout,
          stderr: stderr,
          success: status.success?,
          module: "go"
        }
      else
        { error: "Go compression binary not found", module: "go" }
      end
    end

    def execute_decompress(*args)
      binary_path = File.join(@grim_root, "go_grim", "build", "grim-compression")
      
      if File.exist?(binary_path)
        stdout, stderr, status = Open3.capture3(binary_path, "-decompress", *args, chdir: @grim_root)
        {
          command: "decompress",
          args: args,
          stdout: stdout,
          stderr: stderr,
          success: status.success?,
          module: "go"
        }
      else
        { error: "Go compression binary not found", module: "go" }
      end
    end

    def execute_build(*args)
      go_path = File.join(@grim_root, "go_grim")
      
      if Dir.exist?(go_path)
        stdout, stderr, status = Open3.capture3("go", "build", "-o", "build/grim-compression", ".", chdir: go_path)
        {
          command: "build",
          args: args,
          stdout: stdout,
          stderr: stderr,
          success: status.success?,
          module: "go"
        }
      else
        { error: "Go source directory not found", module: "go" }
      end
    end

    def execute_test(*args)
      go_path = File.join(@grim_root, "go_grim")
      
      if Dir.exist?(go_path)
        stdout, stderr, status = Open3.capture3("go", "test", *args, chdir: go_path)
        {
          command: "test",
          args: args,
          stdout: stdout,
          stderr: stderr,
          success: status.success?,
          module: "go"
        }
      else
        { error: "Go source directory not found", module: "go" }
      end
    end

    def execute_benchmark(*args)
      go_path = File.join(@grim_root, "go_grim")
      
      if Dir.exist?(go_path)
        stdout, stderr, status = Open3.capture3("go", "test", "-bench=.", *args, chdir: go_path)
        {
          command: "benchmark",
          args: args,
          stdout: stdout,
          stderr: stderr,
          success: status.success?,
          module: "go"
        }
      else
        { error: "Go source directory not found", module: "go" }
      end
    end

    def execute_generic(command, *args)
      binary_path = File.join(@grim_root, "go_grim", "build", "grim-#{command}")
      
      if File.exist?(binary_path)
        stdout, stderr, status = Open3.capture3(binary_path, *args, chdir: @grim_root)
        {
          command: command,
          args: args,
          stdout: stdout,
          stderr: stderr,
          success: status.success?,
          module: "go"
        }
      else
        { error: "Go binary not found: grim-#{command}", module: "go" }
      end
    end
  end
end 