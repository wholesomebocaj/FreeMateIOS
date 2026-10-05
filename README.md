# FreeMate

FreeMate is a free beginner chess app. There are no ads, no paywall, and no account. Lessons, drills, opening lines, and games are saved in the browser on this device.

## Web app

The web app runs on phones and desktops.

```bash
cd web
python3 -m http.server 8765
```

Open [http://127.0.0.1:8765](http://127.0.0.1:8765).

It includes:

- Interactive lessons for the board, piece movement, check, checkmate, tactics, and simple opening ideas
- Practice drills
- A board to play the computer, plus a free board for experimenting
- Guided opening lines from the bundled course data

Lesson sources live in `Resources/data/courses`. Regenerate the web bundle after editing them:

```bash
python3 web/build_content.py
cd web && npm test
```

## iOS

Native SwiftUI sources and the Xcode project are in `FreeMateIOS/`. The web app is the cross-platform way to learn without an account.
