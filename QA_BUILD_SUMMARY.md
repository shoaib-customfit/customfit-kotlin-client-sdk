# CustomFit SDK QA Build Package Summary

## 📦 What's Included

A complete set of build scripts to generate **APKs** and **IPAs** for all CustomFit SDK demo applications across multiple platforms:

### Platforms Covered
- **Android Native SDK** (Kotlin) - Debug & Release APKs
- **iOS Swift SDK** - Simulator & Device builds
- **Flutter SDK** - Android APKs + iOS IPAs
- **React Native SDK** - Android APKs + iOS IPAs

### Build Scripts Available
1. **`build_qa_releases.sh`** - Complete QA package (all platforms)
2. **`build_android_only.sh`** - Android APKs only (faster)
3. **`build_ios_only.sh`** - iOS builds only (macOS required)
4. **`validate_build_environment.sh`** - Check prerequisites

## 🚀 Quick Start for QA Team

### For Development Team (Building)
```bash
# 1. Validate environment
./validate_build_environment.sh

# 2. Build complete QA package
./build_qa_releases.sh

# 3. Share the generated ZIP file
# CustomFit_SDK_QA_Package_[timestamp].zip
```

### For QA Team (Testing)
1. **Receive ZIP package** from development team
2. **Extract** the ZIP file
3. **Install apps:**
   - **Android**: Enable "Unknown Sources" → Install APKs
   - **iOS**: Drag .app bundles to iOS Simulator

## 📱 Apps in QA Package

### Android APKs (6 total)
- `CustomFit_Android_Native_Debug_v1.0.0.apk`
- `CustomFit_Android_Native_Release_v1.0.0.apk`
- `CustomFit_Flutter_Android_Debug_v1.0.0.apk`
- `CustomFit_Flutter_Android_Release_v1.0.0.apk`
- `CustomFit_ReactNative_Android_Debug_v1.0.0.apk`
- `CustomFit_ReactNative_Android_Release_v1.0.0.apk`

### iOS Builds (3+ apps)
- `CustomFit_iOS_Swift_v1.0.0.ipa`
- Flutter iOS archives + app bundles
- React Native iOS archives + app bundles

## ✅ Testing Checklist

### Core SDK Features (All Apps)
- [ ] SDK initialization
- [ ] Feature flag retrieval (`enhanced_toast`, `hero_text`)
- [ ] Configuration updates in real-time
- [ ] Event tracking (button clicks, navigation)
- [ ] Offline functionality
- [ ] Background/foreground transitions

### Platform-Specific Testing
- [ ] **Android**: Native performance, lifecycle handling
- [ ] **iOS**: Swift integration, background refresh
- [ ] **Flutter**: Cross-platform consistency
- [ ] **React Native**: Bridge functionality

### Network Scenarios
- [ ] Online operation
- [ ] Offline mode
- [ ] Poor connectivity recovery
- [ ] Background sync

## 🔧 Build Environment Requirements

### ✅ Current Environment Status
Based on validation:
- **macOS** ✅ (iOS builds supported)
- **Java** ✅ (v17.0.6)
- **Xcode** ✅ (v16.3)
- **iPhone 15 Simulator** ✅
- **Flutter** ✅
- **Node.js** ✅ (v20.19.1)
- **NPM** ✅ (v10.8.2)
- **All project directories** ✅
- **All build scripts** ✅

### Platform Capabilities
- ✅ **Android builds** - Ready
- ✅ **iOS builds** - Ready (macOS)
- ✅ **Flutter builds** - Ready
- ✅ **React Native builds** - Ready

## 📋 For QA Team: Installation Instructions

### Android Installation
1. **Enable installation from unknown sources:**
   - Settings → Security → Unknown Sources (ON)
2. **Transfer APK to device:**
   - Email, ADB, or file sharing
3. **Install:** Tap APK file
4. **Test:** Open app and verify functionality

### iOS Installation
1. **Simulator testing:**
   - Open iOS Simulator
   - Drag .app bundle to simulator
   - App will install automatically
2. **Device testing:**
   - Use Xcode Organizer with .xcarchive files
   - Requires proper provisioning profiles

## 🐛 Troubleshooting

### Common Issues
- **App won't install**: Check "Unknown Sources" on Android
- **iOS app crashes**: Try different simulator version
- **Network features not working**: Check internet connection
- **Config not updating**: Verify polling intervals

### Debug Information
- All apps have debug logging enabled
- Check device logs for detailed SDK behavior
- Monitor network requests in development tools

## 📞 Support

**For QA Team:**
- Test all SDK features across platforms
- Report issues with device info, steps to reproduce
- Include logs when possible

**For Development Team:**
- Build logs available in `Build_Logs/` folder
- Validation script helps identify environment issues
- Scripts support CI/CD integration

## 🎯 Expected Deliverables from QA

### Test Reports Should Include:
1. **Platform coverage** (Android Native, iOS Swift, Flutter, React Native)
2. **Feature validation** (flags, events, real-time updates)
3. **Performance metrics** (startup time, memory, battery)
4. **Network scenario testing** (online/offline/poor connectivity)
5. **Device compatibility** (different Android/iOS versions)

### Bug Reports Should Include:
- Platform and app version
- Device information
- Steps to reproduce
- Expected vs actual behavior
- Screenshots/screen recordings
- Log files (if available)

---

## 🚀 Ready to Ship!

This QA build system provides:
- **Complete platform coverage** across all CustomFit SDKs
- **Automated build process** for consistent releases
- **Comprehensive documentation** for both teams
- **Easy sharing** via ZIP packages
- **Validation tools** to ensure quality

**Share the generated ZIP package with your QA team and start testing! 🎉** 