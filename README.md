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
git clone https://github.com/yourusername/sftp-user-manager.git

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
# With all arguments
sudo ./sftp.sh -add -u <username> -b <base_dir> -c <sshd_config_path>

# Example
sudo ./sftp.sh -add -u john -b /sftp -c /etc/ssh/sshd_config

# With custom folder name
sudo ./sftp.sh -add -u john -b /sftp -f john_files -c /etc/ssh/sshd_config

# With specific password
sudo ./sftp.sh -add -u john -p "MySecurePass123" -b /sftp -c /etc/ssh/sshd_config
```

#### Delete an SFTP user

```bash
sudo ./sftp.sh -delete -u <username> -b <base_dir> -c <sshd_config_path>

# Example
sudo ./sftp.sh -delete -u john -b /sftp -c /etc/ssh/sshd_config
```

#### Update user password

```bash
# Auto-generate new password
sudo ./sftp.sh -passwd -u <username>

# Set specific password
sudo ./sftp.sh -passwd -u <username> -p "NewPassword123"
```

### Options

| Option | Long Form | Description |
|--------|-----------|-------------|
| `-u` | `--username` | Username for SFTP account |
| `-p` | `--password` | Password (auto-generated if not provided) |
| `-b` | `--basedir` | Base directory for SFTP jail |
| `-f` | `--folder` | Folder name within base directory (defaults to username) |
| `-c` | `--config` | Path to sshd_config file |
| `-i` | `--interactive` | Force interactive mode for all prompts |
| `-h` | `--help` | Show help message |

## Directory Structure

When you create an SFTP user, the following structure is created:

```
<base_dir>/
└── <folder>/           # Owned by root (chroot requirement)
    └── uploads/        # Owned by user (writable)
```

Example with `sudo ./sftp.sh -add -u john -b /sftp`:

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

