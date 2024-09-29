# SSH Deploy GitHub Action

This Action allows you to deploy your application to a remote server via SSH using a jump host (bastion) for more secure deployment.

## Inputs

| Name              | Description                                                 | Required | Default |
| ----------------- | ----------------------------------------------------------- | -------- | ------- |
| `jump_ssh_host`   | The SSH host (jump server) for the bastion connection.      | `true`   |         |
| `jump_ssh_user`   | The SSH user for the jump host.                             | `true`   |         |
| `ssh_host`        | The destination SSH host where the application is deployed. | `true`   |         |
| `ssh_user`        | The SSH user for the destination server.                    | `true`   |         |
| `ssh_private_key` | The private SSH key used for authentication.                | `true`   |         |
| `deploy_script`   | Path to the deployment script on the remote server.         | `true`   |         |
| `service_name`    | The name of the service to be deployed.                     | `true`   |         |
| `service_version` | The version of the service to deploy.                       | `true`   |         |

## Usage Example

```yaml
name: Deploy Application

on:
  push:
    branches:
      - main

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v2

      - name: Deploy to Remote Server
        uses: your-username/your-actions-repo/ssh-deploy@v1.0.0
        with:
          jump_ssh_host: ${{ secrets.JUMP_SSH_HOST }}
          jump_ssh_user: ${{ secrets.JUMP_SSH_USER }}
          ssh_host: ${{ secrets.SSH_HOST }}
          ssh_user: ${{ secrets.SSH_USER }}
          ssh_private_key: ${{ secrets.SSH_PRIVATE_KEY }}
          deploy_script: './deploy.sh'
          service_name: 'my-app'
          service_version: '1.0.0'
```

## Secrets Configuration

For security reasons, it is recommended to store sensitive information such as the SSH private key and server credentials in GitHub Secrets.

| Secret Name       | Description                              |
| ----------------- | ---------------------------------------- |
| `JUMP_SSH_HOST`   | The SSH host (jump server) IP or domain. |
| `JUMP_SSH_USER`   | The SSH user for the jump server.        |
| `SSH_HOST`        | The SSH host where deployment occurs.    |
| `SSH_USER`        | The SSH user for the destination host.   |
| `SSH_PRIVATE_KEY` | The private SSH key for authentication.  |

### Example GitHub Secrets

To set up these secrets in your repository:

1. Navigate to your repository on GitHub.

2. Click on `Settings` > `Secrets and variables` > `Actions`.

3. Click on 

   ```
   New repository secret
   ```

    and add each of the following secrets:

   - `JUMP_SSH_HOST`
   - `JUMP_SSH_USER`
   - `SSH_HOST`
   - `SSH_USER`
   - `SSH_PRIVATE_KEY`

## How it Works

This GitHub Action performs the following steps:

1. Sets up SSH key authentication using the provided `ssh_private_key`.
2. Configures an SSH connection through a jump host.
3. Executes the provided `deploy_script` on the remote server, deploying the specified service (`service_name`) at the specified version (`service_version`).
4. The script is executed inside a new `screen` session to ensure the deployment process continues in case the SSH session is disconnected.