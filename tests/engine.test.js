// Engine tests. Appended after the page's engine code by tests/run.sh and run with
// macOS JavaScript for Automation (osascript -l JavaScript). Returns a text report.
const results = [];
const ok = (name, cond, info) => results.push((cond ? "OK   " : "FALHA") + " " + name + (info ? "  (" + info + ")" : ""));
const near = (a, b, tol) => Math.abs(a - b) <= tol;
defaults();
const rows = DATA.BTCUSDT, o_ = rows.map(x => x[1]), h = rows.map(x => x[2]), l = rows.map(x => x[3]), c = rows.map(x => x[4]);

// 1) No look-ahead: signals and HMM states computed on a prefix equal the full-history values.
for (const s of STRATS) {
  const p = st.params[s.id], full = signals(s.id, p, c, h, l, true).pos; let bad = 0;
  for (const K of [900, 1700, 2400]) { const cut = signals(s.id, p, c.slice(0, K), h.slice(0, K), l.slice(0, K), true).pos; for (let t = 0; t < K; t++) if (cut[t] !== full[t]) bad++; }
  ok("sem olhar o futuro: " + s.id, bad === 0, bad + " diferenças");
}
{ const fe = Math.floor(c.length * 0.45), full = hmmTrend(c, fe), part = hmmTrend(c.slice(0, 2400), fe); let bad = 0;
  for (let t = 0; t < 2400; t++) if (part.trend[t] !== full.trend[t]) bad++;
  ok("sem olhar o futuro: HMM", full.ok && bad === 0, bad + " diferenças"); }

// 2) Simulator vs an independent vectorized calculation (no stops, no fees).
for (const id of ["sma", "macd", "st", "ichi"]) {
  EX = { mode: "fixed", roi: false, atrPct: null };
  const pos = signals(id, st.params[id], c, h, l, true).pos, start = 300, end = c.length - 1;
  const sim = simulate(pos, { o: o_, h, l, c }, 0, start, end, Infinity, Infinity, id);
  let a = 1, b = 1; for (let t = start + 1; t <= end; t++) { a *= 1 + sim.r[t]; b *= 1 + pos[t - 1] * (c[t] / c[t - 1] - 1); }
  ok("simulador = cálculo vetorizado: " + id, near(Math.log(a), Math.log(b), 1e-9), a.toFixed(6) + " vs " + b.toFixed(6));
}

// 3) Exit rules on small synthetic series.
EX = { mode: "trail", roi: false, atrPct: null };
{ const D = { o: [100, 100, 110, 120, 118], h: [100, 105, 115, 125, 119], l: [100, 99, 108, 117, 105], c: [100, 104, 112, 121, 110] };
  const t = simulate([1, 1, 1, 1, 1], D, 0, 0, 4, 0.1, Infinity, "x").trades[0];
  ok("stop móvel sai a 10% da máxima anterior", t.exitType === "trail" && t.x === 4 && near(t.exitPx, 112.5, 1e-9), JSON.stringify([t.exitType, t.x, t.exitPx])); }
EX = { mode: "fixed", roi: true, atrPct: null };
{ const n = 12, D = { o: Array(n).fill(100), h: Array(n).fill(101), l: Array(n).fill(99), c: Array(n).fill(100) };
  const t = simulate(Array(n).fill(1), D, 0, 0, n - 1, Infinity, 0.02, "x").trades[0];
  ok("alvo por tempo: metade do alvo a partir do 7º dia", t.exitType === "roi" && t.x === 7 && t.exitPx === 101, JSON.stringify([t.exitType, t.x, t.exitPx])); }
EX = { mode: "fixed", roi: false, atrPct: null };
{ const D = { o: [100, 95, 100], h: [100, 101, 100], l: [100, 89, 100], c: [100, 96, 100] };
  const t = simulate([1, 1, 1], D, 0, 0, 2, 0.1, 0.01, "x").trades[0];
  ok("stop e alvo no mesmo candle: conta o stop", t.exitType === "stop" && t.exitPx === 90, JSON.stringify([t.exitType, t.exitPx])); }
{ const D = { o: [100, 85, 100], h: [100, 90, 100], l: [100, 80, 100], c: [100, 88, 100] };
  const t = simulate([1, 1, 1], D, 0, 0, 2, 0.1, Infinity, "x").trades[0];
  ok("gap abaixo do stop: sai na abertura", t.exitPx === 85, String(t.exitPx)); }

// 4) Walk-forward: training never reaches the test window.
Object.assign(st, { asset: "BTCUSDT", val: "wf", folds: 5, wfInit: 40, wfMode: "anchored", stops: "on", stopCrit: "wins", stopMode: "fixed", roi: "fixed", rsrc: "sma", tf: "strict", short: false, fee: 10, from: null, to: null });
let RW = run();
ok("walk-forward: treino e simulação terminam antes do teste", RW.folds.every(f => f.simEnd < f.cut && f.train.every(t => t < f.cut)));

// 5) Regression: known results (BTC, out of sample, walk-forward 5 windows).
ok("regressão: cruzamento de médias, mais wins = -4,6%/ano", near(stats(RW.res.sma.r, RW.test).cagr, -0.046, 0.0015), (stats(RW.res.sma.r, RW.test).cagr * 100).toFixed(2) + "%");
st.stopCrit = "exp"; RW = run();
ok("regressão: cruzamento de médias, melhor expectativa = 15,9%/ano", near(stats(RW.res.sma.r, RW.test).cagr, 0.159, 0.0015), (stats(RW.res.sma.r, RW.test).cagr * 100).toFixed(2) + "%");
ok("regressão: buy & hold = 11,7%/ano", near(stats(RW.res.bh.r, RW.test).cagr, 0.117, 0.0015), (stats(RW.res.bh.r, RW.test).cagr * 100).toFixed(2) + "%");

const fails = results.filter(r => r.startsWith("FALHA")).length;
results.join("\n") + "\n\n" + (fails ? fails + " teste(s) falharam" : "Todos os " + results.length + " testes passaram");
