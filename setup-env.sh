#!/bin/bash

# Environment Setup Script for Stratos
# This script helps set up the local development environment

set -e

echo "🛠️  Stratos Environment Setup"
echo "============================"

# Check Python version
echo "📋 Checking Python version..."
if command -v python3 &> /dev/null; then
    PYTHON_VERSION=$(python3 --version | cut -d' ' -f2)
    echo "✅ Python $PYTHON_VERSION found"
    
    # Check if version is 3.8 or higher
    if python3 -c "import sys; exit(0 if sys.version_info >= (3, 8) else 1)"; then
        echo "✅ Python version is compatible"
    else
        echo "❌ Python 3.8 or higher is required"
        exit 1
    fi
else
    echo "❌ Python 3 is not installed"
    exit 1
fi

# Create virtual environment
if [ ! -d "venv" ]; then
    echo "🔧 Creating virtual environment..."
    python3 -m venv venv
    echo "✅ Virtual environment created"
else
    echo "✅ Virtual environment already exists"
fi

# Activate virtual environment
echo "🔄 Activating virtual environment..."
source venv/bin/activate

# Upgrade pip
echo "📦 Upgrading pip..."
pip install --upgrade pip

# Install dependencies
echo "📦 Installing dependencies..."
pip install -r requirements.txt

# Create .env file if it doesn't exist
if [ ! -f ".env" ]; then
    echo "⚙️  Creating .env file..."
    cp .env.example .env
    echo "✅ .env file created from template"
    echo ""
    echo "📝 Please edit .env file to configure your Azure services:"
    echo "   - KUSTO_CLUSTER: Your Azure Data Explorer cluster URL"
    echo "   - KUSTO_DATABASE: Your database name (default: SubscriptionDB)"
    echo "   - LOGIC_APP_URL: Your Logic App trigger URL"
    echo "   - SECRET_KEY: A secure secret key for Flask"
    echo ""
    echo "💡 Leave these empty to run in demo mode with mock data"
else
    echo "✅ .env file already exists"
fi

echo ""
echo "🎉 Setup completed successfully!"
echo ""
echo "📋 Next steps:"
echo "1. Edit the .env file with your Azure configuration (optional)"
echo "2. Run the application:"
echo "   source venv/bin/activate"
echo "   python app.py"
echo ""
echo "🌐 The application will be available at http://localhost:5000"
echo ""
echo "🚀 To deploy to Azure, use:"
echo "   ./deploy.sh"