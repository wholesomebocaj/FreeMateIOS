import { readFileSync } from "node:fs";
import { Chess, uciOf } from "./engine.js";

const bundle = JSON.parse(readFileSync(new URL("./content/curriculum.json", import.meta.url), "utf8"));
let failed = 0;

function check(name, condition) {
  if (!condition) {
    failed += 1;
    console.error(`FAIL ${name}`);
  }
}

function playUci(chess, uci) {
  return chess.move(uci.slice(0, 2), uci.slice(2, 4), uci.slice(4) || "q");
}

for (const course of bundle.courses) {
  for (const lesson of course.lessons) {
    check(`${lesson.id} has steps`, lesson.steps.length > 0);
    for (const step of lesson.steps) {
      if (step.fen) {
        try {
          const chess = new Chess(step.fen);
          check(`${lesson.id} ${step.title} has two kings`, chess.kingSquare("w") >= 0 && chess.kingSquare("b") >= 0);
        } catch (error) {
          check(`${lesson.id} ${step.title} fen ${error.message}`, false);
        }
      }
      const allowed = new Set(step.allowedMoves || []);
      if (step.startSquare && step.targetSquare) allowed.add(`${step.startSquare}${step.targetSquare}`);
      if (!allowed.size || !step.fen) continue;
      const chess = new Chess(step.fen);
      const legal = new Set(chess.legalMoves().map(uciOf));
      for (const uci of allowed) {
        check(`${lesson.id} ${step.title} ${uci} legal`, legal.has(uci) || legal.has(`${uci}q`));
      }
    }
  }
}

for (const drill of bundle.drills) {
  for (const puzzle of drill.puzzles) {
    const chess = new Chess(puzzle.fen);
    const legal = new Set(chess.legalMoves().map(uciOf));
    for (const uci of puzzle.solution) {
      check(`${drill.id} ${puzzle.id} ${uci}`, legal.has(uci));
      const next = chess.clone();
      const played = playUci(next, uci);
      check(`${drill.id} ${puzzle.id} played`, Boolean(played));
      if (puzzle.mate) check(`${drill.id} ${puzzle.id} mate`, next.isCheckmate());
    }
  }
}

for (const opening of bundle.openings) {
  const chess = new Chess();
  for (const move of opening.moves) {
    const played = playUci(chess, move.uci);
    if (!played) {
      check(`${opening.id} ${move.uci}`, false);
      break;
    }
  }
}

const lessonCount = bundle.courses.reduce((sum, course) => sum + course.lessons.length, 0);
check("15 lessons", lessonCount === 15);
check("openings", bundle.openings.length >= 8);
check("drills", bundle.drills.length >= 4);

if (failed) {
  console.error(`${failed} failed`);
  process.exit(1);
}
console.log(`content tests passed (${lessonCount} lessons, ${bundle.openings.length} openings)`);
