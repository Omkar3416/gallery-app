# AWS Plan — Always-Free + Hard Guards

Goal: use multiple AWS features but guarantee no surprise costs *before and after* the 12-month Free Tier.

## Principles
- **Default OFF** in-app (see Settings). Local Isar DB is fully capable.
- When ON, stay inside **Always Free** quotas only:
  - Lambda: 1M requests/mo + 400k GB-s/mo (Always Free)
  - DynamoDB: 25 GB + free RCU/WCU thresholds (Always Free)
  - S3: *not* always free — use sparingly or skip.
- Hard local caps: the app blocks AWS calls after a monthly limit (default 0).
- Prefer **simulation** (LocalStack) for dev.

## Suggested Minimal Stack
- **Cognito**: unauthenticated identities (guest), or skip.
- **API Gateway + Lambda**: small helpers (e.g., tag normalization).
- **DynamoDB**: optional cloud index of tags (mirror of local Isar).
- **S3**: optional manual backup bucket (OFF by default).

## IaC Skeleton
Use Terraform or AWS CDK. Example layout:

infra/aws/terraform/
- main.tf             # provider + region
- lambda.tf           # a tiny function, reserved concurrency=1
- apigw.tf            # HTTP API with 1 route
- dynamodb.tf         # pay-per-request table (small)
- iam.tf              # least-privilege roles/policies
- budgets.md          # instructions to set AWS Budgets alerts (email/SNS)

> Note: Budgets raise alerts; they don't hard-stop spend. The **app’s local caps** are your hard guard.
