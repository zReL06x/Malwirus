---
trigger: always_on
---

Always use centralized theme and icons for consistency and easy maintenance. It is store in style
folder that contains icons.dart and theme.dart

Always check for reusable code (widgets, handlers, utilities) to avoid duplication.

Always follow a consistent design pattern (layout spacing, font sizes, colors).

Always implement Day/Night mode; if an existing theme is available, reuse and extend it.

Always separate logic from UI (e.g., use handlers or services for background logic).

Keep URL scanning and pattern matching centralized (e.g., in UrlScanner and SuspiciousUrlPatterns).

Use platform channels only when native Android code is required (e.g., SMS, background services).

Use shared preferences for simple persistent data and ensure keys are clearly named.

Use bottom sheets or dialogs for secondary actions (e.g., whitelist, recommendations).

Keep history and logs modular and easy to clear or export if needed.

Avoid hardcoding strings or colors; use constants or resource files.

Ensure permissions are handled gracefully and inform the user clearly why they are needed.

Write descriptive comments in your code to explain structure or complex logic.

Follow clean folder structure: group by feature (not file type) for better scalability.

Optimize for network checks (use utility class like NetworkUtils) before doing web requests.

Do not Create new classes/files when coding as they are already separated. Just put them into
already made files/classes.

Do not hard code strings, Use the strings.dart to store strings/text that will be displayed on UI.

