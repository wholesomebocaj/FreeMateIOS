#!/usr/bin/env python3
"""Check the bundled drills and puzzles.

For every puzzle: the FEN is legal and each solution move is legal.
Mate puzzles: every solution mates. Any other mate is also accepted in the app.
Material puzzles: each solution wins at least WIN centipawns, and every move that is not a
solution is at least MARGIN worse, so a learner is never marked wrong for an equal move.

    pip install chess
    python3 tools/check_puzzles.py
"""

import json
import sys
from pathlib import Path

import chess

ROOT = Path(__file__).resolve().parents[1]
RESOURCES = ROOT / "FreeMateIOS" / "Resources"
VALUES = {chess.PAWN: 100, chess.KNIGHT: 320, chess.BISHOP: 330, chess.ROOK: 500, chess.QUEEN: 900, chess.KING: 0}
MATE = 100_000
WIN = 200
MARGIN = 150


def material(board):
    score = sum(VALUES[p.piece_type] * (1 if p.color == board.turn else -1) for p in board.piece_map().values())
    return score


def quiesce(board, alpha, beta, depth=4):
    stand = material(board)
    if stand >= beta or depth == 0:
        return stand
    alpha = max(alpha, stand)
    for move in board.legal_moves:
        if not board.is_capture(move):
            continue
        board.push(move)
        score = -quiesce(board, -beta, -alpha, depth - 1)
        board.pop()
        if score >= beta:
            return score
        alpha = max(alpha, score)
    return alpha


def negamax(board, depth, alpha, beta):
    if board.is_checkmate():
        return -(MATE + depth)
    if board.is_stalemate() or board.is_insufficient_material():
        return 0
    if depth == 0:
        return quiesce(board, alpha, beta)
    best = -10**9
    for move in board.legal_moves:
        board.push(move)
        score = -negamax(board, depth - 1, -beta, -alpha)
        board.pop()
        best = max(best, score)
        alpha = max(alpha, score)
        if alpha >= beta:
            break
    return best


def scores(board):
    result = {}
    for move in board.legal_moves:
        board.push(move)
        result[move.uci()] = -negamax(board, 1, -10**9, 10**9)
        board.pop()
    return result


def check(puzzle, where):
    problems = []
    board = chess.Board(puzzle["fen"])
    if not board.is_valid():
        return [f"{where}: invalid FEN ({board.status()})"]
    for uci in puzzle["solution"]:
        if chess.Move.from_uci(uci) not in board.legal_moves:
            problems.append(f"{where}: {uci} is not legal")
    if problems:
        return problems
    if puzzle.get("mate") or puzzle.get("theme") == "mate":
        for uci in puzzle["solution"]:
            board.push_uci(uci)
            if not board.is_checkmate():
                problems.append(f"{where}: {uci} is not mate")
            board.pop()
        return problems
    if puzzle.get("theme") != "material":
        return problems  # Drills that teach a motif rather than winning material.
    scored = scores(board)
    now = material(board)
    for uci in puzzle["solution"]:
        if scored[uci] - now < WIN:
            problems.append(f"{where}: {uci} only gains {scored[uci] - now}")
    worst_solution = min(scored[uci] for uci in puzzle["solution"])
    for uci, score in scored.items():
        if uci not in puzzle["solution"] and score > worst_solution - MARGIN:
            problems.append(f"{where}: {uci} ({score}) is nearly as good as the solution ({worst_solution})")
    return problems


def main():
    problems = []
    drills = json.loads((RESOURCES / "drills.json").read_text())
    for drill in drills:
        for puzzle in drill["puzzles"]:
            problems += check(puzzle, f"drill {drill['id']}/{puzzle['id']}")
    puzzles = json.loads((RESOURCES / "puzzles.json").read_text())
    ids = set()
    for level in puzzles["levels"]:
        for puzzle in level["puzzles"]:
            if puzzle["id"] in ids:
                problems.append(f"duplicate id {puzzle['id']}")
            ids.add(puzzle["id"])
            if puzzle.get("theme") not in ("mate", "material"):
                problems.append(f"{puzzle['id']}: theme must be mate or material")
            problems += check(puzzle, f"level {level['level']}/{puzzle['id']}")
    for problem in problems:
        print(problem)
    count = sum(len(level["puzzles"]) for level in puzzles["levels"])
    print(f"{len(problems)} problems in {sum(len(d['puzzles']) for d in drills)} drill puzzles and {count} puzzles")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
