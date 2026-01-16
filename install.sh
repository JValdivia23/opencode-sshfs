#!/bin/bash
# ============================================================================
# install.sh - Installation helper for opencode-sshfs
# Version: 0.1.0
# ============================================================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ============================================================================
# Helper Functions
# ============================================================================

print_banner() {
    echo ""
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}        ${BOLD}opencode-sshfs${NC} - Remote Development Tools             ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}        Edit locally with OpenCode, files live remotely        ${CYAN}║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

print_step() {
    echo ""
    echo -e "${BOLD}${BLUE}Step $1: $2${NC}"
    echo -e "${BLUE}────────────────────────────────────────${NC}"
}

print_ok() {
    echo -e "  ${GREEN}✓${NC} $1"
}

print_warn() {
    echo -e "  ${YELLOW}!${NC} $1"
}

print_error() {
    echo -e "  ${RED}✗${NC} $1"
}

print_info() {
    echo -e "  ${CYAN}→${NC} $1"
}

print_cmd() {
    echo -e "    ${BOLD}$1${NC}"
}

ask_yes_no() {
    local prompt="$1"
    local default="${2:-n}"
    local answer
    
    if [[ "$default" == "y" ]]; then
        prompt="$prompt [Y/n]: "
    else
        prompt="$prompt [y/N]: "
    fi
    
    read -r -p "$prompt" answer
    answer="${answer:-$default}"
    
    [[ "$answer" =~ ^[Yy] ]]
}

# ============================================================================
# System Checks
# ============================================================================

check_os() {
    print_step 1 "Checking System"
    
    if [[ "$(uname)" != "Darwin" ]]; then
        print_error "This installer is for macOS only."
        print_info "For Linux, install sshfs via your package manager and source remote-tools.sh manually."
        exit 1
    fi
    
    local macos_version
    macos_version=$(sw_vers -productVersion)
    print_ok "macOS $macos_version detected"
}

check_homebrew() {
    print_step 2 "Checking Homebrew"
    
    if command -v brew &> /dev/null; then
        print_ok "Homebrew is installed"
        return 0
    else
        print_warn "Homebrew is not installed"
        echo ""
        print_info "Homebrew is required to install sshfs. Install it with:"
        print_cmd '/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
        echo ""
        
        if ask_yes_no "Would you like to open the Homebrew website for instructions?"; then
            open "https://brew.sh"
        fi
        
        return 1
    fi
}

check_macfuse() {
    print_step 3 "Checking macFUSE"
    
    # Check if macFUSE is installed
    if [[ -d "/Library/Filesystems/macfuse.fs" ]] || brew list --cask macfuse &>/dev/null 2>&1; then
        print_ok "macFUSE is installed"
        return 0
    else
        print_warn "macFUSE is not installed"
        echo ""
        print_info "macFUSE is required for sshfs. Install it with:"
        print_cmd "brew install --cask macfuse"
        echo ""
        print_info "${YELLOW}Note:${NC} You may need to restart your computer after installation."
        print_info "${YELLOW}Note:${NC} You may need to allow the kernel extension in System Settings > Privacy & Security."
        echo ""
        
        if ask_yes_no "Would you like to install macFUSE now?"; then
            echo ""
            brew install --cask macfuse
            echo ""
            print_warn "Please restart your computer before continuing."
            print_warn "Then run this installer again."
            exit 0
        fi
        
        return 1
    fi
}

check_sshfs() {
    print_step 4 "Checking sshfs"
    
    if command -v sshfs &> /dev/null; then
        print_ok "sshfs is installed"
        return 0
    else
        print_warn "sshfs is not installed"
        echo ""
        print_info "Install sshfs with:"
        print_cmd "brew install sshfs"
        echo ""
        
        if ask_yes_no "Would you like to install sshfs now?"; then
            echo ""
            brew install sshfs
            echo ""
            if command -v sshfs &> /dev/null; then
                print_ok "sshfs installed successfully"
                return 0
            else
                print_error "sshfs installation may have failed"
                return 1
            fi
        fi
        
        return 1
    fi
}

# ============================================================================
# Setup Steps
# ============================================================================

setup_directories() {
    print_step 5 "Setting Up Directories"
    
    # Create mounts directory
    if [[ ! -d "$HOME/mounts" ]]; then
        print_info "Creating ~/mounts directory..."
        mkdir -p "$HOME/mounts"
        print_ok "Created ~/mounts"
    else
        print_ok "~/mounts already exists"
    fi
    
    # Create SSH sockets directory
    if [[ ! -d "$HOME/.ssh/sockets" ]]; then
        print_info "Creating ~/.ssh/sockets directory..."
        mkdir -p "$HOME/.ssh/sockets"
        chmod 700 "$HOME/.ssh/sockets"
        print_ok "Created ~/.ssh/sockets"
    else
        print_ok "~/.ssh/sockets already exists"
    fi
}

setup_config() {
    print_step 6 "Setting Up Configuration"
    
    if [[ -f "${SCRIPT_DIR}/remotes.conf" ]]; then
        print_ok "remotes.conf already exists"
    else
        print_info "Creating remotes.conf from template..."
        cp "${SCRIPT_DIR}/remotes.conf.example" "${SCRIPT_DIR}/remotes.conf"
        print_ok "Created remotes.conf"
        print_warn "Edit remotes.conf to add your remote systems"
    fi
}

setup_shell() {
    print_step 7 "Shell Integration"
    
    local shell_rc=""
    local shell_name=""
    
    if [[ "$SHELL" == *"zsh"* ]]; then
        shell_rc="$HOME/.zshrc"
        shell_name="zsh"
    elif [[ "$SHELL" == *"bash"* ]]; then
        shell_rc="$HOME/.bashrc"
        shell_name="bash"
    else
        shell_rc="$HOME/.profile"
        shell_name="shell"
    fi
    
    local source_line="source \"${SCRIPT_DIR}/remote-tools.sh\""
    
    if grep -q "remote-tools.sh" "$shell_rc" 2>/dev/null; then
        print_ok "Shell integration already configured in $shell_rc"
    else
        print_info "Add this line to your $shell_rc:"
        echo ""
        print_cmd "$source_line"
        echo ""
        
        if ask_yes_no "Would you like to add this automatically?"; then
            echo "" >> "$shell_rc"
            echo "# opencode-sshfs - Remote development tools" >> "$shell_rc"
            echo "$source_line" >> "$shell_rc"
            print_ok "Added to $shell_rc"
            print_info "Run 'source $shell_rc' or restart your terminal to activate"
        else
            print_info "Add the line manually when ready"
        fi
    fi
}

print_ssh_config_help() {
    print_step 8 "SSH Configuration (Optional but Recommended)"
    
    echo ""
    print_info "For better performance with password+2FA, configure SSH ControlMaster."
    print_info "Add entries like this to ~/.ssh/config:"
    echo ""
    echo -e "${BOLD}# Example for a remote system${NC}"
    cat << 'EOF'
Host myserver
    HostName server.example.com
    User myusername
    ControlMaster auto
    ControlPath ~/.ssh/sockets/%r@%h:%p
    ControlPersist 8h
EOF
    echo ""
    print_info "This allows you to authenticate once and reuse the connection."
    print_info "See docs/installation.md for more details."
}

print_next_steps() {
    echo ""
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}                    ${BOLD}Installation Complete!${NC}                      ${CYAN}║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${BOLD}Next Steps:${NC}"
    echo ""
    echo "  1. Edit your configuration file:"
    print_cmd "nano ${SCRIPT_DIR}/remotes.conf"
    echo ""
    echo "  2. Restart your terminal or run:"
    print_cmd "source ${SCRIPT_DIR}/remote-tools.sh"
    echo ""
    echo "  3. List your configured remotes:"
    print_cmd "list-remotes"
    echo ""
    echo "  4. Mount a remote and start working:"
    print_cmd "mount-remote <name>"
    print_cmd "cd ~/mounts/<name>"
    print_cmd "opencode ."
    echo ""
    echo -e "${BOLD}Available Commands:${NC}"
    echo "  list-remotes        - List all configured remotes"
    echo "  mount-remote <name> - Mount a remote filesystem"
    echo "  umount-remote <name>- Unmount a remote filesystem"
    echo "  remote-status       - Show mount status"
    echo "  remote-ssh <name>   - SSH into a remote"
    echo "  remote-health <name>- Test connectivity"
    echo "  remote-help         - Show all commands"
    echo ""
    echo -e "${BOLD}Documentation:${NC}"
    echo "  docs/installation.md  - Detailed setup guide"
    echo "  docs/usage.md         - Command reference"
    echo "  docs/troubleshooting.md - Common issues"
    echo ""
}

# ============================================================================
# Main
# ============================================================================

main() {
    print_banner
    
    check_os
    
    local deps_ok=true
    
    check_homebrew || deps_ok=false
    
    if [[ "$deps_ok" == "true" ]]; then
        check_macfuse || deps_ok=false
    fi
    
    if [[ "$deps_ok" == "true" ]]; then
        check_sshfs || deps_ok=false
    fi
    
    if [[ "$deps_ok" == "false" ]]; then
        echo ""
        print_warn "Some dependencies are missing. Install them and run this script again."
        exit 1
    fi
    
    setup_directories
    setup_config
    setup_shell
    print_ssh_config_help
    print_next_steps
}

main "$@"
