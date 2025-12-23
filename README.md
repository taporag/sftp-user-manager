# SFTP User Manager

A flexible, production-safe bash script for managing SFTP-only user accounts with chroot jail isolation on Linux servers.

## Features

- 🔐 **Secure SFTP-only access** - Users are jailed to their home directory with no shell access
- 👥 **Group-based access control** - Single SSHD config block for all SFTP users (no per-user config spam)
- 🔑 **SSH hardening compatible** - Works with global `PasswordAuthentication no`
- 🎯 **No hardcoded values** - Fully configurable via arguments, prompts, or environment variables
- 🔄 **Interactive configuration** - Always shows defaults and lets you override before proceeding
- 🎨 **Colored output** - Clear visual feedback for operations
- ✅ **Idempotent** - Can be run repeatedly without duplicating config
- 🔑 **Auto-generate passwords** - Secure random password generation using OpenSSL

## How It Works

Instead of adding per-user `Match User` blocks to `sshd_config`, this script:

1. Creates a single group (`sftpusers` by default)
2. Adds ONE `Match Group` block to `sshd_config`
3. Adds each SFTP user to the group

This approach is:
- **Maintainable** - No config file bloat
- **Secure** - Enables password auth only for SFTP users
- **Scalable** - Add/remove users without touching SSHD config

## Prerequisites

- Linux server (Ubuntu/Debian recommended)
- Root or sudo access
- OpenSSL (for password generation)
- systemd (for SSH service management)

## Installation

```bash
# Clone the repository
git clone https://github.com/taporag/sftp-user-manager.git

# Navigate to the directory
cd sftp-user-manager

# Make the script executable
chmod +x sftp.sh
```

## Quick Start

### 1. Initial Setup (Run Once)

```bash
sudo ./sftp.sh -setup
```

You'll see the current configuration and can override any settings:

```
=== SFTP Initial Setup ===

Current Configuration (defaults):
  1) Base Directory:   /sftp
  2) SSHD Config:      /etc/ssh/sshd_config
  3) SFTP Group:       sftpusers
  4) Upload Directory: uploads

Would you like to change any of these settings? [y/N]: y

Base directory [/sftp]: /data/sftp
SSHD config path [/etc/ssh/sshd_config]: 
SFTP group name [sftpusers]: mycompany-sftp
Upload directory name [uploads]: 

Final Configuration:
  Base Directory:   /data/sftp
  SSHD Config:      /etc/ssh/sshd_config
  SFTP Group:       mycompany-sftp
  Upload Directory: uploads

This will:
  1. Create the SFTP group 'mycompany-sftp'
  2. Create the base directory '/data/sftp'
  3. Add a Match Group block to '/etc/ssh/sshd_config'

Proceed with setup? [y/N]: y
```

### 2. Add SFTP Users

```bash
sudo ./sftp.sh -add -u john
```

You can override any settings before the user is created:

```
=== Add SFTP User ===

Current Configuration:
  Username:         john
  Base Directory:   /sftp
  SFTP Group:       sftpusers
  Upload Directory: uploads
  Nologin Shell:    /usr/sbin/nologin

Would you like to change any settings? [y/N]: n

Leave password empty to auto-generate
Enter password []: 
📝 Auto-generated password

Final Configuration:
  Username:         john
  SFTP Group:       sftpusers
  Home Directory:   /sftp/john
  Upload Directory: /sftp/john/uploads
  Nologin Shell:    /usr/sbin/nologin

Proceed with creating user? [y/N]: y
```

### 3. Users Connect via SFTP

```bash
sftp john@your-server.com
```

## Usage

### Interactive Mode (Recommended)

Simply run the script without arguments:

```bash
sudo ./sftp.sh
```

You'll see a menu:

```
=== SFTP User Manager ===

Select an action:
  1) Initial setup (run once)
  2) Add user
  3) Delete user
  4) Update password
  5) Exit
```

Every operation shows you the current configuration and asks if you want to change any settings before proceeding.

### Command Line Mode

You can also pass arguments directly. The script will still show the configuration and let you override if needed.

#### Initial Setup

```bash
# With defaults (will prompt to change)
sudo ./sftp.sh -setup

# Pre-set values via arguments
sudo ./sftp.sh -setup -b /data/sftp -g mycompany-sftp
```

#### Add a new SFTP user

```bash
# Basic usage
sudo ./sftp.sh -add -u john

# With pre-set values
sudo ./sftp.sh -add -u john -b /data/sftp -g mycompany-sftp

# With specific password
sudo ./sftp.sh -add -u john -p "MySecurePass123"
```

#### Delete an SFTP user

```bash
# Basic usage
sudo ./sftp.sh -delete -u john

# With custom base directory
sudo ./sftp.sh -delete -u john -b /data/sftp
```

#### Update user password

```bash
# Auto-generate new password
sudo ./sftp.sh -passwd -u john

# Set specific password
sudo ./sftp.sh -passwd -u john -p "NewPassword123"
```

### Options

| Option | Long Form | Default | Description |
|--------|-----------|---------|-------------|
| `-u` | `--username` | *(required)* | Username for SFTP account |
| `-p` | `--password` | *(auto-generated)* | Password for the account |
| `-b` | `--basedir` | `/sftp` | Base directory for SFTP jail |
| `-c` | `--config` | `/etc/ssh/sshd_config` | Path to sshd_config file |
| `-s` | `--shell` | `/usr/sbin/nologin` | Path to nologin shell |
| `-g` | `--group` | `sftpusers` | SFTP users group name |
| `-d` | `--uploaddir` | `uploads` | Upload directory name inside jail |
| `-i` | `--interactive` | `false` | Force full interactive mode |
| `-h` | `--help` | - | Show help message |

### Environment Variables

Override defaults system-wide:

| Variable | Default | Description |
|----------|---------|-------------|
| `SFTP_BASE_DIR` | `/sftp` | Default base directory |
| `SFTP_SSHD_CONFIG` | `/etc/ssh/sshd_config` | Default sshd_config path |
| `SFTP_NOLOGIN_SHELL` | `/usr/sbin/nologin` | Default nologin shell path |
| `SFTP_UPLOAD_DIR` | `uploads` | Default upload directory name |
| `SFTP_GROUP` | `sftpusers` | Default SFTP users group |

Example:

```bash
export SFTP_BASE_DIR="/data/sftp"
export SFTP_GROUP="company-sftp"
sudo -E ./sftp.sh -add -u john
```

## Directory Structure

When you create an SFTP user, the following structure is created:

```
/sftp/                      # Base directory (root:root, 755)
└── john/                   # User's chroot jail (root:root, 755)
    └── uploads/            # User's writable directory (john:john, 755)
```

The SSHD `ChrootDirectory` uses the pattern `/sftp/%u`, where `%u` is replaced with the username.

## SSHD Configuration

After running `-setup`, your `sshd_config` will contain:

```
# SFTP group config (sftpusers)
Match Group sftpusers
    ChrootDirectory /sftp/%u
    ForceCommand internal-sftp -d uploads
    PasswordAuthentication yes
    PermitTunnel no
    AllowAgentForwarding no
    AllowTcpForwarding no
    X11Forwarding no
```

### Recommended Global SSHD Hardening

Your global `sshd_config` should have:

```
PermitRootLogin no
PasswordAuthentication no
```

The `Match Group` block re-enables password authentication **only** for SFTP users.
Admin SSH access remains key-only.

## Security Considerations

- ✅ Users are completely isolated in their chroot jail
- ✅ No shell access is possible (even if attempted)
- ✅ Users can only access their designated `uploads` folder
- ✅ Password authentication enabled ONLY for SFTP group
- ✅ Admin SSH access remains key-based only
- ✅ All tunneling and forwarding capabilities are disabled

## Troubleshooting

### "User already exists" error
The user account already exists. Delete it first or choose a different username.

### "SSHD config file not found" error
Verify the path to your SSH daemon configuration file:
- `/etc/ssh/sshd_config` (most Linux distributions)
- `/etc/openssh/sshd_config` (some systems)

### SFTP connection fails
1. Check SSH service status: `sudo systemctl status ssh`
2. Verify the sshd_config syntax: `sudo sshd -t`
3. Ensure user is in the SFTP group: `groups username`
4. Check directory permissions:
   - `/sftp` must be owned by `root:root` with `755`
   - `/sftp/<username>` must be owned by `root:root` with `755`
   - `/sftp/<username>/uploads` must be owned by `username:username`

### Permission denied when uploading files
Ensure the user owns the `uploads` directory:
```bash
sudo chown username:username /sftp/username/uploads
```

### Admin can't SSH after setup
The Match Group block should not affect admin SSH access. Verify:
1. Your admin user is NOT in the `sftpusers` group
2. Global `PasswordAuthentication no` is set before any Match blocks
3. Your SSH key authentication is working

## Migration from Per-User Config

If you have existing per-user `Match User` blocks:

1. Run the setup: `sudo ./sftp.sh -setup`
2. Manually remove old `Match User` blocks from `sshd_config`
3. Add existing users to the group: `sudo usermod -aG sftpusers <username>`
4. Reload SSH: `sudo systemctl reload ssh`

## Uninstalling

To remove a user:
```bash
sudo ./sftp.sh -delete -u <username>
```

To completely remove the SFTP setup:
1. Delete all SFTP users
2. Remove the Match Group block from `sshd_config`
3. Delete the group: `sudo groupdel sftpusers`
4. Remove the base directory: `sudo rm -rf /sftp`

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Author

Built with ❤️ for easy and secure SFTP user management.

---

**⭐ If you find this useful, please consider giving it a star!**
