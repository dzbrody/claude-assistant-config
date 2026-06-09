# AXERP Master Technical Specification

> **Status:** Active Development Blueprint · Axina Group Inc.
> **Maintainer:** CTO / Engineering Team
> **Last Reviewed:** 2026-05-17
> **Legacy Note:** All references to "XGCERP" in prior documentation have been superseded by "AXERP". This specification is authoritative.

[TOC]

---

## 1. Platform Overview

AXERP (formerly XGCERP) is a multi-tenant SaaS Enterprise Resource Planning system built on **Frappe Framework v16+**. It is deployed on a sovereign AWS cloud infrastructure and is purpose-built for:

1. **Carbon Registry & Offset Management** — certified carbon credit lifecycle from project registration through issuance, serialisation, and marketplace trading.
2. **Blockchain / Crypto Integration** — xGreen Coin issuance, NFT tokenisation of credits, decentralised exchange (DEX), and smart-contract-driven compliance.
3. **Full-Suite ERP** — Accounting, Procurement, Manufacturing 4.0 (MRP II), Inventory & Trading, CRM, Sales & E-commerce, HR & Global Payroll.

The system is built on top of the open-source ERPNext codebase and heavily extended via the `axerp` custom Frappe app at https://github.com/axinagroup/axerp.

---

## 2. Technology Stack

| Layer | Technology | Notes |
|---|---|---|
| Application Framework | Frappe Framework v16+ | Python 3.11+, Jinja2 templating |
| ERP Base | ERPNext v16+ (OSS) | Upstream pinned; custom app overrides |
| Custom App | `axerp` | `apps/axerp/` in bench |
| Database | MariaDB 10.6+ (Multi-AZ RDS) | InnoDB engine; read-replica for reports |
| Cache / Queue | Redis 7+ (ElastiCache) | Cluster mode; separate cache + queue instances |
| Task Queue | RQ (Redis Queue) via Frappe | Long-running jobs: payroll, carbon batch, blockchain TX |
| File Storage | Amazon EFS (shared) | Mounted on all ECS nodes |
| Web Server | NGINX (Frappe Proxy) | SSL termination at ALB |
| Process Manager | Supervisor (within containers) | Web, worker, beat, socketio |
| Frontend | Vue 3 + Frappe UI | Desk SPA; custom carbon dashboard |
| Blockchain Layer | Ethereum (public) + Hyperledger Fabric (private) | Dual-chain architecture |
| Smart Contracts | Solidity (EVM) + Fabric chaincode (Go) | See CarbonBlockchain sub-project |
| CI/CD | GitHub Actions | Deploy to ECS via ECR |
| IaC | Terraform (HCL) | See `AWS` project hierarchy |
| Containerisation | Docker / AWS ECS Fargate | Multi-container task definitions |

---

## 3. DocType Architecture

Frappe DocTypes are the core data models. The following describes the primary custom and extended DocTypes in AXERP.

### 3.1 Carbon Registry Module

| DocType | Type | Key Fields | Purpose |
|---|---|---|---|
| Carbon Project | Document | project_id, standard (VCS/GoldStandard), country, status, hectares, sequestration_rate | Master record for each carbon offset project (e.g., Kenya Mangrove Forest) |
| Carbon Credit Batch | Document | project, vintage_year, quantity_tco2, verification_body, cert_doc | Represents a verified batch of credits received from a project |
| Carbon Credit Inventory | Document | serial_no, batch, status (available/sold/burned/retired), token_id | Single-unit tonne of CO₂; linked to ERPNext Serial Number |
| Carbon NFT | Document | serial_no, token_contract, token_id, metadata_uri, qr_code, smart_contract_hash | On-chain representation of a single burned/issued credit |
| Green Coin Wallet | Document | customer, wallet_address, balance_gc, last_sync | Customer Green Coin balance synced from blockchain |
| Carbon Trade | Document | seller, buyer, quantity, gc_price, usd_price, tx_hash, exchange (EEX/DEX) | Carbon credit trade record; immutable after submission |
| Carbon Compliance Report | Report | Links Project → Inventory → NFT → Trade | Regulatory reporting: VCS, Gold Standard, national registries |

### 3.2 Core ERP Extensions

| DocType | Base Module | AXERP Extension | Notes |
|---|---|---|---|
| Customer | Selling | carbon_customer (checkbox), kyc_status, blockchain_wallet | Extends ERPNext Customer |
| Item | Stock | is_carbon_credit (checkbox), carbon_standard, vintage_year | Enables carbon-specific workflows |
| Serial No | Stock | carbon_credit_inventory (Link) | Ties physical serial to Carbon Credit Inventory |
| Sales Invoice | Accounts | carbon_credits_sold (Table) | Line items auto-trigger NFT issuance on submit |
| Project (ERPNext) | Projects | carbon_project_ref (Link) | Links ERP project to Carbon Project master |

### 3.3 DocType State Machines

**Carbon Credit Lifecycle:**
```
Carbon Project (Active)
  └─► Carbon Credit Batch (Verified)
        └─► Carbon Credit Inventory (Available)
              ├─► [Sale] → Carbon Trade → Carbon Credit Inventory (Sold)
              │                                └─► [Burn] → Carbon NFT (Issued)
              └─► [Retire] → Carbon Credit Inventory (Retired)
```

**Green Coin Flow:**
```
Customer purchases credits → Sales Invoice (submit)
  └─► Webhook → Blockchain API → Token mint (Green Coin or NFT)
        └─► Green Coin Wallet updated via sync job
              └─► Customer burns GC → NFT Certificate issued
```

---

## 4. Sovereign AWS Stack

See the full infrastructure specification in **[AWS Infrastructure & Deployment Plan](02_AWS_Infrastructure_Deployment_Plan.md)**.

### 4.1 Architecture Summary

```
Internet
  │
  ▼
[ Route 53 ] ──► ALB (HTTPS :443, WAF enabled)
                   │
         ┌─────────┴──────────┐
         ▼                    ▼
   ECS Fargate           ECS Fargate
   (Web / NGINX)         (Worker / Scheduler)
         │                    │
         └────────┬───────────┘
                  │
         ┌────────┴────────┐
         ▼                 ▼
   RDS MariaDB      ElastiCache Redis
   (Multi-AZ)       (Cluster: cache + queue)
         │
         ▼
       EFS
   (Shared Files)
```

### 4.2 Multi-Tenancy Model

Each AXERP tenant gets:
- A dedicated **Frappe site** (subdomain: `tenant.axerp.io`)
- An **isolated MariaDB schema** within the shared RDS cluster (or dedicated RDS instance for enterprise tier)
- A **shared EFS volume path** under `/home/frappe/frappe-bench/sites/<tenant>/`
- Shared Redis cluster with key-prefix namespacing per site

---

## 5. Module Deep-Dives

### 5.1 Accounting & Financial Management

**Scope:** General Ledger, Chart of Accounts (CoA), multi-currency, fiscal year management, accounts payable/receivable, journal entries, bank reconciliation (Plaid), asset management, deferred revenue/expense, subscription billing, GST/VAT compliance.

**Key Configuration:**
- Multi-company setup: each Axina Group entity (Axina Inc., XGC Software Inc., etc.) has its own Company record sharing Customer/Supplier master data.
- Finance Books for parallel IFRS and local GAAP reporting.
- Accounting Dimensions: `Cost Center`, `Project`, `Carbon Project` for dimensional P&L.

**Carbon-Specific Accounting:**
- Carbon credit purchases are booked as inventory receipts (Inventory Asset → Carbon Credit Stock).
- On sale/burn, cost-of-goods-sold entries post automatically.
- Green Coin transactions are marked as commodity trades; revenue is recognised on NFT issuance.

**Integrations:**
- **Plaid** — automatic bank statement import and reconciliation.
- **QuickBooks Migrator** — for migrating existing customer books into AXERP.

---

### 5.2 Procurement & Sourcing

**Scope:** Material Requests, RFQ, Purchase Orders, Supplier Quotation comparison, Supplier Scorecard, GRN (Purchase Receipt), Purchase Invoice, landed cost.

**Workflow:**
```
Material Request → RFQ → Supplier Quotation → Purchase Order
  → Purchase Receipt → Purchase Invoice → Payment Entry
```

**Carbon Project Procurement:**
- Project-specific procurement budgets enforced via Cost Center budget limits.
- Verified Carbon Standard auditor engagements tracked as service POs.

---

### 5.3 Manufacturing 4.0 (MRP II)

**Scope:** Bill of Materials (multi-level), Work Orders, Job Cards, Workstations, Production Planning, Quality Inspection, Subcontracting, Scrap Management.

**For Carbon Projects (Asset Manufacturing analog):**
- BOMs model the "production" of carbon credits: inputs = monitoring equipment, labour, land; output = CO₂ tonnes sequestered.
- Work Orders track field activities (planting, measurement campaigns).
- Quality Inspection DocTypes record third-party verification audits.

**MRP II Planning:**
- Production Planning Tool auto-generates Work Orders and Material Requests from open Sales Orders (carbon credit forward contracts).

---

### 5.4 Inventory & Trading

**Scope:** Warehouses, Items, Serial/Batch tracking, Stock Entries, Delivery Notes, Purchase Receipts, Stock Reconciliation, Price Lists.

**Carbon Credit Inventory:**
- Each tonne of CO₂ is an **Item** with `is_carbon_credit = True`.
- Each unit gets a **Serial Number** (the AXERP serial number seeds the blockchain hash).
- Warehouse = "Carbon Credit Registry" (logical; no physical location).
- Stock Ledger Entry records every movement: receipt, sale, burn/retirement.

**Trading:**
- Marketplace integration with EEX (European Energy Exchange) via API connector.
- Internal DEX trades processed through Carbon Trade DocType.

---

### 5.5 CRM & Lead Engagement

**Scope:** Leads, Opportunities, Quotations, CRM Analytics, Email Campaigns, Call logging.

**Carbon Market CRM:**
- Lead sources: ESG compliance buyers, carbon brokers, regulated industries.
- Opportunity stage pipeline: `Prospect → Qualified → Proposal → Negotiation → Won/Lost`.
- Quotations auto-generate carbon credit pricing from current Green Coin market rate.

---

### 5.6 Sales & E-commerce

**Scope:** Sales Orders, Delivery Notes, Sales Invoices, Credit/Debit Notes, Customer Portal, Point-of-Sale, Shopify integration, Amazon SP-API.

**Carbon Sales Workflow:**
1. Sales Order created for carbon credit units.
2. On SO confirm: inventory reserved (serial numbers allocated).
3. Sales Invoice submitted: triggers blockchain NFT issuance webhook.
4. NFT Certificate PDF attached to invoice and emailed to customer.

---

### 5.7 HR & Global Payroll

**Scope:** Employee master, Leave management, Attendance, Payroll Entry, Salary Structure, Appraisals, Recruitment, Fleet Management, Expense Claims.

**Multi-Region Payroll:**
- Salary Structures per jurisdiction (Canada, India, Kenya, South Africa).
- Tax Withholding Categories mapped per country.
- Payroll Entry run monthly; generates Salary Slips in bulk.

---

## 6. Security & Compliance Architecture

| Control | Implementation |
|---|---|
| Authentication | Frappe JWT + optional LDAP / SSO (Keycloak / fairlogin) |
| Authorisation | Frappe Role-Permission Matrix; field-level permissions for sensitive financial data |
| Data Encryption | TLS 1.3 in transit; AES-256 at rest (RDS + EFS encryption enabled) |
| Audit Trail | Frappe Document Versioning + Access Log DocType on all financial records |
| GDPR / Data Privacy | Frappe Data Privacy module; customer PII scrubbing workflows |
| Carbon Credit Integrity | Dual-chain blockchain (Ethereum public + Hyperledger Fabric private); serial-number-seeded hash chain |
| Infrastructure Security | AWS WAF, Security Hub, GuardDuty, Secrets Manager, IAM least-privilege |
| Backup | Automated daily RDS snapshots; EFS backup to S3; 30-day retention |

---

## 7. Development Standards

- **Branch strategy:** `main` (production) → `develop` → `feature/AXERP-<ticket>` → PR → `develop`.
- **DocType changes:** Always via migration scripts; never direct DB edits in production.
- **Custom scripts:** Python controllers only; no monkey-patching of Frappe core.
- **Testing:** Pytest unit tests required for all custom DocType controllers; CI runs on every PR.
- **API versioning:** All external API endpoints prefixed `/api/v1/`; breaking changes require a new version prefix.

---
