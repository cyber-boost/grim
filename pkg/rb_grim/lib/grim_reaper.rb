# frozen_string_literal: true

require_relative "grim_reaper/version"
require_relative "grim_reaper/core"
require_relative "grim_reaper/shell_module"
require_relative "grim_reaper/python_module"
require_relative "grim_reaper/go_module"
require_relative "grim_reaper/security_module"
require_relative "grim_reaper/otp_module"
require_relative "grim_reaper/installer"

# Grim Reaper - The Ultimate Backup, Monitoring, and Security System
# Ruby Wrapper for all Grim Reaper modules
module GrimReaper
  class Error < StandardError; end
  
  # Main entry point for the gem
  def self.new(config = {})
    Core.new(config)
  end
  
  # Quick access methods
  def self.status
    Core.new.status
  end
  
  def self.execute(command, *args)
    Core.new.execute(command, *args)
  end
  
  def self.backup(path)
    Core.new.execute('backup', path)
  end
  
  def self.monitor(path)
    Core.new.execute('monitor', path)
  end
  
  def self.security
    Core.new.execute('security')
  end

  def self.setup_otp
    Core.new.get_otp_module.setup_otp
  end

  def self.verify_otp(code)
    Core.new.get_otp_module.verify_otp(code)
  end
end 