#!/usr/bin/env bash
# End-to-end check: send an order to SQS, then verify it lands in DynamoDB and S3.
set -euo pipefail
export AWS_ACCESS_KEY_ID=test AWS_SECRET_ACCESS_KEY=test AWS_DEFAULT_REGION=ap-south-1
EP=http://localhost:4566

QUEUE_URL=$(terraform output -raw queue_url)
TABLE=$(terraform output -raw table_name)
BUCKET=$(terraform output -raw bucket_name)
NOTIFICATIONS_QUEUE_URL=$(terraform output -raw notifications_queue_url)

aws --endpoint-url $EP sqs send-message --queue-url "$QUEUE_URL" \
  --message-body '{"order_id":"1001","item":"kashmiri-shawl"}' > /dev/null
echo "Order sent. Waiting for Lambda..."

for _ in $(seq 1 30); do
  if aws --endpoint-url $EP dynamodb get-item --table-name "$TABLE" \
       --key '{"order_id":{"S":"1001"}}' --query Item.status.S --output text 2>/dev/null | grep -q PROCESSED; then
    aws --endpoint-url $EP s3 ls "s3://$BUCKET/receipts/1001.json" > /dev/null
    echo "✅ Order processed: stored in DynamoDB and receipt in S3"

    echo "Checking for the SNS notification (via its SQS fan-out subscriber)..."
    for _ in $(seq 1 10); do
      if aws --endpoint-url $EP sqs receive-message --queue-url "$NOTIFICATIONS_QUEUE_URL" \
           --query 'Messages[0].Body' --output text 2>/dev/null | grep -q PROCESSED; then
        echo "✅ Notification received"
        exit 0
      fi
      sleep 2
    done
    echo "❌ Order was processed but no SNS notification arrived in time"; exit 1
  fi
  sleep 3
done
echo "❌ Order was not processed in time"; exit 1
