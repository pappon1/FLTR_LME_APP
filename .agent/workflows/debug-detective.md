---
description: Automated loop to detect, analyze, and fix crashes or exceptions from logs.
---

# Debug Detective Workflow

This workflow automates the process of finding and fixing compilation errors or runtime exceptions.

## Steps to Execute

1.  **Scan Logs**:
    *   Action: Use `read_terminal` or `command_status` to fetch the last 100-200 lines of output.
2.  **Identify Exception**:
    *   Action: Look for keywords: `Exception`, `Error`, `RangeError`, `NoSuchMethodError`, `RenderFlex overflowed`.
    *   **Turbo**: If "File not found" or "Syntax error", jump to Fix immediately.
3.  **Locate Source**:
    *   Action: Extract the `Filename` and `Line Number` from the stack trace (e.g., `lib/screens/home.dart:45`).
4.  **Analyze File**:
    *   Action: Use `view_file` to read the context around that specific line.
5.  **Propose & Apply Fix**:
    *   Action: Logic fix, Null check addition, or Syntax correction using `replace_file_content`.
6.  **Verify**:
    *   Action: Run `Hot Restart` (`R`) or `Hot Reload` (`r`).
    *   Repeat Step 1 if error persists.

## Trigger
Use this when you see red logs in the terminal or the user says "App crash ho gaya" or "Error aa raha hai".
