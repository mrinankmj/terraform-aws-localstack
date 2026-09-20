# Event-driven order pipeline:
#   SQS (orders) ──► Lambda (processor) ──► DynamoDB (orders table)
#                                       └─► S3 (receipts bucket)

module "receipts_bucket" {
  source = "./modules/s3"
  name   = "orders-receipts-${var.env}"
}

module "orders_queue" {
  source = "./modules/sqs"
  name   = "orders-${var.env}"
}

module "orders_table" {
  source   = "./modules/dynamodb"
  name     = "orders-${var.env}"
  hash_key = "order_id"
}

module "processor" {
  source      = "./modules/lambda"
  name        = "order-processor-${var.env}"
  source_dir  = "${path.root}/lambda_src"
  handler     = "handler.handler"
  queue_arn   = module.orders_queue.arn
  environment = {
    TABLE_NAME  = module.orders_table.name
    BUCKET_NAME = module.receipts_bucket.name
  }
  policy_arns = []
}

# Least-privilege permissions for the processor
resource "aws_iam_role_policy" "processor" {
  name   = "order-processor-access"
  role   = module.processor.role_name
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["sqs:ReceiveMessage", "sqs:DeleteMessage", "sqs:GetQueueAttributes"]
        Resource = module.orders_queue.arn
      },
      {
        Effect   = "Allow"
        Action   = ["dynamodb:PutItem"]
        Resource = module.orders_table.arn
      },
      {
        Effect   = "Allow"
        Action   = ["s3:PutObject"]
        Resource = "${module.receipts_bucket.arn}/receipts/*"
      },
      {
        Effect   = "Allow"
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "*"
      }
    ]
  })
}
