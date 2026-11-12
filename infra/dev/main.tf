terraform {
  required_version = ">= 1.10.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = var.region
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  name       = "${var.team}-${var.environment}"
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.region

  # Role names (the IAM module uses the map key as the role name)
  exec_role_name  = "${local.name}-exec"
  task_role_name  = "${local.name}-task"
  sched_role_name = "${local.name}-sched"

  # ARNs built from names, so the IAM module does not depend on ECS
  cluster_arn         = "arn:aws:ecs:${local.region}:${local.account_id}:cluster/${local.name}-cluster"
  task_definition_arn = "arn:aws:ecs:${local.region}:${local.account_id}:task-definition/${local.name}-quotes"
  exec_role_arn       = "arn:aws:iam::${local.account_id}:role/${local.exec_role_name}"
  task_role_arn       = "arn:aws:iam::${local.account_id}:role/${local.task_role_name}"
}

# IAM
# All three roles live here: execution, task and scheduler
module "IAM" {
  source = "git::https://github.com/KateChukwusom/AWSTerraform_Modules.git//modules/IAM?ref=main"

  team        = var.team
  environment = var.environment

  cob_iam_assume_role = {
    (local.exec_role_name) = {
      trusted_principal_type = "Service"
      trusted_identifiers    = ["ecs-tasks.amazonaws.com"]
      managed_policy_arns    = ["arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"]
    }
    (local.task_role_name) = {
      trusted_principal_type = "Service"
      trusted_identifiers    = ["ecs-tasks.amazonaws.com"]
    }
    (local.sched_role_name) = {
      trusted_principal_type = "Service"
      trusted_identifiers    = ["scheduler.amazonaws.com"]
      trust_conditions = [{
        test     = "StringEquals"
        variable = "aws:SourceAccount"
        values   = [local.account_id]
      }]
    }
  }

  cob_iam_role_policy_statements = {
    # Execution role: read the secrets injected into the container
    (local.exec_role_name) = [{
      effect    = "Allow"
      actions   = ["secretsmanager:GetSecretValue"]
      resources = values(var.app_secrets)
    }]

    # Task role: what the running code may do (use EFS)
    (local.task_role_name) = [{
      effect    = "Allow"
      actions   = ["elasticfilesystem:ClientMount", "elasticfilesystem:ClientWrite"]
      resources = [module.EFS.file_system_arn]
    }]

    # Scheduler role: start the task and pass the two roles to ECS
    (local.sched_role_name) = [
      {
        effect    = "Allow"
        actions   = ["ecs:RunTask"]
        resources = [local.task_definition_arn, "${local.task_definition_arn}:*"]
        conditions = [{
          test     = "ArnEquals"
          variable = "ecs:cluster"
          values   = [local.cluster_arn]
        }]
      },
      {
        effect    = "Allow"
        actions   = ["iam:PassRole"]
        resources = [local.exec_role_arn, local.task_role_arn]
        conditions = [{
          test     = "StringLike"
          variable = "iam:PassedToService"
          values   = ["ecs-tasks.amazonaws.com"]
        }]
      }
    ]
  }
}

# NETWORK
module "Networking" {
  source = "git::https://github.com/KateChukwusom/AWSTerraform_Modules.git//modules/networking?ref=main"

  team           = var.team
  environment    = var.environment
  vpc_cidr       = var.vpc_cidr
  public_subnets = var.public_subnets
}

# IMAGE REPOSITORY
module "ECR" {
  source = "git::https://github.com/KateChukwusom/AWSTerraform_Modules.git//modules/ECR?ref=main"

  team             = var.team
  environment      = var.environment
  ecr_repositories = var.ecr_repositories
}

# STORAGE
module "EFS" {
  source = "git::https://github.com/KateChukwusom/AWSTerraform_Modules.git//modules/EFS?ref=main"

  team                       = var.team
  environment                = var.environment
  vpc_id                     = module.Networking.vpc_id
  subnet_ids                 = module.Networking.public_subnet_ids
  allowed_security_group_ids = values(module.ECS.service_security_group_ids)
  access_points              = var.efs_access_points
}

locals {
  ecs_services = {
    quotes = {
      container_image  = "${module.ECR.repository_urls["quotes"]}:${var.image_tag}"
      cpu              = 1024
      memory           = 3072
      create_service   = false
      assign_public_ip = true

      environment = var.app_environment
      secrets     = var.app_secrets

      efs_volumes = {
        data = {
          file_system_id  = module.EFS.file_system_id
          access_point_id = module.EFS.access_point_ids["data"]
          container_path  = "/data"
        }
      }
    }
  }
}

# CONTAINER PLATFORM
module "ECS" {
  source = "git::https://github.com/KateChukwusom/AWSTerraform_Modules.git//modules/ECS?ref=main"

  team               = var.team
  environment        = var.environment
  vpc_id             = module.Networking.vpc_id
  subnet_ids         = values(module.Networking.public_subnet_ids)
  container_insights = var.container_insights
  log_retention_days = var.log_retention_days
  ecs_services       = local.ecs_services

  execution_role_arn = module.IAM.role_arns[local.exec_role_name]
  task_role_arns     = { quotes = module.IAM.role_arns[local.task_role_name] }
}

# CLOCK
module "Scheduler" {
  source = "git::https://github.com/KateChukwusom/AWSTerraform_Modules.git//modules/scheduler?ref=main"

  team               = var.team
  environment        = var.environment
  scheduler_role_arn = module.IAM.role_arns[local.sched_role_name]

  schedules = {
    quotes = {
      schedule_expression = var.schedule_expression
      timezone            = var.schedule_timezone
      cluster_arn         = module.ECS.cluster_arn
      task_definition_arn = module.ECS.task_definition_arns["quotes"]
      subnet_ids          = values(module.Networking.public_subnet_ids)
      security_group_ids  = [module.ECS.service_security_group_ids["quotes"]]
      assign_public_ip    = true
    }
  }
}