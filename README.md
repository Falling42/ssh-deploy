# Deploy via SSH

 [English](README.md) | [简体中文](README.CN.md)

**Deploy via SSH** is a GitHub Action for deploying applications via SSH. It supports file transfers, executing remote scripts, and allows for secure SSH connections using a jump host.

## Features

- **SSH Connection**: Connect to remote servers via SSH, with support for using a jump host.
- **File Transfer**: Transfer files from your repository to the remote server.
- **Remote Script Execution**: Execute deployment scripts on the remote server.
- **Supports `screen` Sessions**: Use `screen` to ensure deployment tasks continue even after the SSH session ends (**Ensure `screen` is installed on the remote server**).
- **Flexible Configuration**: Configure SSH settings, file transfers, and script execution through input parameters.

## Prerequisites

Before using this action, ensure that:

- The remote server can be accessed via SSH.
- If using a jump host, ensure the jump host is accessible.
- SSH public key authentication is set up on the remote server, and you have the corresponding private key.

## Input Parameters

| Input Name              | Description                                                  | Required | Default |
| ----------------------- | ------------------------------------------------------------ | -------- | ------- |
| `use_screen`            | Whether to use `screen` to execute commands (`yes` or `no`)  | No       | `no`    |
| `use_jump_host`         | Whether to use a jump host (`yes` or `no`)                   | No       | `no`    |
| `jump_ssh_host`         | The SSH host name of the jump host                           | No       |         |
| `jump_ssh_user`         | The SSH username for the jump host                           | No       |         |
| `jump_ssh_private_key`  | The SSH private key for the jump host                        | No       |         |
| `jump_ssh_port`         | The SSH port for the jump host (default: `22`)               | No       | `22`    |
| `ssh_host`              | The SSH host name of the remote server                       | Yes      |         |
| `ssh_user`              | The SSH username for the remote server                       | Yes      |         |
| `ssh_private_key`       | The SSH private key for the remote server                    | Yes      |         |
| `ssh_port`              | The SSH port for the remote server (default: `22`)           | No       | `22`    |
| `execute_remote_script` | Whether to execute a remote script (`yes` or `no`)           | No       | `no`    |
| `copy_script`           | Whether to copy a deployment script from your repository (`yes` or `no`) | No       | `no`    |
| `source_script`         | The relative path to the source script in your repository    | No       |         |
| `deploy_script`         | The full path to the deployment script on the remote server  | No       |         |
| `service_name`          | The name of the service to deploy                            | No       |         |
| `service_version`       | The version of the service to deploy                         | No       |         |
| `transfer_files`        | Whether to transfer files to the remote server (`yes` or `no`) | Yes       | `yes`   |
| `source_file_path`      | The relative path to the file to upload from the repository  | No       |         |
| `destination_path`      | The full path on the remote server to transfer the file to   | No       |         |

## Example Workflow

Here is an example of a GitHub Actions workflow using this action:

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
      # ... other jobs ...
      - name: Deploy Application via SSH
        uses: falling42/ssh-deploy@v0.1.18
        with:
          use_screen: 'yes' # Defaults to no, omit if not needed
          ssh_host: ${{ secrets.SSH_HOST }}
          ssh_user: ${{ secrets.SSH_USER }}
          ssh_private_key: ${{ secrets.SSH_PRIVATE_KEY }}
          ssh_port: 23456 # Default is 22, omit if not needed
          use_jump_host: 'no' # Defaults to no, omit if not needed
          transfer_files: 'yes' # Defaults to yes, as transferring files is a core function of this action :)
          source_file_path: './build/app.jar' # Artifact from an upstream job
          destination_path: '/var/www/app/' # Ensure the remote server has this directory
          execute_remote_script: 'yes' # Enable this for the following parameters to take effect
          copy_script: 'yes' # If disabled, the deploy_script must already exist on the remote server
          source_script: 'scripts/deploy.sh' # Ensure this file exists in your repository
          deploy_script: '/var/www/scripts/deploy.sh' # This file will be overwritten each time if copy_script is enabled
          service_name: 'my-app' # Can be hardcoded or use an upstream variable
          service_version: ${{ steps.meta.outputs.version }} # Populate from upstream variable if needed by your deploy script
```

### Using a Jump Host

If there is network instability between GitHub's servers and your target server, you can connect via a jump host by adding the following configuration:

```yaml
      - name: Deploy Application via SSH with Jump Host
        uses: falling42/ssh-deploy@v0.1.18
        with:
          use_jump_host: 'yes'
          jump_ssh_host: ${{ secrets.JUMP_SSH_HOST }}
          jump_ssh_user: ${{ secrets.JUMP_SSH_USER }}
          jump_ssh_private_key: ${{ secrets.JUMP_SSH_PRIVATE_KEY }}
          jump_ssh_port: 34567 # Default is 22, omit if not needed
          # ...
```

### Using Secrets

It is recommended to store sensitive information such as SSH keys and host details in GitHub Secrets. You can configure secrets in your repository's settings (**Settings** > **Secrets and Variables** > **Actions**). The following secrets are recommended:

| Secret Name            | Description                                                   | 
| ---------------------- | ------------------------------------------------------------- |
| `JUMP_SSH_HOST`        | SSH host IP or domain of the jump host.                        |
| `JUMP_SSH_USER`        | SSH username for the jump host.                               |
| `JUMP_SSH_PRIVATE_KEY` | SSH private key for the jump host, used for authentication.    |
| `JUMP_SSH_PORT`        | SSH port for the jump host, if you don't want your custom port to be visible to others. |
| `SSH_HOST`             | SSH host IP or domain of the target deployment server.         |
| `SSH_USER`             | SSH username for the target deployment server.                |
| `SSH_PRIVATE_KEY`      | SSH private key for the target deployment server, used for authentication. |
| `SSH_PORT`             | SSH port for the target deployment server, if you don't want your custom port to be visible to others. |
| `DEPLOY_SCRIPT`        | Full path to the deployment script on the target server, if you don't want it to be visible to others. |

## Outputs

This action does not produce any outputs at this time.

## Error Handling

If any required inputs are missing or if an SSH, SCP, or script execution command fails, the action will exit with an error. Check the logs for detailed error information.

## Security

- Ensure that sensitive data such as SSH keys and host information are stored in GitHub Secrets.
- Avoid hardcoding sensitive data directly in your workflow YAML file.
