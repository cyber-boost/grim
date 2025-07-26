#!/usr/bin/env bash
# Server Todo Manager - Simple Implementation
# This provides a basic implementation of the todo manager functionality

set -euo pipefail

# Configuration
TODO_ROOT="${TODO_ROOT:-/opt/reaper/todo}"
TODO_USER_ROOT="${HOME}/.server-todo"

# Use user directory if system directory isn't writable
if [ ! -w "/opt/reaper" ] 2>/dev/null; then
    TODO_ROOT="$TODO_USER_ROOT"
fi

# Ensure directories exist
mkdir -p "$TODO_ROOT"/{conversations,tasks,projects,reports/{daily,weekly,monthly}}

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

log_task() {
    echo -e "${BLUE}[TASK]${NC} $1"
}

# Generate UUID for tasks
generate_uuid() {
    if command -v uuidgen >/dev/null 2>&1; then
        uuidgen | tr '[:upper:]' '[:lower:]'
    else
        # Fallback UUID generation
        echo "$(date +%s)-$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 8)"
    fi
}

# Get current timestamp
get_timestamp() {
    date -u +"%Y-%m-%dT%H:%M:%SZ"
}

# Get date for filenames
get_date() {
    date +"%Y-%m-%d"
}

# Initialize task files if they don't exist
init_task_files() {
    local files=("active-tasks.json" "completed-tasks.json" "backlog.json")
    for file in "${files[@]}"; do
        if [ ! -f "$TODO_ROOT/tasks/$file" ]; then
            echo '{"tasks": []}' > "$TODO_ROOT/tasks/$file"
        fi
    done
    
    if [ ! -f "$TODO_ROOT/projects/project-registry.json" ]; then
        echo '{"projects": []}' > "$TODO_ROOT/projects/project-registry.json"
    fi
}

# Log conversation summary
log_conversation() {
    local summary="${1:-No summary provided}"
    local date=$(get_date)
    local summary_file="$TODO_ROOT/conversations/${date}-summary.md"
    
    # Create or append to today's summary
    if [ ! -f "$summary_file" ]; then
        cat > "$summary_file" <<EOF
# Conversation Summary - ${date}

## Participants
- User: $(whoami)
- Assistant: Claude

## Conversation Sessions

EOF
    fi
    
    # Append new session
    cat >> "$summary_file" <<EOF

### Session at $(date +"%H:%M:%S")

**Summary**: $summary

**Tasks Discussed**:
- [ ] (Add tasks discussed)

**Key Points**:
- (Add key decisions or points)

---
EOF
    
    log_info "Conversation logged to: $summary_file"
}

# Add a new task
add_task() {
    local title="$1"
    local project="${2:-general}"
    local priority="${3:-medium}"
    local description="${4:-}"
    
    local task_id=$(generate_uuid)
    local timestamp=$(get_timestamp)
    local date=$(get_date)
    
    # Read existing tasks
    local active_tasks=$(cat "$TODO_ROOT/tasks/active-tasks.json")
    
    # Create new task JSON
    local new_task=$(cat <<EOF
{
    "id": "$task_id",
    "created_date": "$timestamp",
    "modified_date": "$timestamp",
    "title": "$title",
    "description": "$description",
    "project": "$project",
    "status": "created",
    "priority": "$priority",
    "tags": [],
    "dependencies": [],
    "conversation_refs": ["${date}-summary.md"],
    "completed_date": null,
    "notes": []
}
EOF
)
    
    # Add task to active tasks using jq if available, otherwise use python
    if command -v jq >/dev/null 2>&1; then
        echo "$active_tasks" | jq ".tasks += [$new_task]" > "$TODO_ROOT/tasks/active-tasks.json"
    else
        python3 -c "
import json
import sys

data = json.loads('$active_tasks')
new_task = json.loads('$new_task')
data['tasks'].append(new_task)
print(json.dumps(data, indent=2))
" > "$TODO_ROOT/tasks/active-tasks.json"
    fi
    
    log_task "Created task: $task_id - $title"
    echo "$task_id"
}

# List tasks
list_tasks() {
    local status="${1:-all}"
    local project="${2:-all}"
    
    echo -e "\n${BLUE}=== Task List ===${NC}"
    echo -e "Status: $status | Project: $project\n"
    
    # Function to display tasks from a file
    display_tasks() {
        local file="$1"
        local file_status="$2"
        
        if [ ! -f "$file" ]; then
            return
        fi
        
        if command -v jq >/dev/null 2>&1; then
            # Use jq for pretty output
            local filter=".tasks[]"
            if [ "$project" != "all" ]; then
                filter="$filter | select(.project == \"$project\")"
            fi
            
            jq -r "$filter | \"[\(.priority)] \(.id) - \(.title) (Project: \(.project))\"" "$file" 2>/dev/null || true
        else
            # Fallback to python
            python3 -c "
import json
with open('$file', 'r') as f:
    data = json.load(f)
    for task in data.get('tasks', []):
        if '$project' == 'all' or task.get('project') == '$project':
            print(f\"[{task.get('priority', 'medium')}] {task['id']} - {task['title']} (Project: {task.get('project', 'none')})\")
" 2>/dev/null || true
        fi
    }
    
    # Display tasks based on status
    case "$status" in
        active|in-progress|created)
            echo -e "${GREEN}Active Tasks:${NC}"
            display_tasks "$TODO_ROOT/tasks/active-tasks.json" "active"
            ;;
        completed|done)
            echo -e "${BLUE}Completed Tasks:${NC}"
            display_tasks "$TODO_ROOT/tasks/completed-tasks.json" "completed"
            ;;
        backlog)
            echo -e "${YELLOW}Backlog Tasks:${NC}"
            display_tasks "$TODO_ROOT/tasks/backlog.json" "backlog"
            ;;
        all|*)
            echo -e "${GREEN}Active Tasks:${NC}"
            display_tasks "$TODO_ROOT/tasks/active-tasks.json" "active"
            echo -e "\n${BLUE}Completed Tasks:${NC}"
            display_tasks "$TODO_ROOT/tasks/completed-tasks.json" "completed"
            echo -e "\n${YELLOW}Backlog Tasks:${NC}"
            display_tasks "$TODO_ROOT/tasks/backlog.json" "backlog"
            ;;
    esac
}

# Generate daily report
generate_daily_report() {
    local date=$(get_date)
    local report_file="$TODO_ROOT/reports/daily/${date}-report.md"
    
    cat > "$report_file" <<EOF
# Daily Report - ${date}

## Summary
Generated at: $(date +"%H:%M:%S")

## Active Tasks
$(list_tasks active all)

## Completed Today
$(list_tasks completed all | grep -A 100 "$(get_date)" || echo "No tasks completed today")

## Conversations
$(ls -la "$TODO_ROOT/conversations/${date}"*.md 2>/dev/null | wc -l || echo "0") conversation(s) logged today

## Notes
- Add any additional notes here

---
Generated by Server Todo Manager
EOF
    
    log_info "Daily report generated: $report_file"
    cat "$report_file"
}

# Show recent context
show_context() {
    local days="${1:-7}"
    local project="${2:-all}"
    
    echo -e "\n${BLUE}=== Recent Context (Last $days days) ===${NC}\n"
    
    # Find recent conversation summaries
    echo -e "${GREEN}Recent Conversations:${NC}"
    find "$TODO_ROOT/conversations" -name "*.md" -mtime -"$days" -type f | \
        xargs -I {} basename {} | sort -r | head -10
    
    echo -e "\n${GREEN}Recent Tasks:${NC}"
    list_tasks active "$project" | head -20
    
    echo -e "\n${GREEN}Quick Stats:${NC}"
    local active_count=$(grep -c '"status":' "$TODO_ROOT/tasks/active-tasks.json" 2>/dev/null || echo "0")
    local completed_count=$(grep -c '"status":' "$TODO_ROOT/tasks/completed-tasks.json" 2>/dev/null || echo "0")
    
    echo "- Active tasks: $active_count"
    echo "- Completed tasks: $completed_count"
    echo "- Projects tracked: $(grep -c '"id":' "$TODO_ROOT/projects/project-registry.json" 2>/dev/null || echo "0")"
}

# Main command handler
main() {
    init_task_files
    
    local command="${1:-help}"
    shift || true
    
    case "$command" in
        conversation|conv)
            log_conversation "$@"
            ;;
        add|task)
            add_task "$@"
            ;;
        list|ls)
            list_tasks "$@"
            ;;
        report)
            generate_daily_report
            ;;
        context|ctx)
            show_context "$@"
            ;;
        init)
            init_task_files
            log_info "Todo manager initialized at: $TODO_ROOT"
            ;;
        help|--help|-h)
            cat <<EOF
Server Todo Manager

Usage: $0 [command] [options]

Commands:
    conversation, conv     Log a conversation summary
                          Usage: $0 conv "Summary of discussion"
    
    add, task             Add a new task
                          Usage: $0 add "Task title" [project] [priority] [description]
    
    list, ls              List tasks
                          Usage: $0 list [status] [project]
                          Status: all, active, completed, backlog
    
    report                Generate daily report
                          Usage: $0 report
    
    context, ctx          Show recent context
                          Usage: $0 context [days] [project]
    
    init                  Initialize todo manager
    
    help                  Show this help message

Examples:
    $0 conv "Discussed Python package deployment"
    $0 add "Deploy Python package to PyPI" grim-reaper high
    $0 list active grim-reaper
    $0 context 7
    $0 report

Todo Root: $TODO_ROOT
EOF
            ;;
        *)
            log_error "Unknown command: $command"
            echo "Run '$0 help' for usage information"
            exit 1
            ;;
    esac
}

# Run main function
main "$@"