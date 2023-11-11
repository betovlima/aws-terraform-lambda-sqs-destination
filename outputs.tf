output "lambda" {
  value = "${aws_lambda_function.hello_lambda.qualified_arn}"
}
