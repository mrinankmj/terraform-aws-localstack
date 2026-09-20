output "queue_url" { value = module.orders_queue.url }
output "table_name" { value = module.orders_table.name }
output "bucket_name" { value = module.receipts_bucket.name }
output "lambda_name" { value = module.processor.name }
output "topic_arn" { value = module.order_events.arn }
output "notifications_queue_url" { value = aws_sqs_queue.notifications.url }
