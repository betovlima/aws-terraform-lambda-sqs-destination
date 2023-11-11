data "aws_iam_policy_document" "hello_lambda_policy" {
  statement {
    sid    = ""
    effect = "Allow"

    principals {
      identifiers = ["lambda.amazonaws.com"]
      type        = "Service"
    }

    actions = ["sts:AssumeRole"]
  }
}

 
resource "aws_iam_role" "iam_for_lambda" {
  name               = "iam_for_lambda"
  assume_role_policy = data.aws_iam_policy_document.hello_lambda_policy.json
}

resource "aws_sns_topic_policy" "default" {
  arn = aws_sns_topic.hello_sns.arn

  policy = data.aws_iam_policy_document.sns_topic_policy.json
}

data "aws_iam_policy_document" "sns_topic_policy" {
  policy_id = "__default_policy_ID"

  statement {
    actions = [
      "SNS:Subscribe",
      "SNS:SetTopicAttributes",
      "SNS:RemovePermission",
      "SNS:Receive",
      "SNS:Publish",
      "SNS:ListSubscriptionsByTopic",
      "SNS:GetTopicAttributes",
      "SNS:DeleteTopic",
      "SNS:AddPermission",
    ]


    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = ["*"]
    }

    resources = [
      aws_sns_topic.hello_sns.arn,
    ]

    sid = "__default_statement_ID"
  }
}

resource "aws_iam_policy" "lambda_policy" {
  name        = "${var.env_name}_lambda_policy"
  description = "${var.env_name}_lambda_policy"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "lambda:InvokeFunction"
      ],
      "Effect": "Allow",
      "Resource": [
        "arn:aws:s3:::${var.env_name_destination}"
      ]
    },
    {
      "Action": [
        "s3:ListBucket",
        "s3:GetObject",
        "s3:CopyObject",
        "s3:HeadObject"
      ],
      "Effect": "Allow",
      "Resource": [
        "arn:aws:s3:::${var.env_bucket_name}-src-bucket/*"
      ]
    },
    {
      "Action": [
        "s3:ListBucket",
        "s3:PutObject",
        "s3:PutObjectAcl",
        "s3:GetObject",
        "s3:CopyObject",
        "s3:HeadObject"
      ],
      "Effect": "Allow",
      "Resource": [
        "arn:aws:s3:::${var.env_bucket_name}-dst-bucket/*"
      ]
    },
    {
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Effect": "Allow",
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_iam_role" "hello_lambda_iam_role" {
  name               = "app_${var.env_name}_lambda"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow"
    }
  ]
}
EOF
}

resource "aws_iam_role" "hello_lambda_destination_iam_role" {
  name               = "app_${var.env_name_destination}_lambda"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "hello_lambda_iam_policy_basic_execution" {
  role       = aws_iam_role.hello_lambda_iam_role.id
  policy_arn = aws_iam_policy.lambda_policy.arn
}

resource "aws_lambda_permission" "allow_terraform_bucket" {
  statement_id  = "AllowExecutionFromS3Bucket"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.hello_lambda.arn
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.source_bucket.arn
}

#resource "aws_lambda_permission" "allow_hello_lambda_to_invoke_destination" {
#  function_name = aws_lambda_function.hello_lambda.arn # The function that needs permission to invoke
#  action        = "lambda:InvokeFunction"              # The action to grant permission for
#  principal     = "s3.amazonaws.com"
#  source_arn    = aws_lambda_function.hello_lambda_destination.arn # The ARN of the function to invoke
#}

resource "aws_iam_policy" "lambda_logging" {
  name        = "hello_lambda_logging"
  path        = "/"
  description = "IAM policy for logging from a lambda"
  policy      = data.aws_iam_policy_document.lambda_logging.json
}

resource "aws_iam_policy" "lambda_invoke_policy" {
  name        = "lambda-invoke-policy"
  description = "Policy to allow invoking any Lambda function"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "lambda:InvokeFunction",
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "lambda_destination_invoke_attachment" {
  role       = aws_iam_role.hello_lambda_destination_iam_role.id
  policy_arn = aws_iam_policy.lambda_policy.arn
}

resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.iam_for_lambda.name
  policy_arn = aws_iam_policy.lambda_logging.arn
}

data "aws_iam_policy_document" "lambda_logging" {
  statement {
    effect = "Allow"

    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]

    resources = ["arn:aws:logs:*:*:*"]
  }
}