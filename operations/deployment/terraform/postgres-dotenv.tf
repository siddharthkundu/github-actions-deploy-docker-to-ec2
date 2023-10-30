# Additional postgres configuration in postgres.tf

resource "local_file" "postgres-dotenv" {
  count = var.aws_enable_postgres == "true" ? 1 : 0
  filename = format("%s/%s", abspath(path.root), "postgres.env")
  content  = <<-EOT

####
#### Postgres values
####

# Amazon Resource Name (ARN) of cluster
POSTGRES_CLUSTER_ARN=${aws_rds_cluster.aurora[0].arn}

# The RDS Cluster Identifier
POSTGRES_CLUSTER_ID=${aws_rds_cluster.aurora[0].id}

# The RDS Cluster Resource ID
POSTGRES_CLUSTER_RESOURCE_ID=${aws_rds_cluster.aurora[0].cluster_resource_id}

# Writer endpoint for the cluster
POSTGRES_CLUSTER_ENDPOINT=${aws_rds_cluster.aurora[0].endpoint}

# A read-only endpoint for the cluster, automatically load-balanced across replicas
POSTGRES_CLUSTER_READER_ENDPOINT=${aws_rds_cluster.aurora[0].reader_endpoint}

# The running version of the cluster database
POSTGRES_CLUSTER_ENGINE_VERSION_ACTUAL=${aws_rds_cluster.aurora[0].engine_version_actual}

# Name for an automatically created database on cluster creation
# database_name is not set on `aws_rds_cluster[0]` resource if it was not specified, so can't be used in output
POSTGRES_CLUSTER_DATABASE_NAME=${aws_rds_cluster.aurora[0].database_name == null ? "" : aws_rds_cluster.aurora[0].database_name}

# The database port
POSTGRES_CLUSTER_PORT=${aws_rds_cluster.aurora[0].port}


# TODO: use IAM (give ec2 instance(s) access to the DB via a role)
# The database master password
POSTGRES_CLUSTER_MASTER_PASSWORD=${aws_rds_cluster.aurora[0].master_user_secret}

# The database master username
POSTGRES_CLUSTER_MASTER_USERNAME=${aws_rds_cluster.aurora[0].master_username}

# The Route53 Hosted Zone ID of the endpoint
POSTGRES_CLUSTER_HOSTED_ZONE_ID=${aws_rds_cluster.aurora[0].hosted_zone_id}


# POSTGRES specific env vars
PG_USER="${aws_rds_cluster.aurora[0].master_username}"
PG_PASSWORD="${aws_rds_cluster.aurora[0].master_user_secret}"
PGDATABASE=${aws_rds_cluster.aurora[0].database_name == null ? "" : aws_rds_cluster.aurora[0].database_name}
PGPORT="${aws_rds_cluster.aurora[0].port}"
PGHOST="${aws_rds_cluster.aurora[0].endpoint}"
EOT
}
