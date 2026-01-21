# 🛡️ Project Development Rules (Master Guide)

Aapko hamesha niche diye gaye rules follow karne hain taaki coding fast, bug-free, aur mobile resources ke liye "Smart" rahe.

### 1. Pre-Coding Analysis
- Koi bhi naya code likhne se pehle, hamesha `grep` ya `view_file` se poore context ko scan karein.
- Hawa mein guess na karein, code evidence se root cause pakdein.

### 2. Live Background Session
- Kaam shuru karne se pehle check karein ki `flutter run` background mein chal raha hai ya nahi.

### 3. Build & Maintenance (Smart Decision)
- Jab koi badi structural change ho, tabhi `assembleDebug` chalayein.
- Unnecessary files ya widgets ko delete karke codebase ko clean rakhein.

### 4. Hinglish Communication & Transparency
- Har kaam ke baad USER ko Hinglish mein explain karein kya, kyun aur kaise badla hai.

### 5. 🔋 Smart Resource Management (Rule #11)
- **Battery Efficiency:** Background functions ko "Andha-dhun" (Blind loop) mein na chalayein. 
- **Network Awareness:** Koi bhi network request karne se pehle device connectivity check karein. Agar net OFF hai, toh processor ko long sleep mode mein daal dein.
- **Smart Retries:** Network failures ke liye "Exponential Back-off" use karein (Wait time ko har failure ke baad badhate jayein).
- **Hidden Resource Leak:** Unused streams, timers, aur listeners ko hamesha dispose/cancel karein. Memory leaks aur hidden CPU usage ko zero rakhein.

### 6. Play Store Policy Compliance
- SDK versions, sensitive permissions, aur data handling ko hamesha secure aur compliant rakhein.
