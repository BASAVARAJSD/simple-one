resource "aws_db_instance" "Demo-mysql-database" {
    identifier = "mysqldatabase"
    storage_type = "gp2"  
    allocated_storage = 20
    engine = "mysql"
    engine_version = "8.0"
    instance_class = "db.t2.micro"
    port = "3306"
    db_name = "myDemoDB"
    username = var.username
    password = var.password
    availability_zone = "us-east-1a"
    publicly_accessible = true 
    backup_retention_period = 0
    deletion_protection = false 
    skip_final_snapshot = true

    tags = {
      "name" = "Demo MySQL RDS Instance"
    }
}
