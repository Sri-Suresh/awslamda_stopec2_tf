provider "aws" {
  region = "us-east-1"
}

data "aws_iam_policy_document" "sri_policy_doc" {
  statement {
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
    resources = [
      "*",
    ]
  }
  statement {
    effect = "Allow"
    actions = [
      "ec2:*",
    ]
    resources = [
      "*",
    ]
  }
}

resource "aws_iam_policy" "sri_policy" {
  name   = "sri_policy"
  path   = "/"
  policy = data.aws_iam_policy_document.sri_policy_doc.json
}

resource "aws_iam_role_policy_attachment" "sri_policy" {
  role       = aws_iam_role.sri_lambda_role.name
  policy_arn = aws_iam_policy.sri_policy.arn
}

resource "aws_iam_role" "sri_lambda_role" {
  name = "sri_lambda_role"
  path = "/"

  assume_role_policy = <<EOF
{
        "Version": "2012-10-17",
        "Statement": [
        {
        "Action": "sts:AssumeRole",
        "Principal": {
                "Service": "lambda.amazonaws.com"
        },
        "Effect": "Allow",
        "Sid": ""
        }
        ]
        }

EOF

}

resource "aws_cloudwatch_event_rule" "sri-tf-lambda-event" {
  name                = "sri-tf-lambda-event"
  description         = "created by terraform"
  schedule_expression = "cron(45 17 ? * * *)"
}

resource "aws_cloudwatch_event_target" "sri-tfcheck-file-event-lambda-target" {
  target_id = "sri-tfcheck-file-event-lambda-target"
  rule      = aws_cloudwatch_event_rule.sri-tf-lambda-event.name
  arn       = aws_lambda_function.sritf_lambda_function.arn
}

resource "aws_lambda_function" "sritf_lambda_function" {
  filename         = "sritf_lambda_function.zip"
  function_name    = "sritf_lambda_function"
  role             = aws_iam_role.sri_lambda_role.arn
  handler          = "sritf_lambda_function.lambda_handler"
  runtime          = "python2.7"
  timeout          = 10
  source_code_hash = filebase64sha256("sritf_lambda_function.zip")
}

resource "aws_lambda_permission" "sritf_cloudwatch" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.sritf_lambda_function.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.sri-tf-lambda-event.arn
}

