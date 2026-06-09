# OpenProject Architecture — AXERP & AWS
## CTO / PM Recommendations · Axina Group Inc.

---

## Structure 1 — Head Project: `AXERP`

**Identifier:** `axerp`
**Status:** Active
**Description:**
AXERP is Axina Group Inc.'s flagship SaaS Enterprise Resource Planning platform, built on Frappe Framework v16+ and AWS Sovereign Infrastructure. The platform targets multi-tenant carbon registry management, carbon-offset project financing, blockchain-backed carbon coin issuance (xGreen Coin), and a full suite of enterprise modules (Accounting, Procurement, Manufacturing 4.0, Inventory, CRM, HR). This is the root project; all technical work, sprints, and wiki documentation roll up here.

**Repository:** https://github.com/axinagroup/axerp

---

### Sub-Project 1.1 — `CarbonAi`

**Identifier:** `axerp-carbonai`
**Parent:** AXERP
**Description:**
AI/ML services layer for the carbon registry. Covers predictive analytics for carbon sequestration rates, automated document classification for certification records (VCS / Gold Standard), NLP-driven contract summarisation, and AI-assisted compliance monitoring. Integrates with the core AXERP DocType layer via REST API and Frappe hooks. Work items here govern model development, training pipelines, and AI feature flags.

**Repository:** N/A (housed within axinagroup/axerp under `apps/carbonai/`)

---

### Sub-Project 1.2 — `CarbonBlockchain`

**Identifier:** `axerp-carbonblockchain`
**Parent:** AXERP
**Description:**
The full blockchain integration layer: xGreen Coin tokenomics, NFT issuance for certified carbon credits, Ethereum + Hyperledger Fabric node operation, SPV client, decentralised exchange (DEX), and smart-contract lifecycle management. Serial numbers from the AXERP inventory module seed all blockchain hashing. This sub-project owns the on-chain and off-chain components as well as the Solidity / Hyperledger chaincode source.

**Repository:** https://github.com/orgs/XGCERP/repositories (terra-blockchain / coin repos)

---

### Sub-Project 1.3 — `onboarding`

**Identifier:** `axerp-onboarding`
**Parent:** AXERP
**Description:**
Tenant onboarding workflow for new AXERP SaaS customers. Covers automated site provisioning on Frappe Press (AWS ECS), KYC/KYB flows, initial Chart of Accounts setup, multi-currency configuration, and user role seeding. Also tracks the internal engineering onboarding process: Frappe bench setup, GitHub access, AWS SSO, and development environment standards.

**Repository:** N/A (scripts housed in axinagroup/axerp under `scripts/onboarding/`)

---

### Sub-Project 1.4 — `axerp-code`

**Identifier:** `axerp-code`
**Parent:** AXERP
**Description:**
Core ERP application codebase. All Frappe custom app development, DocType extensions, custom Python controllers, JavaScript client scripts, server-side hooks, and automated tests live here. This project is the primary sprint delivery vehicle for new ERP module features. Linked directly to the canonical GitHub repository.

**Repository:** https://github.com/axinagroup/axerp

---

### Sub-Project 1.5 — `API`

**Identifier:** `axerp-api`
**Parent:** AXERP
**Description:**
External-facing REST/GraphQL API layer and third-party integration hub. Governs Plaid (bank sync), Shopify (e-commerce), Amazon SP-API (marketplace), SendCloud (logistics), EEX (carbon exchange), and any future fintech or ESG data connectors. Owns API versioning, rate-limit policy, authentication tokens (OAuth2 / API keys), and the OpenAPI specification.

**Repository:** N/A (within axinagroup/axerp under `apps/axerp_integrations/`)

---

### Sub-Project 1.6 — `AXLogistics`

**Identifier:** `axerp-axlogistics`
**Parent:** AXERP
**Description:**
Logistics and supply-chain module layer. Covers warehouse management, inbound/outbound shipment tracking, carrier integration (SendCloud), delivery-note automation, and landed-cost calculation. For carbon projects, this module tracks physical project assets and equipment procurement. Manages the Manufacturing 4.0 and inventory sub-systems as they relate to physical fulfilment.

**Repository:** N/A (within axinagroup/axerp under `apps/axlogistics/`)

---

## Structure 2 — Head Project: `AWS`

**Identifier:** `aws-infra`
**Status:** Active
**Description:**
AWS infrastructure umbrella project for all Axina Group cloud deployments. Managed via Terraform (HCL). All provisioning, networking, IAM, and multi-region work is tracked here. The canonical Terraform state is stored in S3 with DynamoDB locking. Infrastructure PRs require CTO sign-off before `terraform apply`.

**Repository:** https://github.com/orgs/XGCERP/repositories

---

### Sub-Project 2.1 — `terra-ecs-africa-aws`

**Identifier:** `aws-africa-ecs`
**Parent:** AWS
**Description:**
Terraform module for the primary Africa (Cape Town: af-south-1) AXERP deployment. Provisions the Multi-Tenant Frappe Press architecture: ECS Fargate (web + worker + scheduler nodes), Amazon RDS MariaDB Multi-AZ, ElastiCache Redis (cluster mode), EFS shared storage, ALB with WAF, ACM certificates, Route 53 DNS, and VPC networking. This is the production environment for AXERP SaaS tenants.

**Repository:** https://github.com/orgs/XGCERP/repositories (`terra-ecs-africa-aws`)

---

### Sub-Project 2.2 — `terra-ecs-us-east`

**Identifier:** `aws-useast-ecs`
**Parent:** AWS
**Description:**
Terraform module for the US East (N. Virginia: us-east-1) deployment. Mirrors the Africa stack for North American tenants and provides the disaster-recovery / failover target for the primary region. Includes cross-region RDS read-replica configuration and Route 53 health-check failover routing.

**Repository:** https://github.com/orgs/XGCERP/repositories (`terra-ecs-us-east` — create if not yet present)

---

### Sub-Project 2.3 — `terraform-shared-modules`

**Identifier:** `aws-tf-modules`
**Parent:** AWS
**Description:**
Shared Terraform modules (VPC, ECS service, RDS, Redis, ALB, IAM baseline) referenced by both regional stacks. Versioned via GitHub tags; regional stacks pin to a specific module version. Changes here require regression testing against both regional stacks.

**Repository:** https://github.com/orgs/XGCERP/repositories (`terraform-shared-modules`)

---

### Sub-Project 2.4 — `aws-security-compliance`

**Identifier:** `aws-security`
**Parent:** AWS
**Description:**
Security posture and compliance work: AWS Security Hub findings, GuardDuty alert triage, IAM permission audits, WAF rule tuning, Secrets Manager rotation schedules, and compliance mapping to SOC 2 / ISO 27001. Tracks work items for remediating high/critical findings.

---
