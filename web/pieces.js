const SHAPES = {
  p: `<circle cx="22.5" cy="15" r="6"/><path d="M15.2 34.5h14.6l-1.8-8.2a8.2 8.2 0 0 0-11 0z"/><path d="M13 36.5h19v2.2H13z"/>`,
  r: `<path d="M12 36.5h21v-3.2H12z"/><path d="M14 33.3h17l-1.2-14h3.4V9.2h-4.2v5.2h-3.2V9.2h-4.2v5.2h-3.2V9.2H13v10.1h3.2z"/>`,
  n: `<path d="M31.5 36.5h-18l1.6-6.4 4.2.8 1.3-5.6-5.2 2.4c-4.4-1.6-6.2-7.2-3.4-11.2 2.2-3.2 7.2-4.2 10-1.6l1.4-4.4 6.4 3.2c3.4 2.2 4.2 6.4 1.8 9.6l-3.6 4.6 4.8 2.2z"/>`,
  b: `<path d="M22.5 7.2a4.3 4.3 0 0 1 2.2 8c1.6.8 3.2 2.4 3.6 4.2-2.2 1.4-5.4.6-5.8-.8-2.4 6.8-4 12.4-5.2 16.4h12.4c-1.6-5-4-11.6-5.4-16.2 1.8 1.2 4.6.6 5.6-1.2.2-2.2-1.4-4.6-3.6-5.6a4.3 4.3 0 0 1-3.8-4.8z"/><path d="M13.5 36.5h18v2.2h-18z"/>`,
  q: `<path d="M10 16.5 14.2 32h16.6L35 16.5l-5.2 5.2L22.5 10l-7.3 11.7z"/><circle cx="10" cy="15.2" r="2.3"/><circle cx="16.2" cy="12.2" r="2.3"/><circle cx="22.5" cy="8.4" r="2.3"/><circle cx="28.8" cy="12.2" r="2.3"/><circle cx="35" cy="15.2" r="2.3"/><path d="M14 34.2h17v2.3H14z"/>`,
  k: `<path d="M22.5 5.2v6.4M19.3 8.4h6.4"/><path d="M15.2 36.5h14.6L27.6 22c3.6.8 6.2-2.4 4.4-5.6-2.8 2.2-6.2 1.2-7.4-.6h-4.2c-1.2 1.8-4.6 2.8-7.4.6-1.8 3.2.8 6.4 4.4 5.6z"/><path d="M13.6 36.5h17.8v2.2H13.6z"/>`,
};

export function pieceSvg(color, type) {
  const white = color === "w";
  const fill = white ? "#fbf7ef" : "#241c16";
  const stroke = white ? "#3a2d22" : "#f4ecdf";
  return `<svg viewBox="0 0 45 45" aria-hidden="true" focusable="false"><g fill="${fill}" stroke="${stroke}" stroke-width="1.6" stroke-linejoin="round" stroke-linecap="round">${SHAPES[type] || ""}</g></svg>`;
}

export function pieceName(type) {
  return { p: "pawn", n: "knight", b: "bishop", r: "rook", q: "queen", k: "king" }[type] || "piece";
}
