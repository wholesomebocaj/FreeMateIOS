import { Chess, START_FEN, chooseComputerMove, squareName, uciOf } from "./engine.js";

let failed = 0;

function check(name, condition) {
  if (!condition) {
    failed += 1;
    console.error(`FAIL ${name}`);
  }
}

const start = new Chess();
check("start fen", start.fen() === START_FEN);
check("20 opening moves", start.legalMoves().length === 20);
check("e4", start.move("e2", "e4")?.san === "e4");
check("black to move", start.turn === "b");
check("e5", start.move("e5", "e5") === null);
check("black e5", start.move("e7", "e5")?.san === "e5");

const scholars = new Chess("r1bqkbnr/pppp1ppp/2n5/4p2Q/2B1P3/8/PPPP1PPP/RNB1K1NR w KQkq - 4 4");
const mate = scholars.move("h5", "f7");
check("scholars san", mate?.san === "Qxf7#");
check("scholars mate", scholars.isCheckmate());

const matePos = new Chess("7k/6Q1/6K1/8/8/8/8/8 b - - 0 1");
check("queen mate", matePos.isCheckmate());
const stale = new Chess("7k/5Q2/6K1/8/8/8/8/8 b - - 0 1");
check("stalemate", stale.isStalemate());
check("stalemate not mate", !stale.isCheckmate());

const castle = new Chess("rnbqk2r/pppp1ppp/5n2/2b1p3/2B1P3/5N2/PPPP1PPP/RNBQK2R w KQkq - 4 4");
const castled = castle.move("e1", "g1");
check("castle san", castled?.san === "O-O");
check("rook landed", castle.pieceAt("f1")?.type === "r");
check("king landed", castle.pieceAt("g1")?.type === "k");

const ep = new Chess("rnbqkbnr/ppp1pppp/8/3pP3/8/8/PPPP1PPP/RNBQKBNR w KQkq d6 0 3");
const epMove = ep.move("e5", "d6");
check("en passant", epMove?.san === "exd6");
check("captured pawn gone", !ep.pieceAt("d5"));
check("pawn on d6", ep.pieceAt("d6")?.type === "p");

const promo = new Chess("8/P7/8/8/8/8/8/k1K5 w - - 0 1");
check("promo choices", promo.legalMoves("a7").filter((move) => move.promo).length === 4);
check("underpromote", promo.move("a7", "a8", "n")?.san === "a8=N");

const pin = new Chess("k3r3/8/8/8/8/8/4N3/4K3 w - - 0 1");
const knightMoves = pin.legalMoves("e2").map(uciOf);
check("pinned knight stays", knightMoves.length === 0);
check("pinned knight no d4", !knightMoves.includes("e2d4"));

const backRank = new Chess("6k1/5ppp/8/8/8/8/8/R5K1 w - - 0 1");
check("back rank mate", backRank.move("a1", "a8")?.san.endsWith("#"));

const fork = new Chess("8/6k1/8/8/3N4/4q3/8/K7 w - - 0 1");
check("fork legal", fork.legalMoves("d4").some((move) => uciOf(move) === "d4f5"));

const escape = new Chess("4k3/8/8/8/8/4q3/8/4K3 w - - 0 1");
const escapes = escape.legalMoves().map(uciOf).sort();
check("king escapes", escapes.includes("e1d1") && escapes.includes("e1f1") && escapes.length === 2);

const captureCheck = new Chess("4k3/8/8/8/8/8/4q3/4K3 w - - 0 1");
check("capture checker", captureCheck.legalMoves().map(uciOf).join(",") === "e1e2");

const save = new Chess("3rk3/8/8/8/8/8/8/3QK3 w - - 0 1");
check("queen is in danger", save.legalMoves("d1").some((move) => uciOf(move) === "d1a4"));

const ai = new Chess();
const reply = chooseComputerMove(ai, "easy");
check("computer move", reply && squareName(reply.from) && squareName(reply.to));

const queenside = new Chess("r3k2r/8/8/8/8/8/8/R3K2R w KQkq - 0 1");
check("queenside castle", queenside.move("e1", "c1")?.san === "O-O-O");

if (failed) {
  console.error(`${failed} failed`);
  process.exit(1);
}
console.log("engine tests passed");
