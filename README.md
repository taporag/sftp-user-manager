# SFTP User Manager

A flexible, interactive bash script for managing SFTP-only user accounts with chroot jail isolation on Linux servers.

## Features

- 🔐 **Secure SFTP-only access** - Users are jailed to their home directory with no shell access
- 🎯 **No hardcoded values** - Fully configurable via arguments or interactive prompts
- 🔄 **Interactive mode** - User-friendly prompts for all operations
- 🎨 **Colored output** - Clear visual feedback for operations
- ✅ **Confirmation prompts** - Safety checks before destructive actions
- 🔑 **Auto-generate passwords** - Secure random password generation using OpenSSL

## Prerequisites

- Linux server with SSH/SFTP enabled
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

## Usage

### Interactive Mode (Recommended for beginners)

Simply run the script without arguments to enter fully interactive mode:

```bash
sudo ./sftp.sh
```

You'll see a menu to select your action:

```
=== SFTP User Manager ===

Select an action:
  1) Add user
  2) Delete user
  3) Update password
  4) Exit

Enter choice [1-4]:
```

### Command Line Mode

#### Add a new SFTP user

```bash
# Simplest usage - uses all defaults (base: /sftp, config: /etc/ssh/sshd_config)
sudo ./sftp.sh -add -u john

# With custom base directory
sudo ./sftp.sh -add -u john -b /data/sftp

# With custom folder name
sudo ./sftp.sh -add -u john -f john_files

# With specific password
sudo ./sftp.sh -add -u john -p "MySecurePass123"

# Override all defaults
sudo ./sftp.sh -add -u john -b /data/sftp -f john_home -c /etc/openssh/sshd_config -d files
```

#### Delete an SFTP user

```bash
# Uses defaults for base directory and config path
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
| `-f` | `--folder` | *(username)* | Folder name within base directory |
| `-c` | `--config` | `/etc/ssh/sshd_config` | Path to sshd_config file |
| `-s` | `--shell` | `/usr/sbin/nologin` | Path to nologin shell |
| `-d` | `--uploaddir` | `uploads` | Upload directory name inside jail |
| `-i` | `--interactive` | `false` | Force interactive mode for all prompts |
| `-h` | `--help` | - | Show help message |

### Environment Variables

You can set these environment variables to override the defaults system-wide:

| Variable | Default | Description |
|----------|---------|-------------|
| `SFTP_BASE_DIR` | `/sftp` | Default base directory |
| `SFTP_SSHD_CONFIG` | `/etc/ssh/sshd_config` | Default sshd_config path |
| `SFTP_NOLOGIN_SHELL` | `/usr/sbin/nologin` | Default nologin shell path |
| `SFTP_UPLOAD_DIR` | `uploads` | Default upload directory name |

Example using environment variables:

```bash
export SFTP_BASE_DIR="/data/sftp"
export SFTP_SSHD_CONFIG="/etc/openssh/sshd_config"
sudo -E ./sftp.sh -add -u john
```

## Directory Structure

When you create an SFTP user, the following structure is created:

```
<base_dir>/
└── <folder>/           # Owned by root (chroot requirement)
    └── uploads/        # Owned by user (writable)
```

Example with `sudo ./sftp.sh -add -u john`:

```
/sftp/
└── john/               # Chroot jail (root:root, 755)
    └── uploads/        # User's writable directory (john:john)
```

## How It Works

1. **User Creation**: Creates a system user with no login shell (`/usr/sbin/nologin`)
2. **Directory Setup**: Creates a chroot jail with proper ownership for SFTP
3. **SSH Configuration**: Adds a `Match User` block to `sshd_config` with:
   - `ForceCommand internal-sftp` - Only allows SFTP, no shell
   - `ChrootDirectory` - Jails user to their home directory
   - Disabled tunneling, agent forwarding, TCP forwarding, and X11

## Connecting via SFTP

Once a user is created, they can connect using any SFTP client:

```bash
sftp username@your-server-ip
```

They will be automatically placed in the `uploads` directory where they can read/write files.

## Security Considerations

- Users are completely isolated in their chroot jail
- No shell access is possible (even if attempted)
- Users can only access their designated `uploads` folder
- Password authentication is enabled per-user (can be customized)
- All tunneling and forwarding capabilities are disabled

## Troubleshooting

### "User already exists" error
The user account already exists on the system. Delete it first or choose a different username.

### "SSHD config file not found" error
Verify the path to your SSH daemon configuration file. Common locations:
- `/etc/ssh/sshd_config` (most Linux distributions)
- `/etc/openssh/sshd_config` (some systems)

### SFTP connection fails after user creation
1. Check SSH service status: `sudo systemctl status sshd`
2. Verify the sshd_config syntax: `sudo sshd -t`
3. Check directory permissions:
   - Chroot directory must be owned by `root:root` with `755`
   - `uploads` directory must be owned by the user

### Permission denied when uploading files
Ensure the user owns the `uploads` directory:
```bash
sudo chown username:username /base_dir/folder/uploads
```

## Uninstalling

To completely remove a user and clean up:

```bash
sudo ./sftp.sh -delete -u <username> -b <base_dir> -c <sshd_config_path>
```

This will:
- Delete the user account
- Remove the user's home directory
- Remove the SSH configuration block
- Reload the SSH service

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

Built with ❤️ for easy SFTP user management.

---

**⭐ If you find this useful, please consider giving it a star!**

