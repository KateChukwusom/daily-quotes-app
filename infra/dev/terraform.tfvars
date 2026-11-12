region      = "us-east-1"
team        = "quotemail"
environment = "dev"

vpc_cidr = "10.0.0.0/16"

public_subnets = {
  public-a = { cidr_block = "10.0.1.0/24", availability_zone = "us-east-1a" }
}

# ECR
ecr_repositories = {
  quotes = {}
}

# EFS
efs_access_points = {
  data = {
    path        = "/sqlite-data"
    posix_uid   = 1000
    posix_gid   = 1000
    permissions = "0755"
  }
}

# App
# Tags are immutable in ECR, so every new image needs a new tag.
image_tag = "v1"

app_environment = {
  EMAIL_ADDRESS       = "katechisom072@gmail.com"
  ADMIN_EMAIL_ADDRESS = "katechisom072@gmail.com"
  DB_PATH             = "/data/storage.db"
}

app_secrets = {
  EMAIL_PASSWORD = "arn:aws:secretsmanager:us-east-1:905418429000:secret:quotes/emailpassword-qhvqUi"
}

# Schedule 
schedule_expression = "cron(0 0,7,14,21 * * ? *)"
schedule_timezone   = "Africa/Lagos"

container_insights = true
log_retention_days = 14