# 🚀 Server Bootstrap

A reusable server bootstrap toolkit for configuring fresh Ubuntu servers for Docker-based application deployments with GitHub and GitHub Actions.

The goal is to automate the repetitive steps involved when provisioning a new VPS, including:

* Updating the server
* Installing required system packages
* Installing Docker and Docker Compose
* Creating a dedicated deployment user
* Configuring SSH
* Configuring GitHub repository access
* Configuring the firewall
* Installing basic security tooling
* Preparing application directories
* Preparing the server for GitHub Actions CI/CD deployments

---

## 📁 Project Structure

```text
server-bootstrap/
├── bootstrap.sh
├── README.md
│
├── scripts/
│   ├── 01-system.sh
│   ├── 02-docker.sh
│   ├── 03-deploy-user.sh
│   ├── 04-firewall.sh
│   ├── 05-github.sh
│   └── 06-security.sh
│
├── templates/
│   ├── deploy.sh
│   └── ssh-config
│
└── examples/
    └── github-actions-deploy.yml
```

---

# 🖥️ Setting Up a New Server

## 1. Connect to the Server

Connect to the new server using SSH.

```bash
ssh root@SERVER_IP
```

Example:

```bash
ssh root@123.123.123.123
```

---

## 2. Clone the Bootstrap Repository

Clone this repository onto the server.

```bash
git clone YOUR_BOOTSTRAP_REPOSITORY
```

Then enter the directory:

```bash
cd server-bootstrap
```

> If the bootstrap repository itself is private, GitHub authentication must first be configured or the repository can temporarily be downloaded using another authenticated method.

---

## 3. Make the Scripts Executable

```bash
chmod +x bootstrap.sh
chmod +x scripts/*.sh
chmod +x templates/*.sh
```

---

## 4. Run the Bootstrap Script

Run:

```bash
sudo ./bootstrap.sh
```

The script will ask for information such as:

```text
Deployment user [deploy]:
Application name:
Application directory:
GitHub repository SSH URL:
```

Example:

```text
Deployment user [deploy]: deploy

Application name: my-app

Application directory [/var/www/my-app]:

GitHub repository SSH URL:
git@github.com:username/my-app.git
```

If the default application directory is acceptable, simply press **Enter**.

The application will then use:

```text
/var/www/my-app
```

---

# 🐳 Docker

The bootstrap process installs:

* Docker Engine
* Docker CLI
* containerd
* Docker Buildx
* Docker Compose Plugin

You can verify the installation using:

```bash
docker --version
```

and:

```bash
docker compose version
```

Docker is also configured to start automatically when the server boots.

---

# 👤 Deployment User

A dedicated deployment user is created instead of running application deployments as `root`.

The default user is:

```text
deploy
```

The user is added to the Docker group so that it can execute Docker commands.

Switch to the deployment user using:

```bash
sudo -u deploy -i
```

or:

```bash
su - deploy
```

Verify Docker access:

```bash
docker ps
```

---

# 📂 Application Directory

Applications are stored under:

```text
/var/www
```

For example:

```text
/var/www/my-app
```

Multiple applications can therefore be organized as:

```text
/var/www/
├── app-one/
├── app-two/
├── app-three/
└── app-four/
```

---

# 🔑 GitHub Repository Access

The server requires access to GitHub when cloning or pulling private repositories.

The bootstrap process generates an SSH key for this purpose.

The public key will be displayed after setup.

It can also be viewed manually using:

```bash
cat /home/deploy/.ssh/github_repo.pub
```

Copy the complete output.

---

## Add the Key to GitHub

Open the application repository on GitHub.

Navigate to:

```text
Repository
    ↓
Settings
    ↓
Deploy keys
    ↓
Add deploy key
```

Give the key a descriptive name such as:

```text
Production Server
```

Paste the public key.

### Important

Do **not** enable:

```text
Allow write access
```

The production server normally only needs permission to clone and pull code.

---

# 🧪 Test GitHub Access

Switch to the deployment user:

```bash
sudo -u deploy -i
```

Then run:

```bash
ssh -T git@github.com
```

A successful connection should return a GitHub authentication message.

---

# 📥 Clone the Application

Switch to the deployment user:

```bash
sudo -u deploy -i
```

Navigate to:

```bash
cd /var/www
```

Clone the application:

```bash
git clone git@github.com:USERNAME/REPOSITORY.git
```

Example:

```bash
git clone git@github.com:username/my-app.git
```

Then enter the application:

```bash
cd my-app
```

---

# ⚙️ Production Environment

Create the production environment file:

```bash
nano .env.prod
```

Add the required application configuration.

For example:

```env
APP_ENV=production
DEBUG=false

DATABASE_HOST=postgres
DATABASE_NAME=myapp
DATABASE_USER=myapp
DATABASE_PASSWORD=CHANGE_ME
```

> Never commit `.env.prod` or production credentials to Git.

---

# 🚀 Starting the Application

If the application contains a Docker Compose configuration, start it with:

```bash
docker compose --env-file .env.prod up -d --build
```

Check running containers:

```bash
docker ps
```

Check the application logs:

```bash
docker compose logs -f
```

---

# 🔄 Deployment Script

Applications can use the provided deployment script:

```text
templates/deploy.sh
```

A typical deployment performs:

```text
GitHub
   ↓
git pull
   ↓
Docker build
   ↓
Docker Compose
   ↓
New containers
```

Example:

```bash
./deploy.sh /var/www/my-app
```

The deployment script will:

1. Navigate to the application directory
2. Fetch the latest code
3. Pull the latest `main` branch
4. Rebuild Docker containers
5. Restart the application
6. Remove unused Docker images

---

# 🔁 GitHub Actions CI/CD

GitHub Actions can automatically deploy the application whenever code is pushed to the `main` branch.

An example workflow is available at:

```text
examples/github-actions-deploy.yml
```

Copy it into the application repository as:

```text
.github/workflows/deploy.yml
```

---

# 🔐 GitHub Actions Deployment Key

GitHub Actions needs permission to connect **to the server**.

This is separate from the SSH key the server uses to access GitHub.

The two authentication flows are:

```text
Server → GitHub

Used for:
git clone
git pull

Key:
github_repo
```

and:

```text
GitHub Actions → Server

Used for:
automatic deployments

Key:
DEPLOY_SSH_KEY
```

Do not reuse the same private key for both purposes.

---

# 🔑 Generate the CI/CD Deployment Key

Generate this key from a trusted machine:

```bash
ssh-keygen -t ed25519 -C "github-actions-deploy" -f deploy_key
```

This creates:

```text
deploy_key
deploy_key.pub
```

The files have different purposes.

### Private key

```text
deploy_key
```

This goes into GitHub Actions Secrets.

### Public key

```text
deploy_key.pub
```

This goes onto the server.

---

# 🖥️ Add GitHub Actions Access to the Server

Copy the contents of:

```text
deploy_key.pub
```

Add it to:

```text
/home/deploy/.ssh/authorized_keys
```

For example:

```bash
nano /home/deploy/.ssh/authorized_keys
```

Make sure permissions are correct:

```bash
chmod 700 /home/deploy/.ssh
chmod 600 /home/deploy/.ssh/authorized_keys
chown -R deploy:deploy /home/deploy/.ssh
```

---

# 🔒 GitHub Actions Secrets

Open the application repository and navigate to:

```text
Repository
    ↓
Settings
    ↓
Secrets and variables
    ↓
Actions
```

Create the following repository secrets:

```text
DEPLOY_HOST
DEPLOY_USER
DEPLOY_PATH
DEPLOY_SSH_KEY
```

---

## DEPLOY_HOST

The server IP address or hostname.

Example:

```text
123.123.123.123
```

---

## DEPLOY_USER

The deployment user.

Usually:

```text
deploy
```

---

## DEPLOY_PATH

The location of the application.

Example:

```text
/var/www/my-app
```

---

## DEPLOY_SSH_KEY

The **private** deployment key generated earlier.

It should look similar to:

```text
-----BEGIN OPENSSH PRIVATE KEY-----
...
-----END OPENSSH PRIVATE KEY-----
```

Never commit this key to the repository.

---

# 🔄 Deployment Flow

Once CI/CD is configured, deployments follow this flow:

```text
Developer
    │
    │ git push
    ▼
GitHub
    │
    ▼
GitHub Actions
    │
    │ SSH
    ▼
Production Server
    │
    ▼
/var/www/my-app
    │
    ├── git pull
    │
    ├── docker compose build
    │
    └── docker compose up
    │
    ▼
Updated Application
```

A normal deployment therefore becomes:

```bash
git add .
git commit -m "Update application"
git push
```

GitHub Actions handles the production deployment.

---

# 🔥 Firewall

The bootstrap script configures UFW.

The following ports are allowed:

| Port  | Purpose |
| ----- | ------- |
| `22`  | SSH     |
| `80`  | HTTP    |
| `443` | HTTPS   |

Check firewall status:

```bash
sudo ufw status
```

---

# 🛡️ Security

The bootstrap process installs and enables:

```text
fail2ban
```

Check its status:

```bash
sudo systemctl status fail2ban
```

Additional SSH hardening can be performed after confirming that SSH key authentication works correctly.

Avoid disabling password or root authentication until another working SSH session has been tested.

---

# 🔍 Useful Commands

## Running containers

```bash
docker ps
```

## All containers

```bash
docker ps -a
```

## Application logs

```bash
docker compose logs -f
```

## Restart containers

```bash
docker compose restart
```

## Stop application

```bash
docker compose down
```

## Rebuild application

```bash
docker compose --env-file .env.prod up -d --build
```

## Docker disk usage

```bash
docker system df
```

## Remove unused images

```bash
docker image prune
```

## Check firewall

```bash
sudo ufw status
```

## Check Docker

```bash
sudo systemctl status docker
```

## Check Fail2ban

```bash
sudo systemctl status fail2ban
```

---

# ⚠️ Secrets

Never commit any of the following to this repository:

```text
.env
.env.prod
*.pem
*.key
deploy_key
SSH private keys
database passwords
API keys
GitHub tokens
server credentials
```

Only public SSH keys may safely be shared when required.

Consider adding the following to `.gitignore`:

```gitignore
.env
.env.*
!.env.example

*.pem
*.key

deploy_key
deploy_key.*

secrets/
credentials/
```

---

# 🆕 New Server Checklist

For a completely new server:

```text
[ ] Create VPS
[ ] SSH into server
[ ] Clone server-bootstrap
[ ] Run bootstrap.sh
[ ] Add generated server deploy key to GitHub
[ ] Test server → GitHub SSH
[ ] Clone application into /var/www
[ ] Create .env.prod
[ ] Start Docker application
[ ] Generate GitHub Actions deployment key
[ ] Add public deployment key to server
[ ] Add GitHub Actions secrets
[ ] Add deploy.yml to application repository
[ ] Push to main
[ ] Verify automatic deployment
[ ] Configure domain DNS
[ ] Configure HTTPS/reverse proxy
[ ] Verify firewall
[ ] Verify backups
```

---

# 🎯 Goal

The objective of this repository is to make provisioning a new server predictable and repeatable.

Instead of repeatedly searching for Docker installation commands, SSH configuration, GitHub deploy keys, firewall rules, and CI/CD configuration, a new server should require approximately:

```bash
ssh root@SERVER_IP

git clone YOUR_BOOTSTRAP_REPOSITORY

cd server-bootstrap

chmod +x bootstrap.sh scripts/*.sh

sudo ./bootstrap.sh
```

After that, only application-specific configuration such as environment variables, domains, DNS, and application-specific Docker configuration should need to be provided.
