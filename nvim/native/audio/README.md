# Neovim system-audio waveform

The helper uses a private, unmuted macOS Core Audio process tap to read system
playback. It does not use the microphone, change the output device, save audio,
or send it over the network. PCM is reduced to 256 signed samples per frame and
sent to Neovim through the child process's stdout pipe, about 25 times a second.

The footer draws thin vertical strokes, separated by two blank columns, in
muted cyan. A single braille column gives each tip four bottom-up positions
per character row, rather than growing in whole pipe-character steps. This
is terminal-cell rendering, not a pixel graphics overlay. Samples are half-wave rectified with `max(0, sample * gain)`, capped
at 1, before measuring positive peaks in 64 small groups. The envelope responds
over 80 ms and settles over 280 ms to follow the music without hard jumps.
Negative samples never become positive energy. The default display gain is 2.5;
set `vim.g.system_audio_gain` to change it. Silence settles to a dotted baseline. The footer reserves four audio rows plus a seven-row invisible keyboard map
rather than covering editable text. The keyboard map has 68 US/ANSI key slots
(excluding power and standalone modifiers). Squares flash green only for keys
Neovim receives and fade back to black after 350 ms. This uses `vim.on_key`,
requires no keyboard-monitoring permission, and stores no keystroke history.
OS-reserved media shortcuts that never reach Neovim cannot light a square. The helper destroys its private tap and aggregate device
on exit, and also exits if its Neovim parent disappears.

## Controls

- `Space u v` or `:AudioToggle`: show/hide the waveform and start/stop capture.
- `:AudioStart`: start or retry capture.
- `:AudioStop`: stop capture and remove the footer.
- `Space u a`: pause/resume all motion, including audio capture.

The waveform starts when an interactive Neovim UI opens. To opt out, set
`vim.g.system_audio_autostart = false` before loading the configuration.
Headless Neovim does not start capture.

macOS may request system-audio capture permission for the launching terminal.
Allow it in the prompt or in System Settings > Privacy & Security > Screen &
System Audio Recording, then run `:AudioStart`. Permission errors are displayed
in the footer; the visualizer does not substitute fake waveform data.

## Build

Requires macOS 14.2+ and Apple's Command Line Tools. This installation includes a
locally compiled, ad-hoc-signed helper in `build/system-waveform` (git-ignored).
After changing the native source, run `:AudioBuild`, or run `sh build.sh` here.
`build/system-waveform --self-test` checks the signed PCM conversion without
capturing audio. `--seconds 4` limits a live capture to four seconds.

API reference: [Apple: Capturing system audio with Core Audio taps](https://developer.apple.com/documentation/coreaudio/capturing-system-audio-with-core-audio-taps).
