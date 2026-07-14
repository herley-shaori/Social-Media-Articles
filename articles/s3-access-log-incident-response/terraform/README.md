# Terraform: S3 Access Log Incident Simulation

This is the canonical, referenceable copy of the Terraform configuration used
in the article "Tracing Access Denied Errors and Suspicious Requests Through
S3 Access Logs." The full article, log-format walkthrough, and simulation
results live in the `herley-dev` repository:

https://github.com/herley-shaori/herley-dev/tree/master/articles/s3-access-log-incident-response

## What this provisions

An S3 bucket (`exports`), a separate log-destination bucket with S3 Server
Access Logging enabled, an IAM role (`nightly-export-job`), and a bucket
policy assembled from two boolean variables so the same configuration
reproduces three incident states in sequence:

| Variables | State |
|---|---|
| `public_read_enabled=true` | Public exposure via an overly broad bucket policy statement |
| `public_read_enabled=false`, `nightly_job_allowed=false` | Exposure fixed, but the legitimate role's write access breaks as a side effect |
| `nightly_job_allowed=true` | Scoped fix: exposure stays closed, role's access restored narrowly |

## Usage

```
cp terraform.tfvars.example terraform.tfvars
# edit terraform.tfvars: set a globally-unique name_prefix
terraform init
terraform apply -var public_read_enabled=true
terraform apply -var public_read_enabled=false -var nightly_job_allowed=false
terraform apply -var nightly_job_allowed=true
terraform destroy
```

`terraform.tfvars` is gitignored — never commit real bucket names or
account-specific values there.

## Keeping this in sync

This is a duplicate of `herley-dev/articles/s3-access-log-incident-response/terraform/`,
kept here so the code can be referenced/linked independently of the article
repo. If you change one copy, update the other. The article in `herley-dev`
links to specific-commit permalinks in this repo for each file below.
