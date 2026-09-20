variable "region" {
  type    = string
  default = "ap-south-1"
}

variable "env" {
  type    = string
  default = "dev"
}

variable "localstack_endpoint" {
  type    = string
  default = "http://localhost:4566"
}
