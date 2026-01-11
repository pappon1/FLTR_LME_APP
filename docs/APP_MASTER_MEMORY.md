# 🧠 LME Admin App - Master Memory & Architecture Guide

> **Status:** Active / Stable
> **Last Updated:** 2026-01-11
> **Purpose:** To serve as a comprehensive backup of the application's Logic, UI/UX, Design System, and Functionality. If code is lost or broken, refer to this file to restore the intended behavior.

---

## 🏗️ 1. Project Structure Overview

The project is a **Flutter Admin Application** for managing the "Local Mobile Engineer" platform.

### **Core Directory Layout:**
- `lib/`
  - `main.dart`: Entry point. Sets up Firebase, System UI (Portrait, Transparent StatusBar), and Providers.
  - `utils/app_theme.dart`: Central Design System (Colors, Fonts).
  - `screens/`: Contains all UI screens organized by feature.
  - `providers/`: State management (Provider pattern).
  - `services/`: External integrations (Firebase, BunnyCDN).
  - `models/`: Data models (Course, User, etc.).
  - `widgets/`: Reusable UI components.

---

## 🎨 2. Design System (UI/UX)

**Controlled by:** `lib/utils/app_theme.dart`

### **Typography:**
- **Headings:** `Outfit` (Bold, Modern).
- **Body Text:** `Inter` (Clean, Readable).

### **Color Palette:**
- **Primary:** Indigo (`0xFF6366F1`)
- **Secondary:** Purple (`0xFF8B5CF6`)
- **Background (Dark):** Deep Navy (`0xFF0A0E27`) -> *Critical for Premium Feel*
- **Cards (Dark):** Lighter Navy (`0xFF151935`)
- **Accents:** Green (Success), Orange (Warning), Red (Error).

### **Gradients:**
- Used heavily in buttons and cards for a "Premium" look.
- Example: `primaryGradient` (Indigo -> Purple).

---

## 🧭 3. Navigation Architecture

**Root:** `main.dart` -> `AuthWrapper`
- Checks Firebase Auth State.
- If Logged In & Admin -> **HomeScreen**
- Else -> **LoginScreen**

**Main Navigation (HomeScreen):**
- **Type:** Bottom Navigation Bar (`NavigationBar`).
- **State:** `DashboardProvider` controls `selectedIndex`.
- **Tabs:**
  1.  **Dashboard** (`DashboardTab`): Statistics & Overview.
  2.  **Courses** (`CoursesTab`): Manage Courses (Add/Edit).
  3.  **Settings** (`SettingsTab`): App & Account settings.

---

## 📱 4. Screen-Specific Logic & UX

### **A. Add Course Screen (`AddCourseScreen.dart`)**
*This is the most complex screen currently.*

**Navigation Path:** `Courses Tab` -> Click `+ Add Course` button.

**Structure (3 Steps):**
1.  **Basic Info:**
    - Title, Description.
    - **Thumbnail:** 16:9 Image Picker (Validation approx 1.77 ratio).
    - **Pricing:** MRP, Discount, Final Price (Auto-calculated).
    - **Selectors:** Category (Hardware/Software), Type (Beginner/Adv), Badge Duration.
2.  **Contents ( The "Brain" ):**
    - **List:** Reorderable List of Video/PDF/Zip/Folder.
    - **FAB (Floating Button):** Custom Circular "Add" button (**Round**, Shadowed).
    - **Add Menu:** BottomSheet with Folder, Video, PDF, Image, Zip, Paste.
    - **Folder Logic:** Can create folders. Click folder -> Opens `FolderDetailScreen`.
    - **Drag & Drop:**
        - **Long Press:** Activates Selection Mode (Multi-select for Delete/Copy/Cut).
        - **Hold (0.6s):** Activates Drag Mode (Haptic Feedback) -> Drag handle appears left/right.
    - **Clipboard:** Global static variable allows Copy/Cut from one folder and Paste into another.
3.  **Advance:**
    - Duration text.
    - Publish Switch.
    - Submit Button.

**Critical UX Details:**
- **Step Indicator:** Uses `AnimatedSize` to remove black gaps when hidden.
- **Plus Icon:** Must be **CIRCLE** (not square) to match Folder UI.
- **Scroll Zones:** During drag, top/bottom edges auto-scroll.

### **B. Admin Notification Screen**
**Navigation Path:** Dashboard -> Notification Icon (Top Right).

**Features:**
- **Tabs:** Send (Compose), Scheduled, Received (History).
- **Compose:** Title, Body, Image URL, Topic Selector.
- **Logic:** Uses `AdminNotificationProvider` to send FCM messages.

---

## 🛠️ 5. Key Functionalities

### **Authentication**
- **Service:** `FirebaseAuthService`.
- **Logic:** Checks logical "Admin" flag in Firestore `users` collection.

### **State Management**
- **Pattern:** Provider.
- **Key Providers:**
    - `ThemeProvider`: Light/Dark toggle.
    - `DashboardProvider`: Holds Global App State (Nav index, Course List).
    - `AdminNotificationProvider`: Manages notification sending/history.

### **Icons**
- **Library:** `font_awesome_flutter` is preferred for modern icons, mixed with standard `Icons` (Material).

---

## ⚠️ 6. "Do Not Touch" / Critical Memory
*Code sections that are tricky and stable.*

1.  **`AddCourseScreen.dart` -> `buildStepIndicator`**:
    - Wrapped in `AnimatedSize`. Do NOT change to `AnimatedContainer` without handling the height `0` vs `120` logic perfectly, otherwise black gap returns.
2.  **`main.dart` -> `SystemChrome`**:
    - configured for **Transparent Status Bar** and **Portrait Only**. Changing this breaks the "Full Screen Premium" feel.
3.  **`AddCourseScreen.dart` -> `_pickImage`**:
    - Has strict 16:9 ratio validation. Removing this breaks the layout on the User App.

---
**📝 Note to AI:** When updating this file, always check the "Last Updated" date and append new features or logic changes under the appropriate section.
