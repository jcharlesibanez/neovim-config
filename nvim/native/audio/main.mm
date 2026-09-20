#import <Foundation/Foundation.h>
#import <CoreAudio/CoreAudio.h>
#import <CoreAudio/CATapDescription.h>
#import <CoreAudio/AudioHardwareTapping.h>
#include <algorithm>
#include <array>
#include <atomic>
#include <chrono>
#include <cmath>
#include <csignal>
#include <cstdio>
#include <cstring>
#include <thread>
#include <unistd.h>

constexpr size_t count = 256;
struct Capture {
    std::array<std::atomic<float>, count> samples{};
    std::atomic<uint64_t> packets{0};
};
static volatile sig_atomic_t stopping = 0;
static void stop(int) { stopping = 1; }

// The audio callback does no allocation, file IO, or locking.
static OSStatus receive(AudioObjectID, const AudioTimeStamp *, const AudioBufferList *input,
                        const AudioTimeStamp *, AudioBufferList *, const AudioTimeStamp *, void *context) {
    auto &capture = *static_cast<Capture *>(context);
    if (!input || input->mNumberBuffers == 0) return noErr;
    const auto &buffer = input->mBuffers[0];
    if (!buffer.mData || buffer.mNumberChannels == 0) return noErr;
    const size_t frames = buffer.mDataByteSize / sizeof(float) / buffer.mNumberChannels;
    if (!frames) return noErr;
    const auto *data = static_cast<const float *>(buffer.mData);
    for (size_t i = 0; i < count; ++i) {
        const size_t frame = i * frames / count;
        float value = 0;
        for (UInt32 channel = 0; channel < buffer.mNumberChannels; ++channel)
            value += data[frame * buffer.mNumberChannels + channel];
        value /= buffer.mNumberChannels;
        capture.samples[i].store(std::isfinite(value) ? value : 0, std::memory_order_relaxed);
    }
    capture.packets.fetch_add(1, std::memory_order_release);
    return noErr;
}

static bool check(OSStatus status, const char *operation) {
    if (status == noErr) return true;
    fprintf(stderr, "%s failed (%d). Allow system audio capture in macOS Privacy & Security, then run :AudioStart.\n", operation, (int)status);
    return false;
}

int main(int argc, char **argv) {
    signal(SIGTERM, stop); signal(SIGINT, stop); signal(SIGPIPE, stop);
    const pid_t parent = getppid();
    Capture capture;
    if (argc > 1 && strcmp(argv[1], "--self-test") == 0) {
        std::array<float, count> samples{};
        for (size_t i = 0; i < count; ++i) samples[i] = std::sin(i * .1f);
        AudioBufferList list{};
        list.mNumberBuffers = 1; list.mBuffers[0] = {1, sizeof(samples), samples.data()};
        receive(0, nullptr, &list, nullptr, nullptr, nullptr, &capture);
        for (size_t i = 0; i < count; ++i)
            if (std::abs(capture.samples[i].load() - samples[i]) > .00001f) return 1;
        puts("PASS: PCM callback preserves signed samples"); return 0;
    }
    int seconds = argc > 2 && strcmp(argv[1], "--seconds") == 0 ? atoi(argv[2]) : 0;
    @autoreleasepool {
        if (@available(macOS 14.2, *)) {
            CATapDescription *description = [[CATapDescription alloc] initMonoGlobalTapButExcludeProcesses:@[]];
            description.name = @"Neovim system waveform";
            description.UUID = [NSUUID UUID];
            description.privateTap = YES;
            description.muteBehavior = CATapUnmuted;
            AudioObjectID tap = kAudioObjectUnknown, aggregate = kAudioObjectUnknown;
            if (!check(AudioHardwareCreateProcessTap(description, &tap), "System audio tap")) return 2;
            AudioStreamBasicDescription format{};
            UInt32 size = sizeof(format);
            AudioObjectPropertyAddress address = {kAudioTapPropertyFormat, kAudioObjectPropertyScopeGlobal, kAudioObjectPropertyElementMain};
            if (!check(AudioObjectGetPropertyData(tap, &address, 0, nullptr, &size, &format), "Audio format") ||
                format.mFormatID != kAudioFormatLinearPCM || !(format.mFormatFlags & kAudioFormatFlagIsFloat) || format.mBitsPerChannel != 32) {
                fprintf(stderr, "The system tap must supply 32-bit float PCM.\n");
                AudioHardwareDestroyProcessTap(tap); return 3;
            }
            NSDictionary *options = @{
                @kAudioAggregateDeviceNameKey: @"Neovim waveform (private)",
                @kAudioAggregateDeviceUIDKey: [[NSUUID UUID] UUIDString],
                @kAudioAggregateDeviceIsPrivateKey: @YES,
                @kAudioAggregateDeviceTapAutoStartKey: @NO,
                @kAudioAggregateDeviceTapListKey: @[@{
                    @kAudioSubTapUIDKey: description.UUID.UUIDString,
                    @kAudioSubTapDriftCompensationKey: @YES,
                }],
            };
            if (!check(AudioHardwareCreateAggregateDevice((__bridge CFDictionaryRef)options, &aggregate), "Audio stream")) {
                AudioHardwareDestroyProcessTap(tap); return 4;
            }
            AudioDeviceIOProcID proc = nullptr;
            if (!check(AudioDeviceCreateIOProcID(aggregate, receive, &capture, &proc), "Audio callback")) {
                AudioHardwareDestroyAggregateDevice(aggregate); AudioHardwareDestroyProcessTap(tap); return 5;
            }
            if (!check(AudioDeviceStart(aggregate, proc), "Start audio")) {
                AudioDeviceDestroyIOProcID(aggregate, proc); AudioHardwareDestroyAggregateDevice(aggregate);
                AudioHardwareDestroyProcessTap(tap); return 6;
            }
            setvbuf(stdout, nullptr, _IOLBF, 0);
            const auto start = std::chrono::steady_clock::now();
            auto lastPacket = start;
            uint64_t previous = 0;
            while (!stopping && getppid() == parent) {
                const auto now = std::chrono::steady_clock::now();
                if (seconds > 0 && now - start >= std::chrono::seconds(seconds)) break;
                uint64_t packets = capture.packets.load(std::memory_order_acquire);
                if (packets != previous) { lastPacket = now; previous = packets; }
                bool fresh = packets > 0 && now - lastPacket < std::chrono::milliseconds(200);
                printf("{\"status\":\"%s\",\"samples\":[", packets > 0 ? "live" : "waiting");
                for (size_t i = 0; i < count; ++i)
                    printf("%s%.5f", i ? "," : "", fresh ? capture.samples[i].load(std::memory_order_relaxed) : 0.f);
                puts("]}");
                std::this_thread::sleep_for(std::chrono::milliseconds(40));
            }
            AudioDeviceStop(aggregate, proc);
            AudioDeviceDestroyIOProcID(aggregate, proc);
            AudioHardwareDestroyAggregateDevice(aggregate);
            AudioHardwareDestroyProcessTap(tap);
        } else {
            fprintf(stderr, "System audio capture requires macOS 14.2 or newer.\n"); return 7;
        }
    }
    return 0;
}
