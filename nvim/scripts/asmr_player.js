// Long-running macOS sound player for :ASMR (run with: osascript -l JavaScript asmr_player.js).
// Spawning afplay per key costs ~1 s of process lifetime each, so fast typing piles them up.
// This keeps every clip loaded and plays one per line read from stdin: "<path>\n"
// ("load <dir>\n" preloads a profile).
//
// Why it's built this way (the "goes silent after a while / after holding a key" bug):
//  - Inside osascript, NSSound never notices a clip has finished: isPlaying stays true
//    forever and its audio resources are never released. Hundreds of those piled up and
//    macOS eventually stopped producing sound. So we track each clip's end time ourselves
//    and explicitly stop() it once it's done, which frees it.
//  - A fresh NSSound copy per key is never freed by the JS bridge (memory grew ~60 MB a
//    minute while holding a key). Instead each clip gets a fixed pool of players reused
//    round-robin, so the number of sound objects and memory stay flat forever.
ObjC.import('AppKit');
const stdin = $.NSFileHandle.fileHandleWithStandardInput;
const DEBUG = !$.NSProcessInfo.processInfo.environment.objectForKey('ASMR_DEBUG').isNil();
const POOL = 4; // overlapping plays per clip; 5 random key clips => up to 20 overlapping keystrokes
const pools = {}; // path -> { sounds, ends, next, ms }
let buffer = '';
let plays = 0;
let failed = 0;
let dropped = 0;
let nextLog = 250;

function pool(path) {
  let p = pools[path];
  if (!p) {
    const base = $.NSSound.alloc.initWithContentsOfFileByReference(path, true);
    if (base.isNil()) return null;
    p = pools[path] = { sounds: [base], ends: [0], next: 0, ms: Number(base.duration) * 1000 + 30 };
    for (let i = 1; i < POOL; i++) { p.sounds.push(base.copy); p.ends.push(0); }
    for (const s of p.sounds) s.volume = 0.7;
  }
  return p;
}

// Stop every clip whose time is up, so finished sounds don't hold on to audio resources.
function reap(now) {
  let live = 0;
  for (const k in pools) {
    const p = pools[k];
    for (let i = 0; i < POOL; i++) {
      if (!p.ends[i]) continue;
      if (now >= p.ends[i]) { p.sounds[i].stop; p.ends[i] = 0; } else live++;
    }
  }
  return live;
}

// "load <dir>": load a profile's clips up front so the first keystrokes aren't delayed.
function preload(dir) {
  for (const name of ['key1', 'key2', 'key3', 'key4', 'key5', 'space', 'enter', 'backspace']) pool(`${dir}/${name}.wav`);
}

function play(path, now) {
  const p = pool(path);
  if (!p) return;
  const i = p.next;
  p.next = (i + 1) % POOL;
  const s = p.sounds[i];
  if (p.ends[i]) s.stop; // this slot is still sounding: cut it off and restart
  if (!s.play) failed++;
  p.ends[i] = now + p.ms;
  plays++;
}

while (true) {
  const data = stdin.availableData;
  if (Number(data.length) === 0) break; // Neovim closed the pipe (JXA returns length as a string)
  buffer += $.NSString.alloc.initWithDataEncoding(data, $.NSUTF8StringEncoding).js;
  const keys = [];
  let nl;
  while ((nl = buffer.indexOf('\n')) >= 0) {
    const path = buffer.slice(0, nl).trim();
    buffer = buffer.slice(nl + 1);
    if (path.startsWith('load ')) preload(path.slice(5));
    else if (path) keys.push(path);
  }
  // Each play() costs ~11 ms. If keys ever arrive faster than that, play only the newest
  // two instead of working through a backlog, so the sound never lags behind your typing.
  const now = Date.now();
  for (const path of keys.slice(-2)) play(path, now);
  dropped += Math.max(0, keys.length - 2);
  const live = reap(Date.now()); // after playing, so cleanup never delays a keystroke
  if (DEBUG && plays >= nextLog) {
    nextLog += 250;
    let stale = 0;
    for (const k in pools) for (let i = 0; i < POOL; i++) if (!pools[k].ends[i] && pools[k].sounds[i].isPlaying) stale++;
    console.log(`plays=${plays} dropped=${dropped} failed=${failed} sounding=${live} stuck=${stale}`);
  }
}
