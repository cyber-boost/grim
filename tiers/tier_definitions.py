#!/usr/bin/env python3
"""
GRIM REAPER SYSTEM - TIER DEFINITIONS AND COMMAND ACCESS CONTROL
Production-ready tier management with comprehensive command categorization
"""

from enum import Enum
from typing import Dict, List, Set, Optional
from dataclasses import dataclass
import json

class TierLevel(Enum):
    """Tier levels in ascending order of access"""
    FREE = "free"
    PRO = "pro"
    MASTER = "master"
    REAPER = "reaper"

@dataclass
class TierLimits:
    """Tier-specific limits and capabilities"""
    name: str
    display_name: str
    price_monthly: int  # cents
    price_annually: int  # cents
    max_storage_gb: int
    max_alerts_monthly: int
    max_api_calls_monthly: int  # -1 for unlimited
    max_file_size_gb: int
    max_monitor_targets: int
    backup_interval_minutes: int
    backup_retention_days: int
    encryption_enabled: bool
    compression_enabled: bool
    support_level: str
    features: List[str]

class CommandCategory(Enum):
    """Command categories for organization"""
    CORE = "core"
    BACKUP = "backup"
    SECURITY = "security"
    MONITORING = "monitoring"
    PERFORMANCE = "performance"
    AI = "ai"
    ENTERPRISE = "enterprise"
    CLOUD = "cloud"
    MAINTENANCE = "maintenance"
    REPORTING = "reporting"
    TESTING = "testing"
    DEVELOPMENT = "development"

@dataclass
class CommandDefinition:
    """Command definition with access control"""
    name: str
    display_name: str
    description: str
    category: CommandCategory
    minimum_tier: TierLevel
    is_billable: bool = False
    usage_weight: float = 1.0
    aliases: List[str] = None
    dependencies: List[str] = None

class TierManager:
    """Comprehensive tier management system"""
    
    def __init__(self):
        self.tier_definitions = self._init_tier_definitions()
        self.command_definitions = self._init_command_definitions()
        self.tier_hierarchy = [TierLevel.FREE, TierLevel.PRO, TierLevel.MASTER, TierLevel.REAPER]
    
    def _init_tier_definitions(self) -> Dict[TierLevel, TierLimits]:
        """Initialize tier definitions based on business requirements"""
        return {
            TierLevel.FREE: TierLimits(
                name="free",
                display_name="Free",
                price_monthly=0,
                price_annually=0,
                max_storage_gb=1,
                max_alerts_monthly=10,
                max_api_calls_monthly=-1,  # Unlimited for CLI usage
                max_file_size_gb=0,  # 100MB = 0.1GB
                max_monitor_targets=1,
                backup_interval_minutes=1440,  # Daily
                backup_retention_days=7,
                encryption_enabled=False,
                compression_enabled=False,
                support_level="community",
                features=[
                    "basic_backup",
                    "basic_restore",
                    "file_scanning",
                    "basic_monitoring",
                    "community_support"
                ]
            ),
            TierLevel.PRO: TierLimits(
                name="pro",
                display_name="Pro",
                price_monthly=2000,  # $20.00
                price_annually=20000,  # $200.00 (2 months free)
                max_storage_gb=25,
                max_alerts_monthly=100,
                max_api_calls_monthly=-1,  # Unlimited
                max_file_size_gb=1,
                max_monitor_targets=5,
                backup_interval_minutes=60,  # Hourly
                backup_retention_days=30,
                encryption_enabled=True,
                compression_enabled=True,
                support_level="email",
                features=[
                    "encrypted_backups",
                    "scheduled_backups",
                    "active_monitoring",
                    "security_scanning",
                    "performance_optimization",
                    "email_support",
                    "deduplication",
                    "auto_backup"
                ]
            ),
            TierLevel.MASTER: TierLimits(
                name="master",
                display_name="Master",
                price_monthly=4900,  # $49.00
                price_annually=49000,  # $490.00 (3 months free)
                max_storage_gb=100,
                max_alerts_monthly=500,
                max_api_calls_monthly=10000,
                max_file_size_gb=10,
                max_monitor_targets=25,
                backup_interval_minutes=15,  # 15-minute intervals
                backup_retention_days=90,
                encryption_enabled=True,
                compression_enabled=True,
                support_level="priority",
                features=[
                    "ai_analysis",
                    "ai_optimization",
                    "predictive_analytics",
                    "advanced_security",
                    "compliance_auditing",
                    "enterprise_monitoring",
                    "performance_testing",
                    "quality_assurance",
                    "web_dashboard",
                    "load_balancing",
                    "distributed_systems",
                    "priority_support"
                ]
            ),
            TierLevel.REAPER: TierLimits(
                name="reaper",
                display_name="Reaper",
                price_monthly=9900,  # $99.00
                price_annually=99000,  # $990.00 (4 months free)
                max_storage_gb=1024,  # 1TB
                max_alerts_monthly=5000,
                max_api_calls_monthly=100000,
                max_file_size_gb=100,
                max_monitor_targets=100,
                backup_interval_minutes=1,  # Real-time
                backup_retention_days=365,
                encryption_enabled=True,
                compression_enabled=True,
                support_level="dedicated",
                features=[
                    "ai_production_deployment",
                    "cloud_integration",
                    "white_label_customization",
                    "custom_development",
                    "enterprise_sso",
                    "multi_tenant_management",
                    "unlimited_customization",
                    "dedicated_support",
                    "account_manager",
                    "custom_integrations",
                    "priority_development"
                ]
            )
        }
    
    def _init_command_definitions(self) -> Dict[str, CommandDefinition]:
        """Initialize comprehensive command definitions"""
        commands = {}
        
        # FREE TIER COMMANDS (15 total)
        free_commands = [
            # Basic Operations (5)
            CommandDefinition("help", "Help", "Show available commands and usage", 
                            CommandCategory.CORE, TierLevel.FREE),
            CommandDefinition("status", "Status", "Show system status", 
                            CommandCategory.CORE, TierLevel.FREE),
            CommandDefinition("health", "Health Check", "Basic health check", 
                            CommandCategory.MONITORING, TierLevel.FREE),
            CommandDefinition("init", "Initialize", "Initialize grim system", 
                            CommandCategory.CORE, TierLevel.FREE),
            CommandDefinition("version", "Version", "Show version information", 
                            CommandCategory.CORE, TierLevel.FREE),
            
            # Essential Backup (3)
            CommandDefinition("backup", "Basic Backup", "Create basic backup (no encryption/compression)", 
                            CommandCategory.BACKUP, TierLevel.FREE),
            CommandDefinition("restore", "Basic Restore", "Restore from backup (basic verification)", 
                            CommandCategory.BACKUP, TierLevel.FREE),
            CommandDefinition("scan", "Basic Scan", "Scan files and directories (limited depth)", 
                            CommandCategory.SECURITY, TierLevel.FREE),
            
            # Monitoring & Reports (4)
            CommandDefinition("monitor-status", "Monitor Status", "View monitoring status (read-only)", 
                            CommandCategory.MONITORING, TierLevel.FREE),
            CommandDefinition("list", "List", "List backups and basic info", 
                            CommandCategory.BACKUP, TierLevel.FREE),
            CommandDefinition("report-daily", "Daily Report", "Generate basic daily report", 
                            CommandCategory.REPORTING, TierLevel.FREE),
            CommandDefinition("cleanup-temp", "Cleanup Temp", "Clean temporary files only", 
                            CommandCategory.MAINTENANCE, TierLevel.FREE),
            
            # Configuration (3)
            CommandDefinition("config-get", "Get Config", "View configuration settings", 
                            CommandCategory.CORE, TierLevel.FREE),
            CommandDefinition("compress", "Basic Compress", "Basic compression (gzip only)", 
                            CommandCategory.PERFORMANCE, TierLevel.FREE),
            CommandDefinition("verify", "Basic Verify", "Basic file verification (checksums only)", 
                            CommandCategory.SECURITY, TierLevel.FREE),
        ]
        
        # PRO TIER COMMANDS (20 additional = 35 total)
        pro_commands = [
            # Enhanced Backup Operations (8)
            CommandDefinition("backup-create", "Advanced Backup", "Advanced backup with options", 
                            CommandCategory.BACKUP, TierLevel.PRO),
            CommandDefinition("backup-verify", "Verify Backup", "Verify backup integrity", 
                            CommandCategory.BACKUP, TierLevel.PRO),
            CommandDefinition("backup-list", "List Backups", "List all backups with details", 
                            CommandCategory.BACKUP, TierLevel.PRO),
            CommandDefinition("backup-schedule", "Schedule Backup", "Schedule automated backups", 
                            CommandCategory.BACKUP, TierLevel.PRO),
            CommandDefinition("auto-backup", "Auto Backup", "Intelligent auto-backup system", 
                            CommandCategory.BACKUP, TierLevel.FREE),
            CommandDefinition("encrypt", "Encrypt", "File encryption/decryption", 
                            CommandCategory.SECURITY, TierLevel.PRO),
            CommandDefinition("dedup", "Deduplication", "Deduplication for storage efficiency", 
                            CommandCategory.PERFORMANCE, TierLevel.PRO),
            CommandDefinition("restore-verify", "Verified Restore", "Restore with full verification", 
                            CommandCategory.BACKUP, TierLevel.PRO),
            
            # Active Monitoring (5)
            CommandDefinition("monitor-start", "Start Monitor", "Start active monitoring", 
                            CommandCategory.MONITORING, TierLevel.PRO),
            CommandDefinition("monitor-stop", "Stop Monitor", "Stop monitoring processes", 
                            CommandCategory.MONITORING, TierLevel.PRO),
            CommandDefinition("monitor-events", "Monitor Events", "View monitoring events", 
                            CommandCategory.MONITORING, TierLevel.PRO),
            CommandDefinition("lookouts-start", "Start Lookouts", "Start system lookouts", 
                            CommandCategory.MONITORING, TierLevel.PRO),
            CommandDefinition("notify", "Notifications", "Send notifications/alerts", 
                            CommandCategory.MONITORING, TierLevel.PRO),
            
            # Security Basics (4)
            CommandDefinition("security-scan", "Security Scan", "Basic security scanning", 
                            CommandCategory.SECURITY, TierLevel.PRO),
            CommandDefinition("security-encrypt", "Security Encrypt", "Security-focused encryption", 
                            CommandCategory.SECURITY, TierLevel.PRO),
            CommandDefinition("quarantine-isolate", "Quarantine", "Isolate suspicious files", 
                            CommandCategory.SECURITY, TierLevel.PRO),
            CommandDefinition("credentials", "Credentials", "Basic credential management", 
                            CommandCategory.SECURITY, TierLevel.PRO),
            
            # Performance & Maintenance (3)
            CommandDefinition("compress-benchmark", "Compression Benchmark", "Compression performance testing", 
                            CommandCategory.PERFORMANCE, TierLevel.PRO),
            CommandDefinition("optimize-storage", "Storage Optimization", "Basic storage optimization", 
                            CommandCategory.PERFORMANCE, TierLevel.PRO),
            CommandDefinition("cleanup-logs", "Log Cleanup", "Log file cleanup and rotation", 
                            CommandCategory.MAINTENANCE, TierLevel.PRO),
        ]
        
        # MASTER TIER COMMANDS (25 additional = 60 total)
        master_commands = [
            # AI & Intelligence Suite (7)
            CommandDefinition("ai-analyze", "AI Analyze", "AI-powered file analysis", 
                            CommandCategory.AI, TierLevel.MASTER, is_billable=True),
            CommandDefinition("ai-optimize", "AI Optimize", "AI optimization recommendations", 
                            CommandCategory.AI, TierLevel.MASTER, is_billable=True),
            CommandDefinition("ai-predict", "AI Predict", "Predictive analytics for issues", 
                            CommandCategory.AI, TierLevel.MASTER, is_billable=True),
            CommandDefinition("ai-recommend", "AI Recommend", "Smart suggestions engine", 
                            CommandCategory.AI, TierLevel.MASTER, is_billable=True),
            CommandDefinition("smart-suggestions", "Smart Suggestions", "Intelligent automation suggestions", 
                            CommandCategory.AI, TierLevel.MASTER, is_billable=True),
            CommandDefinition("predictive-analytics", "Predictive Analytics", "Advanced pattern recognition", 
                            CommandCategory.AI, TierLevel.MASTER, is_billable=True),
            CommandDefinition("nlp-interface", "NLP Interface", "Natural language processing", 
                            CommandCategory.AI, TierLevel.MASTER, is_billable=True),
            
            # Advanced Security & Compliance (6)
            CommandDefinition("security-audit", "Security Audit", "Comprehensive security audit", 
                            CommandCategory.SECURITY, TierLevel.MASTER),
            CommandDefinition("audit-start", "Start Audit", "Start compliance auditing", 
                            CommandCategory.SECURITY, TierLevel.MASTER),
            CommandDefinition("audit-report", "Audit Report", "Generate audit reports", 
                            CommandCategory.REPORTING, TierLevel.MASTER),
            CommandDefinition("quarantine-analyze", "Quarantine Analysis", "Analyze quarantined files", 
                            CommandCategory.SECURITY, TierLevel.MASTER),
            CommandDefinition("security-testing", "Security Testing", "Security vulnerability testing", 
                            CommandCategory.TESTING, TierLevel.MASTER),
            CommandDefinition("compliance-check", "Compliance Check", "Regulatory compliance verification", 
                            CommandCategory.SECURITY, TierLevel.MASTER),
            
            # Enterprise Operations (6)
            CommandDefinition("distributed-arch", "Distributed Architecture", "Distributed architecture management", 
                            CommandCategory.ENTERPRISE, TierLevel.MASTER),
            CommandDefinition("service-discovery", "Service Discovery", "Service discovery and registration", 
                            CommandCategory.ENTERPRISE, TierLevel.MASTER),
            CommandDefinition("load-balancing", "Load Balancing", "Load balancer configuration", 
                            CommandCategory.ENTERPRISE, TierLevel.MASTER),
            CommandDefinition("remote", "Remote Operations", "Remote operations management", 
                            CommandCategory.ENTERPRISE, TierLevel.MASTER),
            CommandDefinition("web", "Web Services", "Web-based dashboard", 
                            CommandCategory.ENTERPRISE, TierLevel.MASTER),
            CommandDefinition("dashboard", "Dashboard", "Advanced monitoring dashboard", 
                            CommandCategory.MONITORING, TierLevel.MASTER),
            
            # Quality & Performance (6)
            CommandDefinition("performance-testing", "Performance Testing", "Comprehensive performance tests", 
                            CommandCategory.TESTING, TierLevel.MASTER),
            CommandDefinition("quality-assurance", "Quality Assurance", "QA framework and testing", 
                            CommandCategory.TESTING, TierLevel.MASTER),
            CommandDefinition("user-acceptance", "User Acceptance", "User acceptance testing", 
                            CommandCategory.TESTING, TierLevel.MASTER),
            CommandDefinition("optimize-all", "System Optimization", "System-wide optimization", 
                            CommandCategory.PERFORMANCE, TierLevel.MASTER),
            CommandDefinition("heal-diagnose", "System Healing", "System healing and diagnosis", 
                            CommandCategory.MAINTENANCE, TierLevel.MASTER),
            CommandDefinition("testing-framework", "Testing Framework", "Advanced testing capabilities", 
                            CommandCategory.TESTING, TierLevel.MASTER),
        ]
        
        # REAPER TIER COMMANDS (140+ additional = 200+ total)
        reaper_commands = [
            # Full AI Production Suite (15)
            CommandDefinition("ai-train", "AI Training", "Train custom AI models", 
                            CommandCategory.AI, TierLevel.REAPER, is_billable=True, usage_weight=5.0),
            CommandDefinition("ai-setup", "AI Setup", "Production AI deployment setup", 
                            CommandCategory.AI, TierLevel.REAPER, is_billable=True),
            CommandDefinition("ai-production-deploy", "AI Production Deploy", "Deploy AI to production", 
                            CommandCategory.AI, TierLevel.REAPER, is_billable=True, usage_weight=10.0),
            CommandDefinition("ai-velocity-enhance", "AI Velocity Enhancement", "Maximum performance AI", 
                            CommandCategory.AI, TierLevel.REAPER, is_billable=True),
            CommandDefinition("ai-decision-engine", "AI Decision Engine", "AI-powered decision making", 
                            CommandCategory.AI, TierLevel.REAPER, is_billable=True),
            CommandDefinition("ai-integration", "AI Integration", "Full AI integration framework", 
                            CommandCategory.AI, TierLevel.REAPER, is_billable=True),
            CommandDefinition("ai-turbo", "AI Turbo", "Maximum AI performance mode", 
                            CommandCategory.AI, TierLevel.REAPER, is_billable=True),
            CommandDefinition("monitoring-enhance", "Enhanced Monitoring", "AI-enhanced monitoring", 
                            CommandCategory.MONITORING, TierLevel.REAPER, is_billable=True),
            CommandDefinition("analyze-decisions", "Decision Analysis", "Advanced decision analysis", 
                            CommandCategory.AI, TierLevel.REAPER, is_billable=True),
            CommandDefinition("neural-networks", "Neural Networks", "Neural network processing", 
                            CommandCategory.AI, TierLevel.REAPER, is_billable=True),
            CommandDefinition("machine-learning", "Machine Learning", "ML model operations", 
                            CommandCategory.AI, TierLevel.REAPER, is_billable=True),
            CommandDefinition("deep-learning", "Deep Learning", "Deep learning capabilities", 
                            CommandCategory.AI, TierLevel.REAPER, is_billable=True),
            CommandDefinition("ai-ensemble", "AI Ensemble", "Ensemble AI models", 
                            CommandCategory.AI, TierLevel.REAPER, is_billable=True),
            CommandDefinition("ai-timeseries", "AI Time Series", "Time series AI analysis", 
                            CommandCategory.AI, TierLevel.REAPER, is_billable=True),
            CommandDefinition("ai-classification", "AI Classification", "AI classification systems", 
                            CommandCategory.AI, TierLevel.REAPER, is_billable=True),
            
            # Cloud & Enterprise Integration (25)
            CommandDefinition("cloud-native-platform", "Cloud Platform", "Full cloud integration", 
                            CommandCategory.CLOUD, TierLevel.REAPER),
            CommandDefinition("aws-integration", "AWS Integration", "Amazon Web Services integration", 
                            CommandCategory.CLOUD, TierLevel.REAPER),
            CommandDefinition("azure-integration", "Azure Integration", "Microsoft Azure integration", 
                            CommandCategory.CLOUD, TierLevel.REAPER),
            CommandDefinition("gcp-integration", "GCP Integration", "Google Cloud Platform integration", 
                            CommandCategory.CLOUD, TierLevel.REAPER),
            CommandDefinition("serverless-functions", "Serverless Functions", "Serverless deployment", 
                            CommandCategory.CLOUD, TierLevel.REAPER),
            CommandDefinition("kubernetes-deploy", "Kubernetes Deploy", "Kubernetes orchestration", 
                            CommandCategory.CLOUD, TierLevel.REAPER),
            CommandDefinition("docker-management", "Docker Management", "Container management", 
                            CommandCategory.CLOUD, TierLevel.REAPER),
            CommandDefinition("microservices-arch", "Microservices Architecture", "Microservices architecture", 
                            CommandCategory.ENTERPRISE, TierLevel.REAPER),
            CommandDefinition("container-orchestration", "Container Orchestration", "Advanced container orchestration", 
                            CommandCategory.CLOUD, TierLevel.REAPER),
            CommandDefinition("cloud-scaling", "Cloud Scaling", "Dynamic cloud scaling", 
                            CommandCategory.CLOUD, TierLevel.REAPER),
            CommandDefinition("multi-cloud", "Multi-Cloud", "Multi-cloud deployment", 
                            CommandCategory.CLOUD, TierLevel.REAPER),
            CommandDefinition("hybrid-cloud", "Hybrid Cloud", "Hybrid cloud architecture", 
                            CommandCategory.CLOUD, TierLevel.REAPER),
            CommandDefinition("cloud-security", "Cloud Security", "Cloud security management", 
                            CommandCategory.SECURITY, TierLevel.REAPER),
            CommandDefinition("cloud-monitoring", "Cloud Monitoring", "Cloud infrastructure monitoring", 
                            CommandCategory.MONITORING, TierLevel.REAPER),
            CommandDefinition("cloud-backup", "Cloud Backup", "Cloud-native backup systems", 
                            CommandCategory.BACKUP, TierLevel.REAPER),
            CommandDefinition("disaster-recovery", "Disaster Recovery", "Enterprise disaster recovery", 
                            CommandCategory.BACKUP, TierLevel.REAPER),
            CommandDefinition("high-availability", "High Availability", "HA architecture deployment", 
                            CommandCategory.ENTERPRISE, TierLevel.REAPER),
            CommandDefinition("fault-tolerance", "Fault Tolerance", "Fault-tolerant systems", 
                            CommandCategory.ENTERPRISE, TierLevel.REAPER),
            CommandDefinition("geo-replication", "Geo Replication", "Geographic data replication", 
                            CommandCategory.ENTERPRISE, TierLevel.REAPER),
            CommandDefinition("cdn-integration", "CDN Integration", "Content delivery network integration", 
                            CommandCategory.CLOUD, TierLevel.REAPER),
            CommandDefinition("edge-computing", "Edge Computing", "Edge computing deployment", 
                            CommandCategory.CLOUD, TierLevel.REAPER),
            CommandDefinition("iot-integration", "IoT Integration", "Internet of Things integration", 
                            CommandCategory.ENTERPRISE, TierLevel.REAPER),
            CommandDefinition("blockchain-integration", "Blockchain Integration", "Blockchain technology integration", 
                            CommandCategory.ENTERPRISE, TierLevel.REAPER),
            CommandDefinition("api-management", "API Management", "Enterprise API management", 
                            CommandCategory.ENTERPRISE, TierLevel.REAPER),
            CommandDefinition("service-mesh", "Service Mesh", "Service mesh architecture", 
                            CommandCategory.ENTERPRISE, TierLevel.REAPER),
            
            # Enterprise Administration and Customization (50+ commands)
            CommandDefinition("white-label-config", "White Label Config", "White-label customization", 
                            CommandCategory.ENTERPRISE, TierLevel.REAPER),
            CommandDefinition("custom-branding", "Custom Branding", "Custom UI/branding options", 
                            CommandCategory.ENTERPRISE, TierLevel.REAPER),
            CommandDefinition("multi-tenant-mgmt", "Multi-Tenant Management", "Multi-tenant administration", 
                            CommandCategory.ENTERPRISE, TierLevel.REAPER),
            CommandDefinition("enterprise-sso", "Enterprise SSO", "Single sign-on integration", 
                            CommandCategory.ENTERPRISE, TierLevel.REAPER),
            CommandDefinition("custom-development", "Custom Development", "On-demand custom features", 
                            CommandCategory.DEVELOPMENT, TierLevel.REAPER, is_billable=True, usage_weight=20.0),
            CommandDefinition("custom-integrations", "Custom Integrations", "Bespoke integration development", 
                            CommandCategory.DEVELOPMENT, TierLevel.REAPER, is_billable=True),
            CommandDefinition("workflow-automation", "Workflow Automation", "Advanced workflow automation", 
                            CommandCategory.ENTERPRISE, TierLevel.REAPER),
            CommandDefinition("business-intelligence", "Business Intelligence", "Advanced BI capabilities", 
                            CommandCategory.REPORTING, TierLevel.REAPER),
            CommandDefinition("data-warehousing", "Data Warehousing", "Enterprise data warehousing", 
                            CommandCategory.ENTERPRISE, TierLevel.REAPER),
            CommandDefinition("etl-processing", "ETL Processing", "Extract, Transform, Load processing", 
                            CommandCategory.ENTERPRISE, TierLevel.REAPER),
        ]
        
        # Combine all commands
        all_commands = free_commands + pro_commands + master_commands + reaper_commands
        
        # Convert to dictionary
        for cmd in all_commands:
            commands[cmd.name] = cmd
            # Add aliases if they exist
            if cmd.aliases:
                for alias in cmd.aliases:
                    commands[alias] = cmd
        
        return commands
    
    def get_user_tier(self, user_tier_name: str) -> Optional[TierLevel]:
        """Get tier level from string name"""
        try:
            return TierLevel(user_tier_name.lower())
        except ValueError:
            return None
    
    def can_access_command(self, user_tier: TierLevel, command_name: str) -> bool:
        """Check if user tier can access specific command"""
        if command_name not in self.command_definitions:
            return False
        
        command = self.command_definitions[command_name]
        required_tier = command.minimum_tier
        
        # Check if user tier is at or above required tier
        user_level = self.tier_hierarchy.index(user_tier)
        required_level = self.tier_hierarchy.index(required_tier)
        
        return user_level >= required_level
    
    def get_available_commands(self, user_tier: TierLevel) -> List[CommandDefinition]:
        """Get all commands available to a specific tier"""
        available = []
        for command in self.command_definitions.values():
            if self.can_access_command(user_tier, command.name):
                available.append(command)
        return available
    
    def get_tier_upgrade_suggestions(self, user_tier: TierLevel, attempted_command: str) -> Dict:
        """Get upgrade suggestions when user attempts to use unavailable command"""
        if attempted_command not in self.command_definitions:
            return {"error": "Command not found"}
        
        command = self.command_definitions[attempted_command]
        required_tier = command.minimum_tier
        
        if self.can_access_command(user_tier, attempted_command):
            return {"error": "Command already accessible"}
        
        # Find the minimum tier needed
        current_index = self.tier_hierarchy.index(user_tier)
        required_index = self.tier_hierarchy.index(required_tier)
        
        upgrade_options = []
        for i in range(current_index + 1, len(self.tier_hierarchy)):
            tier = self.tier_hierarchy[i]
            tier_info = self.tier_definitions[tier]
            upgrade_options.append({
                "tier": tier.value,
                "display_name": tier_info.display_name,
                "price_monthly": tier_info.price_monthly,
                "price_annually": tier_info.price_annually,
                "unlocks_command": i >= required_index
            })
        
        return {
            "command": attempted_command,
            "command_description": command.description,
            "required_tier": required_tier.value,
            "current_tier": user_tier.value,
            "upgrade_options": upgrade_options
        }
    
    def get_usage_limits(self, user_tier: TierLevel) -> Dict:
        """Get usage limits for a specific tier"""
        tier_info = self.tier_definitions[user_tier]
        return {
            "storage_gb": tier_info.max_storage_gb,
            "alerts_monthly": tier_info.max_alerts_monthly,
            "api_calls_monthly": tier_info.max_api_calls_monthly,
            "file_size_gb": tier_info.max_file_size_gb,
            "monitor_targets": tier_info.max_monitor_targets,
            "backup_interval_minutes": tier_info.backup_interval_minutes,
            "backup_retention_days": tier_info.backup_retention_days,
            "features": tier_info.features
        }
    
    def calculate_overage_costs(self, user_tier: TierLevel, usage: Dict) -> Dict:
        """Calculate overage costs based on usage"""
        limits = self.get_usage_limits(user_tier)
        overages = {}
        total_overage = 0
        
        # Storage overage ($0.05/GB/month)
        if usage.get("storage_gb", 0) > limits["storage_gb"]:
            storage_overage = usage["storage_gb"] - limits["storage_gb"]
            storage_cost = storage_overage * 5  # $0.05 = 5 cents
            overages["storage"] = {
                "amount_gb": storage_overage,
                "cost_cents": storage_cost,
                "rate_per_gb": 5
            }
            total_overage += storage_cost
        
        # Alert overage ($0.10 per alert)
        if usage.get("alerts_monthly", 0) > limits["alerts_monthly"]:
            alert_overage = usage["alerts_monthly"] - limits["alerts_monthly"]
            alert_cost = alert_overage * 10  # $0.10 = 10 cents
            overages["alerts"] = {
                "amount_alerts": alert_overage,
                "cost_cents": alert_cost,
                "rate_per_alert": 10
            }
            total_overage += alert_cost
        
        # API call overage ($0.001 per call) - only for tiers with limits
        if limits["api_calls_monthly"] > 0 and usage.get("api_calls_monthly", 0) > limits["api_calls_monthly"]:
            api_overage = usage["api_calls_monthly"] - limits["api_calls_monthly"]
            api_cost = api_overage * 0.1  # $0.001 = 0.1 cents
            overages["api_calls"] = {
                "amount_calls": api_overage,
                "cost_cents": api_cost,
                "rate_per_call": 0.1
            }
            total_overage += api_cost
        
        return {
            "total_overage_cents": int(total_overage),
            "overages": overages,
            "has_overages": len(overages) > 0
        }
    
    def export_tier_config(self) -> str:
        """Export tier configuration as JSON for external systems"""
        config = {
            "tiers": {},
            "commands": {},
            "hierarchy": [tier.value for tier in self.tier_hierarchy]
        }
        
        # Export tier definitions
        for tier, limits in self.tier_definitions.items():
            config["tiers"][tier.value] = {
                "display_name": limits.display_name,
                "price_monthly": limits.price_monthly,
                "price_annually": limits.price_annually,
                "limits": {
                    "storage_gb": limits.max_storage_gb,
                    "alerts_monthly": limits.max_alerts_monthly,
                    "api_calls_monthly": limits.max_api_calls_monthly,
                    "file_size_gb": limits.max_file_size_gb,
                    "monitor_targets": limits.max_monitor_targets
                },
                "features": limits.features
            }
        
        # Export command definitions
        for name, cmd in self.command_definitions.items():
            if name == cmd.name:  # Skip aliases
                config["commands"][name] = {
                    "display_name": cmd.display_name,
                    "description": cmd.description,
                    "category": cmd.category.value,
                    "minimum_tier": cmd.minimum_tier.value,
                    "is_billable": cmd.is_billable,
                    "usage_weight": cmd.usage_weight
                }
        
        return json.dumps(config, indent=2)

# Global instance for easy access
tier_manager = TierManager()

# Helper functions for external access
def get_tier_manager() -> TierManager:
    """Get the global tier manager instance"""
    return tier_manager

def check_command_access(user_tier: str, command: str) -> bool:
    """Quick access check for command"""
    tier = tier_manager.get_user_tier(user_tier)
    if not tier:
        return False
    return tier_manager.can_access_command(tier, command)

def get_upgrade_message(user_tier: str, command: str) -> str:
    """Get formatted upgrade message for blocked command"""
    tier = tier_manager.get_user_tier(user_tier)
    if not tier:
        return "Invalid tier specified"
    
    suggestions = tier_manager.get_tier_upgrade_suggestions(tier, command)
    if "error" in suggestions:
        return suggestions["error"]
    
    required_tier = suggestions["required_tier"].title()
    return f"Command '{command}' requires {required_tier} tier or higher. Use 'grim upgrade' to see upgrade options."

if __name__ == "__main__":
    # Export configuration for testing
    print(tier_manager.export_tier_config())