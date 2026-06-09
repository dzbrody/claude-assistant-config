# Developer Onboarding & Repositories

> **Status:** Active · Axina Group Inc. Engineering
> **Maintainer:** VP Engineering / CTO
> **Last Reviewed:** 2026-05-17

[TOC]

---

## 1. Welcome to AXERP Engineering

AXERP is built on the [Frappe Framework](https://frappeframework.com/) and [ERPNext](https://erpnext.com/). If you are new to Frappe, read the [Frappe Developer Docs](https://frappeframework.com/docs) before diving in. This guide covers everything from getting your local environment running to understanding how the GitHub repositories connect to production.

---

## 2. Repository Map

| Repository | GitHub URL | Purpose |
|---|---|---|
| `axerp` | https://github.com/axinagroup/axerp | Core custom Frappe app — all AXERP DocTypes, controllers, APIs, custom scripts |
| `xgc_docker` | https://github.com/XGCERP/xgc_docker | Docker Compose / production container configurations (upstream: frappe_docker) |
| `terra-ecs-africa-aws` | https://github.com/orgs/XGCERP/repositories | Terraform for AWS af-south-1 production stack |
| `terra-ecs-us-east` | https://github.com/orgs/XGCERP/repositories | Terraform for AWS us-east-1 DR stack |
| `terraform-shared-modules` | https://github.com/orgs/XGCERP/repositories | Shared Terraform modules (VPC, ECS, RDS, Redis, ALB) |
| `carbonblockchain` | https://github.com/orgs/XGCERP/repositories | Solidity smart contracts, Hyperledger chaincode, blockchain node configs |

---

## 3. Local Development Environment Setup

### 3.1 Prerequisites (macOS)

```bash
# Install Homebrew (if not installed)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install required packages
brew install python@3.11 node redis mariadb@10.6 yarn supervisor

# Set environment variables — add to ~/.zshrc
export PATH="/usr/local/opt/python@3.11/bin:/usr/local/opt/mariadb@10.6/bin:$PATH"
export LDFLAGS="-L/usr/local/opt/mariadb@10.6/lib"
export CPPFLAGS="-I/usr/local/opt/mariadb@10.6/include"
export PKG_CONFIG_PATH="/usr/local/opt/mariadb@10.6/lib/pkgconfig"

source ~/.zshrc

# Start services
brew services start mariadb@10.6
brew services start redis
```

### 3.2 Install Frappe Bench

```bash
# Create a Python virtual environment
python3 -m venv ~/frappe-bench-env
source ~/frappe-bench-env/bin/activate

# Install Bench CLI
pip install --upgrade pip
pip install frappe-bench

# Initialise a bench directory
mkdir ~/frappe-bench && cd ~/frappe-bench
bench init --skip-redis-config-generation --frappe-branch version-16 frappe-bench
cd frappe-bench
```

### 3.3 Add the AXERP App

```bash
# Clone the core AXERP app
bench get-app --branch main https://github.com/axinagroup/axerp

# Clone ERPNext (upstream base)
bench get-app --branch version-16 erpnext

# Optional: additional Frappe apps
bench get-app --branch version-16 https://github.com/frappe/hrms
bench get-app --branch main https://github.com/frappe/crm
bench get-app --branch main https://github.com/frappe/print_designer
```

### 3.4 Create and Configure a Local Site

```bash
# Create site
bench new-site axerp.local

# Install apps on site
bench --site axerp.local install-app erpnext
bench --site axerp.local install-app axerp
bench --site axerp.local install-app hrms   # optional

# Add site to hosts file
sudo bash -c 'echo "127.0.0.1 axerp.local" >> /etc/hosts'

# Enable live reload (optional, dev convenience)
bench set-config -g live_reload true

# Start the development server
bench start
```

Access your local site at: **http://axerp.local:8000**
Default admin: `Administrator` / password set during `bench new-site`.

---

## 4. Repository Workflow — `axerp` App

### 4.1 Syncing Upstream (ERPNext / Frappe)

The `axerp` app forks from ERPNext. To pull in upstream changes:

```bash
# In apps/axerp/
git remote add upstream https://github.com/frappe/erpnext.git
git fetch upstream
git merge upstream/version-16   # or rebase
git push origin main
```

For `xgc_docker`:

```bash
# In xgc_docker/
git remote add upstream https://github.com/frappe/frappe_docker.git
git fetch upstream
git merge upstream/main
git push origin main
```

### 4.2 Feature Branch Workflow

```
main ──────────────────────────────────────► (production)
  │
  └─► develop ────────────────────────────► (staging auto-deploy)
            │
            └─► feature/AXERP-<ticket-id>  (your work)
                  └─► PR to develop
                        └─► code review + CI pass
                              └─► merge to develop
```

**Branch naming:**
- Features: `feature/AXERP-123-carbon-nft-issuance`
- Bugs: `fix/AXERP-456-serial-number-duplicate`
- Infrastructure: `infra/AXERP-789-ecs-scaling`

**PR requirements:**
1. All CI checks pass (pytest, flake8/eslint, docker build).
2. At least one reviewer approval.
3. Migration script included if DocType schema changed.
4. Wiki updated if feature changes a public API or workflow.

---

## 5. DocType Development Guide

### 5.1 Creating a New DocType

```bash
# In Frappe Desk: Builder → Doctype → New
# OR via JSON fixture:
bench --site axerp.local import-doc apps/axerp/axerp/doctype/<doctype_name>/<doctype_name>.json

# After making changes, export:
bench --site axerp.local export-fixtures
```

### 5.2 Python Controller Pattern

```python
# apps/axerp/axerp/doctype/carbon_credit_inventory/carbon_credit_inventory.py

import frappe
from frappe.model.document import Document

class CarbonCreditInventory(Document):
    def before_submit(self):
        self._validate_serial_unique()

    def on_submit(self):
        if self.status == "Sold":
            self._trigger_nft_issuance()

    def _validate_serial_unique(self):
        if frappe.db.exists("Carbon Credit Inventory",
                            {"serial_no": self.serial_no, "name": ("!=", self.name)}):
            frappe.throw(f"Serial number {self.serial_no} already exists in registry.")

    def _trigger_nft_issuance(self):
        frappe.enqueue(
            "axerp.blockchain.nft.issue_nft",
            queue="long",
            serial_no=self.serial_no,
            credit_inventory=self.name,
        )
```

### 5.3 Running Tests

```bash
bench --site axerp.local run-tests --app axerp
bench --site axerp.local run-tests --module axerp.tests.test_carbon_credit_inventory
```

---

## 6. Environment Variables & Secrets

**Never commit secrets to git.** All credentials are stored in AWS Secrets Manager in production and in `sites/<site>/site_config.json` locally (git-ignored).

| Secret | Local Config Key | AWS Secret Name |
|---|---|---|
| DB password | `db_password` in site_config.json | `axerp/prod/db-password` |
| Redis auth token | `redis_cache`, `redis_queue` | `axerp/prod/redis-auth` |
| Plaid client ID / secret | custom in site_config.json | `axerp/prod/plaid` |
| Blockchain RPC endpoint | `blockchain_rpc_url` | `axerp/prod/blockchain-rpc` |
| AWS S3 backup credentials | `aws_access_key_id`, `aws_secret_access_key` | IAM task role (no static creds in prod) |

---

## 7. Useful Bench Commands

```bash
# Start dev server (foreground, with logs)
bench start

# Run a specific background job manually
bench --site axerp.local execute axerp.blockchain.nft.issue_nft --kwargs '{"serial_no": "CC-001"}'

# Clear cache
bench --site axerp.local clear-cache

# Database console
bench --site axerp.local mariadb

# Check scheduler status
bench --site axerp.local doctor

# Rebuild search index
bench --site axerp.local rebuild-global-search

# Update all apps
bench update --no-backup
```

---

## 8. AWS & Deployment Access

### 8.1 AWS Access

- All team members access AWS via **IAM Identity Center (SSO)**.
- URL: `https://axina.awsapps.com/start`
- Request access from the CTO; you will be assigned to the `Developers` permission set.
- Production access (`AdministratorAccess`) is restricted to CTO + DevOps lead.

### 8.2 Deploying to Staging

Push to `develop` branch — GitHub Actions automatically:
1. Builds Docker images and pushes to ECR.
2. Forces a new ECS deployment on the staging cluster.
3. Runs `bench migrate` as an ECS one-shot task.
4. Posts result to Slack `#deployments`.

### 8.3 Deploying to Production

Requires a PR from `develop` → `main` with CTO approval. After merge, GitHub Actions handles the rolling deployment automatically.

### 8.4 Terraform Changes

```bash
cd terra-ecs-africa-aws/
terraform init
terraform plan -var-file=environments/production.tfvars
# Submit plan output in PR for CTO review before applying
terraform apply -var-file=environments/production.tfvars
```

---

## 9. Code Style & Standards

| Language | Linter / Formatter | Config File |
|---|---|---|
| Python | flake8 + black (line length 120) | `.flake8`, `pyproject.toml` |
| JavaScript / Vue | ESLint + Prettier | `.eslintrc.js`, `.prettierrc` |
| Terraform | `terraform fmt` | N/A |
| SQL migrations | Frappe patch files | `patches.txt` in app |

CI will fail PRs that do not pass linting. Run locally:

```bash
cd apps/axerp
black axerp/ && flake8 axerp/
```

---

## 10. Getting Help

| Channel | Purpose |
|---|---|
| Slack `#axerp-dev` | Day-to-day engineering questions |
| Slack `#axerp-infra` | AWS / DevOps issues |
| OpenProject (this system) | Sprint tickets, bug reports, wiki |
| GitHub Issues | Bug tracking linked from OpenProject |
| `db@xgccorp.com` | Escalate to CTO (Daniel Brody) |

---
