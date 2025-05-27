#!/bin/bash

# CustomFit SDK Android-Only Build Script
# Builds all Android demo apps quickly for Android testing

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

BUILD_DATE=$(date +"%Y%m%d_%H%M%S")
OUTPUT_FOLDER="Android_APKs_${BUILD_DATE}"
ROOT_DIR=$(pwd)

echo -e "${BLUE}🤖 CustomFit Android APK Builder${NC}"
echo -e "${BLUE}================================${NC}"
echo -e "Output Folder: ${OUTPUT_FOLDER}"
echo ""

# Create output folder
mkdir -p "${OUTPUT_FOLDER}"

# Build Android Native SDK
build_android_native() {
    if [ -d "demo-android-app-sdk" ]; then
        echo -e "${YELLOW}Building Android Native SDK Demo...${NC}"
        cd "demo-android-app-sdk"
        
        ./gradlew clean assembleDebug assembleRelease
        
        if [ -f "app/build/outputs/apk/debug/app-debug.apk" ]; then
            cp "app/build/outputs/apk/debug/app-debug.apk" "${ROOT_DIR}/${OUTPUT_FOLDER}/CustomFit_Android_Native_Debug.apk"
            echo -e "${GREEN}✅ Android Native Debug APK created${NC}"
        fi
        
        if [ -f "app/build/outputs/apk/release/app-release-unsigned.apk" ]; then
            cp "app/build/outputs/apk/release/app-release-unsigned.apk" "${ROOT_DIR}/${OUTPUT_FOLDER}/CustomFit_Android_Native_Release.apk"
            echo -e "${GREEN}✅ Android Native Release APK created${NC}"
        fi
        
        cd "${ROOT_DIR}"
    else
        echo -e "${YELLOW}⚠️ Skipping Android Native (demo-android-app-sdk not found)${NC}"
    fi
}

# Build Flutter Android
build_flutter_android() {
    if command -v flutter &> /dev/null && [ -d "demo-flutter-app-sdk" ]; then
        echo -e "${YELLOW}Building Flutter Android APK...${NC}"
        cd "demo-flutter-app-sdk"
        
        flutter pub get
        flutter build apk --debug
        flutter build apk --release
        
        if [ -f "build/app/outputs/flutter-apk/app-debug.apk" ]; then
            cp "build/app/outputs/flutter-apk/app-debug.apk" "${ROOT_DIR}/${OUTPUT_FOLDER}/CustomFit_Flutter_Android_Debug.apk"
            echo -e "${GREEN}✅ Flutter Android Debug APK created${NC}"
        fi
        
        if [ -f "build/app/outputs/flutter-apk/app-release.apk" ]; then
            cp "build/app/outputs/flutter-apk/app-release.apk" "${ROOT_DIR}/${OUTPUT_FOLDER}/CustomFit_Flutter_Android_Release.apk"
            echo -e "${GREEN}✅ Flutter Android Release APK created${NC}"
        fi
        
        cd "${ROOT_DIR}"
    else
        echo -e "${YELLOW}⚠️ Skipping Flutter Android (flutter not found or demo-flutter-app-sdk not found)${NC}"
    fi
}

# Build React Native Android
build_react_native_android() {
    if command -v npm &> /dev/null && [ -d "demo-reactnative-app-sdk" ]; then
        echo -e "${YELLOW}Building React Native Android APK...${NC}"
        cd "demo-reactnative-app-sdk"
        
        npm install --legacy-peer-deps
        cd android
        ./gradlew assembleDebug assembleRelease
        
        if [ -f "app/build/outputs/apk/debug/app-debug.apk" ]; then
            cp "app/build/outputs/apk/debug/app-debug.apk" "${ROOT_DIR}/${OUTPUT_FOLDER}/CustomFit_ReactNative_Android_Debug.apk"
            echo -e "${GREEN}✅ React Native Android Debug APK created${NC}"
        fi
        
        if [ -f "app/build/outputs/apk/release/app-release-unsigned.apk" ]; then
            cp "app/build/outputs/apk/release/app-release-unsigned.apk" "${ROOT_DIR}/${OUTPUT_FOLDER}/CustomFit_ReactNative_Android_Release.apk"
            echo -e "${GREEN}✅ React Native Android Release APK created${NC}"
        fi
        
        cd "${ROOT_DIR}"
    else
        echo -e "${YELLOW}⚠️ Skipping React Native Android (npm not found or demo-reactnative-app-sdk not found)${NC}"
    fi
}

# Main execution
main() {
    # Check Java
    if ! command -v java &> /dev/null; then
        echo -e "${RED}❌ Java not found. Please install Java for Android builds.${NC}"
        exit 1
    fi
    
    # Build all Android apps
    build_android_native
    build_flutter_android
    build_react_native_android
    
    # Summary
    echo -e "\n${BLUE}Build Summary${NC}"
    echo -e "${BLUE}=============${NC}"
    
    APK_COUNT=$(ls -1 "${OUTPUT_FOLDER}/"*.apk 2>/dev/null | wc -l)
    echo -e "Android APKs built: ${GREEN}${APK_COUNT}${NC}"
    
    echo -e "\n${BLUE}Built APKs:${NC}"
    ls -la "${OUTPUT_FOLDER}/"*.apk 2>/dev/null | while read line; do
        filename=$(echo "$line" | awk '{print $9}')
        size=$(echo "$line" | awk '{print $5}')
        echo -e "  📱 $(basename "$filename") ($(numfmt --to=iec-i --suffix=B $size))"
    done
    
    # Create zip
    ZIP_NAME="CustomFit_Android_APKs_${BUILD_DATE}.zip"
    zip -r "${ZIP_NAME}" "${OUTPUT_FOLDER}" > /dev/null 2>&1
    
    if [ $? -eq 0 ]; then
        ZIP_SIZE=$(du -sh "${ZIP_NAME}" | cut -f1)
        echo -e "\n${GREEN}✅ ZIP package created: ${ZIP_NAME} (${ZIP_SIZE})${NC}"
    fi
    
    echo -e "\n${GREEN}🎉 Android build completed!${NC}"
}

main "$@" 