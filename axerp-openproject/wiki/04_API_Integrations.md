# API & Integrations

> **Status:** Active Development Blueprint · Axina Group Inc.
> **Maintainer:** API Team / CTO
> **Last Reviewed:** 2026-05-17

[TOC]

---

## 1. Integration Architecture Overview

AXERP exposes and consumes APIs across three categories:

1. **Inbound integrations** — third-party services push data into AXERP (e.g., Plaid bank transactions, Shopify orders).
2. **Outbound integrations** — AXERP pushes data to external systems (e.g., NFT issuance to blockchain, carbon trades to EEX).
3. **AXERP REST API** — the AXERP public API consumed by the mobile app, customer portal, and partner integrations.

All external API keys and credentials are stored in **AWS Secrets Manager**; they are never hardcoded or committed to git.

```
External Services
      │
      ▼
 ┌─────────────────────────────────────────┐
 │          AXERP Integration Layer         │
 │  (Frappe Webhooks / Scheduled Jobs /    │
 │   Custom API Endpoints in axerp app)    │
 └─────────────────────────────────────────┘
      │
      ▼
 AXERP Core (DocTypes / Controllers)
```

---

## 2. AXERP Public REST API

### 2.1 Base URL

```
Production:  https://api.axerp.io/api/v1/
Staging:     https://staging.axerp.io/api/v1/
```

### 2.2 Authentication

AXERP uses Frappe's token-based authentication. All API clients must include:

```
Authorization: Token <api_key>:<api_secret>
Content-Type: application/json
```

API keys are generated per user in AXERP Desk: **Settings → My Profile → API Access**.

### 2.3 Core Endpoints

| Method | Endpoint | Description |
|---|---|---|
| GET | `/api/v1/carbon/projects` | List all carbon projects |
| GET | `/api/v1/carbon/projects/{project_id}` | Get project detail + sequestration stats |
| GET | `/api/v1/carbon/inventory` | List available carbon credit inventory |
| POST | `/api/v1/carbon/inventory/reserve` | Reserve credits for a purchase |
| POST | `/api/v1/carbon/trade` | Submit a carbon credit trade |
| GET | `/api/v1/carbon/nft/{serial_no}` | Get NFT certificate detail |
| GET | `/api/v1/wallet/{customer_id}` | Get customer Green Coin wallet balance |
| POST | `/api/v1/wallet/burn` | Burn Green Coin → issue NFT certificate |
| GET | `/api/v1/items` | List AXERP items (Frappe standard) |
| POST | `/api/v1/orders` | Create Sales Order |
| GET | `/api/v1/invoices/{invoice_id}` | Get invoice detail |

### 2.4 Webhook Outbound Events

AXERP fires webhooks on these document events (configure in AXERP Desk → **Settings → Webhooks**):

| Event | Payload | Consumers |
|---|---|---|
| `carbon_credit_inventory.on_submit` | `{serial_no, batch, status, project}` | CarbonBlockchain service (triggers token mint) |
| `carbon_trade.on_submit` | `{buyer, seller, quantity, tx_hash}` | EEX / DEX bridge |
| `sales_invoice.on_submit` | `{customer, items[], total, carbon_credits[]}` | Notification service, NFT issuance |
| `customer.after_insert` | `{customer_id, kyc_status, email}` | CRM / onboarding workflow |

---

## 3. Plaid — Bank Synchronisation

**Purpose:** Automatic bank account connection and transaction import for bank reconciliation in AXERP Accounting.

**Frappe Module:** `Home > Integrations > Plaid Settings`

| Parameter | Value |
|---|---|
| Environment | `production` (live) / `sandbox` (dev) |
| Products | `transactions`, `auth`, `balance` |
| Auth | Plaid client ID + secret (Secrets Manager: `axerp/prod/plaid`) |

**Workflow:**
1. Accountant connects bank account via Plaid Link (OAuth).
2. Plaid Link callback stores `access_token` in AXERP site config.
3. Scheduled job (daily 06:00 UTC) pulls transactions via Plaid Transactions API.
4. AXERP creates **Bank Transaction** records automatically.
5. Accountant runs **Payment Reconciliation** to match GL entries.

**Automatic Sync:**
```
Frappe Scheduler (daily)
  └─► axerp.integrations.plaid.sync_transactions()
        └─► Plaid API → /transactions/get
              └─► Creates Bank Transaction DocTypes in AXERP
```

---

## 4. Shopify — E-commerce Integration

**Purpose:** Sync Shopify store orders, customers, and inventory into AXERP for fulfilment and accounting.

**Frappe Module:** `Home > Integrations > Shopify Settings`

| Parameter | Description |
|---|---|
| Shopify URL | `https://<store>.myshopify.com` |
| API Key + Password | Admin API credentials (Secrets Manager: `axerp/prod/shopify`) |
| Webhooks | Order Created, Order Updated, Order Fulfilled, Customer Created |

**Data Mapping:**

| Shopify Object | AXERP DocType |
|---|---|
| Customer | Customer |
| Product | Item |
| Order | Sales Order |
| Fulfillment | Delivery Note |
| Invoice | Sales Invoice |

**Webhook Setup (Shopify Admin → Settings → Notifications):**
```
POST https://api.axerp.io/api/method/axerp.integrations.shopify.handle_webhook
Header: X-Shopify-Hmac-Sha256: <computed_hmac>
```

AXERP verifies the HMAC signature before processing.

---

## 5. Amazon SP-API — Marketplace Integration

**Purpose:** Sync Amazon Marketplace orders, inventory levels, and fulfilment into AXERP.

**Frappe Module:** `Home > Integrations > Amazon SP-API Settings`

**Setup Steps:**
1. Create an IAM user with Selling Partner API permissions.
2. Register as a developer in Amazon Seller Central.
3. Create an SP-API application; obtain Client ID, Client Secret, Refresh Token.
4. Store credentials in AXERP: `Home > Integrations > Amazon SP-API Settings`.

| Parameter | Description |
|---|---|
| Marketplace ID | e.g., `ATVPDKIKX0DER` (US), `A1F83G8C2ARO7P` (UK) |
| LWA Client ID / Secret | Login with Amazon OAuth creds |
| Refresh Token | Per-seller refresh token |
| AWS STS Role ARN | For Selling Partner API role assumption |

**Synced Data:**

| Amazon Object | AXERP DocType | Sync Direction |
|---|---|---|
| Order | Sales Order | Amazon → AXERP |
| Order Item | Sales Order Item | Amazon → AXERP |
| Shipment | Delivery Note | Amazon → AXERP |
| Inventory | Stock Level | AXERP → Amazon |
| Return | Sales Return | Amazon → AXERP |

**Scheduled Sync:**
```
Every 30 minutes:
  axerp.integrations.amazon.sync_orders()
  axerp.integrations.amazon.sync_inventory()
```

---

## 6. SendCloud — Shipping & Logistics

**Purpose:** Print shipping labels, track parcels, and sync delivery status back to AXERP Delivery Notes.

**Frappe Module:** `Home > Integrations > SendCloud Settings` (via `axerp_integrations` app)

| Parameter | Description |
|---|---|
| Public Key / Secret Key | SendCloud API credentials |
| Default Sender Address | Warehouse address for outbound labels |
| Webhook URL | `https://api.axerp.io/api/method/axerp.integrations.sendcloud.handle_webhook` |

**Workflow:**
1. AXERP Delivery Note submitted → webhook to SendCloud creates parcel.
2. SendCloud returns tracking number → stored on Delivery Note.
3. SendCloud webhook fires on parcel status change → AXERP updates Delivery Note status.

**Supported Carriers:** DHL, UPS, PostNL, DPD, FedEx (configured in SendCloud dashboard).

---

## 7. Blockchain API — Carbon Credit Tokenisation

**Purpose:** Issue xGreen Coin tokens and NFT certificates when carbon credits are sold or burned.

**Internal Service:** AXERP calls a dedicated blockchain microservice (hosted separately; see `CarbonBlockchain` sub-project).

**Endpoint:**
```
POST https://blockchain.axerp.io/api/v1/mint-nft
Authorization: Bearer <service-token>
Content-Type: application/json

{
  "serial_no": "CC-2024-KE-00142",
  "project_id": "KENYA-MANGROVE-001",
  "vintage_year": 2024,
  "standard": "VCS",
  "owner_wallet": "0xAbCd...1234",
  "metadata": {
    "tonnes_co2": 1,
    "certification_doc": "ipfs://Qm..."
  }
}
```

**Response:**
```json
{
  "token_id": "0x0000...00a3",
  "tx_hash": "0xdeadbeef...",
  "contract_address": "0x1234...abcd",
  "nft_uri": "https://nft.axerp.io/certificate/CC-2024-KE-00142"
}
```

**AXERP stores** `token_id`, `tx_hash`, and `nft_uri` on the `Carbon NFT` DocType record. The NFT certificate PDF is generated and attached to the Sales Invoice.

**Dual-Chain Design:**

| Chain | Use Case | Access |
|---|---|---|
| Ethereum (mainnet) | Public NFT certificates, Green Coin trades | Public explorer: etherscan.io |
| Hyperledger Fabric | Sensitive inventory data, private brokerage contracts | Permissioned; AXERP nodes only |

---

## 8. EEX (European Energy Exchange) — Carbon Market

**Purpose:** List AXERP carbon credits on the EEX exchange and sync executed trades back.

**Integration Type:** REST API + SFTP batch feed (EEX provides both).

| Parameter | Value |
|---|---|
| API Base URL | `https://api.eex.com/v1/` (provided by EEX) |
| Auth | OAuth2 client credentials |
| Connectivity | Dedicated VPN tunnel (EEX requirement) |
| Sandbox | `https://api.eex-sandbox.com/v1/` |

**Workflow:**
1. Carbon credit batch verified → listed on EEX via `POST /orders`.
2. EEX sends trade execution webhook → AXERP creates `Carbon Trade` record.
3. Financial settlement triggers `Sales Invoice` in AXERP Accounting.

---

## 9. Google Services Integration

### 9.1 Google Drive Backup

**Module:** `Home > Integrations > Google Drive Settings`

Automated daily backup of AXERP database dumps and file attachments to a Google Drive folder. Requires OAuth 2.0 credentials from Google Cloud Console.

```
Scheduler (03:00 UTC daily)
  └─► frappe.integrations.google_drive.take_backup()
        └─► gzip SQL dump + files archive → upload to Drive
```

### 9.2 Google OAuth (Login)

Configured in `Home > Integrations > Social Login Key`. Enables `Sign in with Google` on the AXERP login page. Uses Google's OpenID Connect (OIDC) endpoint.

---

## 10. Email & Notification Integrations

### 10.1 SendGrid (Transactional Email)

AXERP uses SendGrid for outbound transactional emails (invoices, NFT certificates, system alerts).

**Setup:** `Home > Settings > Email Account`

```
Outbound SMTP:
  Host: smtp.sendgrid.net
  Port: 587 (STARTTLS)
  Username: apikey
  Password: <SENDGRID_API_KEY> (Secrets Manager)
```

### 10.2 AWS SES (Bulk / Marketing)

Used for bulk notifications (payroll advices, carbon credit newsletters). Configured in AXERP as a second Email Account with the SES SMTP endpoint for the production region.

---

## 11. LDAP / SSO

**Module:** `Home > Integrations > LDAP Settings`

Supports AD-style LDAP and Keycloak-based OIDC (fairlogin). AXERP automatically syncs user roles from LDAP groups on each login. See [Developer Onboarding](03_Developer_Onboarding_Repositories.md) for team SSO access via AWS IAM Identity Center.

---

## 12. Integration Health Dashboard

Monitor all active integrations: `AXERP Desk → Tools → Integration Requests`

Each outbound API call is logged as an `Integration Request` DocType with status, request body, response, and retry count. Alerts fire to Slack `#axerp-integrations` on consecutive failures.

---
