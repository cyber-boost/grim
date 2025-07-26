# Grim Reaper System Agents

This directory contains specialized AI agents for managing and developing the Grim Reaper System across multiple programming languages and package managers.

## Agent Architecture

The system uses a single build manager with language-specific implementation agents to ensure consistency while respecting each ecosystem's conventions.

## Available Agents

### 1. Build Manager (Single Authority)
**File:** `grim-build-manager.md`
- **Purpose:** Central build authority for the entire system
- **Responsibilities:**
  - Execute `/opt/reaper/admin/build.sh` (only agent authorized to do so)
  - Coordinate multi-platform deployments
  - Ensure version consistency across all package managers
  - Validate path portability before building

### 2. Language Implementation Agents

#### JavaScript/Node.js Expert
**File:** `js-implementation-expert.md`
- **Purpose:** Implement JavaScript/TypeScript code for npm packages
- **Key Features:**
  - CommonJS and ESM dual support
  - Cross-platform path resolution
  - npm package configuration
  - TypeScript type definitions

#### Python Expert
**File:** `python-implementation-expert.md`
- **Purpose:** Implement Python code for PyPI packages
- **Key Features:**
  - PEP-compliant packaging
  - Cross-platform configuration discovery
  - Entry points and CLI setup
  - Virtual environment compatibility

#### Go Expert
**File:** `go-implementation-expert.md`
- **Purpose:** Implement Go code and modules
- **Key Features:**
  - Cross-compilation support
  - Embedded resources
  - Build tags for platform-specific code
  - `go install` compatibility

#### Ruby Expert
**File:** `ruby-implementation-expert.md`
- **Purpose:** Implement Ruby code for RubyGems
- **Key Features:**
  - Gem specification setup
  - Thor-based CLI
  - Platform detection
  - Bundler integration

#### Rust Expert
**File:** `rust-implementation-expert.md`
- **Purpose:** Implement Rust code for crates.io
- **Key Features:**
  - Cross-platform cargo configuration
  - Embedded throne scripts
  - async/await support with Tokio
  - Comprehensive error handling

#### PHP Expert
**File:** `php-implementation-expert.md`
- **Purpose:** Implement PHP code for Composer/Packagist
- **Key Features:**
  - PSR-4 autoloading
  - Symfony Console integration
  - Cross-platform compatibility
  - Composer scripts

#### Shell/Bash Expert
**File:** `shell-implementation-expert.md`
- **Purpose:** Implement shell scripts and system integration
- **Key Features:**
  - POSIX compliance
  - Cross-shell compatibility (bash, sh, zsh)
  - Service management (systemd, launchd)
  - Installation and setup scripts

### 3. Documentation Specialist
**File:** `docs-writer-agent.md`
- **Purpose:** Create and update documentation for all language packages
- **Responsibilities:**
  - Generate language-specific READMEs
  - Update API documentation
  - Create migration guides
  - Ensure examples use portable paths

## Key Principles

### Path Portability
All agents must ensure that deployed packages never hardcode paths. Instead, they use:
- Environment variables: `$GRIM_ROOT`
- Default fallbacks: `$HOME/.graveyard`
- Platform-specific conventions when appropriate

### Single Build Authority
Only the `grim-build-manager` agent can execute build operations. This ensures:
- No duplicate builds
- Consistent versioning
- Synchronized deployments
- Proper manifest updates

### Language Ecosystem Respect
Each implementation agent follows the conventions and best practices of its language:
- JavaScript: npm/yarn conventions
- Python: PEP standards
- Go: Go modules and standard project layout
- Ruby: RubyGems conventions
- Rust: Cargo and crates.io standards
- PHP: PSR standards and Composer
- Shell: POSIX compliance

## Usage Examples

### Implementing a New Feature
1. Use the appropriate language implementation agent to write the code
2. Use the docs-writer agent to update documentation
3. Use the grim-build-manager to build and deploy

### Updating Package Dependencies
1. Use the language-specific agent to update dependency files
2. Test the changes locally
3. Use the grim-build-manager to propagate changes

### Creating Cross-Platform Support
1. Consult multiple language agents for their platform detection methods
2. Implement consistent behavior across all packages
3. Use the docs-writer agent to document platform-specific behaviors

## Agent Selection Guide

Choose the appropriate agent based on your task:

- **Building/Deploying:** Always use `grim-build-manager`
- **Writing Code:** Use the language-specific implementation agent
- **Updating Docs:** Use `docs-writer-agent`
- **System Integration:** Use `shell-implementation-expert`

Remember: Agents work together. The build manager coordinates with implementation agents, and all changes should be documented by the docs-writer agent.