#!/usr/bin/env python3
"""Check the bundled drills and puzzles.

For every puzzle: the FEN is legal and each solution move is legal.
Mate puzzles: every solution mates. Any other mate is also accepted in the app.
Material puzzles: each solution wins at least WIN centipawns, and every move that is not a
solution is at least MARGIN worse, so a learner is never marked wrong for an equal move.
Mate in 2 ("mateIn": 2): there is no mate in 1, and the solution lists exactly the first moves
that force mate next move against every defense.
Blunder checks: a "blunder" move loses at least WIN (or allows mate) and its refutation is the
best reply; a "safe" move loses at most SAFE.

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
SAFE = 60


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


def mates_in_one(board):
    for move in board.legal_moves:
        board.push(move)
        mate = board.is_checkmate()
        board.pop()
        if mate:
            return True
    return False


def forces_mate_in_two(board, move):
    """After `move`, every reply allows mate in one."""
    board.push(move)
    try:
        if board.is_checkmate() or not any(True for _ in board.legal_moves):
            return False
        for reply in list(board.legal_moves):
            board.push(reply)
            ok = mates_in_one(board)
            board.pop()
            if not ok:
                return False
        return True
    finally:
        board.pop()


def check_mate_in_two(puzzle, board, where):
    if mates_in_one(board):
        return [f"{where}: there is a mate in 1"]
    keys = sorted(m.uci() for m in board.legal_moves if forces_mate_in_two(board, m))
    if not keys:
        return [f"{where}: no first move forces mate in 2"]
    if sorted(puzzle["solution"]) != keys:
        return [f"{where}: forcing first moves are {keys}, solution lists {sorted(puzzle['solution'])}"]
    return []


def check_blunder(item, where):
    board = chess.Board(item["fen"])
    if not board.is_valid():
        return [f"{where}: invalid FEN ({board.status()})"]
    move = chess.Move.from_uci(item["move"])
    if move not in board.legal_moves:
        return [f"{where}: {item['move']} is not legal"]
    now = material(board)
    board.push(move)
    replies = {}
    for reply in board.legal_moves:
        board.push(reply)
        replies[reply.uci()] = negamax(board, 0, -10**9, 10**9)
        board.pop()
    after = min(replies.values()) if replies else now
    loss = now - after
    problems = []
    if item["isBlunder"]:
        if loss < WIN:
            problems.append(f"{where}: called a blunder but only loses {loss}")
        best = min(replies, key=replies.get)
        if item.get("refutation") not in replies:
            problems.append(f"{where}: refutation {item.get('refutation')} is not legal (best is {best})")
        elif replies[item["refutation"]] > after + 30:
            problems.append(f"{where}: refutation {item['refutation']} is not the best reply (best is {best})")
    elif loss > SAFE:
        problems.append(f"{where}: called safe but loses {loss}")
    return problems


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
    if puzzle.get("mateIn") == 2:
        return check_mate_in_two(puzzle, board, where)
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
    for collection in puzzles.get("collections", []):
        for puzzle in collection["puzzles"]:
            if puzzle["id"] in ids:
                problems.append(f"duplicate id {puzzle['id']}")
            ids.add(puzzle["id"])
            problems += check(puzzle, f"{collection['id']}/{puzzle['id']}")
    blunders = json.loads((RESOURCES / "blunders.json").read_text())
    for item in blunders:
        problems += check_blunder(item, f"blunder/{item['id']}")
    for problem in problems:
        print(problem)
    count = sum(len(level["puzzles"]) for level in puzzles["levels"])
    count += sum(len(c["puzzles"]) for c in puzzles.get("collections", []))
    print(f"{len(problems)} problems in {sum(len(d['puzzles']) for d in drills)} drill puzzles, {count} puzzles, and {len(blunders)} blunder checks")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
