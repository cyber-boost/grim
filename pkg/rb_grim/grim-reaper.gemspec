# frozen_string_literal: true

require_relative "lib/grim_reaper/version"

Gem::Specification.new do |spec|
  spec.name = "grim-reaper"
  spec.version = GrimReaper::VERSION
  spec.authors = ["Bernie Gengel and his beagle Buddy"]
  spec.email = ["rip@grim.so"]

  spec.summary = "Grim: Unified Data Protection Ecosystem with OTP Security"
  spec.description = "When data death comes knocking, Grim ensures resurrection is just a command away. License management, auto backups, highly compressed backups, multi-algorithm compression, content-based deduplication, smart storage tiering save up to 60% space, military-grade encryption, license protection, security surveillance, OTP authentication, and automated threat response."
  spec.homepage = "https://github.com/cyber-boost/grim"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 2.7.0"

  spec.metadata["allowed_push_host"] = "https://rubygems.org"
  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/cyber-boost/grim"
  spec.metadata["changelog_uri"] = "https://github.com/cyber-boost/grim/blob/main/CHANGELOG.md"
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = Dir.glob("{bin,lib,spec,docs}/**/*") + %w[README.md]
  spec.bindir = "bin"
  spec.executables = ["grim"]
  spec.require_paths = ["lib"]

  # Core dependencies
  spec.add_dependency "thor", "~> 1.2"
  spec.add_dependency "colorize", "~> 0.8"
  spec.add_dependency "json", "~> 2.6"
  spec.add_dependency "yaml", "~> 0.2"

  # Development dependencies
  spec.add_development_dependency "rspec", "~> 3.12"
  spec.add_development_dependency "rubocop", "~> 1.50"
  spec.add_development_dependency "yard", "~> 0.9"
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "bundler", "~> 2.4"

  # Optional dependencies for enhanced functionality
  spec.add_development_dependency "reek", "~> 6.1"
  spec.add_development_dependency "brakeman", "~> 6.1"
  spec.add_development_dependency "bundle-audit", "~> 0.1"

  # Post-install message to guide users
  spec.post_install_message = <<~MESSAGE
    🗡️  Grim Reaper Ruby Gem v#{GrimReaper::VERSION} installed successfully!
    
    🆕 NEW: OTP (One-Time Password) Authentication Support!
    Run 'grim otp-setup' to enable secure two-factor authentication.
    
    The gem provides a unified interface to all Grim Reaper modules:
    - Python components (scythe, py_grim)
    - Go components (go_grim)
    - Shell components (sh_grim)
    - Ruby components (rb_grim)
    - OTP Security Module (NEW!)
    
    Run 'grim rb-setup' to configure your environment and install all components.
    Run 'grim help' to see all available commands.
    
    For automatic installation of all Grim Reaper components, run:
    grim setup-complete
    
    🔐 Security Enhancement:
    • Use --otp flag for secure command execution
    • Setup OTP: grim otp-setup
    • Verify OTP: grim otp-verify <code>
    • Check status: grim otp-status
    
    💡 For missing commands, visit: https://get.grim.so
  MESSAGE
end 