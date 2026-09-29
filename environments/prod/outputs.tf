output "ec2_public_ip" {
  description = "Elastic IP of the WordPress EC2 instance"
  value       = module.ec2.public_ip
}

output "rds_endpoint" {
  description = "RDS MySQL endpoint (for debugging)"
  value       = module.rds.endpoint
}

output "efs_dns_name" {
  description = "EFS DNS name"
  value       = module.efs.efs_dns_name
}

output "wordpress_url" {
  description = "WordPress site URL"
  value       = "https://${var.domain_name}"
}

output "ssh_command" {
  description = "SSH command to connect to EC2"
  value       = "ssh -i ~/.ssh/${var.ec2_key_name}.pem ec2-user@${module.ec2.public_ip}"
}

output "route53_name_servers" {
  description = "IMPORTANT: Add these 4 NS records to onamae.com"
  value       = module.route53.name_servers
}
