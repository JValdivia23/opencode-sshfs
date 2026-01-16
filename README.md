# opencode-sshfs

Remote development workflow for [OpenCode](https://opencode.ai) using SSHFS. Edit code locally with OpenCode while your files live on remote servers, HPC clusters, or cloud VMs.

## Why?

When you can't install OpenCode on a remote system (e.g., university supercomputers, shared servers, NAS devices), this tool lets you:

1. **Mount** remote filesystems locally via SSHFS
2. **Edit** files with OpenCode as if they were local
3. **Execute** code on the remote via a separate SSH terminal

## Features

- Simple configuration file for multiple remotes
- SSH ControlMaster support for password+2FA authentication
- Auto-create mount directories
- Connection health checks
- Works with any SSH-accessible server (HPC clusters, NAS, cloud VMs, lab servers)

## Requirements

- macOS (Linux support planned)
- [Homebrew](https://brew.sh)
- [macFUSE](https://osxfuse.github.io/) and sshfs

> **Important:** After installing macFUSE, you may need to allow the kernel extension in **System Settings → Privacy & Security**, then **restart your Mac**.

## Quick Start

### 1. Install dependencies

```bash
brew install --cask macfuse
brew install sshfs
# Restart your Mac if prompted
```

### 2. Clone the repository

```bash
git clone https://github.com/JValdivia23/opencode-sshfs.git
cd opencode-sshfs
```

### 3. Run the installer

```bash
./install.sh
```

The installer will:
- Check for dependencies (Homebrew, macFUSE, sshfs)
- Offer to install missing dependencies
- Create necessary directories
- Guide you through shell configuration

### 3. Configure your remotes

```bash
# Edit the configuration file
nano remotes.conf
```

Add your remote systems:

```
# Format: NAME|USER|HOST|REMOTE_PATH|LOCAL_MOUNT
casper|jdoe|casper.hpc.ucar.edu|/glade/work/jdoe|~/mounts/casper
lab_server|john|lab.university.edu|/data/john/projects|~/mounts/lab
```

### 4. Start working

```bash
# List your configured remotes
list-remotes

# Mount a remote
mount-remote casper

# Navigate and start OpenCode
cd ~/mounts/casper
opencode .
```

### 5. Use the remote normally (in another terminal)

```bash
# SSH to run code, submit jobs, etc.
ssh casper
python my_script.py
sbatch my_job.slurm
```

### 6. Unmount when done

```bash
umount-remote casper
```

## Commands

| Command | Description |
|---------|-------------|
| `list-remotes` | List all configured remote systems |
| `mount-remote <name>` | Mount a remote filesystem |
| `umount-remote <name>` | Unmount a remote filesystem |
| `remote-status` | Show which remotes are mounted |
| `remote-ssh <name>` | SSH into a configured remote |
| `remote-health <name>` | Test connectivity to a remote |
| `remote-validate` | Validate your configuration file |
| `remote-help` | Show help and all commands |

## Configuration

### remotes.conf Format

```
# Lines starting with # are comments
# Format: NAME|USER|HOST|REMOTE_PATH|LOCAL_MOUNT

myserver|username|hostname.example.com|/path/on/remote|~/mounts/myserver
```

### SSH ControlMaster (Recommended for 2FA)

Add this to your `~/.ssh/config` for each remote:

```
Host casper
    HostName casper.hpc.ucar.edu
    User jdoe
    ControlMaster auto
    ControlPath ~/.ssh/sockets/%r@%h:%p
    ControlPersist 8h
```

This allows you to authenticate once and reuse the connection for 8 hours.

## Documentation

- [Installation Guide](docs/installation.md) - Detailed setup instructions
- [Usage Guide](docs/usage.md) - Complete command reference
- [Troubleshooting](docs/troubleshooting.md) - Common issues and solutions
- [Adding Remotes](docs/adding-remotes.md) - How to configure new systems

## Workflow Tips

### Daily Workflow

```bash
# Morning: Establish SSH connection (authenticate once)
ssh casper
# Keep this terminal open

# In another terminal: Mount and work
mount-remote casper
cd ~/mounts/casper
opencode .

# Evening: Clean up
umount-remote casper
```

### Multiple Remotes

```bash
# Mount multiple systems simultaneously
mount-remote casper
mount-remote derecho
mount-remote lab_server

# Check status
remote-status
```

## Limitations

- **Execution happens locally**: OpenCode's bash tool runs on your laptop, not the remote. Use a separate SSH terminal for running code.
- **Network dependent**: Large file operations may be slow over high-latency connections.
- **macOS only**: Linux support is planned for a future release.

## Contributing

Issues and pull requests are welcome! Please see the [GitHub repository](https://github.com/JValdivia23/opencode-sshfs).

## License

MIT License - see [LICENSE](LICENSE) for details.
