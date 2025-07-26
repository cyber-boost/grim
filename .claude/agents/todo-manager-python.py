#!/usr/bin/env python3
"""
Server Todo Manager - Python Implementation
A comprehensive task and conversation manager for server-wide project tracking.
"""

import json
import os
import sys
import uuid
from datetime import datetime, timedelta
from pathlib import Path
from typing import List, Dict, Optional, Any
import argparse
import textwrap

class Colors:
    """Terminal color codes"""
    RED = '\033[0;31m'
    GREEN = '\033[0;32m'
    YELLOW = '\033[1;33m'
    BLUE = '\033[0;34m'
    PURPLE = '\033[0;35m'
    NC = '\033[0m'  # No Color

class TodoManager:
    def __init__(self, root_path: Optional[str] = None):
        """Initialize the Todo Manager with configurable root path."""
        if root_path:
            self.root = Path(root_path)
        else:
            # Try system location first, fall back to user directory
            system_root = Path("/opt/reaper/todo")
            user_root = Path.home() / ".server-todo"
            
            if system_root.parent.exists() and os.access(system_root.parent, os.W_OK):
                self.root = system_root
            else:
                self.root = user_root
        
        self._setup_directories()
        self._init_files()
    
    def _setup_directories(self):
        """Create necessary directory structure."""
        dirs = [
            self.root / "conversations",
            self.root / "tasks",
            self.root / "projects",
            self.root / "projects" / "project-status",
            self.root / "reports" / "daily",
            self.root / "reports" / "weekly",
            self.root / "reports" / "monthly",
        ]
        for dir_path in dirs:
            dir_path.mkdir(parents=True, exist_ok=True)
    
    def _init_files(self):
        """Initialize JSON files if they don't exist."""
        json_files = {
            self.root / "tasks" / "active-tasks.json": {"tasks": []},
            self.root / "tasks" / "completed-tasks.json": {"tasks": []},
            self.root / "tasks" / "backlog.json": {"tasks": []},
            self.root / "projects" / "project-registry.json": {"projects": []},
            self.root / "conversations" / "conversation-index.json": {"conversations": []},
        }
        
        for file_path, default_content in json_files.items():
            if not file_path.exists():
                self._save_json(file_path, default_content)
    
    def _load_json(self, file_path: Path) -> Dict[str, Any]:
        """Load JSON file safely."""
        try:
            with open(file_path, 'r') as f:
                return json.load(f)
        except (FileNotFoundError, json.JSONDecodeError):
            return {}
    
    def _save_json(self, file_path: Path, data: Dict[str, Any]):
        """Save JSON file with pretty printing."""
        with open(file_path, 'w') as f:
            json.dump(data, f, indent=2, default=str)
    
    def log_conversation(self, summary: str, tasks: List[str] = None, notes: List[str] = None):
        """Log a conversation summary."""
        date = datetime.now().strftime("%Y-%m-%d")
        time = datetime.now().strftime("%H:%M:%S")
        summary_file = self.root / "conversations" / f"{date}-summary.md"
        
        # Create or append to summary file
        if not summary_file.exists():
            content = f"""# Conversation Summary - {date}

## Participants
- User: {os.environ.get('USER', 'unknown')}
- Assistant: Claude

## Conversation Sessions
"""
        else:
            with open(summary_file, 'r') as f:
                content = f.read()
        
        # Add new session
        session_content = f"""
### Session at {time}

**Summary**: {summary}

**Tasks Discussed**:
"""
        
        if tasks:
            for task in tasks:
                session_content += f"- [ ] {task}\n"
        else:
            session_content += "- [ ] (Add tasks discussed)\n"
        
        session_content += "\n**Key Points**:\n"
        
        if notes:
            for note in notes:
                session_content += f"- {note}\n"
        else:
            session_content += "- (Add key decisions or points)\n"
        
        session_content += "\n---\n"
        
        with open(summary_file, 'w') as f:
            f.write(content + session_content)
        
        # Update conversation index
        index_file = self.root / "conversations" / "conversation-index.json"
        index = self._load_json(index_file)
        
        if "conversations" not in index:
            index["conversations"] = []
        
        index["conversations"].append({
            "date": date,
            "time": time,
            "summary": summary,
            "file": str(summary_file.name)
        })
        
        self._save_json(index_file, index)
        
        print(f"{Colors.GREEN}[INFO]{Colors.NC} Conversation logged to: {summary_file}")
    
    def add_task(self, title: str, project: str = "general", priority: str = "medium", 
                 description: str = "", tags: List[str] = None, dependencies: List[str] = None):
        """Add a new task."""
        task_id = str(uuid.uuid4())
        timestamp = datetime.utcnow().isoformat() + "Z"
        date = datetime.now().strftime("%Y-%m-%d")
        
        task = {
            "id": task_id,
            "created_date": timestamp,
            "modified_date": timestamp,
            "title": title,
            "description": description,
            "project": project,
            "status": "created",
            "priority": priority,
            "tags": tags or [],
            "dependencies": dependencies or [],
            "conversation_refs": [f"{date}-summary.md"],
            "completed_date": None,
            "notes": []
        }
        
        # Add to active tasks
        active_tasks = self._load_json(self.root / "tasks" / "active-tasks.json")
        active_tasks["tasks"].append(task)
        self._save_json(self.root / "tasks" / "active-tasks.json", active_tasks)
        
        # Update project registry
        self._ensure_project_exists(project)
        
        print(f"{Colors.BLUE}[TASK]{Colors.NC} Created task: {task_id}")
        print(f"       Title: {title}")
        print(f"       Project: {project} | Priority: {priority}")
        
        return task_id
    
    def _ensure_project_exists(self, project_name: str):
        """Ensure a project exists in the registry."""
        registry_file = self.root / "projects" / "project-registry.json"
        registry = self._load_json(registry_file)
        
        # Check if project exists
        project_exists = any(p["id"] == project_name for p in registry.get("projects", []))
        
        if not project_exists:
            new_project = {
                "id": project_name,
                "name": project_name.replace("-", " ").title(),
                "description": f"Auto-created project: {project_name}",
                "status": "active",
                "created_date": datetime.now().strftime("%Y-%m-%d"),
                "primary_languages": [],
                "key_paths": {},
                "active_task_count": 0,
                "completed_task_count": 0
            }
            registry["projects"].append(new_project)
            self._save_json(registry_file, registry)
    
    def list_tasks(self, status: str = "all", project: str = "all", show_details: bool = False):
        """List tasks with optional filtering."""
        print(f"\n{Colors.BLUE}=== Task List ==={Colors.NC}")
        print(f"Status: {status} | Project: {project}\n")
        
        # Define which files to check based on status
        files_to_check = []
        if status in ["all", "active", "created", "in-progress"]:
            files_to_check.append(("Active", self.root / "tasks" / "active-tasks.json", Colors.GREEN))
        if status in ["all", "completed", "done"]:
            files_to_check.append(("Completed", self.root / "tasks" / "completed-tasks.json", Colors.BLUE))
        if status in ["all", "backlog"]:
            files_to_check.append(("Backlog", self.root / "tasks" / "backlog.json", Colors.YELLOW))
        
        total_tasks = 0
        
        for label, file_path, color in files_to_check:
            if file_path.exists():
                data = self._load_json(file_path)
                tasks = data.get("tasks", [])
                
                # Filter by project if specified
                if project != "all":
                    tasks = [t for t in tasks if t.get("project") == project]
                
                if tasks:
                    print(f"{color}{label} Tasks:{Colors.NC}")
                    
                    # Sort by priority
                    priority_order = {"urgent": 0, "high": 1, "medium": 2, "low": 3}
                    tasks.sort(key=lambda x: priority_order.get(x.get("priority", "medium"), 2))
                    
                    for task in tasks:
                        priority = task.get("priority", "medium")
                        priority_color = {
                            "urgent": Colors.RED,
                            "high": Colors.YELLOW,
                            "medium": Colors.NC,
                            "low": Colors.BLUE
                        }.get(priority, Colors.NC)
                        
                        print(f"  {priority_color}[{priority}]{Colors.NC} {task['id'][:8]}... - {task['title']}")
                        
                        if show_details:
                            if task.get("description"):
                                print(f"       Description: {task['description']}")
                            print(f"       Project: {task.get('project', 'none')}")
                            if task.get("tags"):
                                print(f"       Tags: {', '.join(task['tags'])}")
                            print(f"       Created: {task['created_date'][:10]}")
                            print()
                    
                    total_tasks += len(tasks)
                    print()
        
        print(f"Total tasks shown: {total_tasks}")
    
    def update_task_status(self, task_id: str, new_status: str):
        """Update the status of a task."""
        # Search for task in all files
        task_found = False
        task_data = None
        source_file = None
        
        for filename in ["active-tasks.json", "completed-tasks.json", "backlog.json"]:
            file_path = self.root / "tasks" / filename
            data = self._load_json(file_path)
            
            for i, task in enumerate(data.get("tasks", [])):
                if task["id"].startswith(task_id):
                    task_found = True
                    task_data = task
                    source_file = file_path
                    
                    # Remove from current file
                    data["tasks"].pop(i)
                    self._save_json(file_path, data)
                    break
            
            if task_found:
                break
        
        if not task_found:
            print(f"{Colors.RED}[ERROR]{Colors.NC} Task not found: {task_id}")
            return
        
        # Update task
        task_data["status"] = new_status
        task_data["modified_date"] = datetime.utcnow().isoformat() + "Z"
        
        # Determine target file based on new status
        if new_status in ["completed", "done"]:
            target_file = self.root / "tasks" / "completed-tasks.json"
            task_data["completed_date"] = task_data["modified_date"]
        elif new_status == "backlog":
            target_file = self.root / "tasks" / "backlog.json"
        else:
            target_file = self.root / "tasks" / "active-tasks.json"
        
        # Add to target file
        target_data = self._load_json(target_file)
        target_data["tasks"].append(task_data)
        self._save_json(target_file, target_data)
        
        print(f"{Colors.GREEN}[SUCCESS]{Colors.NC} Task {task_id[:8]}... updated to status: {new_status}")
    
    def show_context(self, days: int = 7, project: str = "all"):
        """Show recent context and activity."""
        print(f"\n{Colors.BLUE}=== Recent Context (Last {days} days) ==={Colors.NC}\n")
        
        # Recent conversations
        print(f"{Colors.GREEN}Recent Conversations:{Colors.NC}")
        cutoff_date = datetime.now() - timedelta(days=days)
        
        conv_index = self._load_json(self.root / "conversations" / "conversation-index.json")
        recent_convs = []
        
        for conv in conv_index.get("conversations", []):
            conv_date = datetime.strptime(conv["date"], "%Y-%m-%d")
            if conv_date >= cutoff_date:
                recent_convs.append(conv)
        
        recent_convs.sort(key=lambda x: x["date"], reverse=True)
        
        for conv in recent_convs[:10]:
            print(f"  {conv['date']} {conv['time']} - {conv['summary'][:60]}...")
        
        # Task statistics
        print(f"\n{Colors.GREEN}Task Statistics:{Colors.NC}")
        
        active_tasks = self._load_json(self.root / "tasks" / "active-tasks.json")
        completed_tasks = self._load_json(self.root / "tasks" / "completed-tasks.json")
        backlog_tasks = self._load_json(self.root / "tasks" / "backlog.json")
        
        # Count by project
        project_counts = {}
        for task_list in [active_tasks, completed_tasks, backlog_tasks]:
            for task in task_list.get("tasks", []):
                proj = task.get("project", "none")
                if proj not in project_counts:
                    project_counts[proj] = {"active": 0, "completed": 0, "backlog": 0}
        
        for task in active_tasks.get("tasks", []):
            project_counts[task.get("project", "none")]["active"] += 1
        
        for task in completed_tasks.get("tasks", []):
            project_counts[task.get("project", "none")]["completed"] += 1
        
        for task in backlog_tasks.get("tasks", []):
            project_counts[task.get("project", "none")]["backlog"] += 1
        
        # Display project statistics
        if project == "all":
            for proj, counts in project_counts.items():
                total = sum(counts.values())
                if total > 0:
                    print(f"  {proj}: {counts['active']} active, {counts['completed']} completed, {counts['backlog']} backlog")
        else:
            counts = project_counts.get(project, {"active": 0, "completed": 0, "backlog": 0})
            print(f"  {project}: {counts['active']} active, {counts['completed']} completed, {counts['backlog']} backlog")
        
        # Recent completions
        print(f"\n{Colors.GREEN}Recently Completed:{Colors.NC}")
        recent_completed = []
        
        for task in completed_tasks.get("tasks", []):
            if task.get("completed_date"):
                try:
                    completed_date = datetime.fromisoformat(task["completed_date"].replace("Z", "+00:00"))
                    if completed_date.replace(tzinfo=None) >= cutoff_date:
                        recent_completed.append(task)
                except:
                    pass
        
        recent_completed.sort(key=lambda x: x.get("completed_date", ""), reverse=True)
        
        for task in recent_completed[:5]:
            print(f"  ✓ {task['title']} ({task.get('project', 'none')})")
    
    def generate_report(self, report_type: str = "daily"):
        """Generate a report."""
        date = datetime.now().strftime("%Y-%m-%d")
        time = datetime.now().strftime("%H:%M:%S")
        
        if report_type == "daily":
            report_file = self.root / "reports" / "daily" / f"{date}-report.md"
            
            content = f"""# Daily Report - {date}

## Summary
Generated at: {time}
Report Location: {self.root}

## Task Overview
"""
            
            # Get task counts
            active_tasks = self._load_json(self.root / "tasks" / "active-tasks.json")
            completed_tasks = self._load_json(self.root / "tasks" / "completed-tasks.json")
            backlog_tasks = self._load_json(self.root / "tasks" / "backlog.json")
            
            active_count = len(active_tasks.get("tasks", []))
            completed_count = len(completed_tasks.get("tasks", []))
            backlog_count = len(backlog_tasks.get("tasks", []))
            
            content += f"""
- Active Tasks: {active_count}
- Completed Tasks: {completed_count}
- Backlog Tasks: {backlog_count}

## Today's Activity
"""
            
            # Today's conversations
            conv_count = 0
            conv_file = self.root / "conversations" / f"{date}-summary.md"
            if conv_file.exists():
                with open(conv_file, 'r') as f:
                    conv_count = f.read().count("### Session at")
            
            content += f"\n- Conversation Sessions: {conv_count}\n"
            
            # Tasks completed today
            completed_today = []
            for task in completed_tasks.get("tasks", []):
                if task.get("completed_date", "").startswith(date):
                    completed_today.append(task)
            
            if completed_today:
                content += f"\n## Completed Today ({len(completed_today)} tasks)\n"
                for task in completed_today:
                    content += f"- ✓ {task['title']} (Project: {task.get('project', 'none')})\n"
            else:
                content += "\n## Completed Today\nNo tasks completed today.\n"
            
            # High priority tasks
            high_priority = []
            for task in active_tasks.get("tasks", []):
                if task.get("priority") in ["urgent", "high"]:
                    high_priority.append(task)
            
            if high_priority:
                content += f"\n## High Priority Tasks ({len(high_priority)})\n"
                for task in high_priority:
                    content += f"- [{task.get('priority')}] {task['title']} (Project: {task.get('project', 'none')})\n"
            
            content += f"\n---\nGenerated by Server Todo Manager\nRoot: {self.root}\n"
            
            # Save report
            with open(report_file, 'w') as f:
                f.write(content)
            
            print(f"{Colors.GREEN}[INFO]{Colors.NC} Report generated: {report_file}")
            print("\n" + content)

def main():
    """Main entry point."""
    parser = argparse.ArgumentParser(
        description="Server Todo Manager - Track tasks and conversations across projects",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=textwrap.dedent('''
            Examples:
              %(prog)s conv "Discussed Python package deployment"
              %(prog)s add "Deploy Python package to PyPI" --project grim-reaper --priority high
              %(prog)s list --status active --project grim-reaper
              %(prog)s update abc123 completed
              %(prog)s context --days 7
              %(prog)s report
        ''')
    )
    
    parser.add_argument('--root', help='Override todo root directory')
    
    subparsers = parser.add_subparsers(dest='command', help='Commands')
    
    # Conversation command
    conv_parser = subparsers.add_parser('conv', aliases=['conversation'], help='Log a conversation')
    conv_parser.add_argument('summary', help='Summary of the conversation')
    conv_parser.add_argument('--tasks', nargs='+', help='Tasks discussed')
    conv_parser.add_argument('--notes', nargs='+', help='Key notes or decisions')
    
    # Add task command
    add_parser = subparsers.add_parser('add', aliases=['task'], help='Add a new task')
    add_parser.add_argument('title', help='Task title')
    add_parser.add_argument('--project', default='general', help='Project name')
    add_parser.add_argument('--priority', choices=['urgent', 'high', 'medium', 'low'], 
                           default='medium', help='Task priority')
    add_parser.add_argument('--description', help='Task description')
    add_parser.add_argument('--tags', nargs='+', help='Task tags')
    add_parser.add_argument('--deps', nargs='+', help='Task dependencies (IDs)')
    
    # List tasks command
    list_parser = subparsers.add_parser('list', aliases=['ls'], help='List tasks')
    list_parser.add_argument('--status', default='all', 
                            choices=['all', 'active', 'completed', 'backlog'],
                            help='Filter by status')
    list_parser.add_argument('--project', default='all', help='Filter by project')
    list_parser.add_argument('--details', action='store_true', help='Show task details')
    
    # Update task command
    update_parser = subparsers.add_parser('update', help='Update task status')
    update_parser.add_argument('task_id', help='Task ID (partial match accepted)')
    update_parser.add_argument('status', choices=['active', 'in-progress', 'completed', 'backlog'],
                              help='New status')
    
    # Context command
    context_parser = subparsers.add_parser('context', aliases=['ctx'], help='Show recent context')
    context_parser.add_argument('--days', type=int, default=7, help='Number of days to look back')
    context_parser.add_argument('--project', default='all', help='Filter by project')
    
    # Report command
    report_parser = subparsers.add_parser('report', help='Generate report')
    report_parser.add_argument('--type', choices=['daily', 'weekly', 'monthly'], 
                              default='daily', help='Report type')
    
    args = parser.parse_args()
    
    # Initialize manager
    manager = TodoManager(args.root)
    
    # Execute command
    if args.command in ['conv', 'conversation']:
        manager.log_conversation(args.summary, args.tasks, args.notes)
    
    elif args.command in ['add', 'task']:
        manager.add_task(
            args.title,
            project=args.project,
            priority=args.priority,
            description=args.description or "",
            tags=args.tags,
            dependencies=args.deps
        )
    
    elif args.command in ['list', 'ls']:
        manager.list_tasks(
            status=args.status,
            project=args.project,
            show_details=args.details
        )
    
    elif args.command == 'update':
        manager.update_task_status(args.task_id, args.status)
    
    elif args.command in ['context', 'ctx']:
        manager.show_context(days=args.days, project=args.project)
    
    elif args.command == 'report':
        manager.generate_report(report_type=args.type)
    
    else:
        parser.print_help()

if __name__ == "__main__":
    main()