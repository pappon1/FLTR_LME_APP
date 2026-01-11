# Announcement System Design Plan
Based on `UploadAnnouncementScreen.kt` from the original Android App.

## 1. Feature Overview
The goal is to replicate the "Upload Announcement" feature from the Android app, but enhanced with better UI/UX as per the Flutter admin panel's design language.

## 2. UI Structure (Reference: `UploadAnnouncementScreen.kt`)
The Android screen had:
1.  **Top Bar:** Black background, Back button.
2.  **Main Content:**
    *   Title: "Upload Poster"
    *   Info Card: "Poster Size: 1280x720px (16:9)"
    *   **Upload Area:** A 320x180dp box (16:9).
        *   Empty State: Blue Image Icon + "Tap to select poster".
        *   Selected State: Image Preview (Crop fit).
    *   **Validation:** Strict 16:9 aspect ratio check (±5% tolerance).
    *   **Feedback:** Error messages in red cards, Success messages in green cards.
    *   **Action Button:** "Upload Poster" (Green color).

## 3. Flutter Implementation Plan

### Screen Location
*   New File: `lib/screens/announcements/upload_announcement_screen.dart`
*   Add entry point in `Dashboard` or `Sidebar`.

### UI Components
*   **Header:** Standard Admin AppBar.
*   **Aspect Ratio Info:** Informative banner (Blue tint).
*   **Image Picker:**
    *   Use `DottedBorder` or similar visual cue for upload area.
    *   Size: AspectRatio 16:9.
    *   Logic: `ImagePicker` -> `File` -> validation logic.
*   **Validation Logic (Dart):**
    *   Decode image using `decodeImageFromList`.
    *   Check `width / height` ratio.
    *   Reject if tolerance > 5%.
*   **Upload Logic:**
    *   Use `BunnyCDNService` (already existing).
    *   Path: `images/announcements/`.
*   **Database:**
    *   New Collection: `announcements`
    *   Fields: `imageUrl`, `createdAt`, `isActive`, `createdBy`.
    *   Note: The Android app seemed to handle "Upload" as a direct replacement or single active poster?
    *   *Self-Correction:* The Android code has `DeleteAnnouncementDialog`, implying maybe one active announcement or a list.
    *   *Refinement:* We will assume a list of announcements, or a single "Active" one. Start with "Manage Announcements" (List + Upload).

## 4. Enhanced UI (Better than Original)
*   **Preview:** Use `CachedNetworkImage` for existing ones.
*   **Progress:** Show real upload progress bar inside the card.
*   **Management:** Show "Current Active Poster" vs "History".

## 5. Next Steps
1.  Create `UploadAnnouncementScreen`.
2.  Implement `16:9` Validation.
3.  Integrate `BunnyCDN` upload.
4.  Save to Firestore.
