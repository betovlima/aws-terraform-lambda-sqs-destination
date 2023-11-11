# Specify the provider and access details
provider "aws" {
  region = var.aws_region
}

provider "archive" {}

data "archive_file" "hello_lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/lambda/hello_lambda.py"
  output_path = "${path.module}/lambda/hello_lambda.zip"
}

data "archive_file" "destination_zip" {
  type        = "zip"
  source_file = "${path.module}/destination/destination_lambda.py"
  output_path = "${path.module}/destination/destination_lambda.zip"
}

resource "aws_lambda_function" "hello_lambda" {
  function_name    = "hello_lambda"
  filename         = data.archive_file.hello_lambda_zip.output_path
  source_code_hash = data.archive_file.hello_lambda_zip.output_base64sha256

  role    = aws_iam_role.iam_for_lambda.arn
  handler = "hello_lambda.lambda_handler"
  runtime = "python3.9"

  environment {
    variables = {
      DST_BUCKET = "${var.env_name}-dst-bucket",
      REGION     = "${var.aws_region}",
    }
  }
  depends_on = [
    aws_iam_role_policy_attachment.lambda_logs,
    aws_cloudwatch_log_group.example,
  ]
}


resource "aws_sns_topic" "hello_sns" {
  name            = "hello-sns-topic"
  delivery_policy = <<EOF
{
  "http": {
    "defaultHealthyRetryPolicy": {
      "minDelayTarget": 20,
      "maxDelayTarget": 20,
      "numRetries": 3,
      "numMaxDelayRetries": 0,
      "numNoDelayRetries": 0,
      "numMinDelayRetries": 0,
      "backoffFunction": "linear"
    },
    "disableSubscriptionOverrides": false,
    "defaultThrottlePolicy": {
      "maxReceivesPerSecond": 1
    }
  }
}
EOF
}

resource "aws_lambda_function_event_invoke_config" "hello_lambda_invoke" {
  function_name = aws_lambda_function.hello_lambda.function_name

  destination_config {
    on_success {
      destination = aws_sns_topic.hello_sns.arn
    }
     
  }
}

resource "aws_s3_bucket" "source_bucket" {
  bucket        = var.env_bucket_name
  force_destroy = true
}

resource "aws_s3_bucket_notification" "bucket_terraform_notification" {
  bucket = aws_s3_bucket.source_bucket.id
  lambda_function {
    lambda_function_arn = aws_lambda_function.hello_lambda.arn
    events              = ["s3:ObjectCreated:*"]
  }

  depends_on = [aws_lambda_permission.allow_terraform_bucket]
}

resource "aws_cloudwatch_log_group" "example" {
  name              = "/aws/lambda/hello_lambda"
  retention_in_days = 14
}

