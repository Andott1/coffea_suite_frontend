# Coffea Suite (Tablet POS)

![Flutter](https://img.shields.io/badge/Flutter-3.32%2B-blue?logo=flutter)
![Dart](https://img.shields.io/badge/Dart-3.8%2B-blue?logo=dart)
![Hive](https://img.shields.io/badge/Hive-Local%20Storage-yellow)
![Supabase](https://img.shields.io/badge/Supabase-Cloud%20Sync-green)
![License](https://img.shields.io/badge/License-MIT-green)
![Status](https://img.shields.io/badge/Version-1.3.1-brightgreen)

**Coffea Suite** is a comprehensive, offline-first Point of Sale and Resource Management system tailored for the food and beverage industry. Built with **Flutter** and **Supabase**, it delivers professional-grade reliability for managing sales, inventory, and staff attendance without relying on continuous internet connectivity.

## 🚀 Core Features

### 🛒 Smart Point of Sale
- **Dynamic Cashier:** Visual grid with category filtering (Drinks, Meals, Desserts) and real-time search.
- **Recipe Engine:** Automatically deducts inventory ingredients based on product recipes (e.g., *1 Latte = 30ml Espresso + 150ml Milk*).
- **Order Queue (Kanban):** Drag-and-drop status board for kitchen/bar coordination (Pending → Preparing → Ready → Served).
- **Payment Processing:** Support for Cash (with change calculation), Card, and E-Wallet with reference tracking.

### 📦 Inventory Control
- **Granular Tracking:** Supports unit conversions (e.g., Purchase in **Liters**, Usage in **Milliliters**).
- **Audit Trails:** Logs every stock movement (Restock, Waste, Sale, Correction) with user attribution.
- **Stock Alerts:** Visual indicators for Low Stock and Out-of-Stock items.
- **Local Backups:** Export logs to CSV and create local JSON snapshots of inventory data.

### 👥 Workforce Management
- **Biometric-Ready Clock:** Time clock with **Camera Photo Verification** to prevent "buddy punching."
- **Payroll Calculator:** Automated computation of gross/net pay based on hourly rates and custom adjustments.
- **Role-Based Access:** Granular permissions for Admins (Full Access), Managers (Edit Logs), and Staff (POS Only).

### 📊 Admin & Analytics
- **Live Dashboard:** Real-time sales metrics, top-selling products, and attendance monitoring.
- **Employee Management:** Create users, assign roles, and manage secure PIN access.
- **Data Seeding:** Automated bootstrapping of Products and Ingredients from JSON assets on first install.

---

## 🛠️ Tech Stack

| Component | Technology | Purpose |
| :--- | :--- | :--- |
| **Framework** | Flutter (Dart) | Tablet-optimized UI |
| **State Management** | `flutter_bloc` | Predictable state & business logic |
| **Local DB** | `Hive` (NoSQL) | Offline capability & high-performance reads |
| **Backend** | `Supabase` | PostgreSQL, Auth, and Realtime Sync |
| **Observability** | `Talker` | Centralized logging for errors, navigation, and state changes |
| **Hardware** | `camera` | Employee verification |

---

## 📂 Project Structure

The project follows a **Feature-First** directory structure with a shared core layer.

```text
lib/
├── config/            # Design tokens (ThemeConfig, FontConfig)
├── core/
│   ├── bloc/          # Global App State (Auth, Connectivity)
│   ├── models/        # Hive Adapters & Data Models
│   ├── services/      # Singletons (Sync, Logger, Hardware)
│   └── widgets/       # Atomic UI Components
├── screens/
│   ├── startup/       # Splash, Login, & Data Seeding
│   ├── pos/           # Cashier, Payment, & Order Queue
│   ├── inventory/     # Stock, Recipes, & Adjustments
│   ├── attendance/    # Time Clock & Payroll
│   └── admin/         # Dashboard & User Management
└── scripts/           # JSON parsers for DB seeding
````

-----

## ⚙️ Installation & Setup

### Prerequisites

  - Flutter SDK `3.32` or higher
  - Dart SDK `3.8`

### Deployment Steps

1.  **Clone the Repository:**

    ```bash
    git clone [https://github.com/yourusername/coffea-suite.git](https://github.com/yourusername/coffea-suite.git)
    cd coffea-suite
    ```

2.  **Install Dependencies:**

    ```bash
    flutter pub get
    ```

3.  **Run Code Generation:**
    *Required for Hive TypeAdapters.*

    ```bash
    dart run build_runner build --delete-conflicting-outputs
    ```

4.  **Launch the App:**

    ```bash
    flutter run --dart-define=SUPABASE_URL=[HIDDEN URL] --dart-define=SUPABASE_ANON_KEY=[HIDDEN KEY]
    ```

### Initial Device Setup

On the first launch, the application will:

1.  **Detect** an empty local database.
2.  **Seed Data:** Import default Products and Ingredients from `assets/data/`.
3.  **Admin Setup:** Redirect to `InitialSetupScreen` to create the first Owner/Admin account if no users exist.

-----

## 🔄 Synchronization Logic

The app uses a robust **Offline-First** architecture:

1.  **Local Writes:** All actions (Sales, Stock Updates, Attendance) are written immediately to **Hive**.
2.  **Sync Queue:** A `SyncQueueModel` entry is created for every mutation.
3.  **Background Sync:** `SupabaseSyncService` monitors connectivity. When online, it processes the queue and pushes changes to the cloud.
4.  **Manual Control:** Admins can trigger a "Force Push" or "Restore from Cloud" via the Settings screen or "Force Pull" via the topbar.

-----

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](https://www.google.com/search?q=LICENSE) file for details.
