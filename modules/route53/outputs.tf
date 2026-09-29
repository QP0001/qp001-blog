output "zone_id" {
  value = aws_route53_zone.main.zone_id
}

output "name_servers" {
  description = "Add these 4 NS records to your domain registrar (onamae.com)"
  value       = aws_route53_zone.main.name_servers
}
