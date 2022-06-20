output "smtp_host" {
  description = "SMTP server host to connect to for given AWS region"
  value       = "email-smtp.${var.aws_region}.amazonaws.com"
}

# The SMTP username used for sending email via SES
output "smtp_username" {
  description = "User for sending SMTP email"
  value       = aws_iam_access_key.catalog_smtp_key.id
}

# The SMTP password used for sending email via SES
output "smtp_password" {
  description = "Password for sending SMTP email"
  value       = aws_iam_access_key.catalog_smtp_key.ses_smtp_password_v4
  sensitive   = true
}

