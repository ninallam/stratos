from flask import Flask, render_template, request, jsonify, flash, redirect, url_for
import os
import csv
import io
import json
import requests
from datetime import datetime
import pandas as pd
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

app = Flask(__name__)
app.secret_key = os.environ.get('SECRET_KEY', 'dev-secret-key-change-in-production')

# Configuration
KUSTO_CLUSTER = os.environ.get('KUSTO_CLUSTER')
KUSTO_DATABASE = os.environ.get('KUSTO_DATABASE', 'SubscriptionDB')
LOGIC_APP_URL = os.environ.get('LOGIC_APP_URL')
DEMO_MODE = os.environ.get('DEMO_MODE', 'false').lower() == 'true'

class SubscriptionEmailService:
    def __init__(self):
        self.kusto_client = None
        self.credential = None
        if not DEMO_MODE:
            self._initialize_kusto_client()
    
    def _initialize_kusto_client(self):
        """Initialize Kusto client with default Azure credentials"""
        try:
            # Only import Azure modules if not in demo mode
            from azure.kusto.data import KustoClient, KustoConnectionStringBuilder
            from azure.identity import DefaultAzureCredential
            from azure.core.exceptions import AzureError
            
            if not KUSTO_CLUSTER:
                raise ValueError("KUSTO_CLUSTER environment variable not set")
            
            self.credential = DefaultAzureCredential()
            kcsb = KustoConnectionStringBuilder.with_aad_application_key_authentication(
                KUSTO_CLUSTER, "", "", ""  # Using default credentials
            )
            kcsb = KustoConnectionStringBuilder.with_aad_device_authentication(KUSTO_CLUSTER)
            self.kusto_client = KustoClient(kcsb)
        except Exception as e:
            print(f"Failed to initialize Kusto client: {str(e)}")
    
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
            
            # Example Kusto query - adjust based on your actual table schema
            query = f"""
            SubscriptionAccountTeams
            | where SubscriptionId in ('{subscription_ids_str}')
            | project SubscriptionId, AccountTeamEmail, AccountTeamName
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
    
    def send_email_via_logic_app(self, email_data):
        """Send email using Azure Logic Apps"""
        # Demo mode - just log the email
        if DEMO_MODE:
            print(f"[DEMO MODE] Would send email:")
            print(f"To: {email_data['to']}")
            print(f"Subject: {email_data['subject']}")
            print(f"Body: {email_data['body'][:100]}...")
            return {"success": True, "message": "Email sent successfully (demo mode)"}
        
        if not LOGIC_APP_URL:
            return {"error": "LOGIC_APP_URL not configured"}
        
        try:
            headers = {
                'Content-Type': 'application/json'
            }
            
            response = requests.post(LOGIC_APP_URL, json=email_data, headers=headers)
            response.raise_for_status()
            
            return {"success": True, "message": "Email sent successfully"}
            
        except requests.RequestException as e:
            return {"error": f"Failed to send email: {str(e)}"}

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
    """Send email to account teams"""
    try:
        data = request.get_json()
        
        if not data or not data.get('email_content') or not data.get('recipients'):
            return jsonify({"error": "Missing email content or recipients"})
        
        email_data = {
            "to": data['recipients'],
            "subject": data.get('subject', 'Azure Subscription Notification'),
            "body": data['email_content'],
            "from": data.get('from_email', ''),
            "timestamp": datetime.now().isoformat()
        }
        
        result = email_service.send_email_via_logic_app(email_data)
        return jsonify(result)
        
    except Exception as e:
        return jsonify({"error": f"Failed to send email: {str(e)}"})

@app.route('/health')
def health():
    """Health check endpoint"""
    return jsonify({
        "status": "healthy",
        "timestamp": datetime.now().isoformat(),
        "demo_mode": DEMO_MODE,
        "kusto_configured": KUSTO_CLUSTER is not None,
        "logic_app_configured": LOGIC_APP_URL is not None
    })

if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0', port=5000)