output "zone_id" {
  value       = aws_route53_zone.primary.zone_id
  description = "ID da zona hospedada no Route 53"
}

output "name_servers" {
  value       = aws_route53_zone.primary.name_servers
  description = "Name servers da zona hospedada"
}

output "fqdn" {
  value       = aws_route53_record.aws_endpoint.fqdn
  description = "FQDN do endpoint ponderado"
}
