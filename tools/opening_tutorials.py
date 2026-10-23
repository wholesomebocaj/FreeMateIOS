#!/usr/bin/env python3
"""Check opening tutorial lines and fill ECO codes and names from eco.json.

Usage:
    python3 tools/opening_tutorials.py --eco-dir /path/to/eco-json
    python3 tools/opening_tutorials.py --check

eco.json: https://github.com/JeffML/eco.json (MIT). Requires `pip install chess`.
"""

import argparse
import json
import sys
from pathlib import Path

import chess

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "FreeMateIOS" / "OpeningTutorials" / "opening-tutorials.json"
ECO_FILES = ["ecoA.json", "ecoB.json", "ecoC.json", "ecoD.json", "ecoE.json", "eco_interpolated.json"]


def position_key(board):
    return " ".join(board.fen().split()[:4])


def load_book(eco_dir):
    book = {}
    for name in ECO_FILES:
        path = Path(eco_dir) / name
        if not path.exists():
            continue
        for fen, entry in json.loads(path.read_text()).items():
            key = " ".join(fen.split()[:4])
            current = book.get(key)
            if current is None or (current.get("src") != "eco_tsv" and entry.get("src") == "eco_tsv"):
                book[key] = entry
    if not book:
        sys.exit(f"No eco.json files found in {eco_dir}")
    return book


def play(sans, label):
    board = chess.Board()
    for ply, san in enumerate(sans):
        try:
            board.push_san(san)
        except ValueError:
            sys.exit(f"{label}: ply {ply} {san} is not legal in {board.fen()}")
    return board


def named_entry(sans, book, display_name=None):
    """Shallowest lichess entry naming the line, else the deepest lichess entry."""
    board = chess.Board()
    entries = []
    for san in sans:
        board.push_san(san)
        entry = book.get(position_key(board))
        if entry:
            entries.append(entry)
    lichess = [entry for entry in entries if entry.get("src") == "eco_tsv"] or entries
    if display_name:
        for entry in lichess:
            if display_name.lower() in entry["name"].lower():
                return entry
    return lichess[-1] if lichess else None


def user_turn(side, ply):
    return (ply % 2 == 0) == (side == "white")


def check_opening(opening, book):
    main = [step["san"] for step in opening["mainLine"]]
    side = opening["userSide"]
    play(main, opening["id"])
    if not user_turn(side, len(main) - 1):
        sys.exit(f"{opening['id']}: the main line must end with a {side} move")
    if book:
        entry = named_entry(main, book)
        opening["eco"], opening["ecoName"] = entry["eco"], entry["name"]
    for variation in opening["variations"]:
        label = f"{opening['id']}/{variation['id']}"
        ply = variation["branchPly"]
        moves = [step["san"] for step in variation["moves"]]
        if user_turn(side, ply):
            sys.exit(f"{label}: branchPly {ply} must be an opponent move")
        if ply >= len(main) or moves[0] == main[ply]:
            sys.exit(f"{label}: must branch away from the main line at ply {ply}")
        if not user_turn(side, ply + len(moves) - 1):
            sys.exit(f"{label}: must end with a {side} move")
        full = main[:ply] + moves
        play(full, label)
        if book:
            entry = named_entry(full, book, variation["name"])
            variation["eco"], variation["ecoName"] = entry["eco"], entry["name"]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--eco-dir", help="folder with ecoA.json ... ecoE.json")
    parser.add_argument("--check", action="store_true", help="only check legality")
    args = parser.parse_args()
    data = json.loads(DATA.read_text())
    book = load_book(args.eco_dir) if args.eco_dir and not args.check else None
    for opening in data["openings"]:
        check_opening(opening, book)
    if book:
        DATA.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n")
    for opening in data["openings"]:
        print(f"{opening['id']}: {opening.get('eco', '?')} {opening.get('ecoName', '')}")
        for variation in opening["variations"]:
            print(f"  {variation['id']}: {variation.get('eco', '?')} {variation.get('ecoName', '')}")


if __name__ == "__main__":
    main()
