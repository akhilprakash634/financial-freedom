# 🛡️ Financial Freedom — Offline Personal Finance & Debt Management Application

**Financial Freedom** is a private, 100% offline-first personal finance and debt elimination Flutter application built with Dart, Riverpod, Drift (SQLite), and GoRouter.

It provides absolute financial reality by strictly separating **Actual Cash** physically in your bank/wallets from **Money Owed To You** (unpaid salary arrears & freelance receivables) and **Future Expected Income**.

---

## 🌟 Key Financial Principles

### 1. Actual Cash Integrity
- **Single Source of Truth**: Actual Cash is calculated strictly from account opening balances plus recorded ledger transactions (`income`, `expense`, `debt_payment`, `adjustment`).
- **Zero Cash Inflation**: Unpaid salary arrears, pending invoices, and future expected income **never** inflate spendable cash.

### 2. Salary Arrears & Money Owed To You
- **Idempotent Salary Synchronization**: Automatically calculates and tracks monthly salary occurrences from start date. Unpaid past months accumulate as **Salary Arrears** (e.g. ₹75,000 / 3 months pending).
- **Oldest-First & Partial Settlement**: Settle receivables with full or partial payments. Tapping *Mark Received* settles the oldest pending occurrence first and creates an actual income transaction.

### 3. Dual Affordability Metrics
- **Safe To Spend Now**:
  $$\text{Actual Cash} - \text{Mandatory Payments Before Next Confirmed Income} - \text{Planned Expenses} - \text{Buffer}$$
- **Monthly Disposable Amount**:
  $$\text{Actual Cash} + \text{Confirmed Future Income} - \text{Monthly Debt Payments} - \text{Planned Expenses} - \text{Buffer}$$

### 4. Debt Payoff Strategies
- Dynamically sort debts by **Snowball** (lowest balance first) or **Avalanche** (highest interest rate first).
- Calculates exact projected **Debt-Free Dates** and monthly payoff timelines.

### 5. Non-Destructive Account Reconciliation
- Enter your actual real-world bank balance to log an explicit `adjustment` transaction. Historical transaction ledgers remain intact.

---

## 🛠️ Technology Stack

- **Framework**: [Flutter](https://flutter.dev) (Material 3 Adaptive UI)
- **State Management**: [Riverpod](https://riverpod.dev)
- **Local Database**: [Drift](https://drift.simonbinder.eu) (SQLite v2 schema migration engine)
- **Navigation**: [GoRouter](https://pub.dev/packages/go_router)
- **Charts**: [fl_chart](https://pub.dev/packages/fl_chart)
- **Notifications**: [flutter_local_notifications](https://pub.dev/packages/flutter_local_notifications)
- **Formatting**: `intl` currency & date formatting

---

## 📱 App Features & Screens

1. **Financial Command Center (Dashboard)**: Real-time display of Actual Cash, Safe To Spend Now, Money Owed To You, Next Confirmed Income vs Next Expected Income, Financial Reality indicators (🟢/🟡/🔴), and Cash Flow Warning banners.
2. **Debts & Loan Tracker**: Manage EMI loans, credit cards, and personal debts with Avalanche/Snowball strategy toggle and payoff progress bars.
3. **Money Owed To You (Receivables)**: Track salary arrears and freelance receivables with oldest-first settlement and delay workflows.
4. **Cash Flow & Forecast**: 30-day timeline forecast showing running cash projections and lowest projected balance dates.
5. **Unified Transaction Ledger**: Track income, expenses, debt payments, adjustments, and internal transfers between accounts.
6. **Account Reconciliation**: Reconcile real-world bank balances with zero data deletion.
7. **Offline Backup & Privacy**: JSON data backup and CSV transaction export. 100% offline with zero cloud server dependencies.

---

## 🚀 Getting Started & Build Commands

### Prerequisites
- Flutter SDK (`>= 3.0.0`)
- Android SDK (for Android build) / Linux build tools (for Desktop)

### 1. Run Unit Tests
```bash
flutter test
```

### 2. Run Desktop App (Linux)
```bash
flutter run -d linux
```

### 3. Build Release Android APK
```bash
export ANDROID_HOME=$HOME/android-sdk
export PATH="$PATH:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools"
flutter build apk --release
```
Output location: `build/app/outputs/flutter-apk/app-release.apk`

---

## 📄 License
Private Personal Application. All rights reserved.
