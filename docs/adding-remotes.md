# Adding Remote Systems

Guide to configuring new remote systems in opencode-sshfs.

## Configuration File Location

The configuration file `remotes.conf` should be in the same directory as `remote-tools.sh`. It's created automatically when you run `install.sh` by copying from `remotes.conf.example`.

## Configuration Format

Each remote is defined on a single line with 5 pipe-separated fields:

```
NAME|USER|HOST|REMOTE_PATH|LOCAL_MOUNT
```

| Field | Description | Example |
|-------|-------------|---------|
| `NAME` | Short identifier (alphanumeric, `_`, `-`) | `casper`, `lab_server`, `aws-dev` |
| `USER` | Your username on the remote system | `jdoe`, `ubuntu`, `admin` |
| `HOST` | Hostname or IP address | `casper.hpc.ucar.edu`, `192.168.1.100` |
| `REMOTE_PATH` | Absolute path on the remote | `/glade/work/jdoe`, `/home/ubuntu` |
| `LOCAL_MOUNT` | Local mount point | `~/mounts/casper`, `~/mounts/aws` |

## Step-by-Step: Adding a New Remote

### Step 1: Gather Information

Before adding a remote, collect this information:

1. **SSH access**: Can you SSH to the server?
   ```bash
   ssh username@hostname.example.com
   ```

2. **Working directory**: What path do you want to mount?
   ```bash
   # On the remote, run:
   pwd
   # Example: /home/jdoe/projects
   ```

3. **Username**: What's your username on that system?
   ```bash
   # On the remote, run:
   whoami
   ```

### Step 2: Test SSH Connection

Before adding to config, verify SSH works:

```bash
ssh username@hostname.example.com
```

If this fails, fix SSH access first (check credentials, VPN, etc.).

### Step 3: Add to Configuration

Edit `remotes.conf`:

```bash
nano /path/to/opencode-sshfs/remotes.conf
```

Add a new line:

```
myserver|jdoe|server.example.com|/home/jdoe/projects|~/mounts/myserver
```

### Step 4: Validate Configuration

```bash
remote-validate
```

You should see:
```
[OK] Line X: myserver (jdoe@server.example.com)
```

### Step 5: Test Health

```bash
remote-health myserver
```

### Step 6: Mount and Verify

```bash
mount-remote myserver
ls ~/mounts/myserver
```

## Examples by Server Type

### HPC Cluster (NCAR Casper)

```
casper|jairovp|casper.hpc.ucar.edu|/glade/work/jairovp|~/mounts/casper
```

**SSH Config (recommended):**
```
Host casper
    HostName casper.hpc.ucar.edu
    User jairovp
    ControlMaster auto
    ControlPath ~/.ssh/sockets/%r@%h:%p
    ControlPersist 8h
```

### HPC Cluster (NCAR Derecho)

```
derecho|jairovp|derecho.hpc.ucar.edu|/glade/derecho/scratch/jairovp|~/mounts/derecho
```

### University HPC (CU Boulder CURC)

```
curc|jodo1234|login.rc.colorado.edu|/projects/jodo1234/work|~/mounts/curc
```

### Lab Server

```
lab|researcher|lab.department.edu|/data/researcher/experiments|~/mounts/lab
```

### AWS EC2 Instance

```
aws_dev|ubuntu|ec2-12-34-56-78.compute-1.amazonaws.com|/home/ubuntu/app|~/mounts/aws
```

**Note:** For AWS, ensure your security group allows SSH (port 22).

### DigitalOcean Droplet

```
droplet|root|123.45.67.89|/var/www/mysite|~/mounts/droplet
```

### Home Server / Raspberry Pi

```
homepi|pi|192.168.1.100|/home/pi/projects|~/mounts/homepi
```

**Note:** Use a static IP or hostname for local servers.

### Cloud VM (Google Cloud)

```
gcp|myuser|35.123.45.67|/home/myuser/workspace|~/mounts/gcp
```

## Using Variables

You can use `$USER` in the remote path if your local and remote usernames match:

```
myserver|$USER|server.example.com|/home/$USER/projects|~/mounts/myserver
```

The `~` in local mount paths automatically expands to your home directory.

## Multiple Remotes on Same Host

You can have multiple entries for the same host with different paths:

```
# Main work directory
casper_work|jdoe|casper.hpc.ucar.edu|/glade/work/jdoe|~/mounts/casper_work

# Scratch space
casper_scratch|jdoe|casper.hpc.ucar.edu|/glade/scratch/jdoe|~/mounts/casper_scratch

# Shared project
casper_project|jdoe|casper.hpc.ucar.edu|/glade/p/PROJECT123|~/mounts/casper_project
```

## SSH Config Integration

For the best experience, add entries to `~/.ssh/config`:

```
Host casper
    HostName casper.hpc.ucar.edu
    User jdoe
    ControlMaster auto
    ControlPath ~/.ssh/sockets/%r@%h:%p
    ControlPersist 8h
    ServerAliveInterval 60
    ServerAliveCountMax 3
```

Then in `remotes.conf`, you can use the alias:

```
casper|jdoe|casper|/glade/work/jdoe|~/mounts/casper
```

Note: The HOST field matches the `Host` alias in SSH config.

## Troubleshooting New Remotes

### "Permission denied" when mounting

1. Test SSH access:
   ```bash
   ssh user@host
   ```

2. Verify the remote path exists:
   ```bash
   ssh user@host "ls -la /path/to/directory"
   ```

### "No such file or directory" for remote path

The path may not exist. Create it first:
```bash
ssh user@host "mkdir -p /path/to/directory"
```

### Slow connection

For high-latency connections, add compression to `~/.ssh/config`:
```
Host myremote
    Compression yes
```

### 2FA prompts every time

Set up ControlMaster (see SSH Config Integration above), then:
1. Open SSH connection in one terminal
2. Mount in another terminal (no password prompt!)

## Removing a Remote

Simply delete or comment out the line in `remotes.conf`:

```
# Commented out - not currently using
# oldserver|jdoe|old.example.com|/home/jdoe|~/mounts/oldserver
```

Then verify:
```bash
list-remotes  # Should not show the removed remote
```

## Sharing Configurations

Your `remotes.conf` contains usernames and paths that are specific to you. To share a team configuration:

1. Create a `remotes.conf.team` with placeholders:
   ```
   # Team remotes - copy to remotes.conf and fill in your username
   casper|YOUR_USERNAME|casper.hpc.ucar.edu|/glade/work/YOUR_USERNAME|~/mounts/casper
   ```

2. Each team member copies and customizes:
   ```bash
   cp remotes.conf.team remotes.conf
   sed -i '' 's/YOUR_USERNAME/jdoe/g' remotes.conf
   ```
