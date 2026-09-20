variable "name" { type = string }
variable "source_dir" { type = string }
variable "handler" { type = string }
variable "queue_arn" { type = string }

variable "environment" {
  type    = map(string)
  default = {}
}

variable "policy_arns" {
  type    = list(string)
  default = []
}

data "archive_file" "zip" {
  type        = "zip"
  source_dir  = var.source_dir
  output_path = "${path.root}/.build/${var.name}.zip"
}

resource "aws_iam_role" "this" {
  name = "${var.name}-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "extra" {
  for_each   = toset(var.policy_arns)
  role       = aws_iam_role.this.name
  policy_arn = each.value
}

resource "aws_lambda_function" "this" {
  function_name    = var.name
  role             = aws_iam_role.this.arn
  runtime          = "python3.12"
  handler          = var.handler
  filename         = data.archive_file.zip.output_path
  source_code_hash = data.archive_file.zip.output_base64sha256
  timeout          = 30

  environment {
    variables = var.environment
  }
}

resource "aws_lambda_event_source_mapping" "sqs" {
  event_source_arn = var.queue_arn
  function_name    = aws_lambda_function.this.arn
  batch_size       = 10
}

output "name" { value = aws_lambda_function.this.function_name }
output "role_name" { value = aws_iam_role.this.name }
