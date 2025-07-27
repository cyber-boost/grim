# frozen_string_literal: true

require "openssl"
require "base64"
require "uri"
require "json"
require "fileutils"

module GrimReaper
  # OTP (One-Time Password) authentication module
  class OtpModule
    attr_reader :config, :grim_root, :secret_file, :config_file

    def initialize(config = {}, grim_root = nil)
      @config = config
      @grim_root = grim_root || Dir.pwd
      @secret_file = File.join(@grim_root, ".grim_otp_secret")
      @config_file = File.join(@grim_root, ".grim_otp_config")
    end

    # Setup OTP authentication
    def setup_otp
      secret = generate_secret
      
      # Save secret securely
      File.write(@secret_file, secret)
      File.chmod(0o600, @secret_file)
      
      # Generate QR code URL
      qr_url = generate_qr_url(secret)
      
      # Generate backup codes
      backup_codes = generate_backup_codes
      
      # Save configuration
      otp_config = {
        enabled: true,
        created_at: Time.now.iso8601,
        backup_codes: backup_codes.map { |code| { code: code, used: false } },
        failed_attempts: 0,
        last_auth: nil
      }
      
      File.write(@config_file, JSON.pretty_generate(otp_config))
      File.chmod(0o600, @config_file)
      
      puts "🔑 OTP Secret: #{secret}".colorize(:green)
      puts "📱 QR Code URL: #{qr_url}".colorize(:blue)
      puts "💾 Backup Codes:".colorize(:yellow)
      backup_codes.each_with_index do |code, index|
        puts "   #{index + 1}. #{code}".colorize(:cyan)
      end
      puts "⚠️  Save these backup codes in a secure location!".colorize(:red)
      
      true
    rescue => e
      puts "Error setting up OTP: #{e.message}".colorize(:red)
      false
    end

    # Verify OTP code
    def verify_otp(code)
      return false unless otp_enabled?
      
      config_data = load_config
      secret = load_secret
      
      # Check if it's a backup code
      if verify_backup_code(code, config_data)
        mark_backup_code_used(code, config_data)
        update_last_auth(config_data)
        return true
      end
      
      # Verify TOTP code
      current_time = Time.now.to_i / 30
      
      # Check current and previous time windows (to handle clock skew)
      [-1, 0, 1].each do |offset|
        if generate_totp(secret, current_time + offset) == code.to_s.rjust(6, '0')
          update_last_auth(config_data)
          reset_failed_attempts(config_data)
          return true
        end
      end
      
      # Increment failed attempts
      increment_failed_attempts(config_data)
      false
    rescue => e
      puts "Error verifying OTP: #{e.message}".colorize(:red)
      false
    end

    # Check OTP status
    def status
      if otp_enabled?
        config_data = load_config
        {
          enabled: true,
          last_auth: config_data['last_auth'],
          failed_attempts: config_data['failed_attempts'] || 0,
          backup_codes_remaining: count_unused_backup_codes(config_data)
        }
      else
        {
          enabled: false,
          last_auth: nil,
          failed_attempts: 0,
          backup_codes_remaining: 0
        }
      end
    rescue => e
      { error: e.message }
    end

    # Execute OTP-related commands
    def execute(command, *args)
      case command
      when 'setup'
        setup_otp
      when 'verify'
        verify_otp(args.first)
      when 'status'
        status
      when 'disable'
        disable_otp
      when 'regenerate-backup-codes'
        regenerate_backup_codes
      else
        { error: "Unknown OTP command: #{command}" }
      end
    end

    # Disable OTP authentication
    def disable_otp
      File.delete(@secret_file) if File.exist?(@secret_file)
      File.delete(@config_file) if File.exist?(@config_file)
      puts "🔓 OTP authentication disabled".colorize(:yellow)
      true
    rescue => e
      puts "Error disabling OTP: #{e.message}".colorize(:red)
      false
    end

    # Regenerate backup codes
    def regenerate_backup_codes
      return false unless otp_enabled?
      
      config_data = load_config
      backup_codes = generate_backup_codes
      
      config_data['backup_codes'] = backup_codes.map { |code| { code: code, used: false } }
      
      File.write(@config_file, JSON.pretty_generate(config_data))
      
      puts "💾 New Backup Codes:".colorize(:yellow)
      backup_codes.each_with_index do |code, index|
        puts "   #{index + 1}. #{code}".colorize(:cyan)
      end
      
      true
    rescue => e
      puts "Error regenerating backup codes: #{e.message}".colorize(:red)
      false
    end

    private

    # Check if OTP is enabled
    def otp_enabled?
      File.exist?(@secret_file) && File.exist?(@config_file)
    end

    # Load OTP configuration
    def load_config
      return {} unless File.exist?(@config_file)
      JSON.parse(File.read(@config_file))
    rescue JSON::ParserError
      {}
    end

    # Load OTP secret
    def load_secret
      return nil unless File.exist?(@secret_file)
      File.read(@secret_file).strip
    end

    # Generate a random secret for TOTP
    def generate_secret
      Base64.encode64(OpenSSL::Random.random_bytes(20)).gsub(/\W/, '')[0, 32]
    end

    # Generate TOTP code
    def generate_totp(secret, time_counter)
      # Convert secret from base64
      key = Base64.decode64(secret)
      
      # Create HMAC-SHA1
      time_bytes = [time_counter].pack('Q>')
      hmac = OpenSSL::HMAC.digest('sha1', key, time_bytes)
      
      # Dynamic truncation
      offset = hmac[-1].ord & 0x0f
      code = hmac[offset, 4].unpack('N').first & 0x7fffffff
      
      # Return 6-digit code
      sprintf('%06d', code % 1000000)
    end

    # Generate QR code URL for authenticator apps
    def generate_qr_url(secret)
      account = "grim-reaper@#{Socket.gethostname}"
      issuer = "Grim Reaper"
      
      params = {
        secret: secret,
        issuer: issuer,
        algorithm: 'SHA1',
        digits: 6,
        period: 30
      }
      
      query_string = URI.encode_www_form(params)
      "otpauth://totp/#{URI.encode_www_form_component(account)}?#{query_string}"
    end

    # Generate backup codes
    def generate_backup_codes(count = 10)
      Array.new(count) do
        # Generate 8-character alphanumeric codes
        Array.new(8) { [*'0'..'9', *'A'..'Z'].sample }.join
      end
    end

    # Verify backup code
    def verify_backup_code(code, config_data)
      backup_codes = config_data['backup_codes'] || []
      backup_codes.any? { |bc| bc['code'] == code.upcase && !bc['used'] }
    end

    # Mark backup code as used
    def mark_backup_code_used(code, config_data)
      backup_codes = config_data['backup_codes'] || []
      backup_code = backup_codes.find { |bc| bc['code'] == code.upcase }
      backup_code['used'] = true if backup_code
      
      File.write(@config_file, JSON.pretty_generate(config_data))
    end

    # Count unused backup codes
    def count_unused_backup_codes(config_data)
      backup_codes = config_data['backup_codes'] || []
      backup_codes.count { |bc| !bc['used'] }
    end

    # Update last authentication time
    def update_last_auth(config_data)
      config_data['last_auth'] = Time.now.iso8601
      File.write(@config_file, JSON.pretty_generate(config_data))
    end

    # Reset failed attempts counter
    def reset_failed_attempts(config_data)
      config_data['failed_attempts'] = 0
      File.write(@config_file, JSON.pretty_generate(config_data))
    end

    # Increment failed attempts counter
    def increment_failed_attempts(config_data)
      config_data['failed_attempts'] = (config_data['failed_attempts'] || 0) + 1
      File.write(@config_file, JSON.pretty_generate(config_data))
    end
  end
end 