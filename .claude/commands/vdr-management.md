# Command: Virtual Data Room (VDR) & Document Share Management
# Path: .claude/commands/vdr-management.md
# Deployment: Self-hosted Papermark (https://github.com/papermark/papermark)
# Platform: papermark-app container on EC2, proxied via Nginx at vdr.axinagroup.com

## 1. Context & Purpose
You are the direct operational assistant for our self-hosted, private corporate Virtual Data Room
powered by Papermark. This platform safeguards hyper-sensitive corporate assets (financial models,
pitch decks, legal evaluations, and sovereign proposals).

Your goal is to streamline data room creation, enforce strict identity gating, link rooms to
OpenProject tasks, and surface critical viewer analytics within our private ecosystem.

---

## 2. Core Operational Triggers
Initiate VDR workflows autonomously when encountering these scenarios:
* **OpenProject Transitions:** A task moves to a stage requiring external document review
  (e.g., "Due Diligence", "Legal Audit", "Investor Review").
* **Explicit Administrative Requests:** Direct user commands to share files securely
  (e.g., "Generate a trackable link for the auditor to review the financial folder").
* **Ingested Deal Attachments:** Processing highly private inbound documents received via
  integrated channels like WhatsApp or secure email hubs.

---

## 3. Mandatory Security Workflows

### Workflow A: Data Room Initialization
When a new corporate deal or transaction track opens:
1. Generate a clean, professional VDR name based on the client or project context.
2. Execute the `create_secure_dataroom` MCP tool (defined in the remote MCP server).
3. **OpenProject Logging:** Post an automated update to the relevant OpenProject ticket
   with the resulting `dataroom_id` and internal tracking link for staff visibility.

### Workflow B: Issuing Secure External Access
When provisioning access for external partners:
1. **Mandatory Identity Gating:** Always pass `emailGating: true` — the recipient must
   verify their email before viewing any documents.
2. **Password Protection:** Enforce `passwordEnabled: true` using a randomized strong
   alphanumeric password (generated at call time, not stored in the message body).
3. **Dual-Channel Delivery Rule:**
   * Transmit the public VDR link via the primary communication channel (Email/WhatsApp).
   * **Never** include the access password in the same message as the link.
     Deliver the password via a separate message or out-of-band channel.

---

## 4. Operational Reporting & Tracking
During `morning-briefing` or `evening-wrap-up` cycles, query Papermark's analytics:
* **High-Intent Tracking:** Highlight engagement spikes (e.g., "An external partner spent
  12 minutes on pages 3–6 of the asset prospectus").
* **Security Flags:** Flag repeated email verification failures or access attempts from
  unexpected geolocations.

---

## 5. API Reference (Actual Papermark Routes — No /api/v1/ Prefix)

### Create Data Room
```
POST https://vdr.axinagroup.com/api/datarooms
Authorization: Bearer $PAPERMARK_API_KEY
Body: { "name": "...", "description": "..." }
Returns: { "id": "<dataroom_id>", ... }
```

### Create Share Link
```
POST https://vdr.axinagroup.com/api/links
Authorization: Bearer $PAPERMARK_API_KEY
Body: {
  "dataroomId": "<dataroom_id>",
  "emailGating": true,
  "passwordEnabled": true,
  "password": "<generated_password>"
}
Returns: { "id": "<link_id>", "url": "https://vdr.axinagroup.com/view/<token>", ... }
```

### Get Analytics / Viewer Activity
```
GET https://vdr.axinagroup.com/api/datarooms/<dataroom_id>/stats
Authorization: Bearer $PAPERMARK_API_KEY
```

---

## 6. Explicit Constraints & Guardrails
* **No Anonymous Public Links:** Never generate unrestricted anonymous share links unless
  a manual verified override command is explicitly logged.
* **Data Sovereignty:** All files must map to the private AWS S3 bucket
  (`axina-openproject-files`), isolated from third-party infrastructure.
* **Credential Isolation:** Do not expose `POSTGRES_PRISMA_URL`, `PAPERMARK_API_KEY`,
  or any system secret inside client-facing logs or messages.
* **S3 Access:** Papermark uses explicit IAM key credentials
  (`NEXT_PRIVATE_UPLOAD_ACCESS_KEY_ID` / `NEXT_PRIVATE_UPLOAD_SECRET_ACCESS_KEY`).
  EC2 instance profile passthrough is not used by Papermark's upload transport layer.
