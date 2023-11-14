provider "aws" {
  region = var.aws_region
}

provider "archive" {}

data "archive_file" "hello_lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/lambda/hello_lambda.py"
  output_path = "${path.module}/lambda/hello_lambda.zip"
}

data "archive_file" "hello_lambda_destination_zip" {
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
      REGION = "${var.aws_region}",
    }
  }
  timeout = 20
  depends_on = [
    aws_iam_role_policy_attachment.iam_for_lambda_destination_invokefunction,
    aws_iam_role_policy_attachment.lambda_logs,
    aws_cloudwatch_log_group.aws_cloudwatch_log,
  ]
}

resource "aws_iam_role_policy_attachment" "iam_for_lambda_destination_invokefunction" {
  role       = aws_iam_role.iam_for_lambda_destination.name
  policy_arn = aws_iam_policy.lambda_policy.arn
}

resource "aws_lambda_function" "hello_lambda_destination" {
  function_name    = "hello_lambda_destination"
  filename         = data.archive_file.hello_lambda_destination_zip.output_path
  source_code_hash = data.archive_file.hello_lambda_destination_zip.output_base64sha256

  role    = aws_iam_role.iam_for_lambda_destination.arn
  handler = "destination_lambda.lambda_handler"
  runtime = "python3.9"

  environment {
    variables = {
      REGION = "${var.aws_region}",
    }
  }
  timeout = 20
  depends_on = [
    aws_iam_role_policy_attachment.lambda_logs,
    aws_cloudwatch_log_group.aws_cloudwatch_log,
  ]
}

resource "aws_lambda_function_event_invoke_config" "hello_lambda_invoke" {
  function_name = aws_lambda_function.hello_lambda.function_name

  destination_config {
    on_success {
      destination = aws_lambda_function.hello_lambda_destination.arn
    }
    on_failure {
      destination = aws_sns_topic.hello_sns_on_failure.arn
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

resource "aws_cloudwatch_log_group" "aws_cloudwatch_log" {
  name              = "/aws/lambda/hello_lambda"
  retention_in_days = 14
}

