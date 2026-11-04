/// All user-facing text lives here so Urdu/English localization can be added
/// later (swap this for ARB files / gen-l10n) without touching widgets.
class AppStrings {
  AppStrings._();

  static const appName = 'Kabari App';
  static const tagline = 'Apni dukaan ka hisaab, asaan';

  // Onboarding
  static const skip = 'Skip';
  static const next = 'Next';
  static const getStarted = 'Get Started';
  static const onb1Title = 'Daily purchases, quickly';
  static const onb1Body = 'Record what you bought today in a few taps.';
  static const onb2Title = 'Works without internet';
  static const onb2Body = 'Save entries offline. They sync automatically when internet is back.';
  static const onb3Title = 'Stock and totals';
  static const onb3Body = 'See current stock by material and your weekly and monthly totals.';

  // Auth
  static const login = 'Login';
  static const register = 'Create account';
  static const logout = 'Logout';
  static const email = 'Email';
  static const password = 'Password';
  static const confirmPassword = 'Confirm password';
  static const ownerName = 'Owner name';
  static const shopName = 'Shop name';
  static const forgotPassword = 'Forgot password?';
  static const sendResetLink = 'Send reset link';
  static const resetLinkSent = 'Reset link sent. Check your email.';
  static const noAccount = "Don't have an account? Register";
  static const haveAccount = 'Already have an account? Login';

  // Validation
  static const fieldRequired = 'This field is required';
  static const emailInvalid = 'Enter a valid email';
  static const passwordShort = 'Password must be at least 6 characters';
  static const passwordMismatch = 'Passwords do not match';

  // Errors
  static const errNetwork = 'Internet is required for login and registration the first time. Please connect and try again.';
  static const errWrongCredentials = 'Incorrect email or password.';
  static const errEmailInUse = 'This email is already registered.';
  static const errWeakPassword = 'Password is too weak. Use at least 6 characters.';
  static const errTooMany = 'Too many attempts. Please wait a few minutes and try again.';
  static const errUserDisabled = 'This account has been disabled.';
  static const errGeneric = 'Something went wrong. Please try again.';

  // Blocked states
  static const disabledTitle = 'Account disabled';
  static const disabledBody = 'Your account is not active. Please contact support.';
  static const profileMissingTitle = 'Account setup incomplete';
  static const profileMissingBody = 'We could not load your shop profile. Please check your internet and sign in again.';

  // Inventory / purchases
  static const save = 'Save';
  static const cancel = 'Cancel';
  static const today = 'Today';
  static const materials = 'Materials';
  static const addMaterial = 'Add material';
  static const editMaterial = 'Edit material';
  static const materialName = 'Material name';
  static const ratePerKg = 'Rate per kg (Rs)';
  static const rateNotSet = 'Rate not set';
  static const noMaterialsYet = 'No materials yet. Add the materials you buy.';
  static const addCommonMaterials = 'Add common materials';
  static const addPurchase = 'Add purchase';
  static const selectMaterial = 'Select material';
  static const materialRequired = 'Please select a material';
  static const weightKg = 'Weight (kg)';
  static const sellerOptional = 'Seller name (optional)';
  static const total = 'Total';
  static const purchasesToday = "Today's purchases";
  static const noPurchasesToday = 'No purchases yet today.';
  static const stock = 'Stock';
  static const totalStock = 'Total in shop';
  static const noStockYet = 'No stock yet. Add a purchase first.';
  static const addMaterialsFirst = 'Add your materials first, then you can record purchases.';
  static const entries = 'entries';
  static const voidPurchase = 'Cancel this purchase?';
  static const voidBody = 'It will be removed from today\'s total and stock. This cannot be undone.';
  static const voidAction = 'Cancel purchase';
  static const keep = 'Keep';
  static const waitingToSync = 'Waiting for internet to sync';
  static const synced = 'Synced';
  static const invalidNumber = 'Enter a valid number';

  // Purchase slip
  static const newSlip = 'New purchase slip';
  static const slipItems = 'Items on this slip';
  static const noItemsYet = 'No items yet. Add the first item below.';
  static const addItem = 'Add item to slip';
  static const saveSlip = 'Save slip';
  static const slipTotal = 'Slip total';
  static const scaleWeight = 'Weight on scale (kg)';
  static const tapAddItemFirst = 'Tap "Add item to slip" first, or clear the weight.';
  static const perKg = 'Per kg';
  static const perPakaSeer = 'Per paka seer';
  static const ratePerPakaSeer = 'Rate per paka seer (Rs)';
  static const rateIs = 'Rate is';
  static const fixedRates = 'Fixed rates (set one or both)';
  static const defaultUnit = 'Default unit on slip';
  static const priceBy = 'Price by';
  static const rateNotSetShort = 'not set';
  static const kachaToPaka = 'Scale weight is converted: 1 paka seer = 1.25 kg';
  static const slip = 'Purchase slip';
  static const items = 'items';
  static const seller = 'Seller';
  static const close = 'Close';

  // History
  static const history = 'History';
  static const periodDay = 'Day';
  static const periodWeek = 'Week';
  static const periodMonth = 'Month';
  static const allMaterials = 'All materials';
  static const byMaterial = 'By material';
  static const byDay = 'By day';
  static const slipsOfDay = 'Slips';
  static const nothingInPeriod = 'No purchases in this period.';
  static const previous = 'Previous';
}
