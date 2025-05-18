#!/bin/bash

# Script to run the CustomFit Kotlin SDK in headless mode
# This is a workaround for Flutter environment issues

echo "Starting CustomFit SDK Test in headless mode"

# Go to the root directory of the Kotlin SDK
cd /Users/shoaibmohammed/Desktop/work/CF/sdk/customfit-kotlin-client-sdk

# Check if gradlew exists
if [ ! -f "./gradlew" ]; then
    echo "Error: gradlew file not found. Make sure you're in the correct directory."
    exit 1
fi

# Make gradlew executable if it's not
chmod +x ./gradlew

# Run the Kotlin Main class
echo "Running Kotlin Main.kt via Gradle..."
./gradlew run

echo "Test completed successfully" 