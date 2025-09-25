// Common application JavaScript functions

// Utility function to show toast notifications
function showToast(message, type = 'info') {
    // This can be extended with toast libraries like Toastr
    console.log(`${type.toUpperCase()}: ${message}`);
}

// Form validation utilities
function validateEmail(email) {
    const re = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    return re.test(email);
}

function validateSubscriptionId(subscriptionId) {
    // Basic UUID validation for Azure subscription IDs
    const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
    return uuidRegex.test(subscriptionId);
}

// File handling utilities
function validateCSVFile(file) {
    if (!file) return false;
    
    // Check file type
    if (file.type !== 'text/csv' && !file.name.endsWith('.csv')) {
        return false;
    }
    
    // Check file size (max 5MB)
    if (file.size > 5 * 1024 * 1024) {
        return false;
    }
    
    return true;
}

// Initialize application when DOM is loaded
document.addEventListener('DOMContentLoaded', function() {
    // Auto-dismiss alerts after 5 seconds
    const alerts = document.querySelectorAll('.alert');
    alerts.forEach(alert => {
        if (!alert.querySelector('.btn-close')) {
            setTimeout(() => {
                alert.remove();
            }, 5000);
        }
    });
    
    // Add file validation to CSV input
    const csvInput = document.getElementById('csv_file');
    if (csvInput) {
        csvInput.addEventListener('change', function(e) {
            const file = e.target.files[0];
            if (file && !validateCSVFile(file)) {
                alert('Please select a valid CSV file (max 5MB)');
                e.target.value = '';
            }
        });
    }
    
    // Clear other input when one is used
    if (csvInput) {
        csvInput.addEventListener('change', function() {
            if (this.files.length > 0) {
                const textInput = document.getElementById('subscription_ids');
                if (textInput) textInput.value = '';
            }
        });
    }
    
    const textInput = document.getElementById('subscription_ids');
    if (textInput) {
        textInput.addEventListener('input', function() {
            if (this.value.trim()) {
                if (csvInput) csvInput.value = '';
            }
        });
    }
});

// Export functions for use in other scripts
window.StratosUtils = {
    validateEmail,
    validateSubscriptionId,
    validateCSVFile,
    showToast
};