#!/bin/bash

# CustomFit SDK iOS-Only Build Script
# Builds all iOS demo apps for iOS testing (macOS only)

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

BUILD_DATE=$(date +"%Y%m%d_%H%M%S")
OUTPUT_FOLDER="iOS_IPAs_${BUILD_DATE}"
ROOT_DIR=$(pwd)

echo -e "${BLUE}🍎 CustomFit iOS IPA Builder${NC}"
echo -e "${BLUE}============================${NC}"
echo -e "Output Folder: ${OUTPUT_FOLDER}"
echo ""

# Check if running on macOS
if [[ "$OSTYPE" != "darwin"* ]]; then
    echo -e "${RED}❌ This script must be run on macOS for iOS builds${NC}"
    exit 1
fi

# Create output folder
mkdir -p "${OUTPUT_FOLDER}"

# Build iOS Swift SDK
build_ios_swift() {
    if [ -d "demo-swift-app-sdk" ]; then
        echo -e "${YELLOW}Building iOS Swift SDK Demo...${NC}"
        cd "demo-swift-app-sdk"
        
        # Build for simulator
        xcodebuild -scheme CustomFitDemoApp \
                   -configuration Debug \
                   -destination 'platform=iOS Simulator,name=iPhone 15,OS=17.0.1' \
                   -archivePath "${ROOT_DIR}/${OUTPUT_FOLDER}/CustomFit_iOS_Swift_Debug.xcarchive" \
                   archive
        
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✅ iOS Swift archive created${NC}"
            
            # Create a simple app bundle for testing
            APP_PATH="${ROOT_DIR}/${OUTPUT_FOLDER}/CustomFitSwiftDemo.app"
            cp -r "${ROOT_DIR}/${OUTPUT_FOLDER}/CustomFit_iOS_Swift_Debug.xcarchive/Products/Applications/CustomFitDemoApp.app" "$APP_PATH" 2>/dev/null || true
            
            if [ -d "$APP_PATH" ]; then
                echo -e "${GREEN}✅ iOS Swift app bundle created${NC}"
            fi
        else
            echo -e "${RED}❌ iOS Swift build failed${NC}"
        fi
        
        cd "${ROOT_DIR}"
    else
        echo -e "${YELLOW}⚠️ Skipping iOS Swift (demo-swift-app-sdk not found)${NC}"
    fi
}

# Build Flutter iOS
build_flutter_ios() {
    if command -v flutter &> /dev/null && [ -d "demo-flutter-app-sdk" ]; then
        echo -e "${YELLOW}Building Flutter iOS IPA...${NC}"
        cd "demo-flutter-app-sdk"
        
        flutter pub get
        flutter build ios --debug --no-codesign
        
        # Create iOS archive
        xcodebuild -workspace ios/Runner.xcworkspace \
                   -scheme Runner \
                   -configuration Debug \
                   -destination 'platform=iOS Simulator,name=iPhone 15,OS=17.0.1' \
                   -archivePath "${ROOT_DIR}/${OUTPUT_FOLDER}/CustomFit_Flutter_iOS_Debug.xcarchive" \
                   archive
        
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✅ Flutter iOS archive created${NC}"
            
            # Create app bundle
            APP_PATH="${ROOT_DIR}/${OUTPUT_FOLDER}/CustomFitFlutterDemo.app"
            cp -r "${ROOT_DIR}/${OUTPUT_FOLDER}/CustomFit_Flutter_iOS_Debug.xcarchive/Products/Applications/Runner.app" "$APP_PATH" 2>/dev/null || true
            
            if [ -d "$APP_PATH" ]; then
                echo -e "${GREEN}✅ Flutter iOS app bundle created${NC}"
            fi
        else
            echo -e "${RED}❌ Flutter iOS build failed${NC}"
        fi
        
        cd "${ROOT_DIR}"
    else
        echo -e "${YELLOW}⚠️ Skipping Flutter iOS (flutter not found or demo-flutter-app-sdk not found)${NC}"
    fi
}

# Build React Native iOS
build_react_native_ios() {
    if command -v npm &> /dev/null && [ -d "demo-reactnative-app-sdk" ]; then
        echo -e "${YELLOW}Building React Native iOS IPA...${NC}"
        cd "demo-reactnative-app-sdk"
        
        npm install
        cd ios
        
        xcodebuild -workspace CustomFitDemo.xcworkspace \
                   -scheme CustomFitDemo \
                   -configuration Debug \
                   -destination 'platform=iOS Simulator,name=iPhone 15,OS=17.0.1' \
                   -archivePath "${ROOT_DIR}/${OUTPUT_FOLDER}/CustomFit_ReactNative_iOS_Debug.xcarchive" \
                   archive
        
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✅ React Native iOS archive created${NC}"
            
            # Create app bundle
            APP_PATH="${ROOT_DIR}/${OUTPUT_FOLDER}/CustomFitReactNativeDemo.app"
            cp -r "${ROOT_DIR}/${OUTPUT_FOLDER}/CustomFit_ReactNative_iOS_Debug.xcarchive/Products/Applications/CustomFitDemo.app" "$APP_PATH" 2>/dev/null || true
            
            if [ -d "$APP_PATH" ]; then
                echo -e "${GREEN}✅ React Native iOS app bundle created${NC}"
            fi
        else
            echo -e "${RED}❌ React Native iOS build failed${NC}"
        fi
        
        cd "${ROOT_DIR}"
    else
        echo -e "${YELLOW}⚠️ Skipping React Native iOS (npm not found or demo-reactnative-app-sdk not found)${NC}"
    fi
}

# Main execution
main() {
    # Check Xcode
    if ! command -v xcodebuild &> /dev/null; then
        echo -e "${RED}❌ Xcode not found. Please install Xcode for iOS builds.${NC}"
        exit 1
    fi
    
    # Build all iOS apps
    build_ios_swift
    build_flutter_ios
    build_react_native_ios
    
    # Summary
    echo -e "\n${BLUE}Build Summary${NC}"
    echo -e "${BLUE}=============${NC}"
    
    ARCHIVE_COUNT=$(ls -1 "${OUTPUT_FOLDER}/"*.xcarchive 2>/dev/null | wc -l)
    APP_COUNT=$(ls -1 "${OUTPUT_FOLDER}/"*.app 2>/dev/null | wc -l)
    
    echo -e "iOS Archives built: ${GREEN}${ARCHIVE_COUNT}${NC}"
    echo -e "iOS App bundles: ${GREEN}${APP_COUNT}${NC}"
    
    echo -e "\n${BLUE}Built Files:${NC}"
    find "${OUTPUT_FOLDER}" -name "*.xcarchive" -o -name "*.app" | while read file; do
        size=$(du -sh "$file" | cut -f1)
        echo -e "  📱 $(basename "$file") (${size})"
    done
    
    # Create zip
    ZIP_NAME="CustomFit_iOS_Apps_${BUILD_DATE}.zip"
    zip -r "${ZIP_NAME}" "${OUTPUT_FOLDER}" > /dev/null 2>&1
    
    if [ $? -eq 0 ]; then
        ZIP_SIZE=$(du -sh "${ZIP_NAME}" | cut -f1)
        echo -e "\n${GREEN}✅ ZIP package created: ${ZIP_NAME} (${ZIP_SIZE})${NC}"
    fi
    
    echo -e "\n${BLUE}Installation Instructions:${NC}"
    echo -e "1. Extract the ZIP file"
    echo -e "2. For .app bundles: Drag to iOS Simulator"
    echo -e "3. For .xcarchive: Use Xcode Organizer for device testing"
    
    echo -e "\n${GREEN}🎉 iOS build completed!${NC}"
}

main "$@" 