resource "aws_security_group" "pg_security_group" {
  name        = var.aws_security_group_name_pg
  description = "SG for ${var.aws_resource_identifier} - PG"
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "${var.aws_resource_identifier}-pg"
  }
}

resource "aws_security_group_rule" "ingress_postgres" {
  type              = "ingress"
  description       = "${var.aws_resource_identifier} - pgPort"
  from_port         = tonumber(var.aws_postgres_database_port)
  to_port           = tonumber(var.aws_postgres_database_port)
  protocol          = "tcp"
  cidr_blocks       = ["80.79.194.23/32","80.79.194.3/32",var.github_runner_ip]
  security_group_id = aws_security_group.pg_security_group.id
}

resource "aws_rds_cluster" "aurora" {
  depends_on     = [data.aws_subnets.vpc_subnets,aws_security_group_rule.ingress_postgres]
  cluster_identifier = var.aws_resource_identifier
  engine         = var.aws_postgres_engine
  engine_version = var.aws_postgres_engine_version

  serverlessv2_scaling_configuration {
    max_capacity = 1.0
    min_capacity = 0.5
  }

  # Todo: handle vpc/networking explicitly
  # vpc_id                 = var.vpc_id
  # allowed_cidr_blocks    = [var.vpc_cidr]
  #subnets                  = var.aws_postgres_subnets == null || length(var.aws_postgres_subnets) == 0 ? data.aws_subnets.vpc_subnets.ids : var.aws_postgres_subnets

  port                   = var.aws_postgres_database_port
  deletion_protection    = var.aws_postgres_database_protection
  storage_encrypted      = true
  #db_subnet_group_name   = "${var.aws_resource_identifier}-pg"
  vpc_security_group_ids = [aws_security_group.pg_security_group.id]

  # TODO: take advantage of iam database auth
  iam_database_authentication_enabled    = true
  master_username                        = "postgres"
  master_password                        = random_password.rds.result
  apply_immediately                      = true
  skip_final_snapshot                    = var.aws_postgres_database_final_snapshot == "" ? true : false
  #snapshot_identifier                    = var.aws_postgres_database_final_snapshot
  #db_cluster_parameter_group_name        = var.aws_resource_identifier

  #db_instance_parameter_group_name        = var.aws_resource_identifier
  enabled_cloudwatch_logs_exports = var.aws_postgres_engine == "aurora-postgresql" ? ["postgresql"] : ["audit","error","general","slowquery"]
  tags = {
    Name = "${var.aws_resource_identifier}-RDS"
  }
}

resource "aws_rds_cluster_instance" "aurora" {
  depends_on          = [aws_rds_cluster.aurora]
  #db_subnet_group_name   = "${var.aws_resource_identifier}-pg"
  cluster_identifier  = aws_rds_cluster.aurora.id
  instance_class      = var.aws_postgres_instance_class
  engine              = aws_rds_cluster.aurora.engine
  engine_version      = aws_rds_cluster.aurora.engine_version
  apply_immediately   = true
  publicly_accessible = true
}

provider "postgresql" {
  host     = aws_rds_cluster.aurora.endpoint
  database = aws_rds_cluster.aurora.database_name
  port     = var.aws_postgres_database_port
  username = "postgres"
  password = random_password.rds.result
}

resource "postgresql_database" "db" {
  depends_on = [aws_rds_cluster_instance.aurora]
  for_each  = toset( split(",", var.aws_postgres_database_name))
  name  = each.key
  owner = aws_rds_cluster.aurora.master_username
}

resource "random_password" "rds" {
  length = 10
  special = false
}

// Creates a secret manager secret for the databse credentials
resource "aws_secretsmanager_secret" "database_credentials" {
   name   = "${var.aws_resource_identifier_supershort}-ec2db-pub-${random_string.random_sm.result}"
}
 
resource "aws_secretsmanager_secret_version" "database_credentials_sm_secret_version" {
  secret_id = aws_secretsmanager_secret.database_credentials.id
  secret_string = <<EOF
   {
    "key": "database_password",
    "value": "${sensitive(random_password.rds.result)}"
   }
EOF
}

resource "random_string" "random_sm" {
  length    = 5
  lower     = true
  special   = false
  numeric   = false
}
