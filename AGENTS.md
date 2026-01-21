# PROJECT KNOWLEDGE BASE

**Generated:** 2026-01-20
**Context:** opencode-sshfs (Bash/SSHFS Remote Dev Tool)

## OVERVIEW
Bash-based utility for remote development with OpenCode using SSHFS. Enables local editing of remote files via user-space mounting. Core stack: Bash, sshfs, macFUSE.

## STRUCTURE
```
.
├── install.sh         # Interactive installer (dependencies, dirs, shell setup)
├── remote-tools.sh    # Core logic (sourced library of functions)
├── remotes.conf       # User config (pipe-delimited) [GitIgnored usually]
├── remotes.conf.example # Template for config
└── docs/              # Detailed markdown documentation
```

## WHERE TO LOOK
| Task | Location | Notes |
|------|----------|-------|
| **Mount/Unmount Logic** | `remote-tools.sh` | See `mount-remote` and `umount-remote` functions |
| **Config Parsing** | `remote-tools.sh` | `_rt_get_remote` and `remote-validate` |
| **Installation Checks** | `install.sh` | Checks Homebrew, macFUSE, sshfs presence |
| **Health Checks** | `remote-tools.sh` | `remote-health` tests DNS, Port 22, Auth |

## CONVENTIONS
- **Execution**: `remote-tools.sh` is intended to be **sourced**, not run directly (provides shell functions).
- **Configuration**: Pipe-delimited text file (`NAME|USER|HOST|PATH|MOUNT`).
- **Dependencies**: Relies on external system tools (`sshfs`, `brew`).
- **OS Support**: Currently macOS specific (checks for Darwin kernel).

## ANTI-PATTERNS (THIS PROJECT)
- **Config Syntax**: DO NOT put spaces around the `|` delimiter in `remotes.conf`.
- **Workflow**: NEVER disconnect network/sleep before running `umount-remote` (causes stale handles).
- **Mounting**: DO NOT manually `mkdir` mount points; the script handles creation.

## COMMANDS
```bash
# Setup
./install.sh

# Load functions (usually in .zshrc/.bashrc)
source remote-tools.sh

# Usage
list-remotes
mount-remote <name>
umount-remote <name>
remote-health <name>
```

## NOTES
- **SSH ControlMaster**: Recommended for 2FA environments to avoid repeated auth prompts.
- **Debug Mode**: Set `REMOTE_TOOLS_VERBOSE=1` or use `-v` flag for detailed logs.
