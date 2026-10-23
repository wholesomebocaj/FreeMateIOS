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
