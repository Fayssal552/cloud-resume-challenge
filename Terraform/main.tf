# Create S3 bucket
resource "aws_s3_bucket" "fisl" {
  bucket = "mybucket-fisl-123"
}


# Origin Acess Control OAC
resource "aws_cloudfront_origin_access_control" "cloudfront_s3_oac" {
  name                              = "CloudFront S3 OAC"
  description                       = "Cloud Front S3 OAC"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# Cloudfront Distribution
locals {
  s3_origin_id = "Fisl-myS3Origin"
}

resource "aws_cloudfront_distribution" "my_distrib" {

  origin {
    domain_name = aws_s3_bucket.fisl.bucket_regional_domain_name
    origin_id   = local.s3_origin_id
    origin_access_control_id = aws_cloudfront_origin_access_control.cloudfront_s3_oac.id
  }
	
	aliases             = ["resumee.fayssal.online"]
	
	enabled             = true   # required (Whether the distribution is enabled to accept end user requests for content.)
  is_ipv6_enabled     = true   # Optional
  comment             = "Some comment"
  default_root_object = "index.html"

	default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = local.s3_origin_id

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "allow-all"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

	restrictions {
    geo_restriction {
      restriction_type = "none"
      locations        = []
    }
  }
	
	# viewer_certificate {
  #   cloudfront_default_certificate = true
  # }
  viewer_certificate {
    acm_certificate_arn = module.acm.acm_certificate_arn
    ssl_support_method = "sni-only"
  }
	
}

# Bucket IAM Policy
data "aws_iam_policy_document" "s3_bucket_policy" {
  statement {
    actions = [ "s3:GetObject" ]
    resources = [ "${aws_s3_bucket.fisl.arn}/*" ]
    principals {
      type = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }
    condition {
      test = "StringEquals"
      variable = "AWS:SourceArn"
      values = [aws_cloudfront_distribution.my_distrib.arn]
    }
  }
}

# bucket Policy
resource "aws_s3_bucket_policy" "cdn-oac-bucket-policy" {
  bucket = aws_s3_bucket.fisl.id
  policy = data.aws_iam_policy_document.s3_bucket_policy.json
}

# Add certificate 
module "acm" {
  source  = "terraform-aws-modules/acm/aws"
  version = "~> 4.0"

  domain_name  = "fayssal.online"
  zone_id      = "Z037850328PVOZFY73SL6"

  subject_alternative_names = [
    "*.fayssal.online",  ]

  wait_for_validation = true

}

# Add Route53 record
resource "aws_route53_record" "cloudfront_alias" {
  zone_id = "Z037850328PVOZFY73SL6"
  name    = "resumee.fayssal.online"
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.my_distrib.domain_name
    zone_id                = aws_cloudfront_distribution.my_distrib.hosted_zone_id
    evaluate_target_health = false
  }
}



