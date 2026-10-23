import { Chess, START_FEN, chooseComputerMove, squareName, uciOf } from "./engine.js";
import { pieceName, pieceSvg } from "./pieces.js";

const KEY = "freemate.progress.v1";
const memory = new Map();

const store = {
  get(key) {
    try { return localStorage.getItem(key); } catch { return memory.has(key) ? memory.get(key) : null; }
  },
  set(key, value) {
    memory.set(key, value);
    try { localStorage.setItem(key, value); } catch { /* keep the in-memory copy */ }
  },
  remove(key) {
    memory.delete(key);
    try { localStorage.removeItem(key); } catch { /* ignore */ }
  },
};

const state = {
  data: null,
  loadError: "",
  progress: loadProgress(),
  sig: "",
  selected: null,
  found: [],
  feedback: "",
  feedbackKind: "",
  solved: false,
  wrong: "",
  promo: null,
  lessonChess: null,
  last: [],
  drillSig: "",
  drillChess: null,
  drillIndex: 0,
  lineId: "",
  line: null,
  linePly: 0,
  game: null,
  sandbox: null,
  filters: { side: "all", level: "all", query: "" },
  announce: "",
  thinkToken: 0,
};

function loadProgress() {
  const empty = {
    completedLessons: [],
    reached: {},
    drills: {},
    openings: {},
    games: { played: 0, wins: 0, losses: 0, draws: 0 },
    sound: false,
    level: "easy",
  };
  try {
    const parsed = JSON.parse(store.get(KEY) || "null");
    if (!parsed) return empty;
    return { ...empty, ...parsed, games: { ...empty.games, ...(parsed.games || {}) } };
  } catch {
    return empty;
  }
}

function saveProgress() {
  store.set(KEY, JSON.stringify(state.progress));
}

function esc(value) {
  return String(value ?? "").replace(/[&<>"']/g, (ch) => ({
    "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;",
  }[ch]));
}

function parseRoute() {
  const parts = (location.hash.replace(/^#/, "") || "/home").split("/").filter(Boolean);
  const [name, id] = parts;
  if (name === "lesson" && id) return { name, id };
  if (name === "drill" && id) return { name, id };
  if (name === "opening" && id) return { name, id };
  if (["lessons", "practice", "play", "openings", "home", "sandbox"].includes(name)) return { name, id: id || "" };
  return { name: "home", id: "" };
}

function allLessons() {
  return (state.data?.courses || []).flatMap((course) => course.lessons.map((lesson) => ({ ...lesson, courseTitle: course.title, courseId: course.id })));
}

function findLesson(id) {
  return allLessons().find((lesson) => lesson.id === id) || null;
}

function findCourse(id) {
  return (state.data?.courses || []).find((course) => course.id === id) || null;
}

function doneCount() {
  return state.progress.completedLessons.length;
}

function lessonDone(id) {
  return state.progress.completedLessons.includes(id);
}

function percent() {
  const total = allLessons().length || 1;
  return Math.round((doneCount() / total) * 100);
}

function nextLesson() {
  return allLessons().find((lesson) => !lessonDone(lesson.id)) || allLessons()[0] || null;
}

function autoStep(step) {
  return ["explain", "board-demo", "checklist", "highlight-demo"].includes(step?.type);
}

function moveStep(step) {
  return ["move-task", "capture-task", "tactic-task", "board-task"].includes(step?.type);
}

function allowedFor(step) {
  const list = [...(step?.allowedMoves || [])];
  if (step?.startSquare && step?.targetSquare) list.push(`${step.startSquare}${step.targetSquare}`);
  return { list, lock: step?.lockToAllowedMoves ?? list.length > 0 };
}

function highlightsFor(step) {
  const marks = new Map();
  for (const entry of step?.highlightSquares || []) {
    if (typeof entry === "string") marks.set(entry, "focus");
    else if (entry?.square) marks.set(entry.square, entry.className || "focus");
  }
  for (const square of state.found) marks.set(square, "correct");
  return marks;
}

function playUci(chess, uci) {
  return chess.move(uci.slice(0, 2), uci.slice(2, 4), uci.slice(4) || "q");
}

function detailed(chess, move) {
  return chess.legalMoves().find((item) => item.from === move.from && item.to === move.to && (item.promo || null) === (move.promo || null)) || move;
}

function sideLabel(color) {
  return color === "b" || color === "black" ? "Black" : "White";
}

function userSide(opening) {
  return String(opening.side || "white").toLowerCase().startsWith("b") ? "b" : "w";
}

function beep() {
  if (!state.progress.sound) return;
  try {
    const ctx = new AudioContext();
    const osc = ctx.createOscillator();
    const gain = ctx.createGain();
    osc.frequency.value = 620;
    gain.gain.value = 0.03;
    osc.connect(gain).connect(ctx.destination);
    osc.start();
    osc.stop(ctx.currentTime + 0.05);
    osc.onended = () => ctx.close();
  } catch { /* sound is optional */ }
}

function boardHtml(chess, { orientation = "w", interactive = true, marks = new Map(), last = [], selected = null, dests = [] } = {}) {
  if (!chess) return "";
  const ranks = orientation === "b" ? [0, 1, 2, 3, 4, 5, 6, 7] : [7, 6, 5, 4, 3, 2, 1, 0];
  const files = orientation === "b" ? [7, 6, 5, 4, 3, 2, 1, 0] : [0, 1, 2, 3, 4, 5, 6, 7];
  const checkSquare = chess.inCheck() ? chess.kingSquare(chess.turn) : -1;
  const destSet = new Set(dests);
  const squares = ranks.flatMap((rank) => files.map((file) => {
    const index = rank * 8 + file;
    const name = squareName(index);
    const piece = chess.board[index];
    const light = (file + rank) % 2 === 1;
    const classes = ["square", light ? "light" : "dark"];
    if (selected === name) classes.push("selected");
    if (last.includes(name)) classes.push("last");
    if (checkSquare === index) classes.push("check");
    if (marks.has(name)) classes.push(`mark-${marks.get(name)}`);
    const isDest = destSet.has(name);
    if (isDest) classes.push(piece ? "capture" : "legal");
    const coords = [
      file === files[0] ? `<span class="coord rank" aria-hidden="true">${rank + 1}</span>` : "",
      rank === ranks.at(-1) ? `<span class="coord file" aria-hidden="true">${"abcdefgh"[file]}</span>` : "",
    ].join("");
    const icon = piece ? pieceSvg(piece.color, piece.type) : "";
    const dot = isDest ? `<span class="hint-dot" aria-hidden="true"></span>` : "";
    const who = piece ? `${piece.color === "w" ? "White" : "Black"} ${pieceName(piece.type)} on ${name}` : `Empty square ${name}`;
    const tabIndex = !interactive ? -1 : name === (selected || squareName(ranks[0] * 8 + files[0])) ? 0 : -1;
    return `<button class="${classes.join(" ")}" type="button" role="gridcell" data-action="square" data-sq="${name}" data-file="${file}" data-rank="${rank}" aria-label="${esc(who)}" tabindex="${tabIndex}">${coords}${dot}${icon}</button>`;
  })).join("");
  const turn = sideLabel(chess.turn);
  const status = chess.isCheckmate() ? `${turn} is checkmated` : chess.isStalemate() ? "Stalemate" : chess.inCheck() ? `${turn} is in check` : `${turn} to move`;
  return `<div class="board" role="grid" data-orientation="${orientation}" aria-label="Chessboard. ${esc(status)}. Use arrow keys to move between squares.">${squares}</div><p class="meta board-status">${esc(status)}</p>`;
}

function destinations(chess, selected, step) {
  if (!chess || !selected) return [];
  const { list, lock } = step ? allowedFor(step) : { list: [], lock: false };
  return chess.legalMoves(selected).map((move) => {
    const uci = uciOf(move).slice(0, 4);
    if (lock && list.length && !list.includes(uci) && !list.includes(uciOf(move))) return null;
    return squareName(move.to);
  }).filter(Boolean);
}

function syncLesson(lesson, index) {
  const step = lesson.steps[index];
  const sig = `${lesson.id}:${index}:${step?.fen || ""}:${step?.type}`;
  if (state.sig === sig) return step;
  state.sig = sig;
  state.selected = null;
  state.found = [];
  state.feedback = "";
  state.feedbackKind = "";
  state.wrong = "";
  state.promo = null;
  state.last = [];
  state.solved = autoStep(step);
  state.lessonChess = step?.fen ? new Chess(step.fen) : null;
  return step;
}

function lessonView() {
  const route = parseRoute();
  const lesson = findLesson(route.id);
  if (!lesson) return `<h1 tabindex="-1">Lesson not found</h1><p><a href="#/lessons">Back to lessons</a></p>`;
  const reached = state.progress.reached[lesson.id] ?? 0;
  let index = Math.min(reached, lesson.steps.length);
  if (index >= lesson.steps.length) index = 0;
  const step = syncLesson(lesson, Number(state.forceIndex ?? index));
  const shown = Number(state.forceIndex ?? index);
  if (!step) return completeLesson(lesson);
  const marks = highlightsFor(step);
  const showBoard = Boolean(step.fen) || moveStep(step) || ["square-click", "click-all-squares", "board-demo"].includes(step.type);
  const chess = state.lessonChess;
  const interactive = moveStep(step) || ["square-click", "click-all-squares"].includes(step.type) || Boolean(step.fen);
  const dests = moveStep(step) ? destinations(chess, state.selected, step) : [];
  const dots = lesson.steps.map((item, dot) => {
    const locked = dot > (state.progress.reached[lesson.id] ?? 0);
    return `<button type="button" data-action="jump" data-index="${dot}" ${locked ? "disabled" : ""} ${dot === shown ? 'aria-current="step"' : ""}>${dot + 1}</button>`;
  }).join("");
  const choices = (step.choices || []).map((choice) => {
    const good = state.solved && choice.value === step.correctChoice;
    const bad = state.wrong === choice.value;
    return `<button class="choice ${good ? "good" : ""} ${bad ? "bad" : ""}" type="button" data-action="choice" data-value="${esc(choice.value)}">${esc(choice.label)}</button>`;
  }).join("");
  const tasks = (step.tasks || []).map((task) => `<li>${esc(task)}</li>`).join("");
  const found = step.type === "click-all-squares" ? `<p class="meta">${state.found.length} of ${(step.targetSquares || []).length} squares found</p>` : "";
  const board = showBoard && chess ? boardHtml(chess, {
    orientation: step.orientation === "black" ? "b" : "w",
    interactive,
    marks,
    last: state.last,
    selected: state.selected,
    dests,
  }) : "";
  return `<p class="meta"><a href="#/lessons/${esc(lesson.courseId)}">${esc(lesson.courseTitle)}</a></p>
    <h1 tabindex="-1">${esc(lesson.title)}</h1>
    <p class="meta">Step ${shown + 1} of ${lesson.steps.length}${lessonDone(lesson.id) ? " · already completed" : ""}</p>
    <div class="dots" aria-label="Lesson steps">${dots}</div>
    <div class="lesson-layout">
      <div class="board-column">${board}${promoHtml()}</div>
      <section class="panel">
        <h2>${esc(step.title || "Step")}</h2>
        ${step.body ? `<p>${esc(step.body)}</p>` : ""}
        ${step.question ? `<p><strong>${esc(step.question)}</strong></p>` : ""}
        ${tasks ? `<ul class="tasks">${tasks}</ul>` : ""}
        ${choices ? `<div class="choices">${choices}</div>` : ""}
        ${found}
        <p class="feedback ${state.feedbackKind}" role="status">${esc(state.feedback)}</p>
        <div class="actions">
          ${shown > 0 ? `<button class="button" type="button" data-action="back">Back</button>` : ""}
          <button class="button primary" type="button" data-action="next" ${state.solved ? "" : "disabled"}>${shown === lesson.steps.length - 1 ? "Finish" : "Next"}</button>
        </div>
        <p class="meta">On a move task, select a piece, then select a destination. Arrow keys move around the board.</p>
      </section>
    </div>`;
}

function completeLesson(lesson) {
  const lessons = allLessons();
  const next = lessons[lessons.findIndex((item) => item.id === lesson.id) + 1];
  return `<h1 tabindex="-1">Lesson complete</h1>
    <p class="lede">${esc(lesson.title)} is saved on this device.</p>
    <div class="actions">
      ${next ? `<a class="button primary" href="#/lesson/${esc(next.id)}">Next: ${esc(next.title)}</a>` : `<a class="button primary" href="#/practice">Practice a drill</a>`}
      <a class="button" href="#/lessons/${esc(lesson.courseId)}">Back to the course</a>
    </div>`;
}

function promoHtml() {
  if (!state.promo) return "";
  const buttons = state.promo.choices.map((piece) => `<button class="button" type="button" data-action="promo" data-piece="${piece}">${esc(pieceName(piece))}</button>`).join("");
  return `<div class="promo" role="dialog" aria-label="Choose a promotion piece">${buttons}</div>`;
}

function homeView() {
  if (!state.data) return loading();
  const next = nextLesson();
  const drillSolved = Object.values(state.progress.drills).reduce((sum, item) => sum + (item.solved?.length || 0), 0);
  const cards = state.data.courses.map((course) => {
    const done = course.lessons.filter((lesson) => lessonDone(lesson.id)).length;
    return `<a class="card" href="#/lessons/${esc(course.id)}"><h3>${esc(course.title)}</h3><p>${esc(course.description)}</p><p class="meta">${done} of ${course.lessons.length} lessons</p></a>`;
  }).join("");
  return `<p class="meta">Beginner chess</p>
    <h1 tabindex="-1">Learn chess the calm way.</h1>
    <p class="lede">FreeMate teaches how the pieces move, what check and checkmate mean, simple tactics, and a few opening ideas. Then you can drill them and play.</p>
    <div class="actions">
      ${next ? `<a class="button primary" href="#/lesson/${esc(next.id)}">${doneCount() ? "Continue" : "Start"}: ${esc(next.title)}</a>` : ""}
      <a class="button" href="#/play">Play the computer</a>
    </div>
    <div class="grid">
      <section class="panel"><h3>${percent()}% of lessons</h3><div class="meter" aria-hidden="true"><span style="width:${percent()}%"></span></div><p class="meta">${doneCount()} of ${allLessons().length} lessons finished</p></section>
      <section class="panel"><h3>${drillSolved} drills solved</h3><p class="meta">Mate, forks, pins, hanging pieces, and checks.</p></section>
      <section class="panel"><h3>${state.progress.games.played} games</h3><p class="meta">${state.progress.games.wins} wins · ${state.progress.games.draws} draws · ${state.progress.games.losses} losses</p></section>
    </div>
    <h2>Courses</h2>
    <div class="grid">${cards}</div>
    <h2>What to remember</h2>
    <div class="grid">
      ${(state.data.brackets || []).slice(0, 2).map((bracket) => `<section class="panel"><h3>${esc(bracket.title)}</h3><p>${esc(bracket.description)}</p><p class="meta">${esc((bracket.learn || []).join(" · "))}</p></section>`).join("")}
    </div>
    <p class="meta">FreeMate is free. There are no ads and no account. Progress stays in this browser on this device.</p>
    <button class="button" type="button" data-action="reset">Reset progress on this device</button>`;
}

function lessonsView() {
  if (!state.data) return loading();
  const route = parseRoute();
  const course = route.id ? findCourse(route.id) : null;
  if (!course && route.id) return `<h1 tabindex="-1">Course not found</h1>`;
  if (course) {
    const rows = course.lessons.map((lesson) => {
      const reached = state.progress.reached[lesson.id] || 0;
      const status = lessonDone(lesson.id) ? "Done" : reached > 0 ? "In progress" : "Start";
      return `<a class="card" href="#/lesson/${esc(lesson.id)}"><h3>${esc(lesson.title)}</h3><p>${esc(lesson.summary || "")}</p><p class="meta">${status} · ${lesson.steps.length} steps · ${lesson.timeMinutes || 5} min</p></a>`;
    }).join("");
    return `<p class="meta"><a href="#/lessons">All courses</a></p><h1 tabindex="-1">${esc(course.title)}</h1><p class="lede">${esc(course.description)}</p><div class="grid">${rows}</div>`;
  }
  const cards = state.data.courses.map((item) => `<a class="card" href="#/lessons/${esc(item.id)}"><h3>${esc(item.title)}</h3><p>${esc(item.description)}</p><p class="meta">${item.lessons.length} lessons</p></a>`).join("");
  return `<h1 tabindex="-1">Lessons</h1><p class="lede">Start anywhere. The suggested path runs from the board and the pieces through tactics, checkmate, and practical habits.</p><div class="grid">${cards}</div>`;
}

function practiceView() {
  if (!state.data) return loading();
  const cards = state.data.drills.map((drill) => {
    const solved = state.progress.drills[drill.id]?.solved?.length || 0;
    return `<a class="card" href="#/drill/${esc(drill.id)}"><h3>${esc(drill.title)}</h3><p>${esc(drill.summary)}</p><p class="meta">${solved} of ${drill.puzzles.length} solved</p></a>`;
  }).join("");
  return `<h1 tabindex="-1">Practice</h1>
    <p class="lede">Short drills for mate, forks, pins, hanging pieces, and getting out of check.</p>
    <div class="grid">${cards}</div>
    <div class="actions"><a class="button" href="#/sandbox">Free board</a><a class="button" href="#/play">Play a game</a></div>`;
}

function ensureDrill(drill) {
  const solved = new Set(state.progress.drills[drill.id]?.solved || []);
  let index = drill.puzzles.findIndex((puzzle) => !solved.has(puzzle.id));
  if (index < 0) index = 0;
  if (state.drillSig.startsWith(`${drill.id}:`) && state.forceDrill == null) return drill.puzzles[state.drillIndex] || drill.puzzles[0];
  const use = state.forceDrill ?? index;
  const puzzle = drill.puzzles[use];
  const sig = `${drill.id}:${use}:${puzzle.fen}`;
  if (state.drillSig !== sig) {
    state.drillSig = sig;
    state.drillIndex = use;
    state.drillChess = new Chess(puzzle.fen);
    state.selected = null;
    state.feedback = "";
    state.feedbackKind = "";
    state.solved = false;
    state.last = [];
    state.promo = null;
  }
  state.forceDrill = null;
  return puzzle;
}

function drillView() {
  const route = parseRoute();
  const drill = state.data?.drills.find((item) => item.id === route.id);
  if (!drill) return `<h1 tabindex="-1">Drill not found</h1><p><a href="#/practice">Back to practice</a></p>`;
  const puzzle = ensureDrill(drill);
  const chess = state.drillChess;
  const step = { allowedMoves: puzzle.solution, lockToAllowedMoves: true, highlightSquares: [] };
  const board = boardHtml(chess, {
    orientation: "w",
    marks: new Map(),
    last: state.last,
    selected: state.selected,
    dests: state.solved ? [] : destinations(chess, state.selected, step),
  });
  const solved = state.progress.drills[drill.id]?.solved?.length || 0;
  return `<p class="meta"><a href="#/practice">Practice</a></p>
    <h1 tabindex="-1">${esc(drill.title)}</h1>
    <p class="meta">Puzzle ${state.drillIndex + 1} of ${drill.puzzles.length} · ${solved} solved</p>
    <div class="lesson-layout">
      <div class="board-column">${board}${promoHtml()}</div>
      <section class="panel">
        <h2>${esc(puzzle.prompt)}</h2>
        <p class="feedback ${state.feedbackKind}" role="status">${esc(state.feedback)}</p>
        <div class="actions">
          <button class="button" type="button" data-action="hint">Hint</button>
          ${state.solved ? `<button class="button primary" type="button" data-action="drill-next">${state.drillIndex === drill.puzzles.length - 1 ? "Finish drill" : "Next puzzle"}</button>` : ""}
        </div>
        <p class="meta">${esc(drill.summary)}</p>
      </section>
    </div>`;
}

function ensureGame() {
  if (state.game) return;
  state.game = {
    chess: new Chess(),
    history: [],
    orientation: "w",
    user: "w",
    level: state.progress.level || "easy",
    thinking: false,
    recorded: false,
  };
}

function liveResult(game) {
  if (!game) return { over: false, winner: null, reason: "" };
  if (game.resigned) return { over: true, winner: game.user === "w" ? "black" : "white", reason: "resign" };
  return game.chess.result();
}

function playView() {
  ensureGame();
  const game = state.game;
  const result = liveResult(game);
  const board = boardHtml(game.chess, {
    orientation: game.orientation,
    last: state.last,
    selected: game.thinking || result.over ? null : state.selected,
    dests: game.thinking || result.over ? [] : destinations(game.chess, state.selected, null),
  });
  const moves = game.history.map((item, index) => `${index % 2 === 0 ? `${(index / 2 | 0) + 1}. ` : ""}${esc(item.san)}`).join(" ");
  const banner = result.over ? resultText(result, game) : game.thinking ? "The computer is thinking." : state.feedback;
  return `<h1 tabindex="-1">Play</h1>
    <p class="lede">A beginner-friendly computer. Easy misses some tactics. Fair looks one move deeper.</p>
    <div class="play-layout">
      <div class="board-column">${board}${promoHtml()}</div>
      <section class="panel">
        <p class="feedback ${result.over ? "ok" : ""}" role="status">${esc(banner)}</p>
        <fieldset>
          <legend>Your color</legend>
          <button class="button" type="button" data-action="new-game" data-color="w">Play White</button>
          <button class="button" type="button" data-action="new-game" data-color="b">Play Black</button>
        </fieldset>
        <fieldset>
          <legend>Computer</legend>
          <label><input type="radio" name="level" data-action="level" value="easy" ${game.level === "easy" ? "checked" : ""}> Easy</label>
          <label><input type="radio" name="level" data-action="level" value="fair" ${game.level === "fair" ? "checked" : ""}> Fair</label>
        </fieldset>
        <label><input type="checkbox" data-action="sound" ${state.progress.sound ? "checked" : ""}> Move sounds</label>
        <div class="actions">
          <button class="button" type="button" data-action="undo" ${game.history.length ? "" : "disabled"}>Undo</button>
          <button class="button" type="button" data-action="flip">Flip board</button>
          <button class="button" type="button" data-action="resign" ${result.over ? "disabled" : ""}>Resign</button>
        </div>
        <h2>Moves</h2>
        <p>${moves || "No moves yet."}</p>
      </section>
    </div>`;
}

function resultText(result, game) {
  if (result.reason === "checkmate") {
    const userWon = (result.winner === "white" && game.user === "w") || (result.winner === "black" && game.user === "b");
    return userWon ? "Checkmate. You won." : "Checkmate. The computer won.";
  }
  if (result.reason === "stalemate") return "Stalemate. The game is a draw.";
  if (result.reason === "fifty-move") return "Draw by the fifty-move rule.";
  if (result.reason === "insufficient") return "Draw by insufficient material.";
  if (result.reason === "resign") return "You resigned.";
  return "Game over.";
}

function sandboxView() {
  if (!state.sandbox) state.sandbox = { chess: new Chess(), orientation: "w" };
  const board = boardHtml(state.sandbox.chess, {
    orientation: state.sandbox.orientation,
    last: state.last,
    selected: state.selected,
    dests: destinations(state.sandbox.chess, state.selected, null),
  });
  return `<h1 tabindex="-1">Free board</h1>
    <p class="lede">Move either color. Useful for trying a piece move before a lesson.</p>
    <div class="play-layout">
      <div class="board-column">${board}${promoHtml()}</div>
      <section class="panel">
        <p class="feedback ${state.feedbackKind}">${esc(state.feedback)}</p>
        <div class="actions">
          <button class="button" type="button" data-action="sandbox-reset">Reset</button>
          <button class="button" type="button" data-action="sandbox-flip">Flip board</button>
          <a class="button" href="#/practice">Back to practice</a>
        </div>
      </section>
    </div>`;
}

function openingsView() {
  if (!state.data) return loading();
  const query = state.filters.query.trim().toLowerCase();
  const rows = state.data.openings.filter((opening) => {
    const side = userSide(opening) === "b" ? "black" : "white";
    if (state.filters.side !== "all" && state.filters.side !== side) return false;
    if (state.filters.level !== "all" && opening.difficulty !== state.filters.level) return false;
    if (query && !`${opening.name} ${opening.eco} ${opening.description}`.toLowerCase().includes(query)) return false;
    return true;
  }).map((opening) => {
    const done = state.progress.openings[opening.id]?.done;
    return `<a class="card" href="#/opening/${esc(opening.id)}"><h3>${esc(opening.name)}</h3><p>${esc(opening.description)}</p><p class="meta">${esc(opening.eco)} · ${esc(opening.difficulty)} · ${esc(sideLabel(userSide(opening)))} · ${opening.moves.length} moves${done ? " · practiced" : ""}</p></a>`;
  }).join("");
  const levels = [...new Set(state.data.openings.map((opening) => opening.difficulty))];
  return `<h1 tabindex="-1">Opening ideas</h1>
    <p class="lede">Play through a short main line. FreeMate explains the idea behind each move.</p>
    <div class="actions">
      <label>Side <select id="side-filter" data-action="filter-side">${["all", "white", "black"].map((side) => `<option ${state.filters.side === side ? "selected" : ""}>${side}</option>`).join("")}</select></label>
      <label>Level <select id="level-filter" data-action="filter-level"><option value="all" ${state.filters.level === "all" ? "selected" : ""}>all</option>${levels.map((level) => `<option ${state.filters.level === level ? "selected" : ""}>${esc(level)}</option>`).join("")}</select></label>
      <label>Search <input id="opening-search" type="search" value="${esc(state.filters.query)}" data-action="filter-query" aria-label="Search openings"></label>
    </div>
    <div class="grid">${rows || `<p>No openings match.</p>`}</div>`;
}

function ensureLine(opening) {
  if (state.lineId === opening.id && state.line) return;
  state.lineId = opening.id;
  state.line = new Chess();
  state.linePly = 0;
  state.selected = null;
  state.feedback = "";
  state.feedbackKind = "";
  state.last = [];
  state.promo = null;
  const target = state.progress.openings[opening.id]?.ply || 0;
  while (state.linePly < target && state.linePly < opening.moves.length) {
    const played = playUci(state.line, opening.moves[state.linePly].uci);
    if (!played) break;
    state.last = [squareName(played.from), squareName(played.to)];
    state.linePly += 1;
  }
  autoplayLine(opening);
}

function autoplayLine(opening) {
  while (state.linePly < opening.moves.length) {
    const color = state.linePly % 2 === 0 ? "w" : "b";
    if (color === userSide(opening)) break;
    const played = playUci(state.line, opening.moves[state.linePly].uci);
    if (!played) break;
    state.last = [squareName(played.from), squareName(played.to)];
    state.linePly += 1;
  }
  state.progress.openings[opening.id] = {
    done: state.linePly >= opening.moves.length,
    ply: state.linePly,
  };
  saveProgress();
}

function openingView() {
  const route = parseRoute();
  const opening = state.data?.openings.find((item) => item.id === route.id);
  if (!opening) return `<h1 tabindex="-1">Opening not found</h1><p><a href="#/openings">Back</a></p>`;
  ensureLine(opening);
  const expected = opening.moves[state.linePly];
  const done = state.linePly >= opening.moves.length;
  const step = expected ? { allowedMoves: [expected.uci], lockToAllowedMoves: true } : null;
  const marks = new Map();
  if (state.showHint && expected) {
    marks.set(expected.uci.slice(0, 2), "focus");
    marks.set(expected.uci.slice(2, 4), "target");
  }
  const board = boardHtml(state.line, {
    orientation: userSide(opening),
    marks,
    last: state.last,
    selected: done ? null : state.selected,
    dests: done ? [] : destinations(state.line, state.selected, step),
  });
  const notes = opening.moves.slice(0, state.linePly).map((move, index) => `<li><strong>${index % 2 === 0 ? `${(index / 2 | 0) + 1}. ` : ""}${esc(move.san)}</strong> ${esc(move.explanation)}</li>`).join("");
  const ideas = (opening.ideas || []).slice(0, 3).map((idea) => `<li>${esc(idea)}</li>`).join("");
  return `<p class="meta"><a href="#/openings">Openings</a></p>
    <h1 tabindex="-1">${esc(opening.name)}</h1>
    <p class="lede">${esc(opening.description)}</p>
    <div class="lesson-layout">
      <div class="board-column">${board}</div>
      <section class="panel">
        <p class="meta">You play ${esc(sideLabel(userSide(opening)))}. ${done ? "Line complete." : "Play the highlighted idea when it is your turn."}</p>
        <p class="feedback ${state.feedbackKind}" role="status">${esc(state.feedback || (done ? "You finished this line. It is saved on this device." : ""))}</p>
        <div class="actions">
          ${expected && !done ? `<button class="button" type="button" data-action="line-hint">Hint</button>` : ""}
          <button class="button" type="button" data-action="line-restart">Start line over</button>
        </div>
        <h2>Why these moves</h2>
        <ol class="tasks">${notes || "<li>Make the first move to see the idea.</li>"}</ol>
        ${ideas ? `<h2>Ideas to keep</h2><ul class="tasks">${ideas}</ul>` : ""}
      </section>
    </div>`;
}

function loading() {
  if (state.loadError) return `<h1 tabindex="-1">FreeMate</h1><p>${esc(state.loadError)}</p>`;
  return `<h1 tabindex="-1">FreeMate</h1><p>Loading lessons…</p>`;
}

function view() {
  const route = parseRoute();
  if (!state.data && route.name !== "home") return loading();
  if (route.name === "lesson") return lessonView();
  if (route.name === "lessons") return lessonsView();
  if (route.name === "practice") return practiceView();
  if (route.name === "drill") return drillView();
  if (route.name === "play") return playView();
  if (route.name === "sandbox") return sandboxView();
  if (route.name === "openings") return openingsView();
  if (route.name === "opening") return openingView();
  return homeView();
}

function render(options = {}) {
  const main = document.querySelector("main");
  const focusId = options.focusId || null;
  main.innerHTML = view();
  document.querySelectorAll("nav a").forEach((link) => {
    const route = parseRoute();
    const map = { lesson: "lessons", drill: "practice", sandbox: "practice", opening: "openings" };
    const current = map[route.name] || route.name;
    link.setAttribute("aria-current", link.dataset.nav === current ? "page" : "false");
  });
  if (state.announce) {
    document.querySelector("#live").textContent = state.announce;
    state.announce = "";
  }
  if (options.focus) main.querySelector("h1")?.focus();
  else if (options.focusSquare) main.querySelector(`[data-sq="${options.focusSquare}"]`)?.focus();
  else if (focusId) document.getElementById(focusId)?.focus();
  if (state.promo) main.querySelector("[data-action='promo']")?.focus();
}

function currentLessonIndex(lesson) {
  const reached = state.progress.reached[lesson.id] ?? 0;
  const base = reached >= lesson.steps.length ? 0 : reached;
  return Number(state.forceIndex ?? base);
}

function setLessonIndex(lesson, index) {
  state.forceIndex = index;
  state.progress.reached[lesson.id] = Math.max(state.progress.reached[lesson.id] || 0, index);
  saveProgress();
}

function finishLesson(lesson) {
  if (!state.progress.completedLessons.includes(lesson.id)) state.progress.completedLessons.push(lesson.id);
  state.progress.reached[lesson.id] = lesson.steps.length;
  saveProgress();
  state.forceIndex = lesson.steps.length;
  state.sig = "";
  state.announce = `${lesson.title} complete.`;
}

function onNext() {
  const lesson = findLesson(parseRoute().id);
  if (!lesson || !state.solved) return;
  const index = currentLessonIndex(lesson);
  if (index >= lesson.steps.length - 1) {
    finishLesson(lesson);
    render({ focus: true });
    return;
  }
  setLessonIndex(lesson, index + 1);
  state.announce = lesson.steps[index + 1]?.title || "Next step";
  render({ focus: true });
}

function onBack() {
  const lesson = findLesson(parseRoute().id);
  if (!lesson) return;
  const index = currentLessonIndex(lesson);
  if (index <= 0) return;
  state.forceIndex = index - 1;
  state.sig = "";
  render({ focus: true });
}

function onJump(index) {
  const lesson = findLesson(parseRoute().id);
  if (!lesson) return;
  if (index > (state.progress.reached[lesson.id] ?? 0)) return;
  state.forceIndex = index;
  state.sig = "";
  render({ focus: true });
}

function say(message, kind) {
  state.feedback = message;
  state.feedbackKind = kind;
  state.announce = message;
}

function onChoice(value) {
  const lesson = findLesson(parseRoute().id);
  const step = lesson?.steps[currentLessonIndex(lesson)];
  if (!step || step.type !== "multiple-choice") return;
  if (value === step.correctChoice) {
    state.solved = true;
    state.wrong = "";
    say(step.successText || "Correct.", "ok");
  } else {
    state.wrong = value;
    say(step.errorText || "Try again.", "bad");
  }
  render();
}

function onSquareLesson(square) {
  const lesson = findLesson(parseRoute().id);
  const step = lesson?.steps[currentLessonIndex(lesson)];
  if (!step) return;
  if (step.type === "click-all-squares") {
    const targets = step.targetSquares || [];
    if (!targets.includes(square)) {
      say(step.errorText || "Try one of the highlighted squares.", "bad");
      render();
      return;
    }
    if (!state.found.includes(square)) state.found.push(square);
    if (state.found.length === targets.length) {
      state.solved = true;
      say(step.successText || "You found them all.", "ok");
    } else {
      say(`${state.found.length} of ${targets.length} squares found.`, "ok");
    }
    render({ focusSquare: square });
    return;
  }
  if (step.type === "square-click") {
    if (square === step.targetSquare) {
      state.solved = true;
      state.found = [square];
      say(step.successText || `${square} is right.`, "ok");
    } else {
      say(step.errorText || `Click ${step.targetSquare}.`, "bad");
    }
    render({ focusSquare: square });
    return;
  }
  if (moveStep(step)) {
    if (state.solved) return;
    attemptMove(state.lessonChess, square, step, (played) => {
      state.last = [squareName(played.from), squareName(played.to)];
      state.solved = true;
      say(step.successText || `${played.san} is right.`, "ok");
      beep();
    });
    return;
  }
  const piece = state.lessonChess?.pieceAt(square);
  const name = piece ? `${piece.color === "w" ? "White" : "Black"} ${pieceName(piece.type)} on ${square}` : `${square} is empty`;
  say(name, "");
  render({ focusSquare: square });
}

function attemptMove(chess, square, step, onSuccess) {
  if (!chess) return;
  const piece = chess.pieceAt(square);
  if (state.selected && destinations(chess, state.selected, step).includes(square)) {
    const choices = chess.legalMoves(state.selected).filter((move) => squareName(move.to) === square);
    const { list, lock } = step ? allowedFor(step) : { list: [], lock: false };
    const matching = choices.filter((move) => {
      if (!lock || !list.length) return true;
      const uci = uciOf(move);
      return list.includes(uci) || list.includes(uci.slice(0, 4));
    });
    if (!matching.length) {
      say(step?.errorText || "That move is not part of this exercise.", "bad");
      state.selected = null;
      render({ focusSquare: square });
      return;
    }
    if (matching.length > 1 && matching.every((move) => move.promo)) {
      state.promo = { from: state.selected, to: square, choices: matching.map((move) => move.promo), chess, step, onSuccess };
      render();
      return;
    }
    const played = chess.move(state.selected, square, matching[0].promo || "q");
    state.selected = null;
    if (!played) {
      say("That move is not legal.", "bad");
      render({ focusSquare: square });
      return;
    }
    onSuccess(played);
    render({ focusSquare: squareName(played.to) });
    return;
  }
  if (piece && piece.color === chess.turn) {
    state.selected = state.selected === square ? null : square;
    state.feedback = state.selected ? `${pieceName(piece.type)} selected on ${square}.` : "";
    state.announce = state.feedback;
    render({ focusSquare: square });
    return;
  }
  say(piece ? `It is ${sideLabel(chess.turn)}'s turn.` : "Select one of your pieces.", "bad");
  state.selected = null;
  render({ focusSquare: square });
}

function onSquareDrill(square) {
  const route = parseRoute();
  const drill = state.data.drills.find((item) => item.id === route.id);
  const puzzle = drill?.puzzles[state.drillIndex];
  if (!puzzle || state.solved) return;
  const step = { allowedMoves: puzzle.solution, lockToAllowedMoves: true, errorText: puzzle.hint ? `Not that one. ${puzzle.hint}` : "Try a different legal move." };
  attemptMove(state.drillChess, square, step, (played) => {
    state.last = [squareName(played.from), squareName(played.to)];
    state.solved = true;
    const record = state.progress.drills[drill.id] || { solved: [] };
    if (!record.solved.includes(puzzle.id)) record.solved.push(puzzle.id);
    state.progress.drills[drill.id] = record;
    saveProgress();
    say(puzzle.success || "Correct.", "ok");
    beep();
  });
}

function onSquarePlay(square) {
  const game = state.game;
  if (!game || game.thinking || liveResult(game).over) return;
  if (game.chess.turn !== game.user) return;
  attemptMove(game.chess, square, null, (played) => {
    commitGameMove(played);
    maybeThink();
  });
}

function commitGameMove(played) {
  state.game.history.push({ san: played.san, uci: uciOf(played), color: played.color });
  state.last = [squareName(played.from), squareName(played.to)];
  state.feedback = "";
  beep();
  recordGame();
}

function recordGame() {
  const game = state.game;
  const result = liveResult(game);
  if (!result.over || game.recorded) return;
  game.recorded = true;
  state.progress.games.played += 1;
  if (result.reason === "checkmate") {
    const userWon = (result.winner === "white" && game.user === "w") || (result.winner === "black" && game.user === "b");
    state.progress.games[userWon ? "wins" : "losses"] += 1;
  } else if (result.reason === "resign") {
    state.progress.games.losses += 1;
  } else {
    state.progress.games.draws += 1;
  }
  saveProgress();
}

function maybeThink() {
  const game = state.game;
  if (!game || liveResult(game).over || game.chess.turn === game.user) return;
  const token = ++state.thinkToken;
  game.thinking = true;
  render();
  window.setTimeout(() => {
    if (token !== state.thinkToken || !state.game) return;
    const raw = chooseComputerMove(state.game.chess, state.game.level);
    state.game.thinking = false;
    if (!raw) {
      recordGame();
      render();
      return;
    }
    const move = detailed(state.game.chess, raw);
    state.game.chess.play(move);
    commitGameMove(move);
    state.announce = `${sideLabel(move.color)} plays ${move.san}.`;
    render({ focusSquare: squareName(move.to) });
  }, 240);
}

function onSquareLine(square) {
  const opening = state.data.openings.find((item) => item.id === parseRoute().id);
  if (!opening || state.linePly >= opening.moves.length) return;
  const expected = opening.moves[state.linePly];
  const step = { allowedMoves: [expected.uci], lockToAllowedMoves: true, errorText: "That is not the move in this line. Use the hint if you want a nudge." };
  attemptMove(state.line, square, step, (played) => {
    state.last = [squareName(played.from), squareName(played.to)];
    state.linePly += 1;
    state.showHint = false;
    say(expected.explanation || played.san, "ok");
    beep();
    autoplayLine(opening);
    const reply = opening.moves[state.linePly - 1];
    if (reply && state.linePly > 0 && (state.linePly - 1) % 2 !== (userSide(opening) === "w" ? 0 : 1)) {
      state.feedback = reply.explanation || state.feedback;
    }
  });
}

function onSquareSandbox(square) {
  attemptMove(state.sandbox.chess, square, null, (played) => {
    state.last = [squareName(played.from), squareName(played.to)];
    say(`${played.san}`, "ok");
    beep();
  });
}

function newGame(color) {
  state.thinkToken += 1;
  state.game = {
    chess: new Chess(START_FEN),
    history: [],
    orientation: color,
    user: color,
    level: state.progress.level || "easy",
    thinking: false,
    recorded: false,
  };
  state.selected = null;
  state.last = [];
  state.promo = null;
  state.feedback = color === "b" ? "You are Black. White moves first." : "You are White. Play a move.";
  render({ focus: true });
  if (color === "b") maybeThink();
}

function undoGame() {
  const game = state.game;
  if (!game || game.thinking || !game.history.length) return;
  state.thinkToken += 1;
  let remove = 1;
  if (game.history.at(-1).color !== game.user && game.history.length > 1) remove = 2;
  const keep = game.history.slice(0, -remove);
  const chess = new Chess();
  for (const item of keep) playUci(chess, item.uci);
  game.chess = chess;
  game.history = keep;
  game.recorded = false;
  game.thinking = false;
  state.selected = null;
  state.last = keep.length ? [keep.at(-1).uci.slice(0, 2), keep.at(-1).uci.slice(2, 4)] : [];
  render();
}

function onClick(event) {
  const actionEl = event.target.closest("[data-action]");
  if (!actionEl) return;
  const action = actionEl.dataset.action;
  if (action === "square") {
    const route = parseRoute();
    const square = actionEl.dataset.sq;
    if (route.name === "lesson") onSquareLesson(square);
    else if (route.name === "drill") onSquareDrill(square);
    else if (route.name === "play") onSquarePlay(square);
    else if (route.name === "opening") onSquareLine(square);
    else if (route.name === "sandbox") onSquareSandbox(square);
    return;
  }
  if (action === "next") onNext();
  if (action === "back") onBack();
  if (action === "jump") onJump(Number(actionEl.dataset.index));
  if (action === "choice") onChoice(actionEl.dataset.value);
  if (action === "promo") {
    const promo = state.promo;
    state.promo = null;
    if (!promo) return;
    const played = promo.chess.move(promo.from, promo.to, actionEl.dataset.piece);
    state.selected = null;
    if (played) promo.onSuccess(played);
    render({ focusSquare: played ? squareName(played.to) : promo.to });
  }
  if (action === "hint") {
    const drill = state.data.drills.find((item) => item.id === parseRoute().id);
    const puzzle = drill?.puzzles[state.drillIndex];
    if (puzzle) {
      say(puzzle.hint || "Look for a check or a capture.", "");
      render();
    }
  }
  if (action === "drill-next") {
    const drill = state.data.drills.find((item) => item.id === parseRoute().id);
    if (state.drillIndex >= drill.puzzles.length - 1) {
      location.hash = "#/practice";
      return;
    }
    state.forceDrill = state.drillIndex + 1;
    state.drillSig = "";
    render({ focus: true });
  }
  if (action === "new-game") newGame(actionEl.dataset.color);
  if (action === "undo") undoGame();
  if (action === "flip" && state.game) {
    state.game.orientation = state.game.orientation === "w" ? "b" : "w";
    render();
  }
  if (action === "resign" && state.game && !liveResult(state.game).over) {
    state.game.resigned = true;
    state.game.thinking = false;
    state.thinkToken += 1;
    recordGame();
    state.announce = "You resigned.";
    render();
  }
  if (action === "line-restart") {
    const opening = state.data?.openings.find((item) => item.id === parseRoute().id);
    if (opening) state.progress.openings[opening.id] = { done: false, ply: 0 };
    saveProgress();
    state.lineId = "";
    state.line = null;
    state.showHint = false;
    state.feedback = "";
    render({ focus: true });
  }
  if (action === "level") {
    state.progress.level = actionEl.value;
    if (state.game) state.game.level = actionEl.value;
    saveProgress();
  }
  if (action === "sound") {
    state.progress.sound = actionEl.checked;
    saveProgress();
  }
  if (action === "sandbox-reset") {
    state.sandbox = { chess: new Chess(), orientation: state.sandbox?.orientation || "w" };
    state.selected = null;
    state.last = [];
    render();
  }
  if (action === "sandbox-flip" && state.sandbox) {
    state.sandbox.orientation = state.sandbox.orientation === "w" ? "b" : "w";
    render();
  }
  if (action === "line-hint") {
    state.showHint = true;
    const opening = state.data.openings.find((item) => item.id === parseRoute().id);
    const move = opening?.moves[state.linePly];
    say(move ? `Play ${move.san}. ${move.title || ""}`.trim() : "", "");
    render();
  }
  if (action === "reset") {
    if (window.confirm("Erase lesson, drill, and game progress stored on this device?")) {
      store.remove(KEY);
      state.progress = loadProgress();
      state.sig = "";
      state.announce = "Progress reset.";
      render({ focus: true });
    }
  }
}

function onChange(event) {
  const action = event.target.dataset.action;
  if (action === "filter-side") {
    state.filters.side = event.target.value;
    render({ focusId: "side-filter" });
  }
  if (action === "filter-level") {
    state.filters.level = event.target.value;
    render({ focusId: "level-filter" });
  }
  if (action === "filter-query") {
    state.filters.query = event.target.value;
    render({ focusId: "opening-search" });
  }
  if (action === "level") {
    state.progress.level = event.target.value;
    if (state.game) state.game.level = event.target.value;
    saveProgress();
  }
  if (action === "sound") {
    state.progress.sound = event.target.checked;
    saveProgress();
  }
}

function onInput(event) {
  if (event.target.dataset.action === "filter-query") {
    state.filters.query = event.target.value;
    const start = event.target.selectionStart;
    render({ focusId: "opening-search" });
    const input = document.getElementById("opening-search");
    if (input) {
      input.focus();
      input.setSelectionRange(start, start);
    }
  }
}

function onKey(event) {
  const square = event.target.closest?.("[data-sq]");
  if (!square || !["ArrowUp", "ArrowDown", "ArrowLeft", "ArrowRight"].includes(event.key)) return;
  event.preventDefault();
  const orientation = square.closest(".board").dataset.orientation;
  const delta = {
    ArrowLeft: orientation === "b" ? [1, 0] : [-1, 0],
    ArrowRight: orientation === "b" ? [-1, 0] : [1, 0],
    ArrowUp: orientation === "b" ? [0, -1] : [0, 1],
    ArrowDown: orientation === "b" ? [0, 1] : [0, -1],
  }[event.key];
  const file = Number(square.dataset.file) + delta[0];
  const rank = Number(square.dataset.rank) + delta[1];
  document.querySelector(`[data-file="${file}"][data-rank="${rank}"]`)?.focus();
}

async function boot() {
  document.querySelector("main").addEventListener("click", onClick);
  document.querySelector("main").addEventListener("change", onChange);
  document.querySelector("main").addEventListener("input", onInput);
  document.querySelector("main").addEventListener("keydown", onKey);
  document.querySelector("main").addEventListener("focusin", (event) => {
    const square = event.target.closest?.("[data-sq]");
    if (!square) return;
    square.closest(".board")?.querySelectorAll("[data-sq]").forEach((button) => {
      button.tabIndex = button === square ? 0 : -1;
    });
  });
  window.addEventListener("hashchange", () => {
    state.forceIndex = null;
    state.sig = "";
    state.drillSig = "";
    state.showHint = false;
    state.solved = false;
    state.selected = null;
    state.found = [];
    state.feedback = "";
    state.feedbackKind = "";
    state.promo = null;
    state.last = [];
    state.wrong = "";
    render({ focus: true });
  });
  if (!location.hash) location.hash = "#/home";
  render({ focus: true });
  try {
    const response = await fetch("content/curriculum.json");
    if (!response.ok) throw new Error("missing");
    state.data = await response.json();
  } catch {
    state.loadError = "Lessons could not be loaded. Start a local server from the web folder and open this page again.";
  }
  render({ focus: true });
}

boot();
