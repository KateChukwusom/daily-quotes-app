terraform {
  required_version = ">= 1.9.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

# Tells Terraform which AWS region to build everything in
provider "aws" {
  region = var.region
}

# NETWORK
# The VPC and subnets everything else lives in. Only public subnets are used
module "Networking" {
  source = "git::https://github.com/KateChukwusom/AWSTerraform_Modules.git//modules/Networking?ref=v1.0.0"

  team                    = var.team
  environment             = var.environment
  vpc_cidr                = var.vpc_cidr
  public_subnets          = var.public_subnets
}

# IMAGE REPOSITORY
# The place the Docker image is pushed to. ECS pulls the image from here when the job runs.
module "ECR" {
  source = "git::https://github.com/KateChukwusom/AWSTerraform_Modules.git//modules/ECR?ref=v1.0.0"

  team             = var.team
  environment      = var.environment
  ecr_repositories = var.ecr_repositories
}

# STORAGE
#The volume mount to replace the container's ephemeral root file system 
module "EFS" {
  source = "git::https://github.com/KateChukwusom/AWSTerraform_Modules.git//modules/EFS?ref=v1.0.0"

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
      #Repo address and image tag
      container_image = "${module.ECR.repository_urls["quotes"]}:${var.image_tag}"

      # Fargate task size: 1 vCPU and 3 GiB (memory is in MiB)
      cpu    = 1024
      memory = 3072

      # false means "only create the task definition". The Scheduler starts it, ECS does not keep it running.
      create_service = false

      # The task sits in a public subnet, so it needs a public IP to reach ECR and CloudWatch
      assign_public_ip = true

      environment = var.app_environment
      secrets     = var.app_secrets

      # Mounts the EFS access point inside the container at /data
      efs_volumes = {
        data = {
          file_system_id  = module.EFS.file_system_id
          access_point_id = module.EFS.access_point_ids["data"]
          container_path  = "/data"
        }
      }

      # Lets the task mount and write to the EFS file system
      task_role_policy_statements = [{
        effect    = "Allow"
        actions   = ["elasticfilesystem:ClientMount", "elasticfilesystem:ClientWrite"]
        resources = [module.EFS.file_system_arn]
      }]
    }
  }
}

# CONTAINER PLATFORM
# Creates the cluster, log group, security group, IAM roles and task definition.
module "ECS" {
  source = "git::https://github.com/KateChukwusom/AWSTerraform_Modules.git//modules/ECS?ref=v1.0.0"

  team               = var.team
  environment        = var.environment
  vpc_id             = module.Networking.vpc_id
  subnet_ids         = values(module.Networking.public_subnet_ids)
  container_insights = var.container_insights
  log_retention_days = var.log_retention_days
  ecs_services       = local.ecs_services
}

# CLOCK
# Starts the quotes task on a schedule and creates the role the scheduler uses to do that.
module "Scheduler" {
  source = "git::https://github.com/KateChukwusom/AWSTerraform_Modules.git//modules/Scheduler?ref=v1.0.0"

  team        = var.team
  environment = var.environment

  schedules = {
    quotes = {
      schedule_expression = var.schedule_expression
      timezone            = var.schedule_timezone
      cluster_arn         = module.ECS.cluster_arn
      task_definition_arn = module.ECS.task_definition_arns["quotes"]
      execution_role_arn  = module.ECS.execution_role_arn
      task_role_arn       = module.ECS.task_role_arns["quotes"]
      subnet_ids          = values(module.Networking.public_subnet_ids)
      security_group_ids  = [module.ECS.service_security_group_ids["quotes"]]
      assign_public_ip    = true
    }
  }
}