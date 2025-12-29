import json
import os
import boto3
from botocore.exceptions import ClientError

# Initialize DynamoDB client
dynamodb = boto3.resource('dynamodb')
table_name = os.environ.get('USER_TENANT_MAPPING_TABLE')
table = dynamodb.Table(table_name)

def lambda_handler(event, context):
    """
    Lambda handler for getting user-tenant mapping information.
    
    Expected API endpoint: GET /user/tenant?user_id={user_id}
    
    Query Parameters:
        user_id: The user identifier (Cognito username or email)
    
    Returns:
        200: User-tenant mapping found
        400: Missing user_id parameter
        404: User mapping not found
        500: Internal server error
    """
    
    # CORS headers
    cors_headers = {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'Content-Type,X-Tenant-Id,Authorization',
        'Access-Control-Allow-Methods': 'GET,OPTIONS'
    }
    
    try:
        # Extract user_id from query parameters
        user_id = None
        
        # Check query string parameters
        if event.get('queryStringParameters'):
            user_id = event['queryStringParameters'].get('user_id')
        
        # Check headers as fallback
        if not user_id and event.get('headers'):
            user_id = event['headers'].get('user_id') or event['headers'].get('User-Id')
        
        # Validate user_id is provided
        if not user_id:
            return {
                'statusCode': 400,
                'headers': cors_headers,
                'body': json.dumps({
                    'error': 'Missing required parameter: user_id',
                    'message': 'Please provide user_id as a query parameter or header'
                })
            }
        
        # Query DynamoDB for user-tenant mapping
        response = table.get_item(
            Key={
                'user_id': user_id
            }
        )
        
        # Check if item exists
        if 'Item' not in response:
            return {
                'statusCode': 404,
                'headers': cors_headers,
                'body': json.dumps({
                    'error': 'User mapping not found',
                    'message': f'No tenant mapping found for user_id: {user_id}'
                })
            }
        
        # Return the user-tenant mapping
        item = response['Item']
        
        return {
            'statusCode': 200,
            'headers': cors_headers,
            'body': json.dumps({
                'user_id': item.get('user_id'),
                'tenant_id': item.get('tenant_id'),
                'role': item.get('role'),
                'email': item.get('email'),
                'created_at': item.get('created_at')
            })
        }
        
    except ClientError as e:
        # DynamoDB client error
        print(f"DynamoDB error: {str(e)}")
        return {
            'statusCode': 500,
            'headers': cors_headers,
            'body': json.dumps({
                'error': 'Internal server error',
                'message': 'Failed to retrieve user mapping from database'
            })
        }
        
    except Exception as e:
        # Generic error handler
        print(f"Unexpected error: {str(e)}")
        return {
            'statusCode': 500,
            'headers': cors_headers,
            'body': json.dumps({
                'error': 'Internal server error',
                'message': 'An unexpected error occurred'
            })
        }
