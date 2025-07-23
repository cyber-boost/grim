#!/bin/bash

# RC - Remote Control Agent Management System
# Usage: ./rc.sh [project_id] [command] [options]

set -e

RC_DIR="/opt/reaper/rc"
TEMPLATES_DIR="/opt/reaper/rc/templates"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Initialize RC system
init_rc() {
    log_info "Initializing RC system..."
    mkdir -p "$RC_DIR"
    mkdir -p "$TEMPLATES_DIR"
    
    # Create project templates
    create_templates
    
    log_success "RC system initialized at $RC_DIR"
}

# Create project templates
create_templates() {
    # TuskTone template conversion project
    mkdir -p "$TEMPLATES_DIR/tusktone"
    cat > "$TEMPLATES_DIR/tusktone/project.json" << 'EOF'
{
  "name": "TuskTone Template Conversion",
  "type": "template_conversion",
  "description": "Convert HTML templates to TuskTone PHP format",
  "time_estimate": "20 minutes",
  "files_needed": [
    "HTML templates",
    "tusk_ai_dev_guide.md",
    "commands.txt"
  ],
  "outputs": [
    "PHP templates",
    "Extracted assets",
    "Feature documentation"
  ]
}
EOF

    # Web development project
    mkdir -p "$TEMPLATES_DIR/webdev"
    cat > "$TEMPLATES_DIR/webdev/project.json" << 'EOF'
{
  "name": "Web Development",
  "type": "web_development",
  "description": "Full-stack web development project",
  "time_estimate": "varies",
  "files_needed": [
    "Requirements",
    "Design files",
    "API specifications"
  ],
  "outputs": [
    "Frontend code",
    "Backend code",
    "Documentation"
  ]
}
EOF

    # Code analysis project
    mkdir -p "$TEMPLATES_DIR/analysis"
    cat > "$TEMPLATES_DIR/analysis/project.json" << 'EOF'
{
  "name": "Code Analysis",
  "type": "code_analysis",
  "description": "Analyze codebase and provide insights",
  "time_estimate": "30 minutes",
  "files_needed": [
    "Source code",
    "Documentation"
  ],
  "outputs": [
    "Analysis report",
    "Recommendations",
    "Metrics"
  ]
}
EOF
}

# Interactive project creation
create_project() {
    local project_id="$1"
    
    if [[ -z "$project_id" ]]; then
        log_error "Project ID required"
        echo "Usage: ./rc.sh create <project_id>"
        exit 1
    fi
    
    local project_dir="$RC_DIR/$project_id"
    
    if [[ -d "$project_dir" ]]; then
        log_error "Project $project_id already exists"
        exit 1
    fi
    
    log_info "Creating new project: $project_id"
    
    # Interactive questions
    echo -e "\n${BLUE}Project Setup Questions:${NC}"
    
    read -p "Project name: " project_name
    read -p "Project type (tusktone/webdev/analysis/custom): " project_type
    read -p "Description: " project_desc
    read -p "Estimated time (e.g., 20 minutes): " time_estimate
    read -p "Priority (low/medium/high/critical): " priority
    
    # Create project structure
    mkdir -p "$project_dir/goals"
    mkdir -p "$project_dir/files"
    mkdir -p "$project_dir/output"
    mkdir -p "$project_dir/logs"
    
    # Create project metadata
    cat > "$project_dir/project.json" << EOF
{
  "id": "$project_id",
  "name": "$project_name",
  "type": "$project_type",
  "description": "$project_desc",
  "time_estimate": "$time_estimate",
  "priority": "$priority",
  "created": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "status": "created",
  "agent": null,
  "files": [],
  "goals": [],
  "outputs": []
}
EOF
    
    # Copy template files if applicable
    if [[ -d "$TEMPLATES_DIR/$project_type" ]]; then
        log_info "Copying template files for $project_type"
        cp -r "$TEMPLATES_DIR/$project_type"/* "$project_dir/" 2>/dev/null || true
    fi
    
    # Create goal files based on project type
    create_goals "$project_id" "$project_type"
    
    log_success "Project $project_id created at $project_dir"
    echo -e "\nNext steps:"
    echo "1. Add files to: $project_dir/files/"
    echo "2. Review goals in: $project_dir/goals/"
    echo "3. Execute with: ./rc.sh $project_id execute"
}

# Create goal files based on project type
create_goals() {
    local project_id="$1"
    local project_type="$2"
    local project_dir="$RC_DIR/$project_id"
    
    case "$project_type" in
        "tusktone")
            cat > "$project_dir/goals/no-goal-1.txt" << 'EOF'
GOAL: Convert HTML Templates to TuskTone PHP
PRIORITY: CRITICAL
TIME LIMIT: 20 minutes

TASK: Convert all HTML templates to proper TuskTone PHP format

REQUIREMENTS:
[ ] Use TuskTone::render('layouts/name', $data) pattern
[ ] Extract CSS/JS assets to mahout/assets/
[ ] Create feature documentation
[ ] Implement grim command integration
[ ] Test all templates render correctly

DELIVERABLES:
[ ] PHP templates in views/admin/ and views/public/
[ ] Extracted assets in mahout/assets/
[ ] Feature documentation files
[ ] Working grim integration
EOF
            ;;
        "webdev")
            cat > "$project_dir/goals/no-goal-1.txt" << 'EOF'
GOAL: Full-Stack Web Development
PRIORITY: HIGH
TIME LIMIT: varies

TASK: Develop complete web application

REQUIREMENTS:
[ ] Frontend user interface
[ ] Backend API endpoints
[ ] Database integration
[ ] Authentication system
[ ] Testing framework

DELIVERABLES:
[ ] Working web application
[ ] API documentation
[ ] Database schema
[ ] Test suite
EOF
            ;;
        "analysis")
            cat > "$project_dir/goals/no-goal-1.txt" << 'EOF'
GOAL: Code Analysis and Insights
PRIORITY: MEDIUM
TIME LIMIT: 30 minutes

TASK: Analyze codebase and provide recommendations

REQUIREMENTS:
[ ] Code quality assessment
[ ] Performance analysis
[ ] Security review
[ ] Architecture evaluation
[ ] Documentation review

DELIVERABLES:
[ ] Analysis report
[ ] Recommendations
[ ] Metrics and statistics
[ ] Improvement plan
EOF
            ;;
        *)
            cat > "$project_dir/goals/no-goal-1.txt" << 'EOF'
GOAL: Custom Project Goal
PRIORITY: MEDIUM
TIME LIMIT: TBD

TASK: Define your custom project requirements

REQUIREMENTS:
[ ] Define specific requirements
[ ] Set clear deliverables
[ ] Establish success criteria
[ ] Create timeline

DELIVERABLES:
[ ] Define expected outputs
[ ] Set quality standards
[ ] Create acceptance criteria
EOF
            ;;
    esac
}

# List all projects
list_projects() {
    log_info "RC Projects:"
    echo
    
    if [[ ! -d "$RC_DIR" ]]; then
        log_warning "No RC directory found. Run './rc.sh init' first."
        return
    fi
    
    for project_dir in "$RC_DIR"/*; do
        if [[ -d "$project_dir" && -f "$project_dir/project.json" ]]; then
            local project_id=$(basename "$project_dir")
            local project_name=$(jq -r '.name' "$project_dir/project.json" 2>/dev/null || echo "Unknown")
            local project_status=$(jq -r '.status' "$project_dir/project.json" 2>/dev/null || echo "unknown")
            local project_type=$(jq -r '.type' "$project_dir/project.json" 2>/dev/null || echo "unknown")
            
            echo -e "${BLUE}$project_id${NC} - $project_name"
            echo -e "  Type: $project_type | Status: $project_status"
            echo
        fi
    done
}

# Show project details
show_project() {
    local project_id="$1"
    local project_dir="$RC_DIR/$project_id"
    
    if [[ ! -d "$project_dir" ]]; then
        log_error "Project $project_id not found"
        exit 1
    fi
    
    log_info "Project Details: $project_id"
    echo
    
    if [[ -f "$project_dir/project.json" ]]; then
        cat "$project_dir/project.json" | jq '.'
    fi
    
    echo
    log_info "Files in project:"
    ls -la "$project_dir/files/" 2>/dev/null || echo "No files yet"
    
    echo
    log_info "Goals:"
    ls -la "$project_dir/goals/" 2>/dev/null || echo "No goals yet"
    
    echo
    log_info "Outputs:"
    ls -la "$project_dir/output/" 2>/dev/null || echo "No outputs yet"
}

# Execute project (prepare for agent)
execute_project() {
    local project_id="$1"
    local project_dir="$RC_DIR/$project_id"
    
    if [[ ! -d "$project_dir" ]]; then
        log_error "Project $project_id not found"
        exit 1
    fi
    
    log_info "Preparing project $project_id for execution"
    
    # Create execution package
    local exec_dir="$project_dir/execution"
    mkdir -p "$exec_dir"
    mkdir -p "$exec_dir/communication"
    
    # Copy all necessary files
    cp -r "$project_dir/goals"/* "$exec_dir/" 2>/dev/null || true
    cp -r "$project_dir/files"/* "$exec_dir/" 2>/dev/null || true
    cp "$project_dir/project.json" "$exec_dir/"
    
    # Create command files for agent communication
    cat > "$exec_dir/communication/status.json" << EOF
{
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "project_id": "$project_id",
  "status": "READY_FOR_EXECUTION",
  "current_goal": null,
  "progress": 0,
  "last_action": "Project prepared for execution",
  "next_action": "Agent should read EXECUTE_ME.md",
  "warnings": [],
  "errors": []
}
EOF

    cat > "$exec_dir/communication/progress.json" << EOF
{
  "goals_completed": 0,
  "total_goals": $(ls "$project_dir/goals/" | wc -l),
  "current_goal": null,
  "files_created": 0,
  "last_update": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF

    cat > "$exec_dir/communication/commands.json" << EOF
{
  "read_before_action": true,
  "update_after_action": true,
  "communication_required": true,
  "commands": [
    {
      "command": "READ_STATUS",
      "description": "Always read status.json before taking any action",
      "required": true
    },
    {
      "command": "UPDATE_PROGRESS",
      "description": "Update progress.json after completing each task",
      "required": true
    },
    {
      "command": "REPORT_COMPLETION",
      "description": "Update status.json when goals are completed",
      "required": true
    }
  ]
}
EOF
    
    # Create comprehensive execution instructions
    cat > "$exec_dir/EXECUTE_ME.md" << EOF
# 🚀 EXECUTE PROJECT: $project_id

## 🚨 CRITICAL AGENT EXECUTION PROTOCOL

### **MANDATORY WORKFLOW - MUST FOLLOW EXACTLY**

**BEFORE EVERY ACTION:**
1. **READ** \`communication/status.json\` - Check current status
2. **READ** \`communication/progress.json\` - Check current progress
3. **READ** \`communication/commands.json\` - Check for new commands

**AFTER EVERY ACTION:**
1. **UPDATE** \`communication/status.json\` with current action
2. **UPDATE** \`communication/progress.json\` with progress
3. **COMMIT** any files created or modified

**NEVER SKIP THESE STEPS - COMMUNICATION IS MANDATORY**

---

## 📋 Project Overview
**Description:** $(jq -r '.description' "$project_dir/project.json")
**Type:** $(jq -r '.type' "$project_dir/project.json")
**Priority:** $(jq -r '.priority' "$project_dir/project.json")
**Time Limit:** $(jq -r '.time_estimate' "$project_dir/project.json")

## 📁 Files Included
\`\`\`
$(ls -la "$exec_dir/" | grep -v "^total")
\`\`\`

## 🎯 Goals to Complete
$(ls "$project_dir/goals/" | sed 's/^/- /')

## 📋 EXECUTION CHECKLIST

### **PHASE 1: INITIALIZATION**
- [ ] Read this EXECUTE_ME.md file completely
- [ ] Read communication/status.json
- [ ] Read communication/progress.json
- [ ] Read communication/commands.json
- [ ] Read project.json for context
- [ ] Update status.json with "INITIALIZATION_COMPLETE"

### **PHASE 2: GOAL EXECUTION**
For each goal file (no-goal-*.txt):
- [ ] Read communication/status.json BEFORE starting
- [ ] Read the goal file completely
- [ ] Update status.json with "GOAL_X_STARTED"
- [ ] Execute all requirements in the goal
- [ ] Create all deliverables specified
- [ ] Update progress.json with completed tasks
- [ ] Update status.json with "GOAL_X_COMPLETED"
- [ ] VERIFY all checkboxes are marked [x]

### **PHASE 3: COMPLETION**
- [ ] Read communication/status.json one final time
- [ ] Verify all goals completed
- [ ] Create final deliverables summary
- [ ] Update status.json with "PROJECT_COMPLETED"
- [ ] Update progress.json with 100% completion
- [ ] Create completion report

## 🔄 COMMUNICATION PROTOCOL

### **Status Updates (MANDATORY)**
Update \`communication/status.json\` with:
\`\`\`json
{
  "timestamp": "current_time",
  "project_id": "$project_id",
  "status": "CURRENT_STATUS",
  "current_goal": "goal_name",
  "progress": percentage,
  "last_action": "what_you_just_did",
  "next_action": "what_you_will_do_next",
  "warnings": [],
  "errors": []
}
\`\`\`

### **Progress Updates (MANDATORY)**
Update \`communication/progress.json\` with:
\`\`\`json
{
  "goals_completed": number,
  "total_goals": total_number,
  "current_goal": "goal_name",
  "files_created": number,
  "last_update": "current_time"
}
\`\`\`

## 📤 Output Locations
- **Created Files:** Place in \`../output/\` directory
- **Logs:** Place in \`../logs/\` directory
- **Documentation:** Include in deliverables

## ⚠️ CRITICAL REQUIREMENTS

1. **ALWAYS READ BEFORE ACTION**: Check status.json before every action
2. **ALWAYS UPDATE AFTER ACTION**: Update progress after every task
3. **FOLLOW CHECKBOXES**: Mark [x] for completed items
4. **TIME LIMITS**: Respect the time limit: $(jq -r '.time_estimate' "$project_dir/project.json")
5. **QUALITY STANDARDS**: All deliverables must meet requirements
6. **COMMUNICATION**: Maintain real-time status updates

## 🚫 FORBIDDEN ACTIONS
- **NO SKIPPING** status/progress reads
- **NO BATCH UPDATES** - update after each action
- **NO INCOMPLETE WORK** - finish what you start
- **NO SILENCE** - always communicate status

## ✅ SUCCESS CRITERIA
- All goals completed with [x] checkboxes
- All deliverables created and functional
- All communication files updated
- Project completed within time limit
- Quality standards met

## 🎯 EXECUTION STARTS NOW

**Step 1:** Read communication/status.json
**Step 2:** Update status.json with "EXECUTION_STARTED"
**Step 3:** Begin Phase 1 - Initialization
**Step 4:** Follow the protocol EXACTLY

**Remember: READ BEFORE ACTION, UPDATE AFTER ACTION, COMMUNICATE ALWAYS**
EOF

    # Create agent prompt file
    cat > "$exec_dir/AGENT_PROMPT.md" << EOF
# 🤖 AGENT EXECUTION PROMPT

## **IMMEDIATE INSTRUCTIONS FOR AI AGENT**

You are about to execute project: **$project_id**

### **CRITICAL PROTOCOL - MUST FOLLOW**

1. **ALWAYS READ FIRST**: Before every action, read \`communication/status.json\`
2. **ALWAYS UPDATE AFTER**: After every action, update \`communication/progress.json\`
3. **FOLLOW WORKFLOW**: Read → Act → Update → Repeat
4. **MARK CHECKBOXES**: Use [x] for completed items
5. **COMMUNICATE STATUS**: Keep status.json current with your actions

### **EXECUTION SEQUENCE**

\`\`\`
1. READ communication/status.json
2. READ EXECUTE_ME.md (full file)
3. UPDATE status.json with "READING_COMPLETE"
4. READ first goal file
5. UPDATE status.json with "GOAL_1_STARTED"
6. EXECUTE goal requirements
7. UPDATE progress.json with completion
8. UPDATE status.json with "GOAL_1_COMPLETED"
9. REPEAT for all goals
10. UPDATE status.json with "PROJECT_COMPLETED"
\`\`\`

### **FILE LOCATIONS**
- **Goals**: no-goal-*.txt files
- **Status**: communication/status.json
- **Progress**: communication/progress.json
- **Commands**: communication/commands.json
- **Outputs**: ../output/ directory

### **TIME LIMIT**: $(jq -r '.time_estimate' "$project_dir/project.json")

### **SUCCESS REQUIREMENT**: 
- All goals completed
- All communication files updated
- All deliverables created
- Project finished within time limit

**BEGIN EXECUTION NOW - READ EXECUTE_ME.md FIRST**
EOF
    
    # Update project status
    jq '.status = "ready_for_execution" | .prepared_at = "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'"' "$project_dir/project.json" > "$project_dir/project.json.tmp"
    mv "$project_dir/project.json.tmp" "$project_dir/project.json"
    
    log_success "Project $project_id ready for execution"
    echo -e "\nExecution package created at: $exec_dir"
    echo -e "\n${GREEN}AGENT INSTRUCTIONS:${NC}"
    echo -e "1. Give the agent the execution directory: $exec_dir"
    echo -e "2. Tell the agent to read EXECUTE_ME.md first"
    echo -e "3. Agent must follow the read-before-action protocol"
    echo -e "4. Monitor progress via: $exec_dir/communication/status.json"
    echo -e "\n${YELLOW}MONITORING COMMAND:${NC}"
    echo -e "watch -n 5 'cat $exec_dir/communication/status.json'"
}

# Main command dispatcher
main() {
    local command="$1"
    local project_id="$2"
    
    case "$command" in
        "init")
            init_rc
            ;;
        "create")
            create_project "$project_id"
            ;;
        "list")
            list_projects
            ;;
        "show")
            show_project "$project_id"
            ;;
        "execute")
            execute_project "$project_id"
            ;;
        "help"|"")
            echo "RC - Remote Control Agent Management System"
            echo
            echo "Usage: ./rc.sh [command] [project_id]"
            echo
            echo "Commands:"
            echo "  init              Initialize RC system"
            echo "  create <id>       Create new project with interactive setup"
            echo "  list              List all projects"
            echo "  show <id>         Show project details"
            echo "  execute <id>      Prepare project for agent execution"
            echo "  help              Show this help"
            echo
            echo "Examples:"
            echo "  ./rc.sh init"
            echo "  ./rc.sh create tusktone_project"
            echo "  ./rc.sh list"
            echo "  ./rc.sh show tusktone_project"
            echo "  ./rc.sh execute tusktone_project"
            ;;
        *)
            log_error "Unknown command: $command"
            echo "Run './rc.sh help' for usage information"
            exit 1
            ;;
    esac
}

# Run main function
main "$@"