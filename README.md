# ☕ COFFEA POS Suite

## A Modular Point-of-Sale and Business Management System for Coffea

![Flutter](https://img.shields.io/badge/Flutter-3.19%2B-blue?logo=flutter)
![Hive](https://img.shields.io/badge/Hive-Local%20Storage-yellow)
![License](https://img.shields.io/badge/License-MIT-green)
![Status](https://img.shields.io/badge/Version-1.0.1-brightgreen)

---

## 📖 Overview

**COFFEA POS** is an integrated café management suite built with **Flutter** and **Hive**. It unifies **Point of Sale**, **Inventory**, **Attendance**, and **Admin Tools** into a single responsive application optimized for tablet and desktop screens.

### 🎯 Key Objectives

* Provide a unified POS ecosystem with **role-based access** (Admin/Employee)
* Enable **offline-first** data storage using Hive
* Simplify **inventory updates** through ingredient usage tracking
* Maintain modularity for **future BLoC state management integration**

---

## 🧩 Project Structure

```plaintext
assets/
├── data/
│   ├── ingredients_list.json
│   ├── ingredients_usage.json
│   └── products_list.json
├── fonts/
├── icons/
└── logo/
    └── coffea.png

lib/
├── config/              # Global configuration (theme, fonts, roles)
├── core/                # Models, services, utils, widgets
├── screens/             # UI modules (POS, Inventory, Attendance, Admin)
├── scripts/             # Hive seeding scripts
└── main.dart            # Entry point
```

---

## 🚀 Core Features

### 💰 Point of Sale

* Intuitive cashier interface with dynamic product grid
* Supports **multi-size** and **variant-based** pricing
* Designed for **offline and online** operation

### 📦 Inventory Management

* Tracks stock levels via `IngredientUsageModel`
* Auto-seeds initial data from JSON sources
* Unit conversion-ready (e.g., `kg → g`, `L → mL`)

### ⏱️ Attendance & Payroll

* Time-in/time-out with employee cards
* Placeholder modules for upcoming payroll automation

### 🛠️ Admin Tools

* Access to analytics, product, and employee management
* Restricted by **Admin Role Only** via reactive role switching

---

## 🗄️ Local Storage Schema (Hive)

| Box Name            | Model                  | Stored Data                        |
| ------------------- | ---------------------- | ---------------------------------- |
| `ingredients`       | `IngredientModel`      | Ingredient stock and metadata      |
| `products`          | `ProductModel`         | Café menu items and pricing        |
| `ingredient_usages` | `IngredientUsageModel` | Ingredient consumption per product |

Data is auto-seeded on the first run via `HiveService.init()`.

---

## 🧠 Architecture Overview

### Clean Modular Structure

```plaintext
lib/
├── config/        → Global app settings
├── core/
│   ├── models/    → Data layer (Hive models)
│   ├── providers/ → Lightweight reactive state
│   ├── services/  → Business logic & data sync
│   ├── utils/     → Helper functions
│   └── widgets/   → Shared UI components
├── screens/       → UI modules per system
└── scripts/       → Hive data seeding
```

### Module Interconnection

| Module     | Dependencies                       | Description                    |
| ---------- | ---------------------------------- | ------------------------------ |
| POS        | ProductModel, IngredientUsageModel | Order creation, sales tracking |
| Inventory  | IngredientModel, ProductModel      | Stock management, analytics    |
| Attendance | EmployeeModel, AttendanceModel     | Employee time tracking         |
| Admin      | All Modules                        | Analytics, configuration       |

---

## ⚙️ Initialization & Seeding

### Workflow

```plaintext
main.dart
└──> HiveService.init()
      ├── Registers Hive adapters
      ├── Opens Hive boxes
      ├── Seeds data from /assets/data if empty
```

### Scripts

| Script                        | Source                               | Description                       |
| ----------------------------- | ------------------------------------ | --------------------------------- |
| `seed_ingredients.dart`       | `assets/data/ingredients_list.json`  | Seeds all ingredients             |
| `seed_products.dart`          | `assets/data/products_list.json`     | Seeds products & pricing          |
| `seed_ingredients_usage.dart` | `assets/data/ingredients_usage.json` | Maps ingredient usage per product |

---

## 🧰 Tech Stack

| Layer                 | Technology            |
| --------------------- | --------------------- |
| **Frontend**          | Flutter 3.32+         |
| **Database**          | Hive (Offline-first)  |
| **Networking**        | Dio (API-ready)       |
| **State**             | Provider (BLoC-ready) |
| **Backend (Planned)** | Supabase              |

---

## 🧾 Versioning

| File              | Version | Description                |
| ----------------- | ------- | -------------------------- |
| `data_master.txt` | 1.0.1   | Central dataset reference  |
| `lib_master.txt`  | 1.0.2h  | Flutter codebase reference |

---

## 🧠 Developer Setup

### Installation

```bash
git clone https://github.com/yourusername/coffea-pos-suite.git
cd coffea-pos-suite
flutter pub get
```

### Run

```bash
flutter run
```

### Clean Build

```bash
flutter clean && flutter pub get
```

---

## 💅 UI Design Guidelines

* Consistent `Roboto` typography
* Adaptive sizing using `Responsive` class
* Shared color palette from `theme_config.dart`
* Unified navigation via `MasterTopBar`

---

## 🤝 Contributing

1. **Create a new branch**

   ```bash
   git checkout -b feature/inventory-improvements
   ```

2. **Commit your changes**

   ```bash
   git commit -m "Add ingredient stock auto-deduction"
   ```

3. **Push and open PR**

   ```bash
   git push origin feature/inventory-improvements
   ```

4. **After merge**, clean up local branches

   ```bash
   git fetch -p
   ```

---

## 🧭 Roadmap

* [x] Modular structure for POS, Inventory, Attendance, Admin
* [x] Data seeding from `data_master.txt`
* [x] Role-based UI switching
* [ ] Setup Admin Tools Products Tab
* [ ] Setup POS System
* [ ] Setup Inventory Management System
* [ ] Setup Attendance Monitoring System

---

## 📜 License Summary (MIT)

The **MIT License** allows anyone to freely use, modify, and distribute this software — even commercially — provided they credit the original author. The software is provided *as is* without any warranty or liability.

```bash
MIT License
Copyright (c) 2025
Kurt Andre Olaer
```

---

> *“Brewing a smarter way to manage cafés — one cup, one system, one suite.”* ☕
