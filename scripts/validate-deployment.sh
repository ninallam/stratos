#!/bin/bash

# Stratos Deployment Validation Script
# This script validates that all deployment files are present and correct

echo "🔍 Validating Stratos deployment configuration..."
echo "================================================"

# Check for required files
files=(
    "azure.yaml"
    "requirements.txt"
    "app.py"
    "startup.sh"
    "infra/main.bicep"
    "infra/main.parameters.json"
    "infra/resources/api.bicep"
    "infra/resources/logic-app.bicep"
    "infra/resources/keyvault.bicep"
    "infra/resources/monitoring.bicep"
    "DEPLOYMENT.md"
)

missing_files=()
for file in "${files[@]}"; do
    if [ -f "$file" ]; then
        echo "✅ $file"
    else
        echo "❌ $file"
        missing_files+=("$file")
    fi
done

if [ ${#missing_files[@]} -eq 0 ]; then
    echo ""
    echo "✅ All required files are present!"
else
    echo ""
    echo "❌ Missing files: ${missing_files[*]}"
    exit 1
fi

# Validate Bicep syntax
echo ""
echo "🔍 Validating Bicep template syntax..."
if command -v az &> /dev/null; then
    if az bicep build --file infra/main.bicep --stdout > /dev/null 2>&1; then
        echo "✅ Bicep templates are syntactically valid"
    else
        echo "❌ Bicep template validation failed"
        exit 1
    fi
else
    echo "⚠️  Azure CLI not available - skipping Bicep validation"
fi

# Validate Python app
echo ""
echo "🔍 Validating Python application..."
if python -c "import app" 2>/dev/null; then
    echo "✅ Python application imports successfully"
else
    echo "❌ Python application import failed"
    exit 1
fi

# Check for executability of scripts
echo ""
echo "🔍 Validating script permissions..."
if [ -x "startup.sh" ]; then
    echo "✅ startup.sh is executable"
else
    echo "❌ startup.sh is not executable"
    exit 1
fi

if [ -x "scripts/deploy.sh" ]; then
    echo "✅ scripts/deploy.sh is executable"
else
    echo "❌ scripts/deploy.sh is not executable"
    exit 1
fi

echo ""
echo "🎉 All validation checks passed!"
echo "Your Stratos application is ready for Azure deployment."
echo ""
echo "Next steps:"
echo "1. Run 'scripts/deploy.sh' or use 'azd up' directly"
echo "2. Follow the instructions in DEPLOYMENT.md"