// Long-running macOS sound player for :ASMR (run with: osascript -l JavaScript asmr_player.js).
// Spawning afplay per key costs ~1 s of process lifetime each, so fast typing piles them up.
// This keeps every clip loaded and plays one per line read from stdin: "<path>\n".
ObjC.import('AppKit');
const stdin = $.NSFileHandle.fileHandleWithStandardInput;
const cache = {};
let buffer = '';
while (true) {
  const data = stdin.availableData;
  if (Number(data.length) === 0) break; // Neovim closed the pipe (JXA returns length as a string)
  buffer += $.NSString.alloc.initWithDataEncoding(data, $.NSUTF8StringEncoding).js;
  let nl;
  while ((nl = buffer.indexOf('\n')) >= 0) {
    const path = buffer.slice(0, nl).trim();
    buffer = buffer.slice(nl + 1);
    if (!path) continue;
    if (!cache[path]) cache[path] = $.NSSound.alloc.initWithContentsOfFileByReference(path, true);
    // A copy lets the same clip overlap itself when keys are pressed quickly.
    const s = cache[path].copy;
    s.volume = 0.7;
    s.play;
  }
}
