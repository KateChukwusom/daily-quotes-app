# Every value the composition needs is declared here and given a value in terraform.tfvars.
# The modules validate most of these themselves, so the checks here are kept light.
variable "cob_iam_assume_role" {
  type = map(object({
    trusted_principal_type = string
    trusted_identifiers    = list(string)
  }))
}

variable "cob_iam_role_policy_statements" {
  type = any
}

variable "region" {
  type        = string
  description = "AWS region everything is created in"
}

variable "team" {
  type        = string
  description = "Team name, used in resource names and tags (lowercase, max 20 characters)"
}

variable "environment" {
  type        = string
  description = "dev or prod"
}

variable "vpc_cidr" {
  type        = string
  description = "IP range of the VPC"
}

variable "public_subnets" {
  type = map(object({
    cidr_block        = string
    availability_zone = string
  }))
  description = "Public subnets keyed by name"
}

variable "private_subnets" {
  type = map(object({
    cidr_block        = string
    availability_zone = string
  }))
  description = "Private subnets keyed by name, empty because this job runs in public subnets"
  default     = {}
}

variable "nat_gateway_subnet_keys" {
  type        = list(string)
  description = "Public subnet keys that host a NAT gateway, empty means no NAT"
  default     = []
}

variable "ecr_repositories" {
  type = map(object({
    image_tag_mutability = optional(string, "IMMUTABLE")
    scan_on_push         = optional(bool, true)
    force_delete         = optional(bool, false)
    max_image_count      = optional(number, 30)
    kms_key_arn          = optional(string)
  }))
  description = "Image repositories to create, keyed by short name"
}

variable "efs_access_points" {
  type = map(object({
    path        = string
    posix_uid   = optional(number, 1000)
    posix_gid   = optional(number, 1000)
    permissions = optional(string, "0750")
  }))
  description = "Folders on the EFS drive the container is allowed to use, keyed by name"
}

variable "image_tag" {
  type        = string
  description = "Tag of the image pushed to ECR. Tags are immutable, so every new image needs a new tag (use the commit SHA in CI)"
}

variable "app_environment" {
  type        = map(string)
  description = "Plain environment variables for the container, never passwords"
  default     = {}
}

variable "app_secrets" {
  type        = map(string)
  description = "ENV_NAME = Secrets Manager or SSM parameter ARN, for things like the SMTP password"
  default     = {}
}


variable "schedule_expression" {
  type        = string
  description = "When the job runs, for example cron(0 8 * * ? *) or rate(5 minutes)"
}

variable "schedule_timezone" {
  type        = string
  description = "Timezone the schedule is read in, so the send time does not drift"
  default     = "UTC"
}

variable "container_insights" {
  type        = bool
  description = "Turn on CloudWatch Container Insights for the cluster"
  default     = true
}

variable "log_retention_days" {
  type        = number
  description = "How many days container logs are kept"
  default     = 14
}