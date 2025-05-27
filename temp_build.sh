#!/bin/bash

# CustomFit SDK QA Build Script
# Builds all demo apps for Android and iOS platforms
# Organizes outputs in a single folder for QA team

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
BUILD_DATE=$(date +"%Y%m%d_%H%M%S")
QA_FOLDER="QA_Build_20250527_143346"
ROOT_DIR=$(pwd)

# App versions
ANDROID_VERSION="1.0.0"
IOS_VERSION="1.0.0"
FLUTTER_VERSION="1.0.0"
RN_VERSION="1.0.0"

echo -e "${BLUE}🚀 CustomFit SDK QA Build Script${NC}"
echo -e "${BLUE}=================================${NC}"
echo -e "Build Date: ${BUILD_DATE}"
echo -e "Output Folder: ${QA_FOLDER}"
echo ""

# Create QA build folder structure
create_qa_folder() {
    echo -e "${YELLOW}📁 Creating QA build folder structure...${NC}"
    
    rm -rf "${QA_FOLDER}"
    mkdir -p "${QA_FOLDER}/Android"
    mkdir -p "${QA_FOLDER}/iOS"
    mkdir -p "${QA_FOLDER}/Documentation"
    mkdir -p "${QA_FOLDER}/Build_Logs"
    
    echo -e "${GREEN}✅ QA folder structure created${NC}"
}

# Build Android Native SDK Demo
build_android_native() {
    echo -e "${YELLOW}🤖 Building Android Native SDK Demo...${NC}"
    
    cd "${ROOT_DIR}/demo-android-app-sdk"
    
    # Clean and build
    echo "Cleaning previous builds..."
    ./gradlew clean > "${ROOT_DIR}/${QA_FOLDER}/Build_Logs/android_native_build.log" 2>&1
    
    echo "Building debug APK..."
    ./gradlew assembleDebug >> "${ROOT_DIR}/${QA_FOLDER}/Build_Logs/android_native_build.log" 2>&1
    
    echo "Building release APK..."
    ./gradlew assembleRelease >> "${ROOT_DIR}/${QA_FOLDER}/Build_Logs/android_native_build.log" 2>&1
    
    # Copy APKs
    if [ -f "app/build/outputs/apk/debug/app-debug.apk" ]; then
        cp "app/build/outputs/apk/debug/app-debug.apk" "${ROOT_DIR}/${QA_FOLDER}/Android/CustomFit_Android_Native_Debug_v${ANDROID_VERSION}.apk"
        echo -e "${GREEN}✅ Android Native Debug APK created${NC}"
    else
        echo -e "${RED}❌ Android Native Debug APK build failed${NC}"
    fi
    
    if [ -f "app/build/outputs/apk/release/app-release-unsigned.apk" ]; then
        cp "app/build/outputs/apk/release/app-release-unsigned.apk" "${ROOT_DIR}/${QA_FOLDER}/Android/CustomFit_Android_Native_Release_v${ANDROID_VERSION}.apk"
        echo -e "${GREEN}✅ Android Native Release APK created${NC}"
    else
        echo -e "${RED}❌ Android Native Release APK build failed${NC}"
    fi
    
    cd "${ROOT_DIR}"
}

# Build iOS Swift SDK Demo
build_ios_swift() {
    echo -e "${YELLOW}🍎 Building iOS Swift SDK Demo...${NC}"
    
    cd "${ROOT_DIR}/demo-swift-app-sdk"
    
    # Build with xcodebuild
    echo "Building Swift iOS app..."
    
    # Build for simulator (easier for QA testing on macOS)
    xcodebuild -scheme CustomFitDemoApp \
               -configuration Debug \
               -destination 'platform=iOS Simulator,name=iPhone 15,OS=17.0.1' \
               -archivePath "${ROOT_DIR}/${QA_FOLDER}/iOS/CustomFit_iOS_Swift_Debug.xcarchive" \
               archive > "${ROOT_DIR}/${QA_FOLDER}/Build_Logs/ios_swift_build.log" 2>&1
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ iOS Swift Debug archive created${NC}"
        
        # Try to export IPA for testing (optional - don't fail if this doesn't work)
        echo "Attempting to export IPA (this may fail without proper code signing)..."
        
        cat > export_options.plist << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>development</string>
    <key>teamID</key>
    <string>YOUR_TEAM_ID</string>
</dict>
</plist>
EOF
        
        # Don't fail the script if IPA export fails - this is optional
        set +e
        xcodebuild -exportArchive \
                   -archivePath "${ROOT_DIR}/${QA_FOLDER}/iOS/CustomFit_iOS_Swift_Debug.xcarchive" \
                   -exportPath "${ROOT_DIR}/${QA_FOLDER}/iOS/" \
                   -exportOptionsPlist export_options.plist >> "${ROOT_DIR}/${QA_FOLDER}/Build_Logs/ios_swift_build.log" 2>&1
        
        IPA_EXPORT_RESULT=$?
        set -e
        
        # Rename IPA if export succeeded
        if [ $IPA_EXPORT_RESULT -eq 0 ] && [ -f "${ROOT_DIR}/${QA_FOLDER}/iOS/CustomFitDemoApp.ipa" ]; then
            mv "${ROOT_DIR}/${QA_FOLDER}/iOS/CustomFitDemoApp.ipa" "${ROOT_DIR}/${QA_FOLDER}/iOS/CustomFit_iOS_Swift_v${IOS_VERSION}.ipa"
            echo -e "${GREEN}✅ iOS Swift IPA exported successfully${NC}"
        else
            echo -e "${YELLOW}⚠️ iOS Swift IPA export failed (archive available for testing)${NC}"
        fi
        
        rm -f export_options.plist
    else
        echo -e "${RED}❌ iOS Swift build failed${NC}"
    fi
    
    cd "${ROOT_DIR}"
}

# Build Flutter SDK Demo (Android + iOS)
build_flutter() {
    echo -e "${YELLOW}💙 Building Flutter SDK Demo...${NC}"
    
    cd "${ROOT_DIR}/demo-flutter-app-sdk"
    
    # Ensure Flutter dependencies
    echo "Getting Flutter dependencies..."
    flutter pub get > "${ROOT_DIR}/${QA_FOLDER}/Build_Logs/flutter_build.log" 2>&1
    
    # Build Android APK
    echo "Building Flutter Android APK..."
    
    # Don't fail the script if individual builds fail
    set +e
    flutter build apk --debug >> "${ROOT_DIR}/${QA_FOLDER}/Build_Logs/flutter_build.log" 2>&1
    DEBUG_RESULT=$?
    
    flutter build apk --release >> "${ROOT_DIR}/${QA_FOLDER}/Build_Logs/flutter_build.log" 2>&1
    RELEASE_RESULT=$?
    set -e
    
    # Copy Flutter Android APKs
    if [ $DEBUG_RESULT -eq 0 ] && [ -f "build/app/outputs/flutter-apk/app-debug.apk" ]; then
        cp "build/app/outputs/flutter-apk/app-debug.apk" "${ROOT_DIR}/${QA_FOLDER}/Android/CustomFit_Flutter_Android_Debug_v${FLUTTER_VERSION}.apk"
        echo -e "${GREEN}✅ Flutter Android Debug APK created${NC}"
    else
        echo -e "${RED}❌ Flutter Android Debug APK build failed${NC}"
    fi
    
    if [ $RELEASE_RESULT -eq 0 ] && [ -f "build/app/outputs/flutter-apk/app-release.apk" ]; then
        cp "build/app/outputs/flutter-apk/app-release.apk" "${ROOT_DIR}/${QA_FOLDER}/Android/CustomFit_Flutter_Android_Release_v${FLUTTER_VERSION}.apk"
        echo -e "${GREEN}✅ Flutter Android Release APK created${NC}"
    else
        echo -e "${RED}❌ Flutter Android Release APK build failed${NC}"
    fi
    
    # Build iOS IPA (if on macOS)
    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo "Building Flutter iOS IPA..."
        
        # Don't fail the script if iOS build fails
        set +e
        flutter build ios --debug --no-codesign >> "${ROOT_DIR}/${QA_FOLDER}/Build_Logs/flutter_build.log" 2>&1
        IOS_BUILD_RESULT=$?
        
        if [ $IOS_BUILD_RESULT -eq 0 ]; then
            # Create iOS archive
            xcodebuild -workspace ios/Runner.xcworkspace \
                       -scheme Runner \
                       -configuration Debug \
                       -destination 'platform=iOS Simulator,name=iPhone 15,OS=17.0.1' \
                       -archivePath "${ROOT_DIR}/${QA_FOLDER}/iOS/CustomFit_Flutter_iOS_Debug.xcarchive" \
                       archive >> "${ROOT_DIR}/${QA_FOLDER}/Build_Logs/flutter_build.log" 2>&1
            
            if [ $? -eq 0 ]; then
                echo -e "${GREEN}✅ Flutter iOS archive created${NC}"
            else
                echo -e "${RED}❌ Flutter iOS archive failed${NC}"
            fi
        else
            echo -e "${RED}❌ Flutter iOS build failed${NC}"
        fi
        set -e
    else
        echo -e "${YELLOW}⚠️ Skipping iOS build (not on macOS)${NC}"
    fi
    
    cd "${ROOT_DIR}"
}

# Build React Native SDK Demo (Android + iOS)
build_react_native() {
    echo -e "${YELLOW}⚛️ Building React Native SDK Demo...${NC}"
    
    cd "${ROOT_DIR}/demo-reactnative-app-sdk"
    
    # Install dependencies
    echo "Installing React Native dependencies..."
    npm install --legacy-peer-deps > "${ROOT_DIR}/${QA_FOLDER}/Build_Logs/react_native_build.log" 2>&1
    
    # Build Android APK
    echo "Building React Native Android APK..."
    cd android
    ./gradlew assembleDebug >> "${ROOT_DIR}/${QA_FOLDER}/Build_Logs/react_native_build.log" 2>&1
    ./gradlew assembleRelease >> "${ROOT_DIR}/${QA_FOLDER}/Build_Logs/react_native_build.log" 2>&1
    
    # Copy React Native Android APKs
    if [ -f "app/build/outputs/apk/debug/app-debug.apk" ]; then
        cp "app/build/outputs/apk/debug/app-debug.apk" "${ROOT_DIR}/${QA_FOLDER}/Android/CustomFit_ReactNative_Android_Debug_v${RN_VERSION}.apk"
        echo -e "${GREEN}✅ React Native Android Debug APK created${NC}"
    fi
    
    if [ -f "app/build/outputs/apk/release/app-release-unsigned.apk" ]; then
        cp "app/build/outputs/apk/release/app-release-unsigned.apk" "${ROOT_DIR}/${QA_FOLDER}/Android/CustomFit_ReactNative_Android_Release_v${RN_VERSION}.apk"
        echo -e "${GREEN}✅ React Native Android Release APK created${NC}"
    fi
    
    cd ..
    
    # Build iOS IPA (if on macOS)
    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo "Building React Native iOS IPA..."
        cd ios
        xcodebuild -workspace CustomFitDemo.xcworkspace \
                   -scheme CustomFitDemo \
                   -configuration Debug \
                   -destination 'platform=iOS Simulator,name=iPhone 15,OS=17.0.1' \
                   -archivePath "${ROOT_DIR}/${QA_FOLDER}/iOS/CustomFit_ReactNative_iOS_Debug.xcarchive" \
                   archive >> "${ROOT_DIR}/${QA_FOLDER}/Build_Logs/react_native_build.log" 2>&1
        
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✅ React Native iOS archive created${NC}"
        else
            echo -e "${RED}❌ React Native iOS build failed${NC}"
        fi
        cd ..
    else
        echo -e "${YELLOW}⚠️ Skipping iOS build (not on macOS)${NC}"
    fi
    
    cd "${ROOT_DIR}"
}

# Generate QA documentation
generate_qa_docs() {
    echo -e "${YELLOW}📝 Generating QA documentation...${NC}"
    
    cat > "${QA_FOLDER}/Documentation/QA_Testing_Guide.md" << 'EOF'
# CustomFit SDK QA Testing Guide

## Overview
This package contains demo applications for all CustomFit SDK platforms for QA testing.

## Contents

### Android APKs (`Android/` folder)
- `CustomFit_Android_Native_Debug_v1.0.0.apk` - Native Android SDK demo (Debug)
- `CustomFit_Android_Native_Release_v1.0.0.apk` - Native Android SDK demo (Release)
- `CustomFit_Flutter_Android_Debug_v1.0.0.apk` - Flutter SDK demo for Android (Debug)
- `CustomFit_Flutter_Android_Release_v1.0.0.apk` - Flutter SDK demo for Android (Release)
- `CustomFit_ReactNative_Android_Debug_v1.0.0.apk` - React Native SDK demo for Android (Debug)
- `CustomFit_ReactNative_Android_Release_v1.0.0.apk` - React Native SDK demo for Android (Release)

### iOS IPAs (`iOS/` folder)
- `CustomFit_iOS_Swift_v1.0.0.ipa` - Native Swift SDK demo
- Flutter and React Native iOS builds (if built on macOS)

## Installation Instructions

### Android
1. Enable "Unknown Sources" in Android Settings > Security
2. Transfer APK to device via ADB, email, or file sharing
3. Tap APK file to install
4. Grant necessary permissions

### iOS
1. Install via Xcode (for simulator testing)
2. Use TestFlight for device testing (requires proper provisioning)
3. Use enterprise distribution (if available)

## Testing Checklist

### Core SDK Features
- [ ] SDK initialization
- [ ] Feature flag retrieval
- [ ] Configuration value updates
- [ ] Event tracking
- [ ] Real-time config listeners
- [ ] Offline functionality
- [ ] Background/foreground transitions

### Platform-Specific Testing
- [ ] Android native implementation
- [ ] iOS Swift implementation  
- [ ] Flutter cross-platform
- [ ] React Native cross-platform

### Network Conditions
- [ ] Online operation
- [ ] Offline operation
- [ ] Poor network conditions
- [ ] Network interruption recovery

### Performance Testing
- [ ] App startup time
- [ ] Memory usage
- [ ] Battery consumption
- [ ] Network usage

### UI/UX Testing
- [ ] Button interactions
- [ ] Screen navigation
- [ ] Toast/Alert messages
- [ ] Configuration displays
- [ ] Event tracking display

## Expected Behavior

### Feature Flags
- `enhanced_toast`: Controls toast message style
- `hero_text`: Updates main screen title text

### Events Tracked
- `[platform]_toast_button_interaction`: When toast button is clicked
- `[platform]_screen_navigation`: When navigating between screens
- `[platform]_config_manual_refresh`: When manually refreshing config

### Real-time Updates
- Configuration changes should appear without app restart
- Event tracking should be visible in logs
- Network status should be reflected in UI

## Troubleshooting

### Common Issues
1. **SDK not initializing**: Check network connectivity and client key
2. **Config not updating**: Verify polling intervals and network status
3. **Events not tracking**: Check flush intervals and network connectivity
4. **High battery usage**: Enable battery optimization features

### Debug Information
- All apps have debug logging enabled
- Check device logs for detailed SDK behavior
- Monitor network requests in development tools

## Contact
For issues or questions, contact the development team with:
- Device information
- App version
- Steps to reproduce
- Expected vs actual behavior
- Log files (if available)
EOF

    # Create build info
    cat > "${QA_FOLDER}/Documentation/Build_Info.txt" << EOF
CustomFit SDK QA Build Information
==================================

Build Date: ${BUILD_DATE}
Builder: $(whoami)
Build Environment: $(uname -a)

App Versions:
- Android Native: ${ANDROID_VERSION}
- iOS Swift: ${IOS_VERSION}
- Flutter: ${FLUTTER_VERSION}
- React Native: ${RN_VERSION}

Git Information:
- Branch: $(git branch --show-current 2>/dev/null || echo "Unknown")
- Commit: $(git rev-parse HEAD 2>/dev/null || echo "Unknown")
- Status: $(git status --porcelain 2>/dev/null | wc -l) modified files

Build Environment:
EOF

    # Add environment info
    if command -v java &> /dev/null; then
        echo "- Java: $(java -version 2>&1 | head -n 1)" >> "${QA_FOLDER}/Documentation/Build_Info.txt"
    fi
    
    if command -v flutter &> /dev/null; then
        echo "- Flutter: $(flutter --version | head -n 1)" >> "${QA_FOLDER}/Documentation/Build_Info.txt"
    fi
    
    if command -v node &> /dev/null; then
        echo "- Node.js: $(node --version)" >> "${QA_FOLDER}/Documentation/Build_Info.txt"
    fi
    
    if command -v npm &> /dev/null; then
        echo "- NPM: $(npm --version)" >> "${QA_FOLDER}/Documentation/Build_Info.txt"
    fi
    
    if command -v xcodebuild &> /dev/null; then
        echo "- Xcode: $(xcodebuild -version | head -n 1)" >> "${QA_FOLDER}/Documentation/Build_Info.txt"
    fi

    echo -e "${GREEN}✅ QA documentation generated${NC}"
}

# Create summary report
create_summary() {
    echo -e "${YELLOW}📊 Creating build summary...${NC}"
    
    echo -e "\n${BLUE}Build Summary${NC}"
    echo -e "${BLUE}=============${NC}"
    
    # Count successful builds
    ANDROID_COUNT=$(ls -1 "${QA_FOLDER}/Android/"*.apk 2>/dev/null | wc -l)
    IOS_COUNT=$(ls -1 "${QA_FOLDER}/iOS/"*.ipa 2>/dev/null | wc -l)
    
    echo -e "Android APKs built: ${GREEN}${ANDROID_COUNT}${NC}"
    echo -e "iOS IPAs built: ${GREEN}${IOS_COUNT}${NC}"
    
    # List all built files
    echo -e "\n${BLUE}Built Files:${NC}"
    find "${QA_FOLDER}" -name "*.apk" -o -name "*.ipa" | while read file; do
        size=$(du -h "$file" | cut -f1)
        echo -e "  📱 $(basename "$file") (${size})"
    done
    
    # Calculate total size
    TOTAL_SIZE=$(du -sh "${QA_FOLDER}" | cut -f1)
    echo -e "\nTotal package size: ${GREEN}${TOTAL_SIZE}${NC}"
}

# Create ZIP package
create_zip_package() {
    echo -e "${YELLOW}📦 Creating ZIP package for QA team...${NC}"
    
    ZIP_NAME="CustomFit_SDK_QA_Package_${BUILD_DATE}.zip"
    
    # Create zip with progress
    zip -r "${ZIP_NAME}" "${QA_FOLDER}" -x "*.DS_Store" > /dev/null 2>&1
    
    if [ $? -eq 0 ]; then
        ZIP_SIZE=$(du -sh "${ZIP_NAME}" | cut -f1)
        echo -e "${GREEN}✅ ZIP package created: ${ZIP_NAME} (${ZIP_SIZE})${NC}"
        
        # Create checksum
        if command -v sha256sum &> /dev/null; then
            sha256sum "${ZIP_NAME}" > "${ZIP_NAME}.sha256"
            echo -e "${GREEN}✅ SHA256 checksum created${NC}"
        elif command -v shasum &> /dev/null; then
            shasum -a 256 "${ZIP_NAME}" > "${ZIP_NAME}.sha256"
            echo -e "${GREEN}✅ SHA256 checksum created${NC}"
        fi
    else
        echo -e "${RED}❌ Failed to create ZIP package${NC}"
    fi
}

# Main execution
main() {
    echo -e "${BLUE}Starting CustomFit SDK QA build process...${NC}\n"
    
    # Check prerequisites
    if ! command -v java &> /dev/null; then
        echo -e "${RED}❌ Java not found. Please install Java for Android builds.${NC}"
        exit 1
    fi
    
    # Create folder structure
    create_qa_folder
    
    # Build all platforms
    echo -e "\n${BLUE}Building all demo applications...${NC}"
    
    # Android builds
    if [ -d "demo-android-app-sdk" ]; then
        build_android_native
    else
        echo -e "${YELLOW}⚠️ Skipping Android Native (demo-android-app-sdk not found)${NC}"
    fi
    
    # iOS builds (only on macOS)
    if [[ "$OSTYPE" == "darwin"* ]] && [ -d "demo-swift-app-sdk" ]; then
        build_ios_swift
    else
        echo -e "${YELLOW}⚠️ Skipping iOS Swift (not on macOS or demo-swift-app-sdk not found)${NC}"
    fi
    
    # Flutter builds
    if command -v flutter &> /dev/null && [ -d "demo-flutter-app-sdk" ]; then
        build_flutter
    else
        echo -e "${YELLOW}⚠️ Skipping Flutter (flutter not found or demo-flutter-app-sdk not found)${NC}"
    fi
    
    # React Native builds
    if command -v npm &> /dev/null && [ -d "demo-reactnative-app-sdk" ]; then
        build_react_native
    else
        echo -e "${YELLOW}⚠️ Skipping React Native (npm not found or demo-reactnative-app-sdk not found)${NC}"
    fi
    
    # Generate documentation and summary
    generate_qa_docs
    create_summary
    create_zip_package
    
    echo -e "\n${GREEN}🎉 QA build process completed!${NC}"
    echo -e "${BLUE}Package ready for QA team: ${ZIP_NAME}${NC}"
    echo -e "${BLUE}Share this file with your QA team for testing.${NC}"
}

# Run main function
main "$@" 