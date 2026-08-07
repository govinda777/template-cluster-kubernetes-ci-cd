resource "aws_route53_zone" "primary" {
  name          = var.domain_name
  force_destroy = true

  tags = {
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

resource "aws_route53_record" "aws_endpoint" {
  zone_id = aws_route53_zone.primary.zone_id
  name    = "${var.subdomain}.${var.domain_name}"
  type    = "CNAME"
  ttl     = 60

  weighted_routing_policy {
    weight = var.aws_weight
  }

  set_identifier = "aws-endpoint"
  records        = [var.aws_target]
}

resource "aws_route53_record" "gcp_endpoint" {
  zone_id = aws_route53_zone.primary.zone_id
  name    = "${var.subdomain}.${var.domain_name}"
  type    = "CNAME"
  ttl     = 60

  weighted_routing_policy {
    weight = var.gcp_weight
  }

  set_identifier = "gcp-endpoint"
  records        = [var.gcp_target]
}
