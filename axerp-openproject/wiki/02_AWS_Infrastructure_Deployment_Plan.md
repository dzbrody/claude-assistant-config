# AWS Infrastructure & Deployment Plan

> **Status:** Active Development Blueprint · Axina Group Inc.
> **Maintainer:** CTO / DevOps Team
> **Last Reviewed:** 2026-05-17
> **Terraform Repos:** https://github.com/orgs/XGCERP/repositories

[TOC]

---

## 1. Overview

AXERP runs on a **Sovereign AWS Multi-Tenant Frappe Press** architecture. The design is region-independent; the primary deployment is in **af-south-1 (Cape Town)** with a secondary deployment / disaster-recovery footprint in **us-east-1 (N. Virginia)**.

All infrastructure is provisioned and managed via **Terraform** (HCL). No manual console changes are permitted in production. State is stored in S3 with DynamoDB locking.

---

## 2. Architecture Diagram

```
┌──────────────────────────────────────────────────────────────────┐
│ AWS Region: af-south-1 (Primary)                                 │
│                                                                  │
│  Internet                                                        │
│    │                                                             │
│    ▼                                                             │
│  Route 53 (axerp.io, *.axerp.io)                                │
│    │                                                             │
│    ▼                                                             │
│  ALB (Application Load Balancer)                                 │
│  ├─ HTTPS :443 → TLS termination (ACM cert)                     │
│  ├─ WAF (OWASP Core Rule Set + rate limiting)                    │
│  └─ HTTP :80 → redirect to HTTPS                                │
│         │                                                        │
│    ┌────┴─────────────────────────┐                              │
│    │       ECS Cluster (Fargate)  │                              │
│    │  ┌────────────────────────┐  │                              │
│    │  │ Task: axerp-web        │  │  ← NGINX + Gunicorn          │
│    │  │  (2 vCPU / 4 GB RAM)   │  │    per-tenant routing        │
│    │  └────────────────────────┘  │                              │
│    │  ┌────────────────────────┐  │                              │
│    │  │ Task: axerp-worker     │  │  ← RQ workers (default,      │
│    │  │  (2 vCPU / 4 GB RAM)   │  │    long, short queues)       │
│    │  └────────────────────────┘  │                              │
│    │  ┌────────────────────────┐  │                              │
│    │  │ Task: axerp-scheduler  │  │  ← Frappe beat scheduler     │
│    │  │  (0.5 vCPU / 1 GB RAM) │  │                              │
│    │  └────────────────────────┘  │                              │
│    │  ┌────────────────────────┐  │                              │
│    │  │ Task: axerp-socketio   │  │  ← Frappe realtime           │
│    │  │  (0.5 vCPU / 1 GB RAM) │  │                              │
│    │  └────────────────────────┘  │                              │
│    └──────────────────────────────┘                              │
│         │              │              │                           │
│         ▼              ▼              ▼                           │
│  ┌────────────┐  ┌──────────────┐  ┌───────┐                    │
│  │ RDS MariaDB│  │ ElastiCache  │  │  EFS  │                    │
│  │ Multi-AZ   │  │ Redis 7      │  │ (NFS) │                    │
│  │ (Primary + │  │ Cluster Mode │  │ Mount │                    │
│  │  Standby)  │  │              │  │ /sites│                    │
│  └────────────┘  └──────────────┘  └───────┘                    │
│         │                                                         │
│         ▼ (async replication)                                     │
│  RDS Read Replica ──────────────────────────────────► us-east-1  │
└──────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────┐
│ AWS Region: us-east-1 (Secondary / DR)                           │
│  Mirrors af-south-1 stack; Route 53 health-check failover        │
└──────────────────────────────────────────────────────────────────┘
```

---

## 3. Component Specifications

### 3.1 ECS Fargate

| Parameter | Web Task | Worker Task | Scheduler Task | SocketIO Task |
|---|---|---|---|---|
| CPU | 2 vCPU | 2 vCPU | 0.5 vCPU | 0.5 vCPU |
| Memory | 4 GB | 4 GB | 1 GB | 1 GB |
| Desired Count | 2 (min) / 10 (max) | 2 (min) / 8 (max) | 1 | 1 |
| Auto-scaling Trigger | ALB RequestCount / CPU > 70% | Queue depth > 50 jobs | N/A | N/A |
| Container Image | `ECR: axerp-web:latest` | `ECR: axerp-worker:latest` | `ECR: axerp-scheduler:latest` | `ECR: axerp-socketio:latest` |
| Health Check | `GET /api/method/ping` | ECS exec: `rq info` | ECS exec: `frappe scheduler status` | TCP :9000 |

**Task IAM Role Permissions:**
- Read secrets from Secrets Manager (DB password, Redis auth token, API keys)
- Read/Write EFS
- Write CloudWatch Logs
- ECR pull (via execution role)

---

### 3.2 Amazon RDS — MariaDB

| Parameter | Value |
|---|---|
| Engine | MariaDB 10.6 |
| Instance Class | `db.r6g.xlarge` (production) |
| Multi-AZ | Enabled (automatic standby failover) |
| Storage | 500 GB GP3, auto-scaling to 2 TB |
| Encryption | AES-256 (KMS CMK) |
| Backup Retention | 30 days automated snapshots |
| Read Replica | 1x `db.r6g.large` in same AZ (reports workload) |
| Parameter Group | `axerp-mariadb106` (InnoDB buffer = 75% RAM, slow query log enabled) |
| Monitoring | Enhanced Monitoring + Performance Insights enabled |

**Multi-Tenancy:**
- Each Frappe site uses a separate MariaDB database within the same RDS instance.
- Enterprise tenants may be provisioned on a dedicated RDS instance.
- Frappe `common_site_config.json` routes report queries to the read replica.

---

### 3.3 Amazon ElastiCache — Redis

| Parameter | Value |
|---|---|
| Engine | Redis 7.x |
| Mode | Cluster Mode Enabled |
| Node Type | `cache.r6g.large` |
| Shards | 3 (6 nodes with replicas) |
| Auth | Redis AUTH token (stored in Secrets Manager) |
| Encryption | TLS in transit + at-rest |
| Use Case | Cache: Frappe page cache, session; Queue: RQ job queues (default/short/long) |

**Redis Key Namespacing:**
Each Frappe site uses a key prefix: `frappe|<sitename>|*` to prevent cross-tenant collisions.

---

### 3.4 Amazon EFS

| Parameter | Value |
|---|---|
| Performance Mode | General Purpose |
| Throughput Mode | Elastic (auto-scales with load) |
| Encryption | AES-256 (KMS) |
| Access Points | One per environment (prod / staging) |
| Mount Target | Each AZ in VPC (for ECS Fargate NFS mounts) |
| Path Structure | `/frappe-bench/sites/<sitename>/` |

EFS hosts: site configs, uploaded files (private + public), backup files before S3 sync.

---

### 3.5 Application Load Balancer (ALB)

| Parameter | Value |
|---|---|
| Scheme | Internet-facing |
| Listeners | HTTP :80 (redirect to HTTPS), HTTPS :443 |
| SSL Policy | ELBSecurityPolicy-TLS13-1-2-2021-06 |
| Certificate | ACM wildcard `*.axerp.io` + SAN list for custom tenant domains |
| WAF | AWS WAF v2 — Core Rule Set (CRS), rate limit 2000 req/5min per IP |
| Routing | Host-based: `<tenant>.axerp.io` → target group `axerp-web-tg` |
| Health Check | `GET /api/method/ping` — 200 OK within 5s |
| Stickiness | Enabled (1-day duration) for SocketIO connections |

---

### 3.6 Networking (VPC)

| Subnet | CIDR | Purpose |
|---|---|---|
| Public-1a | 10.0.1.0/24 | ALB, NAT Gateway |
| Public-1b | 10.0.2.0/24 | ALB secondary |
| Private-App-1a | 10.0.10.0/24 | ECS Fargate tasks |
| Private-App-1b | 10.0.11.0/24 | ECS Fargate tasks |
| Private-Data-1a | 10.0.20.0/24 | RDS, ElastiCache |
| Private-Data-1b | 10.0.21.0/24 | RDS standby, ElastiCache replica |

- ECS tasks have **no public IP**; all egress via NAT Gateway.
- Security Groups: App SG → Data SG (5306 MariaDB, 6379 Redis, 2049 NFS); ALB SG → App SG (8000 Gunicorn, 9000 SocketIO).

---

## 4. Terraform Repository Structure

```
terra-ecs-africa-aws/
├── main.tf                  # Root module — wires all child modules
├── variables.tf             # Region, env, tenant list, sizing vars
├── outputs.tf               # ALB DNS, RDS endpoint, EFS ID
├── backend.tf               # S3 state bucket + DynamoDB lock table
│
├── modules/
│   ├── vpc/                 # VPC, subnets, IGW, NAT, route tables
│   ├── ecs_cluster/         # ECS cluster, capacity provider (Fargate)
│   ├── ecs_service_web/     # Web task def, service, auto-scaling
│   ├── ecs_service_worker/  # Worker task def, service, auto-scaling
│   ├── rds/                 # RDS instance, subnet group, param group
│   ├── elasticache/         # Redis cluster, subnet group
│   ├── efs/                 # EFS filesystem, mount targets, access points
│   ├── alb/                 # ALB, listeners, target groups, WAF assoc
│   ├── acm/                 # ACM cert request + Route53 DNS validation
│   ├── route53/             # DNS records (A alias to ALB)
│   ├── iam/                 # Task execution role, task role, policies
│   ├── secrets/             # Secrets Manager secrets (DB pass, Redis auth)
│   └── cloudwatch/         # Log groups, alarms, dashboards
│
└── environments/
    ├── production.tfvars
    └── staging.tfvars
```

---

## 5. CI/CD Deployment Pipeline

```
Developer Push → GitHub PR
  └─► GitHub Actions: CI
        ├─ pytest (Frappe unit tests)
        ├─ terraform validate + plan (on infra changes)
        └─ Docker build + push to ECR (axerp-web, axerp-worker images)

PR Merge to `develop`
  └─► GitHub Actions: Deploy Staging
        └─ ECS force-new-deployment (staging cluster)
               └─ bench migrate (Frappe DB migrations)
                     └─ Health check passes → staging green

PR Merge to `main` (CTO approval required)
  └─► GitHub Actions: Deploy Production
        ├─ ECR image tag: `<git-sha>` → also tag `latest`
        ├─ ECS rolling deployment (web task first, then worker)
        │    └─ ALB drains old tasks; new tasks pass health check
        └─ bench migrate (via ECS run-task one-shot)
               └─ CloudWatch alarm check: error rate < 0.1% → success
```

**Rollback:** Re-tag previous `<git-sha>` image as `latest` and trigger a new ECS deployment. RDS point-in-time restore for data rollback if needed.

---

## 6. Multi-Tenant Frappe Press Operations

### 6.1 Provisioning a New Tenant

```bash
# Run as ECS one-shot task (via aws ecs run-task)
bench new-site <tenant>.axerp.io \
  --db-host $RDS_ENDPOINT \
  --db-root-password $DB_ROOT_PASSWORD \
  --admin-password $TENANT_ADMIN_PASSWORD

bench --site <tenant>.axerp.io install-app axerp
bench --site <tenant>.axerp.io install-app erpnext
bench --site <tenant>.axerp.io install-app hrms

# Set site config
bench --site <tenant>.axerp.io set-config db_read_host $RDS_READONLY_ENDPOINT
bench --site <tenant>.axerp.io set-config redis_cache "redis://:<auth>@$REDIS_ENDPOINT:6379/0"
bench --site <tenant>.axerp.io set-config redis_queue "redis://:<auth>@$REDIS_ENDPOINT:6379/1"
```

### 6.2 Site Migrations (Frappe Updates)

```bash
# Coordinated migration — run during maintenance window
bench --site <tenant>.axerp.io migrate
bench --site <tenant>.axerp.io build --force   # Recompile assets
bench restart
```

### 6.3 Backup Procedure

| Backup Type | Schedule | Destination | Retention |
|---|---|---|---|
| RDS Automated Snapshot | Daily (02:00 UTC) | AWS managed S3 | 30 days |
| Frappe files backup | Daily (03:00 UTC) | S3 bucket `axerp-backups-<env>` | 30 days |
| Cross-region copy | Daily (04:00 UTC) | us-east-1 S3 (replication) | 7 days |

---

## 7. Monitoring & Alerting

| Metric | Threshold | Alert Channel |
|---|---|---|
| ALB 5xx error rate | > 1% over 5 min | PagerDuty (P1) |
| ECS CPU utilisation | > 80% sustained 10 min | Slack #infra-alerts |
| RDS CPU | > 75% sustained 10 min | Slack #infra-alerts |
| RDS Storage | < 20% free | PagerDuty (P2) |
| Redis memory | > 85% | Slack #infra-alerts |
| ECS task stopped (unexpected) | Any | PagerDuty (P1) |
| Frappe scheduler last run | > 15 min ago | Slack #infra-alerts |
| Terraform drift | Daily plan detects changes | Slack #infra-alerts |

CloudWatch dashboards: `AXERP-Production`, `AXERP-Staging`, `AXERP-Carbon-Blockchain`.

---

## 8. Cost Optimisation

- ECS Fargate Spot for worker tasks (non-production environments).
- RDS reserved instances (1-year) for production.
- S3 Intelligent-Tiering for backup buckets.
- NAT Gateway: single per AZ; use VPC Endpoints for S3, ECR, Secrets Manager to reduce data transfer costs.
- Auto-scaling: scale-in aggressively during off-peak (22:00–06:00 SAST).

---
