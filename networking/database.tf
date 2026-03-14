# database.tf

# 1. RDS Subnet Group
resource "aws_db_subnet_group" "db_subnet_group" {
  name       = "${var.project_name}-db-subnet-group"
  subnet_ids = aws_subnet.db[*].id

  tags = { Name = "${var.project_name}-db-subnet-group" }
}

# 2. RDS Instance (PostgreSQL)
resource "aws_db_instance" "postgres" {
  identifier           = "${var.project_name}-db"
  allocated_storage     = 20
  storage_type         = "gp2"
  engine               = "postgres"
  engine_version       = "15.4" # Or latest available
  instance_class       = "db.t3.micro"
  db_name              = var.db_name
  username             = var.db_username
  password             = var.db_password
  parameter_group_name = "default.postgres15"
  skip_final_snapshot  = true
  multi_az             = false # Set to true for HA in production

  db_subnet_group_name   = aws_db_subnet_group.db_subnet_group.name
  vpc_security_group_ids = [aws_security_group.db_sg.id]

  tags = { Name = "${var.project_name}-db" }
}
