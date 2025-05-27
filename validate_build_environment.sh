#!/bin/bash

# CustomFit SDK Build Environment Validation
# Checks prerequisites and validates build environment

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🔍 CustomFit SDK Build Environment Validation${NC}"
echo -e "${BLUE}=============================================${NC}"
echo ""

# Check operating system
check_os() {
    echo -e "${YELLOW}Checking Operating System...${NC}"
    OS_TYPE=$(uname -s)
    echo -e "OS: ${GREEN}${OS_TYPE}${NC}"
    
    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo -e "Platform: ${GREEN}macOS (iOS builds supported)${NC}"
        SUPPORTS_IOS=true
    else
        echo -e "Platform: ${YELLOW}Non-macOS (iOS builds not supported)${NC}"
        SUPPORTS_IOS=false
    fi
    echo ""
}

# Check Java
check_java() {
    echo -e "${YELLOW}Checking Java...${NC}"
    if command -v java &> /dev/null; then
        JAVA_VERSION=$(java -version 2>&1 | head -n 1)
        echo -e "Java: ${GREEN}✅ ${JAVA_VERSION}${NC}"
    else
        echo -e "Java: ${RED}❌ Not found${NC}"
        echo -e "  Install Java JDK 8+ for Android builds"
    fi
    echo ""
}

# Check Android environment
check_android() {
    echo -e "${YELLOW}Checking Android Environment...${NC}"
    
    if [ -n "$ANDROID_HOME" ]; then
        echo -e "ANDROID_HOME: ${GREEN}✅ $ANDROID_HOME${NC}"
    else
        echo -e "ANDROID_HOME: ${YELLOW}⚠️ Not set${NC}"
    fi
    
    if command -v gradle &> /dev/null; then
        GRADLE_VERSION=$(gradle --version | grep "Gradle" | head -n 1)
        echo -e "Gradle: ${GREEN}✅ ${GRADLE_VERSION}${NC}"
    else
        echo -e "Gradle: ${YELLOW}⚠️ Not found (wrapper scripts available)${NC}"
    fi
    echo ""
}

# Check iOS environment
check_ios() {
    if [ "$SUPPORTS_IOS" = true ]; then
        echo -e "${YELLOW}Checking iOS Environment...${NC}"
        
        if command -v xcodebuild &> /dev/null; then
            XCODE_VERSION=$(xcodebuild -version | head -n 1)
            echo -e "Xcode: ${GREEN}✅ ${XCODE_VERSION}${NC}"
            
            # Check for simulators
            SIM_COUNT=$(xcrun simctl list devices | grep -c "iPhone 15" || echo "0")
            if [ "$SIM_COUNT" -gt 0 ]; then
                echo -e "iOS Simulator: ${GREEN}✅ iPhone 15 available${NC}"
            else
                echo -e "iOS Simulator: ${YELLOW}⚠️ iPhone 15 not found${NC}"
            fi
        else
            echo -e "Xcode: ${RED}❌ Not found${NC}"
            echo -e "  Install Xcode for iOS builds"
        fi
        echo ""
    fi
}

# Check Flutter
check_flutter() {
    echo -e "${YELLOW}Checking Flutter Environment...${NC}"
    if command -v flutter &> /dev/null; then
        FLUTTER_VERSION=$(flutter --version | head -n 1)
        echo -e "Flutter: ${GREEN}✅ ${FLUTTER_VERSION}${NC}"
        
        echo -e "${BLUE}Flutter Doctor Summary:${NC}"
        flutter doctor --machine | jq -r '.[] | select(.status == "installed") | "  ✅ " + .name' 2>/dev/null || flutter doctor | head -n 10
    else
        echo -e "Flutter: ${YELLOW}⚠️ Not found${NC}"
        echo -e "  Install Flutter SDK for Flutter builds"
    fi
    echo ""
}

# Check React Native
check_react_native() {
    echo -e "${YELLOW}Checking React Native Environment...${NC}"
    
    if command -v node &> /dev/null; then
        NODE_VERSION=$(node --version)
        echo -e "Node.js: ${GREEN}✅ ${NODE_VERSION}${NC}"
    else
        echo -e "Node.js: ${RED}❌ Not found${NC}"
        echo -e "  Install Node.js for React Native builds"
    fi
    
    if command -v npm &> /dev/null; then
        NPM_VERSION=$(npm --version)
        echo -e "NPM: ${GREEN}✅ v${NPM_VERSION}${NC}"
    else
        echo -e "NPM: ${RED}❌ Not found${NC}"
    fi
    echo ""
}

# Check project structure
check_projects() {
    echo -e "${YELLOW}Checking Project Structure...${NC}"
    
    projects=("demo-android-app-sdk" "demo-swift-app-sdk" "demo-flutter-app-sdk" "demo-reactnative-app-sdk")
    
    for project in "${projects[@]}"; do
        if [ -d "$project" ]; then
            echo -e "  ${GREEN}✅ $project${NC}"
        else
            echo -e "  ${RED}❌ $project${NC}"
        fi
    done
    echo ""
}

# Check build scripts
check_build_scripts() {
    echo -e "${YELLOW}Checking Build Scripts...${NC}"
    
    scripts=("build_qa_releases.sh" "build_android_only.sh" "build_ios_only.sh")
    
    for script in "${scripts[@]}"; do
        if [ -f "$script" ]; then
            if [ -x "$script" ]; then
                echo -e "  ${GREEN}✅ $script (executable)${NC}"
            else
                echo -e "  ${YELLOW}⚠️ $script (not executable)${NC}"
                echo -e "    Run: chmod +x $script"
            fi
        else
            echo -e "  ${RED}❌ $script (missing)${NC}"
        fi
    done
    echo ""
}

# Test build script validation
test_build_scripts() {
    echo -e "${YELLOW}Testing Build Scripts (Validation Only)...${NC}"
    
    # Test main script help/validation
    if [ -x "build_qa_releases.sh" ]; then
        echo -e "${BLUE}Testing main QA script validation...${NC}"
        # We'll just check if the script can parse its initial checks
        bash -n build_qa_releases.sh && echo -e "  ${GREEN}✅ build_qa_releases.sh syntax OK${NC}" || echo -e "  ${RED}❌ build_qa_releases.sh syntax error${NC}"
    fi
    
    if [ -x "build_android_only.sh" ]; then
        echo -e "${BLUE}Testing Android-only script validation...${NC}"
        bash -n build_android_only.sh && echo -e "  ${GREEN}✅ build_android_only.sh syntax OK${NC}" || echo -e "  ${RED}❌ build_android_only.sh syntax error${NC}"
    fi
    
    if [ -x "build_ios_only.sh" ]; then
        echo -e "${BLUE}Testing iOS-only script validation...${NC}"
        bash -n build_ios_only.sh && echo -e "  ${GREEN}✅ build_ios_only.sh syntax OK${NC}" || echo -e "  ${RED}❌ build_ios_only.sh syntax error${NC}"
    fi
    echo ""
}

# Generate recommendations
generate_recommendations() {
    echo -e "${BLUE}📋 Recommendations${NC}"
    echo -e "${BLUE}=================${NC}"
    
    echo -e "${GREEN}Ready for:${NC}"
    if command -v java &> /dev/null; then
        echo -e "  ✅ Android builds"
    fi
    if [ "$SUPPORTS_IOS" = true ] && command -v xcodebuild &> /dev/null; then
        echo -e "  ✅ iOS builds"
    fi
    if command -v flutter &> /dev/null; then
        echo -e "  ✅ Flutter builds"
    fi
    if command -v npm &> /dev/null; then
        echo -e "  ✅ React Native builds"
    fi
    
    echo -e "\n${YELLOW}Missing/Recommended:${NC}"
    if ! command -v java &> /dev/null; then
        echo -e "  📦 Install Java JDK 8+ for Android builds"
    fi
    if [ "$SUPPORTS_IOS" = true ] && ! command -v xcodebuild &> /dev/null; then
        echo -e "  📦 Install Xcode for iOS builds"
    fi
    if ! command -v flutter &> /dev/null; then
        echo -e "  📦 Install Flutter SDK for Flutter builds"
    fi
    if ! command -v npm &> /dev/null; then
        echo -e "  📦 Install Node.js and NPM for React Native builds"
    fi
    
    echo -e "\n${BLUE}Next Steps:${NC}"
    echo -e "1. Fix any missing dependencies above"
    echo -e "2. Run: ${GREEN}./build_qa_releases.sh${NC} for complete QA build"
    echo -e "3. Or run platform-specific scripts for faster iteration:"
    echo -e "   - ${GREEN}./build_android_only.sh${NC} (Android APKs only)"
    if [ "$SUPPORTS_IOS" = true ]; then
        echo -e "   - ${GREEN}./build_ios_only.sh${NC} (iOS IPAs only)"
    fi
    echo ""
}

# Main execution
main() {
    check_os
    check_java
    check_android
    check_ios
    check_flutter
    check_react_native
    check_projects
    check_build_scripts
    test_build_scripts
    generate_recommendations
    
    echo -e "${GREEN}🎉 Environment validation completed!${NC}"
    echo -e "${BLUE}You can now run the build scripts to generate QA packages.${NC}"
}

main "$@" 