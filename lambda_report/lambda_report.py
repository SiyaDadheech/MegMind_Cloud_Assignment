import boto3
import os
from datetime import datetime

s3 = boto3.client('s3')
ses = boto3.client('ses')

def lambda_handler(event, context):
    bucket = os.environ['PROCESSED_BUCKET']
    report_bucket = os.environ['REPORT_BUCKET']
    sender = os.environ['SES_EMAIL']
    recipient = sender
    
    response = s3.list_objects_v2(Bucket=bucket)
    file_count = response['KeyCount'] if 'KeyCount' in response else 0
    
    report_content = f"Report Date: {datetime.utcnow().strftime('%Y-%m-%d')}\nProcessed files count: {file_count}"
    report_key = f"daily_report_{datetime.utcnow().strftime('%Y-%m-%d')}.txt"
    
    # Upload report
    s3.put_object(Bucket=report_bucket, Key=report_key, Body=report_content)
    
    # Send email
    ses.send_email(
        Source=sender,
        Destination={'ToAddresses': [recipient]},
        Message={
            'Subject': {'Data': 'Daily Data Processing Report'},
            'Body': {'Text': {'Data': report_content}}
        }
    )
    
    return {
        'statusCode': 200,
        'body': 'Report generated and email sent.'
    }
