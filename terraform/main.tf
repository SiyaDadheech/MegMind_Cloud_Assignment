provider "aws" {
  region = "ap-south-1"
}

# Raw Data Bucket
resource "aws_s3_bucket" "raw_bucket" {
  bucket = "megamind-raw-bucket-unique12345"
  force_destroy = true
}

# Processed Data Bucket
resource "aws_s3_bucket" "processed_bucket" {
  bucket = "megamind-processed-bucket-unique12345"
  force_destroy = true
}

# IAM Role for Lambda
resource "aws_iam_role" "lambda_role" {
  name = "lambda_execution_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action    = "sts:AssumeRole",
      Effect    = "Allow",
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_s3" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Lambda Function - Initial Data Processor
resource "aws_lambda_function" "initial_processor" {
  function_name = "initial_data_processor"
  runtime       = "python3.11"
  handler       = "lambda_initial.lambda_handler"
  role          = aws_iam_role.lambda_role.arn
  filename      = "../lambda_initial.zip"

  environment {
    variables = {
      PROCESSED_BUCKET = aws_s3_bucket.processed_bucket.bucket
    }
  }
}

# Lambda Function - Report Generator
resource "aws_lambda_function" "report_generator" {
  function_name = "daily_report_generator"
  runtime       = "python3.11"
  handler       = "lambda_report.lambda_handler"
  role          = aws_iam_role.lambda_role.arn
  filename      = "../lambda_report.zip"

  environment {
    variables = {
      PROCESSED_BUCKET = aws_s3_bucket.processed_bucket.bucket
      REPORT_BUCKET    = aws_s3_bucket.processed_bucket.bucket
      SES_EMAIL        = "siyadadheech175@gmail.com"
    }
  }
}

# S3 Notification to Lambda
resource "aws_lambda_permission" "allow_s3_initial" {
  statement_id  = "AllowS3InvokeInitial"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.initial_processor.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.raw_bucket.arn
}

resource "aws_s3_bucket_notification" "raw_bucket_notification" {
  bucket = aws_s3_bucket.raw_bucket.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.initial_processor.arn
    events              = ["s3:ObjectCreated:*"]
  }

  depends_on = [aws_lambda_permission.allow_s3_initial]
}

# EventBridge Rule for daily report
resource "aws_cloudwatch_event_rule" "daily_trigger" {
  name                = "daily-report-trigger"
  schedule_expression = "cron(0 0 * * ? *)"
}

resource "aws_cloudwatch_event_target" "invoke_report_lambda" {
  rule      = aws_cloudwatch_event_rule.daily_trigger.name
  target_id = "daily-report-lambda"
  arn       = aws_lambda_function.report_generator.arn
}

resource "aws_lambda_permission" "allow_eventbridge_report" {
  statement_id  = "AllowEventBridgeInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.report_generator.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.daily_trigger.arn
}
