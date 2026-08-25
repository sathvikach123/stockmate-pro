/**
 * ============================================================================
 * StockMate Pro - Appium Base Page & Helper Utilities
 * File: appium-tests/pages/BasePage.js
 * ============================================================================
 */

class BasePage {
  constructor(driver) {
    this.driver = driver;
  }

  async waitForElement(selector, timeoutMs = 15000) {
    const el = await this.driver.$(selector);
    await el.waitForDisplayed({ timeout: timeoutMs });
    return el;
  }

  async click(selector, timeoutMs = 15000) {
    const el = await this.waitForElement(selector, timeoutMs);
    await el.click();
  }

  async typeText(selector, text, clearFirst = true) {
    const el = await this.waitForElement(selector);
    if (clearFirst) {
      await el.clearValue();
    }
    await el.setValue(text);
  }

  async getText(selector) {
    const el = await this.waitForElement(selector);
    return await el.getText();
  }

  async isElementVisible(selector) {
    try {
      const el = await this.driver.$(selector);
      return await el.isDisplayed();
    } catch (err) {
      return false;
    }
  }

  // Mobile Gestures: Swipe Up / Scroll Down
  async swipeUp(distanceFraction = 0.5) {
    const { width, height } = await this.driver.getWindowRect();
    const startX = width / 2;
    const startY = height * 0.75;
    const endY = height * (0.75 - distanceFraction);

    await this.driver.performActions([
      {
        type: 'pointer',
        id: 'finger1',
        parameters: { pointerType: 'touch' },
        actions: [
          { type: 'pointerMove', duration: 0, x: startX, y: startY },
          { type: 'pointerDown', button: 0 },
          { type: 'pause', duration: 100 },
          { type: 'pointerMove', duration: 600, x: startX, y: endY },
          { type: 'pointerUp', button: 0 },
        ],
      },
    ]);
    await this.driver.pause(500);
  }

  // Mobile Gestures: Pull-to-Refresh
  async pullToRefresh() {
    const { width, height } = await this.driver.getWindowRect();
    const startX = width / 2;
    const startY = height * 0.25;
    const endY = height * 0.75;

    await this.driver.performActions([
      {
        type: 'pointer',
        id: 'finger1',
        parameters: { pointerType: 'touch' },
        actions: [
          { type: 'pointerMove', duration: 0, x: startX, y: startY },
          { type: 'pointerDown', button: 0 },
          { type: 'pause', duration: 200 },
          { type: 'pointerMove', duration: 800, x: startX, y: endY },
          { type: 'pointerUp', button: 0 },
        ],
      },
    ]);
    await this.driver.pause(1000);
  }

  // Device Actions: Hide Keyboard
  async hideKeyboard() {
    try {
      if (await this.driver.isKeyboardShown()) {
        await this.driver.hideKeyboard();
      }
    } catch (err) {
      // Ignored if keyboard not active
    }
  }

  // Device Actions: Background App
  async backgroundApp(seconds = 3) {
    await this.driver.background(seconds);
  }

  // Screenshot capture
  async captureScreenshot(name) {
    const timestamp = Date.now();
    const filePath = `./reports/screenshots/${name}_${timestamp}.png`;
    await this.driver.saveScreenshot(filePath);
    return filePath;
  }
}

module.exports = BasePage;
