# FreeMate iOS

FreeMate is a free, beginner-focused chess learning platform designed to make high-quality chess education accessible to everyone.

The phone-and-desktop web app lives in `web/`. From that folder, run `python3 -m http.server 8765` and open http://127.0.0.1:8765. Learning does not require an account. 

This repository houses the native iOS version of the platform, built to help new players improve their game through practical learning rather than paywalled courses.

## Core Architecture

* **Engine Core:** Native Swift implementation porting modular game loops and state evaluation logic.
* **User Interface:** Rebuilt completely using modern Apple SwiftUI rendering patterns.
* **Data Layer:** Local storage for tracking puzzle completion rates, lesson checkpoints, and rating progression.

## Roadmap & Features

* **Interactive Lessons:** Step-by-step beginner guides with active piece highlighting.
* **Chessboard Exercises:** Tactical mini-challenges that teach board control and positional awareness.
* **Curated Puzzles:** Zero-paywall puzzles dynamically adapted to user progression.
* **Progress Dashboard:** Local metrics mapping strengths, weaknesses, and historical growth.

## Design system

Colors, type, spacing, and shared components are defined in `FreeMateIOS/DesignSystem/Theme.swift`. The rules are in [`DESIGN.md`](../DESIGN.md). Every screen uses those tokens instead of literal colors.

## Opening Tutorials

The guided tutorials sit at the top of the Openings tab, each with a board preview and its status (Not Started, In Progress, or Mastered). Each tutorial has two steps:

1. **Main line.** The learner plays one side. The start square is tinted and the target square glows. A wrong move springs back with a gentle shake and an error haptic, and the card shows a hint.
2. **Branching out.** The opponent tries the common alternatives from the tutorial data, and the learner answers from memory. Squares only light up after a mistake or when the learner taps Hint.

Finishing everything shows a completion overlay with stats.

Code in `FreeMateIOS/OpeningTutorials/`:

* `ChessOpening.swift`: the data model (`ChessOpening`, `OpeningStep`, `OpeningVariation`) and the merged variation tree.
* `OpeningTutorialLibrary.swift`: loads `opening-tutorials.json`, resolves every SAN move with `ChessEngine`, and saves progress on the device.
* `OpeningTutorialSession.swift`: the tutorial state machine. It owns the position and is UI-free.
* `OpeningTutorialPresentation.swift`: what the card, progress bar, and completion screen say. UI-free and unit tested.
* `OpeningTutorialController.swift`: drives the shared `PracticeBoard` through its `onMoveAttempt` hook.
* `Views/`: the tutorial card, the tutorial screen, the progress header, the floating instruction card, and the completion overlay.

Reusable pieces in `FreeMateIOS/DesignSystem/`:

* `ModernBoardView.swift`: the cream and sage board for any `PracticeBoard`. Supports tap or drag, sliding pieces, a breathing guide glow, and VoiceOver actions per square.
* `ChessPieceShape.swift`: vector pieces, so they stay crisp at any size.
* `BoardPieceLayout.swift`: keeps piece identities across moves so pieces glide instead of jumping.
* `BoardThumbnail.swift`: a single-pass `Canvas` preview board.
* `MotionEffects.swift` and `Haptics.swift`: the shared spring, shake, glow, pressable cards, and light, error, and success haptics.
* `FilterChips.swift`: the search-and-filter chip row used by the Lessons and Openings tabs.

## Play the computer

The Practice tab opens on a game against the same beginner computer as the web app. Easy looks one move ahead with a lot of randomness, so it misses tactics. Fair looks two moves ahead. The learner picks White or Black, can undo a move, and can resign. Wins, draws, and losses are saved on the device. The Free Board side of the tab is the old two-sided board.

* `ComputerOpponent.swift`: the search, ported from `web/engine.js`. It is UI-free and runs off the main thread.
* `ComputerGame.swift`: plays a game on a `PracticeBoard` and keeps the record.
* `Tabs/ComputerPlayPanel.swift`: the screen.

The tab root screens live in `FreeMateIOS/Tabs/`: Lessons (`CourseLibraryView`), Openings (`OpeningBrowserView`), and Practice (`PracticeView`). Every board in the app, including lessons, the opening trainer, and Practice, uses `ModernBoardView`.

To add an opening, edit `opening-tutorials.json`, then check it and fill ECO codes from [eco.json](https://github.com/JeffML/eco.json):

```bash
pip install chess
python3 tools/opening_tutorials.py --eco-dir /path/to/eco-json
```

## Tests

In Xcode, run the `FreeMateIOS` scheme's tests (Cmd-U). GitHub Actions (`.github/workflows/ios-build.yml`) builds the app and runs the tests on every push. Without Xcode, including on Linux, the UI-free core runs with:

```bash
swift test
```
