enum AccountType {
  bank,
  cash,
  savings,
  other,
}

enum IncomeStatus {
  expected,
  confirmed,
  due,
  overdue,
  delayed,
  received,
  cancelled,
}

enum IncomeConfidence {
  high,
  medium,
  low,
}

enum RecurrenceFrequency {
  daily,
  weekly,
  monthly,
  yearly,
  custom,
}

enum TransactionType {
  income,
  expense,
  debtPayment,
  transfer,
  adjustment,
}

enum TransactionCategoryType {
  income,
  expense,
  both,
}

enum DebtType {
  emiLoan,
  personalDebt,
  creditCard,
  bnpl,
  familyFriend,
  other,
}

enum DebtStatus {
  active,
  settled,
}

enum DebtStrategy {
  snowball,
  avalanche,
}

enum PaymentStatus {
  upcoming,
  due,
  paid,
  overdue,
  cancelled,
}

enum PaymentType {
  normalEmi,
  minimumPayment,
  extraPayment,
  partialSettlement,
  fullSettlement,
}
