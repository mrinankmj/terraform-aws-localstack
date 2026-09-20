variable "name" { type = string }

variable "max_receive_count" {
  type    = number
  default = 3
}

resource "aws_sqs_queue" "dlq" {
  name                      = "${var.name}-dlq"
  message_retention_seconds = 1209600
}

resource "aws_sqs_queue" "this" {
  name                       = var.name
  visibility_timeout_seconds = 60
  redrive_policy             = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dlq.arn
    maxReceiveCount     = var.max_receive_count
  })
}

output "arn" { value = aws_sqs_queue.this.arn }
output "url" { value = aws_sqs_queue.this.url }
output "dlq_arn" { value = aws_sqs_queue.dlq.arn }
