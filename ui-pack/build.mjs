// Sushi Incremental UI pack builder (not synced by Rojo).
//   node ui-pack/build.mjs
// Writes ui-pack/png/**.png (icons 512x512, 9-slice frames) by rendering SVG with headless
// Chrome, and ui-pack/UI-Pack.html (page.html with the icon sprite and slice table filled in).
import { writeFileSync, readFileSync, mkdirSync, rmSync } from "node:fs";
import { execFile } from "node:child_process";
import { promisify } from "node:util";
import { dirname, join } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

const DIR = dirname(fileURLToPath(import.meta.url));
const CHROME = process.env.CHROME || "C:/Program Files/Google/Chrome/Application/chrome.exe";

const INK = "#2B2233", RICE = "#FFF7EA";
const P = {
	maguro: "#FF4D5E", tamago: "#FFC93C", wasabi: "#7BD93F",
	cash: "#2FC27A", kg: "#FF8A3D", prestige: "#FFC233", rebirth: "#A066FF", neko: "#FF6FAE", fish: "#3BB2FF",
	common: "#B8C0CC", uncommon: "#5DD55A", rare: "#3D9BFF", epic: "#A955FF", legendary: "#FFB020", mythic: "#FF3D6E",
	locked: "#6B6478", disabled: "#C9C3D1",
};

// ---------- icons (512 viewBox, chunky ink outline + hard drop shadow) ----------
const hi = (d) => `<path d="${d}" fill="#fff" opacity=".5" stroke="none"/>`;
const star = (cx, cy, R, r, n = 5) => Array.from({ length: n * 2 }, (_, i) => {
	const a = -Math.PI / 2 + (i * Math.PI) / n, rad = i % 2 ? r : R;
	return `${(cx + rad * Math.cos(a)).toFixed(1)},${(cy + rad * Math.sin(a)).toFixed(1)}`;
}).join(" ");
const gear = (n, R, r) => Array.from({ length: n * 4 }, (_, i) => {
	const a = (i * Math.PI * 2) / (n * 4) + 0.2, rad = i % 4 < 2 ? R : r;
	return `${(256 + rad * Math.cos(a)).toFixed(1)},${(256 + rad * Math.sin(a)).toFixed(1)}`;
}).join(" ");
const pt = (a, rad = 150) => [256 + rad * Math.cos((a * Math.PI) / 180), 256 + rad * Math.sin((a * Math.PI) / 180)];
function arrowArc(a0, a1, color) { // clockwise arc with an arrowhead at a1
	const [x0, y0] = pt(a0), [x1, y1] = pt(a1), r = (a1 * Math.PI) / 180;
	const t = [-Math.sin(r), Math.cos(r)], n = [Math.cos(r), Math.sin(r)];
	const head = [[x1 + t[0] * 70, y1 + t[1] * 70], [x1 + n[0] * 62, y1 + n[1] * 62], [x1 - n[0] * 62, y1 - n[1] * 62]]
		.map((p) => p.map((v) => v.toFixed(1)).join(",")).join(" ");
	const d = `M${x0.toFixed(1)} ${y0.toFixed(1)} A150 150 0 0 1 ${x1.toFixed(1)} ${y1.toFixed(1)}`;
	return { under: `<path d="${d}" fill="none" stroke-width="96"/><polygon points="${head}" fill="${color}"/>`, over: `<path d="${d}" fill="none" stroke="${color}" stroke-width="52"/>` };
}
const gem = (id, c, light) => `<polygon points="256,62 414,156 414,356 256,450 98,356 98,156" fill="${c}"/>
<polygon points="256,140 344,192 344,320 256,372 168,320 168,192" fill="${light}" stroke-width="12"/>
${hi("M140 180 L250 116 L262 140 L160 200 Z")}`;
const rarityLight = { common: "#E4E8EE", uncommon: "#B4F2B0", rare: "#A9D3FF", epic: "#DDB8FF", legendary: "#FFE08A", mythic: "#FFA3BC" };

const ICONS = {
	cash: `<rect x="66" y="140" width="360" height="210" rx="34" fill="#1E9E5E" transform="rotate(-10 256 256)"/>
<rect x="80" y="176" width="360" height="210" rx="34" fill="${P.cash}"/>
<circle cx="260" cy="281" r="62" fill="#A6F2C8" stroke-width="16"/>
<path d="M276 248 Q240 238 238 262 Q238 280 262 282 Q286 284 284 302 Q280 324 242 312 M260 236 V326" fill="none" stroke-width="16"/>
<circle cx="140" cy="226" r="14" fill="#A6F2C8" stroke="none"/><circle cx="380" cy="336" r="14" fill="#A6F2C8" stroke="none"/>
${hi("M110 196 H300 Q312 196 312 206 Q312 214 300 214 H110 Q100 214 100 206 Q100 196 110 196Z")}`,
	kg: `<path d="M196 214 C190 100 322 100 316 214" fill="none" stroke-width="64"/>
<path d="M196 214 C190 100 322 100 316 214" fill="none" stroke="${P.kg}" stroke-width="22"/>
<path d="M150 196 H362 Q382 196 388 216 L432 412 Q436 440 408 440 H104 Q76 440 80 412 L124 216 Q130 196 150 196Z" fill="${P.kg}"/>
<rect x="196" y="290" width="120" height="70" rx="20" fill="#FFD2B0" stroke-width="14"/>
${hi("M150 222 H250 L244 246 H140 Z")}`,
	prestige: `<polygon points="${star(256, 266, 210, 96)}" fill="${P.prestige}"/>
<polygon points="${star(236, 236, 70, 32)}" fill="#FFF0B0" stroke="none"/>`,
	rebirth: (() => { const a = arrowArc(200, 330, P.rebirth), b = arrowArc(20, 150, P.rebirth); return a.under + b.under + a.over + b.over + `<circle cx="256" cy="256" r="40" fill="#E2CCFF" stroke-width="16"/>`; })(),
	neko: `<ellipse cx="256" cy="330" rx="128" ry="104" fill="${P.neko}"/>
<ellipse cx="128" cy="206" rx="46" ry="56" fill="${P.neko}" transform="rotate(-20 128 206)"/>
<ellipse cx="208" cy="134" rx="46" ry="58" fill="${P.neko}" transform="rotate(-6 208 134)"/>
<ellipse cx="304" cy="134" rx="46" ry="58" fill="${P.neko}" transform="rotate(6 304 134)"/>
<ellipse cx="384" cy="206" rx="46" ry="56" fill="${P.neko}" transform="rotate(20 384 206)"/>
<ellipse cx="256" cy="338" rx="76" ry="58" fill="#FFC6DE" stroke="none"/>
${hi("M180 290 Q200 262 236 258 Q232 274 196 300 Z")}`,
	fish: `<polygon points="350,256 452,166 440,256 452,346" fill="#1E8FE0"/>
<path d="M252 150 L300 104 L320 170 Z" fill="#1E8FE0"/>
<ellipse cx="226" cy="262" rx="160" ry="104" fill="${P.fish}"/>
<path d="M290 200 Q320 262 290 324" fill="none" stroke-width="14"/>
<circle cx="140" cy="240" r="26" fill="#fff" stroke-width="12"/><circle cx="146" cy="240" r="11" fill="${INK}" stroke="none"/>
${hi("M140 300 Q220 346 320 310 Q300 330 230 336 Q170 334 140 300Z")}`,
	shop: `<rect x="104" y="228" width="304" height="210" rx="18" fill="${RICE}"/>
<rect x="210" y="314" width="92" height="124" rx="12" fill="#8C5A3F"/>
<rect x="126" y="290" width="62" height="56" rx="10" fill="#9FE3FF" stroke-width="12"/><rect x="324" y="290" width="62" height="56" rx="10" fill="#9FE3FF" stroke-width="12"/>
${[0, 1, 2, 3, 4, 5].map((i) => `<circle cx="${101 + i * 62}" cy="236" r="31" fill="${i % 2 ? RICE : P.maguro}"/>`).join("")}
<path d="M56 236 L124 110 H388 L456 236 Z" fill="${P.maguro}"/>
<circle cx="256" cy="172" r="30" fill="${RICE}" stroke-width="14"/>
${hi("M140 128 H372 L380 144 H130 Z")}`,
	index: `<path d="M64 140 V412 Q170 392 256 432 Q342 392 448 412 V140" fill="#2BC4B6"/>
<path d="M256 152 Q176 110 92 128 V386 Q176 370 256 408 Z" fill="${RICE}"/>
<path d="M256 152 Q336 110 420 128 V386 Q336 370 256 408 Z" fill="${RICE}"/>
<path d="M136 196 Q180 188 220 206 M136 252 Q180 244 220 262 M292 206 Q332 188 376 196 M292 262 Q332 244 376 252" fill="none" stroke-width="12" opacity=".55"/>
<polygon points="${star(334, 326, 34, 16)}" fill="${P.tamago}" stroke-width="10"/>`,
	skills: `<path d="M256 396 V250 L140 140 M256 250 L372 140" fill="none" stroke-width="58"/>
<path d="M256 396 V250 L140 140 M256 250 L372 140" fill="none" stroke="${P.tamago}" stroke-width="24"/>
<circle cx="256" cy="396" r="54" fill="${P.wasabi}"/><circle cx="256" cy="250" r="54" fill="${P.wasabi}"/>
<circle cx="140" cy="140" r="54" fill="${P.wasabi}"/><circle cx="372" cy="140" r="54" fill="${P.locked}"/>
${hi("M226 222 Q246 206 270 210 Q252 222 236 236Z")}${hi("M110 112 Q130 96 154 100 Q136 112 120 126Z")}${hi("M226 368 Q246 352 270 356 Q252 368 236 382Z")}`,
	runes: `<polygon points="256,60 410,176 368,440 144,440 102,176" fill="${P.rebirth}"/>
<polygon points="256,60 410,176 256,222 102,176" fill="#C49BFF" stroke-width="14"/>
<path d="M256 252 V396 M206 290 L256 334 L306 290" fill="none" stroke="#F1E6FF" stroke-width="22"/>
${hi("M150 172 L250 96 L254 120 L170 182Z")}`,
	titles: `<polygon points="30,226 120,226 120,356 30,356 70,291" fill="#E5A21F"/>
<polygon points="482,226 392,226 392,356 482,356 442,291" fill="#E5A21F"/>
<rect x="86" y="186" width="340" height="140" rx="20" fill="${P.tamago}"/>
<polygon points="${star(256, 258, 46, 20)}" fill="${RICE}" stroke-width="12"/>
${hi("M110 204 H400 Q410 204 410 214 Q410 222 400 222 H110 Q100 222 100 214 Q100 204 110 204Z")}`,
	profile: `<polygon points="120,96 108,236 222,172" fill="${RICE}"/><polygon points="392,96 404,236 290,172" fill="${RICE}"/>
<polygon points="134,140 132,210 190,176" fill="${P.neko}" stroke="none"/><polygon points="378,140 380,210 322,176" fill="${P.neko}" stroke="none"/>
<ellipse cx="256" cy="290" rx="172" ry="146" fill="${RICE}"/>
<path d="M162 286 Q192 252 222 286 M290 286 Q320 252 350 286" fill="none" stroke-width="18"/>
<path d="M232 322 Q244 346 256 330 Q268 346 280 322" fill="none" stroke-width="12"/>
<polygon points="244,306 268,306 256,318" fill="${P.neko}" stroke-width="8"/>
<ellipse cx="160" cy="336" rx="30" ry="18" fill="${P.neko}" opacity=".55" stroke="none"/><ellipse cx="352" cy="336" rx="30" ry="18" fill="${P.neko}" opacity=".55" stroke="none"/>
<path d="M120 412 Q256 470 392 412" fill="none" stroke="${P.maguro}" stroke-width="30"/><circle cx="256" cy="440" r="24" fill="${P.tamago}" stroke-width="12"/>`,
	areas: `<rect x="138" y="170" width="52" height="270" fill="${P.maguro}"/><rect x="322" y="170" width="52" height="270" fill="${P.maguro}"/>
<rect x="126" y="404" width="76" height="40" rx="8" fill="${INK}"/><rect x="310" y="404" width="76" height="40" rx="8" fill="${INK}"/>
<rect x="96" y="216" width="320" height="42" rx="8" fill="${P.maguro}"/>
<path d="M44 118 Q256 158 468 118 L450 182 Q256 204 62 182 Z" fill="${P.maguro}"/>
<rect x="232" y="176" width="48" height="44" fill="${INK}"/>
${hi("M80 132 Q256 166 430 132 L428 146 Q256 178 82 148Z")}`,
	settings: `<polygon points="${gear(8, 200, 156)}" fill="#7E8FB8"/>
<circle cx="256" cy="256" r="70" fill="${RICE}"/>
${hi("M150 180 Q190 130 250 120 L246 146 Q196 156 172 192Z")}`,
	lock: `<path d="M168 236 V176 A88 88 0 0 1 344 176 V236" fill="none" stroke-width="80"/>
<path d="M168 236 V176 A88 88 0 0 1 344 176 V236" fill="none" stroke="#C9C3D1" stroke-width="38"/>
<rect x="104" y="222" width="304" height="226" rx="44" fill="${P.tamago}"/>
<circle cx="256" cy="316" r="30" fill="${INK}" stroke="none"/><rect x="242" y="320" width="28" height="70" rx="12" fill="${INK}" stroke="none"/>
${hi("M140 246 H360 Q372 246 372 258 Q372 268 360 268 H140 Q128 268 128 258 Q128 246 140 246Z")}`,
	close: `<path d="M140 140 L372 372 M372 140 L140 372" fill="none" stroke-width="118"/>
<path d="M140 140 L372 372 M372 140 L140 372" fill="none" stroke="#fff" stroke-width="66"/>`,
	check: `<path d="M110 270 L214 372 L404 150" fill="none" stroke-width="118"/>
<path d="M110 270 L214 372 L404 150" fill="none" stroke="${P.wasabi}" stroke-width="66"/>`,
	gift: `<ellipse cx="196" cy="138" rx="62" ry="40" fill="${P.tamago}" transform="rotate(20 196 138)"/>
<ellipse cx="316" cy="138" rx="62" ry="40" fill="${P.tamago}" transform="rotate(-20 316 138)"/>
<rect x="104" y="236" width="304" height="212" rx="20" fill="${P.maguro}"/>
<rect x="80" y="172" width="352" height="86" rx="20" fill="#FF7482"/>
<rect x="224" y="172" width="64" height="276" fill="${P.tamago}"/>
${hi("M104 188 H220 V206 H104 Q96 206 96 198 Q96 188 104 188Z")}`,
	potion: `<rect x="194" y="56" width="124" height="56" rx="16" fill="#8C5A3F"/>
<rect x="210" y="100" width="92" height="96" fill="#E9F6FF"/>
<circle cx="256" cy="318" r="146" fill="#E9F6FF"/>
<path d="M118 330 Q256 280 394 330 Q384 444 256 450 Q128 444 118 330Z" fill="${P.neko}" stroke="none"/>
<circle cx="256" cy="318" r="146" fill="none"/>
<circle cx="300" cy="370" r="16" fill="#fff" opacity=".7" stroke="none"/><circle cx="226" cy="400" r="10" fill="#fff" opacity=".7" stroke="none"/>
${hi("M150 270 Q170 214 220 196 Q214 222 172 286Z")}`,
	sushi: `<rect x="96" y="246" width="320" height="168" rx="76" fill="${RICE}"/>
<path d="M70 262 Q84 162 256 168 Q426 162 444 254 Q452 304 380 298 Q256 306 124 302 Q66 300 70 262Z" fill="#FF8A5C"/>
<path d="M150 200 Q170 250 160 290 M240 186 Q262 240 252 296 M330 192 Q352 244 344 294" fill="none" stroke="#FFD6BE" stroke-width="16"/>
<rect x="222" y="150" width="68" height="272" rx="10" fill="#2E4A3A"/>
<ellipse cx="150" cy="370" rx="12" ry="8" fill="#EFE2C8" stroke="none"/><ellipse cx="360" cy="376" rx="12" ry="8" fill="#EFE2C8" stroke="none"/>`,
	lantern: `<rect x="216" y="44" width="80" height="44" rx="10" fill="${INK}"/>
<ellipse cx="256" cy="250" rx="160" ry="176" fill="${P.maguro}"/>
<path d="M120 190 H392 M104 250 H408 M120 310 H392" fill="none" stroke="#C92F3F" stroke-width="12"/>
<rect x="216" y="414" width="80" height="44" rx="10" fill="${INK}"/>
<path d="M240 458 V492 M256 458 V500 M272 458 V492" fill="none" stroke="${P.tamago}" stroke-width="14"/>
${hi("M150 160 Q190 100 250 92 L246 120 Q196 128 170 172Z")}`,
	robux: `<polygon points="256,60 426,158 426,354 256,452 86,354 86,158" fill="${P.wasabi}"/>
<polygon points="256,160 342,210 342,302 256,352 170,302 170,210" fill="#2E7D12" stroke-width="14"/>
<rect x="222" y="222" width="68" height="68" rx="8" fill="${P.wasabi}" stroke-width="12"/>`,
};
for (const r of ["common", "uncommon", "rare", "epic", "legendary", "mythic"]) ICONS[`rarity_${r}`] = gem(r, P[r], rarityLight[r]);

const SHADOW = `<filter id="sh" x="-20%" y="-20%" width="140%" height="150%"><feDropShadow dx="0" dy="14" stdDeviation="0" flood-color="${INK}" flood-opacity=".3"/></filter>`;
const iconBody = (body) => `<g filter="url(#sh)" stroke="${INK}" stroke-width="22" stroke-linejoin="round" stroke-linecap="round">${body}</g>`;
const iconSvg = (body) => `<svg xmlns="http://www.w3.org/2000/svg" width="512" height="512" viewBox="0 0 512 512"><defs>${SHADOW}</defs>${iconBody(body)}</svg>`;

// ---------- 9-slice frames: rounded body, ink outline, top gloss, hard shadow ----------
// Gloss stays inside the top slice so stretching never distorts it.
function frame(w, h, { r, fill, fill2, stroke = 6, shadow = 8, gloss = true, round = false }) {
	const s = stroke / 2, bw = w - stroke, bh = h - stroke - shadow, rad = round ? bh / 2 : r;
	// pills/circles: keep a 2px centre so the Rect stays valid; stretch those horizontally only
	const m = Math.min(Math.ceil(rad + stroke), Math.floor(w / 2) - 1, Math.floor((h - shadow) / 2) - 1);
	const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="${w}" height="${h}" viewBox="0 0 ${w} ${h}">
<defs><linearGradient id="g" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="${fill}"/><stop offset="1" stop-color="${fill2 || fill}"/></linearGradient></defs>
<rect x="${s}" y="${s + shadow}" width="${bw}" height="${bh}" rx="${rad}" fill="${INK}" opacity=".35"/>
<rect x="${s}" y="${s}" width="${bw}" height="${bh}" rx="${rad}" fill="url(#g)" stroke="${INK}" stroke-width="${stroke}"/>
${gloss ? `<rect x="${stroke + 6}" y="${stroke + 4}" width="${w - 2 * stroke - 12}" height="${Math.min(14, m - stroke - 6)}" rx="${Math.min(7, (m - stroke - 6) / 2)}" fill="#fff" opacity=".4"/>` : ""}
</svg>`;
	return { svg, w, h, slice: [m, m, w - m, h - m - shadow] };
}
const shade = (hex, k) => "#" + hex.slice(1).match(/../g).map((c) => Math.round(parseInt(c, 16) * k).toString(16).padStart(2, "0")).join("");
const btn = (c) => frame(192, 96, { r: 26, fill: c, fill2: shade(c, 0.82) });
const FRAMES = {
	button_primary: btn(P.maguro), button_secondary: btn(P.tamago), button_buy: btn(P.wasabi),
	button_disabled: btn(P.disabled), button_locked: btn(P.locked),
	button_icon: frame(128, 128, { r: 28, fill: RICE, fill2: "#F1E1C6" }),
	button_close: frame(128, 128, { r: 28, fill: P.maguro, fill2: shade(P.maguro, 0.82) }),
	panel: frame(256, 256, { r: 40, fill: RICE, fill2: "#F6E8D2", stroke: 8, shadow: 12 }),
	panel_inner: frame(128, 128, { r: 22, fill: "#F3E3C8", stroke: 4, shadow: 0, gloss: false }),
	title_tab: frame(256, 128, { r: 30, fill: P.maguro, fill2: shade(P.maguro, 0.85), stroke: 8, shadow: 8 }),
	popup: frame(256, 256, { r: 36, fill: "#FFFFFF", fill2: RICE, stroke: 8, shadow: 12 }),
	tooltip: frame(128, 96, { r: 20, fill: INK, stroke: 4, shadow: 6, gloss: false }),
	tab_active: frame(192, 96, { r: 26, fill: RICE, fill2: "#F6E8D2" }),
	tab_idle: frame(192, 96, { r: 26, fill: "#E2CFAF", fill2: "#D2BC98" }),
	card: frame(256, 256, { r: 32, fill: "#FFFFFF", fill2: RICE }),
	card_locked: frame(256, 256, { r: 32, fill: "#8D869A", fill2: P.locked }),
	bar_track: frame(256, 64, { r: 0, round: true, fill: "#3A3145", stroke: 6, shadow: 4, gloss: false }),
	bar_fill_white: frame(256, 64, { r: 0, round: true, fill: "#FFFFFF", fill2: "#D9D9D9", stroke: 0, shadow: 0 }),
	toggle_on: frame(192, 96, { r: 0, round: true, fill: P.wasabi, fill2: shade(P.wasabi, 0.82) }),
	toggle_off: frame(192, 96, { r: 0, round: true, fill: "#B9B2C4", fill2: "#9E96AB" }),
	knob: frame(96, 96, { r: 0, round: true, fill: "#FFFFFF", fill2: RICE }),
	badge: frame(96, 96, { r: 0, round: true, fill: "#FF3B4E", fill2: "#D91F33", stroke: 6, shadow: 4 }),
	currency_pill: frame(256, 96, { r: 0, round: true, fill: "#FFFFFF", fill2: RICE }),
};
for (const r of ["common", "uncommon", "rare", "epic", "legendary", "mythic"]) FRAMES[`card_${r}`] = frame(256, 256, { r: 32, fill: P[r], fill2: shade(P[r], 0.78) });

// ---------- render ----------
const run = promisify(execFile);
async function render(svg, w, h, out) {
	const tmp = out.replace(/\.png$/, ".svg");
	writeFileSync(tmp, svg);
	await run(CHROME, ["--headless=new", "--disable-gpu", "--hide-scrollbars", "--default-background-color=00000000",
		`--window-size=${w},${h}`, `--screenshot=${out}`, pathToFileURL(tmp).href]);
	rmSync(tmp);
}
const jobs = [];
for (const [name, body] of Object.entries(ICONS)) jobs.push(["icons", name, iconSvg(body), 512, 512]);
for (const [name, f] of Object.entries(FRAMES)) jobs.push(["9slice", name, f.svg, f.w, f.h]);

const only = process.argv[2]; // `node build.mjs page` skips the PNGs
if (only !== "page") {
	for (const d of ["icons", "9slice"]) { rmSync(join(DIR, "png", d), { recursive: true, force: true }); mkdirSync(join(DIR, "png", d), { recursive: true }); }
	for (let i = 0; i < jobs.length; i += 8)
		await Promise.all(jobs.slice(i, i + 8).map(([d, n, svg, w, h]) => render(svg, w, h, join(DIR, "png", d, `${n}.png`))));
	console.log(`rendered ${jobs.length} PNGs`);
}

// ---------- page ----------
const sprite = `<svg class="sprite" aria-hidden="true"><defs>${SHADOW}${Object.entries(ICONS).map(([n, b]) => `<symbol id="i-${n}" viewBox="0 0 512 512">${iconBody(b)}</symbol>`).join("")}</defs></svg>`;
const sliceRows = Object.entries(FRAMES).map(([n, f]) =>
	`<tr><td><code>9slice/${n}.png</code></td><td>${f.w}×${f.h}</td><td><code>Rect.new(${f.slice.join(", ")})</code></td></tr>`).join("");
const iconRows = Object.keys(ICONS).map((n) => `<figure><span class="ic" data-i="${n}"></span><figcaption>${n}.png</figcaption></figure>`).join("");
const page = readFileSync(join(DIR, "page.html"), "utf8")
	.replace("<!--SPRITE-->", sprite).replace("<!--SLICE_ROWS-->", sliceRows).replace("<!--ICON_GRID-->", iconRows);
writeFileSync(join(DIR, "UI-Pack.html"), page);
console.log("wrote UI-Pack.html");
