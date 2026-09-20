"""Processes order messages from SQS: stores them in DynamoDB and writes a receipt to S3."""
import json
import os

import boto3

_endpoint = os.getenv("AWS_ENDPOINT_URL")  # set automatically inside LocalStack
dynamodb = boto3.resource("dynamodb", endpoint_url=_endpoint)
s3 = boto3.client("s3", endpoint_url=_endpoint)
sns = boto3.client("sns", endpoint_url=_endpoint)

TABLE = os.environ["TABLE_NAME"]
BUCKET = os.environ["BUCKET_NAME"]
TOPIC_ARN = os.environ["TOPIC_ARN"]


def handler(event, _context):
    table = dynamodb.Table(TABLE)
    processed = 0
    for record in event.get("Records", []):
        order = json.loads(record["body"])
        order_id = str(order["order_id"])
        table.put_item(Item={"order_id": order_id, "item": order.get("item", ""), "status": "PROCESSED"})
        s3.put_object(
            Bucket=BUCKET,
            Key=f"receipts/{order_id}.json",
            Body=json.dumps({"order_id": order_id, "status": "PROCESSED"}),
            ContentType="application/json",
        )
        sns.publish(
            TopicArn=TOPIC_ARN,
            Message=json.dumps({"order_id": order_id, "status": "PROCESSED"}),
        )
        processed += 1
    return {"processed": processed}
