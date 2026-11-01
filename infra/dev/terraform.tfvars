region      = "us-east-1"
team        = "quotes"
environment = "dev"

# Public subnets only, so there is no NAT gateway and no fixed monthly NAT cost.
# The task has no inbound rules, so nothing on the internet can reach it.
vpc_cidr = "10.0.0.0/16"

public_subnets = {
  public-a = { cidr_block = "10.0.1.0/24", availability_zone = "us-east-1a" }
}

# ECR
# One repository
ecr_repositories = {
  quotes = {}
}

# EFS
# One folder on the drive, mounted in the container at /data
efs_access_points = {
  data = {
    path        = "/sqlite-data"
    posix_uid   = 1000
    posix_gid   = 1000
    permissions = "0755"
  }
}

# App 
# Tags are immutable in ECR, so every new image needs a new tag. In CI use the commit SHA.
image_tag = "v1"

# Plain settings your script reads. Add whatever it expects, never passwords.
app_environment = {
  EMAIL_ADDRESS = "katechisom072@gmail.com"
  EMAIL_SENDER  = "katechisom072@gmail.com"
  DB_PATH       = "/data/storage.db"
}


app_secrets = { EMAIL_PASSWORD = "arn:aws:secretsmanager:us-east-1:905418429000:secret:quotes/emailpassword-qhvqUi" }


# Schedule 
# Every day at 07:00 Lagos time. Use rate(5 minutes) while testing.
schedule_expression = "cron(0 7 * * ? *)"
schedule_timezone   = "Africa/Lagos"

container_insights = true
log_retention_days = 14