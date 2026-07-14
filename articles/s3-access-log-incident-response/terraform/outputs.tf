output "exports_bucket" {
  value = aws_s3_bucket.exports.id
}

output "logs_bucket" {
  value = aws_s3_bucket.logs.id
}

output "nightly_export_job_role_arn" {
  value = aws_iam_role.nightly_export_job.arn
}
