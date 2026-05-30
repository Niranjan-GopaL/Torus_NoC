// build_arch_v3.js — only the two VC variants, with the "Plane 0 (purple) / Plane 1 (red)" rework.
// Run with: node build_arch_v3.js   then sharp each svg_v3/*.svg into png at density 160.

const fs = require('fs');
const path = require('path');

const C = {
  bg:'#131C2A', card:'#E8EAEF', cardEdge:'#9FA6B2', cardTxt:'#1A2540',
  cardMuted:'#5A6878', rail:'#1F2D42', railEdge:'#2E3F5A',
  data:'#F5B14B',
  vrsBlue:'#5BBAF0', fifoCyan:'#26C6DA',
  vc0:'#7C4DFF',   // purple — Plane 0
  vc1:'#EC407A',   // red    — Plane 1
  pN:'#00ACC1', pS:'#E91E63', pE:'#43A047', pW:'#FB8C00', pL:'#8E24AA',
  white:'#FFFFFF', muted:'#7C8B9D',
};
const PORT_COLORS = [C.pN, C.pS, C.pE, C.pW, C.pL];
const PORT_NAMES  = ['N','S','E','W','L'];
const VC_COLORS   = [C.vc0, C.vc1];

function bgNavy(w, h) {
  return `<defs>
    <pattern id="dots-navy" width="20" height="20" patternUnits="userSpaceOnUse">
      <circle cx="2" cy="2" r="1" fill="#2C3D58"/>
    </pattern>
  </defs>
  <rect width="${w}" height="${h}" fill="${C.bg}"/>
  <rect width="${w}" height="${h}" fill="url(#dots-navy)" opacity="0.45"/>`;
}
function wire(x1, y1, x2, y2, color, opts = {}) {
  const w  = opts.width   || 1.8;
  const op = opts.opacity ?? 1;
  return `<line x1="${x1}" y1="${y1}" x2="${x2}" y2="${y2}" stroke="${color}" stroke-width="${w}" opacity="${op}"/>`;
}

function svgRouterVC(useFifoOut) {
  const W = 1900, H = 1100;
  const NUM_VC = 2;

  const title    = useFifoOut ? 'vc_router_output_fifo.sv' : 'vc_router.sv';
  const subtitle = useFifoOut
    ? `Plane 0 (purple, VC0) + Plane 1 (red, VC1) · stage-2 VC arbiter · FIFO at output`
    : `Plane 0 (purple, VC0) + Plane 1 (red, VC1) · stage-2 VC arbiter · slice at output`;

  let s = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${W} ${H}">
    ${bgNavy(W, H)}
    <text x="60" y="58" fill="${C.white}" font-family="JetBrains Mono,monospace" font-size="34" font-weight="700">${title}</text>
    <text x="60" y="92" fill="${C.muted}" font-family="Inter,Helvetica,sans-serif" font-size="16">${subtitle}</text>`;

  // Layout — no wrapper plane card any more
  const yTop = 165, yPitch = 175;
  const inArrowX = 30;
  const counterX = 110, counterW = 70;
  const fifoX  = 220, fifoW  = 145;
  const splitX = fifoX + fifoW + 30;   // 395
  const splitW = 105;
  const mergeX = 1410, mergeW = 105;
  const arbX   = mergeX + mergeW + 30; // 1545
  const arbW   = 100;
  const outBufX = arbX + arbW + 25;    // 1670
  const outBufW = 195;

  // Per-VC stub Y helpers (so the 4 wires fan from each split / converge into each merge)
  function srcStubY(src, v, dstIdx) {
    const sy = yTop + src*yPitch + 70 + (v === 0 ? -30 : 30);
    return sy - 14 + dstIdx*9;
  }
  function dstStubY(dst, v, srcIdx) {
    const my = yTop + dst*yPitch + 70 + (v === 0 ? -30 : 30);
    return my - 14 + srcIdx*9;
  }

  // ---- Crossbar wires: draw VC1 (dimmed) BEHIND VC0 (bright) ----
  for (let v = 1; v >= 0; v--) {
    const wireColor   = VC_COLORS[v];
    const wireOpacity = v === 0 ? 0.95 : 0.18;
    const wireWidth   = v === 0 ? 1.9  : 1.2;
    for (let src = 0; src < 5; src++) {
      let dstIdx = 0;
      for (let dst = 0; dst < 5; dst++) {
        if (dst === src) continue;
        const y1 = srcStubY(src, v, dstIdx);
        const srcIdx = (src < dst) ? src : (src - 1);
        const y2 = dstStubY(dst, v, srcIdx);
        const sx = splitX + splitW;
        const mx = mergeX;
        s += `<path d="M ${sx} ${y1} C ${sx + 320} ${y1}, ${mx - 320} ${y2}, ${mx} ${y2}"
                fill="none" stroke="${wireColor}" stroke-width="${wireWidth}" opacity="${wireOpacity}"/>`;
        if (v === 0) {
          s += `<polygon points="${mx-5},${y2-3} ${mx},${y2} ${mx-5},${y2+3}" fill="${wireColor}" opacity="${wireOpacity}"/>`;
        }
        dstIdx++;
      }
    }
  }

  // ---- Per-row components (no wrapper plane card) ----
  for (let p = 0; p < 5; p++) {
    const yc = yTop + p*yPitch + 70;
    const color = PORT_COLORS[p];

    // incoming arrow + label
    s += `<text x="${inArrowX}" y="${yc - 12}" fill="${color}" font-family="JetBrains Mono,monospace" font-size="13" font-weight="700">from ${PORT_NAMES[p]}</text>
          <line x1="${inArrowX}" y1="${yc}" x2="${counterX - 6}" y2="${yc}" stroke="${color}" stroke-width="2.2"/>
          <polygon points="${counterX-6},${yc-7} ${counterX+6},${yc} ${counterX-6},${yc+7}" fill="${color}"/>`;

    // VC counter pip
    s += `<rect x="${counterX}" y="${yc - 28}" width="${counterW}" height="56" rx="8" fill="${C.card}" stroke="${color}" stroke-width="1.6"/>
          <text x="${counterX + counterW/2}" y="${yc - 12}" fill="${C.cardMuted}" font-family="JetBrains Mono,monospace" font-size="9"  letter-spacing="1.5" text-anchor="middle">VC SEL</text>
          <text x="${counterX + counterW/2}" y="${yc + 4}"  fill="${C.cardTxt}"   font-family="JetBrains Mono,monospace" font-size="13" font-weight="700"   text-anchor="middle">counter</text>
          <text x="${counterX + counterW/2}" y="${yc + 20}" fill="${C.cardMuted}" font-family="JetBrains Mono,monospace" font-size="10" text-anchor="middle">→ 0 | 1</text>`;

    // counter → VC0/VC1 FIFOs (two arrows split out)
    for (let v = 0; v < NUM_VC; v++) {
      const vy = yc + (v === 0 ? -30 : 30);
      s += `<path d="M ${counterX + counterW} ${yc} C ${counterX + counterW + 30} ${yc}, ${fifoX - 30} ${vy}, ${fifoX - 4} ${vy}"
              fill="none" stroke="${VC_COLORS[v]}" stroke-width="1.6" opacity="0.85"/>
            <polygon points="${fifoX-4},${vy-5} ${fifoX+5},${vy} ${fifoX-4},${vy+5}" fill="${VC_COLORS[v]}" opacity="0.9"/>`;
    }

    // Per-VC FIFO / split / merge (bare boxes, no wrapper)
    for (let v = 0; v < NUM_VC; v++) {
      const vy = yc + (v === 0 ? -30 : 30);
      const vColor = VC_COLORS[v];

      // FIFO
      s += `<rect x="${fifoX}" y="${vy - 18}" width="${fifoW}" height="36" rx="5" fill="${C.bg}" stroke="${vColor}" stroke-width="1.6"/>
            <text x="${fifoX + 10}" y="${vy + 4}" fill="${vColor}" font-family="JetBrains Mono,monospace" font-size="11" font-weight="700">VC${v} FIFO</text>`;
      for (let i = 0; i < 3; i++) {
        s += `<rect x="${fifoX + 80 + i*18}" y="${vy - 9}" width="14" height="18" rx="2" fill="${C.bg}" stroke="${vColor}" stroke-width="0.9" opacity="0.85"/>`;
      }

      // Split
      s += `<rect x="${splitX}" y="${vy - 18}" width="${splitW}" height="36" rx="5" fill="${C.bg}" stroke="${vColor}" stroke-width="1.6"/>
            <text x="${splitX + splitW/2}" y="${vy - 2}"  fill="${vColor}" font-family="JetBrains Mono,monospace" font-size="11" font-weight="700" text-anchor="middle">split</text>
            <text x="${splitX + splitW/2}" y="${vy + 12}" fill="${vColor}" font-family="JetBrains Mono,monospace" font-size="10" text-anchor="middle" opacity="0.85">VC${v}</text>`;

      // Merge
      s += `<rect x="${mergeX}" y="${vy - 18}" width="${mergeW}" height="36" rx="5" fill="${C.bg}" stroke="${vColor}" stroke-width="1.6"/>
            <text x="${mergeX + mergeW/2}" y="${vy - 2}"  fill="${vColor}" font-family="JetBrains Mono,monospace" font-size="11" font-weight="700" text-anchor="middle">merge</text>
            <text x="${mergeX + mergeW/2}" y="${vy + 12}" fill="${vColor}" font-family="JetBrains Mono,monospace" font-size="10" text-anchor="middle" opacity="0.85">VC${v}</text>`;

      // FIFO → split wire per VC
      s += wire(fifoX + fifoW, vy, splitX, vy, vColor, { width: 1.4, opacity: 0.9 });
    }

    // Stage-2 arb
    s += `<rect x="${arbX}" y="${yc - 38}" width="${arbW}" height="76" rx="8" fill="${C.card}" stroke="${color}" stroke-width="2"/>
          <text x="${arbX + arbW/2}" y="${yc - 18}" fill="${C.cardMuted}" font-family="JetBrains Mono,monospace" font-size="10" letter-spacing="1.5" text-anchor="middle">STAGE-2</text>
          <text x="${arbX + arbW/2}" y="${yc + 2}"  fill="${C.cardTxt}"   font-family="JetBrains Mono,monospace" font-size="13" font-weight="700"   text-anchor="middle">VC arb</text>
          <text x="${arbX + arbW/2}" y="${yc + 20}" fill="${C.cardMuted}" font-family="JetBrains Mono,monospace" font-size="10" text-anchor="middle">${NUM_VC} → 1 RR</text>`;

    // merge.VCv → arb
    for (let v = 0; v < NUM_VC; v++) {
      const vy = yc + (v === 0 ? -30 : 30);
      s += `<path d="M ${mergeX + mergeW} ${vy} C ${mergeX + mergeW + 18} ${vy}, ${arbX - 18} ${yc}, ${arbX} ${yc}"
              fill="none" stroke="${VC_COLORS[v]}" stroke-width="1.6" opacity="0.9"/>`;
    }

    // Output buffer
    if (useFifoOut) {
      s += `<rect x="${outBufX}" y="${yc - 50}" width="${outBufW}" height="100" rx="10" fill="${C.card}" stroke="${C.fifoCyan}" stroke-width="2"/>
            <text x="${outBufX + 12}" y="${yc - 30}" fill="${C.fifoCyan}" font-family="JetBrains Mono,monospace" font-size="11" letter-spacing="1.5">OUT ${PORT_NAMES[p]}</text>
            <text x="${outBufX + outBufW/2}" y="${yc - 4}" fill="${C.cardTxt}" font-family="JetBrains Mono,monospace" font-size="13" font-weight="700" text-anchor="middle">fifo_sync</text>`;
      for (let i = 0; i < 4; i++) {
        s += `<rect x="${outBufX + 22 + i*36}" y="${yc + 12}" width="30" height="28" rx="3" fill="${C.bg}" stroke="${C.fifoCyan}" stroke-width="1.2"/>
              <text x="${outBufX + 37 + i*36}" y="${yc + 30}" fill="${C.fifoCyan}" font-family="JetBrains Mono,monospace" font-size="10" text-anchor="middle">${i<2?'B'+i:'··'}</text>`;
      }
    } else {
      s += `<rect x="${outBufX}" y="${yc - 50}" width="${outBufW}" height="100" rx="10" fill="${C.card}" stroke="${C.vrsBlue}" stroke-width="2"/>
            <text x="${outBufX + 12}" y="${yc - 30}" fill="${C.vrsBlue}" font-family="JetBrains Mono,monospace" font-size="11" letter-spacing="1.5">OUT ${PORT_NAMES[p]}</text>
            <text x="${outBufX + outBufW/2}" y="${yc + 2}"  fill="${C.cardTxt}" font-family="JetBrains Mono,monospace" font-size="14" font-weight="700" text-anchor="middle">valid_ready_slice</text>
            <rect x="${outBufX + 50}" y="${yc + 18}" width="${outBufW - 100}" height="22" rx="4" fill="${C.bg}" stroke="${C.vrsBlue}" stroke-width="1.4"/>
            <text x="${outBufX + outBufW/2}" y="${yc + 34}" fill="${C.vrsBlue}" font-family="JetBrains Mono,monospace" font-size="11" text-anchor="middle">depth 1</text>`;
    }

    // arb → output buffer
    s += wire(arbX + arbW, yc, outBufX, yc, C.data, { width: 1.8 });

    // outgoing arrow
    const outColor = useFifoOut ? C.fifoCyan : C.vrsBlue;
    s += `<line x1="${outBufX + outBufW}" y1="${yc}" x2="${W - 60}" y2="${yc}" stroke="${outColor}" stroke-width="2.2"/>
          <polygon points="${W-60},${yc-7} ${W-48},${yc} ${W-60},${yc+7}" fill="${outColor}"/>
          <text x="${W - 40}" y="${yc - 5}" fill="${outColor}" font-family="JetBrains Mono,monospace" font-size="13" font-weight="700">to ${PORT_NAMES[p]}</text>`;
  }

  // Foot legend
  s += `<g transform="translate(60, 1020)">
    <rect x="0" y="0" width="${W - 120}" height="64" rx="8" fill="${C.rail}" stroke="${C.railEdge}" stroke-width="1"/>
    <text x="20" y="26" fill="${C.muted}" font-family="JetBrains Mono,monospace" font-size="11" letter-spacing="1.5">PLANES</text>
    <line x1="100" y1="22" x2="160" y2="22" stroke="${C.vc0}" stroke-width="3"/>
    <text x="170" y="27" fill="${C.vc0}" font-family="JetBrains Mono,monospace" font-size="13" font-weight="700">Plane 0  (VC0, purple) — bright</text>
    <line x1="660" y1="22" x2="720" y2="22" stroke="${C.vc1}" stroke-width="3" opacity="0.4"/>
    <text x="730" y="27" fill="${C.vc1}" font-family="JetBrains Mono,monospace" font-size="13" opacity="0.7">Plane 1  (VC1, red) — dimmed</text>
    <text x="20" y="52" fill="${C.muted}" font-family="JetBrains Mono,monospace" font-size="11">Each plane is an independent 5×5 crossbar (every split → every merge, no U-turns). Stage-2 arb picks one VC winner per output.</text>
  </g>`;

  return s + `</svg>`;
}

const out = path.join(__dirname, 'svg_v3');
fs.mkdirSync(out, { recursive: true });
const targets = {
  'router_5x5_vc.svg':         svgRouterVC(false),
  'router_5x5_vc_outfifo.svg': svgRouterVC(true),
};
for (const [n, c] of Object.entries(targets)) {
  const safe = c.replace(/>([^<]*?)<(\d)/g, (m, a, d) => `>${a}&lt;${d}`);
  fs.writeFileSync(path.join(out, n), safe);
}
console.log('wrote', Object.keys(targets).length, 'svgs to', out);