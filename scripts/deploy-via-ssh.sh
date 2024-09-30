#!/usr/bin/env bash

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
    echo "uuidgen is already installed."
    return 0  # 退出安装函数，表示已安装
  fi
  echo "uuidgen is not installed. Installing..."
  if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    if command -v apt-get &> /dev/null; then
      echo "Detected Debian/Ubuntu. Installing uuidgen..."
      sudo apt-get update
      sudo apt-get install -y uuid-runtime
    elif command -v yum &> /dev/null; then
      echo "Detected CentOS/RedHat/Fedora. Installing uuidgen..."
      sudo yum install -y util-linux
    elif command -v dnf &> /dev/null; then
      echo "Detected Fedora (dnf). Installing uuidgen..."
      sudo dnf install -y util-linux
    elif command -v pacman &> /dev/null; then
      echo "Detected Arch Linux. Installing uuidgen..."
      sudo pacman -S util-linux
    else
      echo "Unsupported Linux distribution. Please install uuidgen manually."
      exit 1
    fi
  elif [[ "$OSTYPE" == "darwin"* ]]; then
    if command -v uuidgen &> /dev/null; then
      echo "uuidgen is already installed on macOS."
    else
      echo "Installing uuidgen on macOS..."
      if ! command -v brew &> /dev/null; then
        echo "Homebrew is not installed. Installing Homebrew first..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
      fi
      echo "Installing uuidgen via Homebrew..."
      brew install coreutils
    fi
  else
    echo "Unsupported OS. Please install uuidgen manually."
    exit 1
  fi
  if command -v uuidgen &> /dev/null; then
    echo "uuidgen installation successful."
  else
    echo "uuidgen installation failed."
    exit 1
  fi
}

# 检查必需参数是否为空
check_param() {
  local param_value=$1
  local param_name=$2

  if [ -z "$param_value" ]; then
    echo "Error: $param_name is missing."
    exit 1
  else
    echo "$param_name is $param_value."
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
  chmod 600 "${key_path}" || { echo "Error: Failed to set permissions for ${key_path}."; exit 1; }
  [ ! -f "${key_path}" ] && { echo "Error: Failed to write SSH private key at ${key_path}."; exit 1; }
}

# 设置 SSH 配置文件
setup_ssh_config() {
  local host_name="$1"
  local ssh_host="$2"
  local ssh_user="$3"
  local ssh_key="$4"
  local ssh_port="${5:-22}"
  local proxy_jump="$6"

if ! grep -q "Host $host_name" ~/.ssh/config; then
  echo "Writing SSH configuration for $host_name"
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
  echo "SSH configuration for $host_name already exists."
fi
}

# 检查并安装 screen
check_and_install_screen() {
  echo "Checking if 'screen' is installed on the remote host..."
  if ssh remote "command -v screen &>/dev/null"; then
    echo "'screen' is already installed on the remote host."
  else
    echo "'screen' is not installed. Attempting to install..."
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
                 fi" || { echo "Error: Failed to install 'screen' on the remote server."; exit 1; }
    echo "'screen' installation completed on the remote host."
  fi
}

# 在screen里执行命令
execute_inscreen() {
  local command="$1"
  local screen_name="${2:-}"

  check_and_install_screen
  install_uuidgen
  screen_name="$screen_name$(uuidgen)"
  echo "Creating screen session: $screen_name"
  eval "ssh remote sudo screen -dmS $screen_name" || { echo "Error: Failed to create screen session."; exit 1; }
  echo "Executing command in screen: $command"
  eval "ssh remote sudo screen -S $screen_name -X stuff \"\$'$command && exit\n'\"" || { echo "Error: Failed to execute command in screen."; exit 1; }
  echo "Command is executing in screen. Check the screen session for any errors."
}

# 执行命令
execute_command() {
  local command="$1"

  echo "Executing command: $command"
  eval "ssh remote \"$command\"" || { echo "Error: Failed to execute command."; exit 1; }
  echo "Command executed successfully."
}

# 确保远程目录存在
ensure_directory_exists() {
  local remote_dir_path="$1"
  
  echo "Checking if directory ${remote_dir_path} exists on remote host..."
  if ! ssh remote "[ -d ${remote_dir_path} ]"; then
    echo "Directory ${remote_dir_path} does not exist. Creating it..."
    execute_command "sudo mkdir -p ${remote_dir_path}" || { echo "Error: Failed to create directory ${remote_dir_path}."; exit 1; }
    echo "Directory ${remote_dir_path} created successfully."
  else
    echo "Directory ${remote_dir_path} already exists."
  fi
}

# 传输文件
transfer_files() {
  local source_path="$1"
  local destination_path="$2"

  ensure_directory_exists "$destination_path"
  echo "Transferring files from ${source_path} to remote:${destination_path}..."
  scp "${source_path}" "remote:${destination_path}" || { echo "Error: File transfer to ${remote_host} failed."; exit 1; }
  echo "File transfer to remote server completed successfully."
  set_file_permissions "$destination_path"
}

# 为远程文件设置权限
set_file_permissions() {
  local remote_file_path="$1"
  echo "Setting file permissions for ${remote_file_path} on remote host..."
  execute_command "sudo chmod -R 755 ${remote_file_path}" || { echo "Error: Failed to set file permissions for ${remote_file_path}."; exit 1; }
  echo "File permissions for ${remote_file_path} set to 755 successfully."
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
  echo "Deployment executed successfully."
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
    set_file_permissions "$DESTINATION_PATH" 
  else
    echo "Skipping transfer files as per configuration."
  fi    
}

# 处理部署
check_execute_deployment(){
  if [ "$EXECUTE_REMOTE_SCRIPT" == "yes" ]; then
    check_param "$COPY_SCRIPT" "Copy script"
    check_param "$DEPLOY_SCRIPT" "Deploy script"

    if [ "$COPY_SCRIPT" == "yes" ]; then
      check_param "$SOURCE_SCRIPT" "Source script"
      dirname "$DEPLOY_SCRIPT"
      dir="$(dirname "$DEPLOY_SCRIPT")"
      transfer_files "$SOURCE_SCRIPT" "${dir}" "remote"
    fi

    set_file_permissions "$DEPLOY_SCRIPT" 
    execute_deployment "$DEPLOY_SCRIPT" "$SERVICE_NAME" "$SERVICE_VERSION"
  else
    echo "Skipping remote script execution as per configuration."
  fi  
}

# 主函数
main(){
  echo "v0.1.22"
  check_required_params
  setup_ssh
  check_transfer_files
  check_execute_deployment
}

main