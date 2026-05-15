import 'package:flutter/material.dart';

class ResponsiveHelper {
  static bool isSmallScreen(BuildContext context) {
    return MediaQuery.of(context).size.width < 600;
  }
  
  static bool isMediumScreen(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= 600 && width < 900;
  }
  
  static bool isLargeScreen(BuildContext context) {
    return MediaQuery.of(context).size.width >= 900;
  }
  
  // Responsive padding
  static double getPadding(BuildContext context) {
    if (isSmallScreen(context)) return 8.0;
    if (isMediumScreen(context)) return 12.0;
    return 16.0;
  }
  
  // Responsive spacing
  static double getSpacing(BuildContext context) {
    if (isSmallScreen(context)) return 8.0;
    if (isMediumScreen(context)) return 12.0;
    return 16.0;
  }
  
  // Responsive font size
  static double getFontSize(BuildContext context, double baseSize) {
    if (isSmallScreen(context)) return baseSize * 0.85;
    if (isMediumScreen(context)) return baseSize * 0.95;
    return baseSize;
  }
  
  // Responsive button padding
  static EdgeInsets getButtonPadding(BuildContext context) {
    if (isSmallScreen(context)) {
      return const EdgeInsets.symmetric(horizontal: 12, vertical: 8);
    }
    return const EdgeInsets.symmetric(horizontal: 24, vertical: 12);
  }
  
  // Responsive container padding
  static EdgeInsets getContainerPadding(BuildContext context) {
    final padding = getPadding(context);
    return EdgeInsets.all(padding);
  }
  
  // Responsive image display height
  static double getImageHeight(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    if (isSmallScreen(context)) {
      return screenHeight * 0.35; // 35% of screen height
    }
    if (isMediumScreen(context)) {
      return screenHeight * 0.45; // 45% of screen height
    }
    return 400.0; // Fixed 400px for large screens
  }
  
  // Responsive text field font size
  static double getTextFieldFontSize(BuildContext context) {
    if (isSmallScreen(context)) return 14.0;
    return 16.0;
  }
  
  // Responsive info box font size
  static double getInfoFontSize(BuildContext context) {
    if (isSmallScreen(context)) return 12.0;
    if (isMediumScreen(context)) return 13.0;
    return 14.0;
  }
  
  // Responsive overlay text size
  static double getOverlayTextSize(BuildContext context) {
    if (isSmallScreen(context)) return 10.0;
    if (isMediumScreen(context)) return 12.0;
    return 14.0;
  }
  
  // Responsive overlay padding
  static double getOverlayPadding(BuildContext context) {
    if (isSmallScreen(context)) return 10.0;
    if (isMediumScreen(context)) return 15.0;
    return 20.0;
  }
}