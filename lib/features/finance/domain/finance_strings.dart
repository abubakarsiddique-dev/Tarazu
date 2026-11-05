// Kept here so this feature is a pure copy-paste (same approach as ReportStrings).
class FinanceStrings {
  FinanceStrings._();

  // shared
  static const day = 'Day';
  static const week = 'Week';
  static const month = 'Month';
  static const previous = 'Previous';
  static const next = 'Next';
  static const error = 'Something went wrong. Please try again.';

  // profit
  static const profit = 'Profit';
  static const sales = 'Sales';
  static const costOfSold = 'Cost of sold stock';
  static const grossProfit = 'Profit before expenses';
  static const expenses = 'Expenses';
  static const stockLoss = 'Stock loss / shortage';
  static const netProfit = 'Net profit';
  static const byMaterial = 'Profit by material';
  static const sold = 'Sold';
  static const cost = 'Cost';
  static const margin = 'margin';
  static const perKg = 'per kg';
  static const stockCostNow = 'Money tied up in stock now (at cost)';
  static const nothing = 'No sales or losses in this period.';
  static const estimateNote =
      'Estimated. Cost uses the average buying rate of each material. '
      'Stock you have not sold yet is not counted as a cost.';
  static String noCostWarning(String kg) =>
      '$kg were sold with no buying record, so their cost is counted as 0 and '
      'profit may look too high. Enter opening stock as a purchase slip.';

  // expenses
  static const expensesTitle = 'Expenses';
  static const addExpense = 'Add expense';
  static const amount = 'Amount (Rs)';
  static const category = 'Category';
  static const noteOptional = 'Note (optional)';
  static const save = 'Save';
  static const keep = 'Keep';
  static const cancelExpense = 'Cancel this expense?';
  static const cancelExpenseBody =
      'It will be removed from the totals. A record is kept.';
  static const cancelAction = 'Cancel expense';
  static const noExpenses = 'No expenses in this period.';
  static const amountInvalid = 'Enter an amount greater than 0';
  static const total = 'Total';
}
