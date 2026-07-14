data "aws_caller_identity" "current" {}

# --- Log destination bucket -------------------------------------------------

resource "aws_s3_bucket" "logs" {
  bucket = "${var.name_prefix}-logs"
}

resource "aws_s3_bucket_public_access_block" "logs" {
  bucket                  = aws_s3_bucket.logs.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Grant the S3 log delivery service permission to write into this bucket.
# This is the modern (non-ACL) way to receive server access logs.
resource "aws_s3_bucket_policy" "logs" {
  bucket = aws_s3_bucket.logs.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "S3ServerAccessLogsPolicy"
        Effect    = "Allow"
        Principal = { Service = "logging.s3.amazonaws.com" }
        Action    = "s3:PutObject"
        Resource  = "${aws_s3_bucket.logs.arn}/access-logs/*"
        Condition = {
          ArnLike = {
            "aws:SourceArn" = aws_s3_bucket.exports.arn
          }
          StringEquals = {
            "aws:SourceAccount" = data.aws_caller_identity.current.account_id
          }
        }
      }
    ]
  })
}

# --- Source bucket (the "exports" bucket in the article) -------------------

resource "aws_s3_bucket" "exports" {
  bucket = "${var.name_prefix}-exports"
}

# Block Public Access is relaxed only while public_read_enabled=true, to let
# the intentionally-broad bucket policy below actually take effect. This
# mirrors Act 3 of the article: a real, reachable misconfiguration, not a
# theoretical one. It is re-enabled the moment the policy is tightened.
resource "aws_s3_bucket_public_access_block" "exports" {
  bucket                  = aws_s3_bucket.exports.id
  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = !var.public_read_enabled
  restrict_public_buckets = !var.public_read_enabled
}

resource "aws_s3_bucket_logging" "exports" {
  bucket        = aws_s3_bucket.exports.id
  target_bucket = aws_s3_bucket.logs.id
  target_prefix = "access-logs/"
}

# Dummy export objects used to generate realistic, sequential-looking keys
# for the log evidence. Content is placeholder text, not real customer data.
resource "aws_s3_object" "exports" {
  for_each = toset([
    "exports/customer-2026-01.csv",
    "exports/customer-2026-02.csv",
    "exports/customer-2026-03.csv",
    "exports/customer-2026-04.csv",
  ])
  bucket  = aws_s3_bucket.exports.id
  key     = each.value
  content = "id,region\n1,placeholder\n"
}

resource "aws_s3_object" "report" {
  bucket  = aws_s3_bucket.exports.id
  key     = "reports/q2-summary.pdf"
  content = "placeholder report content"
}

# --- The nightly export job's IAM role --------------------------------------
# A stand-in for a legitimate automated job that writes new exports nightly.

resource "aws_iam_role" "nightly_export_job" {
  name = "${var.name_prefix}-nightly-export-job"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root" }
        Action    = "sts:AssumeRole"
      }
    ]
  })
}

# --- Bucket policy: the vulnerability, the tightening, and the fix ---------
#
# Statements are assembled from toggles so the same config can be applied
# three times to reproduce each act of the article:
#   1. public_read_enabled=true,  nightly_job_allowed=(irrelevant) -> Act 3 state
#   2. public_read_enabled=false, nightly_job_allowed=false        -> Act 4 state (broken)
#   3. public_read_enabled=false, nightly_job_allowed=true         -> Act 5 state (fixed)

resource "aws_s3_bucket_policy" "exports" {
  # Must wait for the public access block to finish updating first, or a
  # public-read policy write can race ahead of it and fail with 403.
  depends_on = [aws_s3_bucket_public_access_block.exports]

  bucket = aws_s3_bucket.exports.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat(
      [
        {
          Sid       = "DenyInsecureTransport"
          Effect    = "Deny"
          Principal = "*"
          Action    = "s3:*"
          Resource  = [aws_s3_bucket.exports.arn, "${aws_s3_bucket.exports.arn}/*"]
          Condition = { Bool = { "aws:SecureTransport" = "false" } }
        }
      ],
      var.public_read_enabled ? [
        {
          # This single broad statement is the actual root cause: it was
          # meant to let the nightly job read/write exports without anyone
          # having to configure a separate IAM identity policy for it, but
          # Principal was left as "*" and Resource as the whole bucket
          # instead of being scoped to the job's own role ARN. It grants
          # GetObject to the entire internet AND is the only thing
          # currently authorizing the nightly job's PutObject calls.
          Sid       = "AccidentalPublicReadWriteOfExports"
          Effect    = "Allow"
          Principal = "*"
          Action    = ["s3:GetObject", "s3:PutObject"]
          Resource  = "${aws_s3_bucket.exports.arn}/*"
        }
      ] : [],
      var.nightly_job_allowed ? [
        {
          Sid       = "NightlyExportJobWrite"
          Effect    = "Allow"
          Principal = { AWS = aws_iam_role.nightly_export_job.arn }
          Action    = "s3:PutObject"
          Resource  = "${aws_s3_bucket.exports.arn}/exports/*"
        }
      ] : []
    )
  })
}
