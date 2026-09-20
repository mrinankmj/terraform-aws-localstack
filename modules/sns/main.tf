variable "name" { type = string }

resource "aws_sns_topic" "this" {
  name = var.name
}

output "arn" { value = aws_sns_topic.this.arn }
output "name" { value = aws_sns_topic.this.name }
