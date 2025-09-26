#!/usr/bin/env python3
"""
Demo data and mock service for testing Stratos application
This script provides mock data when Azure services are not available
"""

import json
from datetime import datetime

# Mock subscription data for demonstration
MOCK_SUBSCRIPTION_DATA = {
    "12345678-1234-1234-1234-123456789012": [
        {
            "email": "team1@company.com",
            "name": "Account Team Alpha"
        },
        {
            "email": "manager1@company.com", 
            "name": "Account Manager John Doe"
        }
    ],
    "87654321-4321-4321-4321-210987654321": [
        {
            "email": "team2@company.com",
            "name": "Account Team Beta"
        }
    ],
    "11111111-2222-3333-4444-555566667777": [
        {
            "email": "team3@company.com",
            "name": "Account Team Gamma"
        },
        {
            "email": "support@company.com",
            "name": "Support Team"
        }
    ]
}

def get_mock_account_teams(subscription_ids):
    """Return mock account team data for testing"""
    if isinstance(subscription_ids, str):
        subscription_ids = [subscription_ids]
    
    result = {}
    for sub_id in subscription_ids:
        if sub_id in MOCK_SUBSCRIPTION_DATA:
            result[sub_id] = MOCK_SUBSCRIPTION_DATA[sub_id]
        else:
            # Return generic team for unknown subscription IDs
            result[sub_id] = [
                {
                    "email": f"account-team-{sub_id[:8]}@company.com",
                    "name": f"Account Team for {sub_id[:8]}"
                }
            ]
    
    return result

def create_sample_csv():
    """Create a sample CSV file for testing"""
    csv_content = """SubscriptionId
12345678-1234-1234-1234-123456789012
87654321-4321-4321-4321-210987654321
11111111-2222-3333-4444-555566667777"""
    
    with open('sample_subscriptions.csv', 'w') as f:
        f.write(csv_content)
    
    print("Created sample_subscriptions.csv with demo data")

if __name__ == "__main__":
    create_sample_csv()
    
    # Test mock data
    test_ids = ["12345678-1234-1234-1234-123456789012", "unknown-subscription"]
    result = get_mock_account_teams(test_ids)
    print(json.dumps(result, indent=2))