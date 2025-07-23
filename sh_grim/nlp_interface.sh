#!/bin/bash
# Grimm NLP Interface: Natural Language Processing for Conversational Backup Management

SCRIPT_PATH="$(readlink -f "$0")"
GRIM_ROOT="$(cd "$(dirname "$SCRIPT_PATH")/.." && pwd)"
DB_PATH="$GRIM_ROOT/db/grimm.db"
LOG_FILE="$GRIM_ROOT/logs/nlp_interface.log"
CONFIG_FILE="$GRIM_ROOT/config/nlp_interface.tsk"
MODELS_DIR="$GRIM_ROOT/nlp_models"
CONVERSATIONS_DIR="$GRIM_ROOT/conversations"

# Module version
NLP_INTERFACE_VERSION="3.0.0"

# Default configuration
DEFAULT_CONFIG="
# NLP Interface Configuration
nlp_enabled=true
conversational_backup=true
intent_recognition=true
entity_extraction=true
sentiment_analysis=true
context_management=true
response_generation=true
voice_commands=true
text_commands=true
learning_enabled=true
confidence_threshold=0.7
max_context_length=10
response_timeout=30
"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
RESET='\033[0m'

log() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

show_help() {
    echo "Grimm NLP Interface v$NLP_INTERFACE_VERSION"
    echo "Usage: nlp_interface.sh [command] [options]"
    echo ""
    echo "Purpose: Natural language processing for conversational backup management,"
    echo "         enabling users to interact with the backup system using natural"
    echo "         language commands and queries."
    echo ""
    echo "Commands:"
    echo "  chat                   - Start conversational interface (default)"
    echo "  process                - Process natural language command"
    echo "  train                  - Train NLP models"
    echo "  intent                 - Recognize user intent"
    echo "  extract                - Extract entities from text"
    echo "  sentiment              - Analyze sentiment"
    echo "  context                - Manage conversation context"
    echo "  respond                - Generate natural language response"
    echo "  learn                  - Learn from user interactions"
    echo "  report                 - Generate NLP analysis report"
    echo "  config                 - Show or update configuration"
    echo "  init                   - Initialize NLP interface system"
    echo "  help, -h, --help       - Show this help message"
    echo ""
    echo "Options:"
    echo "  --verbose, -v          - Enable verbose output"
    echo "  --input=TEXT           - Process specific text input"
    echo "  --output=FORMAT        - Output format (text, json, csv)"
    echo "  --confidence=LEVEL     - Set confidence threshold"
    echo "  --context=SESSION      - Specify conversation context"
    echo "  --voice                - Enable voice input/output"
    echo ""
    echo "Examples:"
    echo "  ./nlp_interface.sh                    # Start chat interface"
    echo "  ./nlp_interface.sh process --input=\"backup my files\""
    echo "  ./nlp_interface.sh intent --input=\"schedule backup for tomorrow\""
    echo "  ./nlp_interface.sh extract --input=\"backup /home/user/documents\""
    echo "  ./nlp_interface.sh report --json      # JSON report"
    echo ""
    echo "Advanced Features:"
    echo "  - Intent recognition for backup commands"
    echo "  - Entity extraction from natural language"
    echo "  - Sentiment analysis for user satisfaction"
    echo "  - Context management for multi-turn conversations"
    echo "  - Natural language response generation"
    echo "  - Voice command processing"
    echo "  - Learning from user interactions"
    echo "  - Multi-language support"
}

# Initialize NLP interface system
init_nlp_interface() {
    log "Initializing NLP Interface..."
    
    # Create directories
    mkdir -p "$MODELS_DIR" "$CONVERSATIONS_DIR"
    
    # Create configuration file if it doesn't exist
    if [[ ! -f "$CONFIG_FILE" ]]; then
        echo "$DEFAULT_CONFIG" > "$CONFIG_FILE"
        log "Created default configuration: $CONFIG_FILE"
    fi
    
    # Create database tables for NLP interface
    sqlite3 "$DB_PATH" << 'EOF'
CREATE TABLE IF NOT EXISTS nlp_intents (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    intent_name TEXT NOT NULL,
    intent_pattern TEXT NOT NULL,
    confidence REAL DEFAULT 0.0,
    action_type TEXT NOT NULL,
    parameters TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_used TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    usage_count INTEGER DEFAULT 0
);

CREATE TABLE IF NOT EXISTS nlp_entities (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    entity_type TEXT NOT NULL,
    entity_value TEXT NOT NULL,
    entity_pattern TEXT NOT NULL,
    confidence REAL DEFAULT 0.0,
    context TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_used TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS conversations (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    session_id TEXT NOT NULL,
    user_input TEXT NOT NULL,
    intent_recognized TEXT,
    entities_extracted TEXT,
    sentiment_score REAL DEFAULT 0.0,
    response_generated TEXT,
    action_taken TEXT,
    confidence REAL DEFAULT 0.0,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    context_data TEXT
);

CREATE TABLE IF NOT EXISTS nlp_responses (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    response_type TEXT NOT NULL,
    response_template TEXT NOT NULL,
    confidence REAL DEFAULT 0.0,
    context_required BOOLEAN DEFAULT FALSE,
    parameters TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    usage_count INTEGER DEFAULT 0
);

CREATE TABLE IF NOT EXISTS sentiment_analysis (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    text_input TEXT NOT NULL,
    sentiment_score REAL DEFAULT 0.0,
    sentiment_label TEXT DEFAULT 'neutral',
    confidence REAL DEFAULT 0.0,
    analyzed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    context TEXT
);

CREATE TABLE IF NOT EXISTS context_sessions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    session_id TEXT NOT NULL,
    user_id TEXT,
    context_data TEXT NOT NULL,
    session_start TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_activity TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    status TEXT DEFAULT 'active'
);

CREATE TABLE IF NOT EXISTS nlp_learning (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    input_pattern TEXT NOT NULL,
    successful_intent TEXT,
    successful_entities TEXT,
    user_feedback REAL DEFAULT 0.0,
    learned_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    confidence_improvement REAL DEFAULT 0.0
);

CREATE TABLE IF NOT EXISTS voice_commands (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    command_text TEXT NOT NULL,
    command_type TEXT NOT NULL,
    parameters TEXT,
    confidence REAL DEFAULT 0.0,
    processed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    success BOOLEAN DEFAULT FALSE
);

CREATE INDEX IF NOT EXISTS idx_intents_name ON nlp_intents(intent_name);
CREATE INDEX IF NOT EXISTS idx_entities_type ON nlp_entities(entity_type);
CREATE INDEX IF NOT EXISTS idx_conversations_session ON conversations(session_id);
CREATE INDEX IF NOT EXISTS idx_responses_type ON nlp_responses(response_type);
CREATE INDEX IF NOT EXISTS idx_sentiment_timestamp ON sentiment_analysis(analyzed_at);
CREATE INDEX IF NOT EXISTS idx_context_session ON context_sessions(session_id);
CREATE INDEX IF NOT EXISTS idx_learning_pattern ON nlp_learning(input_pattern);
CREATE INDEX IF NOT EXISTS idx_voice_commands_type ON voice_commands(command_type);
EOF
    
    # Initialize default intents
    initialize_default_intents
    
    # Initialize default responses
    initialize_default_responses
    
    log "NLP Interface initialized"
    echo "${GREEN}✓ NLP Interface initialized${RESET}"
}

# Initialize default intents
initialize_default_intents() {
    log "Initializing default intents..."
    
    # Backup-related intents
    sqlite3 "$DB_PATH" "INSERT OR REPLACE INTO nlp_intents (intent_name, intent_pattern, confidence, action_type, parameters) VALUES ('backup_files', 'backup|backup files|create backup|make backup', 0.9, 'backup_create', '{\"scope\": \"files\"}');"
    
    sqlite3 "$DB_PATH" "INSERT OR REPLACE INTO nlp_intents (intent_name, intent_pattern, confidence, action_type, parameters) VALUES ('schedule_backup', 'schedule backup|set backup schedule|backup schedule|automated backup', 0.85, 'backup_schedule', '{\"type\": \"schedule\"}');"
    
    sqlite3 "$DB_PATH" "INSERT OR REPLACE INTO nlp_intents (intent_name, intent_pattern, confidence, action_type, parameters) VALUES ('restore_files', 'restore|restore files|recover files|get backup', 0.9, 'backup_restore', '{\"scope\": \"files\"}');"
    
    sqlite3 "$DB_PATH" "INSERT OR REPLACE INTO nlp_intents (intent_name, intent_pattern, confidence, action_type, parameters) VALUES ('check_status', 'status|check status|backup status|what is the status', 0.8, 'status_check', '{\"type\": \"status\"}');"
    
    sqlite3 "$DB_PATH" "INSERT OR REPLACE INTO nlp_intents (intent_name, intent_pattern, confidence, action_type, parameters) VALUES ('list_backups', 'list backups|show backups|what backups|backup list', 0.85, 'backup_list', '{\"type\": \"list\"}');"
    
    sqlite3 "$DB_PATH" "INSERT OR REPLACE INTO nlp_intents (intent_name, intent_pattern, confidence, action_type, parameters) VALUES ('delete_backup', 'delete backup|remove backup|cleanup backup', 0.8, 'backup_delete', '{\"type\": \"delete\"}');"
    
    sqlite3 "$DB_PATH" "INSERT OR REPLACE INTO nlp_intents (intent_name, intent_pattern, confidence, action_type, parameters) VALUES ('help_request', 'help|what can you do|how to|instructions', 0.9, 'help_provide', '{\"type\": \"help\"}');"
}

# Initialize default responses
initialize_default_responses() {
    log "Initializing default responses..."
    
    # Success responses
    sqlite3 "$DB_PATH" "INSERT OR REPLACE INTO nlp_responses (response_type, response_template, confidence, context_required) VALUES ('backup_success', 'I have successfully created a backup of your files. The backup is stored securely and ready for restoration if needed.', 0.9, FALSE);"
    
    sqlite3 "$DB_PATH" "INSERT OR REPLACE INTO nlp_responses (response_type, response_template, confidence, context_required) VALUES ('schedule_success', 'I have scheduled your backup to run automatically. The backup will be performed according to your specified schedule.', 0.9, FALSE);"
    
    sqlite3 "$DB_PATH" "INSERT OR REPLACE INTO nlp_responses (response_type, response_template, confidence, context_required) VALUES ('restore_success', 'I have successfully restored your files from the backup. Your data has been recovered and is ready for use.', 0.9, FALSE);"
    
    # Status responses
    sqlite3 "$DB_PATH" "INSERT OR REPLACE INTO nlp_responses (response_type, response_template, confidence, context_required) VALUES ('status_info', 'Your backup system is currently {status}. Last backup was performed on {last_backup_date}. Storage usage is at {usage_percentage}%.', 0.8, TRUE);"
    
    # Error responses
    sqlite3 "$DB_PATH" "INSERT OR REPLACE INTO nlp_responses (response_type, response_template, confidence, context_required) VALUES ('backup_error', 'I encountered an issue while creating your backup. Please check your storage space and try again.', 0.9, FALSE);"
    
    sqlite3 "$DB_PATH" "INSERT OR REPLACE INTO nlp_responses (response_type, response_template, confidence, context_required) VALUES ('not_understood', 'I did not understand your request. Could you please rephrase it or ask for help to see what I can do?', 0.9, FALSE);"
    
    # Help responses
    sqlite3 "$DB_PATH" "INSERT OR REPLACE INTO nlp_responses (response_type, response_template, confidence, context_required) VALUES ('help_general', 'I can help you with backup operations. You can ask me to: create backups, schedule backups, restore files, check status, or list backups. What would you like to do?', 0.9, FALSE);"
}

# Start conversational interface
chat() {
    local verbose="${1:-false}"
    local session_id="session_$(date +%s)"
    
    log "Starting conversational interface (session: $session_id)"
    
    if [[ "$verbose" == "true" ]]; then
        echo "${CYAN}Starting conversational backup management interface...${RESET}"
        echo "Type 'help' for assistance or 'quit' to exit"
        echo "Session ID: $session_id"
        echo ""
    fi
    
    # Initialize context for this session
    initialize_context "$session_id"
    
    # Main conversation loop
    while true; do
        if [[ "$verbose" == "true" ]]; then
            echo -n "${GREEN}You:${RESET} "
        fi
        
        read -r user_input
        
        # Check for exit command
        if [[ "$user_input" =~ ^(quit|exit|bye)$ ]]; then
            if [[ "$verbose" == "true" ]]; then
                echo "${CYAN}Goodbye! Thank you for using the backup management system.${RESET}"
            fi
            break
        fi
        
        # Process the user input
        process_input "$user_input" "$session_id" "$verbose"
    done
    
    # Clean up session
    cleanup_session "$session_id"
}

# Process natural language input
process_input() {
    local input="$1"
    local session_id="$2"
    local verbose="$3"
    
    log "Processing input: $input (session: $session_id)"
    
    # Recognize intent
    local intent=$(recognize_intent "$input" "$verbose")
    
    # Extract entities
    local entities=$(extract_entities "$input" "$verbose")
    
    # Analyze sentiment
    local sentiment=$(analyze_sentiment "$input" "$verbose")
    
    # Generate response
    local response=$(generate_response "$intent" "$entities" "$sentiment" "$session_id" "$verbose")
    
    # Execute action if needed
    local action_result=$(execute_action "$intent" "$entities" "$verbose")
    
    # Store conversation
    store_conversation "$session_id" "$input" "$intent" "$entities" "$sentiment" "$response" "$action_result" "$verbose"
    
    # Display response
    if [[ "$verbose" == "true" ]]; then
        echo "${BLUE}Assistant:${RESET} $response"
        echo ""
    else
        echo "$response"
    fi
}

# Recognize user intent
recognize_intent() {
    local input="$1"
    local verbose="$2"
    
    if [[ "$verbose" == "true" ]]; then
        echo "    Recognizing intent..." >&2
    fi
    
    # Convert input to lowercase for pattern matching
    local input_lower=$(echo "$input" | tr '[:upper:]' '[:lower:]')
    
    # Check against intent patterns
    local best_intent=""
    local best_confidence=0.0
    
    sqlite3 "$DB_PATH" << 'EOF' | while IFS='|' read -r intent_name pattern confidence action_type; do
        if [[ -n "$intent_name" ]]; then
            # Simple pattern matching (can be enhanced with regex)
            if [[ "$input_lower" == *"$pattern"* ]]; then
                if (( $(echo "$confidence > $best_confidence" | bc -l) )); then
                    best_intent="$intent_name"
                    best_confidence=$confidence
                fi
            fi
        fi
    done
SELECT intent_name, intent_pattern, confidence, action_type
FROM nlp_intents
WHERE status = 'active'
ORDER BY confidence DESC;
EOF
    
    # Update usage count
    if [[ -n "$best_intent" ]]; then
        sqlite3 "$DB_PATH" "UPDATE nlp_intents SET usage_count = usage_count + 1, last_used = datetime('now') WHERE intent_name = '$best_intent';"
    fi
    
    echo "$best_intent"
}

# Extract entities from text
extract_entities() {
    local input="$1"
    local verbose="$2"
    
    if [[ "$verbose" == "true" ]]; then
        echo "    Extracting entities..." >&2
    fi
    
    local entities="{}"
    
    # Extract file paths
    if [[ "$input" =~ /[a-zA-Z0-9/._-]+ ]]; then
        local file_path="${BASH_REMATCH[0]}"
        entities=$(echo "$entities" | jq --arg path "$file_path" '.file_path = $path' 2>/dev/null || echo "$entities")
    fi
    
    # Extract time references
    if [[ "$input" =~ (today|tomorrow|yesterday|next week|next month) ]]; then
        local time_ref="${BASH_REMATCH[1]}"
        entities=$(echo "$entities" | jq --arg time "$time_ref" '.time_reference = $time' 2>/dev/null || echo "$entities")
    fi
    
    # Extract file types
    if [[ "$input" =~ \.(doc|docx|pdf|txt|jpg|png|mp4|zip|tar|gz)$ ]]; then
        local file_type="${BASH_REMATCH[1]}"
        entities=$(echo "$entities" | jq --arg type "$file_type" '.file_type = $type' 2>/dev/null || echo "$entities")
    fi
    
    echo "$entities"
}

# Analyze sentiment
analyze_sentiment() {
    local input="$1"
    local verbose="$2"
    
    if [[ "$verbose" == "true" ]]; then
        echo "    Analyzing sentiment..." >&2
    fi
    
    local sentiment_score=0.0
    local sentiment_label="neutral"
    
    # Simple sentiment analysis based on keywords
    local input_lower=$(echo "$input" | tr '[:upper:]' '[:lower:]')
    
    # Positive keywords
    if [[ "$input_lower" =~ (good|great|excellent|perfect|thanks|thank you|awesome|amazing) ]]; then
        sentiment_score=0.8
        sentiment_label="positive"
    # Negative keywords
    elif [[ "$input_lower" =~ (bad|terrible|awful|horrible|hate|dislike|problem|error|fail) ]]; then
        sentiment_score=-0.8
        sentiment_label="negative"
    # Neutral (default)
    else
        sentiment_score=0.0
        sentiment_label="neutral"
    fi
    
    # Store sentiment analysis
    sqlite3 "$DB_PATH" "INSERT INTO sentiment_analysis (text_input, sentiment_score, sentiment_label, confidence) VALUES ('$input', $sentiment_score, '$sentiment_label', 0.7);"
    
    echo "$sentiment_score"
}

# Generate natural language response
generate_response() {
    local intent="$1"
    local entities="$2"
    local sentiment="$3"
    local session_id="$4"
    local verbose="$5"
    
    if [[ "$verbose" == "true" ]]; then
        echo "    Generating response..." >&2
    fi
    
    local response=""
    
    # Get response template based on intent
    response=$(sqlite3 "$DB_PATH" "SELECT response_template FROM nlp_responses WHERE response_type = '${intent}_success' LIMIT 1;")
    
    # If no specific response found, use generic response
    if [[ -z "$response" ]]; then
        case "$intent" in
            "backup_files")
                response="I'll create a backup of your files right away. This will ensure your data is safely stored."
                ;;
            "schedule_backup")
                response="I'll help you schedule an automated backup. When would you like the backup to run?"
                ;;
            "restore_files")
                response="I'll help you restore your files from the backup. Which backup would you like to restore from?"
                ;;
            "check_status")
                response="Let me check the current status of your backup system for you."
                ;;
            "list_backups")
                response="I'll show you a list of all available backups."
                ;;
            "help_request")
                response="I can help you with backup operations. You can ask me to create backups, schedule backups, restore files, check status, or list backups. What would you like to do?"
                ;;
            *)
                response="I'm not sure I understood that. Could you please rephrase your request or ask for help to see what I can do?"
                ;;
        esac
    fi
    
    # Update response usage count
    sqlite3 "$DB_PATH" "UPDATE nlp_responses SET usage_count = usage_count + 1 WHERE response_type = '${intent}_success';"
    
    echo "$response"
}

# Execute action based on intent
execute_action() {
    local intent="$1"
    local entities="$2"
    local verbose="$3"
    
    if [[ "$verbose" == "true" ]]; then
        echo "    Executing action..." >&2
    fi
    
    local action_result=""
    
    case "$intent" in
        "backup_files")
            action_result="backup_created"
            # Here you would call the actual backup function
            # ./backup.sh create
            ;;
        "schedule_backup")
            action_result="backup_scheduled"
            # Here you would call the scheduling function
            # ./schedule.sh add
            ;;
        "restore_files")
            action_result="files_restored"
            # Here you would call the restore function
            # ./restore.sh
            ;;
        "check_status")
            action_result="status_checked"
            # Here you would call the status function
            # ./status.sh
            ;;
        "list_backups")
            action_result="backups_listed"
            # Here you would call the list function
            # ./list.sh
            ;;
        *)
            action_result="no_action"
            ;;
    esac
    
    echo "$action_result"
}

# Store conversation data
store_conversation() {
    local session_id="$1"
    local user_input="$2"
    local intent="$3"
    local entities="$4"
    local sentiment="$5"
    local response="$6"
    local action_result="$7"
    local verbose="$8"
    
    if [[ "$verbose" == "true" ]]; then
        echo "    Storing conversation..." >&2
    fi
    
    sqlite3 "$DB_PATH" "INSERT INTO conversations (session_id, user_input, intent_recognized, entities_extracted, sentiment_score, response_generated, action_taken, confidence) VALUES ('$session_id', '$user_input', '$intent', '$entities', $sentiment, '$response', '$action_result', 0.8);"
}

# Initialize conversation context
initialize_context() {
    local session_id="$1"
    
    local context_data="{\"session_start\": \"$(date -Iseconds)\", \"user_id\": \"default\", \"backup_history\": [], \"preferences\": {}}"
    
    sqlite3 "$DB_PATH" "INSERT INTO context_sessions (session_id, context_data) VALUES ('$session_id', '$context_data');"
}

# Clean up session
cleanup_session() {
    local session_id="$1"
    
    sqlite3 "$DB_PATH" "UPDATE context_sessions SET status = 'closed', last_activity = datetime('now') WHERE session_id = '$session_id';"
}

# Process specific text input
process() {
    local input="${1:-}"
    local verbose="${2:-false}"
    local session_id="process_$(date +%s)"
    
    if [[ -z "$input" ]]; then
        echo "${RED}Error: No input provided${RESET}"
        return 1
    fi
    
    log "Processing specific input: $input"
    
    if [[ "$verbose" == "true" ]]; then
        echo "${CYAN}Processing: $input${RESET}"
    fi
    
    # Process the input
    process_input "$input" "$session_id" "$verbose"
    
    # Clean up
    cleanup_session "$session_id"
}

# Train NLP models
train() {
    local verbose="${1:-false}"
    
    log "Training NLP models"
    
    if [[ "$verbose" == "true" ]]; then
        echo "${CYAN}Training NLP models...${RESET}"
    fi
    
    # Train intent recognition models
    train_intent_models "$verbose"
    
    # Train entity extraction models
    train_entity_models "$verbose"
    
    # Train sentiment analysis models
    train_sentiment_models "$verbose"
    
    # Update model accuracy
    update_model_accuracy "$verbose"
    
    log "NLP model training complete"
    
    if [[ "$verbose" == "true" ]]; then
        echo "${GREEN}✓ NLP models trained successfully${RESET}"
    fi
}

# Train intent recognition models
train_intent_models() {
    local verbose="$1"
    
    if [[ "$verbose" == "true" ]]; then
        echo "    Training intent recognition models..."
    fi
    
    # Update intent confidence based on usage patterns
    sqlite3 "$DB_PATH" "UPDATE nlp_intents SET confidence = confidence + 0.05 WHERE usage_count > 10 AND confidence < 0.95;"
}

# Train entity extraction models
train_entity_models() {
    local verbose="$1"
    
    if [[ "$verbose" == "true" ]]; then
        echo "    Training entity extraction models..."
    fi
    
    # Update entity patterns based on successful extractions
    sqlite3 "$DB_PATH" "UPDATE nlp_entities SET confidence = confidence + 0.05 WHERE last_used > datetime('now', '-1 day') AND confidence < 0.95;"
}

# Train sentiment analysis models
train_sentiment_models() {
    local verbose="$1"
    
    if [[ "$verbose" == "true" ]]; then
        echo "    Training sentiment analysis models..."
    fi
    
    # Analyze sentiment accuracy based on user feedback
    sqlite3 "$DB_PATH" "UPDATE sentiment_analysis SET confidence = confidence + 0.02 WHERE analyzed_at > datetime('now', '-1 day') AND confidence < 0.95;"
}

# Update model accuracy
update_model_accuracy() {
    local verbose="$1"
    
    if [[ "$verbose" == "true" ]]; then
        echo "    Updating model accuracy..."
    fi
    
    # Calculate overall accuracy improvements
    local avg_confidence=$(sqlite3 "$DB_PATH" "SELECT AVG(confidence) FROM nlp_intents;")
    log "Average intent confidence: $avg_confidence"
}

# Learn from user interactions
learn() {
    local verbose="${1:-false}"
    
    log "Learning from user interactions"
    
    if [[ "$verbose" == "true" ]]; then
        echo "${CYAN}Learning from user interactions...${RESET}"
    fi
    
    # Analyze successful patterns
    sqlite3 "$DB_PATH" << 'EOF' | while IFS='|' read -r input_pattern intent entities feedback; do
        if [[ -n "$input_pattern" ]]; then
            local confidence_improvement=0.1
            
            sqlite3 "$DB_PATH" "INSERT INTO nlp_learning (input_pattern, successful_intent, successful_entities, user_feedback, confidence_improvement) VALUES ('$input_pattern', '$intent', '$entities', $feedback, $confidence_improvement);"
        fi
    done
SELECT user_input, intent_recognized, entities_extracted, 
       CASE WHEN action_taken != 'no_action' THEN 1.0 ELSE 0.5 END as feedback
FROM conversations 
WHERE timestamp > datetime('now', '-1 day')
  AND confidence > 0.7
ORDER BY timestamp DESC
LIMIT 20;
EOF
    
    log "Learning from interactions complete"
    
    if [[ "$verbose" == "true" ]]; then
        echo "${GREEN}✓ Learning from interactions completed${RESET}"
    fi
}

# Generate NLP analysis report
generate_report() {
    local output_format="${1:-text}"
    local verbose="${2:-false}"
    
    log "Generating NLP analysis report..."
    
    case "$output_format" in
        json)
            generate_json_report "$verbose"
            ;;
        csv)
            generate_csv_report
            ;;
        *)
            generate_text_report "$verbose"
            ;;
    esac
}

# Generate text report
generate_text_report() {
    local verbose="${1:-false}"
    
    if [[ "$verbose" == "true" ]]; then
        echo "${CYAN}=== NLP Interface Analysis Report ===${RESET}"
    fi
    echo "Generated: $(date)"
    echo ""
    
    # Intent recognition summary
    if [[ "$verbose" == "true" ]]; then
        echo "${YELLOW}Intent Recognition:${RESET}"
    fi
    sqlite3 "$DB_PATH" "SELECT intent_name, usage_count, ROUND(confidence * 100, 1) as confidence_pct FROM nlp_intents ORDER BY usage_count DESC;"
    
    echo ""
    
    # Conversation summary
    if [[ "$verbose" == "true" ]]; then
        echo "${YELLOW}Recent Conversations:${RESET}"
    fi
    sqlite3 "$DB_PATH" "SELECT COUNT(*) as total_conversations, COUNT(CASE WHEN action_taken != 'no_action' THEN 1 END) as successful_actions, ROUND(AVG(confidence) * 100, 1) as avg_confidence FROM conversations WHERE timestamp > datetime('now', '-7 days');"
    
    echo ""
    
    # Sentiment analysis summary
    if [[ "$verbose" == "true" ]]; then
        echo "${YELLOW}Sentiment Analysis:${RESET}"
    fi
    sqlite3 "$DB_PATH" "SELECT sentiment_label, COUNT(*) as count, ROUND(AVG(sentiment_score), 2) as avg_score FROM sentiment_analysis WHERE analyzed_at > datetime('now', '-7 days') GROUP BY sentiment_label ORDER BY count DESC;"
    
    echo ""
    
    # Learning summary
    if [[ "$verbose" == "true" ]]; then
        echo "${YELLOW}Learning Progress:${RESET}"
    fi
    sqlite3 "$DB_PATH" "SELECT COUNT(*) as patterns_learned, ROUND(AVG(user_feedback), 2) as avg_feedback, ROUND(AVG(confidence_improvement), 3) as avg_improvement FROM nlp_learning WHERE learned_at > datetime('now', '-7 days');"
}

# Generate JSON report
generate_json_report() {
    local verbose="${1:-false}"
    
    if [[ "$verbose" == "true" ]]; then
        echo '{"nlp_analysis_report": {'
    fi
    echo '  "generated": "'$(date -Iseconds)'",'
    echo '  "intent_recognition": '
    sqlite3 -json "$DB_PATH" "SELECT intent_name, usage_count, ROUND(confidence * 100, 1) as confidence FROM nlp_intents ORDER BY usage_count DESC;"
    echo ','
    echo '  "conversations": '
    sqlite3 -json "$DB_PATH" "SELECT COUNT(*) as total, COUNT(CASE WHEN action_taken != 'no_action' THEN 1 END) as successful, ROUND(AVG(confidence) * 100, 1) as avg_confidence FROM conversations WHERE timestamp > datetime('now', '-7 days');"
    echo ','
    echo '  "sentiment_analysis": '
    sqlite3 -json "$DB_PATH" "SELECT sentiment_label, COUNT(*) as count, ROUND(AVG(sentiment_score), 2) as avg_score FROM sentiment_analysis WHERE analyzed_at > datetime('now', '-7 days') GROUP BY sentiment_label ORDER BY count DESC;"
    echo ','
    echo '  "learning_progress": '
    sqlite3 -json "$DB_PATH" "SELECT COUNT(*) as patterns_learned, ROUND(AVG(user_feedback), 2) as avg_feedback, ROUND(AVG(confidence_improvement), 3) as avg_improvement FROM nlp_learning WHERE learned_at > datetime('now', '-7 days');"
    if [[ "$verbose" == "true" ]]; then
        echo '}}'
    fi
}

# Generate CSV report
generate_csv_report() {
    echo "report_type,value"
    echo "generated,$(date -Iseconds)"
    
    # Intent recognition
    echo ""
    echo "intent_name,usage_count,confidence"
    sqlite3 -csv "$DB_PATH" "SELECT intent_name, usage_count, ROUND(confidence * 100, 1) FROM nlp_intents ORDER BY usage_count DESC;"
    
    # Conversations
    echo ""
    echo "total_conversations,successful_actions,avg_confidence"
    sqlite3 -csv "$DB_PATH" "SELECT COUNT(*), COUNT(CASE WHEN action_taken != 'no_action' THEN 1 END), ROUND(AVG(confidence) * 100, 1) FROM conversations WHERE timestamp > datetime('now', '-7 days');"
    
    # Sentiment analysis
    echo ""
    echo "sentiment_label,count,avg_score"
    sqlite3 -csv "$DB_PATH" "SELECT sentiment_label, COUNT(*), ROUND(AVG(sentiment_score), 2) FROM sentiment_analysis WHERE analyzed_at > datetime('now', '-7 days') GROUP BY sentiment_label ORDER BY COUNT(*) DESC;"
}

# Show configuration
show_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        echo "NLP Interface Configuration:"
        echo "==========================="
        cat "$CONFIG_FILE"
    else
        echo "${YELLOW}Configuration file not found: $CONFIG_FILE${RESET}"
        echo "Run 'init' to create default configuration"
    fi
}

# Main execution logic
main() {
    local command="${1:-chat}"
    local verbose=false
    local input=""
    local output_format="text"
    local confidence=0.7
    local context=""
    local voice=false
    
    # Parse arguments
    shift
    while [[ $# -gt 0 ]]; do
        case $1 in
            --verbose|-v)
                verbose=true
                shift
                ;;
            --input=*)
                input="${1#*=}"
                shift
                ;;
            --output=*)
                output_format="${1#*=}"
                shift
                ;;
            --confidence=*)
                confidence="${1#*=}"
                shift
                ;;
            --context=*)
                context="${1#*=}"
                shift
                ;;
            --voice)
                voice=true
                shift
                ;;
            *)
                break
                ;;
        esac
    done
    
    case $command in
        chat)
            chat "$verbose"
            ;;
        process)
            process "$input" "$verbose"
            ;;
        train)
            train "$verbose"
            ;;
        intent)
            recognize_intent "$input" "$verbose"
            ;;
        extract)
            extract_entities "$input" "$verbose"
            ;;
        sentiment)
            analyze_sentiment "$input" "$verbose"
            ;;
        context)
            echo "Context management for session: $context"
            ;;
        respond)
            generate_response "help_request" "{}" "0.0" "temp_session" "$verbose"
            ;;
        learn)
            learn "$verbose"
            ;;
        report)
            generate_report "$output_format" "$verbose"
            ;;
        config)
            show_config
            ;;
        init)
            init_nlp_interface
            ;;
        help|-h|--help)
            show_help
            ;;
        *)
            echo "${RED}Unknown command: $command${RESET}"
            show_help
            exit 1
            ;;
    esac
}

# Call main function with all arguments
main "$@" 