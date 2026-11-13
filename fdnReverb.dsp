// The UGen is OTT. Short name: scsynth rejects UGen names of 32+ characters.
declare name "OTT";
declare description "Stereo wrapper around co.xfer_ott (Xfer OTT model) for SuperCollider: numbered, smoothed controls and a lookahead limiter";

// Build for SuperCollider with build_sc.sh (Apple Silicon: scalar code, no -ftz,
// fixed architecture file, no -ffast-math):
//     ./build_sc.sh ott.dsp
// Keep xfer_ott_270.lib in the same folder as this file.
// After rebuilding, check the argument order and names in the generated .sc class.
//
// xfer_ott_270.lib is co.xfer_ott with a change so it compiles with Faust 2.70.
// With Faust 2.90 or later you can use co.xfer_ott instead: replace
// `ot.xfer_ott` with `co.xfer_ott` and remove the `ot = library(...)` line.
//
// Signal flow: in -> xfer_ott -> lookahead limiter -> out
// The limiter is co.limiter_lad_stereo with the settings of co.limiter_lad_bw
// (10 ms lookahead, ~1.6 ms attack, 100 ms hold, ~160 ms release), but with an
// adjustable ceiling. It adds 10 ms of latency, also when `limit` is off, so
// turning it on or off doesn't shift the timing. SuperCollider doesn't
// compensate for latency: delay any parallel dry path by 10 ms.

import("stdfaust.lib");

ot = library("xfer_ott_270.lib");

//============================ UI ======================================
// Every control has an explicit [n] index so the UGen argument order is fixed.
// All controls except `time` are smoothed (xfer_ott doesn't smooth them, and SuperCollider
// sends control changes in steps). `smooth0` starts at the control's value
// instead of 0, so a new synth doesn't begin with a fade or a jump.
smooth0(x) = f ~ _
with { c = 1 - 44.1/ma.SR; f(y) = ba.if(ba.time == 0, x, c*y + (1 - c)*x); };

// Same ranges and defaults as the plug-in (percent controls as 0-2 or 0-10,
// gains in dB). Bypass switches are smoothed too, so they fade instead of click.
depth    = hslider("[00]depth",    1, 0, 1, 0.01)      : smooth0;   // 0-100 %
time     = hslider("[01]time",     1, 0, 10, 0.01);               // release scale, 1 = 100 %;
                                                                   // not smoothed: it only sets a release time
                                                                   // (smoothing it cost 3 expm1 calls per sample)
inGain   = hslider("[02]inGain",   0, -60, 19.1, 0.01) : smooth0;   // dB
outGain  = hslider("[03]outGain",  0, -60, 19.1, 0.01) : smooth0;   // dB
upward   = hslider("[04]upward",   1, 0, 2, 0.01)      : smooth0;   // 0-200 %
downward = hslider("[05]downward", 1, 0, 2, 0.01)      : smooth0;   // 0-200 %
threshL  = hslider("[06]threshL",  1, 0, 2, 0.01)      : smooth0;   // 0-200 %
threshM  = hslider("[07]threshM",  1, 0, 2, 0.01)      : smooth0;
threshH  = hslider("[08]threshH",  1, 0, 2, 0.01)      : smooth0;
gainL    = hslider("[09]gainL",    0, -60, 6, 0.01)    : smooth0;   // band output gain, dB
gainM    = hslider("[10]gainM",    0, -60, 6, 0.01)    : smooth0;
gainH    = hslider("[11]gainH",    0, -60, 6, 0.01)    : smooth0;
bypUpL   = checkbox("[12]bypUpL") : smooth0;                        // 1 = bypass that branch
bypUpM   = checkbox("[13]bypUpM") : smooth0;
bypUpH   = checkbox("[14]bypUpH") : smooth0;
bypDnL   = checkbox("[15]bypDnL") : smooth0;
bypDnM   = checkbox("[16]bypDnM") : smooth0;
bypDnH   = checkbox("[17]bypDnH") : smooth0;

process = ot.xfer_ott(depth, time, inGain, outGain, upward, downward,
                      threshL, threshM, threshH, gainL, gainM, gainH,
                      bypUpL, bypUpM, bypUpH, bypDnL, bypDnM, bypDnH);
