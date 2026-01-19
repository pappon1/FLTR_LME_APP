---
description: description: Comprehensive Developer Workflow (Analyze -> Code -> Sync -> Fix)
---

// turbo-all
Follow this workflow for every coding request from the USER:
1. **Scan & Analyze**: 
   - Sabse pehle `grep_search` ya `view_file` se poora context scan karein.
   - Summarize the current state to the USER in Hinglish before any edits.
2. **Run Background Check & Live Start**:
   - Check karein ki `flutter run` active hai ya nahi.
   - Agar band hai, toh use turant sahi device ID par start karein.
3. **Step-by-Step Implementation**:
   - Chote chunks mein `multi_replace_file_content` use karke badlav karein.
   - Har implementation ka "Kyun/Kahan/Kaise" Hinglish mein explain karein.
4. **Watchman Build Monitoring (Active Mode)**:
   - Jab `flutter run` ya `gradle` build chale, tab `command_status` tool se lagatar (loop mein) check karte rahein jab tak **SUCCESS** na ho jaye.
   - **Auto-Fix:** Agar build bich mein ruk jaye ya error de, toh usi waqt use fix karein aur phir se build shuru karein bina USER ka wait kiye.
5. **Sync & Validate**:
   - Send `r` (Hot Reload) ya `R` (Hot Restart).
   - `flutter analyze` ka use karke ensure karein ki koi naya bug toh nahi aaya.
6. **Final Report**:
   - USER ko detail mein bataein ki kya Improvements aur Implementation hui hain.