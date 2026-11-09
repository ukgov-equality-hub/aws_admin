
variable "service_name" {
  type = string
  description = "The short name of the service."
  default = "aws_admin__tag_ips"
}

variable "service_name_hyphens" {
  type = string
  description = "The short name of the service (using hyphen-style)."
  default = "aws-admin--tag-ips"
}

variable "github_url" {
  type = string
  description = "The URL to the GitHub repo (we add this as a Tag to all resources)"
}

variable "aws_region" {
  type = string
  description = "The AWS region used for the provider and resources."
  default = "eu-west-2"
}


variable "NOTIFICATION_EMAIL" {
  description = "Email address to receive daily success/failure notifications"
  type        = string
}
