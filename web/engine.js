/** Legal chess rules used by lessons, drills, and play. */

export const START_FEN = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1";

const FILES = "abcdefgh";
const VALUES = { p: 100, n: 320, b: 330, r: 500, q: 900, k: 0 };
const KNIGHT = [[1, 2], [2, 1], [2, -1], [1, -2], [-1, -2], [-2, -1], [-2, 1], [-1, 2]];
const KING = [[1, 0], [1, 1], [0, 1], [-1, 1], [-1, 0], [-1, -1], [0, -1], [1, -1]];
const ROOK_DIR = [[1, 0], [-1, 0], [0, 1], [0, -1]];
const BISHOP_DIR = [[1, 1], [1, -1], [-1, 1], [-1, -1]];

const PST = {
  p: [
    0, 0, 0, 0, 0, 0, 0, 0,
    5, 10, 10, -20, -20, 10, 10, 5,
    5, -5, -10, 0, 0, -10, -5, 5,
    0, 0, 0, 20, 20, 0, 0, 0,
    5, 5, 10, 25, 25, 10, 5, 5,
    10, 10, 20, 30, 30, 20, 10, 10,
    50, 50, 50, 50, 50, 50, 50, 50,
    0, 0, 0, 0, 0, 0, 0, 0,
  ],
  n: [
    -50, -40, -30, -30, -30, -30, -40, -50,
    -40, -20, 0, 0, 0, 0, -20, -40,
    -30, 0, 10, 15, 15, 10, 0, -30,
    -30, 5, 15, 20, 20, 15, 5, -30,
    -30, 0, 15, 20, 20, 15, 0, -30,
    -30, 5, 10, 15, 15, 10, 5, -30,
    -40, -20, 0, 5, 5, 0, -20, -40,
    -50, -40, -30, -30, -30, -30, -40, -50,
  ],
  b: [
    -20, -10, -10, -10, -10, -10, -10, -20,
    -10, 0, 0, 0, 0, 0, 0, -10,
    -10, 0, 5, 10, 10, 5, 0, -10,
    -10, 5, 5, 10, 10, 5, 5, -10,
    -10, 0, 10, 10, 10, 10, 0, -10,
    -10, 10, 10, 10, 10, 10, 10, -10,
    -10, 5, 0, 0, 0, 0, 5, -10,
    -20, -10, -10, -10, -10, -10, -10, -20,
  ],
  r: [
    0, 0, 0, 0, 0, 0, 0, 0,
    5, 10, 10, 10, 10, 10, 10, 5,
    -5, 0, 0, 0, 0, 0, 0, -5,
    -5, 0, 0, 0, 0, 0, 0, -5,
    -5, 0, 0, 0, 0, 0, 0, -5,
    -5, 0, 0, 0, 0, 0, 0, -5,
    -5, 0, 0, 0, 0, 0, 0, -5,
    0, 0, 0, 5, 5, 0, 0, 0,
  ],
  q: [
    -20, -10, -10, -5, -5, -10, -10, -20,
    -10, 0, 0, 0, 0, 0, 0, -10,
    -10, 0, 5, 5, 5, 5, 0, -10,
    -5, 0, 5, 5, 5, 5, 0, -5,
    0, 0, 5, 5, 5, 5, 0, -5,
    -10, 5, 5, 5, 5, 5, 0, -10,
    -10, 0, 5, 0, 0, 0, 0, -10,
    -20, -10, -10, -5, -5, -10, -10, -20,
  ],
  k: [
    20, 30, 10, 0, 0, 10, 30, 20,
    20, 20, 0, 0, 0, 0, 20, 20,
    -10, -20, -20, -20, -20, -20, -20, -10,
    -20, -30, -30, -40, -40, -30, -30, -20,
    -30, -40, -40, -50, -50, -40, -40, -30,
    -30, -40, -40, -50, -50, -40, -40, -30,
    -30, -40, -40, -50, -50, -40, -40, -30,
    -30, -40, -40, -50, -50, -40, -40, -30,
  ],
};

export function squareName(index) {
  return FILES[index % 8] + String((index / 8 | 0) + 1);
}

export function squareIndex(name) {
  if (!name || name.length < 2) return -1;
  const file = name.charCodeAt(0) - 97;
  const rank = name.charCodeAt(1) - 49;
  if (file < 0 || file > 7 || rank < 0 || rank > 7) return -1;
  return rank * 8 + file;
}

export function uciOf(move) {
  return squareName(move.from) + squareName(move.to) + (move.promo || "");
}

export class Chess {
  constructor(fen = START_FEN) {
    this.board = Array(64).fill(null);
    this.turn = "w";
    this.castling = "KQkq";
    this.ep = -1;
    this.halfmove = 0;
    this.fullmove = 1;
    this.load(fen);
  }

  load(fen) {
    const parts = String(fen || "").trim().split(/\s+/);
    if (parts.length < 4) throw new Error("FEN must include placement, turn, castling, and en passant.");
    const ranks = parts[0].split("/");
    if (ranks.length !== 8) throw new Error("FEN must contain 8 ranks.");
    this.board = Array(64).fill(null);
    for (let r = 0; r < 8; r += 1) {
      let file = 0;
      const rank = 7 - r;
      for (const ch of ranks[r]) {
        if (ch >= "1" && ch <= "8") {
          file += Number(ch);
        } else {
          const type = ch.toLowerCase();
          if (!"pnbrqk".includes(type) || file > 7) throw new Error(`Unsupported FEN piece: ${ch}`);
          this.board[rank * 8 + file] = { color: ch === type ? "b" : "w", type };
          file += 1;
        }
      }
      if (file !== 8) throw new Error("Each FEN rank must contain 8 files.");
    }
    this.turn = parts[1] === "b" ? "b" : "w";
    this.castling = parts[2] === "-" ? "" : parts[2];
    this.ep = parts[3] === "-" ? -1 : squareIndex(parts[3]);
    this.halfmove = Number(parts[4] || 0);
    this.fullmove = Number(parts[5] || 1);
    return this;
  }

  fen() {
    const ranks = [];
    for (let rank = 7; rank >= 0; rank -= 1) {
      let row = "";
      let empty = 0;
      for (let file = 0; file < 8; file += 1) {
        const piece = this.board[rank * 8 + file];
        if (!piece) {
          empty += 1;
          continue;
        }
        if (empty) {
          row += empty;
          empty = 0;
        }
        const letter = piece.type;
        row += piece.color === "w" ? letter.toUpperCase() : letter;
      }
      if (empty) row += empty;
      ranks.push(row);
    }
    return [
      ranks.join("/"),
      this.turn,
      this.castling || "-",
      this.ep >= 0 ? squareName(this.ep) : "-",
      this.halfmove,
      this.fullmove,
    ].join(" ");
  }

  clone() {
    const copy = new Chess(START_FEN);
    copy.board = this.board.map((piece) => (piece ? { ...piece } : null));
    copy.turn = this.turn;
    copy.castling = this.castling;
    copy.ep = this.ep;
    copy.halfmove = this.halfmove;
    copy.fullmove = this.fullmove;
    return copy;
  }

  pieceAt(square) {
    const index = typeof square === "number" ? square : squareIndex(square);
    return index < 0 ? null : this.board[index];
  }

  kingSquare(color) {
    for (let i = 0; i < 64; i += 1) {
      const piece = this.board[i];
      if (piece && piece.color === color && piece.type === "k") return i;
    }
    return -1;
  }

  inCheck(color = this.turn) {
    const king = this.kingSquare(color);
    return king >= 0 && this.isAttacked(king, color === "w" ? "b" : "w");
  }

  legalMoves(fromSquare = null, { san = true } = {}) {
    const fromIndex = fromSquare == null ? null : typeof fromSquare === "number" ? fromSquare : squareIndex(fromSquare);
    const moves = [];
    for (let from = 0; from < 64; from += 1) {
      if (fromIndex != null && from !== fromIndex) continue;
      const piece = this.board[from];
      if (!piece || piece.color !== this.turn) continue;
      for (const move of this.pseudoMoves(from, piece)) {
        if (this.isLegal(move)) moves.push(move);
      }
    }
    if (san) this.addSan(moves);
    return moves;
  }

  move(from, to, promo = "q") {
    const origin = typeof from === "number" ? from : squareIndex(from);
    const target = typeof to === "number" ? to : squareIndex(to);
    const wanted = (promo || "q").toLowerCase();
    const match = this.legalMoves(origin).find((move) => move.to === target && (move.promo || "") === (this.needsPromo(origin, target) ? wanted : ""));
    if (!match) return null;
    this.play(match);
    return match;
  }

  play(move) {
    const piece = this.board[move.from];
    const captured = this.board[move.capturedSquare] || this.board[move.to];
    this.board[move.from] = null;
    if (move.ep) this.board[move.capturedSquare] = null;
    this.board[move.to] = { color: piece.color, type: move.promo || piece.type };
    if (move.castle === "K") {
      this.board[7] = null;
      this.board[5] = { color: "w", type: "r" };
    } else if (move.castle === "Q") {
      this.board[0] = null;
      this.board[3] = { color: "w", type: "r" };
    } else if (move.castle === "k") {
      this.board[63] = null;
      this.board[61] = { color: "b", type: "r" };
    } else if (move.castle === "q") {
      this.board[56] = null;
      this.board[59] = { color: "b", type: "r" };
    }
    this.castling = this.nextCastling(move, piece);
    if (piece.type === "p" && Math.abs(move.to - move.from) === 16) {
      this.ep = (move.from + move.to) / 2;
    } else {
      this.ep = -1;
    }
    if (piece.type === "p" || captured) this.halfmove = 0;
    else this.halfmove += 1;
    if (this.turn === "b") this.fullmove += 1;
    this.turn = this.turn === "w" ? "b" : "w";
    return move;
  }

  isCheckmate() {
    return this.inCheck() && this.legalMoves().length === 0;
  }

  isStalemate() {
    return !this.inCheck() && this.legalMoves().length === 0;
  }

  isInsufficientMaterial() {
    const pieces = this.board.filter(Boolean);
    if (pieces.length === 2) return true;
    if (pieces.length === 3 && pieces.some((piece) => piece.type === "n" || piece.type === "b")) return true;
    return false;
  }

  isDraw() {
    return this.isStalemate() || this.halfmove >= 100 || this.isInsufficientMaterial();
  }

  isGameOver() {
    return this.isCheckmate() || this.isDraw();
  }

  result() {
    if (this.isCheckmate()) return { over: true, winner: this.turn === "w" ? "black" : "white", reason: "checkmate" };
    if (this.isStalemate()) return { over: true, winner: null, reason: "stalemate" };
    if (this.halfmove >= 100) return { over: true, winner: null, reason: "fifty-move" };
    if (this.isInsufficientMaterial()) return { over: true, winner: null, reason: "insufficient" };
    if (this.inCheck()) return { over: false, winner: null, reason: "check" };
    return { over: false, winner: null, reason: "" };
  }

  isAttacked(target, byColor) {
    const file = target % 8;
    const rank = target / 8 | 0;
    const pawnRank = rank + (byColor === "w" ? -1 : 1);
    if (pawnRank >= 0 && pawnRank <= 7) {
      for (const df of [-1, 1]) {
        const pf = file + df;
        if (pf < 0 || pf > 7) continue;
        const pawn = this.board[pawnRank * 8 + pf];
        if (pawn && pawn.color === byColor && pawn.type === "p") return true;
      }
    }
    for (const [df, dr] of KNIGHT) {
      const f = file + df;
      const r = rank + dr;
      if (f < 0 || f > 7 || r < 0 || r > 7) continue;
      const knight = this.board[r * 8 + f];
      if (knight && knight.color === byColor && knight.type === "n") return true;
    }
    for (const [df, dr] of KING) {
      const f = file + df;
      const r = rank + dr;
      if (f < 0 || f > 7 || r < 0 || r > 7) continue;
      const king = this.board[r * 8 + f];
      if (king && king.color === byColor && king.type === "k") return true;
    }
    const rays = [
      ...ROOK_DIR.map((dir) => ({ dir, types: "rq" })),
      ...BISHOP_DIR.map((dir) => ({ dir, types: "bq" })),
    ];
    for (const { dir, types } of rays) {
      let f = file + dir[0];
      let r = rank + dir[1];
      while (f >= 0 && f <= 7 && r >= 0 && r <= 7) {
        const piece = this.board[r * 8 + f];
        if (piece) {
          if (piece.color === byColor && types.includes(piece.type)) return true;
          break;
        }
        f += dir[0];
        r += dir[1];
      }
    }
    return false;
  }

  pseudoMoves(from, piece) {
    const moves = [];
    const file = from % 8;
    const rank = from / 8 | 0;
    const push = (to, extra = {}) => {
      if (to < 0 || to > 63) return;
      const target = this.board[to];
      if (target && target.color === piece.color) return;
      moves.push({
        from,
        to,
        color: piece.color,
        piece: piece.type,
        capture: extra.capture || (target ? target.type : null),
        capturedSquare: extra.capturedSquare ?? (target ? to : -1),
        promo: extra.promo || null,
        castle: extra.castle || null,
        ep: Boolean(extra.ep),
      });
    };
    if (piece.type === "p") {
      const dir = piece.color === "w" ? 8 : -8;
      const startRank = piece.color === "w" ? 1 : 6;
      const one = from + dir;
      if (one >= 0 && one < 64 && !this.board[one]) {
        this.addPawnMoves(push, from, one, piece);
        if (rank === startRank) {
          const two = from + dir * 2;
          if (!this.board[two]) push(two);
        }
      }
      for (const df of [-1, 1]) {
        const f = file + df;
        if (f < 0 || f > 7) continue;
        const to = from + dir + df;
        if (to < 0 || to > 63) continue;
        if (this.board[to] && this.board[to].color !== piece.color) this.addPawnMoves(push, from, to, piece);
        if (to === this.ep) {
          push(to, { capture: "p", capturedSquare: to - dir, ep: true });
        }
      }
      return moves;
    }
    if (piece.type === "n") {
      for (const [df, dr] of KNIGHT) {
        const f = file + df;
        const r = rank + dr;
        if (f < 0 || f > 7 || r < 0 || r > 7) continue;
        push(r * 8 + f);
      }
      return moves;
    }
    if (piece.type === "k") {
      for (const [df, dr] of KING) {
        const f = file + df;
        const r = rank + dr;
        if (f < 0 || f > 7 || r < 0 || r > 7) continue;
        push(r * 8 + f);
      }
      this.addCastles(push, piece);
      return moves;
    }
    const dirs = piece.type === "b" ? BISHOP_DIR : piece.type === "r" ? ROOK_DIR : [...ROOK_DIR, ...BISHOP_DIR];
    for (const [df, dr] of dirs) {
      let f = file + df;
      let r = rank + dr;
      while (f >= 0 && f <= 7 && r >= 0 && r <= 7) {
        const to = r * 8 + f;
        push(to);
        if (this.board[to]) break;
        f += df;
        r += dr;
      }
    }
    return moves;
  }

  addPawnMoves(push, from, to, piece) {
    const promoRank = piece.color === "w" ? 7 : 0;
    if ((to / 8 | 0) === promoRank) {
      for (const promo of ["q", "r", "b", "n"]) push(to, { promo });
      return;
    }
    push(to);
  }

  addCastles(push, piece) {
    const enemy = piece.color === "w" ? "b" : "w";
    if (piece.color === "w" && this.castling.includes("K") && !this.board[5] && !this.board[6] && this.board[7]?.type === "r") {
      if (!this.isAttacked(4, enemy) && !this.isAttacked(5, enemy) && !this.isAttacked(6, enemy)) {
        push(6, { castle: "K" });
      }
    }
    if (piece.color === "w" && this.castling.includes("Q") && !this.board[1] && !this.board[2] && !this.board[3] && this.board[0]?.type === "r") {
      if (!this.isAttacked(4, enemy) && !this.isAttacked(3, enemy) && !this.isAttacked(2, enemy)) {
        push(2, { castle: "Q" });
      }
    }
    if (piece.color === "b" && this.castling.includes("k") && !this.board[61] && !this.board[62] && this.board[63]?.type === "r") {
      if (!this.isAttacked(60, enemy) && !this.isAttacked(61, enemy) && !this.isAttacked(62, enemy)) {
        push(62, { castle: "k" });
      }
    }
    if (piece.color === "b" && this.castling.includes("q") && !this.board[57] && !this.board[58] && !this.board[59] && this.board[56]?.type === "r") {
      if (!this.isAttacked(60, enemy) && !this.isAttacked(59, enemy) && !this.isAttacked(58, enemy)) {
        push(58, { castle: "q" });
      }
    }
  }

  isLegal(move) {
    const copy = this.clone();
    copy.play(move);
    return !copy.inCheck(move.color);
  }

  needsPromo(from, to) {
    const piece = this.board[from];
    if (!piece || piece.type !== "p") return false;
    const rank = to / 8 | 0;
    return (piece.color === "w" && rank === 7) || (piece.color === "b" && rank === 0);
  }

  nextCastling(move, piece) {
    let rights = this.castling;
    const drop = (flag) => {
      rights = rights.replace(flag, "");
    };
    if (piece.type === "k") {
      if (piece.color === "w") {
        drop("K");
        drop("Q");
      } else {
        drop("k");
        drop("q");
      }
    }
    const touched = new Set([move.from, move.to, move.capturedSquare]);
    if (touched.has(0)) drop("Q");
    if (touched.has(7)) drop("K");
    if (touched.has(56)) drop("q");
    if (touched.has(63)) drop("k");
    return rights;
  }

  addSan(moves) {
    for (const move of moves) {
      if (move.castle === "K" || move.castle === "k") {
        move.san = "O-O";
      } else if (move.castle === "Q" || move.castle === "q") {
        move.san = "O-O-O";
      } else {
        const same = moves.filter((other) => other !== move && other.piece === move.piece && other.to === move.to && other.promo === move.promo);
        let disambiguation = "";
        if (move.piece !== "p" && same.length) {
          const fileClash = same.some((other) => other.from % 8 === move.from % 8);
          const rankClash = same.some((other) => (other.from / 8 | 0) === (move.from / 8 | 0));
          if (!fileClash) disambiguation = FILES[move.from % 8];
          else if (!rankClash) disambiguation = String((move.from / 8 | 0) + 1);
          else disambiguation = squareName(move.from);
        }
        const letter = move.piece === "p" ? "" : move.piece.toUpperCase();
        const capture = move.capture ? "x" : "";
        const pawnFile = move.piece === "p" && move.capture ? FILES[move.from % 8] : "";
        const promo = move.promo ? `=${move.promo.toUpperCase()}` : "";
        move.san = `${letter}${pawnFile}${disambiguation}${capture}${squareName(move.to)}${promo}`;
      }
      const copy = this.clone();
      copy.play(move);
      if (copy.isCheckmate()) move.san += "#";
      else if (copy.inCheck()) move.san += "+";
    }
  }
}

function tableIndex(piece, index) {
  const file = index % 8;
  const rank = index / 8 | 0;
  const mirrored = piece.color === "w" ? rank * 8 + file : (7 - rank) * 8 + file;
  return PST[piece.type][mirrored] || 0;
}

export function evaluate(chess) {
  let score = 0;
  for (let i = 0; i < 64; i += 1) {
    const piece = chess.board[i];
    if (!piece) continue;
    const sign = piece.color === "w" ? 1 : -1;
    score += sign * (VALUES[piece.type] + tableIndex(piece, i));
  }
  return score;
}

function ordered(chess, moves) {
  return [...moves].sort((a, b) => {
    const av = a.capture ? VALUES[a.capture] - VALUES[a.piece] / 10 : 0;
    const bv = b.capture ? VALUES[b.capture] - VALUES[b.piece] / 10 : 0;
    return bv - av;
  });
}

function negamax(chess, depth, alpha, beta) {
  const moves = chess.legalMoves(null, { san: false });
  if (!moves.length) return chess.inCheck() ? -100000 - depth : 0;
  if (chess.halfmove >= 100 || chess.isInsufficientMaterial()) return 0;
  if (depth === 0) {
    const base = evaluate(chess);
    return chess.turn === "w" ? base : -base;
  }
  let best = -Infinity;
  for (const move of ordered(chess, moves)) {
    const next = chess.clone();
    next.play(move);
    const score = -negamax(next, depth - 1, -beta, -alpha);
    if (score > best) best = score;
    if (score > alpha) alpha = score;
    if (alpha >= beta) break;
  }
  return best;
}

export function chooseComputerMove(chess, level = "easy") {
  const moves = chess.legalMoves(null, { san: false });
  if (!moves.length) return null;
  const depth = level === "fair" ? 2 : 1;
  const noise = level === "fair" ? 35 : 160;
  let best = null;
  let bestScore = -Infinity;
  for (const move of ordered(chess, moves)) {
    const next = chess.clone();
    next.play(move);
    const score = -negamax(next, depth - 1, -Infinity, Infinity) + (Math.random() * noise - noise / 2);
    if (score > bestScore) {
      bestScore = score;
      best = move;
    }
  }
  return best;
}
