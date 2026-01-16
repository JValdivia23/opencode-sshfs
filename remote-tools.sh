#!/bin/bash
# ============================================================================
# remote-tools.sh - SSHFS mount utilities for remote development with OpenCode
# Version: 0.1.0
# https://github.com/JValdivia23/opencode-sshfs
# ============================================================================

# Configuration
REMOTE_TOOLS_VERSION="0.1.0"
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
        echo "  brew install macfuse sshfs"
        echo ""
        echo "Note: You may need to restart your computer after installing macFUSE."
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
  list-remotes              List all configured remote systems
  mount-remote <name>       Mount a remote filesystem via sshfs
  umount-remote <name>      Unmount a remote filesystem
  remote-status             Show mount status of all remotes
  remote-ssh <name>         SSH into a configured remote
  remote-health <name>      Test connectivity to a remote
  remote-validate           Validate the configuration file
  remote-version            Show version information
  remote-help               Show this help message

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

# ============================================================================
# Initialization
# ============================================================================

# Only show init message if sourced interactively
if [[ -n "$PS1" ]]; then
    _rt_debug "remote-tools.sh loaded from ${REMOTE_TOOLS_DIR}"
fi
