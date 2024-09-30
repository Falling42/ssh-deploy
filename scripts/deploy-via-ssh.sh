#!/usr/bin/env bash

# 定义颜色
RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
BLUE="\033[34m"
MAGENTA="\033[35m"
CYAN="\033[36m"
RESET="\033[0m"

# 输出带颜色的信息
log_info() {
  echo -e "${CYAN}$1${RESET}"
}

log_success() {
  echo -e "${GREEN}$1${RESET}"
}

log_error() {
  echo -e "${RED}$1${RESET}"
}

log_warning() {
  echo -e "${YELLOW}$1${RESET}"
}

# 从环境变量中读取值
USE_SCREEN="${USE_SCREEN:-no}"
USE_JUMP_HOST="${USE_JUMP_HOST:-no}"
JUMP_SSH_HOST="${JUMP_SSH_HOST:-}"
JUMP_SSH_USER="${JUMP_SSH_USER:-}"
JUMP_SSH_PRIVATE_KEY="${JUMP_SSH_PRIVATE_KEY:-}"
JUMP_SSH_PORT="${JUMP_SSH_PORT:-22}"
SSH_PRIVATE_KEY="${SSH_PRIVATE_KEY:-}"
SSH_HOST="${SSH_HOST:-}"
SSH_USER="${SSH_USER:-}"
SSH_PORT="${SSH_PORT:-22}"
EXECUTE_REMOTE_SCRIPT="${EXECUTE_REMOTE_SCRIPT:-}"
COPY_SCRIPT="${COPY_SCRIPT:-}"
SOURCE_SCRIPT="${SOURCE_SCRIPT:-}"
DEPLOY_SCRIPT="${DEPLOY_SCRIPT:-}"
TRANSFER_FILES="${TRANSFER_FILES:-yes}"
SOURCE_FILE_PATH="${SOURCE_FILE_PATH:-}"
DESTINATION_PATH="${DESTINATION_PATH:-}"
SERVICE_NAME="${SERVICE_NAME:-}"
SERVICE_VERSION="${SERVICE_VERSION:-}"

# 检测系统并安装 uuidgen
install_uuidgen() {
  if command -v uuidgen &> /dev/null; then
    log_success "uuidgen is already installed on this server."
    return 0  # 退出安装函数，表示已安装
  fi
  log_warning "uuidgen is not installed on this server. Installing..."
  if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    if command -v apt-get &> /dev/null; then
      log_info "Detected Debian/Ubuntu. Installing uuidgen..."
      sudo apt-get update
      sudo apt-get install -y uuid-runtime
    elif command -v yum &> /dev/null; then
      log_info "Detected CentOS/RedHat/Fedora. Installing uuidgen..."
      sudo yum install -y util-linux
    elif command -v dnf &> /dev/null; then
      log_info "Detected Fedora (dnf). Installing uuidgen..."
      sudo dnf install -y util-linux
    elif command -v pacman &> /dev/null; then
      log_info "Detected Arch Linux. Installing uuidgen..."
      sudo pacman -S util-linux
    else
      log_error "Unsupported Linux distribution. Please install uuidgen manually."
      exit 1
    fi
  elif [[ "$OSTYPE" == "darwin"* ]]; then
    if command -v uuidgen &> /dev/null; then
      log_success "uuidgen is already installed on macOS."
    else
      log_warning "Installing uuidgen on macOS..."
      if ! command -v brew &> /dev/null; then
        log_info "Homebrew is not installed. Installing Homebrew first..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
      fi
      log_info "Installing uuidgen via Homebrew..."
      brew install coreutils
    fi
  else
    log_error "Unsupported OS. Please install uuidgen manually."
    exit 1
  fi
  if command -v uuidgen &> /dev/null; then
    log_success "uuidgen installation successful."
  else
    log_error "uuidgen installation failed."
    exit 1
  fi
}

# 检查必需参数是否为空
check_param() {
  local param_value=$1
  local param_name=$2

  if [ -z "$param_value" ]; then
    log_error "Error: $param_name is missing."
    exit 1
  else
    log_info "$param_name is ${BLUE}$param_value${RESET}."
  fi
}

ssh_init(){
  mkdir -p ~/.ssh/
  chmod 700 ~/.ssh/
}

# 设置 SSH 私钥
setup_ssh_key() {
  local ssh_key="$1"
  local key_path="$2"
  
  echo "${ssh_key}" > "${key_path}"
  chmod 600 "${key_path}" || { log_error "Error: Failed to set permissions for ${key_path}."; exit 1; }
  [ ! -f "${key_path}" ] && { log_error "Error: Failed to write SSH private key at ${key_path}."; exit 1; }
}

# 设置 SSH 配置文件
setup_ssh_config() {
  local host_name="$1"
  local ssh_host="$2"
  local ssh_user="$3"
  local ssh_key="$4"
  local ssh_port="${5:-22}"
  local proxy_jump="$6"

  if ! grep -q "Host $host_name" ~/.ssh/config 2>/dev/null; then
    log_info "Writing SSH configuration for $host_name"
    cat >>~/.ssh/config <<END
Host ${host_name}
  HostName ${ssh_host}
  User ${ssh_user}
  Port ${ssh_port}
  IdentityFile ${ssh_key}
  StrictHostKeyChecking no
  ServerAliveInterval 60
  ServerAliveCountMax 3
  ${proxy_jump}
END
  else
    log_info "SSH configuration for $host_name already exists."
  fi
}

# 检查并安装 screen
check_and_install_screen() {
  log_info "Checking if 'screen' is installed on the remote host..."
  if ssh remote "command -v screen &>/dev/null"; then
    log_success "'screen' is already installed on the remote host."
  else
    log_warning "'screen' is not installed. Attempting to install..."
    ssh remote "if command -v apt-get &>/dev/null; then
                   sudo apt-get update && sudo apt-get install -y screen;
                 elif command -v yum &>/dev/null; then
                   sudo yum install -y screen;
                 elif command -v dnf &>/dev/null; then
                   sudo dnf install -y screen;
                 elif command -v pacman &>/dev/null; then
                   sudo pacman -Sy screen;
                 else
                   echo 'Error: Unsupported package manager. Please install screen manually.';
                   exit 1;
                 fi" || { log_error "Error: Failed to install 'screen' on the remote server."; exit 1; }
    log_success "'screen' installation completed on the remote host."
  fi
}

# 在screen里执行命令
execute_inscreen() {
  local command="$1"
  local screen_name="${2:-}"

  check_and_install_screen
  install_uuidgen
  screen_name="$screen_name$(uuidgen)"
  log_info "Creating screen session: $screen_name"
  eval "ssh remote sudo screen -dmS $screen_name" || { log_error "Error: Failed to create screen session."; exit 1; }
  log_info "Executing command in screen: $command"
  eval "ssh remote sudo screen -S $screen_name -X stuff \"\$'$command && exit\n'\"" || { log_error "Error: Failed to execute command in screen."; exit 1; }
  log_info "Command is executing in screen. Check the screen session for any errors."
}

# 执行命令
execute_command() {
  local command="$1"

  log_info "Executing command: $command"
  eval "ssh remote \"$command\"" || { log_error "Error: Failed to execute command."; exit 1; }
  log_success "Command executed successfully."
}

# 确保远程目录存在
ensure_directory_exists() {
  local remote_dir_path="$1"
  
  log_info "Checking if directory ${remote_dir_path} exists on remote host..."
  if ! ssh remote "[ -d ${remote_dir_path} ]"; then
    log_warning "Directory ${remote_dir_path} does not exist. Creating it..."
    execute_command "sudo mkdir -p ${remote_dir_path}" || { log_error "Error: Failed to create directory ${remote_dir_path}."; exit 1; }
    log_success "Directory ${remote_dir_path} created successfully."
  else
    log_success "Directory ${remote_dir_path} already exists."
  fi
}

# 传输文件
transfer_files() {
  local source_path="$1"
  local destination_path="$2"

  ensure_directory_exists "$destination_path"
  log_info "Transferring files from ${source_path} to remote:${destination_path}..."
  scp "${source_path}" "remote:${destination_path}" || { log_error "Error: File transfer to ${remote_host} failed."; exit 1; }
  log_success "File transfer to remote server completed successfully."
  set_dir_permissions "$destination_path"
}

# 为目录设置权限
set_dir_permissions() {
  local remote_dir="$1"
  local permissions="${2:-}"
  
  if [ -z "$permissions" ]; then
    permissions="755"
  fi
  log_info "Setting file permissions for ${remote_dir} on remote host..."
  execute_command "sudo chmod -R ${permissions} ${remote_dir}" || { log_error "Error: Failed to set file permissions for ${remote_dir}."; exit 1; }
  log_success "Directory permissions for ${remote_dir} set to ${permissions} successfully."
}

# 为文件设置权限
set_file_permissions() {
  local remote_file_path="$1"
  local permissions="${2:-}"
  
  if [ -z "$permissions" ]; then
    permissions="755"
  fi
  log_info "Setting file permissions for ${remote_file_path} on remote host..."
  execute_command "sudo chmod ${permissions} ${remote_file_path}" || { log_error "Error: Failed to set file permissions for ${remote_file_path}."; exit 1; }
  log_success "File permissions for ${remote_file_path} set to ${permissions} successfully."
}

# 执行远程部署
execute_deployment() {
  local deploy_script="$1"
  local service_name="$2"
  local service_version="$3"
  local screen_name="${service_name}${service_version}"
  local command="sudo ${deploy_script} ${service_name} ${service_version}"

  if [ "$USE_SCREEN" == "yes" ]; then
    execute_inscreen "$command" "$screen_name"
 else
    execute_command "$command"
  fi
  log_success "Deployment executed successfully."
}

# 检查必需的参数
check_required_params(){
  check_param "$USE_SCREEN" "Use screen"
  check_param "$USE_JUMP_HOST" "Use jump host"
  check_param "$SSH_PRIVATE_KEY" "SSH private key"
  check_param "$SSH_HOST" "SSH host"
  check_param "$SSH_USER" "SSH user"
  check_param "$SSH_PORT" "SSH port"
  check_param "$EXECUTE_REMOTE_SCRIPT" "Execute remote script"
  check_param "$TRANSFER_FILES" "Transfer files"
}

# 设置 SSH 环境
setup_ssh(){
  ssh_init
  if [ "$USE_JUMP_HOST" == "yes" ]; then
    check_param "$JUMP_SSH_HOST" "Jump SSH host"
    check_param "$JUMP_SSH_USER" "Jump SSH user"
    check_param "$JUMP_SSH_PRIVATE_KEY" "Jump SSH private key"
    setup_ssh_key "$JUMP_SSH_PRIVATE_KEY" ~/.ssh/jump.key
    setup_ssh_key "$SSH_PRIVATE_KEY" ~/.ssh/remote.key
    setup_ssh_config "jump" "$JUMP_SSH_HOST" "$JUMP_SSH_USER" "~/.ssh/jump.key" "$JUMP_SSH_PORT"  ""
    setup_ssh_config "remote" "$SSH_HOST" "$SSH_USER" "~/.ssh/remote.key" "$SSH_PORT"  "ProxyJump jump"
  else
    setup_ssh_key "$SSH_PRIVATE_KEY" ~/.ssh/remote.key
    setup_ssh_config "remote" "$SSH_HOST" "$SSH_USER" "~/.ssh/remote.key" "$SSH_PORT"  ""
  fi
  chmod 600 ~/.ssh/config
}

# 处理文件传输
check_transfer_files(){
  if [ "$TRANSFER_FILES" == "yes" ]; then
    check_param "$SOURCE_FILE_PATH" "Source file path"
    check_param "$DESTINATION_PATH" "Destination path"
    transfer_files "$SOURCE_FILE_PATH" "$DESTINATION_PATH" "remote"
  else
    log_info "Skipping file transfer as per configuration."
  fi    
}

# 处理部署
check_execute_deployment(){
  if [ "$EXECUTE_REMOTE_SCRIPT" == "yes" ]; then
    check_param "$COPY_SCRIPT" "Copy script"
    check_param "$DEPLOY_SCRIPT" "Deploy script"

    if [ "$COPY_SCRIPT" == "yes" ]; then
      check_param "$SOURCE_SCRIPT" "Source script"
      dir="$(dirname "$DEPLOY_SCRIPT")"
      transfer_files "$SOURCE_SCRIPT" "${dir}" "remote"
    fi

    set_file_permissions "$DEPLOY_SCRIPT" 
    execute_deployment "$DEPLOY_SCRIPT" "$SERVICE_NAME" "$SERVICE_VERSION"
  else
    log_info "Skipping remote script execution as per configuration."
  fi  
}

# 主函数
main(){
  log_info "Script Version: ${MAGENTA}v0.2.0${RESET}"
  check_required_params
  setup_ssh
  check_transfer_files
  check_execute_deployment
}

main
