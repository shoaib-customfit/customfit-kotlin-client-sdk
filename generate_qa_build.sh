#!/bin/bash

# CustomFit SDK Clean QA Build Generator
# Generates only the essential QA artifacts without bloat

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
BUILD_DATE=$(date +"%Y%m%d_%H%M%S")
QA_FOLDER="QA_Build_${BUILD_DATE}"

echo -e "${BLUE}🧹 CustomFit SDK Clean QA Build Generator${NC}"
echo -e "${BLUE}==========================================${NC}"
echo -e "Build Date: ${BUILD_DATE}"
echo -e "Output Folder: ${QA_FOLDER}"
echo ""

# Function to create clean QA structure
create_clean_qa_structure() {
    echo -e "${YELLOW}📁 Creating clean QA structure...${NC}"
    
    # Remove any existing QA artifacts first
    rm -rf CustomFit_QA_Builds_* QA_Package_* iOS_IPAs_* Android_APKs_* *.xcarchive/
    rm -f CustomFit_*QA_Package*.zip
    
    # Create new clean structure
    mkdir -p "${QA_FOLDER}/Android"
    mkdir -p "${QA_FOLDER}/iOS" 
    mkdir -p "${QA_FOLDER}/Documentation"
    mkdir -p "${QA_FOLDER}/Build_Logs"
    
    echo -e "${GREEN}✅ Clean QA structure created${NC}"
}

# Function to generate minimal documentation
generate_minimal_docs() {
    echo -e "${YELLOW}📝 Generating minimal QA documentation...${NC}"
    
    cat > "${QA_FOLDER}/Documentation/README.md" << EOF
# CustomFit SDK QA Build

## Quick Start
1. Install APKs on Android devices
2. Install IPAs on iOS devices/simulators
3. Test core SDK functionality

## Build Information
- Build Date: ${BUILD_DATE}
- Builder: $(whoami)
- Git Branch: $(git branch --show-current 2>/dev/null || echo "Unknown")
- Git Commit: $(git rev-parse --short HEAD 2>/dev/null || echo "Unknown")

## Test Checklist
- [ ] SDK initialization
- [ ] Feature flag retrieval  
- [ ] Event tracking
- [ ] Network handling
- [ ] Background/foreground transitions

See build logs in \`Build_Logs/\` for details.
EOF

    echo -e "${GREEN}✅ Minimal documentation generated${NC}"
}

# Main execution
main() {
    echo -e "${BLUE}Starting clean QA build process...${NC}\n"
    
    # Create clean structure
    create_clean_qa_structure
    
    # Run the existing build script but capture to our clean folder
    if [ -f "build_qa_releases.sh" ]; then
        echo -e "${YELLOW}🔨 Running optimized build process...${NC}"
        
        # Temporarily modify the build script to use our clean folder
        sed "s/QA_FOLDER=\"CustomFit_QA_Builds_\${BUILD_DATE}\"/QA_FOLDER=\"${QA_FOLDER}\"/" build_qa_releases.sh > temp_build.sh
        chmod +x temp_build.sh
        
        # Run the build
        ./temp_build.sh
        
        # Clean up temp script
        rm -f temp_build.sh
        
        # Generate minimal docs
        generate_minimal_docs
        
        # Create single clean ZIP
        ZIP_NAME="CustomFit_QA_${BUILD_DATE}.zip"
        zip -r "${ZIP_NAME}" "${QA_FOLDER}" -x "*.DS_Store" > /dev/null 2>&1
        
        if [ $? -eq 0 ]; then
            ZIP_SIZE=$(du -sh "${ZIP_NAME}" | cut -f1)
            echo -e "${GREEN}✅ Clean QA package created: ${ZIP_NAME} (${ZIP_SIZE})${NC}"
        fi
        
        echo -e "\n${GREEN}🎉 Clean QA build completed!${NC}"
        echo -e "${BLUE}Package: ${ZIP_NAME}${NC}"
        echo -e "${BLUE}Folder: ${QA_FOLDER}${NC}"
        
    else
        echo -e "${RED}❌ build_qa_releases.sh not found${NC}"
        exit 1
    fi
}

# Show help
if [[ "$1" == "--help" || "$1" == "-h" ]]; then
    echo "Usage: $0"
    echo ""
    echo "Generates a clean QA build package without creating bloat."
    echo "This script:"
    echo "  - Removes old QA artifacts first"
    echo "  - Creates only what's needed"
    echo "  - Generates a single clean ZIP package"
    echo "  - Automatically cleans up after itself"
    exit 0
fi

# Run main function
main "$@" 