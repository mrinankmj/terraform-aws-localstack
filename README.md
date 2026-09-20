# terraform-aws-localstack

An event-driven AWS order pipeline built with **modular Terraform**, tested end to end against **LocalStack** (an AWS emulator), so it runs without an AWS account or any cost.

## Architecture

```
SQS: orders ──► Lambda: order-processor ──► DynamoDB: orders
     │                                  └─► S3: receipts/<id>.json
     └─► DLQ (after 3 failed attempts)
```

## Highlights
- **Reusable modules**: `s3`, `sqs`, `dynamodb`, `lambda`.
- **Least-privilege IAM** for the Lambda (only the exact actions and resources it needs).
- **Secure defaults**: S3 encryption, versioning and public-access block; DynamoDB point-in-time recovery; SQS dead-letter queue.
- **Default tags** on every resource for cost tracking.
- **CI runs the real thing**: GitHub Actions starts LocalStack, applies Terraform, sends a test order, verifies the result, then destroys.
- **Real-AWS ready**: remove the `endpoints` block in `providers.tf` to deploy to AWS.

## Run it
Prereqs: Docker, Terraform, AWS CLI.

```bash
docker compose up -d
terraform init && terraform apply -auto-approve
./scripts-e2e.sh
terraform destroy -auto-approve && docker compose down
```
