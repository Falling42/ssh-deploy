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
TRANSFER_FILES="${TRANSFER_FILES:-}"
SOURCE_FILE_PATH="${SOURCE_FILE_PATH:-}"
DESTINATION_PATH="${DESTINATION_PATH:-}"
SERVICE_NAME="${SERVICE_NAME:-}"
SERVICE_VERSION="${SERVICE_VERSION:-}"

# 检查必需参数是否为空
check_param() {
  local param_value=$1
  local param_name=$2

  if [ -z "$param_value" ]; then
    echo "Error: $param_name is missing."
    exit 1
  fi
}

ssh_init(){
  mkdir -p ~/.ssh/
  touch ~/.ssh/config
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

  # 写入 SSH 配置
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

# 检查并安装 screen
check_and_install_screen() {
  echo "Checking if 'screen' is installed on remote host..."
  if ! eval "ssh remote command -v screen"; then
    echo "'screen' is not installed, installing now..."
    local install_cmd="if command -v apt-get >/dev/null; then sudo apt-get update && sudo apt-get install -y screen; elif command -v yum >/dev/null; then sudo yum install -y screen; else echo 'Error: Unable to install screen. Please install it manually.'; exit 1; fi"
    eval "ssh remote \"$install_cmd\" || { echo 'Error: Failed to install screen on the remote server.'; exit 1; }"
  else
    echo "'screen' is already installed."
  fi
}

# 通过 screen 执行命令
execute_command_with_screen() {
  local command="$1"
  local timestamp=$(date +'%Y%m%d%H%M%S')
  local screen_name="${timestamp}"

  if [ "$USE_SCREEN" == "yes" ]; then
    check_and_install_screen
    echo "Creating screen session: $screen_name"
    eval "ssh remote sudo screen -dmS $screen_name" || { echo "Error: Failed to create screen session."; exit 1; }
    echo "Executing command in screen: $command"
    eval "ssh remote sudo screen -S $screen_name -X stuff \"\$'$command && exit\n'\"" || { echo "Error: Failed to execute command in screen."; exit 1; }
  else
    echo "Executing command directly: $command"
    eval "ssh remote \"$command\"" || { echo "Error: Failed to execute command directly."; exit 1; }
  fi
  echo "Command executed successfully."
}

# 确保远程目录存在
ensure_directory_exists() {
  local remote_dir_path="$1"
  echo "Checking if directory ${remote_dir_path} exists on remote host..."

  # 检查远程目录是否存在
  if ! execute_command_with_screen "[ -d ${remote_dir_path} ]"; then
    echo "Directory ${remote_dir_path} does not exist. Creating it..."
    
    # 如果不存在，则创建目录
    if ! execute_command_with_screen "sudo mkdir -p ${remote_dir_path}"; then
      echo "Error: Failed to create directory ${remote_dir_path}."
      exit 1
    fi

    echo "Directory ${remote_dir_path} created successfully."
  else
    echo "Directory ${remote_dir_path} already exists."
  fi
}

# 为远程文件设置权限
set_file_permissions() {
  local remote_file_path="$1"
  echo "Setting file permissions for ${remote_file_path} on remote host..."
  execute_command_with_screen "sudo chmod -R 755 ${remote_file_path}" || { echo "Error: Failed to set file permissions for ${remote_file_path}."; exit 1; }
  echo "File permissions for ${remote_file_path} set to 755 successfully."
}

# 执行远程部署
execute_deployment() {
  local deploy_script="$1"
  local service_name="$2"
  local service_version="$3"
  local timestamp=$(date +'%Y%m%d%H%M%S')
  local screen_name="${service_name}.${service_version}.${timestamp}"
  local command="sudo ${deploy_script} ${service_name} ${service_version}"

  if [ "$USE_SCREEN" == "yes" ]; then
    check_and_install_screen
    echo "Creating screen session for deployment: $screen_name"
    eval "ssh remote sudo screen -dmS $screen_name" || { echo "Error: Failed to create screen session for deployment."; exit 1; }
    echo "Executing deployment command in screen: $command"
    eval "ssh remote sudo screen -S $screen_name -X stuff \"\$'$command && exit\n'\"" || { echo "Error: Failed to execute deployment command in screen."; exit 1; }
  else
    echo "Executing deployment command directly: $command"
    eval "ssh remote \"$command\"" || { echo "Error: Failed to execute deployment command directly."; exit 1; }
  fi
  echo "Deployment executed successfully."
}

check_required_params(){
  # 检查必须参数
  check_param "$USE_SCREEN" "Use screen"
  check_param "$USE_JUMP_HOST" "Use jump host"
  check_param "$SSH_PRIVATE_KEY" "SSH private key"
  check_param "$SSH_HOST" "SSH host"
  check_param "$SSH_USER" "SSH user"
  check_param "$SSH_PORT" "SSH port"
  check_param "$EXECUTE_REMOTE_SCRIPT" "Execute remote script"
  check_param "$TRANSFER_FILES" "Transfer files"
}

setup_ssh(){
  # 配置ssh
  ssh_init
  if [ "$USE_JUMP_HOST" == "yes" ]; then
    check_param "$JUMP_SSH_HOST" "Jump SSH host"
    check_param "$JUMP_SSH_USER" "Jump SSH user"
    check_param "$JUMP_SSH_PRIVATE_KEY" "Jump SSH private key"
    setup_ssh_key "$JUMP_SSH_PRIVATE_KEY" ~/.ssh/jump.key
    setup_ssh_config "jump" "$JUMP_SSH_HOST" "$JUMP_SSH_USER" "~/.ssh/jump.key" "$JUMP_SSH_PORT"  ""
    setup_ssh_config "remote" "$SSH_HOST" "$SSH_USER" "~/.ssh/remote.key" "$SSH_PORT"  "ProxyJump jump"
  else
    setup_ssh_key "$SSH_PRIVATE_KEY" ~/.ssh/remote.key
    setup_ssh_config "remote" "$SSH_HOST" "$SSH_USER" "~/.ssh/remote.key" "$SSH_PORT"  ""
  fi
  chmod 600 ~/.ssh/config
}

check_transfer_files(){
  # 检查是否需要传输文件
  if [ "$TRANSFER_FILES" == "yes" ]; then
    check_param "$SOURCE_FILE_PATH" "Source file path"
    check_param "$DESTINATION_PATH" "Destination path"
    
    # 使用配置文件中的主机信息传输文件
    transfer_files "$SOURCE_FILE_PATH" "$DESTINATION_PATH" "remote"
  else
    echo "Skipping transfer files as per configuration."
  fi    
}

check_execute_deployment(){
  # 检查是否执行远程脚本
  if [ "$EXECUTE_REMOTE_SCRIPT" == "yes" ]; then
    check_param "$COPY_SCRIPT" "Copy script"
    check_param "$DEPLOY_SCRIPT" "Deploy script"
    # check_param "$SERVICE_NAME" "Service name"
    # check_param "$SERVICE_VERSION" "Service version"

    if [ "$COPY_SCRIPT" == "yes" ]; then
      check_param "$SOURCE_SCRIPT" "Source script"
      ensure_directory_exists "$(dirname "$DEPLOY_SCRIPT")"
      # 复制脚本
      transfer_files "$SOURCE_SCRIPT" "$DEPLOY_SCRIPT" "remote"
    fi

    # 确保脚本具有执行权限
    set_file_permissions "$DEPLOY_SCRIPT" 
    # 执行远程部署
    execute_deployment "$DEPLOY_SCRIPT" "$SERVICE_NAME" "$SERVICE_VERSION"
  else
    echo "Skipping remote script execution as per configuration."
  fi  
}

main(){
  check_required_params
  setup_ssh
  check_transfer_files
  check_execute_deployment
}

main