/**
 * ============================================================================
 * StockMate Pro - Appium Mobile Capabilities & Configuration
 * File: appium-tests/config/capabilities.js
 * ============================================================================
 */

const path = require('path');

const APPIUM_CONFIG = {
  host: process.env.APPIUM_HOST || '127.0.0.1',
  port: parseInt(process.env.APPIUM_PORT, 10) || 4723,
  path: process.env.APPIUM_PATH || '/',
  logLevel: 'info',
};

// Android Desired Capabilities (UiAutomator2 / Flutter)
const androidCapabilities = {
  platformName: 'Android',
  'appium:automationName': 'UiAutomator2',
  'appium:deviceName': process.env.ANDROID_DEVICE_NAME || 'Pixel_6_Pro_API_34',
  'appium:platformVersion': process.env.ANDROID_PLATFORM_VERSION || '14.0',
  'appium:app': process.env.ANDROID_APP_PATH || path.resolve(__dirname, '../../build/app/outputs/flutter-apk/app-debug.apk'),
  'appium:appPackage': 'com.example.stockmate_pro',
  'appium:appActivity': '.MainActivity',
  'appium:noReset': false,
  'appium:fullReset': false,
  'appium:autoGrantPermissions': true,
  'appium:newCommandTimeout': 300,
  'appium:ignoreHiddenApiPolicyError': true,
  'appium:ensureWebviewsHavePages': true,
  'appium:nativeWebScreenshot': true,
  'appium:connectHardwareKeyboard': true,
};

// iOS Desired Capabilities (XCUITest / Simulator)
const iosCapabilities = {
  platformName: 'iOS',
  'appium:automationName': 'XCUITest',
  'appium:deviceName': process.env.IOS_DEVICE_NAME || 'iPhone 15 Pro',
  'appium:platformVersion': process.env.IOS_PLATFORM_VERSION || '17.2',
  'appium:app': process.env.IOS_APP_PATH || path.resolve(__dirname, '../../build/ios/iphonesimulator/Runner.app'),
  'appium:bundleId': 'com.example.stockmatePro',
  'appium:noReset': false,
  'appium:autoAcceptAlerts': true,
  'appium:newCommandTimeout': 300,
};

module.exports = {
  APPIUM_CONFIG,
  androidCapabilities,
  iosCapabilities,
};
