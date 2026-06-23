# Copyright (c) 2026 Yom Shore Ventures LLC
# dba: CTO Rescues - https://ctorescues.com/
# Author: Daniel Brody (@dzbrody)
#
# All rights reserved. Proprietary and confidential.

# ============================================================
# ctorescues.com — DNS, SES, TLS Secrets, IAM
#
# Hosted zone: YOUR_TSPGUSA_ZONE_ID (ctorescues.com, Route 53)
# EC2 Elastic IP: shared with ctorescues.com services (aws_eip.openproject)
#
# Subdomains served:
#   projects.ctorescues.com  → OpenProject
#   files.ctorescues.com     → Nextcloud
#   erp.ctorescues.com       → ERP/Frappe
#
# Mail: no-reply@ctorescues.com via SES (us-east-1)
# TLS:  *.ctorescues.com wildcard cert from internal CA, stored in Secrets Manager
# ============================================================

# ── Route 53 zone (pre-existing, registered in Route 53) ─────────────────────

data "aws_route53_zone" "tspgusa" {
  zone_id = "YOUR_TSPGUSA_ZONE_ID"
}

# Look up the EIP by its known public IP rather than referencing aws_eip.openproject,
# which is in a drifted state (original instance YOUR_INSTANCE_ID no longer exists).
# The EIP itself (YOUR_EC2_ELASTIC_IP / YOUR_EIP_ALLOCATION_ID) is healthy and attached
# to the real instance YOUR_INSTANCE_ID.
data "aws_eip" "openproject" {
  public_ip = "YOUR_EC2_ELASTIC_IP"
}

# ── A records — all four subdomains → EC2 Elastic IP ─────────────────────────

resource "aws_route53_record" "tspgusa_projects" {
  zone_id = data.aws_route53_zone.tspgusa.zone_id
  name    = "projects.ctorescues.com"
  type    = "A"
  ttl     = 300
  records = [data.aws_eip.openproject.public_ip]
}

resource "aws_route53_record" "tspgusa_files" {
  zone_id = data.aws_route53_zone.tspgusa.zone_id
  name    = "files.ctorescues.com"
  type    = "A"
  ttl     = 300
  records = [data.aws_eip.openproject.public_ip]
}

resource "aws_route53_record" "tspgusa_erp" {
  zone_id = data.aws_route53_zone.tspgusa.zone_id
  name    = "erp.ctorescues.com"
  type    = "A"
  ttl     = 300
  records = [data.aws_eip.openproject.public_ip]
}

# ── SES — domain identity for ctorescues.com ────────────────────────────────────

resource "aws_ses_domain_identity" "tspgusa" {
  domain = "ctorescues.com"
}

# SES domain verification TXT record (_amazonses.ctorescues.com)
# SES auto-verifies once this propagates — no manual step needed.
resource "aws_route53_record" "tspgusa_ses_verification" {
  zone_id = data.aws_route53_zone.tspgusa.zone_id
  name    = "_amazonses.ctorescues.com"
  type    = "TXT"
  ttl     = 600
  records = [aws_ses_domain_identity.tspgusa.verification_token]
}

# ── SES Easy DKIM — 3 CNAME records ──────────────────────────────────────────
# SES signs outbound mail with d=ctorescues.com, giving strict DKIM alignment.

resource "aws_ses_domain_dkim" "tspgusa" {
  domain = aws_ses_domain_identity.tspgusa.domain
}

resource "aws_route53_record" "tspgusa_dkim" {
  count   = 3
  zone_id = data.aws_route53_zone.tspgusa.zone_id
  name    = "${aws_ses_domain_dkim.tspgusa.dkim_tokens[count.index]}._domainkey.ctorescues.com"
  type    = "CNAME"
  ttl     = 1800
  records = ["${aws_ses_domain_dkim.tspgusa.dkim_tokens[count.index]}.dkim.amazonses.com"]
}

# ── SPF — root domain TXT record ─────────────────────────────────────────────
# Authorises SES (us-east-1) to send mail on behalf of ctorescues.com.
# ~all = softfail for anything not in the list (recommended over -all initially).

resource "aws_route53_record" "tspgusa_spf" {
  zone_id = data.aws_route53_zone.tspgusa.zone_id
  name    = "ctorescues.com"
  type    = "TXT"
  ttl     = 300
  records = ["v=spf1 include:amazonses.com ~all"]
}

# ── SES custom MAIL FROM domain (mail.ctorescues.com) ───────────────────────────
# Sets the envelope From to mail.ctorescues.com so SPF passes with relaxed alignment
# and bounce/complaint notifications are routed back to SES.

resource "aws_ses_domain_mail_from" "tspgusa" {
  domain           = aws_ses_domain_identity.tspgusa.domain
  mail_from_domain = "mail.ctorescues.com"

  # SES default behavior if MX lookup fails — still send (recommended for prod)
  behavior_on_mx_failure = "UseDefaultValue"
}

# MX record for the MAIL FROM subdomain — required by SES for bounce routing
resource "aws_route53_record" "tspgusa_mail_from_mx" {
  zone_id = data.aws_route53_zone.tspgusa.zone_id
  name    = "mail.ctorescues.com"
  type    = "MX"
  ttl     = 300
  records = ["10 feedback-smtp.us-east-1.amazonses.com"]
}

# SPF for MAIL FROM subdomain — SES checks this for envelope-from
resource "aws_route53_record" "tspgusa_mail_from_spf" {
  zone_id = data.aws_route53_zone.tspgusa.zone_id
  name    = "mail.ctorescues.com"
  type    = "TXT"
  ttl     = 300
  records = ["v=spf1 include:amazonses.com ~all"]
}

# ── DMARC ─────────────────────────────────────────────────────────────────────
# p=quarantine: suspicious mail goes to spam (not rejected outright).
#   Upgrade to p=reject once you've confirmed no legitimate mail is failing.
# adkim=r: relaxed DKIM alignment (d= must be ctorescues.com or subdomain).
# aspf=r: relaxed SPF alignment (mail.ctorescues.com satisfies ctorescues.com).
# rua: aggregate reports sent daily — review these to tune policy.
# fo=1: generate forensic report on any auth failure (useful during ramp-up).

resource "aws_route53_record" "tspgusa_dmarc" {
  zone_id = data.aws_route53_zone.tspgusa.zone_id
  name    = "_dmarc.ctorescues.com"
  type    = "TXT"
  ttl     = 300
  records = ["v=DMARC1; p=quarantine; adkim=r; aspf=r; rua=mailto:dmarc-reports@ctorescues.com; fo=1"]
}

# ── Secrets Manager — wildcard cert placeholders ─────────────────────────────
# After `terraform apply`, populate these via the AWS Console or CLI:
#   aws secretsmanager put-secret-value --secret-id ctorescues/wildcard-cert --secret-string "$(cat fullchain.pem)"
#   aws secretsmanager put-secret-value --secret-id ctorescues/wildcard-key  --secret-string "$(cat privkey.pem)"
# Then run: aws s3 cp scripts/fetch-ctorescues-cert.sh ... && bash fetch-ctorescues-cert.sh

resource "aws_secretsmanager_secret" "tspgusa_wildcard_cert" {
  name                    = "ctorescues/wildcard-cert"
  description             = "*.ctorescues.com wildcard TLS certificate — fullchain PEM (cert + intermediates from internal CA)"
  recovery_window_in_days = 0

  tags = {
    Name    = "ctorescues-wildcard-cert"
    Domain  = "ctorescues.com"
    Managed = "terraform"
  }
}

resource "aws_secretsmanager_secret" "tspgusa_wildcard_key" {
  name                    = "ctorescues/wildcard-key"
  description             = "*.ctorescues.com wildcard TLS private key — PEM (internal CA)"
  recovery_window_in_days = 0

  tags = {
    Name    = "ctorescues-wildcard-key"
    Domain  = "ctorescues.com"
    Managed = "terraform"
  }
}

# ── IAM — EC2 role: read ctorescues cert secrets ────────────────────────────────
# Reference the existing role by name (data source) rather than the drifted resource.

data "aws_iam_role" "openproject" {
  name = "ctorescues-openproject-role"
}

data "aws_iam_policy_document" "tspgusa_cert_secrets" {
  statement {
    sid    = "ReadTspgusaWildcardCert"
    effect = "Allow"
    actions = ["secretsmanager:GetSecretValue"]
    resources = [
      aws_secretsmanager_secret.tspgusa_wildcard_cert.arn,
      aws_secretsmanager_secret.tspgusa_wildcard_key.arn,
    ]
  }
}

resource "aws_iam_role_policy" "tspgusa_cert_secrets" {
  name   = "tspgusa-cert-secrets-access"
  role   = data.aws_iam_role.openproject.name
  policy = data.aws_iam_policy_document.tspgusa_cert_secrets.json
}

# ── IAM — EC2 role: send via SES from @ctorescues.com ───────────────────────────

data "aws_iam_policy_document" "tspgusa_ses_send" {
  statement {
    sid    = "SesSendFromTspgusa"
    effect = "Allow"
    actions = ["ses:SendEmail", "ses:SendRawEmail"]
    resources = ["*"]
    condition {
      test     = "StringLike"
      variable = "ses:FromAddress"
      values   = ["*@ctorescues.com"]
    }
  }
}

resource "aws_iam_role_policy" "tspgusa_ses_send" {
  name   = "tspgusa-ses-send"
  role   = data.aws_iam_role.openproject.name
  policy = data.aws_iam_policy_document.tspgusa_ses_send.json
}

# ── Outputs ───────────────────────────────────────────────────────────────────

output "tspgusa_ses_verification_token" {
  description = "SES domain verification token — added to DNS automatically by this module"
  value       = aws_ses_domain_identity.tspgusa.verification_token
}

output "tspgusa_dkim_tokens" {
  description = "SES Easy DKIM tokens — CNAME records added to DNS automatically by this module"
  value       = aws_ses_domain_dkim.tspgusa.dkim_tokens
}

output "tspgusa_cert_secret_arn" {
  description = "Secrets Manager ARN for *.ctorescues.com fullchain — populate after apply"
  value       = aws_secretsmanager_secret.tspgusa_wildcard_cert.arn
}

output "tspgusa_key_secret_arn" {
  description = "Secrets Manager ARN for *.ctorescues.com private key — populate after apply"
  value       = aws_secretsmanager_secret.tspgusa_wildcard_key.arn
}
