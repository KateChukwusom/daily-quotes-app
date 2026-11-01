# Values printed after apply, handy for pushing the image and watching the logs
output "ecr_repository_urls" {
  value = module.ECR.repository_urls
}

output "ecs_cluster_name" {
  value = module.ECS.cluster_name
}

output "efs_file_system_id" {
  value = module.EFS.file_system_id
}

output "log_group_names" {
  value = module.ECS.log_group_names
}

output "schedule_arns" {
  value = module.Scheduler.schedule_arns
}