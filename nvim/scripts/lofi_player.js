// macOS stream player for :Lofi (run with: osascript -l JavaScript lofi_player.js <url> [volume]).
// Uses the system AVPlayer, so nothing needs installing. Talks back on stdout, one word per line:
//   playing  - audio is actually coming out
//   failed   - the stream errored or stalled; Neovim moves on to the next station
ObjC.import('Foundation');
ObjC.import('unistd');
// JXA can't ObjC.import AVFoundation by name, so load the framework and look the class up.
$.NSBundle.bundleWithPath('/System/Library/Frameworks/AVFoundation.framework').load;

function say(word) {
  const data = $.NSString.alloc.initWithUTF8String(word + '\n').dataUsingEncoding($.NSUTF8StringEncoding);
  $.NSFileHandle.fileHandleWithStandardOutput.writeData(data);
}

function run(argv) {
  const url = $.NSURL.URLWithString(argv[0]);
  const player = $.NSClassFromString('AVPlayer').playerWithURL(url);
  player.volume = Number(argv[1] || 0.5);
  player.play;

  // If Neovim dies without stopping us, we get re-parented to launchd: quit instead of
  // playing music forever with nothing left to turn it off.
  const parent = $.getppid();
  let playing = false;
  let quietSince = Date.now();

  while ($.getppid() === parent) {
    // AVPlayer needs the run loop turning to buffer, recover and report status.
    $.NSRunLoop.currentRunLoop.runUntilDate($.NSDate.dateWithTimeIntervalSinceNow(0.25));
    delay(0.25);
    const failed = Number(player.currentItem.status) === 2; // AVPlayerItemStatusFailed
    const audible = Number(player.timeControlStatus) === 2;  // AVPlayerTimeControlStatusPlaying
    if (audible) {
      quietSince = Date.now();
      if (!playing) { playing = true; say('playing'); }
    } else if (playing && Number(player.timeControlStatus) === 0) {
      player.play; // paused by a hiccup (e.g. audio device change): resume
    }
    // Errored, or no sound for 15 s (never connected, or the stream died): give up.
    if (failed || Date.now() - quietSince > 15000) { say('failed'); return; }
  }
}
