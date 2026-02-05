---
name: flutter-refactoring
description: Use this skill when refactoring large Flutter files, especially AddCourseScreen. This skill should be checked at the START of every coding task to understand the project's refactoring patterns and conventions.
---

# Flutter Refactoring Skill

## 🚨 IMPORTANT: Auto-Check Policy
**Har task ke start mein ye skill check karo** taaki project ke refactoring patterns aur conventions pata rahen.

---

## 📁 Current Refactoring Task: AddCourseScreen

### Original File Location (BACKUP/OG)
- **Primary Source (OG File)**: `c:\Users\wwwpa\Desktop\FLTR_LME_APP\lme\add_course_screen.dart` (4468 lines, 76 methods)
  - *Note: Ye file hamesha reference ke liye use karo jab tak refactoring 100% na ho jaye.*
- **Target File**: `mobile_repair_admin/lib/screens/courses/add_course_screen.dart`

### Target Structure (Screen-Based Naming)
```
add_course/                        ← Folder name matches UI Screen (AddCourseScreen)
├── add_course_screen.dart          ← Entry point (Composition)
├── ui/                            ← DESIGN ONLY
│   ├── app_bar.dart
│   ├── components/                ← Small UI pieces
│   │   ├── text_field.dart
│   │   ├── image_uploader.dart
│   │   └── review_card.dart
│   └── steps/                     ← STEP-BY-STEP UI
│       ├── step_0_basic.dart
│       ├── step_1_setup.dart
│       ├── step_2_content.dart
│       └── step_3_advance.dart
├── local_logic/                   ← APP BEHAVIOR (State/Navigation)
│   ├── state_manager.dart          ← ChangeNotifier/Controllers
│   ├── navigation_logic.dart       ← Hot Reload safe navigation
│   └── validation_logic.dart       ← Form checks
└── backend_service/               ← CORE BUSINESS / DB
    ├── course_service.dart         ← Complete Firebase/API code
    └── models/                     ← Data structures
        └── course_model.dart
```

---

## 🔧 Refactoring Rules

### 1. State Management
- **All state variables** go in `logic/state_manager.dart`
- Use `ChangeNotifier` or `StateNotifier` pattern
- Export via `typedef` for State class

### 2. Widget Separation
- Each step (0-3) should be its own widget file
- Pass callbacks for state updates
- Use `const` constructors where possible

### 3. Tier-Based Extraction
- **UI Folder:** Sirf design aur layout. Har step ke liye alag file. 
- **Local Logic Folder:** Sirf app ka status (State) aur navigation sambhalne ke liye. 
- **Backend/Service Folder:** Pure Firebase/API operations aur business calculations ke liye. (Backend logic hamesha alag complete file mein rahegi).

### 4. Naming Conventions
```dart
// Files: snake_case
step_0_basic.dart

// Classes: PascalCase
class Step0BasicWidget extends StatelessWidget

// Private methods: camelCase with underscore
void _handleSubmit()

// Public methods: camelCase
void saveCourseDraft()
```

### 5. File Size Limit
- **Strict 1000 Lines Limit:** Kisi bhi refactored file mein **1000 lines** se zyada code nahi hona chahiye. Agar logic bada ho raha hai, toh use aur sub-files ya folders mein divide karo.

### 6. Dead Code Deletion
- **Deep Scan Before Delete:** Refactoring ke time jo code redundant (bakwas) lage, use delete karne se pehle **Deep Scan** karo ki wo kahin use toh nahi ho raha. 100% sure hone par hi delete karo.

### 7. Import Organization
```dart
// 1. Dart imports
import 'dart:async';
import 'dart:io';

// 2. Flutter imports
import 'package:flutter/material.dart';

// 3. Package imports
import 'package:provider/provider.dart';

// 4. Project imports (relative)
import '../logic/state_manager.dart';
import '../components/text_field.dart';
```

---

## � Strict No-Addition Policy

**Rule:** Refactoring ke waqt AI apni taraf se **kuch bhi naya** (UI, design, logic, click events, functionality) add **NAHI** karega. 

**Action:**
1. **Perfect Replicated Logic:** OG file mein jo UI logic, navigation aur click events hain, exact wahi naye modular code mein hone chahiye.
2. **No "Bla-Bla" Additions:** AI ko strictly mana hai ki wo extra feature, button ya styling add kare jo original file mein nahi hai.
3. **Zero Creative Liberty:** Creative hone ki zarurat nahi hai. Sirf code ko "Gande" (Big file) se "Saaf" (Modular files) mein convert karo, bina ek bhi purani line ya function badle.
4. **No Optimization:** Refactoring ke waqt code ko "Optimize" ya logic "Improve" karne ki koshish bilkul na karein. Jaisa OG file mein hai, waisa hi modular files mein shift karein. Optimization baad ka step hai.

---

## �📋 Method Categorization

### Logic Methods (Move to logic/)
| Method | Target File |
|--------|-------------|
| `_loadCourseDraft()` | draft_manager.dart |
| `_saveCourseDraft()` | draft_manager.dart |
| `_executeDraftSave()` | draft_manager.dart |
| `_validateStep0()` | validation.dart |
| `_validateStep1_5()` | validation.dart |
| `_validateAllFields()` | validation.dart |
| `_submitCourse()` | submit_handler.dart |
| `_pickContentFile()` | content_manager.dart |
| `_pasteContent()` | content_manager.dart |
| `_confirmRemoveContent()` | content_manager.dart |

### UI Methods (Move to ui/)
| Method | Target File |
|--------|-------------|
| `_buildAppBar()` | app_bar.dart |
| `_buildNavButtons()` | nav_buttons.dart |
| `_buildUploadingOverlay()` | upload_overlay.dart |
| `_buildStep1Basic()` | steps/step_0_basic.dart |
| `_buildStep1_5Setup()` | steps/step_1_setup.dart |
| `_buildStep2Content()` | steps/step_2_content.dart |
| `_buildStep3Advance()` | steps/step_3_advance.dart |

### Component Methods (Move to components/)
| Method | Target File |
|--------|-------------|
| `_buildTextField()` | text_field.dart |
| `_buildImageUploader()` | image_uploader.dart |
| `_buildCourseReviewCard()` | review_card.dart |
| `_buildValiditySelector()` | validity_selector.dart |
| `_buildCertificateSettings()` | certificate_settings.dart |

---

## ✅ Refactoring Checklist

When refactoring, follow this order:

- [ ] **Phase 1: Models**
  - [ ] Extract `CourseUploadTask` to `models/course_upload_task.dart`

- [ ] **Phase 2: Components (Simplest first)**
  - [ ] `_buildTextField` → `components/text_field.dart`
  - [ ] `_buildImageUploader` → `components/image_uploader.dart`
  - [ ] `_buildReviewItem` → `components/review_item.dart`
  - [ ] `_buildOptionItem` → `components/option_item.dart`

- [ ] **Phase 3: Logic**
  - [ ] Validation methods → `logic/validation.dart`
  - [ ] Draft methods → `logic/draft_manager.dart`
  - [ ] Content methods → `logic/content_manager.dart`

- [ ] **Phase 4: UI Steps**
  - [ ] Step 0 (Basic) → `ui/steps/step_0_basic.dart`
  - [ ] Step 1 (Setup) → `ui/steps/step_1_setup.dart`
  - [ ] Step 2 (Content) → `ui/steps/step_2_content.dart`
  - [ ] Step 3 (Advance) → `ui/steps/step_3_advance.dart`

- [ ] **Phase 5: Main Widget**
  - [ ] Clean main file - only imports & composition
  - [ ] Test each step individually
  - [ ] Verify hot reload works

---

## 🎯 Current Progress Tracking

### Completed Files
_(None yet - refactoring not started)_

### Pending Files (All)
**Models:**
- [ ] `models/course_upload_task.dart` - ⏳ Needed

**Logic:**
- [ ] `logic/state_manager.dart` - ⏳ Needed
- [ ] `logic/draft_manager.dart` - ⏳ Needed
- [ ] `logic/validation.dart` - ⏳ Needed
- [ ] `logic/content_manager.dart` - ⏳ Needed
- [ ] `logic/submit_handler.dart` - ⏳ Needed

**Components:**
- [ ] `components/text_field.dart` - ⏳ Needed
- [ ] `components/image_uploader.dart` - ⏳ Needed
- [ ] `components/review_card.dart` - ⏳ Needed

**UI Steps:**
- [ ] `ui/steps/step_0_basic.dart` - ⏳ Needed
- [ ] `ui/steps/step_1_setup.dart` - ⏳ Needed
- [ ] `ui/steps/step_2_content.dart` - ⏳ Needed
- [ ] `ui/steps/step_3_advance.dart` - ⏳ Needed

**Other UI:**
- [ ] `ui/app_bar.dart` - ⏳ Needed
- [ ] `ui/nav_buttons.dart` - ⏳ Needed
- [ ] `ui/upload_overlay.dart` - ⏳ Needed

---

## 📝 Notes for Agent

1. **Professional Autonomy:** Antigravity ek **Pro Experienced Dev** hai. Baar-baar permission na maange. Task ko logic ke saath start kare aur end-to-end complete kare.
2. **OG File Reference:** Hamesha `c:\Users\wwwpa\Desktop\FLTR_LME_APP\lme\add_course_screen.dart` ko main source of truth maano.
3. **No assumptions or Optimizations:** Layout, navigation, click events ya code optimization refactoring ke time bilkul nahi karna.
4. **Verification Step:** Refactoring ke baad code ko `flutter analyze` se check karein taaki linking aur syntax 100% sahi rahe. Kuch bhi missing na ho.
5. **Hot Reload Sync:** Dev manually `flutter run` karke rakhega. AI har extraction ke baad code save karke Dev ko bata dega ki "Hot Reload karke check karlo".
6. **100% Rule:** Original file ko tabhi delete/discard karo jab refactoring 100% complete ho jaye aur naya modular code fully functional ho.
7. **Never break** existing functionality - test after each extraction.
