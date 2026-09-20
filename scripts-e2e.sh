#!/usr/bin/env bash
# End-to-end check: send an order to SQS, then verify it lands in DynamoDB and S3.
set -euo pipefail
export AWS_ACCESS_KEY_ID=test AWS_SECRET_ACCESS_KEY=test AWS_DEFAULT_REGION=ap-south-1
EP=http://localhost:4566

QUEUE_URL=$(terraform output -raw queue_url)
TABLE=$(terraform output -raw table_name)
BUCKET=$(terraform output -raw bucket_name)

aws --endpoint-url $EP sqs send-message --queue-url "$QUEUE_URL" \
  --message-body '{"order_id":"1001","item":"kashmiri-shawl"}' > /dev/null
echo "Order sent. Waiting for Lambda..."

for _ in $(seq 1 30); do
  if aws --endpoint-url $EP dynamodb get-item --table-name "$TABLE" \
       --key '{"order_id":{"S":"1001"}}' --query Item.status.S --output text 2>/dev/null | grep -q PROCESSED; then
    aws --endpoint-url $EP s3 ls "s3://$BUCKET/receipts/1001.json" > /dev/null
    echo "✅ Order processed: stored in DynamoDB and receipt in S3"
    exit 0
  fi
  sleep 3
done
echo "❌ Order was not processed in time"; exit 1
