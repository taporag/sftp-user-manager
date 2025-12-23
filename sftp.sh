#!/bin/bash
# SFTP User Manager (Generic Version)
# All values are taken from arguments or prompted interactively
#
# Usage:
#   sudo ./sftp.sh -add [options]
#   sudo ./sftp.sh -delete [options]
#   sudo ./sftp.sh -passwd [options]
#
# Options:
#   -u, --username    Username for SFTP account
#   -p, --password    Password (auto-generated if not provided)
#   -b, --basedir     Base directory for SFTP jail
#   -f, --folder      Folder name within base directory
#   -c, --config      Path to sshd_config file
#   -i, --interactive Run in fully interactive mode (prompt for all values)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Generate random password
gen_pass() {
  openssl rand -base64 12
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
  FOLDER=""
  SSHD_CONFIG=""
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
      -f|--folder)
        FOLDER="$2"
        shift 2
        ;;
      -c|--config)
        SSHD_CONFIG="$2"
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
  echo "SFTP User Manager"
  echo ""
  echo "Usage:"
  echo "  sudo $0 <action> [options]"
  echo ""
  echo "Actions:"
  echo "  -add        Add a new SFTP user"
  echo "  -delete     Delete an existing SFTP user"
  echo "  -passwd     Update password for an existing user"
  echo ""
  echo "Options:"
  echo "  -u, --username    Username for SFTP account"
  echo "  -p, --password    Password (auto-generated if not provided)"
  echo "  -b, --basedir     Base directory for SFTP jail"
  echo "  -f, --folder      Folder name within base directory (defaults to username)"
  echo "  -c, --config      Path to sshd_config file"
  echo "  -i, --interactive Run in fully interactive mode"
  echo "  -h, --help        Show this help message"
  echo ""
  echo "Examples:"
  echo "  sudo $0 -add -u john -b /sftp -c /etc/ssh/sshd_config"
  echo "  sudo $0 -add -i"
  echo "  sudo $0 -delete -u john -b /sftp -c /etc/ssh/sshd_config"
  echo "  sudo $0 -passwd -u john"
}

# Add SFTP User
add_user() {
  echo -e "${BLUE}=== Add SFTP User ===${NC}"
  echo ""

  # Prompt for missing values
  if [ -z "$USERNAME" ] || [ "$INTERACTIVE" = true ]; then
    USERNAME=$(prompt_required "Enter username")
  fi

  if [ -z "$BASE_DIR" ] || [ "$INTERACTIVE" = true ]; then
    BASE_DIR=$(prompt_required "Enter base directory (e.g., /sftp, /programs)")
  fi

  if [ -z "$FOLDER" ] || [ "$INTERACTIVE" = true ]; then
    FOLDER=$(prompt_input "Enter folder name" "$USERNAME")
  fi

  if [ -z "$SSHD_CONFIG" ] || [ "$INTERACTIVE" = true ]; then
    SSHD_CONFIG=$(prompt_required "Enter sshd_config path (e.g., /etc/ssh/sshd_config)")
  fi

  if [ -z "$PASSWORD" ] || [ "$INTERACTIVE" = true ]; then
    echo "Leave password empty to auto-generate"
    PASSWORD=$(prompt_input "Enter password" "" "true")
  fi

  # Set folder to username if empty
  if [ -z "$FOLDER" ]; then
    FOLDER="$USERNAME"
  fi

  # Generate password if not provided
  if [ -z "$PASSWORD" ]; then
    PASSWORD=$(gen_pass)
    echo -e "${YELLOW}📝 Auto-generated password${NC}"
  fi

  USER_HOME="$BASE_DIR/$FOLDER"

  # Display summary
  echo ""
  echo -e "${BLUE}Summary:${NC}"
  echo "  Username:       $USERNAME"
  echo "  Base Directory: $BASE_DIR"
  echo "  Folder:         $FOLDER"
  echo "  Home Directory: $USER_HOME"
  echo "  SSHD Config:    $SSHD_CONFIG"
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

  # Create user with no shell
  useradd -M -d "$USER_HOME" -s /usr/sbin/nologin "$USERNAME"
  echo "$USERNAME:$PASSWORD" | chpasswd

  # Setup jail dirs
  mkdir -p "$USER_HOME/uploads"
  chown root:root "$USER_HOME"
  chmod 755 "$USER_HOME"
  chown "$USERNAME:$USERNAME" "$USER_HOME/uploads"

  # Add SSHD config block
  if ! grep -q "Match User $USERNAME" "$SSHD_CONFIG"; then
    cat >> "$SSHD_CONFIG" <<EOF

# SFTP config for $USERNAME
Match User $USERNAME
    ForceCommand internal-sftp -d uploads
    ChrootDirectory $USER_HOME
    PasswordAuthentication yes
    PermitTunnel no
    AllowAgentForwarding no
    AllowTcpForwarding no
    X11Forwarding no
EOF
  fi

  systemctl reload sshd

  echo ""
  echo -e "${GREEN}✅ SFTP user created successfully${NC}"
  echo "======================================="
  echo "Username:       $USERNAME"
  echo "Password:       $PASSWORD"
  echo "Home Directory: $USER_HOME/uploads"
  echo "======================================="
}

# Delete SFTP User
delete_user() {
  echo -e "${BLUE}=== Delete SFTP User ===${NC}"
  echo ""

  # Prompt for missing values
  if [ -z "$USERNAME" ] || [ "$INTERACTIVE" = true ]; then
    USERNAME=$(prompt_required "Enter username to delete")
  fi

  if [ -z "$BASE_DIR" ] || [ "$INTERACTIVE" = true ]; then
    BASE_DIR=$(prompt_required "Enter base directory (e.g., /sftp, /programs)")
  fi

  if [ -z "$FOLDER" ] || [ "$INTERACTIVE" = true ]; then
    FOLDER=$(prompt_input "Enter folder name" "$USERNAME")
  fi

  if [ -z "$SSHD_CONFIG" ] || [ "$INTERACTIVE" = true ]; then
    SSHD_CONFIG=$(prompt_required "Enter sshd_config path (e.g., /etc/ssh/sshd_config)")
  fi

  # Set folder to username if empty
  if [ -z "$FOLDER" ]; then
    FOLDER="$USERNAME"
  fi

  USER_HOME="$BASE_DIR/$FOLDER"

  # Display summary
  echo ""
  echo -e "${BLUE}Summary:${NC}"
  echo "  Username:       $USERNAME"
  echo "  Home Directory: $USER_HOME"
  echo "  SSHD Config:    $SSHD_CONFIG"
  echo ""

  echo -e "${RED}⚠️  WARNING: This will permanently delete the user and their data!${NC}"
  if ! confirm_action "Are you sure you want to delete this user?"; then
    echo -e "${YELLOW}⚠️  Operation cancelled${NC}"
    exit 0
  fi

  # Delete user account
  if id "$USERNAME" &>/dev/null; then
    userdel -r "$USERNAME" 2>/dev/null
    echo -e "${GREEN}🗑️  User '$USERNAME' removed${NC}"
  else
    echo -e "${YELLOW}⚠️  User '$USERNAME' does not exist${NC}"
  fi

  # Remove jail folder if still exists
  if [ -d "$USER_HOME" ]; then
    rm -rf "$USER_HOME"
    echo -e "${GREEN}🧹 Removed folder $USER_HOME${NC}"
  fi

  # Remove SSHD config block for this user
  if [ -f "$SSHD_CONFIG" ] && grep -q "# SFTP config for $USERNAME" "$SSHD_CONFIG"; then
    sed -i "/# SFTP config for $USERNAME/,/X11Forwarding no/d" "$SSHD_CONFIG"
    echo -e "${GREEN}🧾 Removed SSHD config block for $USERNAME${NC}"
  else
    echo -e "${YELLOW}⚠️  No SSHD config block found for $USERNAME${NC}"
  fi

  systemctl reload sshd

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
  echo "  1) Add user"
  echo "  2) Delete user"
  echo "  3) Update password"
  echo "  4) Exit"
  echo ""

  read -p "Enter choice [1-4]: " choice

  case "$choice" in
    1) ACTION="add" ;;
    2) ACTION="delete" ;;
    3) ACTION="passwd" ;;
    4) echo "Goodbye!"; exit 0 ;;
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
