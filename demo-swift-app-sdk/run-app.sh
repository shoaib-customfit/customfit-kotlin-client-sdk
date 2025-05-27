#!/bin/bash

echo "🚀 Building and Running CustomFit Swift Demo App..."
echo ""

# Stop any existing instances
echo "🛑 Stopping any running instances..."
killall CustomFitDemoApp 2>/dev/null || true

# Build using Xcode build system (proper bundle handling)
echo "📦 Building with Xcode (proper bundle support)..."
xcodebuild -scheme CustomFitDemoApp -configuration Debug -destination 'platform=macOS' -allowProvisioningUpdates > /dev/null 2>&1

if [ $? -eq 0 ]; then
    echo "✅ Build successful!"
    
    # Find the built executable
    DERIVED_DATA_PATH=$(find ~/Library/Developer/Xcode/DerivedData -name "CustomFitDemoApp" -path "*/Debug/CustomFitDemoApp" -not -path "*simulator*" 2>/dev/null | head -1)
    
    if [ -n "$DERIVED_DATA_PATH" ]; then
        # Launch the properly built app
        echo "🎯 Launching app from: $(dirname $DERIVED_DATA_PATH)"
        open "$DERIVED_DATA_PATH"
        
        echo ""
        echo "✅ CustomFit Swift Demo App is now running!"
        echo ""
        echo "🧪 Test the features:"
        echo "   • Click 'Show Toast' to test alerts"
        echo "   • Click 'Go to Second Screen' for navigation" 
        echo "   • Click 'Refresh Config' to test configuration"
        echo ""
        echo "🛑 To stop the app: killall CustomFitDemoApp"
        echo ""
        echo "💡 This version uses proper Xcode build system"
        echo "   which resolves bundle identifier issues!"
    else
        echo "❌ Could not find built executable. Please try again."
        exit 1
    fi
    
else
    echo "❌ Build failed. Please check the errors above."
    exit 1
fi 