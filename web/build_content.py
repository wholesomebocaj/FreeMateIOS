#!/usr/bin/env python3
"""Fill beginner lesson steps and bundle them for the web app."""

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
COURSES = ROOT / "Resources" / "data" / "courses"
CATALOG = ROOT / "Resources" / "FreeMateCatalog.json"
BRACKETS = ROOT / "Resources" / "data" / "brackets.json"
OPENINGS = ROOT / "Resources" / "data" / "openings"
OUT = Path(__file__).resolve().parent / "content" / "curriculum.json"

START = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"
AFTER_E4 = "rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1"
AFTER_E4_E5 = "rnbqkbnr/pppp1ppp/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR w KQkq e6 0 2"

COURSE_INFO = {
    "beginner-fundamentals": {
        "title": "Beginner Fundamentals",
        "description": "The board, square names, and how each piece moves.",
        "order": 1,
    },
    "beginner-opening-principles": {
        "title": "Opening Principles",
        "description": "Fight for the center, develop pieces, and castle.",
        "order": 2,
    },
    "beginner-tactics": {
        "title": "Basic Tactics",
        "description": "Forks, pins, and pieces left hanging.",
        "order": 3,
    },
    "beginner-endgames": {
        "title": "Check and Checkmate",
        "description": "Checkmate, stalemate, and simple king hunts.",
        "order": 4,
    },
    "beginner-practical-play": {
        "title": "Practical Play",
        "description": "A calm checklist before every move.",
        "order": 5,
    },
}

LESSON_STEPS = {
    "board-basics": [
        {
            "type": "explain",
            "title": "The board",
            "body": "Chess uses 64 squares. Columns are files a through h, left to right for White. Rows are ranks 1 through 8, counting up from White's side.",
        },
        {
            "type": "board-demo",
            "title": "Corners and the center",
            "body": "a1 is White's left corner and h1 is White's right corner. The center is d4, e4, d5, and e5.",
            "fen": START,
            "highlightSquares": ["a1", "h1", "a8", "h8", "d4", "e4", "d5", "e5"],
        },
        {
            "type": "click-all-squares",
            "title": "Find the center",
            "body": "Click d4, e4, d5, and e5.",
            "fen": START,
            "targetSquares": ["d4", "e4", "d5", "e5"],
            "highlightSquares": ["d4", "e4", "d5", "e5"],
            "successText": "Those four squares are the center.",
            "errorText": "The center is where the d and e files cross ranks 4 and 5.",
        },
        {
            "type": "square-click",
            "title": "Name e4",
            "body": "File e is the fifth file. Rank 4 is four squares up from White. Click e4.",
            "fen": START,
            "targetSquare": "e4",
            "successText": "e4 sits in front of White's king pawn.",
            "errorText": "Count a, b, c, d, e, then stop on rank 4.",
        },
        {
            "type": "multiple-choice",
            "title": "What color is a1?",
            "question": "White's left corner, a1, is which color?",
            "board": True,
            "fen": START,
            "highlightSquares": ["a1"],
            "choices": [
                {"label": "Dark", "value": "dark"},
                {"label": "Light", "value": "light"},
            ],
            "correctChoice": "dark",
            "successText": "a1 is dark. h1, White's right corner, is light.",
            "errorText": "Look at a1 again. It is the dark corner.",
        },
        {
            "type": "explain",
            "title": "Lesson recap",
            "body": "Name a square with its file, then its rank: e4, d5, h1. You will use those names in every lesson.",
        },
    ],
    "piece-movement": [
        {
            "type": "explain",
            "title": "Pieces move differently",
            "body": "Rooks slide on ranks and files. Bishops slide on diagonals. The queen does both. Knights jump in an L. Kings step one square. Pawns step forward and capture diagonally.",
        },
        {
            "type": "board-demo",
            "title": "The rook",
            "body": "A rook moves any number of empty squares along a rank or file. It cannot jump.",
            "fen": "4k3/8/8/8/3R4/8/8/4K3 w - - 0 1",
            "highlightSquares": ["d1", "d2", "d3", "d5", "d6", "d7", "d8", "a4", "b4", "c4", "e4", "f4", "g4", "h4"],
        },
        {
            "type": "move-task",
            "title": "Move the rook",
            "body": "Move the rook from d4 to d7.",
            "fen": "4k3/8/8/8/3R4/8/8/4K3 w - - 0 1",
            "startSquare": "d4",
            "targetSquare": "d7",
            "successText": "Rooks travel in straight lines.",
            "errorText": "Slide the rook straight up the d-file to d7.",
        },
        {
            "type": "board-demo",
            "title": "The bishop",
            "body": "A bishop stays on one color and moves any number of empty squares diagonally.",
            "fen": "4k3/8/8/8/3B4/8/8/4K3 w - - 0 1",
            "highlightSquares": ["a1", "b2", "c3", "e5", "f6", "g7", "h8", "a7", "b6", "c5", "e3", "f2", "g1"],
        },
        {
            "type": "move-task",
            "title": "Move the bishop",
            "body": "Move the bishop from d4 to g7.",
            "fen": "4k3/8/8/8/3B4/8/8/4K3 w - - 0 1",
            "startSquare": "d4",
            "targetSquare": "g7",
            "successText": "That diagonal is the bishop's road.",
            "errorText": "Follow the diagonal from d4 to e5, f6, and g7.",
        },
        {
            "type": "board-demo",
            "title": "The knight",
            "body": "A knight jumps in an L: two squares one way and one square sideways. It can jump over pieces.",
            "fen": "4k3/8/8/8/3N4/8/8/4K3 w - - 0 1",
            "highlightSquares": ["b3", "b5", "c2", "c6", "e2", "e6", "f3", "f5"],
        },
        {
            "type": "move-task",
            "title": "Jump the knight",
            "body": "Move the knight from d4 to f5.",
            "fen": "4k3/8/8/8/3N4/8/8/4K3 w - - 0 1",
            "startSquare": "d4",
            "targetSquare": "f5",
            "successText": "Two up and one to the side. That is the knight.",
            "errorText": "From d4, the L to f5 is two squares toward f and one square up.",
        },
        {
            "type": "move-task",
            "title": "Move the queen",
            "body": "The queen combines rook and bishop. Move her from d4 to h4.",
            "fen": "4k3/8/8/8/3Q4/8/8/4K3 w - - 0 1",
            "startSquare": "d4",
            "targetSquare": "h4",
            "successText": "The queen can use any clear rank, file, or diagonal.",
            "errorText": "Slide the queen along the fourth rank to h4.",
        },
        {
            "type": "move-task",
            "title": "Step with the king",
            "body": "The king moves one square at a time. Move the white king from e4 to e5.",
            "fen": "4k3/8/8/8/4K3/8/8/8 w - - 0 1",
            "startSquare": "e4",
            "targetSquare": "e5",
            "successText": "Kings are slow. Keep yours safe until the endgame.",
            "errorText": "The king on e4 can step one square forward to e5.",
        },
        {
            "type": "move-task",
            "title": "The pawn's first step",
            "body": "Pawns move forward. On their first move they may advance one or two squares. Play e2 to e4.",
            "fen": START,
            "startSquare": "e2",
            "targetSquare": "e4",
            "successText": "That pawn now controls d5 and f5.",
            "errorText": "Push the pawn on e2 two squares to e4.",
        },
        {
            "type": "move-task",
            "title": "Pawns capture diagonally",
            "body": "A pawn cannot capture straight ahead. Capture the black pawn by moving from d4 to e5.",
            "fen": "4k3/8/8/4p3/3P4/8/8/4K3 w - - 0 1",
            "startSquare": "d4",
            "targetSquare": "e5",
            "successText": "Pawns capture one square diagonally forward.",
            "errorText": "Move the white pawn from d4 to e5.",
        },
        {
            "type": "multiple-choice",
            "title": "Which piece can jump?",
            "question": "Which piece can leap over other pieces?",
            "choices": [
                {"label": "Rook", "value": "rook"},
                {"label": "Bishop", "value": "bishop"},
                {"label": "Knight", "value": "knight"},
                {"label": "Pawn", "value": "pawn"},
            ],
            "correctChoice": "knight",
            "successText": "Only the knight jumps. Everyone else needs a clear path.",
            "errorText": "Think of the piece that moves in an L.",
        },
        {
            "type": "board-demo",
            "title": "Check",
            "body": "Check means the king is attacked. The side in check must escape on the next move: move the king, capture the attacker, or block the attack.",
            "fen": "4k3/8/8/8/8/8/4q3/4K3 w - - 0 1",
            "highlightSquares": ["e1", "e2"],
        },
        {
            "type": "explain",
            "title": "Lesson recap",
            "body": "Learn the shape of each move before you try to attack. A legal move never leaves your own king in check.",
        },
    ],
    "center-control": [
        {
            "type": "explain",
            "title": "Why the center matters",
            "body": "Pieces in the center reach more squares. A knight in the center has eight jumps. A knight in the corner has two.",
        },
        {
            "type": "click-all-squares",
            "title": "Mark the center",
            "body": "Click the four center squares again: d4, e4, d5, and e5.",
            "fen": START,
            "targetSquares": ["d4", "d5", "e4", "e5"],
            "highlightSquares": ["d4", "d5", "e4", "e5"],
            "successText": "Fight for these squares in the opening.",
            "errorText": "Stay on d4, e4, d5, and e5.",
        },
        {
            "type": "move-task",
            "title": "Put a pawn in the center",
            "body": "Move the e-pawn from e2 to e4.",
            "fen": START,
            "startSquare": "e2",
            "targetSquare": "e4",
            "highlightSquares": ["d5", "e4", "f5"],
            "successText": "e4 claims space and opens a path for the bishop and queen.",
            "errorText": "Advance the pawn on e2 to e4.",
        },
        {
            "type": "multiple-choice",
            "title": "A useful first pawn move",
            "question": "Which pawn move fights for the center?",
            "board": True,
            "fen": START,
            "choices": [
                {"label": "a3", "value": "a3"},
                {"label": "h4", "value": "h4"},
                {"label": "e4", "value": "e4"},
                {"label": "a4", "value": "a4"},
            ],
            "correctChoice": "e4",
            "successText": "e4 and d4 are the classic central pawn moves.",
            "errorText": "Edge pawns do not control d4, e4, d5, or e5.",
        },
        {
            "type": "explain",
            "title": "Lesson recap",
            "body": "Use your first moves to influence the center. You do not have to capture there. Standing on it, or attacking it, is enough.",
        },
    ],
    "opening-goals": [
        {
            "type": "explain",
            "title": "Three opening goals",
            "body": "In the first ten moves, do three things: influence the center, develop knights and bishops, and castle your king. Do not hunt the enemy queen.",
        },
        {
            "type": "multiple-choice",
            "title": "Choose a first move",
            "question": "Which move best matches those goals?",
            "board": True,
            "fen": START,
            "choices": [
                {"label": "a4, pushing an edge pawn", "value": "a4"},
                {"label": "e4, claiming the center", "value": "e4"},
                {"label": "Qh5, bringing the queen out", "value": "qh5"},
                {"label": "Na3, putting a knight on the rim", "value": "na3"},
            ],
            "correctChoice": "e4",
            "successText": "e4 fights for the center and frees the light-squared bishop.",
            "errorText": "Start with the center, not the edge and not the queen.",
        },
        {
            "type": "move-task",
            "title": "Play a principled first move",
            "body": "Play one of these: e4, d4, c4, or Nf3.",
            "fen": START,
            "allowedMoves": ["e2e4", "d2d4", "c2c4", "g1f3"],
            "lockToAllowedMoves": True,
            "highlightSquares": ["e4", "d4", "c4", "f3"],
            "successText": "That move develops a piece or fights for the center.",
            "errorText": "Try e2-e4, d2-d4, c2-c4, or the knight from g1 to f3.",
        },
        {
            "type": "board-demo",
            "title": "After 1. e4",
            "body": "The pawn on e4 controls d5 and f5. The bishop on f1 and the queen on d1 now have diagonals.",
            "fen": AFTER_E4,
            "highlightSquares": ["e4", "d5", "f5", "f1", "d1"],
        },
        {
            "type": "explain",
            "title": "Lesson recap",
            "body": "Center, development, king safety. If a move does none of those, look for a better one.",
        },
    ],
    "develop-your-pieces": [
        {
            "type": "explain",
            "title": "Develop before you attack",
            "body": "Bring knights and bishops out before the queen and rooks. A developed piece influences the board. A piece on its home square does not.",
        },
        {
            "type": "board-demo",
            "title": "Knights like the center",
            "body": "Both sides have a pawn in the center. White's next useful job is to develop the knight from g1.",
            "fen": AFTER_E4_E5,
            "highlightSquares": ["g1", "f3", "e4", "e5"],
        },
        {
            "type": "move-task",
            "title": "Develop the knight",
            "body": "Move the knight from g1 to f3. It attacks e5 and prepares castling.",
            "fen": AFTER_E4_E5,
            "startSquare": "g1",
            "targetSquare": "f3",
            "successText": "Nf3 develops with a purpose: it eyes the center.",
            "errorText": "Move the knight on g1 to f3.",
        },
        {
            "type": "multiple-choice",
            "title": "Leave the queen at home",
            "question": "Why should beginners delay queen moves?",
            "choices": [
                {"label": "The queen is not allowed to move early", "value": "illegal"},
                {"label": "Early queen moves lose time when the opponent attacks her", "value": "tempo"},
                {"label": "The queen cannot move until a pawn has captured", "value": "pawn"},
            ],
            "correctChoice": "tempo",
            "successText": "Develop minor pieces first. The queen joins once she has a clear job.",
            "errorText": "The queen is legal early. She just becomes a target.",
        },
        {
            "type": "explain",
            "title": "Lesson recap",
            "body": "Develop knights toward the center, then bishops, then castle. Rooks belong on open or half-open files later.",
        },
    ],
    "king-safety": [
        {
            "type": "explain",
            "title": "Castle early",
            "body": "Castling moves the king away from the center and brings a rook toward the action. You may castle once per game, and only if the king and that rook have not moved.",
        },
        {
            "type": "board-demo",
            "title": "Ready to castle",
            "body": "The knight and the light-squared bishop are out. The squares between the king and the h1 rook are empty.",
            "fen": "rnbqk2r/pppp1ppp/5n2/2b1p3/2B1P3/5N2/PPPP1PPP/RNBQK2R w KQkq - 4 4",
            "highlightSquares": ["e1", "f1", "g1", "h1"],
        },
        {
            "type": "move-task",
            "title": "Castle kingside",
            "body": "Move the king from e1 to g1. The rook will jump to f1.",
            "fen": "rnbqk2r/pppp1ppp/5n2/2b1p3/2B1P3/5N2/PPPP1PPP/RNBQK2R w KQkq - 4 4",
            "startSquare": "e1",
            "targetSquare": "g1",
            "successText": "The king is safer, and the rook has entered the game.",
            "errorText": "Slide the king two squares toward the rook, from e1 to g1.",
        },
        {
            "type": "multiple-choice",
            "title": "When castling is illegal",
            "question": "Which condition stops you from castling?",
            "choices": [
                {"label": "Your king is in check and stays on an attacked square", "value": "check"},
                {"label": "You have already moved a pawn", "value": "pawn"},
                {"label": "The opponent has more pieces", "value": "material"},
            ],
            "correctChoice": "check",
            "successText": "You also cannot castle through check, out of check, or if the king or rook has moved.",
            "errorText": "Pawn moves do not by themselves cancel castling. Check does.",
        },
        {
            "type": "explain",
            "title": "Lesson recap",
            "body": "Castle before you attack. A king left on e1 is a target once the center opens.",
        },
    ],
    "forks": [
        {
            "type": "explain",
            "title": "One move, two targets",
            "body": "A fork is a move that attacks two pieces at once. The opponent can usually save only one. Knights are famous for forks because their L-shaped jump is hard to see.",
        },
        {
            "type": "board-demo",
            "title": "A knight fork",
            "body": "The knight on c7 attacks the king on a8 and the rook on e8 at the same time.",
            "fen": "k3r3/2N5/8/8/8/8/8/4K3 b - - 0 1",
            "highlightSquares": ["c7", "a8", "e8"],
        },
        {
            "type": "move-task",
            "title": "Fork the king and queen",
            "body": "Move the knight from d4 to f5. It will check the king and attack the queen.",
            "fen": "8/6k1/8/8/3N4/4q3/8/K7 w - - 0 1",
            "startSquare": "d4",
            "targetSquare": "f5",
            "highlightSquares": ["f5", "g7", "e3"],
            "successText": "f5 attacks g7 and e3. That is a fork.",
            "errorText": "Jump the knight from d4 to f5.",
        },
        {
            "type": "move-task",
            "title": "A pawn fork",
            "body": "Push the pawn from d2 to d4. From d4 it attacks both black knights.",
            "fen": "4k3/8/8/2n1n3/8/8/3P4/4K3 w - - 0 1",
            "startSquare": "d2",
            "targetSquare": "d4",
            "highlightSquares": ["d4", "c5", "e5"],
            "successText": "Pawns fork on the two squares they attack diagonally.",
            "errorText": "Advance the d2 pawn two squares to d4.",
        },
        {
            "type": "multiple-choice",
            "title": "Spot the idea",
            "question": "What makes a fork powerful?",
            "choices": [
                {"label": "It attacks two things, so one can be won", "value": "two"},
                {"label": "It always checkmates", "value": "mate"},
                {"label": "It lets a pawn move backward", "value": "back"},
            ],
            "correctChoice": "two",
            "successText": "Look for one piece that can attack two undefended or valuable targets.",
            "errorText": "A fork is about two targets, not an automatic mate.",
        },
        {
            "type": "explain",
            "title": "Lesson recap",
            "body": "Before you move, ask: does my opponent have a fork? After you move, ask the same question about your own pieces.",
        },
    ],
    "pins": [
        {
            "type": "explain",
            "title": "A piece that cannot move",
            "body": "A pin happens when a piece stands between your attacker and a more valuable piece, often the king. If the pinned piece is shielding the king, moving it would be illegal.",
        },
        {
            "type": "board-demo",
            "title": "An absolute pin",
            "body": "The bishop on b5 looks through the knight on c6 to the king on e8. The knight cannot legally move.",
            "fen": "4k3/8/2n5/1B6/8/8/8/4K3 w - - 0 1",
            "highlightSquares": ["b5", "c6", "e8"],
        },
        {
            "type": "move-task",
            "title": "Create the pin",
            "body": "Move the bishop from f1 to b5. It will pin the knight on c6 to the king.",
            "fen": "4k3/8/2n5/8/8/8/8/5BK1 w - - 0 1",
            "startSquare": "f1",
            "targetSquare": "b5",
            "highlightSquares": ["b5", "c6", "e8"],
            "successText": "The knight is pinned. Capturing it next is often the idea.",
            "errorText": "Travel the diagonal from f1 to b5.",
        },
        {
            "type": "multiple-choice",
            "title": "Can the knight move?",
            "question": "The knight on c6 is pinned to the king by the bishop. What is true?",
            "board": True,
            "fen": "4k3/8/2n5/1B6/8/8/8/4K3 b - - 0 1",
            "highlightSquares": ["b5", "c6", "e8"],
            "choices": [
                {"label": "The knight can capture the bishop", "value": "capture"},
                {"label": "Moving the knight would expose the king, so it is illegal", "value": "illegal"},
                {"label": "Pins only apply to pawns", "value": "pawns"},
            ],
            "correctChoice": "illegal",
            "successText": "That is an absolute pin. Relative pins against a queen are legal, but usually costly.",
            "errorText": "Look along the diagonal from the bishop through the knight to the king.",
        },
        {
            "type": "explain",
            "title": "Lesson recap",
            "body": "Rooks, bishops, and queens create pins. When you see three pieces on a line, ask who is pinned.",
        },
    ],
    "hanging-pieces": [
        {
            "type": "explain",
            "title": "Hanging means undefended",
            "body": "A hanging piece can be captured for free. Most beginner games are decided by one piece left without a defender.",
        },
        {
            "type": "board-demo",
            "title": "The queen is loose",
            "body": "Black's queen on d5 has no defender. White's rook looks straight up the d-file.",
            "fen": "4k3/8/8/3q4/8/8/8/3R2K1 w - - 0 1",
            "highlightSquares": ["d1", "d5"],
        },
        {
            "type": "move-task",
            "title": "Take the hanging queen",
            "body": "Capture the queen with the rook, from d1 to d5.",
            "fen": "4k3/8/8/3q4/8/8/8/3R2K1 w - - 0 1",
            "startSquare": "d1",
            "targetSquare": "d5",
            "successText": "You won the queen because nothing defended it.",
            "errorText": "Move the rook from d1 to d5.",
        },
        {
            "type": "multiple-choice",
            "title": "Before you grab",
            "question": "You see a free pawn. What should you check first?",
            "choices": [
                {"label": "Whether taking it hangs one of your own pieces", "value": "safe"},
                {"label": "Whether you have castled on the opposite wing", "value": "wing"},
                {"label": "The color of the square the pawn sits on", "value": "color"},
            ],
            "correctChoice": "safe",
            "successText": "A free pawn is not free if you lose a piece to take it.",
            "errorText": "Ask what the opponent can capture after your move.",
        },
        {
            "type": "explain",
            "title": "Lesson recap",
            "body": "Scan every enemy piece that attacks one of yours. If a piece has no friend defending it, it is hanging.",
        },
    ],
    "before-you-move": [
        {
            "type": "explain",
            "title": "Pause for one breath",
            "body": "Fast moves lose pieces. Before every move, name the check, the captures, and the threat on the board.",
        },
        {
            "type": "checklist",
            "title": "A simple checklist",
            "body": "Use this list until it becomes a habit.",
            "tasks": [
                "Am I in check?",
                "Did my opponent leave a piece hanging?",
                "Will my move hang a piece or allow a fork?",
                "Is my king still safe?",
            ],
        },
        {
            "type": "multiple-choice",
            "title": "The tempting pawn",
            "question": "You can capture a pawn, but the capture leaves your queen on a square attacked by a rook. What do you do?",
            "choices": [
                {"label": "Take the pawn. Pawns win games.", "value": "take"},
                {"label": "Save the queen. Material matters more than one pawn.", "value": "save"},
                {"label": "Move the king for no reason.", "value": "king"},
            ],
            "correctChoice": "save",
            "successText": "Keep the queen. Look for the pawn again after she is safe.",
            "errorText": "A queen is worth far more than a pawn.",
        },
        {
            "type": "board-demo",
            "title": "See the danger first",
            "body": "The rook on d8 attacks the white queen down the open d-file. Saving the queen comes before any attack.",
            "fen": "3rk3/8/8/8/8/8/8/3QK3 w - - 0 1",
            "highlightSquares": ["d1", "d8"],
        },
        {
            "type": "explain",
            "title": "Lesson recap",
            "body": "One quiet look prevents most blunders. Checks, captures, threats, then your plan.",
        },
    ],
    "checks-captures-threats": [
        {
            "type": "explain",
            "title": "Look in this order",
            "body": "Checks come first because they demand an answer. Then captures, especially of undefended pieces. Then threats such as forks and pins.",
        },
        {
            "type": "board-demo",
            "title": "This is check",
            "body": "The queen on e2 attacks the king on e1. White must answer the check.",
            "fen": "4k3/8/8/8/8/8/4q3/4K3 w - - 0 1",
            "highlightSquares": ["e2", "e1"],
        },
        {
            "type": "move-task",
            "title": "Capture the checker",
            "body": "The queen is unprotected. Take it with the king, from e1 to e2.",
            "fen": "4k3/8/8/8/8/8/4q3/4K3 w - - 0 1",
            "startSquare": "e1",
            "targetSquare": "e2",
            "successText": "Capturing the checking piece is one of the three ways out of check.",
            "errorText": "Move the king from e1 to e2.",
        },
        {
            "type": "move-task",
            "title": "Step out of check",
            "body": "The queen on e3 checks along the file. Move the king to d1 or f1.",
            "fen": "4k3/8/8/8/8/4q3/8/4K3 w - - 0 1",
            "allowedMoves": ["e1d1", "e1f1"],
            "lockToAllowedMoves": True,
            "highlightSquares": ["d1", "f1", "e3"],
            "successText": "Moving the king off the line also escapes check.",
            "errorText": "Step to d1 or f1. Both squares are safe.",
        },
        {
            "type": "multiple-choice",
            "title": "The third way out",
            "question": "Besides moving the king or capturing the checker, how else can you escape check from a sliding piece?",
            "choices": [
                {"label": "Block the line with another piece", "value": "block"},
                {"label": "Skip your turn", "value": "skip"},
                {"label": "Move a pawn backward", "value": "back"},
            ],
            "correctChoice": "block",
            "successText": "Interposing works against rooks, bishops, and queens. It does not work against knights.",
            "errorText": "Put something in the way of a rook, bishop, or queen.",
        },
        {
            "type": "explain",
            "title": "Lesson recap",
            "body": "Checks, then captures, then threats. Use that scan on your opponent's move and on the move you are about to play.",
        },
    ],
    "simple-blunder-check": [
        {
            "type": "explain",
            "title": "One question saves games",
            "body": "After the move you want to play, ask: can my opponent checkmate me or win a piece for free? If yes, pick another move.",
        },
        {
            "type": "move-task",
            "title": "Save the queen",
            "body": "The rook on d8 attacks your queen. Move the queen off the d-file, or capture the rook.",
            "fen": "3rk3/8/8/8/8/8/8/3QK3 w - - 0 1",
            "allowedMoves": ["d1d8", "d1a4", "d1h5", "d1c2", "d1e2", "d1b3", "d1f3", "d1g4", "d1c1", "d1b1", "d1a1"],
            "lockToAllowedMoves": True,
            "highlightSquares": ["d1", "d8"],
            "successText": "The queen is safe. That is the whole lesson.",
            "errorText": "Leave the d-file, or capture the rook on d8. Moving the king leaves the queen hanging.",
        },
        {
            "type": "multiple-choice",
            "title": "What is a blunder?",
            "question": "Which move is a blunder?",
            "choices": [
                {"label": "A move that drops a piece or allows mate", "value": "drop"},
                {"label": "Any move that does not give check", "value": "check"},
                {"label": "Castling kingside", "value": "castle"},
            ],
            "correctChoice": "drop",
            "successText": "Quiet moves are fine. Dropping a piece is not.",
            "errorText": "A blunder loses something important. Castling is usually good.",
        },
        {
            "type": "explain",
            "title": "Lesson recap",
            "body": "You do not need a long combination to improve. Stop hanging pieces, answer checks, and castle.",
        },
    ],
}

MINUTES = {
    "board-basics": 6,
    "piece-movement": 10,
    "center-control": 5,
    "opening-goals": 6,
    "develop-your-pieces": 6,
    "king-safety": 6,
    "forks": 7,
    "pins": 6,
    "hanging-pieces": 6,
    "checkmate-basics": 6,
    "queen-vs-king": 6,
    "rook-vs-king": 6,
    "before-you-move": 5,
    "checks-captures-threats": 7,
    "simple-blunder-check": 5,
}

DRILLS = [
    {
        "id": "mate-in-one",
        "title": "Mate in one",
        "summary": "Find the move that ends the game.",
        "puzzles": [
            {
                "id": "back-rank",
                "prompt": "White to move. Find checkmate.",
                "fen": "6k1/5ppp/8/8/8/8/8/R5K1 w - - 0 1",
                "solution": ["a1a8"],
                "mate": True,
                "hint": "The rook can reach the 8th rank. Black's pawns block the king.",
                "success": "Back-rank mate. The king has no flight square.",
            },
            {
                "id": "queen-mate",
                "prompt": "White to move. Checkmate the king on h8.",
                "fen": "7k/Q7/6K1/8/8/8/8/8 w - - 0 1",
                "solution": ["a7g7"],
                "mate": True,
                "hint": "Slide the queen along the 7th rank, next to the king. Your king protects her.",
                "success": "Qg7 is mate. The queen is protected by the king.",
            },
            {
                "id": "scholars",
                "prompt": "White to move. The bishop on c4 eyes f7.",
                "fen": "r1bqkbnr/pppp1ppp/2n5/4p2Q/2B1P3/8/PPPP1PPP/RNB1K1NR w KQkq - 4 4",
                "solution": ["h5f7"],
                "mate": True,
                "hint": "The queen captures on f7, and the bishop protects her.",
                "success": "Qxf7 is checkmate. This is the idea behind Scholar's Mate.",
            },
        ],
    },
    {
        "id": "forks",
        "title": "Forks",
        "summary": "Attack two pieces with one move.",
        "puzzles": [
            {
                "id": "knight-fork",
                "prompt": "Fork the king and the queen.",
                "fen": "8/6k1/8/8/3N4/4q3/8/K7 w - - 0 1",
                "solution": ["d4f5"],
                "hint": "The knight on d4 has a jump that hits g7 and e3.",
                "success": "Nf5 checks the king and attacks the queen.",
            },
            {
                "id": "royal-fork",
                "prompt": "Fork the king on e8 and the rook on a8.",
                "fen": "r3k3/8/8/3N4/8/8/8/4K3 w - - 0 1",
                "solution": ["d5c7"],
                "hint": "Look for a knight jump to c7.",
                "success": "Nc7 attacks the king and the rook.",
            },
            {
                "id": "pawn-fork",
                "prompt": "Push a pawn so it attacks both knights.",
                "fen": "4k3/8/8/2n1n3/8/8/3P4/4K3 w - - 0 1",
                "solution": ["d2d4"],
                "hint": "A pawn on d4 attacks c5 and e5.",
                "success": "d4 forks the two knights.",
            },
        ],
    },
    {
        "id": "pins",
        "title": "Pins",
        "summary": "Line up an attacker, a piece, and the king.",
        "puzzles": [
            {
                "id": "bishop-pin",
                "prompt": "Pin the knight on c6 to the king.",
                "fen": "4k3/8/2n5/8/8/8/8/5BK1 w - - 0 1",
                "solution": ["f1b5"],
                "hint": "The bishop wants the diagonal that runs through c6.",
                "success": "Bb5 pins the knight. It cannot move without exposing the king.",
            },
            {
                "id": "rook-pin",
                "prompt": "Pin the knight on e5 to the king on e8.",
                "fen": "4k3/8/8/4n3/8/8/8/R5K1 w - - 0 1",
                "solution": ["a1e1"],
                "hint": "Use the e-file.",
                "success": "The rook pins the knight. Moving it would expose the king.",
            },
        ],
    },
    {
        "id": "hanging",
        "title": "Hanging pieces",
        "summary": "Take the piece that nobody defends.",
        "puzzles": [
            {
                "id": "loose-queen",
                "prompt": "Win the undefended queen.",
                "fen": "4k3/8/8/3q4/8/8/8/3R2K1 w - - 0 1",
                "solution": ["d1d5"],
                "hint": "The rook and the queen share the d-file.",
                "success": "Rxd5 wins the queen.",
            },
            {
                "id": "loose-knight",
                "prompt": "The knight on d5 is undefended. Capture it.",
                "fen": "4k3/8/8/3n4/8/8/B7/4K3 w - - 0 1",
                "solution": ["a2d5"],
                "hint": "The bishop on a2 has a clear diagonal.",
                "success": "Bxd5 picks up the knight for free.",
            },
        ],
    },
    {
        "id": "out-of-check",
        "title": "Get out of check",
        "summary": "Move the king, capture the checker, or block.",
        "puzzles": [
            {
                "id": "capture-checker",
                "prompt": "You are in check. Capture the unprotected queen.",
                "fen": "4k3/8/8/8/8/8/4q3/4K3 w - - 0 1",
                "solution": ["e1e2"],
                "hint": "The checking queen is next to your king and has no defender.",
                "success": "Kxe2 captures the checker.",
            },
            {
                "id": "step-aside",
                "prompt": "Step the king off the e-file. Either safe square works.",
                "fen": "4k3/8/8/8/8/4q3/8/4K3 w - - 0 1",
                "solution": ["e1d1", "e1f1"],
                "hint": "d1 and f1 are not on the queen's line.",
                "success": "The king left the file, so the check is over.",
            },
            {
                "id": "block",
                "prompt": "Block the rook check by putting the queen on e2.",
                "fen": "4r1k1/8/8/8/8/8/8/3QK3 w - - 0 1",
                "solution": ["d1e2"],
                "hint": "The check runs down the e-file. Stand on e2.",
                "success": "Qe2 blocks the check.",
            },
        ],
    },
]


def main_line(opening):
    sections = opening.get("sections") or []
    if not sections:
        return []
    branches = sections[0].get("branches") or []
    if not branches:
        return []
    moves = []
    for move in branches[0].get("moves") or []:
        moves.append(
            {
                "uci": move.get("uci"),
                "san": move.get("san"),
                "title": move.get("title") or "",
                "explanation": move.get("explanation") or "",
            }
        )
    return moves


def load_lessons():
    lessons = []
    for path in sorted(COURSES.glob("*/*.json")):
        lesson = json.loads(path.read_text())
        if lesson["id"] in LESSON_STEPS:
            lesson["steps"] = LESSON_STEPS[lesson["id"]]
        lesson["timeMinutes"] = MINUTES.get(lesson["id"], 6)
        path.write_text(json.dumps(lesson, indent=2) + "\n")
        lessons.append((path.parent.name, lesson))
    return lessons


def patch_catalog(by_id):
    catalog = json.loads(CATALOG.read_text())
    for folder in catalog.get("courseFolders", []):
        for entry in folder.get("files", []):
            lesson = entry.get("lesson") or {}
            updated = by_id.get(lesson.get("id"))
            if updated:
                lesson["steps"] = updated["steps"]
                lesson["timeMinutes"] = updated["timeMinutes"]
    CATALOG.write_text(json.dumps(catalog, separators=(",", ":"), ensure_ascii=True) + "\n")


def main():
    loaded = load_lessons()
    by_id = {lesson["id"]: lesson for _, lesson in loaded}
    courses = []
    for course_id, info in sorted(COURSE_INFO.items(), key=lambda item: item[1]["order"]):
        course_lessons = [lesson for folder, lesson in loaded if folder == course_id]
        course_lessons.sort(key=lambda lesson: lesson.get("order", 0))
        courses.append(
            {
                "id": course_id,
                "title": info["title"],
                "description": info["description"],
                "lessons": course_lessons,
            }
        )
    openings = []
    for path in sorted(OPENINGS.glob("*/*.json")):
        opening = json.loads(path.read_text())
        openings.append(
            {
                "id": opening["id"],
                "name": opening.get("name"),
                "eco": opening.get("eco") or "",
                "difficulty": opening.get("difficulty") or "Beginner",
                "side": (opening.get("training") or {}).get("sideToTrain") or opening.get("side") or "white",
                "description": opening.get("description") or "",
                "ideas": opening.get("ideas") or [],
                "commonMistakes": opening.get("commonMistakes") or [],
                "moves": main_line(opening),
            }
        )
    openings.sort(key=lambda item: (item["difficulty"], item["name"]))
    bundle = {
        "courses": courses,
        "brackets": json.loads(BRACKETS.read_text()),
        "openings": openings,
        "drills": DRILLS,
    }
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(bundle, indent=2) + "\n")
    patch_catalog(by_id)
    print(f"lessons {len(by_id)} openings {len(openings)} drills {sum(len(d['puzzles']) for d in DRILLS)}")


if __name__ == "__main__":
    main()
