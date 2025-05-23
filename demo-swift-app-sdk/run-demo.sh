#!/bin/bash

echo "🚀 Building CustomFit Swift Demo App..."
echo "📱 This demo replicates the Android demo exactly!"
echo ""

# Build the Swift demo
swift build

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Build successful!"
    echo ""
    echo "📋 To run the demo app:"
    echo "   1. 🎯 RECOMMENDED: Open in Xcode for full UI experience:"
    echo "      open ."
    echo "      (Then press Cmd+R to run)"
    echo ""
    echo "   2. 📱 Or open the .xcodeproj that Xcode creates"
    echo ""
    echo "🎯 This demo includes:"
    echo "   • Main screen with hero text (like MainActivity.kt)"
    echo "   • Second screen (like SecondActivity.kt)" 
    echo "   • Toast messages (exact Android replicas)"
    echo "   • SDK integration with same client key"
    echo "   • Event tracking with same event names"
    echo ""
    echo "📱 Exact Android demo replication complete!"
    echo ""
    echo "⚠️  Note: SwiftUI apps require Xcode to display properly."
    echo "   Command-line builds verify code but need Xcode for UI."
else
    echo ""
    echo "❌ Build failed. Please check the errors above."
    exit 1
fi 