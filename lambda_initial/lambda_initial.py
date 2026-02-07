import boto3
import os

s3 = boto3.client('s3')

def lambda_handler(event, context):
    source_bucket = event['Records'][0]['s3']['bucket']['name']
    object_key = event['Records'][0]['s3']['object']['key']
    target_bucket = os.environ['PROCESSED_BUCKET']
    
    copy_source = {'Bucket': source_bucket, 'Key': object_key}
    s3.copy_object(Bucket=target_bucket, CopySource=copy_source, Key=object_key)
    
    return {
        'statusCode': 200,
        'body': f"File {object_key} copied to {target_bucket}"
    }
