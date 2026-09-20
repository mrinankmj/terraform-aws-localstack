output "queue_url" { value = module.orders_queue.url }
output "table_name" { value = module.orders_table.name }
output "bucket_name" { value = module.receipts_bucket.name }
output "lambda_name" { value = module.processor.name }
