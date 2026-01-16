# Usage Guide

Complete reference for all opencode-sshfs commands.

## Commands Overview

| Command | Description |
|---------|-------------|
| `list-remotes` | List all configured remote systems |
| `mount-remote <name>` | Mount a remote filesystem |
| `umount-remote <name>` | Unmount a remote filesystem |
| `remote-status` | Show which remotes are mounted |
| `remote-ssh <name>` | SSH into a configured remote |
| `remote-health <name>` | Test connectivity to a remote |
| `remote-validate` | Validate your configuration file |
| `remote-version` | Show version information |
| `remote-help` | Show help and all commands |

## Detailed Command Reference

### list-remotes

Display all configured remote systems from your `remotes.conf` file.

```bash
list-remotes
```

**Output:**
```
[remote-tools] Configuration: /path/to/remotes.conf

NAME            USER@HOST            REMOTE PATH                    LOCAL MOUNT
--------------- -------------------- ------------------------------ -------------------------
casper          jdoe@casper.ucar.edu /glade/work/jdoe               ~/mounts/casper [mounted]
derecho         jdoe@derecho.ucar.edu /glade/derecho/scratch/jdoe   ~/mounts/derecho
lab             john@lab.university.edu /data/john/projects          ~/mounts/lab
```

The `[mounted]` indicator shows which remotes are currently active.

---

### mount-remote

Mount a remote filesystem via SSHFS.

```bash
mount-remote <name> [options]
```

**Options:**
- `-v, --verbose`: Enable debug output

**Example:**
```bash
mount-remote casper
```

**Output:**
```
[1/4] Checking mount point...
[OK] Mount point ready: /Users/you/mounts/casper
[2/4] Checking SSH configuration...
[OK] SSH configuration ready
[3/4] Connecting to jdoe@casper.hpc.ucar.edu...

  You may be prompted for password and/or 2FA.

[4/4] Verifying mount...
[OK] Mounted successfully!

Next steps:
  cd /Users/you/mounts/casper
  opencode .

To disconnect later: umount-remote casper
```

**Verbose Mode:**
```bash
mount-remote casper --verbose
```

This shows additional debug information useful for troubleshooting.

---

### umount-remote

Safely unmount a remote filesystem.

```bash
umount-remote <name> [options]
```

**Options:**
- `-f, --force`: Force unmount even if busy

**Example:**
```bash
umount-remote casper
```

**Force Unmount:**

If a normal unmount fails (e.g., files are open), use force:

```bash
umount-remote casper --force
```

**Warning:** Force unmounting while files are open may cause data loss.

---

### remote-status

Show the mount status of all configured remotes.

```bash
remote-status
```

**Output:**
```
REMOTE          STATUS       MOUNT POINT
--------------- ------------ ------------------------------
casper          mounted      /Users/you/mounts/casper
derecho         not mounted  /Users/you/mounts/derecho
lab             mounted      /Users/you/mounts/lab
```

---

### remote-ssh

SSH into a configured remote, automatically changing to the configured working directory.

```bash
remote-ssh <name>
```

**Example:**
```bash
remote-ssh casper
```

This is equivalent to:
```bash
ssh -t jdoe@casper.hpc.ucar.edu "cd /glade/work/jdoe && exec $SHELL -l"
```

---

### remote-health

Test connectivity to a remote system without mounting.

```bash
remote-health <name>
```

**Example:**
```bash
remote-health casper
```

**Output:**
```
Health check for: casper
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

[1/4] Testing network connectivity to casper.hpc.ucar.edu...
[OK] Host is reachable
[2/4] Testing SSH port (22)...
[OK] SSH port is open
[3/4] Testing SSH authentication (may prompt for password/2FA)...
[WARN] Key-based auth not available (password/2FA required for mount)
[4/4] Testing remote path (may prompt for password/2FA)...
[OK] Remote path exists: /glade/work/jdoe

Summary:
  Host: jdoe@casper.hpc.ucar.edu
  Remote path: /glade/work/jdoe
  Local mount: /Users/you/mounts/casper
```

---

### remote-validate

Check your configuration file for errors.

```bash
remote-validate
```

**Example Output (valid):**
```
[remote-tools] Validating configuration: /path/to/remotes.conf

[OK] Line 5: casper (jdoe@casper.hpc.ucar.edu)
[OK] Line 6: derecho (jdoe@derecho.hpc.ucar.edu)

[OK] Configuration valid! Found 2 remote(s).
```

**Example Output (errors):**
```
[remote-tools] Validating configuration: /path/to/remotes.conf

[ERROR] Line 5: Expected 5 fields, found 4
       casper|jdoe|casper.hpc.ucar.edu|/glade/work/jdoe
[OK] Line 6: derecho (jdoe@derecho.hpc.ucar.edu)

[ERROR] Found 1 error(s) in configuration.
```

---

### remote-version

Show version information.

```bash
remote-version
```

**Output:**
```
opencode-sshfs v0.1.0
Remote development tools for OpenCode
https://github.com/JValdivia23/opencode-sshfs
```

---

### remote-help

Show help information with all available commands.

```bash
remote-help
```

---

## Environment Variables

| Variable | Description |
|----------|-------------|
| `REMOTE_TOOLS_CONFIG` | Path to a custom configuration file |
| `REMOTE_TOOLS_VERBOSE` | Set to `1` for debug output |

**Examples:**

```bash
# Use a custom config file
REMOTE_TOOLS_CONFIG=~/my-remotes.conf mount-remote myserver

# Enable verbose mode globally
export REMOTE_TOOLS_VERBOSE=1
mount-remote myserver
```

---

## Typical Workflows

### Daily Development Workflow

```bash
# Morning: Start your session
ssh casper                    # Authenticate once (password + 2FA)
# Keep this terminal open

# In a new terminal: Mount and edit
mount-remote casper
cd ~/mounts/casper/myproject
opencode .

# In the SSH terminal: Run your code
cd myproject
python train_model.py
sbatch job.slurm

# Evening: Clean up
umount-remote casper
```

### Working with Multiple Remotes

```bash
# Mount several remotes
mount-remote casper
mount-remote derecho
mount-remote lab

# Check what's mounted
remote-status

# Work on different projects
cd ~/mounts/casper/project1 && opencode .
cd ~/mounts/lab/experiment2 && opencode .

# Clean up all
umount-remote casper
umount-remote derecho
umount-remote lab
```

### Quick File Check

```bash
# Just need to check some files quickly
mount-remote casper
ls ~/mounts/casper/results/
cat ~/mounts/casper/results/output.log
umount-remote casper
```

### Pre-flight Check Before Long Session

```bash
# Verify connectivity before starting work
remote-health casper

# If all looks good, proceed
mount-remote casper
```

---

## Tips and Best Practices

### 1. Keep an SSH Session Open

With ControlMaster configured, keeping one SSH session open prevents repeated authentication:

```bash
# Terminal 1: Keep this open
ssh casper

# Terminal 2+: Mount and work (no password prompts!)
mount-remote casper
```

### 2. Use `remote-status` Frequently

Before mounting or after reconnecting, check what's already mounted:

```bash
remote-status
```

### 3. Always Unmount Before Disconnecting

Avoid "stale file handle" errors by unmounting before your network changes:

```bash
umount-remote casper
# Now safe to close laptop lid, change networks, etc.
```

### 4. Use Verbose Mode for Debugging

If something isn't working:

```bash
mount-remote casper --verbose
```

### 5. Validate After Editing Config

After modifying `remotes.conf`, verify it's correct:

```bash
remote-validate
```
