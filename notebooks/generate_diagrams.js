// Build all custom SVG diagrams matching the fifo_sync dark aesthetic.
// Palette: bg=#0A0E13, panel=#11161D, accent_orange=#F5B14B (data),
//          accent_green=#5BD982 (valid), accent_blue=#5BBAF0 (ready),
//          violet=#A88BFA, pink=#E879A8, muted=#5C6B7A, text=#D7E1EA
// All diagrams use a faint dot-grid background and JetBrains-Mono style.
const fs = require('fs');
const path = require('path');

const COLORS = {
  bg:     '#0A0E13',
  panel:  '#11161D',
  panel2: '#1B2230',
  grid:   '#1F2933',
  data:   '#F5B14B',
  valid:  '#5BD982',
  ready:  '#5BBAF0',
  violet: '#A88BFA',
  pink:   '#F076B0',
  cyan:   '#65D7E5',
  muted:  '#5C6B7A',
  text:   '#D7E1EA',
  faint:  '#3B4654',
};

// Dot-grid background
function grid(w, h) {
  return `<defs><pattern id="dots" width="14" height="14" patternUnits="userSpaceOnUse">
    <circle cx="1" cy="1" r="0.8" fill="${COLORS.grid}"/>
  </pattern></defs>
  <rect width="${w}" height="${h}" fill="${COLORS.bg}"/>
  <rect width="${w}" height="${h}" fill="url(#dots)" opacity="0.5"/>`;
}

// header() small caption + big title
function header(x, y, kicker, title) {
  return `<text x="${x}" y="${y}" fill="${COLORS.muted}" font-family="JetBrains Mono, monospace" font-size="13" font-weight="500" letter-spacing="2">${kicker}</text>
    <text x="${x}" y="${y+46}" fill="${COLORS.text}" font-family="JetBrains Mono, monospace" font-size="48" font-weight="700">${title}</text>`;
}

function signalLine(x1, y, x2, color, label, labelPos = 'start') {
  const tx = labelPos === 'start' ? x1 : x2 - 6;
  const ta = labelPos === 'start' ? 'start' : 'end';
  return `<line x1="${x1}" y1="${y}" x2="${x2-8}" y2="${y}" stroke="${color}" stroke-width="2.2"/>
    <polygon points="${x2-8},${y-5} ${x2},${y} ${x2-8},${y+5}" fill="${color}"/>
    <text x="${tx}" y="${y-9}" fill="${color}" font-family="JetBrains Mono, monospace" font-size="13" font-weight="500" text-anchor="${ta}">${label}</text>`;
}

function signalLineRev(x1, y, x2, color, label) {
  // arrow points left (back-pressure direction)
  return `<line x1="${x1+8}" y1="${y}" x2="${x2}" y2="${y}" stroke="${color}" stroke-width="2.2"/>
    <polygon points="${x1+8},${y-5} ${x1},${y} ${x1+8},${y+5}" fill="${color}"/>
    <text x="${x2}" y="${y-9}" fill="${color}" font-family="JetBrains Mono, monospace" font-size="13" font-weight="500" text-anchor="end">${label}</text>`;
}

function box(x, y, w, h, label, sub) {
  return `<rect x="${x}" y="${y}" width="${w}" height="${h}" rx="6" fill="${COLORS.panel}" stroke="${COLORS.faint}" stroke-width="1.5"/>
    <text x="${x+w/2}" y="${y+h/2-4}" fill="${COLORS.text}" font-family="JetBrains Mono, monospace" font-size="18" font-weight="700" text-anchor="middle">${label}</text>
    ${sub ? `<text x="${x+w/2}" y="${y+h/2+18}" fill="${COLORS.muted}" font-family="JetBrains Mono, monospace" font-size="12" text-anchor="middle">${sub}</text>` : ''}`;
}

function panel(x, y, w, h, title) {
  return `<rect x="${x}" y="${y}" width="${w}" height="${h}" rx="6" fill="none" stroke="${COLORS.faint}" stroke-width="1"/>
    ${title ? `<text x="${x+14}" y="${y+22}" fill="${COLORS.muted}" font-family="JetBrains Mono, monospace" font-size="11" letter-spacing="2">${title}</text>` : ''}`;
}

function condBox(x, y, w, h, title, lines) {
  const out = [`<rect x="${x}" y="${y}" width="${w}" height="${h}" rx="6" fill="${COLORS.panel}" stroke="${COLORS.faint}" stroke-width="1"/>`,
    `<circle cx="${x+16}" cy="${y+22}" r="3.5" fill="${COLORS.valid}"/>`,
    `<text x="${x+28}" y="${y+27}" fill="${COLORS.text}" font-family="JetBrains Mono, monospace" font-size="12" font-weight="600" letter-spacing="2">${title}</text>`];
  let cy = y + 56;
  for (const ln of lines) {
    if (ln.section) {
      out.push(`<text x="${x+16}" y="${cy}" fill="${COLORS.muted}" font-family="JetBrains Mono, monospace" font-size="10" letter-spacing="2">${ln.section}</text>`);
      cy += 18;
    } else if (ln.html) {
      out.push(`<text x="${x+16}" y="${cy}" font-family="JetBrains Mono, monospace" font-size="13">${ln.html}</text>`);
      cy += ln.bigGap ? 28 : 22;
    } else if (ln.gap) {
      cy += ln.gap;
    }
  }
  return out.join('\n');
}

// utility: colored span for inline text
const sp = (text, color, weight = 500) => `<tspan fill="${color}" font-weight="${weight}">${text}</tspan>`;

// =============================================================================
// 1. valid_ready_slice
// =============================================================================
function svgValidReadySlice() {
  const W = 1600, H = 820;
  return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${W} ${H}">
    ${grid(W, H)}
    <text x="60" y="40" fill="${COLORS.muted}" font-family="JetBrains Mono, monospace" font-size="13" letter-spacing="2">// SKID BUFFER · DEPTH 1 · READY-VALID HANDSHAKE</text>
    <text x="60" y="100" fill="${COLORS.text}" font-family="JetBrains Mono, monospace" font-size="52" font-weight="700">valid_ready_slice</text>
    <text x="60" y="140" fill="${COLORS.muted}" font-family="JetBrains Mono, monospace" font-size="15">A 1-deep registered buffer. Output is the registered value, never combinational from input.</text>
    <text x="60" y="162" fill="${COLORS.muted}" font-family="JetBrains Mono, monospace" font-size="15">Used on output ports of every router for timing isolation across hops.</text>

    ${panel(60, 220, 920, 480, '// DATAPATH')}

    <!-- inputs -->
    ${signalLine(110, 320, 470, COLORS.data, 'data_in [7:0]')}
    ${signalLine(110, 380, 470, COLORS.valid, 'valid_in')}
    ${signalLineRev(110, 440, 470, COLORS.ready, 'ready_out = !data_valid')}

    <!-- the register -->
    <rect x="470" y="290" width="220" height="200" rx="8" fill="${COLORS.panel2}" stroke="${COLORS.faint}" stroke-width="1.5"/>
    <text x="580" y="320" fill="${COLORS.muted}" font-family="JetBrains Mono, monospace" font-size="11" letter-spacing="2" text-anchor="middle">DATA_REG [7:0]</text>
    <rect x="510" y="345" width="140" height="60" rx="4" fill="${COLORS.bg}" stroke="${COLORS.data}" stroke-width="1.5"/>
    <text x="580" y="382" fill="${COLORS.data}" font-family="JetBrains Mono, monospace" font-size="20" font-weight="700" text-anchor="middle">B0</text>
    <text x="580" y="450" fill="${COLORS.valid}" font-family="JetBrains Mono, monospace" font-size="14" font-weight="600" text-anchor="middle">data_valid = 1</text>

    <!-- outputs -->
    ${signalLine(690, 320, 970, COLORS.data, 'data_out [7:0]', 'end')}
    ${signalLine(690, 380, 970, COLORS.valid, 'valid_out', 'end')}
    ${signalLineRev(690, 440, 970, COLORS.ready, 'ready_in')}

    <!-- clk/rst pegs -->
    <line x1="540" y1="490" x2="540" y2="540" stroke="${COLORS.violet}" stroke-width="2"/>
    <circle cx="540" cy="545" r="4" fill="${COLORS.violet}"/>
    <text x="540" y="568" fill="${COLORS.violet}" font-family="JetBrains Mono, monospace" font-size="12" text-anchor="middle">clk</text>

    <line x1="615" y1="490" x2="615" y2="540" stroke="${COLORS.pink}" stroke-width="2"/>
    <circle cx="615" cy="545" r="4" fill="${COLORS.pink}"/>
    <text x="615" y="568" fill="${COLORS.pink}" font-family="JetBrains Mono, monospace" font-size="12" text-anchor="middle">rst_n</text>

    ${condBox(1020, 220, 540, 480, '● CONDITIONS', [
      { section: 'HANDSHAKE OUTPUTS  // COMBINATIONAL' },
      { html: `<tspan x="1036" fill="${COLORS.ready}">ready_out</tspan><tspan fill="${COLORS.text}"> = </tspan><tspan fill="${COLORS.text}">rst_n &amp;&amp; !</tspan><tspan fill="${COLORS.violet}">data_valid</tspan>` },
      { html: `<tspan x="1036" fill="${COLORS.valid}">valid_out</tspan><tspan fill="${COLORS.text}"> = </tspan><tspan fill="${COLORS.violet}">data_valid</tspan>` },
      { html: `<tspan x="1036"> </tspan><tspan fill="${COLORS.data}">data_out</tspan><tspan fill="${COLORS.text}"> = </tspan><tspan fill="${COLORS.data}">data_reg</tspan>`, bigGap: true },
      { section: 'TRANSFER  // ON POSEDGE CLK' },
      { html: `<tspan x="1036" fill="${COLORS.text}">accept_in </tspan><tspan fill="${COLORS.text}">= </tspan><tspan fill="${COLORS.valid}">valid_in</tspan><tspan fill="${COLORS.text}"> &amp;&amp; </tspan><tspan fill="${COLORS.ready}">ready_out</tspan>` },
      { html: `<tspan x="1036" fill="${COLORS.text}">drain     </tspan><tspan fill="${COLORS.text}">= </tspan><tspan fill="${COLORS.violet}">data_valid</tspan><tspan fill="${COLORS.text}"> &amp;&amp; </tspan><tspan fill="${COLORS.ready}">ready_in</tspan>`, bigGap: true },
      { section: 'STATE UPDATE' },
      { html: `<tspan x="1036" fill="${COLORS.text}">if (accept_in)  </tspan><tspan fill="${COLORS.violet}">data_valid</tspan><tspan fill="${COLORS.text}"> &lt;= 1</tspan>` },
      { html: `<tspan x="1036" fill="${COLORS.text}">else if (drain) </tspan><tspan fill="${COLORS.violet}">data_valid</tspan><tspan fill="${COLORS.text}"> &lt;= 0</tspan>` },
    ])}
  </svg>`;
}

// =============================================================================
// 2. split_1to4
// =============================================================================
function svgSplit() {
  const W = 1600, H = 820;
  return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${W} ${H}">
    ${grid(W, H)}
    <text x="60" y="40" fill="${COLORS.muted}" font-family="JetBrains Mono, monospace" font-size="13" letter-spacing="2">// 1→4 DEMUX · ROUTING-DRIVEN · NO U-TURN</text>
    <text x="60" y="100" fill="${COLORS.text}" font-family="JetBrains Mono, monospace" font-size="52" font-weight="700">split_1to4_simple</text>
    <text x="60" y="140" fill="${COLORS.muted}" font-family="JetBrains Mono, monospace" font-size="15">Fans the input into one of four output directions chosen by xy_route_logic.</text>
    <text x="60" y="162" fill="${COLORS.muted}" font-family="JetBrains Mono, monospace" font-size="15">The input's own direction is excluded — flits never make a U-turn.</text>

    ${panel(60, 220, 1000, 530, '// DATAPATH')}

    <!-- input -->
    ${signalLine(100, 360, 380, COLORS.data, 'data_in [7:0]')}
    ${signalLine(100, 420, 380, COLORS.valid, 'valid_in')}
    ${signalLineRev(100, 480, 380, COLORS.ready, 'ready_in')}

    <!-- route logic -->
    <rect x="380" y="330" width="170" height="190" rx="6" fill="${COLORS.panel2}" stroke="${COLORS.violet}" stroke-width="1.5"/>
    <text x="465" y="420" fill="${COLORS.violet}" font-family="JetBrains Mono, monospace" font-size="15" font-weight="700" text-anchor="middle">xy_route</text>
    <text x="465" y="442" fill="${COLORS.muted}" font-family="JetBrains Mono, monospace" font-size="12" text-anchor="middle">→ global_port</text>

    <!-- demux fan -->
    <line x1="550" y1="425" x2="690" y2="300" stroke="${COLORS.muted}" stroke-width="1" stroke-dasharray="3,3"/>
    <line x1="550" y1="425" x2="690" y2="390" stroke="${COLORS.muted}" stroke-width="1" stroke-dasharray="3,3"/>
    <line x1="550" y1="425" x2="690" y2="480" stroke="${COLORS.muted}" stroke-width="1" stroke-dasharray="3,3"/>
    <line x1="550" y1="425" x2="690" y2="570" stroke="${COLORS.muted}" stroke-width="1" stroke-dasharray="3,3"/>

    <!-- four outputs -->
    ${[300, 390, 480, 570].map((y, i) => {
      const labels = ['valid_out[0]', 'valid_out[1]', 'valid_out[2]', 'valid_out[3]'];
      return `<circle cx="690" cy="${y}" r="6" fill="${COLORS.panel}" stroke="${COLORS.valid}" stroke-width="2"/>
        ${signalLine(700, y, 1010, COLORS.valid, labels[i], 'end')}`;
    }).join('')}

    <text x="855" y="615" fill="${COLORS.data}" font-family="JetBrains Mono, monospace" font-size="13" text-anchor="middle">data_out [7:0]  (broadcast)</text>
    <line x1="700" y1="600" x2="1010" y2="600" stroke="${COLORS.data}" stroke-width="2" opacity="0.6"/>

    ${condBox(1100, 220, 460, 530, '● ROUTING TABLE', [
      { section: 'PORTS  // INTERNAL ORDER' },
      { html: `<tspan x="1116" fill="${COLORS.text}">N=0  S=1  E=2  W=3  L=4</tspan>`, bigGap: true },
      { section: 'NO-U-TURN MAP // PORT 0 (N)' },
      { html: `<tspan x="1116" fill="${COLORS.muted}">global_port → dest_index</tspan>` },
      { html: `<tspan x="1116" fill="${COLORS.text}">  S(1) → 0    E(2) → 1</tspan>` },
      { html: `<tspan x="1116" fill="${COLORS.text}">  W(3) → 2    L(4) → 3</tspan>`, bigGap: true },
      { section: 'OUTPUT ASSERTION' },
      { html: `<tspan x="1116" fill="${COLORS.valid}">valid_out</tspan><tspan fill="${COLORS.text}">[dest_index] = </tspan><tspan fill="${COLORS.valid}">valid_in</tspan>` },
      { html: `<tspan x="1116" fill="${COLORS.ready}">ready_in</tspan><tspan fill="${COLORS.text}"> = </tspan><tspan fill="${COLORS.ready}">ready_out</tspan><tspan fill="${COLORS.text}">[dest_index]</tspan>` },
    ])}
  </svg>`;
}

// =============================================================================
// 3. merge_4to1
// =============================================================================
function svgMerge() {
  const W = 1600, H = 820;
  return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${W} ${H}">
    ${grid(W, H)}
    <text x="60" y="40" fill="${COLORS.muted}" font-family="JetBrains Mono, monospace" font-size="13" letter-spacing="2">// 4→1 MERGE · MASKED ROUND-ROBIN ARBITER</text>
    <text x="60" y="100" fill="${COLORS.text}" font-family="JetBrains Mono, monospace" font-size="52" font-weight="700">merge_4to1_comb</text>
    <text x="60" y="140" fill="${COLORS.muted}" font-family="JetBrains Mono, monospace" font-size="15">Picks one valid input per cycle. A mask register clears the served port and</text>
    <text x="60" y="162" fill="${COLORS.muted}" font-family="JetBrains Mono, monospace" font-size="15">refills when exhausted, guaranteeing fairness across all NUM_PORTS inputs.</text>

    ${panel(60, 220, 1000, 530, '// DATAPATH')}

    ${[0, 1, 2, 3].map((i) => {
      const y = 290 + i * 90;
      return `${signalLine(100, y, 480, COLORS.valid, `valid_in[${i}]`)}
        ${signalLine(100, y+30, 480, COLORS.data, `data_in[${i}]`)}`;
    }).join('')}

    <!-- arbiter body -->
    <rect x="480" y="280" width="220" height="380" rx="8" fill="${COLORS.panel2}" stroke="${COLORS.faint}" stroke-width="1.5"/>
    <text x="590" y="310" fill="${COLORS.muted}" font-family="JetBrains Mono, monospace" font-size="11" letter-spacing="2" text-anchor="middle">MASK · GRANT · MUX</text>

    <!-- bitmap visualization of mask -->
    <text x="590" y="345" fill="${COLORS.muted}" font-family="JetBrains Mono, monospace" font-size="11" text-anchor="middle">mask = 1010</text>
    ${[0, 1, 2, 3].map((i) => `
      <rect x="${520 + i*35}" y="355" width="26" height="26" rx="3" fill="${i===1||i===3 ? COLORS.muted : COLORS.violet}" opacity="${i===1||i===3 ? 0.3 : 0.9}"/>
      <text x="${533 + i*35}" y="373" fill="${COLORS.text}" font-family="JetBrains Mono, monospace" font-size="12" text-anchor="middle">${i===1||i===3?'0':'1'}</text>`).join('')}

    <text x="590" y="430" fill="${COLORS.muted}" font-family="JetBrains Mono, monospace" font-size="11" text-anchor="middle">grant = 0010</text>
    ${[0, 1, 2, 3].map((i) => `
      <rect x="${520 + i*35}" y="440" width="26" height="26" rx="3" fill="${i===2 ? COLORS.valid : COLORS.muted}" opacity="${i===2?0.95:0.3}"/>
      <text x="${533 + i*35}" y="458" fill="${COLORS.text}" font-family="JetBrains Mono, monospace" font-size="12" text-anchor="middle">${i===2?'1':'0'}</text>`).join('')}

    <text x="590" y="510" fill="${COLORS.muted}" font-family="JetBrains Mono, monospace" font-size="11" text-anchor="middle">selected_port = 2</text>
    <text x="590" y="540" fill="${COLORS.data}" font-family="JetBrains Mono, monospace" font-size="18" font-weight="700" text-anchor="middle">→ data_in[2]</text>

    <!-- outputs -->
    ${signalLine(700, 410, 1010, COLORS.valid, 'valid_out', 'end')}
    ${signalLine(700, 440, 1010, COLORS.data, 'data_out', 'end')}
    ${signalLineRev(700, 470, 1010, COLORS.ready, 'ready_out')}

    <!-- ready_in fan -->
    ${[0, 1, 2, 3].map((i) => {
      const y = 290 + i * 90 + 60;
      return signalLineRev(100, y, 480, COLORS.ready, `ready_in[${i}]`);
    }).join('')}

    ${condBox(1100, 220, 460, 530, '● ARBITRATION LOGIC', [
      { section: 'STEP 1  // REQUESTS' },
      { html: `<tspan x="1116" fill="${COLORS.text}">masked_req = </tspan><tspan fill="${COLORS.valid}">valid_in</tspan><tspan fill="${COLORS.text}"> &amp; </tspan><tspan fill="${COLORS.violet}">mask</tspan>` },
      { html: `<tspan x="1116" fill="${COLORS.text}">unmasked   = </tspan><tspan fill="${COLORS.valid}">valid_in</tspan><tspan fill="${COLORS.text}"> &amp; (~v + 1)</tspan>`, bigGap: true },
      { section: 'STEP 2  // GRANT' },
      { html: `<tspan x="1116" fill="${COLORS.text}">grant = |masked_req</tspan>` },
      { html: `<tspan x="1116" fill="${COLORS.text}">  ? lowest(masked_req)</tspan>` },
      { html: `<tspan x="1116" fill="${COLORS.text}">  : lowest(unmasked)</tspan>`, bigGap: true },
      { section: 'STEP 3  // MASK UPDATE' },
      { html: `<tspan x="1116" fill="${COLORS.text}">on accept &amp; |masked:</tspan>` },
      { html: `<tspan x="1116" fill="${COLORS.text}">  </tspan><tspan fill="${COLORS.violet}">mask</tspan><tspan fill="${COLORS.text}"> &lt;= mask &amp; ~grant</tspan>` },
      { html: `<tspan x="1116" fill="${COLORS.text}">on accept &amp; !|masked:</tspan>` },
      { html: `<tspan x="1116" fill="${COLORS.text}">  </tspan><tspan fill="${COLORS.violet}">mask</tspan><tspan fill="${COLORS.text}"> &lt;= '1 &amp; ~grant</tspan>` },
    ])}
  </svg>`;
}

// =============================================================================
// 4. fifo_sync
// =============================================================================
function svgFifo() {
  const W = 1600, H = 820;
  return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${W} ${H}">
    ${grid(W, H)}
    <text x="60" y="40" fill="${COLORS.muted}" font-family="JetBrains Mono, monospace" font-size="13" letter-spacing="2">// SYNCHRONOUS FIFO · READY-VALID HANDSHAKE</text>
    <text x="60" y="100" fill="${COLORS.text}" font-family="JetBrains Mono, monospace" font-size="52" font-weight="700">fifo_sync</text>
    <text x="60" y="140" fill="${COLORS.muted}" font-family="JetBrains Mono, monospace" font-size="15">Parameter-depth registered buffer. Pin-compatible with valid_ready_slice.</text>
    <text x="60" y="162" fill="${COLORS.muted}" font-family="JetBrains Mono, monospace" font-size="15">ready_out depends only on occupancy — never on ready_in. Extra-MSB trick disambiguates full/empty.</text>

    ${panel(60, 220, 920, 520, '// DATAPATH')}

    ${signalLine(100, 320, 380, COLORS.data, 'data_in [7:0]')}
    ${signalLine(100, 400, 380, COLORS.valid, 'valid_in')}
    ${signalLineRev(100, 540, 380, COLORS.ready, 'ready_out = !full')}

    <!-- memory -->
    <rect x="380" y="300" width="320" height="200" rx="8" fill="${COLORS.panel2}" stroke="${COLORS.faint}" stroke-width="1.5"/>
    <text x="540" y="328" fill="${COLORS.text}" font-family="JetBrains Mono, monospace" font-size="14" font-weight="700" text-anchor="middle">mem [0:DEPTH-1]</text>
    <text x="436" y="362" fill="${COLORS.ready}" font-family="JetBrains Mono, monospace" font-size="11" text-anchor="middle">rd_ptr ↓</text>
    <text x="540" y="362" fill="${COLORS.data}" font-family="JetBrains Mono, monospace" font-size="11" text-anchor="middle">wr_ptr ↓</text>
    ${[0, 1, 2, 3].map((i) => `
      <rect x="${410 + i*65}" y="380" width="50" height="50" rx="4"
            fill="${i<2?COLORS.bg:'transparent'}" stroke="${i<2?COLORS.valid:COLORS.faint}" stroke-width="1.5"/>
      <text x="${435 + i*65}" y="412" fill="${i<2?COLORS.valid:COLORS.muted}" font-family="JetBrains Mono, monospace" font-size="16" font-weight="700" text-anchor="middle">${i<2?'B'+i:'··'}</text>`).join('')}
    <text x="540" y="465" fill="${COLORS.muted}" font-family="JetBrains Mono, monospace" font-size="12" text-anchor="middle">occupancy = 2 / 4</text>

    ${signalLine(700, 320, 980, COLORS.data, 'data_out [7:0]', 'end')}
    ${signalLine(700, 400, 980, COLORS.valid, 'valid_out = !empty', 'end')}
    ${signalLineRev(700, 540, 980, COLORS.ready, 'ready_in')}

    <line x1="510" y1="500" x2="510" y2="560" stroke="${COLORS.violet}" stroke-width="2"/>
    <circle cx="510" cy="565" r="4" fill="${COLORS.violet}"/>
    <text x="510" y="588" fill="${COLORS.violet}" font-family="JetBrains Mono, monospace" font-size="12" text-anchor="middle">clk</text>
    <line x1="575" y1="500" x2="575" y2="560" stroke="${COLORS.pink}" stroke-width="2"/>
    <circle cx="575" cy="565" r="4" fill="${COLORS.pink}"/>
    <text x="575" y="588" fill="${COLORS.pink}" font-family="JetBrains Mono, monospace" font-size="12" text-anchor="middle">rst_n</text>

    ${condBox(1020, 220, 540, 520, '● CONDITIONS', [
      { section: 'OCCUPANCY  // EXTRA-MSB POINTER TRICK' },
      { html: `<tspan x="1036" fill="${COLORS.text}">empty = (wr_ptr == rd_ptr)</tspan>` },
      { html: `<tspan x="1036" fill="${COLORS.text}">full  = (addr_w == addr_r) &amp;&amp;</tspan>` },
      { html: `<tspan x="1036" fill="${COLORS.text}">        (msb_w ≠ msb_r)</tspan>`, bigGap: true },
      { section: 'HANDSHAKE OUTPUTS // COMBINATIONAL' },
      { html: `<tspan x="1036" fill="${COLORS.ready}">ready_out</tspan><tspan fill="${COLORS.text}"> = rst_n &amp;&amp; !full</tspan>` },
      { html: `<tspan x="1036" fill="${COLORS.valid}">valid_out</tspan><tspan fill="${COLORS.text}"> = !empty</tspan>` },
      { html: `<tspan x="1036"> </tspan><tspan fill="${COLORS.data}">data_out</tspan><tspan fill="${COLORS.text}">  = mem[rd_ptr.addr]</tspan>`, bigGap: true },
      { section: 'POINTER ADVANCE // PTR_NEXT' },
      { html: `<tspan x="1036" fill="${COLORS.text}">if addr == DEPTH-1 →</tspan>` },
      { html: `<tspan x="1036" fill="${COLORS.text}">    addr=0, msb=~msb</tspan>` },
      { html: `<tspan x="1036" fill="${COLORS.text}">else addr = addr + 1</tspan>` },
    ])}
  </svg>`;
}

// =============================================================================
// 5. xy_route_logic
// =============================================================================
function svgXY() {
  const W = 1600, H = 820;
  return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${W} ${H}">
    ${grid(W, H)}
    <text x="60" y="40" fill="${COLORS.muted}" font-family="JetBrains Mono, monospace" font-size="13" letter-spacing="2">// 4x4 TORUS · TIE-SPLIT XY ROUTING · DEADLOCK-FREE</text>
    <text x="60" y="100" fill="${COLORS.text}" font-family="JetBrains Mono, monospace" font-size="52" font-weight="700">xy_route_logic</text>
    <text x="60" y="140" fill="${COLORS.muted}" font-family="JetBrains Mono, monospace" font-size="15">Computes the output port from (my_x, my_y, dst_x, dst_y). Forward ring distance</text>
    <text x="60" y="162" fill="${COLORS.muted}" font-family="JetBrains Mono, monospace" font-size="15">fdx = (dst_x − my_x) mod 4. Distance-2 ties split by coordinate — breaks ring cycle.</text>

    ${panel(60, 220, 940, 530, '// DECISION TREE')}

    <!-- decision flow -->
    <rect x="120" y="280" width="160" height="60" rx="6" fill="${COLORS.panel2}" stroke="${COLORS.violet}" stroke-width="1.5"/>
    <text x="200" y="318" fill="${COLORS.text}" font-family="JetBrains Mono, monospace" font-size="14" font-weight="700" text-anchor="middle">fdx ≠ 0 ?</text>

    <line x1="280" y1="310" x2="380" y2="310" stroke="${COLORS.valid}" stroke-width="2"/>
    <text x="320" y="300" fill="${COLORS.valid}" font-family="JetBrains Mono, monospace" font-size="11" text-anchor="middle">yes</text>

    <rect x="380" y="280" width="180" height="60" rx="6" fill="${COLORS.panel2}" stroke="${COLORS.faint}" stroke-width="1.5"/>
    <text x="470" y="318" fill="${COLORS.text}" font-family="JetBrains Mono, monospace" font-size="14" font-weight="700" text-anchor="middle">switch fdx</text>

    <!-- three fdx cases -->
    <line x1="560" y1="310" x2="610" y2="310" stroke="${COLORS.muted}" stroke-width="1"/>
    <line x1="610" y1="265" x2="610" y2="355" stroke="${COLORS.muted}" stroke-width="1"/>
    ${[
      { y: 265, label: '= 1 → PORT_E', color: COLORS.data, sub: '+1 hop (wrap if my_x==3)' },
      { y: 310, label: '= 3 → PORT_W', color: COLORS.data, sub: '−1 hop (wrap if my_x==0)' },
      { y: 355, label: '= 2 → tie', color: COLORS.pink, sub: '(my_x<2) ? E : W   // breaks cycle' },
    ].map((c) => `
      <line x1="610" y1="${c.y}" x2="650" y2="${c.y}" stroke="${COLORS.muted}" stroke-width="1"/>
      <rect x="650" y="${c.y-22}" width="280" height="44" rx="4" fill="${COLORS.panel}" stroke="${c.color}" stroke-width="1.2"/>
      <text x="664" y="${c.y-4}" fill="${c.color}" font-family="JetBrains Mono, monospace" font-size="13" font-weight="700">fdx ${c.label}</text>
      <text x="664" y="${c.y+13}" fill="${COLORS.muted}" font-family="JetBrains Mono, monospace" font-size="10">${c.sub}</text>`).join('')}

    <!-- no path → Y -->
    <line x1="200" y1="340" x2="200" y2="420" stroke="${COLORS.muted}" stroke-width="2"/>
    <polygon points="195,415 200,425 205,415" fill="${COLORS.muted}"/>
    <text x="215" y="385" fill="${COLORS.muted}" font-family="JetBrains Mono, monospace" font-size="11">no → Y dimension</text>

    <rect x="120" y="440" width="160" height="60" rx="6" fill="${COLORS.panel2}" stroke="${COLORS.violet}" stroke-width="1.5"/>
    <text x="200" y="478" fill="${COLORS.text}" font-family="JetBrains Mono, monospace" font-size="14" font-weight="700" text-anchor="middle">fdy ≠ 0 ?</text>

    <line x1="280" y1="470" x2="380" y2="470" stroke="${COLORS.valid}" stroke-width="2"/>
    <rect x="380" y="440" width="180" height="60" rx="6" fill="${COLORS.panel2}" stroke="${COLORS.faint}" stroke-width="1.5"/>
    <text x="470" y="478" fill="${COLORS.text}" font-family="JetBrains Mono, monospace" font-size="14" font-weight="700" text-anchor="middle">switch fdy</text>

    <line x1="560" y1="470" x2="610" y2="470" stroke="${COLORS.muted}" stroke-width="1"/>
    <line x1="610" y1="425" x2="610" y2="515" stroke="${COLORS.muted}" stroke-width="1"/>
    ${[
      { y: 425, label: '= 1 → PORT_N', color: COLORS.data, sub: '+1 hop (wrap if my_y==3)' },
      { y: 470, label: '= 3 → PORT_S', color: COLORS.data, sub: '−1 hop (wrap if my_y==0)' },
      { y: 515, label: '= 2 → tie', color: COLORS.pink, sub: '(my_y<2) ? N : S' },
    ].map((c) => `
      <line x1="610" y1="${c.y}" x2="650" y2="${c.y}" stroke="${COLORS.muted}" stroke-width="1"/>
      <rect x="650" y="${c.y-22}" width="280" height="44" rx="4" fill="${COLORS.panel}" stroke="${c.color}" stroke-width="1.2"/>
      <text x="664" y="${c.y-4}" fill="${c.color}" font-family="JetBrains Mono, monospace" font-size="13" font-weight="700">fdy ${c.label}</text>
      <text x="664" y="${c.y+13}" fill="${COLORS.muted}" font-family="JetBrains Mono, monospace" font-size="10">${c.sub}</text>`).join('')}

    <line x1="200" y1="500" x2="200" y2="600" stroke="${COLORS.muted}" stroke-width="2"/>
    <polygon points="195,595 200,605 205,595" fill="${COLORS.muted}"/>
    <rect x="120" y="610" width="160" height="50" rx="6" fill="${COLORS.panel2}" stroke="${COLORS.cyan}" stroke-width="1.5"/>
    <text x="200" y="643" fill="${COLORS.cyan}" font-family="JetBrains Mono, monospace" font-size="14" font-weight="700" text-anchor="middle">PORT_L</text>
    <text x="295" y="643" fill="${COLORS.muted}" font-family="JetBrains Mono, monospace" font-size="11">eject (arrived at destination)</text>

    ${condBox(1040, 220, 520, 530, '● DEADLOCK PROOF', [
      { section: 'WHY THE TIE-SPLIT IS SAFE' },
      { html: `<tspan x="1056" fill="${COLORS.text}">Without it: distance-2 traffic</tspan>` },
      { html: `<tspan x="1056" fill="${COLORS.text}">always rotates one direction →</tspan>` },
      { html: `<tspan x="1056" fill="${COLORS.text}">full East-ring channel cycle</tspan>` },
      { html: `<tspan x="1056" fill="${COLORS.text}">(c0→c1→c2→c3→c0). Deadlock.</tspan>`, bigGap: true },
      { html: `<tspan x="1056" fill="${COLORS.text}">With it: low half goes East,</tspan>` },
      { html: `<tspan x="1056" fill="${COLORS.text}">high half goes West for the</tspan>` },
      { html: `<tspan x="1056" fill="${COLORS.text}">distance-2 case. Each ring</tspan>` },
      { html: `<tspan x="1056" fill="${COLORS.text}">CDG becomes linear, acyclic.</tspan>`, bigGap: true },
      { section: 'PORT ENCODING' },
      { html: `<tspan x="1056" fill="${COLORS.text}">N=0  S=1  E=2  W=3  L=4</tspan>` },
    ])}
  </svg>`;
}

// =============================================================================
// 6. 4x4 torus grid (3 variants in one SVG, each gets its own page)
// =============================================================================
function svgTorus4x4(variant) {
  // variant: 'plain' | 'fifo' | 'vc'
  const W = 900, H = 900;
  const titles = {
    plain: 'router',
    fifo:  'router_with_fifo',
    vc:    'vc_router',
  };
  const captions = {
    plain: 'depth-1 skid slices',
    fifo:  'input FIFOs · depth=N',
    vc:    'NUM_VC planes · independent',
  };
  const colors = {
    plain: COLORS.cyan,
    fifo:  COLORS.data,
    vc:    COLORS.violet,
  };
  const accent = colors[variant];

  let g = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${W} ${H}">
    ${grid(W, H)}
    <text x="60" y="50" fill="${COLORS.muted}" font-family="JetBrains Mono, monospace" font-size="13" letter-spacing="2">// 4×4 TORUS · 16 ROUTERS · WRAP-AROUND LINKS</text>
    <text x="60" y="100" fill="${COLORS.text}" font-family="JetBrains Mono, monospace" font-size="42" font-weight="700">${titles[variant]}</text>
    <text x="60" y="135" fill="${accent}" font-family="JetBrains Mono, monospace" font-size="16" font-weight="500">${captions[variant]}</text>`;

  const cell = 140;
  const gap  = 30;
  const x0   = 100;
  const y0   = 200;

  // Wrap link curves (drawn first, behind nodes)
  // Horizontal wraps: col 3 to col 0 (rows)
  for (let r = 0; r < 4; r++) {
    const yc = y0 + r*(cell+gap) + cell/2;
    g += `<path d="M ${x0+3*(cell+gap)+cell-10} ${yc} Q ${x0+3*(cell+gap)+cell+50} ${yc-50} ${x0+3*(cell+gap)+cell+60} ${y0-30}
      L ${x0-60} ${y0-30} Q ${x0-50} ${yc-50} ${x0-10} ${yc}"
      stroke="${COLORS.faint}" stroke-width="1.5" fill="none" stroke-dasharray="4,3"/>`;
  }
  // Vertical wraps: row 3 to row 0 (cols)
  for (let c = 0; c < 4; c++) {
    const xc = x0 + c*(cell+gap) + cell/2;
    g += `<path d="M ${xc} ${y0+3*(cell+gap)+cell-10} Q ${xc+40} ${y0+3*(cell+gap)+cell+50} ${W-60} ${y0+3*(cell+gap)+cell+60}
      L ${W-60} ${y0-50} Q ${xc+40} ${y0-50} ${xc} ${y0-10}"
      stroke="${COLORS.faint}" stroke-width="1.5" fill="none" stroke-dasharray="4,3" opacity="0.5"/>`;
  }
  // Regular grid links (between adjacent routers)
  for (let r = 0; r < 4; r++) {
    for (let c = 0; c < 3; c++) {
      const x1 = x0 + c*(cell+gap) + cell;
      const x2 = x0 + (c+1)*(cell+gap);
      const yc = y0 + r*(cell+gap) + cell/2;
      g += `<line x1="${x1}" y1="${yc}" x2="${x2}" y2="${yc}" stroke="${COLORS.muted}" stroke-width="1.5"/>`;
    }
  }
  for (let c = 0; c < 4; c++) {
    for (let r = 0; r < 3; r++) {
      const xc = x0 + c*(cell+gap) + cell/2;
      const y1 = y0 + r*(cell+gap) + cell;
      const y2 = y0 + (r+1)*(cell+gap);
      g += `<line x1="${xc}" y1="${y1}" x2="${xc}" y2="${y2}" stroke="${COLORS.muted}" stroke-width="1.5"/>`;
    }
  }

  // Routers
  for (let r = 0; r < 4; r++) {
    for (let c = 0; c < 4; c++) {
      const x = x0 + c*(cell+gap);
      const y = y0 + r*(cell+gap);
      g += `<rect x="${x}" y="${y}" width="${cell}" height="${cell}" rx="10"
              fill="${COLORS.panel2}" stroke="${accent}" stroke-width="1.5"/>`;

      // Variant-specific inner detail
      if (variant === 'plain') {
        // single slice indicated
        g += `<rect x="${x+30}" y="${y+50}" width="80" height="40" rx="3" fill="${COLORS.bg}" stroke="${accent}" stroke-width="1"/>
              <text x="${x+70}" y="${y+76}" fill="${accent}" font-family="JetBrains Mono, monospace" font-size="10" text-anchor="middle">slice</text>`;
      } else if (variant === 'fifo') {
        // FIFO row of 4 cells
        for (let i = 0; i < 4; i++) {
          g += `<rect x="${x+22+i*22}" y="${y+55}" width="18" height="30" rx="2" fill="${i<2?COLORS.bg:'transparent'}" stroke="${i<2?accent:COLORS.faint}" stroke-width="1"/>`;
        }
        g += `<text x="${x+cell/2}" y="${y+105}" fill="${accent}" font-family="JetBrains Mono, monospace" font-size="9" text-anchor="middle">FIFO</text>`;
      } else if (variant === 'vc') {
        // Two stacked planes
        g += `<rect x="${x+20}" y="${y+40}" width="100" height="22" rx="3" fill="${COLORS.bg}" stroke="${accent}" stroke-width="1"/>
              <text x="${x+cell/2}" y="${y+56}" fill="${accent}" font-family="JetBrains Mono, monospace" font-size="9" text-anchor="middle">VC0 plane</text>
              <rect x="${x+20}" y="${y+72}" width="100" height="22" rx="3" fill="${COLORS.bg}" stroke="${COLORS.pink}" stroke-width="1"/>
              <text x="${x+cell/2}" y="${y+88}" fill="${COLORS.pink}" font-family="JetBrains Mono, monospace" font-size="9" text-anchor="middle">VC1 plane</text>`;
      }

      const id = r*4 + c;
      g += `<text x="${x+cell/2}" y="${y+128}" fill="${COLORS.text}" font-family="JetBrains Mono, monospace" font-size="12" font-weight="700" text-anchor="middle">(${c},${r})  id=${id}</text>`;
    }
  }

  g += `</svg>`;
  return g;
}

// =============================================================================
// 7. Router internals — three variants
// =============================================================================
function svgRouterInternals(variant) {
  // variant: 'plain' | 'fifo' | 'vc'
  const W = 1600, H = 820;
  const titles = {
    plain: 'router · 5-port',
    fifo:  'router_with_fifo · 5-port',
    vc:    'vc_router · 5-port · NUM_VC planes',
  };
  const accent = { plain: COLORS.cyan, fifo: COLORS.data, vc: COLORS.violet }[variant];

  let g = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${W} ${H}">
    ${grid(W, H)}
    <text x="60" y="40" fill="${COLORS.muted}" font-family="JetBrains Mono, monospace" font-size="13" letter-spacing="2">// 5 INPUTS · 5 OUTPUTS · CROSSBAR INSIDE</text>
    <text x="60" y="100" fill="${COLORS.text}" font-family="JetBrains Mono, monospace" font-size="46" font-weight="700">${titles[variant]}</text>`;

  // Vertical lanes: input-buffer | route+split | merge | output-buffer
  const lanes = [
    { x: 200, w: 160, label: variant === 'plain' ? 'slice' : variant === 'fifo' ? 'FIFO' : 'VC FIFOs', col: accent },
    { x: 460, w: 160, label: 'split + xy_route', col: COLORS.violet },
    { x: 720, w: 160, label: variant === 'vc' ? 'plane merges' : 'merges', col: COLORS.valid },
    ...(variant === 'vc' ? [{ x: 980, w: 160, label: 'stage-2 VC arb', col: COLORS.pink }] : []),
    { x: variant === 'vc' ? 1240 : 980, w: 160, label: variant === 'fifo' ? 'output FIFO' : 'output slice', col: COLORS.ready },
  ];

  const portLabels = ['N', 'S', 'E', 'W', 'L'];
  const yTop = 200;
  const yPitch = 90;

  // Draw port labels on the far left and right
  for (let p = 0; p < 5; p++) {
    const y = yTop + p*yPitch + 30;
    g += `<text x="120" y="${y+5}" fill="${COLORS.muted}" font-family="JetBrains Mono, monospace" font-size="14" text-anchor="end">in[${p}] ${portLabels[p]}</text>
          <line x1="130" y1="${y}" x2="${lanes[0].x}" y2="${y}" stroke="${accent}" stroke-width="1.5"/>
          <polygon points="${lanes[0].x-6},${y-4} ${lanes[0].x},${y} ${lanes[0].x-6},${y+4}" fill="${accent}"/>`;

    const lastLane = lanes[lanes.length-1];
    g += `<line x1="${lastLane.x+lastLane.w}" y1="${y}" x2="${W-130}" y2="${y}" stroke="${COLORS.ready}" stroke-width="1.5"/>
          <polygon points="${W-130-6},${y-4} ${W-130},${y} ${W-130-6},${y+4}" fill="${COLORS.ready}"/>
          <text x="${W-120}" y="${y+5}" fill="${COLORS.muted}" font-family="JetBrains Mono, monospace" font-size="14">out[${p}] ${portLabels[p]}</text>`;
  }

  // Lane backgrounds + per-port boxes
  for (const lane of lanes) {
    g += `<rect x="${lane.x}" y="180" width="${lane.w}" height="500" rx="6" fill="${COLORS.panel}" opacity="0.25" stroke="${COLORS.faint}" stroke-width="1"/>
          <text x="${lane.x+lane.w/2}" y="${175}" fill="${lane.col}" font-family="JetBrains Mono, monospace" font-size="11" letter-spacing="1" text-anchor="middle">${lane.label}</text>`;

    if (lane.label === 'plane merges') {
      // 5 merges per plane stacked — show 2 planes
      for (let pl = 0; pl < 2; pl++) {
        const xoff = pl*70;
        for (let p = 0; p < 5; p++) {
          const y = yTop + p*yPitch + 12;
          g += `<rect x="${lane.x + 10 + xoff}" y="${y}" width="60" height="36" rx="3"
                  fill="${COLORS.panel2}" stroke="${pl===0?accent:COLORS.pink}" stroke-width="1"/>`;
        }
      }
      g += `<text x="${lane.x+45}" y="710" fill="${accent}" font-family="JetBrains Mono, monospace" font-size="10" text-anchor="middle">VC0</text>
            <text x="${lane.x+115}" y="710" fill="${COLORS.pink}" font-family="JetBrains Mono, monospace" font-size="10" text-anchor="middle">VC1</text>`;
    } else if (lane.label === 'VC FIFOs') {
      // 2 vc fifos per port
      for (let p = 0; p < 5; p++) {
        const y = yTop + p*yPitch + 10;
        g += `<rect x="${lane.x + 18}" y="${y}" width="60" height="18" rx="3" fill="${COLORS.panel2}" stroke="${accent}" stroke-width="1"/>
              <text x="${lane.x + 48}" y="${y+13}" fill="${accent}" font-family="JetBrains Mono, monospace" font-size="9" text-anchor="middle">VC0</text>
              <rect x="${lane.x + 82}" y="${y}" width="60" height="18" rx="3" fill="${COLORS.panel2}" stroke="${COLORS.pink}" stroke-width="1"/>
              <text x="${lane.x + 112}" y="${y+13}" fill="${COLORS.pink}" font-family="JetBrains Mono, monospace" font-size="9" text-anchor="middle">VC1</text>`;
      }
    } else {
      // generic 5 per-port boxes
      for (let p = 0; p < 5; p++) {
        const y = yTop + p*yPitch + 10;
        let inner = '';
        if (lane.label === 'split + xy_route') {
          inner = `<text x="${lane.x+lane.w/2}" y="${y+22}" fill="${lane.col}" font-family="JetBrains Mono, monospace" font-size="11" text-anchor="middle">split[${p}]</text>`;
        } else if (lane.label === 'merges') {
          inner = `<text x="${lane.x+lane.w/2}" y="${y+22}" fill="${lane.col}" font-family="JetBrains Mono, monospace" font-size="11" text-anchor="middle">merge[${p}]</text>`;
        } else if (lane.label === 'FIFO') {
          inner = `<g>${[0, 1, 2, 3].map((i) => `<rect x="${lane.x+22+i*28}" y="${y+9}" width="22" height="22" rx="2" fill="${COLORS.bg}" stroke="${lane.col}" stroke-width="1"/>`).join('')}</g>`;
        } else if (lane.label === 'output FIFO') {
          inner = `<g>${[0, 1].map((i) => `<rect x="${lane.x+38+i*42}" y="${y+10}" width="36" height="20" rx="2" fill="${COLORS.bg}" stroke="${lane.col}" stroke-width="1"/>`).join('')}</g>`;
        } else if (lane.label === 'output slice' || lane.label === 'slice') {
          inner = `<rect x="${lane.x+40}" y="${y+8}" width="80" height="24" rx="2" fill="${COLORS.bg}" stroke="${lane.col}" stroke-width="1"/>
                   <text x="${lane.x+lane.w/2}" y="${y+25}" fill="${lane.col}" font-family="JetBrains Mono, monospace" font-size="10" text-anchor="middle">depth 1</text>`;
        } else if (lane.label === 'stage-2 VC arb') {
          inner = `<rect x="${lane.x+30}" y="${y+8}" width="100" height="24" rx="2" fill="${COLORS.bg}" stroke="${lane.col}" stroke-width="1"/>
                   <text x="${lane.x+lane.w/2}" y="${y+25}" fill="${lane.col}" font-family="JetBrains Mono, monospace" font-size="10" text-anchor="middle">2→1 RR</text>`;
        } else {
          inner = `<text x="${lane.x+lane.w/2}" y="${y+22}" fill="${lane.col}" font-family="JetBrains Mono, monospace" font-size="10" text-anchor="middle">${lane.label}</text>`;
        }
        g += inner;
      }
    }
  }

  // Caption strip below
  const caption = {
    plain: 'Input slice → split (xy_route) → 4→1 round-robin merge → output slice. One flit per output per cycle.',
    fifo:  'Input FIFO (depth N) absorbs bursts before routing. Output side stays as a depth-1 skid slice.',
    vc:    'NUM_VC parallel "planes" share inputs and outputs. Stage-2 arbiter picks one VC per output per cycle.',
  }[variant];
  g += `<text x="${W/2}" y="${H-50}" fill="${COLORS.muted}" font-family="JetBrains Mono, monospace" font-size="14" text-anchor="middle">${caption}</text>`;

  g += `</svg>`;
  return g;
}

// =============================================================================
// 8. Routing visual: shortest distance with XY (the torus tie-split)
// =============================================================================
function svgRoutingShortest() {
  const W = 1500, H = 800;
  let g = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${W} ${H}">
    ${grid(W, H)}
    <text x="60" y="40" fill="${COLORS.muted}" font-family="JetBrains Mono, monospace" font-size="13" letter-spacing="2">// SHORTEST DISTANCE WITH XY ROUTING · WRAP-AWARE</text>
    <text x="60" y="100" fill="${COLORS.text}" font-family="JetBrains Mono, monospace" font-size="44" font-weight="700">Torus tie-split routing</text>
    <text x="60" y="135" fill="${COLORS.muted}" font-family="JetBrains Mono, monospace" font-size="15">fdx = (dst_x − my_x) mod 4. Pick the closer side. Distance-2 ties split by coord to kill the ring cycle.</text>`;

  const cell = 110, x0 = 80, y0 = 200;

  // grid
  for (let r = 0; r < 4; r++) {
    for (let c = 0; c < 4; c++) {
      const x = x0 + c*cell;
      const y = y0 + r*cell;
      g += `<rect x="${x+8}" y="${y+8}" width="${cell-16}" height="${cell-16}" rx="6" fill="${COLORS.panel2}" stroke="${COLORS.faint}" stroke-width="1"/>
            <text x="${x+cell/2}" y="${y+cell/2+4}" fill="${COLORS.muted}" font-family="JetBrains Mono, monospace" font-size="11" text-anchor="middle">(${c},${r})</text>`;
    }
  }
  // mark src (1,1) and dst (3,3)
  const cx = (c) => x0 + c*cell + cell/2;
  const cy = (r) => y0 + r*cell + cell/2;
  g += `<circle cx="${cx(1)}" cy="${cy(1)}" r="18" fill="${COLORS.valid}" opacity="0.8"/>
        <text x="${cx(1)}" y="${cy(1)+5}" fill="${COLORS.bg}" font-family="JetBrains Mono, monospace" font-size="11" font-weight="700" text-anchor="middle">SRC</text>
        <circle cx="${cx(3)}" cy="${cy(3)}" r="18" fill="${COLORS.data}" opacity="0.9"/>
        <text x="${cx(3)}" y="${cy(3)+5}" fill="${COLORS.bg}" font-family="JetBrains Mono, monospace" font-size="11" font-weight="700" text-anchor="middle">DST</text>`;
  // path arrows
  function arrow(x1, y1, x2, y2, color, label) {
    const dx = x2-x1, dy = y2-y1, L = Math.hypot(dx, dy), ux = dx/L, uy = dy/L;
    const ex = x2 - ux*22, ey = y2 - uy*22;
    return `<line x1="${x1+ux*22}" y1="${y1+uy*22}" x2="${ex}" y2="${ey}" stroke="${color}" stroke-width="3"/>
            <polygon points="${ex},${ey} ${ex-uy*6-ux*10},${ey+ux*6-uy*10} ${ex+uy*6-ux*10},${ey-ux*6-uy*10}" fill="${color}"/>
            ${label ? `<text x="${(x1+ex)/2}" y="${(y1+ey)/2-10}" fill="${color}" font-family="JetBrains Mono, monospace" font-size="11" text-anchor="middle">${label}</text>` : ''}`;
  }
  // (1,1) → (2,1) East, then (2,1) → (3,1) East, then (3,1) → (3,2) N, then (3,2) → (3,3) N
  g += arrow(cx(1), cy(1), cx(2), cy(1), COLORS.cyan, 'E');
  g += arrow(cx(2), cy(1), cx(3), cy(1), COLORS.cyan, 'E');
  g += arrow(cx(3), cy(1), cx(3), cy(2), COLORS.pink, 'N');
  g += arrow(cx(3), cy(2), cx(3), cy(3), COLORS.pink, 'N');

  // legend / hop summary
  g += `${condBox(700, 200, 760, 460, '● HOP TRACE  (1,1) → (3,3)', [
    { html: `<tspan x="716" fill="${COLORS.text}">at (1,1) : fdx=2 tie, my_x&lt;2 → </tspan><tspan fill="${COLORS.cyan}">EAST</tspan>` },
    { html: `<tspan x="716" fill="${COLORS.text}">at (2,1) : fdx=1            → </tspan><tspan fill="${COLORS.cyan}">EAST</tspan>` },
    { html: `<tspan x="716" fill="${COLORS.text}">at (3,1) : fdx=0, fdy=2 tie  </tspan>` },
    { html: `<tspan x="716" fill="${COLORS.text}">           my_y&lt;2 → </tspan><tspan fill="${COLORS.pink}">NORTH</tspan>` },
    { html: `<tspan x="716" fill="${COLORS.text}">at (3,2) : fdy=1            → </tspan><tspan fill="${COLORS.pink}">NORTH</tspan>` },
    { html: `<tspan x="716" fill="${COLORS.text}">at (3,3) : DST              → </tspan><tspan fill="${COLORS.valid}">LOCAL</tspan>`, bigGap: true },
    { section: 'PROPERTIES' },
    { html: `<tspan x="716" fill="${COLORS.text}">4 hops, all minimal</tspan>` },
    { html: `<tspan x="716" fill="${COLORS.text}">Channel-dep graph is acyclic</tspan>` },
    { html: `<tspan x="716" fill="${COLORS.text}">No virtual channels required</tspan>` },
  ])}`;

  // code snippet
  g += `<rect x="60" y="640" width="600" height="140" rx="6" fill="${COLORS.panel}" stroke="${COLORS.faint}" stroke-width="1"/>
        <text x="74" y="660" fill="${COLORS.muted}" font-family="JetBrains Mono, monospace" font-size="10" letter-spacing="1">// xy_route_logic — torus tie-split</text>
        <text x="74" y="685" fill="${COLORS.text}" font-family="JetBrains Mono, monospace" font-size="12">fdx = (dst_x − my_x) &amp; 2'b11;</text>
        <text x="74" y="703" fill="${COLORS.text}" font-family="JetBrains Mono, monospace" font-size="12">if      (fdx == 1) out_port = E;</text>
        <text x="74" y="721" fill="${COLORS.text}" font-family="JetBrains Mono, monospace" font-size="12">else if (fdx == 3) out_port = W;</text>
        <text x="74" y="739" fill="${COLORS.text}" font-family="JetBrains Mono, monospace" font-size="12">else if (fdx == 2) out_port = (my_x &lt; 2) ? E : W;  </text>
        <text x="74" y="757" fill="${COLORS.muted}" font-family="JetBrains Mono, monospace" font-size="11">// Y dimension symmetric, runs after X is resolved</text>`;

  g += `</svg>`;
  return g;
}

// =============================================================================
// 9. Pure XY mesh routing
// =============================================================================
function svgRoutingPureXY() {
  const W = 1500, H = 800;
  let g = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${W} ${H}">
    ${grid(W, H)}
    <text x="60" y="40" fill="${COLORS.muted}" font-family="JetBrains Mono, monospace" font-size="13" letter-spacing="2">// PURE XY ROUTING · MESH STYLE · NO WRAP USED</text>
    <text x="60" y="100" fill="${COLORS.text}" font-family="JetBrains Mono, monospace" font-size="44" font-weight="700">Pure XY routing</text>
    <text x="60" y="135" fill="${COLORS.muted}" font-family="JetBrains Mono, monospace" font-size="15">Compare dst_x with my_x using signed inequality. Goes the "right way around" only — wrap links unused.</text>`;

  const cell = 110, x0 = 80, y0 = 200;
  for (let r = 0; r < 4; r++) {
    for (let c = 0; c < 4; c++) {
      const x = x0 + c*cell;
      const y = y0 + r*cell;
      g += `<rect x="${x+8}" y="${y+8}" width="${cell-16}" height="${cell-16}" rx="6" fill="${COLORS.panel2}" stroke="${COLORS.faint}" stroke-width="1"/>
            <text x="${x+cell/2}" y="${y+cell/2+4}" fill="${COLORS.muted}" font-family="JetBrains Mono, monospace" font-size="11" text-anchor="middle">(${c},${r})</text>`;
    }
  }
  const cx = (c) => x0 + c*cell + cell/2;
  const cy = (r) => y0 + r*cell + cell/2;
  // SRC (3,0), DST (0,3) — pure XY: West three, then South three. No wrap.
  g += `<circle cx="${cx(3)}" cy="${cy(0)}" r="18" fill="${COLORS.valid}" opacity="0.8"/>
        <text x="${cx(3)}" y="${cy(0)+5}" fill="${COLORS.bg}" font-family="JetBrains Mono, monospace" font-size="11" font-weight="700" text-anchor="middle">SRC</text>
        <circle cx="${cx(0)}" cy="${cy(3)}" r="18" fill="${COLORS.data}" opacity="0.9"/>
        <text x="${cx(0)}" y="${cy(3)+5}" fill="${COLORS.bg}" font-family="JetBrains Mono, monospace" font-size="11" font-weight="700" text-anchor="middle">DST</text>`;

  function arr(x1, y1, x2, y2, c) {
    const dx = x2-x1, dy = y2-y1, L = Math.hypot(dx, dy), ux = dx/L, uy = dy/L;
    const ex = x2 - ux*22, ey = y2 - uy*22;
    return `<line x1="${x1+ux*22}" y1="${y1+uy*22}" x2="${ex}" y2="${ey}" stroke="${c}" stroke-width="3"/>
            <polygon points="${ex},${ey} ${ex-uy*6-ux*10},${ey+ux*6-uy*10} ${ex+uy*6-ux*10},${ey-ux*6-uy*10}" fill="${c}"/>`;
  }
  g += arr(cx(3), cy(0), cx(2), cy(0), COLORS.cyan);
  g += arr(cx(2), cy(0), cx(1), cy(0), COLORS.cyan);
  g += arr(cx(1), cy(0), cx(0), cy(0), COLORS.cyan);
  g += arr(cx(0), cy(0), cx(0), cy(1), COLORS.pink);
  g += arr(cx(0), cy(1), cx(0), cy(2), COLORS.pink);
  g += arr(cx(0), cy(2), cx(0), cy(3), COLORS.pink);

  g += condBox(700, 200, 760, 460, '● PROPERTIES', [
    { section: 'ALGORITHM' },
    { html: `<tspan x="716" fill="${COLORS.text}">while dst_x ≠ my_x:</tspan>` },
    { html: `<tspan x="716" fill="${COLORS.text}">  dst_x &gt; my_x → EAST</tspan>` },
    { html: `<tspan x="716" fill="${COLORS.text}">  dst_x &lt; my_x → WEST</tspan>` },
    { html: `<tspan x="716" fill="${COLORS.text}">then Y dimension symmetric</tspan>`, bigGap: true },
    { section: 'WHAT IT WASTES' },
    { html: `<tspan x="716" fill="${COLORS.text}">Hops (3,0)→(0,3) take </tspan><tspan fill="${COLORS.data}">6 hops</tspan>` },
    { html: `<tspan x="716" fill="${COLORS.text}">Wrap-aware would take </tspan><tspan fill="${COLORS.valid}">2 hops</tspan>` },
    { html: `<tspan x="716" fill="${COLORS.text}">(East-wrap once, South-wrap once)</tspan>`, bigGap: true },
    { section: 'GOOD FOR' },
    { html: `<tspan x="716" fill="${COLORS.text}">Mesh topology (no wrap links)</tspan>` },
  ]);

  g += `<rect x="60" y="640" width="600" height="140" rx="6" fill="${COLORS.panel}" stroke="${COLORS.faint}" stroke-width="1"/>
        <text x="74" y="660" fill="${COLORS.muted}" font-family="JetBrains Mono, monospace" font-size="10" letter-spacing="1">// pure XY — mesh style</text>
        <text x="74" y="685" fill="${COLORS.text}" font-family="JetBrains Mono, monospace" font-size="12">if      (dst_x &gt; my_x) out_port = E;</text>
        <text x="74" y="703" fill="${COLORS.text}" font-family="JetBrains Mono, monospace" font-size="12">else if (dst_x &lt; my_x) out_port = W;</text>
        <text x="74" y="721" fill="${COLORS.text}" font-family="JetBrains Mono, monospace" font-size="12">else if (dst_y &gt; my_y) out_port = N;</text>
        <text x="74" y="739" fill="${COLORS.text}" font-family="JetBrains Mono, monospace" font-size="12">else if (dst_y &lt; my_y) out_port = S;</text>
        <text x="74" y="757" fill="${COLORS.text}" font-family="JetBrains Mono, monospace" font-size="12">else                   out_port = L;</text>`;

  g += `</svg>`;
  return g;
}

// =============================================================================
// 10. Odd-Even routing
// =============================================================================
function svgRoutingOddEven() {
  const W = 1500, H = 800;
  let g = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${W} ${H}">
    ${grid(W, H)}
    <text x="60" y="40" fill="${COLORS.muted}" font-family="JetBrains Mono, monospace" font-size="13" letter-spacing="2">// ODD-EVEN ROUTING · TURN-MODEL · DEADLOCK-FREE ON MESH</text>
    <text x="60" y="100" fill="${COLORS.text}" font-family="JetBrains Mono, monospace" font-size="44" font-weight="700">Odd-Even routing</text>
    <text x="60" y="135" fill="${COLORS.muted}" font-family="JetBrains Mono, monospace" font-size="15">Permits adaptive turns but restricts them in odd columns. Breaks turn cycles without VCs.</text>`;

  const cell = 110, x0 = 80, y0 = 200;
  for (let r = 0; r < 4; r++) {
    for (let c = 0; c < 4; c++) {
      const x = x0 + c*cell;
      const y = y0 + r*cell;
      const odd = c % 2 === 1;
      g += `<rect x="${x+8}" y="${y+8}" width="${cell-16}" height="${cell-16}" rx="6" fill="${odd?COLORS.panel:COLORS.panel2}" stroke="${odd?COLORS.pink:COLORS.cyan}" stroke-width="1.2"/>
            <text x="${x+cell/2}" y="${y+cell/2-4}" fill="${COLORS.muted}" font-family="JetBrains Mono, monospace" font-size="10" text-anchor="middle">(${c},${r})</text>
            <text x="${x+cell/2}" y="${y+cell/2+12}" fill="${odd?COLORS.pink:COLORS.cyan}" font-family="JetBrains Mono, monospace" font-size="9" text-anchor="middle">${odd?'odd':'even'}</text>`;
    }
  }

  g += condBox(700, 200, 760, 460, '● TURN RESTRICTIONS', [
    { section: 'EVEN COLUMNS (my_x[0]==0)' },
    { html: `<tspan x="716" fill="${COLORS.cyan}">→ ALL TURNS ALLOWED</tspan>` },
    { html: `<tspan x="716" fill="${COLORS.text}">  N↔E, N↔W, S↔E, S↔W</tspan>`, bigGap: true },
    { section: 'ODD COLUMNS (my_x[0]==1)' },
    { html: `<tspan x="716" fill="${COLORS.pink}">→ E↔N, E↔S turns FORBIDDEN</tspan>` },
    { html: `<tspan x="716" fill="${COLORS.text}">  Must finish vertical motion</tspan>` },
    { html: `<tspan x="716" fill="${COLORS.text}">  before turning horizontally</tspan>`, bigGap: true },
    { section: 'WHY IT WORKS' },
    { html: `<tspan x="716" fill="${COLORS.text}">Forbidden turns kill the cycles</tspan>` },
    { html: `<tspan x="716" fill="${COLORS.text}">in the channel-dependency graph</tspan>` },
    { html: `<tspan x="716" fill="${COLORS.text}">→ deadlock-free without VCs</tspan>` },
  ]);

  // Code snippet
  g += `<rect x="60" y="640" width="600" height="140" rx="6" fill="${COLORS.panel}" stroke="${COLORS.faint}" stroke-width="1"/>
        <text x="74" y="660" fill="${COLORS.muted}" font-family="JetBrains Mono, monospace" font-size="10" letter-spacing="1">// odd-even (mesh; uses ineq compares)</text>
        <text x="74" y="685" fill="${COLORS.text}" font-family="JetBrains Mono, monospace" font-size="12">if (my_x[0] == 0) begin  // even col — turns OK</text>
        <text x="74" y="703" fill="${COLORS.text}" font-family="JetBrains Mono, monospace" font-size="12">  if (dst_x != my_x) horizontal_first;</text>
        <text x="74" y="721" fill="${COLORS.text}" font-family="JetBrains Mono, monospace" font-size="12">  else                vertical;</text>
        <text x="74" y="739" fill="${COLORS.text}" font-family="JetBrains Mono, monospace" font-size="12">end else begin           // odd col — restrict</text>
        <text x="74" y="757" fill="${COLORS.text}" font-family="JetBrains Mono, monospace" font-size="12">  if (dst_x == my_x) vertical; else horizontal;</text>`;

  g += `</svg>`;
  return g;
}

// =============================================================================
// 11. VC planes (revamped from 1780060577463_image.png in our palette)
// =============================================================================
function svgVCPlanes() {
  const W = 1500, H = 820;
  let g = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${W} ${H}">
    ${grid(W, H)}
    <text x="60" y="40" fill="${COLORS.muted}" font-family="JetBrains Mono, monospace" font-size="13" letter-spacing="2">// VIRTUAL CHANNELS · INDEPENDENT PLANES · HoL RELIEF</text>
    <text x="60" y="100" fill="${COLORS.text}" font-family="JetBrains Mono, monospace" font-size="44" font-weight="700">VC planes</text>
    <text x="60" y="135" fill="${COLORS.muted}" font-family="JetBrains Mono, monospace" font-size="15">Each input port owns NUM_VC parallel FIFOs. A flit blocked on one VC never blocks another VC.</text>`;

  const planes = [
    { y: 240, label: 'VIRTUAL CHANNEL 0', col: COLORS.violet },
    { y: 520, label: 'VIRTUAL CHANNEL 1', col: COLORS.pink },
  ];

  for (const p of planes) {
    // parallelogram body
    g += `<polygon points="350,${p.y+30} 1100,${p.y+30} 1180,${p.y+170} 430,${p.y+170}"
                   fill="${COLORS.panel}" stroke="${p.col}" stroke-width="1.5"/>
          <text x="765" y="${p.y+105}" fill="${p.col}" font-family="JetBrains Mono, monospace" font-size="22" font-weight="700" text-anchor="middle">${p.label}</text>`;

    // signal lines into / out of the plane (green = valid, blue = ready, orange = data)
    const lanes = [
      { x1: 100, x2: 350, y: p.y+60, color: COLORS.valid, label: 'valid' },
      { x1: 100, x2: 350, y: p.y+90, color: COLORS.data,  label: 'data' },
      { x1: 1180, x2: 1430, y: p.y+60, color: COLORS.valid, dir: 'out' },
      { x1: 1180, x2: 1430, y: p.y+90, color: COLORS.data,  dir: 'out' },
    ];
    g += `<line x1="100" y1="${p.y+60}" x2="350" y2="${p.y+60}" stroke="${COLORS.valid}" stroke-width="3"/>
          <line x1="100" y1="${p.y+90}" x2="350" y2="${p.y+90}" stroke="${COLORS.data}" stroke-width="3"/>
          <line x1="1180" y1="${p.y+60}" x2="1430" y2="${p.y+60}" stroke="${COLORS.valid}" stroke-width="3"/>
          <line x1="1180" y1="${p.y+90}" x2="1430" y2="${p.y+90}" stroke="${COLORS.data}" stroke-width="3"/>
          <line x1="500" y1="${p.y+220}" x2="700" y2="${p.y+220}" stroke="${COLORS.valid}" stroke-width="3"/>
          <line x1="500" y1="${p.y+250}" x2="700" y2="${p.y+250}" stroke="${COLORS.data}" stroke-width="3"/>
          <line x1="850" y1="${p.y+220}" x2="1050" y2="${p.y+220}" stroke="${COLORS.valid}" stroke-width="3"/>
          <line x1="850" y1="${p.y+250}" x2="1050" y2="${p.y+250}" stroke="${COLORS.data}" stroke-width="3"/>`;
  }

  g += `<text x="${W/2}" y="${H-30}" fill="${COLORS.muted}" font-family="JetBrains Mono, monospace" font-size="13" text-anchor="middle">Same wires, two logical lanes. Stage-2 arbiter picks one VC per output per cycle.</text>`;

  g += `</svg>`;
  return g;
}

// =============================================================================
// 12. VC allocation — 4 cycles of round-robin
// =============================================================================
function svgVCAlloc() {
  const W = 1500, H = 820;
  let g = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${W} ${H}">
    ${grid(W, H)}
    <text x="60" y="40" fill="${COLORS.muted}" font-family="JetBrains Mono, monospace" font-size="13" letter-spacing="2">// VC ALLOCATION · REUSES merge_4to1_comb AT NUM_PORTS=NUM_VC</text>
    <text x="60" y="100" fill="${COLORS.text}" font-family="JetBrains Mono, monospace" font-size="44" font-weight="700">VC allocation — 4 stages</text>
    <text x="60" y="135" fill="${COLORS.muted}" font-family="JetBrains Mono, monospace" font-size="15">Per output port, a small masked round-robin picks one VC's winner each cycle. Mask drains → reloads.</text>`;

  // 4 columns of arbiter state
  const stages = [
    { mask: [1, 1, 1, 1], grant: [1, 0, 0, 0], caption: 'cycle t:  mask = 1111  → grant VC0' },
    { mask: [0, 1, 1, 1], grant: [0, 1, 0, 0], caption: 'cycle t+1: mask = 0111  → grant VC1' },
    { mask: [0, 0, 1, 1], grant: [0, 0, 1, 0], caption: 'cycle t+2: mask = 0011  → grant VC2' },
    { mask: [0, 0, 0, 1], grant: [0, 0, 0, 1], caption: 'cycle t+3: mask = 0001  → grant VC3, reload next' },
  ];

  stages.forEach((s, i) => {
    const x = 70 + i*350;
    g += `<rect x="${x}" y="200" width="320" height="500" rx="8" fill="${COLORS.panel}" stroke="${COLORS.faint}" stroke-width="1"/>
          <text x="${x+160}" y="232" fill="${COLORS.muted}" font-family="JetBrains Mono, monospace" font-size="11" letter-spacing="2" text-anchor="middle">STAGE ${i+1}</text>

          <text x="${x+30}" y="280" fill="${COLORS.muted}" font-family="JetBrains Mono, monospace" font-size="12">mask:</text>`;
    s.mask.forEach((m, j) => {
      g += `<rect x="${x+90+j*48}" y="265" width="40" height="40" rx="4" fill="${m?COLORS.violet:COLORS.muted}" opacity="${m?0.9:0.3}"/>
            <text x="${x+110+j*48}" y="291" fill="${COLORS.text}" font-family="JetBrains Mono, monospace" font-size="14" font-weight="700" text-anchor="middle">${m}</text>`;
    });
    g += `<text x="${x+30}" y="370" fill="${COLORS.muted}" font-family="JetBrains Mono, monospace" font-size="12">valid:</text>`;
    [1, 1, 1, 1].forEach((m, j) => {
      g += `<rect x="${x+90+j*48}" y="355" width="40" height="40" rx="4" fill="${COLORS.valid}" opacity="0.9"/>
            <text x="${x+110+j*48}" y="381" fill="${COLORS.bg}" font-family="JetBrains Mono, monospace" font-size="14" font-weight="700" text-anchor="middle">${m}</text>`;
    });
    g += `<text x="${x+30}" y="460" fill="${COLORS.muted}" font-family="JetBrains Mono, monospace" font-size="12">grant:</text>`;
    s.grant.forEach((m, j) => {
      g += `<rect x="${x+90+j*48}" y="445" width="40" height="40" rx="4" fill="${m?COLORS.data:COLORS.muted}" opacity="${m?0.95:0.25}"/>
            <text x="${x+110+j*48}" y="471" fill="${m?COLORS.bg:COLORS.text}" font-family="JetBrains Mono, monospace" font-size="14" font-weight="700" text-anchor="middle">${m}</text>`;
    });

    g += `<text x="${x+30}" y="555" fill="${COLORS.muted}" font-family="JetBrains Mono, monospace" font-size="10" letter-spacing="1">// VC LABELS</text>
          <text x="${x+30}" y="575" fill="${COLORS.muted}" font-family="JetBrains Mono, monospace" font-size="11">VC0  VC1  VC2  VC3</text>

          <rect x="${x+20}" y="600" width="280" height="76" rx="4" fill="${COLORS.bg}" stroke="${COLORS.faint}" stroke-width="1"/>
          <text x="${x+30}" y="623" fill="${COLORS.muted}" font-family="JetBrains Mono, monospace" font-size="10" letter-spacing="1">// EFFECT</text>
          <text x="${x+30}" y="645" fill="${COLORS.text}" font-family="JetBrains Mono, monospace" font-size="11">${s.caption.split(':')[0]}:</text>
          <text x="${x+30}" y="663" fill="${COLORS.text}" font-family="JetBrains Mono, monospace" font-size="11">${s.caption.split(':').slice(1).join(':').trim()}</text>`;
  });

  g += `</svg>`;
  return g;
}

// =============================================================================
// Write everything to disk
// =============================================================================
const outDir = path.join(__dirname, 'svg');
fs.mkdirSync(outDir, { recursive: true });

const targets = {
  'valid_ready_slice.svg': svgValidReadySlice(),
  'split.svg':             svgSplit(),
  'merge.svg':             svgMerge(),
  'fifo.svg':              svgFifo(),
  'xy_route_logic.svg':    svgXY(),
  'torus_plain.svg':       svgTorus4x4('plain'),
  'torus_fifo.svg':        svgTorus4x4('fifo'),
  'torus_vc.svg':          svgTorus4x4('vc'),
  'router_plain.svg':      svgRouterInternals('plain'),
  'router_fifo.svg':       svgRouterInternals('fifo'),
  'router_vc.svg':         svgRouterInternals('vc'),
  'routing_shortest.svg':  svgRoutingShortest(),
  'routing_purexy.svg':    svgRoutingPureXY(),
  'routing_oddeven.svg':   svgRoutingOddEven(),
  'vc_planes.svg':         svgVCPlanes(),
  'vc_alloc.svg':          svgVCAlloc(),
};

for (const [name, content] of Object.entries(targets)) {
  fs.writeFileSync(path.join(outDir, name), content);
}
console.log('wrote', Object.keys(targets).length, 'svgs');