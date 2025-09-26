# Stratos - Azure Subscription Email Notifier

Stratos is a web application that enables sending emails to account teams of customers based on their Azure subscription IDs. It fetches account team details from a Kusto database and sends emails via Azure Logic Apps.

## Features

- **Multiple Input Methods**: Accept single subscription ID or CSV file with multiple subscription IDs
- **Kusto Integration**: Fetch account team email addresses from Azure Data Explorer (Kusto) database
- **Email Composition**: User-friendly interface to draft email content
- **Azure Logic Apps**: Send emails through Azure Logic Apps integration
- **Web Interface**: Simple and intuitive web interface built with Flask and Bootstrap

## Prerequisites

- Python 3.8 or higher
- Azure subscription with appropriate permissions
- Azure Data Explorer (Kusto) cluster access
- Azure Logic Apps workflow configured for email sending
- Default Azure credentials configured (Azure CLI, managed identity, or service principal)

## Installation

1. Clone the repository:
```bash
git clone https://github.com/ninallam/stratos.git
cd stratos
```

2. Create a virtual environment:
```bash
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
```

3. Install dependencies:
```bash
pip install -r requirements.txt
```

4. Configure environment variables:
```bash
cp .env.example .env
# Edit .env with your Azure configuration
```

## Configuration

### Environment Variables

Create a `.env` file with the following variables:

```env
# Azure Configuration
KUSTO_CLUSTER=https://your-cluster.kusto.windows.net
KUSTO_DATABASE=SubscriptionDB
LOGIC_APP_URL=https://your-logic-app-url.com/triggers/manual/paths/invoke

# Application Configuration
SECRET_KEY=your-secret-key-here
FLASK_ENV=development
```

### Kusto Database Schema

Your Kusto database should have a table with the following structure:

```kusto
.create table SubscriptionAccountTeams (
    SubscriptionId: string,
    AccountTeamEmail: string,
    AccountTeamName: string
)
```

### Azure Logic Apps

Create an Azure Logic App with an HTTP trigger that accepts the following JSON payload:

```json
{
    "to": ["email1@company.com", "email2@company.com"],
    "subject": "Email Subject",
    "body": "Email content",
    "from": "sender@company.com",
    "timestamp": "2024-01-01T00:00:00"
}
```

## Usage

1. Start the application:
```bash
python app.py
```

2. Open your browser and navigate to `http://localhost:5000`

3. Use the web interface to:
   - Enter subscription IDs manually or upload a CSV file
   - Review the fetched account team information
   - Compose and send emails to the account teams

### CSV File Format

The CSV file should have subscription IDs in the first column:

```csv
SubscriptionId
12345678-1234-1234-1234-123456789012
87654321-4321-4321-4321-210987654321
```

## API Endpoints

- `GET /` - Main web interface
- `POST /fetch_emails` - Fetch account team emails for subscription IDs
- `POST /send_email` - Send email via Azure Logic Apps
- `GET /health` - Health check endpoint

## Authentication

The application uses Azure Default Credential for authentication, which supports:

- Azure CLI authentication
- Managed identity (when running on Azure)
- Environment variables (service principal)
- Visual Studio Code authentication
- Azure PowerShell authentication

## Error Handling

The application includes comprehensive error handling for:

- Invalid subscription ID formats
- Kusto connection failures
- Logic Apps integration issues
- File upload validation
- Email validation

## Security Considerations

- Environment variables for sensitive configuration
- Input validation for all user inputs
- CSRF protection via Flask's built-in security features
- File upload restrictions (CSV only, size limits)

## Development

### Azure Deployment with azd

This application can be deployed to Azure using the Azure Developer CLI (azd):

1. Install the Azure Developer CLI:
```bash
# Windows
winget install microsoft.azd

# macOS
brew tap azure/azd && brew install azd

# Linux (via curl)
curl -fsSL https://aka.ms/install-azd.sh | bash
```

2. Initialize and deploy:
```bash
# Log in to Azure
azd auth login

# Initialize the environment (first time only)
azd init

# Set your environment variables (optional, uses existing Kusto cluster)
azd env set KUSTO_CLUSTER "https://your-cluster.kusto.windows.net"
azd env set KUSTO_DATABASE "SubscriptionDB"
azd env set LOGIC_APP_URL "https://your-logic-app-url.com/triggers/manual/paths/invoke"
azd env set DEMO_MODE "false"

# Deploy to Azure
azd up
```

The deployment will create:
- Azure Container Registry for the application image
- Azure Container Apps Environment
- Container App running the Stratos application
- Log Analytics workspace for monitoring
- Managed Identity for secure access

**Note**: This deployment does not create a Kusto cluster or Logic App. You need to provide existing resource URLs in the environment variables.

### Running Tests

```bash
# Install development dependencies
pip install pytest pytest-cov

# Run tests
pytest
```

### Code Structure

```
stratos/
├── app.py                 # Main Flask application
├── requirements.txt       # Python dependencies
├── .env.example          # Environment configuration template
├── .gitignore           # Git ignore rules
├── templates/           # HTML templates
│   ├── base.html       # Base template
│   └── index.html      # Main page template
└── static/             # Static assets
    ├── css/
    │   └── style.css   # Custom styles
    └── js/
        └── app.js      # JavaScript functionality
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests for new functionality
5. Submit a pull request

## License

This project is licensed under the MIT License. See the LICENSE file for details.

## Support

For issues and questions, please create an issue in the GitHub repository.