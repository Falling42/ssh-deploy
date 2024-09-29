#!/bin/bash

# 从输入参数获取值
SSH_PRIVATE_KEY=$1
JUMP_SSH_HOST=$2
JUMP_SSH_USER=$3
SSH_HOST=$4
SSH_USER=$5
DEPLOY_SCRIPT=$6
SERVICE_NAME=$7
SERVICE_VERSION=$8

# 设置 SSH 配置
mkdir -p ~/.ssh/
echo "${SSH_PRIVATE_KEY}" > ~/.ssh/staging.key
chmod 600 ~/.ssh/staging.key

# 写入 SSH 配置文件
cat >>~/.ssh/config <<END
Host jump
  HostName ${JUMP_SSH_HOST}
  User ${JUMP_SSH_USER}
  IdentityFile ~/.ssh/staging.key
  StrictHostKeyChecking no
Host staging
  HostName ${SSH_HOST}
  User ${SSH_USER}
  IdentityFile ~/.ssh/staging.key
  ProxyJump jump
  StrictHostKeyChecking no
END

# 执行远程部署
TIMESTAMP=$(date +'%Y%m%d%H%M%S')
SCREEN_NAME="${SERVICE_NAME}_${SERVICE_VERSION}_${TIMESTAMP}"
SSH_CMD="ssh staging"
CREATE_SCREEN_CMD="sudo screen -dmS $SCREEN_NAME"
DEPLOY_CMD="sudo screen -S $SCREEN_NAME -X stuff \$'sudo ${DEPLOY_SCRIPT} ${SERVICE_NAME} ${SERVICE_VERSION} && exit\n'"

# 运行命令
echo "Executing create screen command: $CREATE_SCREEN_CMD"
eval "$SSH_CMD \"$CREATE_SCREEN_CMD\""

echo "Executing deploy command: $DEPLOY_CMD"
eval "$SSH_CMD \"$DEPLOY_CMD\""
