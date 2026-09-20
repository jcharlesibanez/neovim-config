# Neovim system-audio waveform

The helper uses a private, unmuted macOS Core Audio process tap to read system
playback. It does not use the microphone, change the output device, save audio,
or send it over the network. PCM is reduced to 256 signed samples per frame and
sent to Neovim through the child process's stdout pipe, about 25 times a second.

The footer displays `max(0, sample * gain)`, capped at 1. Negative samples stay
at zero: this is half-wave rectification, not absolute-value rectification.
The default display gain is 2.5; set `vim.g.system_audio_gain` to change it.
Silence produces a flat baseline. The footer reserves four rows rather than
covering editable text. The helper destroys its private tap and aggregate device
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
