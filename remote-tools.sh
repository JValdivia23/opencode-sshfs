#!/bin/bash
# ============================================================================
# remote-tools.sh - SSHFS mount utilities for remote development with OpenCode
# Version: 1.0.0
# https://github.com/JValdivia23/opencode-sshfs
# ============================================================================

# Configuration
REMOTE_TOOLS_VERSION="1.0.0"
# Get the directory containing this script
# Try BASH_SOURCE first, then fall back to $0 for zsh compatibility
_rt_script_path="${BASH_SOURCE[0]:-$0}"
if [[ -n "$_rt_script_path" && "$_rt_script_path" != *"zsh"* && "$_rt_script_path" != *"bash"* ]]; then
    REMOTE_TOOLS_DIR="$(cd "$(dirname "$_rt_script_path")" && pwd)"
else
    # Fallback: if script path can't be determined, check common locations
    if [[ -f "${HOME}/work/opencode-sshfs/remotes.conf" ]]; then
        REMOTE_TOOLS_DIR="${HOME}/work/opencode-sshfs"
    elif [[ -f "${HOME}/.config/opencode-sshfs/remote-tools.sh" ]]; then
        REMOTE_TOOLS_DIR="${HOME}/.config/opencode-sshfs"
    else
        REMOTE_TOOLS_DIR="$(pwd)"
    fi
fi
unset _rt_script_path
REMOTE_TOOLS_VERBOSE=${REMOTE_TOOLS_VERBOSE:-0}

# Colors for output
_RT_RED='\033[0;31m'
_RT_GREEN='\033[0;32m'
_RT_YELLOW='\033[0;33m'
_RT_BLUE='\033[0;34m'
_RT_CYAN='\033[0;36m'
_RT_BOLD='\033[1m'
_RT_NC='\033[0m' # No Color

# ============================================================================
# Internal Helper Functions
# ============================================================================

_rt_log() {
    echo -e "${_RT_CYAN}[remote-tools]${_RT_NC} $1"
}

_rt_success() {
    echo -e "${_RT_GREEN}[OK]${_RT_NC} $1"
}

_rt_error() {
    echo -e "${_RT_RED}[ERROR]${_RT_NC} $1" >&2
}

_rt_warn() {
    echo -e "${_RT_YELLOW}[WARN]${_RT_NC} $1"
}

_rt_debug() {
    if [[ "$REMOTE_TOOLS_VERBOSE" == "1" ]]; then
        echo -e "${_RT_BLUE}[DEBUG]${_RT_NC} $1"
    fi
}

_rt_step() {
    echo -e "${_RT_BOLD}[$1/$2]${_RT_NC} $3"
}

# Find the configuration file
# Search order: $REMOTE_TOOLS_CONFIG -> ./remotes.conf -> ~/.config/opencode-sshfs/remotes.conf
_rt_find_config() {
    if [[ -n "$REMOTE_TOOLS_CONFIG" && -f "$REMOTE_TOOLS_CONFIG" ]]; then
        echo "$REMOTE_TOOLS_CONFIG"
        return 0
    fi
    
    if [[ -f "${REMOTE_TOOLS_DIR}/remotes.conf" ]]; then
        echo "${REMOTE_TOOLS_DIR}/remotes.conf"
        return 0
    fi
    
    if [[ -f "${HOME}/.config/opencode-sshfs/remotes.conf" ]]; then
        echo "${HOME}/.config/opencode-sshfs/remotes.conf"
        return 0
    fi
    
    if [[ -f "${HOME}/remotes.conf" ]]; then
        echo "${HOME}/remotes.conf"
        return 0
    fi
    
    return 1
}

# Parse a remote entry from config
# Returns: name|user|host|remote_path|local_mount
_rt_get_remote() {
    local remote_name="$1"
    local config_file
    
    config_file=$(_rt_find_config) || {
        _rt_error "Configuration file not found."
        _rt_error "Create remotes.conf from remotes.conf.example"
        return 1
    }
    
    local entry
    entry=$(grep -v '^#' "$config_file" | grep -v '^$' | grep "^${remote_name}|" | head -1)
    
    if [[ -z "$entry" ]]; then
        return 1
    fi
    
    echo "$entry"
    return 0
}

# Expand ~ and $USER in paths
_rt_expand_path() {
    local path="$1"
    # Expand ~
    path="${path/#\~/$HOME}"
    # Expand $USER
    path="${path//\$USER/$USER}"
    echo "$path"
}

# Check if a remote is currently mounted
_rt_is_mounted() {
    local mount_point="$1"
    mount_point=$(_rt_expand_path "$mount_point")
    
    if mount | grep -q "on ${mount_point} "; then
        return 0
    fi
    return 1
}

# Check if sshfs is installed
_rt_check_sshfs() {
    if ! command -v sshfs &> /dev/null; then
        _rt_error "sshfs is not installed."
        echo ""
        echo "Install it with:"
        echo "  brew install --cask macfuse"
        echo "  brew install sshfs"
        echo ""
        echo "Note: Restart your computer after installing sshfs."
        return 1
    fi
    return 0
}

# ============================================================================
# User-Facing Functions
# ============================================================================

# List all configured remotes
list-remotes() {
    local config_file
    
    config_file=$(_rt_find_config) || {
        _rt_error "Configuration file not found."
        echo ""
        echo "Create a configuration file at one of these locations:"
        echo "  ${REMOTE_TOOLS_DIR}/remotes.conf"
        echo "  ~/.config/opencode-sshfs/remotes.conf"
        echo ""
        echo "Copy from remotes.conf.example to get started."
        return 1
    }
    
    _rt_log "Configuration: $config_file"
    echo ""
    
    printf "${_RT_BOLD}%-15s %-20s %-30s %-25s${_RT_NC}\n" "NAME" "USER@HOST" "REMOTE PATH" "LOCAL MOUNT"
    printf "%-15s %-20s %-30s %-25s\n" "---------------" "--------------------" "------------------------------" "-------------------------"
    
    while IFS='|' read -r name user host remote_path local_mount; do
        # Skip empty lines and comments
        [[ -z "$name" || "$name" =~ ^# ]] && continue
        
        local user_host="${user}@${host}"
        local expanded_mount="$(_rt_expand_path "$local_mount")"
        
        # Check if mounted
        local mount_status=""
        if _rt_is_mounted "$expanded_mount"; then
            mount_status=" ${_RT_GREEN}[mounted]${_RT_NC}"
        fi
        
        printf "%-15s %-20s %-30s %-25s%b\n" "$name" "$user_host" "$remote_path" "$local_mount" "$mount_status"
    done < "$config_file"
    
    echo ""
}

# Mount a remote filesystem
mount-remote() {
    local remote_name="$1"
    local verbose_flag=""
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -v|--verbose)
                REMOTE_TOOLS_VERBOSE=1
                verbose_flag="-o debug"
                shift
                ;;
            -*)
                _rt_error "Unknown option: $1"
                return 1
                ;;
            *)
                remote_name="$1"
                shift
                ;;
        esac
    done
    
    if [[ -z "$remote_name" ]]; then
        _rt_error "Usage: mount-remote <remote-name> [-v|--verbose]"
        echo ""
        echo "Available remotes:"
        list-remotes
        return 1
    fi
    
    # Check dependencies
    _rt_check_sshfs || return 1
    
    # Get remote configuration
    local entry
    entry=$(_rt_get_remote "$remote_name") || {
        _rt_error "Remote '$remote_name' not found in configuration."
        echo ""
        echo "Run 'list-remotes' to see available remotes."
        return 1
    }
    
    # Parse entry
    IFS='|' read -r name user host remote_path local_mount <<< "$entry"
    
    local expanded_mount="$(_rt_expand_path "$local_mount")"
    local expanded_remote="$(_rt_expand_path "$remote_path")"
    
    _rt_debug "Remote: $name"
    _rt_debug "User: $user"
    _rt_debug "Host: $host"
    _rt_debug "Remote path: $expanded_remote"
    _rt_debug "Local mount: $expanded_mount"
    
    # Check if already mounted
    if _rt_is_mounted "$expanded_mount"; then
        _rt_warn "'$remote_name' is already mounted at $expanded_mount"
        echo ""
        echo "To unmount first, run: umount-remote $remote_name"
        return 1
    fi
    
    # Create mount point if it doesn't exist
    _rt_step 1 4 "Checking mount point..."
    if [[ ! -d "$expanded_mount" ]]; then
        _rt_log "Creating mount point: $expanded_mount"
        mkdir -p "$expanded_mount" || {
            _rt_error "Failed to create mount point: $expanded_mount"
            return 1
        }
    fi
    _rt_success "Mount point ready: $expanded_mount"
    
    # Check SSH sockets directory
    _rt_step 2 4 "Checking SSH configuration..."
    if [[ ! -d "${HOME}/.ssh/sockets" ]]; then
        _rt_log "Creating SSH sockets directory..."
        mkdir -p "${HOME}/.ssh/sockets"
        chmod 700 "${HOME}/.ssh/sockets"
    fi
    _rt_success "SSH configuration ready"
    
    # Mount using sshfs
    _rt_step 3 4 "Connecting to ${user}@${host}..."
    echo ""
    echo "  ${_RT_YELLOW}You may be prompted for password and/or 2FA.${_RT_NC}"
    echo ""
    
    # sshfs options for better performance and reliability
    local sshfs_opts="reconnect,ServerAliveInterval=15,ServerAliveCountMax=3"
    sshfs_opts+=",follow_symlinks,cache=yes,kernel_cache,defer_permissions"
    
    if sshfs "${user}@${host}:${expanded_remote}" "$expanded_mount" -o "$sshfs_opts" $verbose_flag; then
        echo ""
        _rt_step 4 4 "Verifying mount..."
        
        # Give the mount a moment to register, retry a few times
        local mount_verified=false
        for i in 1 2 3 4 5; do
            if _rt_is_mounted "$expanded_mount"; then
                mount_verified=true
                break
            fi
            sleep 0.5
        done
        
        if [[ "$mount_verified" == "true" ]]; then
            _rt_success "Mounted successfully!"
            echo ""
            echo "  ${_RT_BOLD}Next steps:${_RT_NC}"
            echo "    cd $expanded_mount"
            echo "    opencode ."
            echo ""
            echo "  ${_RT_BOLD}To unmount later:${_RT_NC}"
            echo "    umount-remote $remote_name"
            echo ""
            return 0
        else
            _rt_error "Mount command succeeded but mount point is not active."
            return 1
        fi
    else
        echo ""
        _rt_error "Failed to mount $remote_name"
        echo ""
        
        # Check if it's an authentication issue
        if ! ssh -o BatchMode=yes -o ConnectTimeout=5 "${user}@${host}" "echo test" &>/dev/null; then
            echo "${_RT_YELLOW}Authentication may be required.${_RT_NC}"
            echo ""
            echo "If this server requires password + 2FA, run:"
            echo "  ${_RT_BOLD}remote-setup-controlmaster $remote_name${_RT_NC}"
            echo ""
        fi
        
        echo "Troubleshooting steps:"
        echo "  1. Check your network connection"
        echo "  2. Verify credentials: ssh ${user}@${host}"
        echo "  3. Verify remote path exists: ssh ${user}@${host} 'ls -la ${expanded_remote}'"
        echo "  4. Check if macFUSE is properly installed"
        echo ""
        echo "For more help, see: docs/troubleshooting.md"
        return 1
    fi
}

# Unmount a remote filesystem
umount-remote() {
    local remote_name="$1"
    local force_flag=0
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -f|--force)
                force_flag=1
                shift
                ;;
            -*)
                _rt_error "Unknown option: $1"
                return 1
                ;;
            *)
                remote_name="$1"
                shift
                ;;
        esac
    done
    
    if [[ -z "$remote_name" ]]; then
        _rt_error "Usage: umount-remote <remote-name> [-f|--force]"
        echo ""
        echo "Currently mounted remotes:"
        remote-status
        return 1
    fi
    
    # Get remote configuration
    local entry
    entry=$(_rt_get_remote "$remote_name") || {
        _rt_error "Remote '$remote_name' not found in configuration."
        return 1
    }
    
    # Parse entry
    IFS='|' read -r name user host remote_path local_mount <<< "$entry"
    
    local expanded_mount="$(_rt_expand_path "$local_mount")"
    
    # Check if mounted
    if ! _rt_is_mounted "$expanded_mount"; then
        _rt_warn "'$remote_name' is not currently mounted."
        return 0
    fi
    
    _rt_log "Unmounting $remote_name from $expanded_mount..."
    
    if [[ "$force_flag" == "1" ]]; then
        # Force unmount
        if [[ "$(uname)" == "Darwin" ]]; then
            diskutil unmount force "$expanded_mount" 2>/dev/null || umount -f "$expanded_mount"
        else
            fusermount -uz "$expanded_mount" 2>/dev/null || umount -f "$expanded_mount"
        fi
    else
        # Normal unmount
        if [[ "$(uname)" == "Darwin" ]]; then
            umount "$expanded_mount"
        else
            fusermount -u "$expanded_mount"
        fi
    fi
    
    if _rt_is_mounted "$expanded_mount"; then
        _rt_error "Failed to unmount $remote_name"
        echo ""
        echo "The mount point may be in use. Try:"
        echo "  1. Close any applications using files in $expanded_mount"
        echo "  2. cd to a different directory"
        echo "  3. Run: umount-remote $remote_name --force"
        return 1
    fi
    
    _rt_success "Unmounted $remote_name"
    return 0
}

# Show status of all configured remotes
remote-status() {
    local config_file
    
    config_file=$(_rt_find_config) || {
        _rt_error "Configuration file not found."
        return 1
    }
    
    echo ""
    printf "${_RT_BOLD}%-15s %-12s %-30s${_RT_NC}\n" "REMOTE" "STATUS" "MOUNT POINT"
    printf "%-15s %-12s %-30s\n" "---------------" "------------" "------------------------------"
    
    while IFS='|' read -r name user host remote_path local_mount; do
        # Skip empty lines and comments
        [[ -z "$name" || "$name" =~ ^# ]] && continue
        
        local expanded_mount="$(_rt_expand_path "$local_mount")"
        
        local mount_state=""
        local state_color=""
        if _rt_is_mounted "$expanded_mount"; then
            mount_state="mounted"
            state_color="${_RT_GREEN}"
        else
            mount_state="not mounted"
            state_color="${_RT_YELLOW}"
        fi
        
        printf "%-15s ${state_color}%-12s${_RT_NC} %-30s\n" "$name" "$mount_state" "$expanded_mount"
    done < "$config_file"
    
    echo ""
}

# SSH into a configured remote
remote-ssh() {
    local remote_name="$1"
    
    if [[ -z "$remote_name" ]]; then
        _rt_error "Usage: remote-ssh <remote-name>"
        echo ""
        echo "Available remotes:"
        list-remotes
        return 1
    fi
    
    # Get remote configuration
    local entry
    entry=$(_rt_get_remote "$remote_name") || {
        _rt_error "Remote '$remote_name' not found in configuration."
        return 1
    }
    
    # Parse entry
    IFS='|' read -r name user host remote_path local_mount <<< "$entry"
    
    local expanded_remote="$(_rt_expand_path "$remote_path")"
    
    _rt_log "Connecting to ${user}@${host}..."
    echo ""
    
    # SSH and cd to the work directory
    ssh -t "${user}@${host}" "cd '${expanded_remote}' 2>/dev/null && exec \$SHELL -l || exec \$SHELL -l"
}

# Test connectivity to a remote
remote-health() {
    local remote_name="$1"
    
    if [[ -z "$remote_name" ]]; then
        _rt_error "Usage: remote-health <remote-name>"
        return 1
    fi
    
    # Get remote configuration
    local entry
    entry=$(_rt_get_remote "$remote_name") || {
        _rt_error "Remote '$remote_name' not found in configuration."
        return 1
    }
    
    # Parse entry
    IFS='|' read -r name user host remote_path local_mount <<< "$entry"
    
    local expanded_remote="$(_rt_expand_path "$remote_path")"
    
    echo ""
    echo "${_RT_BOLD}Health check for: $remote_name${_RT_NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    # Check 1: DNS/Network
    _rt_step 1 4 "Testing network connectivity to $host..."
    if ping -c 1 -W 5 "$host" &>/dev/null; then
        _rt_success "Host is reachable"
    else
        _rt_warn "Ping failed (may be blocked by firewall, not necessarily an error)"
    fi
    
    # Check 2: SSH Port
    _rt_step 2 4 "Testing SSH port (22)..."
    if nc -z -w 5 "$host" 22 &>/dev/null; then
        _rt_success "SSH port is open"
    else
        _rt_error "SSH port is not reachable"
        return 1
    fi
    
    # Check 3: SSH Authentication
    _rt_step 3 4 "Testing SSH authentication (may prompt for password/2FA)..."
    if ssh -o BatchMode=yes -o ConnectTimeout=10 "${user}@${host}" "echo 'SSH OK'" &>/dev/null; then
        _rt_success "SSH authentication successful (key-based)"
    else
        _rt_warn "Key-based auth not available (password/2FA required for mount)"
        echo ""
        echo "  ${_RT_YELLOW}Consider running:${_RT_NC} remote-setup-controlmaster $remote_name"
        echo "  This will configure SSH ControlMaster for seamless mounting."
        echo ""
    fi
    
    # Check 4: Remote path
    _rt_step 4 4 "Testing remote path (may prompt for password/2FA)..."
    if ssh -o ConnectTimeout=10 "${user}@${host}" "test -d '${expanded_remote}'" 2>/dev/null; then
        _rt_success "Remote path exists: $expanded_remote"
    else
        _rt_warn "Could not verify remote path (may need authentication)"
    fi
    
    echo ""
    echo "${_RT_BOLD}Summary:${_RT_NC}"
    echo "  Host: ${user}@${host}"
    echo "  Remote path: $expanded_remote"
    echo "  Local mount: $(_rt_expand_path "$local_mount")"
    echo ""
}

# Validate configuration file
remote-validate() {
    local config_file
    
    config_file=$(_rt_find_config) || {
        _rt_error "Configuration file not found."
        return 1
    }
    
    _rt_log "Validating configuration: $config_file"
    echo ""
    
    local line_num=0
    local error_count=0
    local valid_count=0
    
    while IFS= read -r line; do
        ((line_num++))
        
        # Skip empty lines and comments
        [[ -z "$line" || "$line" =~ ^# ]] && continue
        
        # Check field count
        local field_count="$(echo "$line" | tr '|' '\n' | wc -l | tr -d ' ')"
        
        if [[ "$field_count" -ne 5 ]]; then
            _rt_error "Line $line_num: Expected 5 fields, found $field_count"
            echo "       $line"
            ((error_count++))
            continue
        fi
        
        # Parse and validate fields
        IFS='|' read -r name user host remote_path local_mount <<< "$line"
        
        # Validate name (alphanumeric, underscore, dash)
        if [[ ! "$name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
            _rt_error "Line $line_num: Invalid remote name '$name' (use alphanumeric, _, -)"
            ((error_count++))
            continue
        fi
        
        # Validate user
        if [[ -z "$user" ]]; then
            _rt_error "Line $line_num: Missing username"
            ((error_count++))
            continue
        fi
        
        # Validate host
        if [[ -z "$host" ]]; then
            _rt_error "Line $line_num: Missing hostname"
            ((error_count++))
            continue
        fi
        
        # Validate remote path (should start with /)
        if [[ ! "$remote_path" =~ ^/ ]]; then
            _rt_warn "Line $line_num: Remote path '$remote_path' should be absolute (start with /)"
        fi
        
        # Validate local mount
        if [[ -z "$local_mount" ]]; then
            _rt_error "Line $line_num: Missing local mount point"
            ((error_count++))
            continue
        fi
        
        ((valid_count++))
        _rt_success "Line $line_num: $name (${user}@${host})"
        
    done < "$config_file"
    
    echo ""
    if [[ "$error_count" -eq 0 ]]; then
        _rt_success "Configuration valid! Found $valid_count remote(s)."
        return 0
    else
        _rt_error "Found $error_count error(s) in configuration."
        return 1
    fi
}

# Show version information
remote-version() {
    echo "opencode-sshfs v${REMOTE_TOOLS_VERSION}"
    echo "Remote development tools for OpenCode"
    echo "https://github.com/JValdivia23/opencode-sshfs"
}

# Show help
remote-help() {
    cat << 'EOF'

opencode-sshfs - Remote Development Tools for OpenCode
=======================================================

COMMANDS:
  list-remotes                 List all configured remote systems
  mount-remote <name>          Mount a remote filesystem via sshfs
  umount-remote <name>         Unmount a remote filesystem
  remote-status                Show mount status of all remotes
  remote-ssh <name>            SSH into a configured remote
  remote-health <name>         Test connectivity to a remote
  remote-validate              Validate the configuration file
  remote-setup-controlmaster <name>  Setup SSH ControlMaster for 2FA/HPC systems
  generate-instructions [name] Generate AGENTS.md/CLAUDE.md instructions for remote(s)
  remote-version               Show version information
  remote-help                  Show this help message

OPTIONS:
  mount-remote:
    -v, --verbose           Enable debug output
  
  umount-remote:
    -f, --force             Force unmount even if busy

ENVIRONMENT VARIABLES:
  REMOTE_TOOLS_CONFIG       Path to custom configuration file
  REMOTE_TOOLS_VERBOSE      Set to 1 for debug output

CONFIGURATION:
  The configuration file (remotes.conf) is searched in:
    1. $REMOTE_TOOLS_CONFIG (if set)
    2. <script-dir>/remotes.conf
    3. ~/.config/opencode-sshfs/remotes.conf
    4. ~/remotes.conf

EXAMPLES:
  # List available remotes
  list-remotes
  
  # Mount a remote and start editing
  mount-remote myserver
  cd ~/mounts/myserver
  opencode .
  
  # Check connectivity before mounting
  remote-health myserver
  
  # Unmount when done
  umount-remote myserver

For more documentation, see: docs/

EOF
}

# Setup SSH ControlMaster for HPC/2FA systems
remote-setup-controlmaster() {
    local remote_name="$1"
    
    if [[ -z "$remote_name" ]]; then
        _rt_error "Usage: remote-setup-controlmaster <remote-name>"
        echo ""
        echo "This command configures SSH ControlMaster for systems requiring password + 2FA."
        echo ""
        echo "Available remotes:"
        list-remotes
        return 1
    fi
    
    # Get remote configuration
    local entry
    entry=$(_rt_get_remote "$remote_name") || {
        _rt_error "Remote '$remote_name' not found in configuration."
        return 1
    }
    
    # Parse entry
    IFS='|' read -r name user host remote_path local_mount <<< "$entry"
    
    echo ""
    echo "${_RT_BOLD}Setting up ControlMaster for: $remote_name${_RT_NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    # Step 1: Test if key-based auth works
    _rt_step 1 4 "Testing key-based authentication..."
    if ssh -o BatchMode=yes -o ConnectTimeout=10 "${user}@${host}" "echo 'SSH OK'" &>/dev/null; then
        _rt_success "Key-based authentication already works!"
        echo ""
        echo "No ControlMaster setup needed. You can mount directly with:"
        echo "  mount-remote $remote_name"
        echo ""
        return 0
    else
        _rt_warn "Key-based auth not available (this is normal for HPC/2FA systems)"
    fi
    
    # Step 2: Check SSH config
    _rt_step 2 4 "Checking SSH configuration..."
    local ssh_config="${HOME}/.ssh/config"
    local controlmaster_configured=false
    local host_entry_exists=false
    local identity_file=""
    
    if [[ -f "$ssh_config" ]]; then
        # Check if Host entry exists
        if grep -q "^Host $host" "$ssh_config" 2>/dev/null || \
           grep -q "^Host .*$host" "$ssh_config" 2>/dev/null; then
            host_entry_exists=true
            _rt_debug "Found existing Host entry for $host"
            
            # Extract IdentityFile if present
            identity_file=$(awk "/^Host.*$host/,/^Host /" "$ssh_config" 2>/dev/null | \
                grep "IdentityFile" | head -1 | awk '{print $2}')
            if [[ -n "$identity_file" ]]; then
                _rt_debug "Found IdentityFile: $identity_file"
            fi
            
            # Check if ControlMaster is already configured
            if grep -A 10 "^Host.*$host" "$ssh_config" 2>/dev/null | \
               grep -q "ControlMaster"; then
                controlmaster_configured=true
                _rt_success "ControlMaster already configured"
            fi
        fi
    fi
    
    if [[ "$controlmaster_configured" == "true" ]]; then
        echo ""
        echo "${_RT_BOLD}ControlMaster is already configured!${_RT_NC}"
        echo ""
        echo "Next steps:"
        echo "  1. Run: ssh $host  (enter password + 2FA)"
        echo "  2. Keep that terminal open"
        echo "  3. Run: mount-remote $remote_name"
        echo ""
        return 0
    fi
    
    # Step 3: Auto-configure SSH config
    _rt_step 3 4 "Configuring SSH ControlMaster..."
    
    # Determine IdentityFile to use
    if [[ -z "$identity_file" ]]; then
        # Check for common key files
        if [[ -f "${HOME}/.ssh/id_rsa" ]]; then
            identity_file="~/.ssh/id_rsa"
        elif [[ -f "${HOME}/.ssh/id_ed25519" ]]; then
            identity_file="~/.ssh/id_ed25519"
        elif [[ -f "${HOME}/.ssh/id_ecdsa" ]]; then
            identity_file="~/.ssh/id_ecdsa"
        fi
    fi
    
    # Ensure .ssh directory exists
    if [[ ! -d "${HOME}/.ssh" ]]; then
        mkdir -p "${HOME}/.ssh"
        chmod 700 "${HOME}/.ssh"
    fi
    
    # Ensure sockets directory exists
    if [[ ! -d "${HOME}/.ssh/sockets" ]]; then
        mkdir -p "${HOME}/.ssh/sockets"
        chmod 700 "${HOME}/.ssh/sockets"
    fi
    
    # Backup existing config
    if [[ -f "$ssh_config" ]]; then
        cp "$ssh_config" "${ssh_config}.backup.$(date +%Y%m%d_%H%M%S)"
        _rt_debug "Backed up existing SSH config"
    fi
    
    # Add or update SSH config
    if [[ "$host_entry_exists" == "true" ]]; then
        # Update existing entry
        _rt_debug "Updating existing Host entry"
        
        # Create temporary file with updated config
        local temp_config="${ssh_config}.tmp"
        
        # Use sed to add ControlMaster settings after the Host line
        awk -v host="$host" -v idfile="$identity_file" '
            /^Host/ { in_host = 0 }
            /^Host.*\yhost\y/ || /^Host host$/ { in_host = 1 }
            in_host && /^Host/ {
                print
                if (idfile != "" && system("grep -q IdentityFile " host) != 0) {
                    print "    IdentityFile " idfile
                }
                print "    ControlMaster auto"
                print "    ControlPath ~/.ssh/sockets/%r@%h:%p"
                print "    ControlPersist 8h"
                next
            }
            { print }
        ' "$ssh_config" > "$temp_config" 2>/dev/null || {
            # Fallback: append new entry
            _rt_warn "Could not update existing entry, will create new Host alias"
        }
        
        if [[ -f "$temp_config" && -s "$temp_config" ]]; then
            mv "$temp_config" "$ssh_config"
        fi
    else
        # Create new Host entry
        _rt_log "Creating new SSH config entry for $host"
        
        {
            echo ""
            echo "# Added by opencode-sshfs for $remote_name"
            if [[ "$name" != "$host" ]]; then
                echo "Host $name $host"
            else
                echo "Host $host"
            fi
            echo "    HostName $host"
            echo "    User $user"
            if [[ -n "$identity_file" ]]; then
                echo "    IdentityFile $identity_file"
            fi
            echo "    ControlMaster auto"
            echo "    ControlPath ~/.ssh/sockets/%r@%h:%p"
            echo "    ControlPersist 8h"
        } >> "$ssh_config"
    fi
    
    chmod 600 "$ssh_config"
    _rt_success "SSH configuration updated"
    
    # Step 4: Guide user through setup
    _rt_step 4 4 "Setup complete!"
    echo ""
    echo "${_RT_BOLD}Next steps:${_RT_NC}"
    echo ""
    echo "${_RT_YELLOW}IMPORTANT:${_RT_NC} You need to establish the master SSH connection."
    echo ""
    echo "  ${_RT_BOLD}Step 1:${_RT_NC} Open a new terminal and run:"
    echo "    ssh $host"
    echo ""
    echo "  ${_RT_BOLD}Step 2:${_RT_NC} Enter your password + 2FA when prompted"
    echo ""
    echo "  ${_RT_BOLD}Step 3:${_RT_NC} ${_RT_GREEN}Keep that terminal open!${_RT_NC}"
    echo ""
    echo "  ${_RT_BOLD}Step 4:${_RT_NC} In this terminal, run:"
    echo "    mount-remote $remote_name"
    echo ""
    echo "${_RT_BOLD}How it works:${_RT_NC}"
    echo "  The first SSH connection (with password/2FA) creates a 'master' connection."
    echo "  SSHFS will reuse this connection, so no more password prompts!"
    echo ""
    echo "${_RT_BOLD}Tips:${_RT_NC}"
    echo "  - Keep the SSH terminal open while using the mount"
    echo "  - The connection persists for 8 hours (ControlPersist setting)"
    echo "  - You can use VS Code SSH to establish the connection too"
    echo ""
    
    return 0
}

# Generate AGENTS.md/CLAUDE.md instructions for remote development
generate-instructions() {
    local remote_name="$1"
    local config_file
    
    config_file=$(_rt_find_config) || {
        _rt_error "Configuration file not found."
        return 1
    }
    
    if [[ -n "$remote_name" ]]; then
        # Generate for specific remote
        local entry
        entry=$(_rt_get_remote "$remote_name") || {
            _rt_error "Remote '$remote_name' not found in configuration."
            return 1
        }
        
        _generate_instructions_for_remote "$entry"
    else
        # Generate for all remotes
        echo "# Remote Development via SSHFS"
        echo ""
        echo "This project uses files mounted from remote servers via SSHFS."
        echo "Files are edited locally but **commands execute on the remote server**."
        echo ""
        
        local first=true
        while IFS='|' read -r name user host remote_path local_mount; do
            # Skip empty lines and comments
            [[ -z "$name" || "$name" =~ ^# ]] && continue
            
            if [[ "$first" == "true" ]]; then
                first=false
            else
                echo ""
                echo "---"
                echo ""
            fi
            
            _generate_instructions_for_remote "$name|$user|$host|$remote_path|$local_mount"
        done < "$config_file"
    fi
}

# Internal helper to detect scheduler type on remote
_rt_detect_scheduler() {
    local name="$1"
    local host="$2"
    local scheduler="unknown"
    
    # Try to detect scheduler by checking which command exists
    # Use a longer timeout and suppress errors
    if ssh -o ConnectTimeout=10 -o BatchMode=yes "$name" "which qstat" &>/dev/null; then
        scheduler="pbs"
    elif ssh -o ConnectTimeout=10 -o BatchMode=yes "$name" "which squeue" &>/dev/null; then
        scheduler="slurm"
    else
        # Fallback: infer from known HPC host patterns
        # NCAR systems (derecho, casper) use PBS
        if [[ "$host" == *".hpc.ucar.edu"* ]] || [[ "$host" == "derecho" ]] || [[ "$host" == "casper" ]]; then
            scheduler="pbs"
        fi
    fi
    
    echo "$scheduler"
}

# Internal helper to generate instructions for a single remote
_generate_instructions_for_remote() {
    local entry="$1"
    IFS='|' read -r name user host remote_path local_mount <<< "$entry"
    
    local expanded_mount="$(_rt_expand_path "$local_mount")"
    local expanded_remote="$(_rt_expand_path "$remote_path")"
    
    # Detect scheduler
    local scheduler=$(_rt_detect_scheduler "$name" "$host")
    local scheduler_name=""
    local job_submit_cmd=""
    local job_queue_cmd=""
    local job_cancel_cmd=""
    local scheduler_note=""
    
    if [[ "$scheduler" == "pbs" ]]; then
        scheduler_name="PBS Pro"
        job_submit_cmd="qsub"
        job_queue_cmd="qstat -u $user"
        job_cancel_cmd="qdel"
        scheduler_note="PBS Pro job scheduler detected"
    elif [[ "$scheduler" == "slurm" ]]; then
        scheduler_name="Slurm"
        job_submit_cmd="sbatch"
        job_queue_cmd="squeue -u $user"
        job_cancel_cmd="scancel"
        scheduler_note="Slurm job scheduler detected"
    else
        scheduler_name="Unknown"
        job_submit_cmd="<scheduler-submit-command>"
        job_queue_cmd="<scheduler-queue-command>"
        job_cancel_cmd="<scheduler-cancel-command>"
        scheduler_note="Could not detect job scheduler (SSH may require authentication)"
    fi
    
    cat <<EOF
## Important: Remote File System

**Setup:** This project is mounted from \`$name\` ($user@$host) via SSHFS.

**Your constraints:**
- You have full read/write access to files (treat as local)
- You CANNOT execute commands locally - they won't work or will use wrong environment
- You MUST use SSH for: running scripts, submitting jobs, checking remote-only paths, loading modules

**Quick check:** Before running any command, ask: "Does this need the remote environment?" If yes, use \`ssh $name "..."\`

---

## Remote: $name

**Connection Details:**

| Item | Value |
|------|-------|
| Remote Host | \`$host\` |
| Remote User | \`$user\` |
| Local Mount Point | \`$expanded_mount\` |
| Actual Remote Path | \`$expanded_remote\` |
| Job Scheduler | ${scheduler_name}${scheduler:+ ($scheduler_note)} |

### How to Execute Remote Operations

Since the local filesystem is just a mount, use SSH for any operations that depend on the remote environment:

\`\`\`bash
# List files on $name (including paths not mounted)
ssh $name "ls -la /some/path"

# Check if a file exists
ssh $name "test -f /path/to/file && echo 'exists' || echo 'not found'"

# Run a shell script
ssh $name "bash $expanded_remote/scripts/process.sh"

# Check job queue (HPC system)
ssh $name "$job_queue_cmd"

# Submit a job (HPC system)
ssh $name "$job_submit_cmd $expanded_remote/jobs/myjob.slurm"

# Cancel a job (HPC system)
ssh $name "$job_cancel_cmd <job-id>"

# Load modules and run command (HPC system)
ssh $name "module load python && python $expanded_remote/script.py"
\`\`\`

### When to Use SSH vs Local

| Use Local (direct access) | Use SSH (remote execution) |
|---------------------------|----------------------------|
| Reading/editing mounted files | Listing paths outside the mount |
| Git operations | Checking if remote files exist |
| Viewing file contents | Submitting Slurm jobs |
| | Running scripts that need HPC modules/environment |
| | Any command requiring the remote environment |

### Path Translation

When working with this remote:
- **Local path (SSHFS):** \`$expanded_mount/subdir/file\`
- **Remote path (SSH):** \`$expanded_remote/subdir/file\`

### Important Notes

- SSH to \`$name\` is **passwordless** (SSH keys + ControlMaster configured)
- Always use the full remote path (e.g., \`$expanded_remote/...\`) in SSH commands
- For HPC systems: Slurm commands, module loads, and other cluster-specific tools should be run via SSH
- The local mount only provides file access; execution happens on the remote server
EOF
}

# ============================================================================
# Initialization
# ============================================================================

# Only show init message if sourced interactively
if [[ -n "$PS1" ]]; then
    _rt_debug "remote-tools.sh loaded from ${REMOTE_TOOLS_DIR}"
fi
