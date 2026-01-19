# Developer Expert Workflow Rules

Aapko hamesha niche diye gaye "Smart & Strong" rules follow karne hain taaki coding fast aur bug-free rahe:

### 1. Pre-Coding Analysis (Sabse Pehle Scan)
- Koi bhi naya code likhne se pehle, hamesha `grep` ya `view_file` se poore context ko scan karein.
- Kaunsa code kahan hai aur kaise link hai, ye samjhe bina aage na badhein.
- **Hawa mein guess na karein**, hamesha code evidence se root cause pakdein.

### 2. Live Background Session
- Kaam shuru karne se pehle hamesha check karein ki `flutter run` background mein chal raha hai ya nahi.
- Agar session band hai, toh use start karein taaki hamesha live feedback milta rahe.

### 3. Incremental Coding & Fast Sync
- Ek saath bohot bada code na likhein. Chote blocks likhein.
- Har code change ke baad situation ke hisaab se `r` (Hot Reload) ya `R` (Hot Restart) chalayein.
- Agar `R` chalane pe error aaye, toh `flutter analyze` ka use karke issues ko fix karein.

### 4. Build & Maintenance (Smart Decision)
- Jab koi badi structural change ho, tabhi `assembleDebug` chalayein.
- Agar build mein purana kachra (cache) dikhe, toh `flutter clean` karein.
- Unnecessary files ya widgets ko delete karke codebase ko clean rakhein.

### 5. Hinglish Communication & Transparency
- Har kaam ke baad USER ko Hinglish mein explain karein:
  - **Kya kiya?** (What changed)
  - **Kyun kiya?** (The logic/Rationale)
  - **Kya improvement hui?** (Benefit)
- Isse USER (Developer) ko samajh aayega ki "Kahan, Kya, aur Kaise" badla hai.

### 6. Error Fixing Pro-Mode
- Agar koi bug aaye, toh pehle analyzer aur logs dekhein.
- Fix karne ke baad verify karein ki error chala gaya hai, tabhi aage badhein.

### 7. Global Persistence
- Ye rules aapke "Core Memory" ka hissa hain. Har request par inhe load karein aur hamesha USER (Bhai) ki sharton par khade utrein.
