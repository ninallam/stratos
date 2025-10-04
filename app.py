from flask import Flask, render_template, request, jsonify, flash, redirect, url_for
import os
import csv
import io
import json
import requests
from datetime import datetime
import pandas as pd
from dotenv import load_dotenv
import asyncio

# Load environment variables
load_dotenv()

app = Flask(__name__)
app.secret_key = os.environ.get('SECRET_KEY', 'dev-secret-key-change-in-production')

# Configuration
KUSTO_CLUSTER = os.environ.get('KUSTO_CLUSTER')
KUSTO_DATABASE = os.environ.get('KUSTO_DATABASE', 'SubscriptionDB')
DEMO_MODE = os.environ.get('DEMO_MODE', 'false').lower() == 'true'

# Microsoft Graph API configuration
GRAPH_API_ENDPOINT = "https://graph.microsoft.com/v1.0"

class SubscriptionEmailService:
    def __init__(self):
        self.kusto_client = None
        self.credential = None
        if not DEMO_MODE:
            self._initialize_kusto_client()
    
    def _initialize_kusto_client(self):
        """Initialize Kusto client with Managed Identity authentication"""
        try:
            # Only import Azure modules if not in demo mode
            from azure.kusto.data import KustoClient, KustoConnectionStringBuilder
            from azure.identity import ManagedIdentityCredential, DefaultAzureCredential
            from azure.core.exceptions import AzureError
            
            if not KUSTO_CLUSTER:
                raise ValueError("KUSTO_CLUSTER environment variable not set")
            
            # Try Managed Identity first, fallback to DefaultAzureCredential for local development
            try:
                # Use Managed Identity for production Azure deployments
                self.credential = ManagedIdentityCredential()
                auth_method = "Managed Identity"
            except Exception:
                # Fallback to DefaultAzureCredential for local development
                self.credential = DefaultAzureCredential()
                auth_method = "Default Azure Credential"
            
            # Create connection string builder with the selected credential
            kcsb = KustoConnectionStringBuilder.with_aad_token_provider(
                KUSTO_CLUSTER, 
                lambda: self.credential.get_token('https://kusto.kusto.windows.net/.default').token
            )
            
            self.kusto_client = KustoClient(kcsb)
            print(f"Successfully initialized Kusto client using {auth_method} for cluster: {KUSTO_CLUSTER}")
            
        except Exception as e:
            print(f"Failed to initialize Kusto client: {str(e)}")
            self.kusto_client = None
    
    def get_account_team_emails(self, subscription_ids):
        """Fetch account team email addresses for given subscription IDs"""
        # Demo mode for testing without Azure services
        if DEMO_MODE:
            from demo_data import get_mock_account_teams
            return get_mock_account_teams(subscription_ids)
        
        if not self.kusto_client:
            return {"error": "Kusto client not initialized"}
        
        try:
            # Convert subscription_ids to comma-separated string for query
            if isinstance(subscription_ids, list):
                subscription_ids_str = "','".join(subscription_ids)
            else:
                subscription_ids_str = subscription_ids
            
            # Kusto query to get all account team emails for subscriptions
            # Removed 'distinct' to include all email addresses for each subscription
            # query = f"""
            # CustomerSearchFlattened
            # | where SubscriptionGuid in ('{subscription_ids_str}')
            # | project SubscriptionId = SubscriptionGuid , AccountTeamEmail = ContactUpn, AccountTeamName = ""
            # | distinct SubscriptionId, AccountTeamEmail, AccountTeamName
            # """
            

            query = f"""
            SampleAccount
            | where SubscriptionGuid in ('{subscription_ids_str}')
            | project SubscriptionId = SubscriptionGuid , AccountTeamEmail, AccountTeamName = ""
            | distinct SubscriptionId, AccountTeamEmail, AccountTeamName
            """
            response = self.kusto_client.execute(KUSTO_DATABASE, query)
            
            result = {}
            for row in response.primary_results[0]:
                subscription_id = row["SubscriptionId"]
                email = row["AccountTeamEmail"]
                name = row.get("AccountTeamName", "")
                
                if subscription_id not in result:
                    result[subscription_id] = []
                result[subscription_id].append({
                    "email": email,
                    "name": name
                })
            
            return result
            
        except Exception as e:
            return {"error": f"Failed to query Kusto: {str(e)}"}
    
    def send_email_via_graph_api(self, email_data):
        """Send email using Microsoft Graph API from user's own email"""
        # Demo mode - just log the email
        if DEMO_MODE:
            subscription_id = email_data.get('subscription_id', 'Unknown')
            from_user = email_data.get('from', 'Unknown')
            print(f"[DEMO MODE] Would send email for subscription {subscription_id}:")
            print(f"From: {from_user}")
            print(f"To: {email_data['to']}")
            print(f"Subject: {email_data['subject']}")
            print(f"Body: {email_data['body'][:100]}...")
            return {"success": True, "message": f"Email sent successfully (demo mode) from {from_user}"}
        
        if not self.credential:
            return {"error": "Azure credentials not initialized"}
        
        try:
            # Get access token for Microsoft Graph
            token = self.credential.get_token('https://graph.microsoft.com/.default')
            
            headers = {
                'Authorization': f'Bearer {token.token}',
                'Content-Type': 'application/json'
            }
            
            # Get sender email from the data
            from_email = email_data.get('from')
            if not from_email:
                return {"error": "Sender email address is required"}
            
            # Prepare Graph API email payload
            graph_email_data = {
                "message": {
                    "subject": email_data['subject'],
                    "body": {
                        "contentType": "HTML",
                        "content": email_data['body']
                    },
                    "toRecipients": [
                        {"emailAddress": {"address": recipient}} 
                        for recipient in email_data['to']
                    ]
                },
                "saveToSentItems": True
            }
            
            # Send email using Microsoft Graph API on behalf of the user
            graph_url = f"{GRAPH_API_ENDPOINT}/users/{from_email}/sendMail"
            
            response = requests.post(graph_url, json=graph_email_data, headers=headers)
            response.raise_for_status()
            
            return {"success": True, "message": f"Email sent successfully from {from_email}"}
            
        except requests.RequestException as e:
            return {"error": f"Failed to send email via Graph API: {str(e)}"}
        except Exception as e:
            return {"error": f"Graph API error: {str(e)}"}

# Initialize service
email_service = SubscriptionEmailService()

@app.route('/')
def index():
    """Main page with input form"""
    return render_template('index.html')

@app.route('/fetch_emails', methods=['POST'])
def fetch_emails():
    """Fetch account team emails for subscription IDs"""
    try:
        subscription_ids = []
        
        # Handle CSV file upload
        if 'csv_file' in request.files and request.files['csv_file'].filename:
            csv_file = request.files['csv_file']
            stream = io.StringIO(csv_file.stream.read().decode("UTF8"), newline=None)
            csv_reader = csv.reader(stream)
            
            # Skip header if present
            first_row = next(csv_reader, None)
            if first_row and not first_row[0].startswith('subscription'):
                subscription_ids.append(first_row[0])
            
            for row in csv_reader:
                if row and row[0].strip():
                    subscription_ids.append(row[0].strip())
        
        # Handle manual input
        elif request.form.get('subscription_ids'):
            manual_ids = request.form.get('subscription_ids').strip()
            subscription_ids = [id.strip() for id in manual_ids.split(',') if id.strip()]
        
        if not subscription_ids:
            return jsonify({"error": "No subscription IDs provided"})
        
        # Fetch account team emails
        result = email_service.get_account_team_emails(subscription_ids)
        
        if "error" in result:
            return jsonify(result)
        
        return jsonify({
            "success": True,
            "subscription_emails": result,
            "total_subscriptions": len(subscription_ids)
        })
        
    except Exception as e:
        return jsonify({"error": f"Processing failed: {str(e)}"})

@app.route('/send_email', methods=['POST'])
def send_email():
    """Send email to account teams - one email per subscription ID"""
    try:
        data = request.get_json()
        
        if not data or not data.get('email_content') or not data.get('subscription_emails'):
            return jsonify({"error": "Missing email content or subscription data"})
        
        subscription_emails = data['subscription_emails']
        base_subject = data.get('subject', 'Azure Subscription Notification')
        base_content = data.get('email_content', '')
        from_email = data.get('from_email', '')
        
        sent_count = 0
        failed_count = 0
        errors = []
        
        # Send one email per subscription ID
        for subscription_id, teams in subscription_emails.items():
            try:
                # Get all email addresses for this subscription
                recipients = [team['email'] for team in teams]
                
                if not recipients:
                    continue
                
                # Customize email content for this specific subscription
                customized_content = base_content.replace(
                    '{subscription_details}', 
                    f"Subscription ID: {subscription_id}"
                )
                customized_subject = f"{base_subject} - {subscription_id}"
                
                email_data = {
                    "to": recipients,
                    "subject": customized_subject,
                    "body": customized_content,
                    "from": from_email,
                    "timestamp": datetime.now().isoformat(),
                    "subscription_id": subscription_id
                }
                
                result = email_service.send_email_via_graph_api(email_data)
                
                if result.get("success"):
                    sent_count += 1
                else:
                    failed_count += 1
                    errors.append(f"Subscription {subscription_id}: {result.get('error', 'Unknown error')}")
                    
            except Exception as e:
                failed_count += 1
                errors.append(f"Subscription {subscription_id}: {str(e)}")
        
        # Return summary of email sending results
        if sent_count > 0 and failed_count == 0:
            return jsonify({
                "success": True, 
                "message": f"Successfully sent {sent_count} email(s) - one per subscription"
            })
        elif sent_count > 0 and failed_count > 0:
            return jsonify({
                "success": True,
                "message": f"Sent {sent_count} email(s), {failed_count} failed",
                "errors": errors
            })
        else:
            return jsonify({
                "error": f"Failed to send all {failed_count} email(s)",
                "errors": errors
            })
        
    except Exception as e:
        return jsonify({"error": f"Failed to send emails: {str(e)}"})

@app.route('/health')
def health():
    """Health check endpoint"""
    return jsonify({
        "status": "healthy",
        "timestamp": datetime.now().isoformat(),
        "demo_mode": DEMO_MODE,
        "kusto_configured": KUSTO_CLUSTER is not None,
        "graph_api_configured": True
    })

if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0', port=5000)