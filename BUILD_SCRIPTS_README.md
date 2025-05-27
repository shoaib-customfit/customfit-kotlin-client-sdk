# CustomFit SDK QA Build Scripts

This directory contains automated build scripts to generate APKs and IPAs for all CustomFit SDK demo applications for QA testing.

## Overview

The build scripts automate the process of building all demo applications across different platforms:
- **Android Native SDK** (Kotlin)
- **iOS Swift SDK** 
- **Flutter SDK** (Android & iOS)
- **React Native SDK** (Android & iOS)

## Scripts Available

### 1. `build_qa_releases.sh` (Main Script)
**Complete QA build for all platforms**
- Builds all Android APKs and iOS IPAs
- Creates organized folder structure
- Generates comprehensive documentation
- Creates ZIP package for easy sharing
- Includes build logs and testing guides

**Usage:**
```bash
./build_qa_releases.sh
```

**Output:**
- `CustomFit_QA_Builds_[timestamp]/` folder containing:
  - `Android/` - All Android APKs
  - `iOS/` - All iOS IPAs and archives
  - `Documentation/` - Testing guides and build info
  - `Build_Logs/` - Detailed build logs
- `CustomFit_SDK_QA_Package_[timestamp].zip` - Complete package for QA team

### 2. `build_android_only.sh`
**Android-only builds for faster iteration**
- Builds only Android APKs
- Faster execution for Android-specific testing
- Creates timestamped folder and ZIP

**Usage:**
```bash
./build_android_only.sh
```

**Output:**
- `Android_APKs_[timestamp]/` folder
- `CustomFit_Android_APKs_[timestamp].zip`

### 3. `build_ios_only.sh`
**iOS-only builds (macOS required)**
- Builds only iOS archives and app bundles
- Simulator-ready builds
- Creates timestamped folder and ZIP

**Usage:**
```bash
./build_ios_only.sh
```

**Output:**
- `iOS_IPAs_[timestamp]/` folder
- `CustomFit_iOS_Apps_[timestamp].zip`

## Prerequisites

### For All Builds
- **Git** - For repository information
- **macOS** (for iOS builds)

### For Android Builds
- **Java JDK 8+**
- **Android SDK**
- **Gradle** (or use wrapper scripts)

### For iOS Builds
- **macOS** (required)
- **Xcode** with command line tools
- **iOS Simulator**

### For Flutter Builds
- **Flutter SDK** properly installed
- **Dart SDK** (included with Flutter)

### For React Native Builds
- **Node.js** and **npm**
- **React Native CLI**

## Quick Start

1. **Make scripts executable:**
   ```bash
   chmod +x build_qa_releases.sh build_android_only.sh build_ios_only.sh
   ```

2. **Run complete QA build:**
   ```bash
   ./build_qa_releases.sh
   ```

3. **Share with QA team:**
   ```bash
   # Upload the generated ZIP file to your sharing platform
   ls -la CustomFit_SDK_QA_Package_*.zip
   ```

## Build Outputs

### Android APKs Generated
- `CustomFit_Android_Native_Debug_v1.0.0.apk`
- `CustomFit_Android_Native_Release_v1.0.0.apk`
- `CustomFit_Flutter_Android_Debug_v1.0.0.apk`
- `CustomFit_Flutter_Android_Release_v1.0.0.apk`
- `CustomFit_ReactNative_Android_Debug_v1.0.0.apk`
- `CustomFit_ReactNative_Android_Release_v1.0.0.apk`

### iOS Builds Generated
- `CustomFit_iOS_Swift_v1.0.0.ipa`
- Flutter iOS archives and app bundles
- React Native iOS archives and app bundles

## QA Package Contents

The main script generates a comprehensive QA package with:

```
CustomFit_QA_Builds_[timestamp]/
├── Android/
│   ├── CustomFit_Android_Native_Debug_v1.0.0.apk
│   ├── CustomFit_Android_Native_Release_v1.0.0.apk
│   ├── CustomFit_Flutter_Android_Debug_v1.0.0.apk
│   ├── CustomFit_Flutter_Android_Release_v1.0.0.apk
│   ├── CustomFit_ReactNative_Android_Debug_v1.0.0.apk
│   └── CustomFit_ReactNative_Android_Release_v1.0.0.apk
├── iOS/
│   ├── CustomFit_iOS_Swift_v1.0.0.ipa
│   ├── *.xcarchive files
│   └── *.app bundles
├── Documentation/
│   ├── QA_Testing_Guide.md
│   └── Build_Info.txt
└── Build_Logs/
    ├── android_native_build.log
    ├── ios_swift_build.log
    ├── flutter_build.log
    └── react_native_build.log
```

## Testing Instructions for QA Team

### Android Testing
1. **Installation:**
   - Enable "Unknown Sources" in device settings
   - Transfer APK to device
   - Tap APK to install

2. **Testing:**
   - Test both Debug and Release versions
   - Verify all SDK features work
   - Test network connectivity scenarios

### iOS Testing
1. **Simulator Testing:**
   - Drag .app bundles to iOS Simulator
   - Test all functionality

2. **Device Testing:**
   - Use Xcode Organizer with .xcarchive files
   - Requires proper provisioning profiles
   - Test on real devices for performance

## Platform-Specific Features to Test

### Core SDK Features (All Platforms)
- [ ] SDK initialization
- [ ] Feature flag retrieval
- [ ] Configuration updates
- [ ] Event tracking
- [ ] Real-time listeners
- [ ] Offline functionality
- [ ] Background/foreground handling

### Platform-Specific
- [ ] **Android**: Native integration, lifecycle handling
- [ ] **iOS**: Swift integration, background app refresh
- [ ] **Flutter**: Cross-platform consistency
- [ ] **React Native**: Bridge functionality

## Troubleshooting

### Build Failures

#### Android Build Issues
```bash
# Check Java version
java -version

# Check Android SDK
echo $ANDROID_HOME

# Clean and retry
cd demo-android-app-sdk
./gradlew clean
```

#### iOS Build Issues
```bash
# Check Xcode
xcode-select -p

# Clean derived data
rm -rf ~/Library/Developer/Xcode/DerivedData

# Check simulators
xcrun simctl list devices
```

#### Flutter Build Issues
```bash
# Check Flutter installation
flutter doctor

# Clean Flutter project
flutter clean
flutter pub get
```

#### React Native Build Issues
```bash
# Clear npm cache
npm cache clean --force

# Clear Metro cache
npx react-native start --reset-cache

# Check Node version
node --version
```

## Customization

### Changing App Versions
Edit the version variables at the top of each script:
```bash
ANDROID_VERSION="1.0.0"
IOS_VERSION="1.0.0"
FLUTTER_VERSION="1.0.0"
RN_VERSION="1.0.0"
```

### Adding Custom Build Steps
Add your custom build logic in the respective build functions within each script.

### Changing Output Locations
Modify the `OUTPUT_FOLDER` and `QA_FOLDER` variables in each script.

## CI/CD Integration

These scripts can be integrated into your CI/CD pipeline:

```yaml
# Example GitHub Actions step
- name: Build QA Releases
  run: ./build_qa_releases.sh
  
- name: Upload QA Package
  uses: actions/upload-artifact@v3
  with:
    name: qa-builds
    path: CustomFit_SDK_QA_Package_*.zip
```

## Support

For issues with the build scripts:
1. Check the generated build logs in `Build_Logs/` folder
2. Verify all prerequisites are installed
3. Review the error messages in the console output
4. Contact the development team with specific error details

## Security Notes

- Review all generated APKs and IPAs before distribution
- Use proper code signing for production testing
- Consider using TestFlight for iOS distribution
- Implement proper access controls for QA builds

---

**Happy Testing!** 🚀

The build scripts are designed to make QA testing as smooth as possible across all CustomFit SDK platforms. 