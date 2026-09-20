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

module "order_events" {
  source = "./modules/sns"
  name   = "order-events-${var.env}"
}

# Fan-out subscriber used to verify (and, in production, act on) order-processed
# notifications published by the Lambda.
resource "aws_sqs_queue" "notifications" {
  name = "order-notifications-${var.env}"
}

resource "aws_sqs_queue_policy" "notifications" {
  queue_url = aws_sqs_queue.notifications.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "sns.amazonaws.com" }
      Action    = "sqs:SendMessage"
      Resource  = aws_sqs_queue.notifications.arn
      Condition = { ArnEquals = { "aws:SourceArn" = module.order_events.arn } }
    }]
  })
}

resource "aws_sns_topic_subscription" "notifications" {
  topic_arn = module.order_events.arn
  protocol  = "sqs"
  endpoint  = aws_sqs_queue.notifications.arn
}

module "processor" {
  source     = "./modules/lambda"
  name       = "order-processor-${var.env}"
  source_dir = "${path.root}/lambda_src"
  handler    = "handler.handler"
  queue_arn  = module.orders_queue.arn
  environment = {
    TABLE_NAME  = module.orders_table.name
    BUCKET_NAME = module.receipts_bucket.name
  }
  policy_arns = []
}

# Least-privilege permissions for the processor
resource "aws_iam_role_policy" "processor" {
  name = "order-processor-access"
  role = module.processor.role_name
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
