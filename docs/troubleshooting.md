# Troubleshooting Guide

Solutions to common issues with opencode-sshfs.

## Quick Diagnostics

Run these commands to diagnose issues:

```bash
# Check if sshfs is installed
which sshfs

# Check what's currently mounted
remote-status

# Validate your configuration
remote-validate

# Test connectivity to a specific remote
remote-health myremote
```

---

## Installation Issues

### "macFUSE not loaded" or "mount_macfuse: kext not loaded"

**Cause:** macFUSE kernel extension is not allowed or not loaded.

**Solution:**
1. Open **System Settings** (or System Preferences on older macOS)
2. Go to **Privacy & Security**
3. Look for a message about blocked system software from "Benjamin Fleischer" or "macFUSE"
4. Click **Allow**
5. Restart your computer

**Note:** On Apple Silicon Macs, you may need to boot into Recovery Mode to enable kernel extensions.

### "sshfs: command not found"

**Cause:** sshfs is not installed or not in PATH.

**Solution:**
```bash
# Install via Homebrew
brew install sshfs

# Verify installation
which sshfs
```

If still not found, ensure Homebrew binaries are in your PATH:
```bash
echo 'export PATH="/usr/local/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc
```

### "brew: command not found"

**Cause:** Homebrew is not installed.

**Solution:**
```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

---

## Connection Issues

### "Connection refused" or "ssh: connect to host X port 22: Connection refused"

**Causes:**
- Remote server is down
- SSH service not running on remote
- Firewall blocking connection
- Wrong hostname

**Solutions:**
1. Verify the hostname is correct in your configuration
2. Test basic connectivity:
   ```bash
   ping hostname.example.com
   nc -zv hostname.example.com 22
   ```
3. Try connecting with regular SSH:
   ```bash
   ssh user@hostname.example.com
   ```
4. Contact system administrator if the server appears down

### "Permission denied (publickey,password)"

**Causes:**
- Wrong username
- Wrong password
- Account locked
- SSH key issues

**Solutions:**
1. Verify your username in `remotes.conf`
2. Test with regular SSH:
   ```bash
   ssh user@hostname.example.com
   ```
3. If using SSH keys, check key permissions:
   ```bash
   chmod 600 ~/.ssh/id_rsa
   chmod 644 ~/.ssh/id_rsa.pub
   ```

### "Connection timed out" during mount

**Causes:**
- Network issues
- Remote server very slow
- 2FA timeout

**Solutions:**
1. Test basic connectivity first:
   ```bash
   remote-health myremote
   ```
2. Try with verbose mode:
   ```bash
   mount-remote myremote --verbose
   ```
3. If 2FA is timing out, establish an SSH connection first:
   ```bash
   # Terminal 1: Authenticate
   ssh myremote
   
   # Terminal 2: Mount (uses existing auth)
   mount-remote myremote
   ```

---

## Mount Issues

### "mountpoint is not empty"

**Cause:** The local mount directory contains files.

**Solution:**
```bash
# Check what's in the directory
ls -la ~/mounts/myremote

# If it's safe, remove contents
rm -rf ~/mounts/myremote/*

# Or use a different mount point in remotes.conf
```

### "X is already mounted"

**Cause:** Previous mount is still active.

**Solution:**
```bash
# First try normal unmount
umount-remote myremote

# If that fails, force unmount
umount-remote myremote --force

# Then mount again
mount-remote myremote
```

### "mount_macfuse: mount point /path/to/mount is itself on a macFUSE volume"

**Cause:** Trying to mount inside an already-mounted SSHFS directory.

**Solution:**
Choose a mount point that's on your local filesystem:
```bash
# Good: Local directory
~/mounts/myremote

# Bad: Inside another mount
~/mounts/remote1/subdir
```

### "Transport endpoint is not connected"

**Cause:** The SSHFS connection was lost (network disconnect, server restart, etc.).

**Solution:**
```bash
# Force unmount the stale connection
umount-remote myremote --force

# Or manually:
diskutil unmount force ~/mounts/myremote

# Then remount
mount-remote myremote
```

---

## Performance Issues

### File operations are very slow

**Causes:**
- High network latency to remote
- Large files
- Many small file operations
- No caching

**Solutions:**

1. **Use SSH compression** (add to `~/.ssh/config`):
   ```
   Host myremote
       Compression yes
   ```

2. **Increase cache timeout** (modify `remote-tools.sh`):
   ```bash
   # Find the sshfs_opts line and add:
   sshfs_opts+=",cache_timeout=300,attr_timeout=300"
   ```

3. **Work with smaller files**: Copy large files locally for processing

4. **Use remote for execution**: Remember that OpenCode's bash tool runs locally. Use a separate SSH terminal for running compute-intensive tasks.

### OpenCode is slow to start in mounted directory

**Cause:** OpenCode scanning many files over the network.

**Solutions:**
1. Mount a more specific subdirectory instead of your entire home
2. Add appropriate entries to `.gitignore` to reduce file scanning
3. Use OpenCode's `--ignore` option if available

---

## Authentication Issues

### Prompted for password/2FA on every operation

**Cause:** SSH ControlMaster not configured.

**Solution:**
Add ControlMaster to your `~/.ssh/config`:
```
Host myremote
    HostName hostname.example.com
    User myusername
    ControlMaster auto
    ControlPath ~/.ssh/sockets/%r@%h:%p
    ControlPersist 8h
```

Then establish a master connection:
```bash
ssh myremote  # Keep this terminal open
```

### "ControlPath too long"

**Cause:** The socket path exceeds system limits (usually ~100 characters).

**Solution:**
Use a shorter ControlPath:
```
Host myremote
    ControlPath ~/.ssh/s/%r@%h:%p
```

Or use a hash:
```
Host myremote
    ControlPath ~/.ssh/sockets/%C
```

### 2FA times out before mount completes

**Cause:** sshfs takes too long and the 2FA token expires.

**Solution:**
Establish SSH connection first, then mount:
```bash
# Terminal 1
ssh myremote

# Terminal 2
mount-remote myremote
```

---

## Unmount Issues

### "Resource busy" when unmounting

**Cause:** Files are open or processes are using the mount.

**Solutions:**
1. Close all files in the mounted directory
2. Make sure you're not `cd`'d into the mount:
   ```bash
   cd ~
   umount-remote myremote
   ```
3. Check what's using the mount:
   ```bash
   lsof ~/mounts/myremote
   ```
4. Force unmount:
   ```bash
   umount-remote myremote --force
   ```

### Unmount hangs

**Cause:** Network connection lost, mount is unresponsive.

**Solution:**
```bash
# Force unmount on macOS
diskutil unmount force ~/mounts/myremote

# Or use the macOS lazy unmount
umount -f ~/mounts/myremote
```

---

## Configuration Issues

### "Remote 'X' not found in configuration"

**Cause:** The remote name doesn't match any entry in `remotes.conf`.

**Solutions:**
1. Check exact spelling and case:
   ```bash
   list-remotes
   ```
2. Verify `remotes.conf` exists:
   ```bash
   ls -la $(dirname $(which remote-tools.sh 2>/dev/null || echo .))/remotes.conf
   ```
3. Validate configuration:
   ```bash
   remote-validate
   ```

### "Configuration file not found"

**Cause:** `remotes.conf` doesn't exist in any expected location.

**Solutions:**
1. Copy the example file:
   ```bash
   cp remotes.conf.example remotes.conf
   ```
2. Check the search paths:
   - Same directory as `remote-tools.sh`
   - `~/.config/opencode-sshfs/remotes.conf`
   - `~/remotes.conf`

### Configuration changes not taking effect

**Cause:** Shell hasn't reloaded the configuration.

**Solution:**
```bash
# Reload shell config
source ~/.zshrc

# Or just source the tools directly
source /path/to/remote-tools.sh
```

---

## Getting Help

If you're still stuck:

1. **Enable verbose mode**:
   ```bash
   mount-remote myremote --verbose
   ```

2. **Check the GitHub issues**: [github.com/JValdivia23/opencode-sshfs/issues](https://github.com/JValdivia23/opencode-sshfs/issues)

3. **File a new issue** with:
   - Your macOS version
   - Output of `sshfs --version`
   - The exact error message
   - Steps to reproduce
