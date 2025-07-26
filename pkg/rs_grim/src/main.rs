//! Grim Reaper Rust Package
//! Real core integration with sh_grim, py_grim, and go_grim
//! No mock files - calls actual core modules and binaries

use anyhow::{Context, Result};
use clap::{Parser, Subcommand};
use reqwest;
use serde_json::Value;
use std::env;
use std::path::{Path, PathBuf};
use tokio::process::Command as AsyncCommand;

#[derive(Parser)]
#[command(name = "grim")]
#[command(about = "Grim Reaper - Real core integration with sh_grim, py_grim, and go_grim")]
#[command(version = "1.0.1")]
struct Cli {
    #[command(subcommand)]
    command: Commands,
}

#[derive(Subcommand)]
enum Commands {
    /// Create backup using sh_grim/backup.sh
    Backup {
        /// Source path to backup
        source: String,
        /// Backup name
        #[arg(short, long)]
        name: Option<String>,
        /// Compression algorithm (zstd, gzip, lz4, brotli)
        #[arg(short, long, default_value = "zstd")]
        compress: String,
        /// Create incremental backup
        #[arg(short, long)]
        incremental: bool,
    },

    /// Restore from backup using sh_grim/restore.sh
    Restore {
        /// Backup file to restore
        backup: String,
        /// Destination path
        destination: String,
        /// Overwrite existing files
        #[arg(short, long)]
        overwrite: bool,
    },

    /// List available backups
    ListBackups,

    /// Compress file using go_grim compression engine
    Compress {
        /// File to compress
        file: String,
        /// Compression algorithm
        #[arg(short, long, default_value = "zstd")]
        algorithm: String,
        /// Compression level (1-22)
        #[arg(short, long, default_value = "6")]
        level: u8,
        /// Output file
        #[arg(short, long)]
        output: Option<String>,
    },

    /// Decompress file using go_grim
    Decompress {
        /// File to decompress
        file: String,
        /// Output file
        #[arg(short, long)]
        output: Option<String>,
    },

    /// Start monitoring using sh_grim/monitor.sh
    Monitor {
        /// Path to monitor
        path: String,
        /// Monitoring interval in seconds
        #[arg(short, long, default_value = "5")]
        interval: u64,
        /// Events to monitor (all, create, delete, modify)
        #[arg(short, long, default_value = "all")]
        events: String,
    },

    /// Stop monitoring
    StopMonitor,

    /// Get monitoring status
    MonitorStatus,

    /// Scan directory using sh_grim/scan.sh
    Scan {
        /// Path to scan
        path: String,
        /// Recursive scan
        #[arg(short, long)]
        recursive: bool,
        /// File types to scan
        #[arg(short, long)]
        types: Option<String>,
        /// Output file
        #[arg(short, long)]
        output: Option<String>,
    },

    /// Security scan using sh_grim/security.sh
    SecurityScan {
        /// Path to scan
        path: String,
        /// Deep security scan
        #[arg(short, long)]
        deep: bool,
        /// Report output file
        #[arg(short, long)]
        report: Option<String>,
    },

    /// System health check using sh_grim/health.sh
    Health,

    /// Get system status
    Status,

    /// Optimize system using sh_grim/blacksmith.sh
    Optimize {
        /// Optimization target (all, memory, disk, network)
        #[arg(short, long, default_value = "all")]
        target: String,
    },

    /// Self-healing using sh_grim/healer.sh
    Heal,

    /// Get API status from py_grim FastAPI
    ApiStatus,

    /// Get backup info via API
    ApiBackups,

    /// Execute raw grim command via throne script
    Exec {
        /// Command to execute
        command: String,
        /// Command arguments
        args: Vec<String>,
    },

    /// Show Grim version and build info
    Version,

    /// Check if Grim services are running
    Services,

    /// Setup .scythe directory structure
    SetupScythe,
    
    /// Install Grim Reaper from latest.tar.gz
    Install {
        /// Installation directory
        #[arg(short, long)]
        directory: Option<String>,
        /// Skip confirmation prompts
        #[arg(short, long)]
        yes: bool,
    },
}

/// Grim Reaper core integration struct
struct GrimReaper {
    grim_root: PathBuf,
    api_base: String,
}

impl GrimReaper {
    /// Initialize with portable path discovery
    fn new() -> Result<Self> {
        let grim_root = match Self::find_grim_root() {
            Ok(root) => root,
            Err(_) => {
                println!("🔍 Grim Reaper not found locally");
                println!("💡 Please run: grim install");
                println!("   Or install manually: curl -fsSL https://get.grim.so | sudo bash");
                anyhow::bail!("Grim Reaper not installed. Run 'grim install' to install automatically.");
            }
        };
        
        Ok(Self {
            grim_root,
            api_base: "http://localhost:8000".to_string(),
        })
    }

    /// Find Grim Reaper installation directory
    fn find_grim_root() -> Result<PathBuf> {
        // Check environment variable first
        if let Ok(env_path) = env::var("GRIM_ROOT") {
            let path = PathBuf::from(env_path);
            if Self::is_grim_installation(&path) {
                return Ok(path);
            }
        }

        // Search up directory tree
        let mut current_dir = env::current_dir()?;
        for _ in 0..10 {
            if Self::is_grim_installation(&current_dir) {
                return Ok(current_dir);
            }
            
            match current_dir.parent() {
                Some(parent) => current_dir = parent.to_path_buf(),
                None => break,
            }
        }

        // Try common installation paths
        let possible_paths = [
            "/opt/reaper",
            "/usr/local/reaper",
            "/usr/local/share/reaper",
            "/usr/share/reaper",
            "/usr/local/lib/grim-reaper",
            "/usr/lib/grim-reaper",
        ];

        for path_str in &possible_paths {
            let path = PathBuf::from(path_str);
            if Self::is_grim_installation(&path) {
                return Ok(path);
            }
        }

        // Try user directories
        if let Some(home_dir) = dirs::home_dir() {
            let user_paths = [
                home_dir.join("reaper"),
                home_dir.join(".reaper"),
            ];
            for path in &user_paths {
                if Self::is_grim_installation(path) {
                    return Ok(path.clone());
                }
            }
        }

        anyhow::bail!(
            "Could not find Grim Reaper root directory.\n\n\
            Please ensure Grim Reaper is properly installed using:\n\
            • curl -fsSL https://get.grim.so | sudo bash\n\
            • wget -qO- https://get.grim.so | sudo bash\n\n\
            Or set GRIM_ROOT environment variable:\n\
            export GRIM_ROOT=/path/to/your/grim/installation"
        );
    }

    /// Check if path contains a valid Grim installation
    fn is_grim_installation(path: &Path) -> bool {
        if !path.is_dir() {
            return false;
        }

        // Check for key Grim files
        let key_files = [
            "throne/grim_throne.sh",
            "tsk_flask/grim_admin_server.py",
            "sh_grim/backup.sh",
            "go_grim/build/grim-compression",
        ];

        key_files.iter().any(|key_file| {
            path.join(key_file).exists()
        })
    }

    /// Execute sh_grim module with proper error handling
    async fn execute_sh_module(&self, module: &str, args: &[String]) -> Result<String> {
        let throne_path = self.grim_root.join("throne").join("grim_throne.sh");
        
        if !throne_path.exists() {
            anyhow::bail!("Throne script not found: {}", throne_path.display());
        }

        let mut cmd_args = vec![module.to_string()];
        if !args.is_empty() {
            cmd_args.extend(args.iter().cloned());
        }

        let mut cmd = AsyncCommand::new(&throne_path);
        cmd.args(&cmd_args)
            .current_dir(&self.grim_root)
            .env("GRIM_ROOT", &self.grim_root)
            .kill_on_drop(true);

        let output = cmd.output().await
            .with_context(|| format!("Failed to execute module: {}", module))?;

        let stdout = String::from_utf8_lossy(&output.stdout);
        let stderr = String::from_utf8_lossy(&output.stderr);

        if !output.status.success() {
            anyhow::bail!("Module {} failed: {} (stderr: {})", module, stdout, stderr);
        }

        Ok(stdout.to_string())
    }

    /// Execute go_grim binary with proper error handling
    async fn execute_go_binary(&self, binary: &str, args: &[String]) -> Result<String> {
        let binary_path = self.grim_root.join("go_grim").join("build").join(binary);
        
        if !binary_path.exists() {
            anyhow::bail!("Go binary not found: {}", binary);
        }

        let mut cmd = AsyncCommand::new(&binary_path);
        cmd.args(args)
            .current_dir(&self.grim_root)
            .kill_on_drop(true);

        let output = cmd.output().await
            .with_context(|| format!("Failed to execute Go binary: {}", binary))?;

        if !output.status.success() {
            let stderr = String::from_utf8_lossy(&output.stderr);
            anyhow::bail!("Go binary {} failed: {}", binary, stderr);
        }

        Ok(String::from_utf8_lossy(&output.stdout).to_string())
    }

    /// Call py_grim FastAPI service
    async fn call_py_api(&self, endpoint: &str) -> Result<Value> {
        let url = format!("{}{}", self.api_base, endpoint);
        
        let client = reqwest::Client::new();
        let response = client.get(&url)
            .timeout(std::time::Duration::from_secs(30))
            .send()
            .await
            .with_context(|| format!("Failed to call API endpoint: {}", endpoint))?;

        if !response.status().is_success() {
            anyhow::bail!("API call failed with status: {}", response.status());
        }

        let json = response.json::<Value>().await
            .with_context(|| "Failed to parse API response as JSON")?;

        Ok(json)
    }

    /// Execute raw grim command via throne script
    async fn execute_command(&self, command: &str, args: &[String]) -> Result<String> {
        let throne_path = self.grim_root.join("throne").join("grim_throne.sh");
        
        let mut cmd_args = vec![command.to_string()];
        cmd_args.extend(args.iter().cloned());

        let mut cmd = AsyncCommand::new(&throne_path);
        cmd.args(&cmd_args)
            .current_dir(&self.grim_root)
            .env("GRIM_ROOT", &self.grim_root)
            .kill_on_drop(true);

        let output = cmd.output().await
            .with_context(|| format!("Failed to execute command: {}", command))?;

        if !output.status.success() {
            let stderr = String::from_utf8_lossy(&output.stderr);
            anyhow::bail!("Command {} failed: {}", command, stderr);
        }

        Ok(String::from_utf8_lossy(&output.stdout).to_string())
    }
}

/// Install Grim Reaper from latest.tar.gz
async fn install_grim(directory: Option<String>, skip_confirmation: bool) -> Result<()> {
    use std::fs;
    use std::io::{self, Write};
    use std::process::Command;
    
    println!("🗡️  Grim Reaper Installer");
    println!("========================\n");
    
    // Determine installation directory
    let install_dir = match directory {
        Some(dir) => PathBuf::from(dir),
        None => {
            if let Some(home_dir) = dirs::home_dir() {
                home_dir.join(".grim-reaper")
            } else {
                PathBuf::from("/opt/grim-reaper")
            }
        }
    };
    
    println!("📁 Installation directory: {}", install_dir.display());
    
    // Check if already installed
    if install_dir.exists() && GrimReaper::is_grim_installation(&install_dir) {
        println!("✅ Grim Reaper is already installed at: {}", install_dir.display());
        return Ok(());
    }
    
    // Confirmation prompt
    if !skip_confirmation {
        print!("🤔 Proceed with installation? [y/N]: ");
        io::stdout().flush()?;
        
        let mut input = String::new();
        io::stdin().read_line(&mut input)?;
        
        if !input.trim().to_lowercase().starts_with('y') {
            println!("❌ Installation cancelled");
            return Ok(());
        }
    }
    
    // Create installation directory
    println!("📦 Creating installation directory...");
    fs::create_dir_all(&install_dir)?;
    
    // Download latest.tar.gz
    println!("📥 Downloading Grim Reaper from get.grim.so...");
    let temp_file = install_dir.join("grim-latest.tar.gz");
    
    let client = reqwest::Client::new();
    let response = client
        .get("https://get.grim.so/latest.tar.gz")
        .send()
        .await
        .context("Failed to download Grim Reaper")?;
    
    if !response.status().is_success() {
        anyhow::bail!("Failed to download: HTTP {}", response.status());
    }
    
    let bytes = response.bytes().await.context("Failed to read response")?;
    fs::write(&temp_file, &bytes).context("Failed to save download")?;
    println!("✅ Download complete");
    
    // Extract tarball
    println!("📦 Extracting Grim Reaper...");
    let status = Command::new("tar")
        .args(&["-xzf", temp_file.to_str().unwrap()])
        .current_dir(&install_dir)
        .status()
        .context("Failed to extract tarball")?;
    
    if !status.success() {
        anyhow::bail!("Failed to extract tarball");
    }
    
    // Remove temp file
    let _ = fs::remove_file(&temp_file);
    
    // Make scripts executable
    println!("🔧 Making scripts executable...");
    let scripts = [
        "throne/grim_throne.sh",
        "throne/sh_grim_throne.sh", 
        "throne/py_grim_throne.sh",
        "throne/go_grim_throne.sh",
        "sh_grim/*.sh",
        "go_grim/build/*",
        "install.sh",
        "master-install.sh"
    ];
    
    for pattern in &scripts {
        if pattern.contains('*') {
            // Handle glob patterns
            let dir = install_dir.join(pattern.split('*').next().unwrap());
            if dir.exists() {
                let _ = Command::new("chmod")
                    .args(&["+x", "-R", dir.to_str().unwrap()])
                    .status();
            }
        } else {
            let script_path = install_dir.join(pattern);
            if script_path.exists() {
                let _ = Command::new("chmod")
                    .args(&["+x", script_path.to_str().unwrap()])
                    .status();
            }
        }
    }
    
    // Setup environment
    println!("🔧 Setting up environment...");
    let grim_root = install_dir.to_str().unwrap();
    let scythe_dir = format!("{}/.graveyard/.rip/.scythe", grim_root);
    
    // Create scythe directories
    let directories = ["config", "db", "logs", "run", "integrations"];
    for dir in &directories {
        let dir_path = format!("{}/{}", scythe_dir, dir);
        let _ = fs::create_dir_all(&dir_path);
    }
    
    // Create log subdirectories
    let log_subdirs = ["orchestration", "components", "integrations", "security"];
    for subdir in &log_subdirs {
        let dir_path = format!("{}/logs/{}", scythe_dir, subdir);
        let _ = fs::create_dir_all(&dir_path);
    }
    
    // Create integration subdirectories
    let integration_subdirs = ["discovered", "configs", "scripts"];
    for subdir in &integration_subdirs {
        let dir_path = format!("{}/integrations/{}", scythe_dir, subdir);
        let _ = fs::create_dir_all(&dir_path);
    }
    
    // Create scythe configuration
    let config_file = format!("{}/config/scythe.yaml", scythe_dir);
    if !Path::new(&config_file).exists() {
        let config_content = format!(r#"# Scythe Configuration
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
"#, std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).unwrap().as_secs());
        
        let _ = fs::write(&config_file, config_content);
    }
    
    println!("\n✅ Grim Reaper installation complete!");
    println!("📁 Installed to: {}", install_dir.display());
    println!("💡 Restart your shell or run: source ~/.bashrc");
    println!("🗡️  Then use: grim <command>\n");
    
    Ok(())
}

/// Setup .scythe directory structure
fn setup_scythe_directories() {
    use std::fs;
    use std::path::Path;
    use std::process::Command;
    
    println!("🗡️  Setting up .scythe directory structure...");
    
    let grim_root = detect_grim_root();
    let scythe_dir = format!("{}/.graveyard/.rip/.scythe", grim_root);
    
    // Create main scythe directories
    let directories = [
        "config",
        "db", 
        "logs",
        "run",
        "integrations"
    ];
    
    for dir in &directories {
        let dir_path = format!("{}/{}", scythe_dir, dir);
        if let Err(e) = fs::create_dir_all(&dir_path) {
            eprintln!("⚠️  Warning: Could not create directory {}: {}", dir_path, e);
        }
    }
    
    // Create log subdirectories
    let log_subdirs = [
        "orchestration",
        "components", 
        "integrations",
        "security"
    ];
    
    for subdir in &log_subdirs {
        let dir_path = format!("{}/logs/{}", scythe_dir, subdir);
        if let Err(e) = fs::create_dir_all(&dir_path) {
            eprintln!("⚠️  Warning: Could not create log directory {}: {}", dir_path, e);
        }
    }
    
    // Create integration subdirectories  
    let integration_subdirs = [
        "discovered",
        "configs",
        "scripts"
    ];
    
    for subdir in &integration_subdirs {
        let dir_path = format!("{}/integrations/{}", scythe_dir, subdir);
        if let Err(e) = fs::create_dir_all(&dir_path) {
            eprintln!("⚠️  Warning: Could not create integration directory {}: {}", dir_path, e);
        }
    }
    
    // Create scythe configuration file
    let config_file = format!("{}/config/scythe.yaml", scythe_dir);
    if !Path::new(&config_file).exists() {
        let config_content = format!(r#"# Scythe Configuration
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
"#, std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).unwrap().as_secs());
        
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

/// Detect GRIM_ROOT dynamically
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
    format!("{}/.graveyard", env::var("HOME").unwrap_or_else(|_| "/root".to_string()))
}

#[tokio::main]
async fn main() -> Result<()> {
    let cli = Cli::parse();
    
    // Handle install command specially - it doesn't need Grim to be installed
    if let Commands::Install { directory, yes } = &cli.command {
        install_grim(directory.clone(), *yes).await?;
        return Ok(());
    }
    
    // For all other commands, Grim must be installed
    let grim = GrimReaper::new()?;

    match &cli.command {
        Commands::Backup { source, name, compress, incremental } => {
            // The throne script expects: grim backup create <source> [options]
            let mut args = vec!["create".to_string(), source.clone()];
            if let Some(name) = name {
                args.extend(["--name".to_string(), name.clone()]);
            }
            args.extend(["--compress".to_string(), compress.clone()]);
            if *incremental {
                args.push("--incremental".to_string());
            }
            let result = grim.execute_sh_module("backup", &args).await?;
            println!("{}", result);
        },
        Commands::Restore { backup, destination, overwrite } => {
            let mut args = vec![backup.clone(), destination.clone()];
            if *overwrite {
                args.push("--overwrite".to_string());
            }
            let result = grim.execute_sh_module("restore", &args).await?;
            println!("{}", result);
        },
        Commands::ListBackups => {
            let result = grim.execute_sh_module("backup", &["list".to_string()]).await?;
            println!("{}", result);
        },
        Commands::Compress { file, algorithm, level, output } => {
            let mut args = vec![];
            args.extend(["-a".to_string(), algorithm.clone()]);
            args.extend(["-l".to_string(), level.to_string()]);
            if let Some(output) = output {
                args.extend(["-o".to_string(), output.clone()]);
            }
            args.push(file.clone());
            let result = grim.execute_go_binary("grim-compression", &args).await?;
            println!("{}", result);
        },
        Commands::Decompress { file, output } => {
            let mut args = vec!["-d".to_string()];
            if let Some(output) = output {
                args.extend(["-o".to_string(), output.clone()]);
            }
            args.push(file.clone());
            let result = grim.execute_go_binary("grim-compression", &args).await?;
            println!("{}", result);
        },
        Commands::Monitor { path, interval, events } => {
            let args = vec![
                "start".to_string(),
                path.clone(),
                "--interval".to_string(),
                interval.to_string(),
                "--events".to_string(),
                events.clone(),
            ];
            let result = grim.execute_sh_module("monitor", &args).await?;
            println!("{}", result);
        },
        Commands::StopMonitor => {
            let result = grim.execute_sh_module("monitor", &["stop".to_string()]).await?;
            println!("{}", result);
        },
        Commands::MonitorStatus => {
            let result = grim.execute_sh_module("monitor", &["status".to_string()]).await?;
            println!("{}", result);
        },
        Commands::Scan { path, recursive, types, output } => {
            let mut args = vec![path.clone()];
            if *recursive {
                args.push("--recursive".to_string());
            }
            if let Some(types) = types {
                args.extend(["--types".to_string(), types.clone()]);
            }
            if let Some(output) = output {
                args.extend(["--output".to_string(), output.clone()]);
            }
            let result = grim.execute_sh_module("scan", &args).await?;
            println!("{}", result);
        },
        Commands::SecurityScan { path, deep, report } => {
            let mut args = vec![path.clone()];
            if *deep {
                args.push("--deep".to_string());
            }
            if let Some(report) = report {
                args.extend(["--report".to_string(), report.clone()]);
            }
            let result = grim.execute_sh_module("security", &args).await?;
            println!("{}", result);
        },
        Commands::Health => {
            let result = grim.execute_sh_module("health", &["check".to_string()]).await?;
            println!("{}", result);
        },
        Commands::Status => {
            let result = grim.execute_sh_module("health", &["status".to_string()]).await?;
            println!("{}", result);
        },
        Commands::Optimize { target } => {
            let args = vec!["optimize".to_string(), target.clone()];
            let result = grim.execute_sh_module("blacksmith", &args).await?;
            println!("{}", result);
        },
        Commands::Heal => {
            let result = grim.execute_sh_module("healer", &["heal".to_string()]).await?;
            println!("{}", result);
        },
        Commands::ApiStatus => {
            let result = grim.call_py_api("/api/status").await?;
            println!("{}", serde_json::to_string_pretty(&result)?);
        },
        Commands::ApiBackups => {
            let result = grim.call_py_api("/api/backups").await?;
            println!("{}", serde_json::to_string_pretty(&result)?);
        },
        Commands::Exec { command, args } => {
            let result = grim.execute_command(command, args).await?;
            println!("{}", result);
        },
        Commands::Version => {
            // Try to read manifest file first
            let manifest_path = grim.grim_root.join("builds").join("latest").join("manifest.tsk");
            if manifest_path.exists() {
                match tokio::fs::read_to_string(&manifest_path).await {
                    Ok(content) => println!("{}", content),
                    Err(_) => {
                        let result = grim.execute_command("version", &[]).await?;
                        println!("{}", result);
                    },
                }
            } else {
                let result = grim.execute_command("version", &[]).await?;
                println!("{}", result);
            }
        },
        Commands::Services => {
            println!("🗡️  Grim Reaper Services Status");
            
            // Check if services are running using pgrep
            let services = [
                ("FastAPI", "grim_web"),
                ("Monitoring", "monitor.sh"),
                ("Admin Server", "grim_admin_server.py"),
            ];
            
            for (name, process) in &services {
                let mut cmd = AsyncCommand::new("pgrep");
                cmd.args(["-f", process]);
                
                match cmd.output().await {
                    Ok(output) if output.status.success() => {
                        println!("✅ {}: Running", name);
                    },
                    _ => {
                        println!("❌ {}: Not running", name);
                    },
                }
            }
        },
        Commands::SetupScythe => {
            setup_scythe_directories();
            println!("✅ .scythe directory structure setup complete");
        },
        Commands::Install { directory, yes } => {
            install_grim(directory.clone(), *yes).await?;
        },
    }

    Ok(())
}

