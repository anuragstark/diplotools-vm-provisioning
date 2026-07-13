<<<<<<< HEAD
# Ironman VM Provisioning Architecture

This repository contains a robust, scalable, and fully automated deployment architecture for the Ironman Node.js Application using **AWS EC2**, **Terraform**, **Docker Compose**, and **GitHub Actions**.

## Architecture Overview

The architecture embraces a **Mutable Infrastructure via Orchestration** pattern. Instead of baking new Amazon Machine Images (AMIs) on every application update or relying on vulnerable SSH scripts, this architecture securely pushes orchestration updates directly to running instances using **AWS Systems Manager (SSM)**.

### Core Technologies
- **Infrastructure as Code**: Terraform
- **Compute Engine**: AWS EC2 (Ubuntu 22.04)
- **Containerization**: Docker & Docker Compose V2
- **Reverse Proxy**: Nginx
- **Container Registry**: Amazon Elastic Container Registry (ECR)
- **CI/CD Pipelines**: GitHub Actions

---

## Request Flow & Nginx Reverse Proxy

To understand how a user request reaches the application, here is the exact traffic flow:

1. **User Request**: A user enters the EC2 instance's Public IP address (or domain name) into their browser.
2. **AWS Security Group**: The request hits the AWS EC2 Security Group. The firewall rules explicitly allow inbound traffic *only* on port `80` (HTTP) and `443` (HTTPS). All other ports (including SSH on port `22`) are strictly blocked.
3. **Nginx Reverse Proxy**: The request reaches the Docker Compose network, where the Nginx container is listening on port `80`. Nginx acts as the entry point (reverse proxy) for all traffic.
4. **Load Balancing**: Nginx receives the request and proxies it to the backend Node.js containers (`backend-a`, `backend-b`, `backend-c`). Because Nginx is defined in the same Docker network (`app_network`), it natively load-balances requests across these three containers in a round-robin fashion.
5. **Application Response**: The backend container processes the request, injects its specific container ID/name into the HTML response, and sends it back through Nginx to the user's browser.

---

## Request Flow & Nginx Reverse Proxy

To understand how a user request reaches the application, here is the exact traffic flow:

1. **User Request**: A user enters the EC2 instance's Public IP address (or domain name) into their browser.
2. **AWS Security Group**: The request hits the AWS EC2 Security Group. The firewall rules explicitly allow inbound traffic *only* on port `80` (HTTP) and `443` (HTTPS). All other ports (including SSH on port `22`) are strictly blocked.
3. **Nginx Reverse Proxy**: The request reaches the Docker Compose network, where the Nginx container is listening on port `80`. Nginx acts as the entry point (reverse proxy) for all traffic.
4. **Load Balancing**: Nginx receives the request and proxies it to the backend Node.js containers (`backend-a`, `backend-b`, `backend-c`). Because Nginx is defined in the same Docker network (`app_network`), it natively load-balances requests across these three containers in a round-robin fashion.
5. **Application Response**: The backend container processes the request, injects its specific container ID/name into the HTML response, and sends it back through Nginx to the user's browser.

---

## Security & Environment Isolation

### Strict IAM Boundaries
No SSH keys are generated or stored in GitHub Secrets. The CI/CD pipelines authenticate with AWS securely using OpenID Connect (OIDC). All remote command execution is brokered securely via the **AWS SSM Agent**. 

The EC2 instance is attached to a dedicated IAM Instance Profile (`ironman-app-profile`) that explicitly grants read-only access to ECR and core capabilities for SSM.

### Environment Namespacing
The architecture supports completely isolated environments (e.g., `staging` and `dev`). 
- **Terraform Workspaces**: Infrastructure is separated into Terraform Workspaces (`staging` vs `dev`).
- **ECR Isolation**: Docker images are pushed to explicitly namespaced repositories (`ironman-app-staging`, `ironman-app-dev`) to guarantee that a bad push to a lower environment cannot overwrite production images.
- **Dynamic Configuration**: `docker-compose.yml` uses environment variable interpolation (`${ENV_NAME}`) to seamlessly adapt to its deployed environment.

---

## CI/CD Pipelines

### 1. Infrastructure Pipeline (`deploy-infra.yml`)
Triggers automatically when changes are pushed to the `terraform/**` directory.
- Initializes Terraform and automatically selects the workspace based on the Git branch (`main` -> `staging`, `dev` -> `dev`).
- Provisions the Security Group, IAM Roles, and EC2 Instance.
- Injects the environment-specific `cloud-init` file (`dev.yml` or `staging.yml`) as `user_data`.
- **Note**: Modifying a `cloud-init` file forces Terraform to gracefully tear down and recreate the EC2 instance to guarantee state consistency (`user_data_replace_on_change = true`).

### 2. Application Pipeline (`deploy-app.yml`)
Triggers automatically when changes are pushed to the `app/**` or `docker-compose.yml` paths.
- Builds the Node.js application and tags it strictly with the **Git SHA** (avoiding mutable `latest` tags for guaranteed rollback capabilities).
- Pushes the image to the namespaced ECR repository.
- Uses `aws ssm send-command` to securely transfer Base64-encoded orchestration files (`docker-compose.yml`, `nginx.conf`, `bootstrap-app.sh`) to the EC2 instance.
- Executes `bootstrap-app.sh` natively on the EC2 instance to seamlessly pull the new Docker images and perform a zero-downtime rolling restart via `docker compose up -d`.

---

## ⚙️ Server Bootstrapping (Cloud-Init)

When Terraform spins up a new EC2 instance, the AWS `cloud-init` process automatically provisions the server on first boot:
- Installs critical dependencies (`docker.io`, `awscli`, `docker-compose-v2`).
- Creates the necessary deployment directories and handles filesystem permissions.
- Prepares the server to accept application deployments via SSM.

---

## Setup Instructions

To deploy this architecture from scratch in your own AWS account, you must configure GitHub Actions to authenticate with AWS via **OpenID Connect (OIDC)**. 

### 1. Configure AWS OIDC Identity Provider
1. Go to the AWS IAM Console -> **Identity providers** -> Add provider.
2. Select **OpenID Connect**.
3. Provider URL: `https://token.actions.githubusercontent.com`
4. Audience: `sts.amazonaws.com`

### 2. Create the AWS IAM Role
1. Create a new IAM Role in AWS and select **Web identity**.
2. Choose the GitHub OIDC provider you just created.
3. Attach the necessary permissions to this role so Terraform and GitHub Actions can provision resources. At minimum, it needs:
   - `AmazonEC2FullAccess`
   - `AmazonEC2ContainerRegistryFullAccess`
   - `IAMFullAccess` (to create the EC2 Instance Profile)
   - `AmazonSSMFullAccess` (to send commands)
4. Edit the **Trust Relationship** of the role to restrict it to your specific GitHub repository:
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::<YOUR_ACCOUNT_ID>:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:<YOUR_GITHUB_USERNAME>/<YOUR_REPO_NAME>:*"
        },
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        }
      }
    }
  ]
}
```

### 3. Configure GitHub Secrets
Go to your GitHub Repository -> **Settings** -> **Secrets and variables** -> **Actions**.
- Create a new Repository Secret named `AWS_ROLE_ARN`.
- Set the value to the ARN of the IAM Role you created in Step 2 (e.g., `arn:aws:iam::123456783535:role/GitHubActionsRole`).

Once this is configured, any pushes to `dev` or `main` will automatically trigger the infrastructure and application pipelines securely without needing long-lived AWS Access Keys!

---

## Local Development

To run the application stack locally for development:
```bash
# Export dummy environment variables for local testing
export ECR_REGISTRY=local
export ENV_NAME=local
export IMAGE_TAG=latest

# Build and start the containers
docker compose up --build
```

---

## Author

**Anurag Stark**
- LinkedIn: [linkedin.com/in/anuragstark](https://www.linkedin.com/in/anuragstark/)
- GitHub: [github.com/anuragstark](https://github.com/anuragstark)
=======
# Ironman VM Provisioning Architecture

This repository contains a robust, scalable, and fully automated deployment architecture for the Ironman Node.js Application using **AWS EC2**, **Terraform**, **Docker Compose**, and **GitHub Actions**.

## Architecture Overview

The architecture embraces a **Mutable Infrastructure via Orchestration** pattern. Instead of baking new Amazon Machine Images (AMIs) on every application update or relying on vulnerable SSH scripts, this architecture securely pushes orchestration updates directly to running instances using **AWS Systems Manager (SSM)**.

### Core Technologies
- **Infrastructure as Code**: Terraform
- **Compute Engine**: AWS EC2 (Ubuntu 22.04)
- **Containerization**: Docker & Docker Compose V2
- **Reverse Proxy**: Nginx
- **Container Registry**: Amazon Elastic Container Registry (ECR)
- **CI/CD Pipelines**: GitHub Actions

---

## Request Flow & Nginx Reverse Proxy

To understand how a user request reaches the application, here is the exact traffic flow:

1. **User Request**: A user enters the EC2 instance's Public IP address (or domain name) into their browser.
2. **AWS Security Group**: The request hits the AWS EC2 Security Group. The firewall rules explicitly allow inbound traffic *only* on port `80` (HTTP) and `443` (HTTPS). All other ports (including SSH on port `22`) are strictly blocked.
3. **Nginx Reverse Proxy**: The request reaches the Docker Compose network, where the Nginx container is listening on port `80`. Nginx acts as the entry point (reverse proxy) for all traffic.
4. **Load Balancing**: Nginx receives the request and proxies it to the backend Node.js containers (`backend-a`, `backend-b`, `backend-c`). Because Nginx is defined in the same Docker network (`app_network`), it natively load-balances requests across these three containers in a round-robin fashion.
5. **Application Response**: The backend container processes the request, injects its specific container ID/name into the HTML response, and sends it back through Nginx to the user's browser.

---

## Security & Environment Isolation

### Strict IAM Boundaries
No SSH keys are generated or stored in GitHub Secrets. The CI/CD pipelines authenticate with AWS securely using OpenID Connect (OIDC). All remote command execution is brokered securely via the **AWS SSM Agent**. 

The EC2 instance is attached to a dedicated IAM Instance Profile (`ironman-app-profile`) that explicitly grants read-only access to ECR and core capabilities for SSM.

### Environment Namespacing
The architecture supports completely isolated environments (e.g., `staging` and `dev`). 
- **Terraform Workspaces**: Infrastructure is separated into Terraform Workspaces (`staging` vs `dev`).
- **ECR Isolation**: Docker images are pushed to explicitly namespaced repositories (`ironman-app-staging`, `ironman-app-dev`) to guarantee that a bad push to a lower environment cannot overwrite production images.
- **Dynamic Configuration**: `docker-compose.yml` uses environment variable interpolation (`${ENV_NAME}`) to seamlessly adapt to its deployed environment.

### Troubleshooting (No SSH Required)
Even though Port 22 is blocked, you can still securely troubleshoot the EC2 instance using **AWS SSM Session Manager**.

*Note: If using the CLI on a Mac, you must first install the SSM plugin: `brew install --cask session-manager-plugin`*

If you only have the IP address, you can find your Instance ID by running:
```bash
aws ec2 describe-instances \
  --filters "Name=ip-address,Values=<YOUR_EC2_IP>" \
  --query "Reservations[*].Instances[*].InstanceId" \
  --output text
```

- **Interactive Shell**: You can drop into a live, secure bash terminal directly from your browser by navigating to the **AWS EC2 Console -> Connect -> Session Manager**. Alternatively, run this from your terminal using the AWS CLI:
  ```bash
  aws ssm start-session --target <YOUR_EC2_INSTANCE_ID>
  ```
- **One-Off Commands**: If you just need to grab logs without opening a shell, you can send remote commands via SSM:
  ```bash
  aws ssm send-command \
    --instance-ids "<YOUR_EC2_INSTANCE_ID>" \
    --document-name "AWS-RunShellScript" \
    --parameters 'commands=["docker logs proxy --tail 50"]'
  ```

---

## CI/CD Pipelines

### 1. Infrastructure Pipeline (`deploy-infra.yml`)
Triggers automatically when changes are pushed to the `terraform/**` directory.
- Initializes Terraform and automatically selects the workspace based on the Git branch (`main` -> `staging`, `dev` -> `dev`).
- Provisions the Security Group, IAM Roles, and EC2 Instance.
- Injects the environment-specific `cloud-init` file (`dev.yml` or `staging.yml`) as `user_data`.
- **Note**: Modifying a `cloud-init` file forces Terraform to gracefully tear down and recreate the EC2 instance to guarantee state consistency (`user_data_replace_on_change = true`).

### 2. Application Pipeline (`deploy-app.yml`)
Triggers automatically when changes are pushed to the `app/**` or `docker-compose.yml` paths.
- Builds the Node.js application and tags it strictly with the **Git SHA** (avoiding mutable `latest` tags for guaranteed rollback capabilities).
- Pushes the image to the namespaced ECR repository.
- Uses `aws ssm send-command` to securely transfer Base64-encoded orchestration files (`docker-compose.yml`, `nginx.conf`, `bootstrap-app.sh`) to the EC2 instance.
- Executes `bootstrap-app.sh` natively on the EC2 instance to seamlessly pull the new Docker images and perform a zero-downtime rolling restart via `docker compose up -d`.

---

##  Server Bootstrapping (Cloud-Init)

When Terraform spins up a new EC2 instance, the AWS `cloud-init` process automatically provisions the server on first boot:
- Installs critical dependencies (`docker.io`, `awscli`, `docker-compose-v2`).
- Creates the necessary deployment directories and handles filesystem permissions.
- Prepares the server to accept application deployments via SSM.

---

## Setup Instructions

To deploy this architecture from scratch in your own AWS account, you must configure GitHub Actions to authenticate with AWS via **OpenID Connect (OIDC)**. 

### 1. Configure AWS OIDC Identity Provider
1. Go to the AWS IAM Console -> **Identity providers** -> Add provider.
2. Select **OpenID Connect**.
3. Provider URL: `https://token.actions.githubusercontent.com`
4. Audience: `sts.amazonaws.com`

### 2. Create the AWS IAM Role
1. Create a new IAM Role in AWS and select **Web identity**.
2. Choose the GitHub OIDC provider you just created.
3. Attach the necessary permissions to this role so Terraform and GitHub Actions can provision resources. At minimum, it needs:
   - `AmazonEC2FullAccess`
   - `AmazonEC2ContainerRegistryFullAccess`
   - `IAMFullAccess` (to create the EC2 Instance Profile)
   - `AmazonSSMFullAccess` (to send commands)
4. Edit the **Trust Relationship** of the role to restrict it to your specific GitHub repository:
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::<YOUR_ACCOUNT_ID>:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:<YOUR_GITHUB_USERNAME>/<YOUR_REPO_NAME>:*"
        },
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        }
      }
    }
  ]
}
```

### 3. Configure GitHub Secrets
Go to your GitHub Repository -> **Settings** -> **Secrets and variables** -> **Actions**.
- Create a new Repository Secret named `AWS_ROLE_ARN`.
- Set the value to the ARN of the IAM Role you created in Step 2 (e.g., `arn:aws:iam::123456783535:role/GitHubActionsRole`).

Once this is configured, any pushes to `dev` or `main` will automatically trigger the infrastructure and application pipelines securely without needing long-lived AWS Access Keys!

---

## Local Development

To run the application stack locally for development:
```bash
# Export dummy environment variables for local testing
export ECR_REGISTRY=local
export ENV_NAME=local
export IMAGE_TAG=latest

# Build and start the containers
docker compose up --build
```

---

## Author

**Anurag Stark**
- LinkedIn: [linkedin.com/in/anuragstark](https://www.linkedin.com/in/anuragstark/)
- GitHub: [github.com/anuragstark](https://github.com/anuragstark)
>>>>>>> main
