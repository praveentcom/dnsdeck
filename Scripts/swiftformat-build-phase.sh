#!/bin/bash

# SwiftFormat Build Phase Script for DNSDeck
# This script runs SwiftFormat on the source files during the build process

# Check if SwiftFormat is installed
if which swiftformat >/dev/null; then
    echo "Running SwiftFormat..."
    
    # Run SwiftFormat on the source directory
    # The --lint flag will make the build fail if files need formatting
    # Remove --lint if you want it to auto-format during build instead
    swiftformat --lint "${SRCROOT}/DNSDeck"
    
    if [ $? -eq 0 ]; then
        echo "✅ SwiftFormat passed - all files are properly formatted"
    else
        echo "❌ SwiftFormat failed - some files need formatting"
        echo "Run 'swiftformat .' in the project root to fix formatting issues"
        exit 1
    fi
else
    echo "⚠️  SwiftFormat not installed. Install with: brew install swiftformat"
    echo "Skipping SwiftFormat check..."
fi
