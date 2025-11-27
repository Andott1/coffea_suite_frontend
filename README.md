# Coffea Suite (Tablet Version)

**Coffea Suite** is a comprehensive, tablet-first Point of Sale (POS) and management system designed for coffee shops and restaurants. Built with **Flutter**, it features an offline-first architecture using **Hive** for local storage and **Supabase** for cloud synchronization.

## 🚀 Key Features

### 🛒 Point of Sale (POS)

- **Cashier Interface:** Visual product grid with category/sub-category filtering (`CashierScreen`).
- **Dynamic Product Builder:** Handle product variants (sizes, sugar levels) and real-time stock availability checks (`ProductBuilderDialog`).
- **Order Queue (Kanban):** Drag-and-drop or status-based workflow for Pending, Preparing, Ready, and Served orders.
- **Payment Processing:** Support for Cash (with change calculation), Card, and E-Wallet payments (`PaymentScreen`).
- **Transaction History:** View past orders, reprint receipts, and void transactions (`TransactionHistoryScreen`).

### 📦 Inventory Management

- **Ingredient Tracking:** Monitor stock levels with visual status indicators (Good, Low, Critical).
- **Recipe Matrix:** Link products to ingredients (e.g., "Latte" uses "Milk" + "Coffee Beans") for automatic stock deduction upon sale (`StockLogic`).
- **Stock Adjustments:** Handle restocks, wastage, and corrections with unit conversion support (e.g., input in Liters, store in mL).
- **Audit Logs:** Track every stock movement with reasons and user attribution (`InventoryLogsTab`).

### 🕒 Attendance & Payroll

- **Time Clock:** Employee Clock In/Out with **Photo Proof** verification (`TimeClockScreen`).
- **Smart Status:** Auto-detects breaks and shift completion.
- **Payroll Calculator:** Generate payroll reports based on hourly rates, total hours worked, and custom adjustments (bonuses/deductions) (`PayrollScreen`).
- **Manager Verification:** Admins can approve or reject attendance logs based on photo evidence.

### 🛡️ Admin & Analytics

- **Dashboard:** Real-time sales metrics, top-selling products, and inventory health alerts (`AdminDashboardScreen`).
- **Employee Management:** Manage users, roles (Admin, Manager, Employee), and secure PIN access.
- **Cloud Sync Control:** Manual force-push and restore capabilities for data synchronization (`SupabaseSyncService`).
- **Local Backups:** Export logs to CSV and create local JSON snapshots of critical data.

---

## 🛠️ Tech Stack

- **Framework:** [Flutter](https://flutter.dev/) (Tablet Optimized)
- **Language:** Dart
- **State Management:** [flutter_bloc](https://pub.dev/packages/flutter_bloc) (BLoC & Cubit patterns)
- **Local Database:** [Hive](https://docs.hivedb.dev/) (NoSQL, fast key-value storage)
- **Cloud Backend:** [Supabase](https://supabase.com/) (PostgreSQL, Realtime, Storage)
- **Architecture:** Feature-first directory structure with separated Core services.

---

## 📂 Project Structure

The project follows a modular structure organized by feature (`screens`) and shared resources (`core`).

```text
lib/
├── config/             # Theme, Fonts, and UI Constants
├── core/
│   ├── bloc/           # Global BLoCs (Auth, Connectivity)
│   ├── models/         # Hive Types & Data Models
│   ├── services/       # Hive, Supabase, Logger, Backup services
│   ├── utils/          # Formatting, Hashing, Responsive helpers
│   └── widgets/        # Reusable UI components (Buttons, Cards, Dialogs)
├── screens/
│   ├── admin/          # Admin Dashboard & Management
│   ├── attendance/     # Time Clock & Payroll
│   ├── inventory/      # Stock List & Logs
│   ├── pos/            # Cashier & Transaction handling
│   └── startup/        # Initial Setup & Splash
└── scripts/            # Data seeding scripts
````

---

## ⚙️ Setup & Installation

1. **Prerequisites:**

      - Flutter SDK (Latest Stable)
      - Dart SDK

2. **Clone the repository:**

    ```bash
    git clone [https://github.com/yourusername/coffea-suite.git](https://github.com/yourusername/coffea-suite.git)
    cd coffea-suite
    ```

3. **Install Dependencies:**

    ```bash
    flutter pub get
    ```

4. **Code Generation (for Hive Adapters):**
    If you modify models, run the build runner:

    ```bash
    flutter pub run build_runner build --delete-conflicting-outputs
    ```

5. **Run the App:**

    ```bash
    flutter run
    ```

---

## 🔄 Synchronization Logic

The app uses an **Offline-First** approach.

1. **Local Writes:** All actions (Sales, Stock Updates, Attendance) are written immediately to **Hive**.
2. **Sync Queue:** Operations are added to a local `SyncQueueModel`.
3. **Background Sync:** `SupabaseSyncService` monitors connectivity and flushes the queue to the cloud when online.
4. **Conflict Resolution:** The system uses UUIDs for all records to prevent collision between offline devices.

---

## 🔐 Credentials & Security

- **Default Admin Setup:** On the first launch, the app prompts to create an Owner/Admin account if the local database is empty.
- **PIN Security:** Sensitive actions (Voiding orders, Manager verification) require elevated permissions via PIN or Password.
- **Data Privacy:** Passwords and PINs are hashed using **BCrypt** before storage.

---

## 📝 License

This project is proprietary software. Unauthorized copying or distribution is strictly prohibited.
