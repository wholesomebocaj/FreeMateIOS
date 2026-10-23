# FreeMate iOS

FreeMate is a free, beginner-focused chess learning platform designed to make high-quality chess education accessible to everyone.

The phone-and-desktop web app lives in `web/`. From that folder, run `python3 -m http.server 8765` and open http://127.0.0.1:8765. Learning does not require an account. 

This repository houses the native iOS version of the platform, built to help new players improve their game through practical learning rather than paywalled courses.

## Core Architecture

* **Engine Core:** Native Swift implementation porting modular game loops and state evaluation logic.
* **User Interface:** Rebuilt completely using modern Apple SwiftUI rendering patterns.
* **Data Layer:** Typed, Codable progress saved on the device and synced through the learner's own iCloud. There are no accounts.

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

Beginner sits below Easy and is iOS only. It looks one move ahead with so much randomness that it grabs a free queen but plays loosely otherwise.

The game also coaches:

* **Blunder warning.** When a move hangs a piece or allows mate, and a safer move exists, the computer waits. The card names what is at risk, the square is marked, and the learner can take the move back or play on. It can be turned off in the Computer card.
* **Hint.** Marks the coach's best move on the board.
* **Review.** After a game, each of the learner's moves is graded Best, Good, Mistake, or Blunder, with the better move and a short reason.

Code:

* `ComputerOpponent.swift`: the search, ported from `web/engine.js`. It is UI-free and runs off the main thread.
* `ComputerCoach.swift`: grades moves for the warning, hint, and review. It looks at the opponent's best reply and then plays out captures, so it sees hanging pieces, bad trades, and mate in one. UI-free.
* `ComputerGame.swift`: plays a game on a `PracticeBoard` and keeps the record.
* `ComputerGameReview.swift`: grades a finished game one move at a time and steps a board through it.
* `Tabs/ComputerPlayPanel.swift` and `Tabs/ComputerGameReviewView.swift`: the screens.

## Puzzles and drills

The Practice tab's Puzzles side has two parts. Each puzzle is one position with one winning move.

* **Puzzles:** 24 curated mate-in-one and win-a-piece puzzles in four levels of six. Solving 4 in a level unlocks the next. They live in `Resources/puzzles.json`.
* **Drills:** the web app's five drills, on mate in one, forks, pins, hanging pieces, and getting out of check. They live in `Resources/drills.json`, which `web/build_content.py` also reads, so both apps share one copy.

A wrong move springs back and shows the hint. Hint marks the piece to move. After two wrong moves, Show Answer marks the whole move, and the puzzle no longer counts as solved first try. Any checkmate solves a mate puzzle. Progress is saved on the device.

Code in `FreeMateIOS/Puzzles/`: `Puzzle.swift` holds the models, the loader, the progress store, and the UI-free `PuzzleSession`. `PuzzleTrainer.swift` drives the board, and `Views/` has the hub and the trainer screen.

After editing either file, check every position:

```bash
pip install chess
python3 tools/check_puzzles.py
```

It checks that every FEN and solution is legal, and that mate solutions mate. For win-a-piece puzzles, it checks that each solution wins at least 2 pawns' worth and that every other move is clearly worse, so a learner is never marked wrong for an equally good move.

The tab root screens live in `FreeMateIOS/Tabs/`: Lessons (`CourseLibraryView`), Openings (`OpeningBrowserView`), and Practice (`PracticeView`). Every board in the app, including lessons, the opening trainer, and Practice, uses `ModernBoardView`.

To add an opening, edit `opening-tutorials.json`, then check it and fill ECO codes from [eco.json](https://github.com/JeffML/eco.json):

```bash
pip install chess
python3 tools/opening_tutorials.py --eco-dir /path/to/eco-json
```

## Progress, sync, and the widget

Code in `FreeMateIOS/Progress/`:

* `LearnerProgress.swift`: lessons, lesson steps, opening lines, and the review queue as one Codable value, saved under `freemate.progress.v2`. Reviews use spaced repetition: an item comes back after 1, 3, 7, and 14 days, and a miss sends it back to the start, due at once. Practicing before an item is due does not move it up.
* `LegacyProgressMigration.swift`: on first launch, reads the old loose keys, then deletes them. That includes the old local accounts and their password hashes.
* `ActivityStore.swift`: the days the learner practiced anything, for the streak.
* `SyncMerge.swift` and `CloudSync.swift`: iCloud sync through the key-value store. Each store is merged without losing work on either device: completions are unions, steps keep the furthest point, and reviews keep the newer copy. Games against the computer are counted per device and added up.

Home shows a progress dashboard: the streak, reviews due, lessons, mastered openings, puzzles, and the record against the computer.

The Home Screen widget is in `FreeMateWidget/`. It shows the next lesson, reviews due today, and the streak. It reads a `WidgetSnapshot` (in `Shared/`) that the app writes to the App Group `group.com.jacobbakerpersonalteam.FreeMateIOS`. Tapping it opens `freemate://lesson/<id>` or `freemate://review`.

Both targets need their capabilities on the Apple Developer account: App Groups for the app and the widget, and iCloud (key-value storage) for the app. The entitlements are in `Config/`. Simulator builds without signing still run, but they do not sync, and the widget shows its placeholder.

The app icon is drawn from the app's own vector knight. To redraw it:

```bash
tools/render_app_icon.sh
```

## Tests

In Xcode, run the `FreeMateIOS` scheme's tests (Cmd-U). GitHub Actions (`.github/workflows/ios-build.yml`) builds the app and runs the tests on every push. Without Xcode, including on Linux, the UI-free core runs with:

```bash
swift test
```
