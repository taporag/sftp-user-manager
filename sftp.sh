#!/bin/bash
# SFTP User Manager (Group-Based Version)
# Uses a single SSHD Match Group block instead of per-user blocks
#
# Usage:
#   sudo ./sftp.sh -add [options]
#   sudo ./sftp.sh -delete [options]
#   sudo ./sftp.sh -passwd [options]
#   sudo ./sftp.sh -setup    # One-time setup of group and SSHD config
#
# Options:
#   -u, --username    Username for SFTP account
#   -p, --password    Password (auto-generated if not provided)
#   -b, --basedir     Base directory for SFTP jail (must match ChrootDirectory pattern)
#   -c, --config      Path to sshd_config file
#   -s, --shell       Path to nologin shell
#   -g, --group       SFTP users group name
#   -d, --uploaddir   Upload directory name inside jail
#   -i, --interactive Run in fully interactive mode (prompt for all values)

# =============================================================================
# DEFAULT VALUES (can be overridden via arguments or environment variables)
# =============================================================================
DEFAULT_SSHD_CONFIG="${SFTP_SSHD_CONFIG:-/etc/ssh/sshd_config}"
DEFAULT_BASE_DIR="${SFTP_BASE_DIR:-/sftp}"
DEFAULT_NOLOGIN_SHELL="${SFTP_NOLOGIN_SHELL:-/usr/sbin/nologin}"
DEFAULT_UPLOAD_DIR="${SFTP_UPLOAD_DIR:-uploads}"
DEFAULT_SFTP_GROUP="${SFTP_GROUP:-sftpusers}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Generate random password
gen_pass() {
  openssl rand -base64 12
}

# Reload SSH service (Ubuntu uses 'ssh', others use 'sshd')
reload_ssh() {
  if systemctl reload ssh 2>/dev/null; then
    echo -e "${GREEN}🔄 SSH service reloaded${NC}"
  elif systemctl reload sshd 2>/dev/null; then
    echo -e "${GREEN}🔄 SSHD service reloaded${NC}"
  else
    echo -e "${YELLOW}⚠️  Could not reload SSH service. Please reload manually.${NC}"
  fi
}

# Prompt for input with optional default
prompt_input() {
  local prompt_text="$1"
  local default_value="$2"
  local is_password="$3"
  local result

  if [ -n "$default_value" ]; then
    prompt_text="$prompt_text [$default_value]"
  fi

  if [ "$is_password" = "true" ]; then
    read -sp "$prompt_text: " result
    echo
  else
    read -p "$prompt_text: " result
  fi

  if [ -z "$result" ] && [ -n "$default_value" ]; then
    result="$default_value"
  fi

  echo "$result"
}

# Prompt for required input (no default, must provide value)
prompt_required() {
  local prompt_text="$1"
  local is_password="$2"
  local result=""

  while [ -z "$result" ]; do
    if [ "$is_password" = "true" ]; then
      read -sp "$prompt_text: " result
      echo
    else
      read -p "$prompt_text: " result
    fi
    if [ -z "$result" ]; then
      echo -e "${YELLOW}⚠️  This field is required${NC}"
    fi
  done

  echo "$result"
}

# Confirm action
confirm_action() {
  local prompt_text="$1"
  local response

  read -p "$prompt_text [y/N]: " response
  case "$response" in
    [yY][eE][sS]|[yY]) return 0 ;;
    *) return 1 ;;
  esac
}

# Parse command line arguments
parse_args() {
  ACTION=""
  USERNAME=""
  PASSWORD=""
  BASE_DIR=""
  SSHD_CONFIG=""
  NOLOGIN_SHELL=""
  UPLOAD_DIR=""
  SFTP_GROUP=""
  INTERACTIVE=false

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -add)
        ACTION="add"
        shift
        ;;
      -delete)
        ACTION="delete"
        shift
        ;;
      -passwd)
        ACTION="passwd"
        shift
        ;;
      -setup)
        ACTION="setup"
        shift
        ;;
      -u|--username)
        USERNAME="$2"
        shift 2
        ;;
      -p|--password)
        PASSWORD="$2"
        shift 2
        ;;
      -b|--basedir)
        BASE_DIR="$2"
        shift 2
        ;;
      -c|--config)
        SSHD_CONFIG="$2"
        shift 2
        ;;
      -s|--shell)
        NOLOGIN_SHELL="$2"
        shift 2
        ;;
      -g|--group)
        SFTP_GROUP="$2"
        shift 2
        ;;
      -d|--uploaddir)
        UPLOAD_DIR="$2"
        shift 2
        ;;
      -i|--interactive)
        INTERACTIVE=true
        shift
        ;;
      -h|--help)
        show_help
        exit 0
        ;;
      *)
        echo -e "${RED}❌ Unknown option: $1${NC}"
        show_help
        exit 1
        ;;
    esac
  done
}

# Show help
show_help() {
  echo "SFTP User Manager (Group-Based)"
  echo ""
  echo "This script uses a single Match Group block in sshd_config instead of"
  echo "per-user blocks. All SFTP users are added to a common group."
  echo ""
  echo "Usage:"
  echo "  sudo $0 <action> [options]"
  echo ""
  echo "Actions:"
  echo "  -add        Add a new SFTP user"
  echo "  -delete     Delete an existing SFTP user"
  echo "  -passwd     Update password for an existing user"
  echo "  -setup      One-time setup: create group and add SSHD config block"
  echo ""
  echo "Options:"
  echo "  -u, --username    Username for SFTP account (required for add/delete/passwd)"
  echo "  -p, --password    Password (auto-generated if not provided)"
  echo "  -b, --basedir     Base directory for SFTP jail (default: $DEFAULT_BASE_DIR)"
  echo "  -c, --config      Path to sshd_config file (default: $DEFAULT_SSHD_CONFIG)"
  echo "  -s, --shell       Path to nologin shell (default: $DEFAULT_NOLOGIN_SHELL)"
  echo "  -g, --group       SFTP users group name (default: $DEFAULT_SFTP_GROUP)"
  echo "  -d, --uploaddir   Upload directory name (default: $DEFAULT_UPLOAD_DIR)"
  echo "  -i, --interactive Run in fully interactive mode"
  echo "  -h, --help        Show this help message"
  echo ""
  echo "Environment Variables (override defaults):"
  echo "  SFTP_BASE_DIR      Default base directory"
  echo "  SFTP_SSHD_CONFIG   Default sshd_config path"
  echo "  SFTP_NOLOGIN_SHELL Default nologin shell path"
  echo "  SFTP_UPLOAD_DIR    Default upload directory name"
  echo "  SFTP_GROUP         Default SFTP users group name"
  echo ""
  echo "Directory Structure:"
  echo "  <basedir>/<username>/uploads"
  echo "  Example: /sftp/john/uploads"
  echo ""
  echo "  The SSHD ChrootDirectory uses: <basedir>/%u"
  echo "  This means each user is jailed to their own directory."
  echo ""
  echo "Examples:"
  echo "  # Initial setup (run once)"
  echo "  sudo $0 -setup"
  echo ""
  echo "  # Add user with defaults"
  echo "  sudo $0 -add -u john"
  echo ""
  echo "  # Add user with custom base directory"
  echo "  sudo $0 -add -u john -b /data/sftp"
  echo ""
  echo "  # Delete user"
  echo "  sudo $0 -delete -u john"
  echo ""
  echo "  # Update password"
  echo "  sudo $0 -passwd -u john"
  echo ""
  echo "Security Notes:"
  echo "  - Global SSHD config should have: PasswordAuthentication no"
  echo "  - The Match Group block enables password auth ONLY for SFTP users"
  echo "  - Admin SSH access remains key-only"
}

# Apply defaults to variables
apply_defaults() {
  if [ -z "$BASE_DIR" ]; then
    BASE_DIR="$DEFAULT_BASE_DIR"
  fi
  if [ -z "$SSHD_CONFIG" ]; then
    SSHD_CONFIG="$DEFAULT_SSHD_CONFIG"
  fi
  if [ -z "$NOLOGIN_SHELL" ]; then
    NOLOGIN_SHELL="$DEFAULT_NOLOGIN_SHELL"
  fi
  if [ -z "$UPLOAD_DIR" ]; then
    UPLOAD_DIR="$DEFAULT_UPLOAD_DIR"
  fi
  if [ -z "$SFTP_GROUP" ]; then
    SFTP_GROUP="$DEFAULT_SFTP_GROUP"
  fi
}

# Ensure the SFTP group exists
ensure_group() {
  if ! getent group "$SFTP_GROUP" &>/dev/null; then
    groupadd "$SFTP_GROUP"
    echo -e "${GREEN}✅ Created group '$SFTP_GROUP'${NC}"
  else
    echo -e "${CYAN}ℹ️  Group '$SFTP_GROUP' already exists${NC}"
  fi
}

# Ensure base directory exists with correct permissions
ensure_base_dir() {
  if [ ! -d "$BASE_DIR" ]; then
    mkdir -p "$BASE_DIR"
    echo -e "${GREEN}✅ Created base directory '$BASE_DIR'${NC}"
  fi
  chown root:root "$BASE_DIR"
  chmod 755 "$BASE_DIR"
}

# Add Match Group block to sshd_config (only once)
ensure_sshd_group_config() {
  local config_marker="# SFTP group config ($SFTP_GROUP)"
  
  if grep -q "$config_marker" "$SSHD_CONFIG"; then
    echo -e "${CYAN}ℹ️  SSHD Match Group block already exists${NC}"
    return 0
  fi

  echo -e "${BLUE}Adding Match Group block to $SSHD_CONFIG...${NC}"
  
  cat >> "$SSHD_CONFIG" <<EOF

$config_marker
Match Group $SFTP_GROUP
    ChrootDirectory $BASE_DIR/%u
    ForceCommand internal-sftp -d $UPLOAD_DIR
    PasswordAuthentication yes
    PermitTunnel no
    AllowAgentForwarding no
    AllowTcpForwarding no
    X11Forwarding no
EOF

  echo -e "${GREEN}✅ Added Match Group block for '$SFTP_GROUP'${NC}"
  
  # Validate sshd config
  if sshd -t 2>/dev/null; then
    echo -e "${GREEN}✅ SSHD config syntax is valid${NC}"
  else
    echo -e "${RED}❌ SSHD config syntax error! Please check $SSHD_CONFIG${NC}"
    exit 1
  fi
}

# One-time setup
setup() {
  echo -e "${BLUE}=== SFTP Initial Setup ===${NC}"
  echo ""
  
  # Apply defaults
  apply_defaults
  
  # Interactive mode for setup
  if [ "$INTERACTIVE" = true ]; then
    BASE_DIR=$(prompt_input "Enter base directory" "$BASE_DIR")
    SSHD_CONFIG=$(prompt_input "Enter sshd_config path" "$SSHD_CONFIG")
    SFTP_GROUP=$(prompt_input "Enter SFTP group name" "$SFTP_GROUP")
    UPLOAD_DIR=$(prompt_input "Enter upload directory name" "$UPLOAD_DIR")
  fi

  # Display summary
  echo -e "${BLUE}Setup Configuration:${NC}"
  echo "  Base Directory:   $BASE_DIR"
  echo "  SSHD Config:      $SSHD_CONFIG"
  echo "  SFTP Group:       $SFTP_GROUP"
  echo "  Upload Directory: $UPLOAD_DIR"
  echo ""
  echo -e "${CYAN}This will:${NC}"
  echo "  1. Create the SFTP group '$SFTP_GROUP'"
  echo "  2. Create the base directory '$BASE_DIR'"
  echo "  3. Add a Match Group block to '$SSHD_CONFIG'"
  echo ""

  if ! confirm_action "Proceed with setup?"; then
    echo -e "${YELLOW}⚠️  Setup cancelled${NC}"
    exit 0
  fi

  # Validate sshd_config exists
  if [ ! -f "$SSHD_CONFIG" ]; then
    echo -e "${RED}❌ SSHD config file not found: $SSHD_CONFIG${NC}"
    exit 1
  fi

  # Perform setup
  ensure_group
  ensure_base_dir
  ensure_sshd_group_config
  reload_ssh

  echo ""
  echo -e "${GREEN}✅ Setup complete!${NC}"
  echo ""
  echo -e "${CYAN}Next steps:${NC}"
  echo "  1. Add users with: sudo $0 -add -u <username>"
  echo "  2. Users connect via: sftp <username>@<your-server>"
}

# Add SFTP User
add_user() {
  echo -e "${BLUE}=== Add SFTP User ===${NC}"
  echo ""

  # Apply defaults
  apply_defaults

  # Prompt for missing values (username is always required)
  if [ -z "$USERNAME" ] || [ "$INTERACTIVE" = true ]; then
    USERNAME=$(prompt_required "Enter username")
  fi

  # Interactive prompts for other values
  if [ "$INTERACTIVE" = true ]; then
    BASE_DIR=$(prompt_input "Enter base directory" "$BASE_DIR")
    SSHD_CONFIG=$(prompt_input "Enter sshd_config path" "$SSHD_CONFIG")
    SFTP_GROUP=$(prompt_input "Enter SFTP group name" "$SFTP_GROUP")
    NOLOGIN_SHELL=$(prompt_input "Enter nologin shell path" "$NOLOGIN_SHELL")
    UPLOAD_DIR=$(prompt_input "Enter upload directory name" "$UPLOAD_DIR")
  fi

  # Password - prompt or auto-generate
  if [ -z "$PASSWORD" ] || [ "$INTERACTIVE" = true ]; then
    echo "Leave password empty to auto-generate"
    PASSWORD=$(prompt_input "Enter password" "" "true")
  fi

  # Generate password if not provided
  if [ -z "$PASSWORD" ]; then
    PASSWORD=$(gen_pass)
    echo -e "${YELLOW}📝 Auto-generated password${NC}"
  fi

  USER_HOME="$BASE_DIR/$USERNAME"

  # Display summary
  echo ""
  echo -e "${BLUE}Summary:${NC}"
  echo "  Username:         $USERNAME"
  echo "  SFTP Group:       $SFTP_GROUP"
  echo "  Home Directory:   $USER_HOME"
  echo "  Upload Directory: $USER_HOME/$UPLOAD_DIR"
  echo "  Nologin Shell:    $NOLOGIN_SHELL"
  echo ""

  if ! confirm_action "Proceed with creating user?"; then
    echo -e "${YELLOW}⚠️  Operation cancelled${NC}"
    exit 0
  fi

  # Stop if user exists
  if id "$USERNAME" &>/dev/null; then
    echo -e "${RED}❌ User '$USERNAME' already exists. Aborting.${NC}"
    exit 1
  fi

  # Validate sshd_config exists
  if [ ! -f "$SSHD_CONFIG" ]; then
    echo -e "${RED}❌ SSHD config file not found: $SSHD_CONFIG${NC}"
    exit 1
  fi

  # Validate nologin shell exists
  if [ ! -f "$NOLOGIN_SHELL" ]; then
    echo -e "${RED}❌ Nologin shell not found: $NOLOGIN_SHELL${NC}"
    echo -e "${YELLOW}   Try: /bin/false, /usr/bin/false, or /sbin/nologin${NC}"
    exit 1
  fi

  # Ensure group exists
  ensure_group

  # Ensure SSHD group config exists
  ensure_sshd_group_config

  # Ensure base directory exists
  ensure_base_dir

  # Create user with no shell
  useradd -M -d "$USER_HOME" -s "$NOLOGIN_SHELL" "$USERNAME"
  echo "$USERNAME:$PASSWORD" | chpasswd

  # Add user to SFTP group
  usermod -aG "$SFTP_GROUP" "$USERNAME"
  echo -e "${GREEN}✅ Added '$USERNAME' to group '$SFTP_GROUP'${NC}"

  # Setup user jail directory
  # /sftp/<username> -> owned by root:root, 755 (required for chroot)
  # /sftp/<username>/uploads -> owned by user:user, 755 (writable by user)
  mkdir -p "$USER_HOME/$UPLOAD_DIR"
  chown root:root "$USER_HOME"
  chmod 755 "$USER_HOME"
  chown "$USERNAME:$USERNAME" "$USER_HOME/$UPLOAD_DIR"
  chmod 755 "$USER_HOME/$UPLOAD_DIR"

  reload_ssh

  echo ""
  echo -e "${GREEN}✅ SFTP user created successfully${NC}"
  echo "======================================="
  echo "Username:       $USERNAME"
  echo "Password:       $PASSWORD"
  echo "Home Directory: $USER_HOME/$UPLOAD_DIR"
  echo "SFTP Group:     $SFTP_GROUP"
  echo "======================================="
  echo ""
  echo -e "${CYAN}Connect with:${NC} sftp $USERNAME@<your-server>"
}

# Delete SFTP User
delete_user() {
  echo -e "${BLUE}=== Delete SFTP User ===${NC}"
  echo ""

  # Apply defaults
  apply_defaults

  # Prompt for missing values (username is always required)
  if [ -z "$USERNAME" ] || [ "$INTERACTIVE" = true ]; then
    USERNAME=$(prompt_required "Enter username to delete")
  fi

  # Interactive prompts
  if [ "$INTERACTIVE" = true ]; then
    BASE_DIR=$(prompt_input "Enter base directory" "$BASE_DIR")
  fi

  USER_HOME="$BASE_DIR/$USERNAME"

  # Display summary
  echo ""
  echo -e "${BLUE}Summary:${NC}"
  echo "  Username:       $USERNAME"
  echo "  Home Directory: $USER_HOME"
  echo ""

  echo -e "${RED}⚠️  WARNING: This will permanently delete the user and their data!${NC}"
  if ! confirm_action "Are you sure you want to delete this user?"; then
    echo -e "${YELLOW}⚠️  Operation cancelled${NC}"
    exit 0
  fi

  # Delete user account (also removes from all groups)
  if id "$USERNAME" &>/dev/null; then
    userdel "$USERNAME" 2>/dev/null
    echo -e "${GREEN}🗑️  User '$USERNAME' removed${NC}"
  else
    echo -e "${YELLOW}⚠️  User '$USERNAME' does not exist${NC}"
  fi

  # Remove jail folder if still exists
  if [ -d "$USER_HOME" ]; then
    rm -rf "$USER_HOME"
    echo -e "${GREEN}🧹 Removed folder $USER_HOME${NC}"
  fi

  # Note: We do NOT modify sshd_config - the Match Group block stays
  echo -e "${CYAN}ℹ️  SSHD config unchanged (group-based access)${NC}"

  echo ""
  echo -e "${GREEN}✅ SFTP user '$USERNAME' fully removed${NC}"
}

# Update password
update_password() {
  echo -e "${BLUE}=== Update SFTP User Password ===${NC}"
  echo ""

  # Prompt for missing values
  if [ -z "$USERNAME" ] || [ "$INTERACTIVE" = true ]; then
    USERNAME=$(prompt_required "Enter username")
  fi

  # Check if user exists
  if ! id "$USERNAME" &>/dev/null; then
    echo -e "${RED}❌ User '$USERNAME' does not exist${NC}"
    exit 1
  fi

  if [ -z "$PASSWORD" ] || [ "$INTERACTIVE" = true ]; then
    echo "Leave password empty to auto-generate"
    PASSWORD=$(prompt_input "Enter new password" "" "true")
  fi

  # Generate password if not provided
  if [ -z "$PASSWORD" ]; then
    PASSWORD=$(gen_pass)
    echo -e "${YELLOW}📝 Auto-generated password${NC}"
  fi

  echo ""
  if ! confirm_action "Update password for user '$USERNAME'?"; then
    echo -e "${YELLOW}⚠️  Operation cancelled${NC}"
    exit 0
  fi

  echo "$USERNAME:$PASSWORD" | chpasswd

  echo ""
  echo -e "${GREEN}✅ Password updated${NC}"
  echo "======================================="
  echo "Username:     $USERNAME"
  echo "New Password: $PASSWORD"
  echo "======================================="
}

# Interactive mode selector
interactive_menu() {
  echo -e "${BLUE}=== SFTP User Manager ===${NC}"
  echo ""
  echo "Select an action:"
  echo "  1) Initial setup (run once)"
  echo "  2) Add user"
  echo "  3) Delete user"
  echo "  4) Update password"
  echo "  5) Exit"
  echo ""

  read -p "Enter choice [1-5]: " choice

  case "$choice" in
    1) ACTION="setup" ;;
    2) ACTION="add" ;;
    3) ACTION="delete" ;;
    4) ACTION="passwd" ;;
    5) echo "Goodbye!"; exit 0 ;;
    *) echo -e "${RED}❌ Invalid choice${NC}"; exit 1 ;;
  esac
}

# Main
parse_args "$@"

# If no action specified, show interactive menu
if [ -z "$ACTION" ]; then
  interactive_menu
  INTERACTIVE=true
fi

case "$ACTION" in
  setup)
    setup
    ;;
  add)
    add_user
    ;;
  delete)
    delete_user
    ;;
  passwd)
    update_password
    ;;
  *)
    show_help
    exit 1
    ;;
esac
