use std::env;
use std::fs;
use std::path::Path;
use std::process::Command;

fn main() {
    println!("cargo:rerun-if-changed=build.rs");

    // Only run setup during install/build, not during every compilation
    if env::var("CARGO_CFG_TARGET_OS").is_ok() {
        setup_scythe_directories();
    }
}

fn setup_scythe_directories() {
    println!("🗡️  Setting up .scythe directory structure...");

    let grim_root = detect_grim_root();
    let scythe_dir = format!("{grim_root}/.graveyard/.rip/.scythe");

    // Create main scythe directories
    let directories = ["config", "db", "logs", "run", "integrations"];

    for dir in &directories {
        let dir_path = format!("{}/{}", scythe_dir, dir);
        if let Err(e) = fs::create_dir_all(&dir_path) {
            eprintln!(
                "⚠️  Warning: Could not create directory {}: {}",
                dir_path, e
            );
        }
    }

    // Create log subdirectories
    let log_subdirs = ["orchestration", "components", "integrations", "security"];

    for subdir in &log_subdirs {
        let dir_path = format!("{}/logs/{}", scythe_dir, subdir);
        if let Err(e) = fs::create_dir_all(&dir_path) {
            eprintln!(
                "⚠️  Warning: Could not create log directory {}: {}",
                dir_path, e
            );
        }
    }

    // Create integration subdirectories
    let integration_subdirs = ["discovered", "configs", "scripts"];

    for subdir in &integration_subdirs {
        let dir_path = format!("{}/integrations/{}", scythe_dir, subdir);
        if let Err(e) = fs::create_dir_all(&dir_path) {
            eprintln!(
                "⚠️  Warning: Could not create integration directory {}: {}",
                dir_path, e
            );
        }
    }

    // Create scythe configuration file
    let config_file = format!("{}/config/scythe.yaml", scythe_dir);
    if !Path::new(&config_file).exists() {
        let config_content = format!(
            r#"# Scythe Configuration
# Central orchestrator settings for Grim Reaper System

scythe:
  version: "1.0.5"
  install_date: {}
  
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
"#,
            chrono::Utc::now().to_rfc3339()
        );

        if let Err(e) = fs::write(&config_file, config_content) {
            eprintln!("⚠️  Warning: Could not create scythe configuration: {}", e);
        } else {
            println!("✅ Created scythe configuration: {}", config_file);
        }
    }

    // Try to run the universal setup script if available
    let setup_script = format!("{}/scripts/setup_scythe_dirs.sh", grim_root);
    if Path::new(&setup_script).exists() {
        match Command::new("bash")
            .args(&[&setup_script, "setup", &grim_root, "auto"])
            .output()
        {
            Ok(output) => {
                if output.status.success() {
                    println!("✅ Initialized scythe database");
                } else {
                    eprintln!("⚠️  Could not initialize scythe database - basic structure created");
                }
            }
            Err(e) => {
                eprintln!("⚠️  Could not run setup script: {}", e);
            }
        }
    }

    println!("✅ .scythe directory structure created at: {}", scythe_dir);
}

fn detect_grim_root() -> String {
    // Priority order for GRIM_ROOT detection
    if let Ok(grim_root) = env::var("GRIM_ROOT") {
        return grim_root;
    }

    // Check for existing installation
    let possible_paths = [
        format!("{}/.graveyard/reaper", env::var("HOME").unwrap_or_default()),
        format!("{}/.graveyard", env::var("HOME").unwrap_or_default()),
        "/root/.graveyard/reaper".to_string(),
        "/root/.graveyard".to_string(),
    ];

    for path in &possible_paths {
        if Path::new(path).exists() {
            return path.clone();
        }
    }

    // Default fallback
    format!(
        "{}/.graveyard",
        env::var("HOME").unwrap_or_else(|_| "/root".to_string())
    )
}
