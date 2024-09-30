# Deploy via SSH

 [English](README.md) | [简体中文](README.CN.md)

**Deploy via SSH** 是一个通过 SSH 部署应用的 GitHub Action。它支持文件传输、执行远程脚本，并可以使用跳板机进行安全的 SSH 连接。

## 功能特点

- **SSH 连接**：通过 SSH 连接到远程服务器，支持使用跳板机连接。
- **文件传输**：可以从您的仓库将文件传输到远程服务器。
- **远程脚本执行**：在远程服务器上执行部署脚本。
- **支持 `screen` 会话**：使用 `screen` 确保即使 SSH 会话结束后，部署任务仍然继续执行（**请确保远程服务器已经安装`screen`**）。
- **灵活配置**：通过输入参数配置 SSH 设置、文件传输和脚本执行。

## 必要条件

在使用此 Action 之前，您需要确保：

- 远程服务器可以通过 SSH 访问。
- 如果使用跳板机（Jump Host），确保跳板机也可以访问。
- 远程服务器上已配置 SSH 公钥认证，并且您拥有相应的私钥。

## 输入参数

| 输入名称                | 描述                                         | 是否必需 | 默认值 |
| ----------------------- | -------------------------------------------- | -------- | ------ |
| `use_screen`            | 是否使用`screen`执行命令 (`yes` 或 `no`)     | 否       | `no`   |
| `use_jump_host`         | 是否使用跳板机 (`yes` 或 `no`)               | 否       | `no`   |
| `jump_ssh_host`         | 跳板机的 SSH 主机名                          | 否       |        |
| `jump_ssh_user`         | 跳板机的 SSH 用户名                          | 否       |        |
| `jump_ssh_private_key`  | 跳板机的 SSH 私钥                            | 否       |        |
| `jump_ssh_port`         | 跳板机的 SSH 端口 (默认值为 `22`)            | 否       | `22`   |
| `ssh_host`              | 远程服务器的 SSH 主机名                      | 是       |        |
| `ssh_user`              | 远程服务器的 SSH 用户名                      | 是       |        |
| `ssh_private_key`       | 远程服务器的 SSH 私钥                        | 是       |        |
| `ssh_port`              | 远程服务器的 SSH 端口 (默认值为 `22`)        | 否       | `22`   |
| `execute_remote_script` | 是否执行远程脚本 (`yes` 或 `no`)             | 否       | `no`   |
| `copy_script`           | 是否从您的仓库中复制部署脚本 (`yes` 或 `no`) | 否       | `no`   |
| `source_script`         | 仓库中源脚本的相对路径                       | 否       |        |
| `deploy_script`         | 远程服务器上部署脚本的完整路径               | 否       |        |
| `service_name`          | 要部署的服务名称                             | 否       |        |
| `service_version`       | 要部署的服务版本                             | 否       |        |
| `transfer_files`        | 是否将文件传输到远程服务器 (`yes` 或 `no`)   | 否       | `yes`  |
| `source_file_path`      | 要上传的文件在仓库中的相对路径               | 否       |        |
| `destination_path`      | 远程服务器上要传输文件的完整路径             | 否       |        |

## 示例工作流

以下是一个使用此 Action 的 GitHub Actions 工作流示例：

```yaml
name: Deploy to Remote Server

on:
  push:
    branches:
      - main

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      # ... your other jobs ...
      - name: Deploy Application via SSH
        uses: falling42/ssh-deploy@v0.1.18
        with:
          use_screen: 'yes' #默认 no 不需要不填即可
          ssh_host: ${{ secrets.SSH_HOST }}
          ssh_user: ${{ secrets.SSH_USER }}
          ssh_private_key: ${{ secrets.SSH_PRIVATE_KEY }}
          ssh_port: 23456 # 默认22，可不填
          use_jump_host: 'no' # 默认为no，不需要不填即可
          transfer_files: 'yes' # 默认为yes，也即必须传输文件，不然你用这个action干什么 :)
          source_file_path: './build/app.jar' # 上游job构建出的工件
          destination_path: '/var/www/app/' # 请确保远程服务器有此目录
          execute_remote_script: 'yes' # 必须开启此项下面所有参数才有效
          copy_script: 'yes' # 不开启此项需要你的远程服务器存在deploy_script文件
          source_script: 'scripts/deploy.sh' # 需要你的仓库存在这个文件
          deploy_script: '/var/www/scripts/deploy.sh' # 当不开启copy_script时请注意填入的文件需要存在，否则请注意每次运行action都会覆盖这个文件
          service_name: 'my-app' # 直接写/填入你的上游变量，是否填入此项取决于你的deploy.sh是否需要此参数
          service_version: ${{ steps.meta.outputs.version }} # 填入你的上游变量，是否填入此项取决于你的deploy.sh是否需要此参数
```

### 使用跳板机

如果Github的服务器到您的服务器的网络波动较大可以通过跳板机连接，只需添加以下配置：

```yaml
      - name: Deploy Application via SSH with Jump Host
        uses: falling42/ssh-deploy@v0.1.18
        with:
          use_jump_host: 'yes'
          jump_ssh_host: ${{ secrets.JUMP_SSH_HOST }}
          jump_ssh_user: ${{ secrets.JUMP_SSH_USER }}
          jump_ssh_private_key: ${{ secrets.JUMP_SSH_PRIVATE_KEY }}
          jump_ssh_port: 34567 # 默认22，可不填
          # ...
```

### 使用 Secrets

建议使用 GitHub Secrets 来存储敏感信息，如 SSH 密钥和主机信息。您可以在仓库的设置中配置 Secrets（**Settings** > **Secrets and Variables** > **Actions**）。以下是建议您在仓库中配置的 secrets 列表：

| Secret 名称            | 描述                                                         |
| ---------------------- | ------------------------------------------------------------ |
| `JUMP_SSH_HOST`        | 跳板机的 SSH 主机 IP 或域名。                                |
| `JUMP_SSH_USER`        | 跳板机的 SSH 用户名。                                        |
| `JUMP_SSH_PRIVATE_KEY` | 跳板机的 SSH 私钥，用于认证。                                |
| `JUMP_SSH_PORT`        | 跳板机的 SSH 端口，如果你不希望你的自定义端口被别人看到。    |
| `SSH_HOST`             | 部署的目标服务器的 SSH 主机 IP 或域名。                      |
| `SSH_USER`             | 目标服务器的 SSH 用户名。                                    |
| `SSH_PRIVATE_KEY`      | 目标服务器的 SSH 私钥，用于认证。                            |
| `SSH_PORT`             | 目标服务器的 SSH 端口，如果你不希望你的自定义端口被别人看到。 |
| `DEPLOY_SCRIPT`        | 目标服务器的部署脚本完整路径，如果你不希望它被别人看到       |

## 输出

此 Action 目前没有输出值。

## 错误处理

如果任何必需输入缺失，或 SSH、SCP 或脚本执行命令失败，操作将失败并退出。请检查日志以获取详细的错误信息。

## 安全性

- 确保将 SSH 密钥和主机信息等敏感数据存储在 GitHub Secrets 中。
- 避免在工作流 YAML 文件中直接硬编码敏感数据。
