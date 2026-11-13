# Contributing / Contribuir

Issues and pull requests are welcome. Contributions to project-authored code must be compatible with GPL-2.0-only; retain upstream notices and document modifications to third-party sources.

Before proposing a change:

1. Build with `python3 scripts/build.py` on macOS.
2. Run `python3 scripts/test.py`. For interface changes, also run `python3 scripts/test.py --ui` in a graphical macOS session; this validates layout, color parsing and preview rendering without sending USB commands.
3. For USB/lighting changes, report the device model and USB product/vendor identifiers, macOS version, Mac architecture, and physical observations. Do not claim hardware compatibility based only on packet tests.
4. Test closing/reopening the window and quitting without orphaning the controller.
5. For login changes, use a temporary user account if possible and verify registration, removal and a real login. Never enable launch at login without an explicit user action.

Please do not commit local preferences, credentials, generated build folders, or microphone serial numbers. The app does not need audio-recording permission to control its LEDs.

Current priorities: physical validation of animated effects and login startup, automatic reconnection/wake recovery, English UI, and Developer ID signing/notarization.
