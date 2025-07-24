//! Grim Reaper Rust Package
//! Real core integration with sh_grim, py_grim, and go_grim
//! No mock files - calls actual core modules and binaries

use anyhow::{Context, Result};
use clap::{Parser, Subcommand};
use reqwest;
use serde_json::Value;
use std::collections::HashMap;
use std::env;
use std::path::{Path, PathBuf};
use std::process::Command;
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
}

/// Grim Reaper core integration struct
struct GrimReaper {
    grim_root: PathBuf,
    api_base: String,
}

impl GrimReaper {
    /// Initialize with portable path discovery
    fn new() -> Result<Self> {
        let grim_root = Self::find_grim_root()?;
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
        let module_path = self.grim_root.join("sh_grim").join(format!("{}.sh", module));
        
        if !module_path.exists() {
            anyhow::bail!("Module not found: {}", module);
        }

        let mut cmd = AsyncCommand::new(&module_path);
        cmd.args(args)
            .current_dir(&self.grim_root)
            .kill_on_drop(true);

        let output = cmd.output().await
            .with_context(|| format!("Failed to execute module: {}", module))?;

        if !output.status.success() {
            let stderr = String::from_utf8_lossy(&output.stderr);
            anyhow::bail!("Module {} failed: {}", module, stderr);
        }

        Ok(String::from_utf8_lossy(&output.stdout).to_string())
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

#[tokio::main]
async fn main() -> Result<()> {
    let cli = Cli::parse();
    let grim = GrimReaper::new()
        .context("Failed to initialize Grim Reaper - ensure it's properly installed")?;

    match &cli.command {
        Commands::Backup { source, name, compress, incremental } => {
            let mut args = vec![source.clone()];
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
            let result = grim.execute_sh_module("backup", &["--list".to_string()]).await?;
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
    }

    Ok(())
}

