import 'package:flutter/material.dart';

class ResponsiveHelper {
  ResponsiveHelper._();

  static const double smallMobileBreakpoint = 380;
  static const double mobileBreakpoint = 600;

  static double screenWidth(BuildContext context) {
    return MediaQuery.of(context).size.width;
  }

  static double screenHeight(BuildContext context) {
    return MediaQuery.of(context).size.height;
  }

  static bool isSmallMobile(BuildContext context) {
    return screenWidth(context) < smallMobileBreakpoint;
  }

  static bool isMobile(BuildContext context) {
    return screenWidth(context) < mobileBreakpoint;
  }

  static bool isTablet(BuildContext context) {
    return screenWidth(context) >= mobileBreakpoint;
  }

  static bool isLandscape(BuildContext context) {
    return MediaQuery.of(context).orientation == Orientation.landscape;
  }

  static bool isPortrait(BuildContext context) {
    return MediaQuery.of(context).orientation == Orientation.portrait;
  }

  static DeviceType getDeviceType(BuildContext context) {
    if (isSmallMobile(context)) return DeviceType.smallMobile;
    if (isMobile(context)) return DeviceType.mobile;
    return DeviceType.tablet;
  }

  static T responsive<T>(
    BuildContext context, {
    required T mobile,
    T? tablet,
    T? smallMobile,
  }) {
    if (isTablet(context)) return tablet ?? mobile;
    if (isSmallMobile(context)) return smallMobile ?? mobile;
    return mobile;
  }

  static double fontSize(
    BuildContext context, {
    required double mobile,
    double? tablet,
    double? smallMobile,
  }) {
    return responsive<double>(
      context,
      mobile: mobile,
      tablet: tablet ?? mobile * 1.1,
      smallMobile: smallMobile ?? mobile * 0.9,
    );
  }

  static EdgeInsets padding(
    BuildContext context, {
    required EdgeInsets mobile,
    EdgeInsets? tablet,
    EdgeInsets? smallMobile,
  }) {
    return responsive<EdgeInsets>(
      context,
      mobile: mobile,
      tablet: tablet ?? mobile * 1.2,
      smallMobile: smallMobile ?? mobile * 0.8,
    );
  }

  static double widthPercent(BuildContext context, double percent) {
    return screenWidth(context) * (percent / 100);
  }

  static double heightPercent(BuildContext context, double percent) {
    return screenHeight(context) * (percent / 100);
  }

  static double responsiveSize(BuildContext context, double baseSize) {
    final shortestSide = MediaQuery.of(context).size.shortestSide;
    final scaleFactor = shortestSide / 375;
    return baseSize * scaleFactor;
  }

  static int getGridColumnCount(
    BuildContext context, {
    int mobile = 2,
    int tablet = 3,
    int smallMobile = 1,
  }) {
    return responsive<int>(
      context,
      mobile: mobile,
      tablet: tablet,
      smallMobile: smallMobile,
    );
  }
}

enum DeviceType { smallMobile, mobile, tablet }

extension ResponsiveExtension on BuildContext {
  bool get isSmallMobile => ResponsiveHelper.isSmallMobile(this);
  bool get isMobile => ResponsiveHelper.isMobile(this);
  bool get isTablet => ResponsiveHelper.isTablet(this);
  DeviceType get deviceType => ResponsiveHelper.getDeviceType(this);
  double get screenWidth => ResponsiveHelper.screenWidth(this);
  double get screenHeight => ResponsiveHelper.screenHeight(this);
  bool get isLandscape => ResponsiveHelper.isLandscape(this);
  bool get isPortrait => ResponsiveHelper.isPortrait(this);
}
