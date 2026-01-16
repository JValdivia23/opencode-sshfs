# Installation Guide

Complete installation instructions for opencode-sshfs on macOS.

## Prerequisites

### 1. Homebrew

Homebrew is the package manager for macOS. If you don't have it installed:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

Verify installation:

```bash
brew --version
```

### 2. macFUSE

macFUSE allows macOS to mount non-native filesystems like SSHFS.

```bash
brew install --cask macfuse
```

**Important Notes:**
- You may need to restart your computer after installation
- On first use, you may need to allow the kernel extension in **System Settings > Privacy & Security**
- If prompted, click "Allow" for the macFUSE system extension

### 3. SSHFS

```bash
brew install sshfs
```

Verify installation:

```bash
sshfs --version
```

## Installation Steps

### Step 1: Clone the Repository

```bash
git clone https://github.com/JValdivia23/opencode-sshfs.git
cd opencode-sshfs
```

Or download and extract the ZIP file from GitHub.

### Step 2: Run the Installer

```bash
chmod +x install.sh
./install.sh
```

The installer will:
1. Verify you're on macOS
2. Check for Homebrew, macFUSE, and sshfs
3. Offer to install missing dependencies
4. Create the `~/mounts` directory
5. Create the `~/.ssh/sockets` directory
6. Copy `remotes.conf.example` to `remotes.conf`
7. Add the source line to your shell configuration

### Step 3: Configure Your Shell

If the installer didn't automatically add the source line, add it manually:

**For zsh (default on modern macOS):**
```bash
echo 'source "/path/to/opencode-sshfs/remote-tools.sh"' >> ~/.zshrc
source ~/.zshrc
```

**For bash:**
```bash
echo 'source "/path/to/opencode-sshfs/remote-tools.sh"' >> ~/.bashrc
source ~/.bashrc
```

### Step 4: Configure Your Remotes

Edit `remotes.conf` to add your remote systems:

```bash
nano remotes.conf
```

See [Adding Remotes](adding-remotes.md) for detailed configuration instructions.

### Step 5: Verify Installation

```bash
# Show help
remote-help

# List configured remotes
list-remotes

# Validate configuration
remote-validate
```

## SSH Configuration (Recommended)

For the best experience with password and 2FA authentication, configure SSH ControlMaster.

### Create SSH Sockets Directory

This should already be done by the installer, but verify:

```bash
mkdir -p ~/.ssh/sockets
chmod 700 ~/.ssh/sockets
```

### Configure ControlMaster

Edit `~/.ssh/config`:

```bash
nano ~/.ssh/config
```

Add an entry for each remote system:

```
Host casper
    HostName casper.hpc.ucar.edu
    User yourusername
    ControlMaster auto
    ControlPath ~/.ssh/sockets/%r@%h:%p
    ControlPersist 8h

Host derecho
    HostName derecho.hpc.ucar.edu
    User yourusername
    ControlMaster auto
    ControlPath ~/.ssh/sockets/%r@%h:%p
    ControlPersist 8h
```

### How ControlMaster Works

1. **First SSH connection**: You authenticate with password + 2FA
2. **Control socket created**: SSH creates a socket file in `~/.ssh/sockets/`
3. **Subsequent connections**: SSH reuses the existing socket (no re-authentication)
4. **ControlPersist 8h**: The socket stays active for 8 hours after the last connection closes

### Workflow with ControlMaster

```bash
# Terminal 1: Establish master connection
ssh casper
# Enter password + 2FA
# Leave this terminal open

# Terminal 2: Mount uses existing connection (no password prompt!)
mount-remote casper
cd ~/mounts/casper
opencode .
```

## Troubleshooting Installation

### macFUSE Not Loading

If you see errors about macFUSE not being loaded:

1. Check System Settings > Privacy & Security
2. Look for a message about blocked system software
3. Click "Allow" for macFUSE
4. Restart your computer

### sshfs Command Not Found

If `sshfs` isn't found after installation:

```bash
# Check if it's installed
brew list sshfs

# Try reinstalling
brew reinstall sshfs

# Check your PATH
echo $PATH
```

### Permission Denied on Mount

If you get permission errors when mounting:

```bash
# Ensure the mount directory exists
mkdir -p ~/mounts/remotename

# Check permissions
ls -la ~/mounts/
```

## Uninstallation

To remove opencode-sshfs:

1. Remove the source line from your shell configuration (`~/.zshrc` or `~/.bashrc`)
2. Delete the repository directory
3. Optionally remove sshfs and macFUSE:

```bash
brew uninstall sshfs
brew uninstall --cask macfuse
```

## Next Steps

- [Usage Guide](usage.md) - Learn all the commands
- [Adding Remotes](adding-remotes.md) - Configure your remote systems
- [Troubleshooting](troubleshooting.md) - Common issues and solutions
