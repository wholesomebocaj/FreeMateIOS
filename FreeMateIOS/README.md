# FreeMate iOS

FreeMate is a free, beginner-focused chess learning platform designed to make high-quality chess education accessible to everyone. 

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

## Opening Tutorials

Guided tutorials live at the top of the Openings tab. Each one has two steps:

1. **Main line.** The learner plays one side of the opening. The start and end squares of each move are highlighted. A wrong move does not land, and a hint appears.
2. **What if?** The opponent tries the common alternatives from the tutorial data, and the learner must answer from memory. Squares are only highlighted after a mistake or when the learner asks for a hint.

Code is in `FreeMateIOS/OpeningTutorials/`:

* `ChessOpening.swift`: the data model (`ChessOpening`, `OpeningStep`, `OpeningVariation`) and the merged variation tree.
* `OpeningTutorialLibrary.swift`: loads `opening-tutorials.json`, resolves every SAN move with `ChessEngine`, and saves progress on the device.
* `OpeningTutorialSession.swift`: the tutorial state machine. It owns the position and is UI-free.
* `OpeningTutorialCoaching.swift`: coach and feedback text.
* `OpeningTutorialController.swift`: drives the shared `PracticeBoard` through its `onMoveAttempt` hook.
* `OpeningTutorialViews.swift`: SwiftUI screens.

To add an opening, edit `opening-tutorials.json`, then check it and fill ECO codes from [eco.json](https://github.com/JeffML/eco.json):

```bash
pip install chess
python3 tools/opening_tutorials.py --eco-dir /path/to/eco-json
```

## Tests

In Xcode, run the `FreeMateIOS` scheme's tests (Cmd-U). Without Xcode, including on Linux, the UI-free core runs with:

```bash
swift test
```
