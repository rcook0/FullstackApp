# Fullstack Mega Manager Cheat Sheet (Final)

## 1️⃣ Local Deployment
./fullstack_mega_manager.sh auto
./fullstack_mega_manager.sh auto --push "commit message"
./fullstack_mega_manager.sh auto --push "commit message" --ci

## 2️⃣ Docker Deployment
DEPLOY_MODE=docker ./fullstack_mega_manager.sh auto

## 3️⃣ MongoDB Operations
mongo fullstack_app mongo-init.js
docker exec -i fullstack-mongo mongo fullstack_app < mongo-init.js

## 4️⃣ CI/CD Workflow Integration
.github/workflows/deploy.yml

## 5️⃣ Logging
deploy.log

## 6️⃣ Flags Summary
| Flag | Description |
|------|-------------|
| --push | Push local changes |
| --ci | Trigger GitHub Actions |
| DEPLOY_MODE=docker | Docker deployment |

## 7️⃣ PDF Cheat Sheet
docs/DEPLOYMENT.md → docs/DEPLOYMENT.pdf

## 8️⃣ Git Hooks Management
| Flag        | Description |
|-------------|-------------|
| --setup     | Installs Git hooks (pre-commit, post-merge, post-checkout) without running deployment |
| --reset     | Removes old hooks and reinstalls fresh copies from setup-hooks.sh |

### Example usage:
```bash
# Install hooks only
./fullstack_mega_manager.sh --setup

# Reset hooks (remove and reinstall)
./fullstack_mega_manager.sh --reset
---

## 🚀 Running with Docker Compose

The project ships with a `docker-compose.yml` at the root for local development and quick deployments.

### Starting the stack
```sh
docker-compose up --build

---

## 🗄️ Database Management

### Backup MongoDB
```sh
./scripts/db-backup.sh

### Restore
```sh
./scripts/db-restore.sh backups/mongo_<timestamp>

# Note: Restoring will drop existing data before applying backup.
