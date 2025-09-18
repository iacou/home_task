variable "name" {
  type    = string
  default = "luminor-task"
}
variable "aws_region" {
  type    = string
  default = "eu-north-1"
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "azs" {
  type    = list(string)
  default = ["eu-north-1a", "eu-north-1b"]
}

variable "public_subnets" {
  type    = list(string)
  default = ["10.0.0.0/20", "10.0.16.0/20"]
}

variable "k8s_version" {
  type    = string
  default = "1.33"
}

variable "node_instance_type" {
  type    = string
  default = "t3.medium"
}

variable "atlantis_chart_version" {
  type    = string
  default = "5.18.1"
}

variable "github_owner" {
  type = string
  default = "placeholder"
}

variable "github_repo" {
  type = string
  default = "placeholder"
}

variable "github_user" {
  type = string
  default = "placeholder"
}

variable "github_token" {
  type      = string
  sensitive = true
  default = "placeholder"
}

variable "github_webhook_secret" {
  type      = string
  sensitive = true
  default = "placeholder"
}
