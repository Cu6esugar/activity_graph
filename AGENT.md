# GPS Overlay Flutter Application - Project Summary

## Project Overview

A Flutter application that overlays GPS track and activity data from FIT files onto photos, creating personalized activity images with route visualization and performance metrics.

## Development Environment

- **Platform**: Windows 11
- **Flutter**: Channel master, version 3.44.0-1.0.pre-439
- **Dart**: 3.13.0-97.0.dev
- **Primary Test Platforms**: Windows desktop, Android emulator (Pixel 6, API 33)
- **IDE**: Any Flutter-compatible IDE

## Build Commands

### Windows Desktop
```bash
flutter run -d windows
```

### Android
```bash
flutter run -d emulator-5554
```

### Hot Reload/Restart
- Press `r` for hot reload (preserves state)
- Press `R` for hot restart (clears state)

### Clean Build
```bash
flutter clean
flutter pub get
flutter run
```

## Dependencies

```yaml
dependencies:
  flutter: sdk
  cupertino_icons: ^1.0.8
  image_picker: ^1.0.7
  file_picker: 8.3.7
  exif: ^3.3.0
  fit_parser: ^2.0.0
  path_provider: ^2.1.2
  path: ^1.9.0
  intl: ^0.19.0
  image: ^4.1.7
```

## Project Structure

```
activity_it/
├── lib/
│   ├── main.dart                         # App entry point
│   ├── models/
│   │   ├── gps_point.dart                # GPS data model with pace calculation
│   │   └ fit_data.dart                   # FIT data model with time matching logic
│   ├── services/
│   │   ├── fit_parser_service.dart       # FIT file parsing (handles enhanced_speed, timestamps)
│   │   ├── exif_service.dart             # EXIF data extraction (DateTimeOriginal)
│   ├── widgets/
│   │   ├── overlay_painter.dart          # CustomPainter for overlay rendering
│   ├── screens/
│   │   ├── home_screen.dart              # Main UI screen with all functionality
│   ├── utils/
│   │   └ponsive_helper.dart              # Responsive utility functions
├── android/                              # Android platform configuration
│   ├── app/build.gradle.kts              # compileSdk: 36
│   ├── settings.gradle.kts               # Global compileSdk enforcement for plugins
│   ├── gradle.properties                 # Gradle configuration
├── pubspec.yaml                          # Dependencies and metadata
├── AGENT.md                              # This file
└── README files                          # Various documentation files
```

## Key Features

### 1. FIT File Parsing
- Extracts GPS coordinates (latitude, longitude)
- Extracts speed data from `enhanced_speed` field (not `speed` which is often null)
- Handles double-type timestamps (FIT format)
- Converts timestamps from FIT epoch (1989-12-31) to local time
- Extracts heart rate, altitude, distance data

### 2. Photo Selection and EXIF Reading
- Reads `DateTimeOriginal` from photo EXIF metadata
- Handles various date formats and parsing errors
- Displays photo with proper aspect ratio preservation

### 3. Time Matching
- Automatic matching: Uses EXIF timestamp to find GPS point
- Manual time selection: User can override with custom timestamp
- Tolerance: 5 seconds for GPS point matching
- UI: Popup dialog for time selection (clears when closed)

### 4. GPS Track Overlay
- **Position**: Right upper corner (30-40% of width/height)
- **Aspect ratio**: Maintains true GPS track proportions (no distortion)
- **Background**: Semi-transparent black (0.6 opacity)
- **Line**: Blue track with configurable width
- **Position marker**: Red dot with white center, shows current location
- **Dynamic scaling**: Based on image width (800px reference)

### 5. Performance Info Display
- **Chinese labels**: 配速 (pace), 距离 (distance), 心率 (heart rate), 时间 (time)
- **Position**: Bottom of image, full width with margins
- **Format**: 
  - Pace: `min/km` format
  - Distance: `km` format
  - Heart rate: `bpm` format
  - Time: Full timestamp with date and time
- **Background**: Semi-transparent black box
- **Dynamic scaling**: All elements scale proportionally based on image size

### 6. Image Saving
- **Format**: JPG (quality 70) for optimal file size/quality
- **Matching**: Saved image matches UI display exactly
- **Progress indicator**: Shows step-by-step processing status
- **Android/iOS**: Uses `bytes` parameter in `saveFile` API
- **Filename**: `{activityName}_overlay_{timestamp}.jpg`

### 7. Responsive Design
- **Base reference**: 800px image width
- **Scaling formula**: `scaleFactor = currentWidth / 800`
- **Elements scaled**: 
  - Track width
  - Position marker radius
  - Font sizes
  - Padding/margins
  - Background dimensions
- **Test method**: Resize window to simulate mobile screen

## Configuration Parameters

```dart
// Default values (scaled dynamically)
Color _trackColor = Colors.blue;
double _trackWidth = 2.5;              // Track line thickness
Color _positionColor = Colors.red;
double _positionRadius = 6.0;          // Position marker radius
Color _textColor = Colors.white;
double _textSize = 24.0;               // Base text size
```

## UI Components

### Main Screen Layout
- **Top buttons**: Select Image, Select FIT File
- **Secondary buttons**: FIT Info (popup), Time Selection (popup)
- **Input field**: Activity Name (optional)
- **Status indicator**: GPS matched confirmation
- **Main display**: Photo with overlay (InteractiveViewer for zoom/pan)
- **Save button**: Save Image with Overlay

### Popup Dialogs
- **FIT Info Dialog**: Shows activity type, start/end time, duration, distance, GPS points count
- **Time Selection Dialog**: EXIF time display, manual time toggle, manual time picker, current time source indicator

## Platform-Specific Considerations

### Android
- **compileSdk**: 36 (enforced globally for all plugins)
- **Gradle**: 9.4.1 (to avoid download corruption issues)
- **File picker**: `FileType.any` for FIT files (custom extensions not supported)
- **Save file**: Requires `bytes` parameter with Uint8List data
- **Manifest**: Normal Flutter configuration

### Windows
- **File paths**: Absolute paths from file picker
- **EXIF reading**: Works with standard image formats (JPG, PNG)
- **Save file**: Can write directly to returned path
- **Performance**: Generally faster than mobile platforms

### Web
- **NOT SUPPORTED**: fit_parser package incompatible with Web platform (JavaScript integer literal limits)
- **Alternative**: Would need different FIT parsing solution for Web

## Known Issues and Solutions

### 1. FIT File Timestamp Handling
**Issue**: Timestamps may show wrong time due to timezone conversion
**Solution**: Treat FIT timestamps as local time directly (no UTC conversion)
**Code**: `DateTime.fromMillisecondsSinceEpoch(ms, isUtc: false)`

### 2. File Picker on Android
**Issue**: Custom file extensions (`.fit`) not supported
**Solution**: Use `FileType.any` and let FIT parser validate format
**Code**: `FilePicker.platform.pickFiles(type: FileType.any)`

### 3. Gradle Download Corruption
**Issue**: Gradle wrapper zip file may be corrupted on Windows
**Solution**: Use existing Gradle version (9.4.1) instead of downloading new one
**File**: `android/gradle/wrapper/gradle-wrapper.properties`

### 4. Plugin compileSdk Requirements
**Issue**: flutter_plugin_android_lifecycle requires compileSdk 36
**Solution**: Enforce compileSdk 36 globally in `settings.gradle.kts`
**Code**: `gradle.beforeProject { ... compileSdkVersion(36) }`

### 5. Overlay Scaling
**Issue**: Double scaling causes oversized elements in saved images
**Solution**: Let OverlayPainter handle all scaling, don't pre-scale parameters
**Pattern**: Pass base values, painter scales based on `imageSize.width / 800`

### 6. Android/iOS Save Dialog Delay
**Issue**: Save dialog appears after several seconds of processing
**Solution**: Show progress messages for each step (loading, decoding, rendering, encoding)
**UX**: Better user feedback during image processing

## Testing Checklist

### Functional Testing
- [ ] Select image (JPG/PNG)
- [ ] Read EXIF timestamp correctly
- [ ] Select FIT file
- [ ] Parse FIT GPS data correctly
- [ ] Display FIT info in popup
- [ ] Automatic time matching (EXIF → GPS)
- [ ] Manual time selection
- [ ] GPS track displays with correct aspect ratio
- [ ] Position marker shows current location
- [ ] Info box shows Chinese labels correctly
- [ ] Activity name input works
- [ ] Save image with overlay
- [ ] Saved image matches UI display
- [ ] File size reasonable (JPG quality 70)

### Responsive Testing (Windows)
- [ ] Resize window to ~400px width (mobile simulation)
- [ ] All elements scale proportionally
- [ ] Track remains readable
- [ ] Text remains readable
- [ ] Save image at different window sizes (should match UI)

### Platform Testing
- [ ] Windows desktop (primary)
- [ ] Android emulator (secondary)
- [ ] Android real device (if available)
- [ ] iOS requires Mac (not tested on Windows)

## Debug Features

### Console Logging
- EXIF timestamp reading
- FIT file parsing details
- GPS point matching status
- Image size calculations
- Save process steps

### Debug Commands
```bash
flutter run --verbose     # Detailed build logs
flutter doctor -v         # Environment verification
flutter devices           # List available devices
flutter logs              # View runtime logs
```

## Future Enhancements (Optional)

1. **Color customization**: Let user choose track color, text color
2. **Track style options**: Different line styles (solid, dashed)
3. **Multiple activities**: Combine multiple FIT files
4. **Map background**: Add map tiles under GPS track
5. **Heart rate graph**: Visual heart rate zones
6. **Elevation profile**: Add elevation data visualization
7. **Export formats**: PNG, WebP options
8. **Batch processing**: Multiple photos at once
9. **Cloud sync**: Save to cloud storage
10. **Social sharing**: Direct share to social media

## Maintenance Notes

### Dependency Updates
- file_picker has newer versions (11.0.2+) but may have API changes
- Check fit_parser compatibility before upgrading
- Test Android compileSdk compatibility when updating plugins

### Code Style
- No comments in code (as per requirements)
- Follow Flutter conventions
- Use descriptive variable names
- Keep functions focused and modular

### Git Workflow
- Commit after significant changes
- Use descriptive commit messages
- Test before committing
- Document changes in AGENT.md

## Architecture Patterns

### State Management
- StatefulWidget with setState
- Simple and effective for this use case
- No external state management packages needed

### Service Layer
- Separate services for FIT parsing and EXIF reading
- Clean separation of concerns
- Easy to test and maintain

### Widget Composition
- CustomPainter for complex overlay rendering
- Popup dialogs for configuration
- InteractiveViewer for image zoom/pan

## Performance Optimization

### Image Processing
- Load original image once
- Process at original resolution
- Use efficient encoding (JPG quality 70)
- Avoid unnecessary conversions

### GPS Data
- Calculate bounds once
- Reuse scaling factors
- Efficient path drawing

### Memory Management
- Dispose images properly
- Clean up temporary data
- Use Future.delayed for UI updates

## Security Considerations

- No secrets or credentials in code
- Local file access only (no network)
- User chooses all file locations
- No data transmitted externally

## Accessibility

- Chinese labels for local users
- High contrast colors (white on black background)
- Reasonable text sizes (24px base)
- Touch-friendly button sizes

## License and Distribution

- Private project (not published to pub.dev)
- For personal use
- No external distribution planned

## Contact and Support

- Project location: `C:\Users\ligang\activerlay\activity_it`
- Git repository: Local commits ready for push
- Platform: Windows development environment

---

**Last Updated**: 2026-05-15
**Flutter Version**: 3.44.0-1.0.pre-439
**Status**: Active development, Android testing complete