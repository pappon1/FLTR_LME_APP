---
description: Global Rules and Git Policy for Antigravity
---

# Developer Expert Master Rules (Updated)

Aapko hamesha niche diye gaye "Smart & Strong" rules follow karne hain taaki coding fast aur bug-free rahe:

### 1. Pre-Coding Analysis (Sabse Pehle Scan)
- Koi bhi naya code likhne se pehle, hamesha `grep` ya `view_file` se poore context ko scan karein.
- Kaunsa code kahan hai aur kaise link hai, ye samjhe bina aage na badhein.
- **Hawa mein guess na karein**, hamesha code evidence se root cause pakdein.

### 2. Live Background Session
- Kaam shuru karne se pehle hamesha check karein ki `flutter run` background mein chal raha hai ya nahi.
- Agar session band hai, toh use start karein taaki hamesha live feedback milta rahe.

### 3. Watchman Build Monitoring
- **Active Watch:** Jab `gradle task assembleDebug` ya `flutter run` chale, tab "Watchman" mode active rakhein.
- **Stay on Terminal:** Build khatam hone tak terminal ko `command_status` se lagatar check karein.
- **Auto-Fix:** Agar build fail ho, toh kisi ka wait na karein, turant log scan karke error fix karein aur build phir se chalaein jab tak **SUCCESS** na ho jaye.

### 4. Incremental Coding & Fast Sync
- Ek saath bohot bada code na likhein. Chote blocks likhein.
- Har code change ke baad situation ke hisaab se `r` (Hot Reload) ya `R` (Hot Restart) chalayein.
- Agar `R` chalane pe error aaye, toh `flutter analyze` ka use karke issues ko fix karein.

### 5. Git Policy (Strict Rule)
- **No Self-Commits:** Jab tak **DEVELOPER (Aap)** na bole, tab tak na `git commit` karna hai aur na hi `git head` (reset/checkout) change karna hai.
- Sirf user ke explicit order par hi git commands chalani hain.

### 6. Build & Maintenance (Smart Decision)
- Jab koi badi structural change ho, tabhi `assembleDebug` chalayein.
- Agar build mein purana kachra (cache) dikhe, toh `flutter clean` karein.
- Unnecessary files ya widgets ko delete karke codebase ko clean rakhein.

### 7. Hinglish Communication & Transparency
- Har kaam ke baad USER ko Hinglish mein explain karein:
  - **Kya kiya?** (What changed)
  - **Kyun kiya?** (The logic/Rationale)
  - **Kya improvement hui?** (Benefit)

### 8. Global Persistence & Memory
- Ye rules aapke "Core Memory" ka hissa hain. Har request par inhe load karein aur hamesha USER (Bhai) ki sharton par khade utrein.
