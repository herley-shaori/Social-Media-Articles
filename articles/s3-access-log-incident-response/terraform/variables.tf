variable "aws_region" {
  description = "AWS region for the simulation"
  type        = string
  default     = "ap-southeast-1"
}

variable "aws_profile" {
  description = "AWS CLI profile to use"
  type        = string
  default     = "admin@herley.dev"
}

variable "name_prefix" {
  description = "Prefix for bucket names, must be globally unique"
  type        = string
}

variable "public_read_enabled" {
  description = "Act 1/3 toggle: true = the accidental public-read bucket policy is in place (the vulnerability). false = it has been removed."
  type        = bool
  default     = true
}

variable "nightly_job_allowed" {
  description = "Act 4/5 toggle: whether the nightly-export-job role is explicitly granted PutObject in the tightened policy."
  type        = bool
  default     = false
}
