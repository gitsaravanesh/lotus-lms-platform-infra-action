import json
import os
import boto3
from datetime import datetime
from botocore.exceptions import ClientError

def lambda_handler(event, context):
    """
    Lambda handler for Cognito Post Confirmation trigger.
    
    This function is automatically invoked after a user confirms their signup.
    It creates user records in the DynamoDB tables:
    - lotus-lms-users: Stores user profile information
    - lms-user-tenant-mapping: Maps users to their tenant and role
    
    Args:
        event: Cognito Post Confirmation event containing user attributes
        context: Lambda context object
    
    Returns:
        event: The event object (required for Post Confirmation triggers)
    """
    
    print(f"Received event: {json.dumps(event)}")
    
    try:
        # Initialize DynamoDB client
        dynamodb = boto3.resource('dynamodb')
        
        # Get table names from environment variables
        users_table_name = os.environ.get('USERS_TABLE')
        user_tenant_mapping_table_name = os.environ.get('USER_TENANT_MAPPING_TABLE')
        
        if not users_table_name or not user_tenant_mapping_table_name:
            print("ERROR: Required environment variables not set")
            raise Exception("Database configuration error")
        
        users_table = dynamodb.Table(users_table_name)
        user_tenant_mapping_table = dynamodb.Table(user_tenant_mapping_table_name)
        
        # Extract user information from Cognito event
        user_attributes = event['request']['userAttributes']
        user_id = user_attributes.get('sub')  # Cognito username (unique identifier)
        email = user_attributes.get('email')
        username = user_attributes.get('custom:username', email)  # Use custom username or fall back to email
        full_name = user_attributes.get('name', '')
        
        # Create timestamp
        created_at = datetime.utcnow().isoformat()
        
        # Insert record into lotus-lms-users table
        users_table.put_item(
            Item={
                'user_id': user_id,
                'email': email,
                'username': username,
                'full_name': full_name,
                'created_at': created_at,
                'status': 'active'
            }
        )
        print(f"Successfully created user record for user_id: {user_id}")
        
        # Insert record into lms-user-tenant-mapping table
        user_tenant_mapping_table.put_item(
            Item={
                'user_id': user_id,
                'tenant_id': 'trainer1',  # Default tenant
                'role': 'student',  # Default role
                'email': email,
                'created_at': created_at
            }
        )
        print(f"Successfully created user-tenant mapping for user_id: {user_id}")
        
        # IMPORTANT: Return the event object unchanged for Post Confirmation triggers
        return event
        
    except ClientError as e:
        # DynamoDB client error
        print(f"DynamoDB error: {str(e)}")
        print(f"Error details: {e.response['Error']}")
        raise Exception(f"Failed to create user records: {str(e)}")
        
    except Exception as e:
        # Generic error handler
        print(f"Unexpected error: {str(e)}")
        raise Exception(f"An unexpected error occurred: {str(e)}")
