# Orbinius Portal: Enterprise Attendance & Leave Management Dashboard

## Project Overview
Orbinius Portal is a high-performance employee analytics hub and workforce management console built natively inside Salesforce using **Lightning Web Components (LWC)** and **Apex**. It provides employees and administrators with a real-time tracking dashboard for daily working hours, leave balances, and visual performance statistics, eliminating the need for fragmented third-party HR systems.

---

## Architectural & Technical Highlights

### 1. Dynamic UI State Management & Client-Side Timer
* **Live Timer Intervals:** Engineered a high-accuracy, client-side timer framework in JavaScript to track daily logged hours with real-time reactive UI updates.
* **State-Managed Data Tables:** Built modular, state-driven line-item data tables to cleanly manage complex leave balancing calculations and real-time state changes without page refreshes.

### 2. Advanced Third-Party Library Integration (Chart.js)
* **Static Resource Loading:** Leveraged Salesforce platform resource loaders (`lightning/platformResourceLoader`) to securely inject external Chart.js libraries into component execution cycles.
* **Manual DOM Manipulation:** Bypassed Shadow DOM isolation boundaries securely using custom component canvas elements to dynamically render and map structural attendance statistics.

### 3. Intricate Server-Side Calculation Layer (Apex)
* **Holiday & Weekend Processing Matrices:** Designed a robust Apex calculation layer configured to evaluate multi-interval date aggregation variables against complex regional holiday lists and weekend patterns.
* **Optimized Bulk Wrappers:** Modeled data transfer objects (Wrappers) to serialize clean UI-ready transactional summaries from database records efficiently.

---

## Technology Stack & Architecture
* **Frontend Components:** Lightning Web Components (LWC), JavaScript (ES6+), Salesforce Lightning Design System (SLDS), HTML5/CSS3.
* **Data Visualization:** Chart.js Library integration via Secure Platform Resource Loaders.
* **Backend Controllers:** Apex (Object-Agnostic Calculation Layer, Custom Utility Schemas).
* **Data Modeling:** Custom Objects, Complex Date/Time Fields, and Multi-interval Aggregations.

---

## Repository Structure & Key Code Artifacts
* `force-app/main/default/lwc/orbiAttendanceManager/`
  * `orbiAttendanceManager.html`: Responsive SLDS layouts, live timer wrapper headers, and canvas structures for data rendering.
  * `orbiAttendanceManager.js`: Controls component state lifecycle, client-side timers, reactive leave tracking logic, and Chart.js instantiation.
  * `orbiAttendanceManager.css`: Clean custom typography and UI token overrides.
* `force-app/main/default/classes/`
  * `OrbiAttendanceManagerController.cls`: Main controller serving `@AuraEnabled` integrations for UI aggregation streams.
  * `OrbiAttendanceManagerControllerUtility.cls`: Dedicated processing matrix handling calculations for holiday metadata and working hour limits.

---

## Business & Productivity Impact
* **Operational Performance:** Streamlined human resource workflows by automating core tracking, leading to faster data processing speeds for workforce logs.
* **Enhanced Visibility:** Enabled data-driven leave forecasting and transparent shift metrics for enterprise environments directly inside the CRM.
