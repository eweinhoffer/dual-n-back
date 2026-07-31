# Dual N-Back Screenshots

Clean iPhone Simulator captures for the project README, GitHub, and blog posts.
The Statistics screen uses synthetic demonstration sessions, not personal data.

## iOS screens

1. `iOS/01-main.png` — Main training screen
2. `iOS/02-training-active.png` — Active trial with the visual stimulus highlighted
3. `iOS/03-settings.png` — Settings, including offline voice selection and colors
4. `iOS/04-how-to-play.png` — Instructions and Universal Clipboard explanation
5. `iOS/05-statistics.png` — Progress chart and synthetic session history
6. `iOS/06-universal-clipboard-sync.png` — Copy Stats and Paste Stats actions

## Universal Clipboard flow

Both devices must use the same Apple Account with Wi-Fi, Bluetooth, and Handoff enabled.

### iPhone to Mac

1. On iPhone, open **Stats → Sync → Copy Stats**.
2. On Mac, open **Statistics → Paste Stats**.

### Mac to iPhone

1. On Mac, open **Statistics → Copy Stats**.
2. On iPhone, open **Stats → Sync → Paste Stats**.
3. If iOS asks for paste permission, choose **Allow Paste**.

The transfer contains only the app's session-history JSON. Duplicate sessions are skipped when histories are merged.
