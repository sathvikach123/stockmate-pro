/**
 * ============================================================================
 * StockMate Pro - Mobile Appium Auth Page Object
 * File: appium-tests/pages/AuthPage.js
 * ============================================================================
 */

const BasePage = require('./BasePage');

class AuthPage extends BasePage {
  constructor(driver) {
    super(driver);
  }

  // Locators (supports Accessibility ID / Content-Desc / XPath for Flutter Mobile)
  get locators() {
    return {
      // Login Screen UI
      logo: '~SM',
      welcomeHeader: '//android.widget.TextView[@text="Welcome back!"] | ~Welcome back!',
      subtitle: '//android.widget.TextView[contains(@text, "Sign in to manage")]',
      emailInput: '//android.widget.EditText[contains(@text, "Email") or @content-desc="Email Address"] | ~Email Address',
      passwordInput: '//android.widget.EditText[contains(@text, "Password") or @content-desc="Password"] | ~Password',
      signInBtn: '//android.widget.Button[@text="Sign In"] | ~Sign In',
      signUpLink: '//android.widget.TextView[@text="Sign Up"] | ~Sign Up',
      visibilityToggle: '//android.widget.ImageView[contains(@content-desc, "visibility")] | ~Toggle visibility',
      
      // Error & Snackbar alerts
      snackBar: '//android.widget.TextView[contains(@resource-id, "snackbar") or contains(@text, "Invalid")] | ~Snackbar',
      emailError: '//android.widget.TextView[@text="Enter valid email"] | ~Enter valid email',
      passwordError: '//android.widget.TextView[@text="Min 6 characters"] | ~Min 6 characters',
      
      // Signup Screen UI
      signupTitle: '//android.widget.TextView[@text="Create Account"] | ~Create Account',
      fullNameInput: '//android.widget.EditText[contains(@text, "Full Name")] | ~Full Name',
      storeNameInput: '//android.widget.EditText[contains(@text, "Store Name")] | ~Store Name',
      signupEmailInput: '//android.widget.EditText[contains(@text, "Email Address")] | ~Email Address',
      signupPassInput: '//android.widget.EditText[contains(@text, "Password")] | ~Password',
      confirmPassInput: '//android.widget.EditText[contains(@text, "Confirm Password")] | ~Confirm Password',
      createAccountBtn: '//android.widget.Button[@text="Create Account"] | ~Create Account',
      backToLoginBtn: '//android.widget.Button[contains(@content-desc, "Back")] | ~Back',
      
      // Post-Login Destination
      dashboardBottomNav: '//android.view.View[contains(@content-desc, "Dashboard")] | ~Dashboard',
      productsBottomNav: '//android.view.View[contains(@content-desc, "Products")] | ~Products',
      alertsBottomNav: '//android.view.View[contains(@content-desc, "Alerts")] | ~Alerts',
      salesBottomNav: '//android.view.View[contains(@content-desc, "Sales")] | ~Sales',
      accountBottomNav: '//android.view.View[contains(@content-desc, "Account")] | ~Account',
    };
  }

  async login(email, password) {
    await this.typeText(this.locators.emailInput, email);
    await this.typeText(this.locators.passwordInput, password);
    await this.hideKeyboard();
    await this.click(this.locators.signInBtn);
  }

  async navigateToSignup() {
    await this.click(this.locators.signUpLink);
    await this.waitForElement(this.locators.signupTitle);
  }

  async registerStore(name, store, email, password, confirmPassword) {
    await this.typeText(this.locators.fullNameInput, name);
    await this.typeText(this.locators.storeNameInput, store);
    await this.typeText(this.locators.signupEmailInput, email);
    await this.typeText(this.locators.signupPassInput, password);
    await this.typeText(this.locators.confirmPassInput, confirmPassword);
    await this.hideKeyboard();
    await this.click(this.locators.createAccountBtn);
  }

  async isDashboardLoaded() {
    return await this.isElementVisible(this.locators.dashboardBottomNav);
  }

  async getSnackbarText() {
    return await this.getText(this.locators.snackBar);
  }
}

module.exports = AuthPage;
