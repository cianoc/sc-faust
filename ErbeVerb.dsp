declare name "ErbeVerb";
import("stdfaust.lib");

// ==========================================
// PARAMETERS (simple lowercase labels -> valid sclang argument names;
// [n] prefixes fix the argument order)
// ==========================================
mix      = hslider("[0]mix",      0.5,  0,   1,    0.001) : si.smoo;
size     = hslider("[1]size",     0.5,  0,   1,    0.001) : si.smooth(ba.tau2pole(0.1));
decay    = hslider("[2]decay",    0.6,  0,   1,    0.001) : si.smoo;
absorb   = hslider("[3]absorb",   0.5,  0,   1,    0.001) : si.smoo;
tilt     = hslider("[4]tilt",     0.5,  0,   1,    0.001) : si.smoo;
preDelay = hslider("[5]predelay", 0.05, 0,   1,    0.001) : si.smooth(ba.tau2pole(0.05));
modMode  = checkbox("[6]argotic");                       // 0 = cyclic, 1 = argotic
modRate  = hslider("[7]modrate",  1.0,  0.1, 10.0, 0.01);
modDepth = hslider("[8]moddepth", 0.2,  0,   1,    0.001) : si.smoo;

// ==========================================
// CONSTANTS: fixed, power-of-two buffer sizes (see notes on RT memory)
// ==========================================
N      = 8;
MAXDEL = 65536;    // loop lines: 0.417 s max needed -> fits up to 96 kHz
APMAX  = 16384;    // in-loop allpass: a quarter of the line
MAXPRE = 131072;   // pre-delay: 1 s up to 96 kHz (clamped above that)

// ==========================================
// HELPERS & MODULATION
// ==========================================
pDelay = de.sdelay(MAXPRE, 1024, min(MAXPRE - 1, preDelay * ma.SR));

// Bounded cubic soft clipper: unity slope at 0, flat at +/-1.5 -> output in [-1, 1]
saturate = max(-1.5) : min(1.5) : \(x).(x - x*x*x / 6.75);

baseDelays = (0.029, 0.037, 0.043, 0.053, 0.067, 0.079, 0.089, 0.103);

// Independent band-limited random signal per line (no.noise would be the SAME
// noise in all 8 lines)
lfn(i, f) = no.noises(N, i) : ba.latch(os.oscrs(f)) : fi.lowpass(2, f);

modSignal(i) = select2(modMode, cyclic, argotic)
with {
    phase   = (i * 2.0 * ma.PI) / N;
    cyclic  = os.oscp(modRate, phase) * (modDepth * 0.002);
    argotic = lfn(i, modRate * (1.0 + 0.1 * i)) * (modDepth * 0.005);
};

// ==========================================
// ONE FDN BRANCH
// ==========================================
fdnBranch(i) = allpass : line : fi.dcblocker : damping : feedbackGain : saturate
with {
    delaySamples = ((ba.take(i + 1, baseDelays) * (size * 3.9 + 0.1)) + modSignal(i)) * ma.SR
                 : max(8) : min(MAXDEL - 2);
    allpass = fi.allpass_fcomb(APMAX, min(APMAX - 2, delaySamples * 0.25), 0.5);
    line    = de.fdelay(MAXDEL, delaySamples);       // interpolated: modulation won't click
    damping = fi.lowpass(1, 200 * pow(80, 1 - absorb));  // absorb 0 = 16 kHz .. 1 = 200 Hz, exponential
    feedbackGain = *(decay * 1.15);                  // > 1 self-oscillates into the clipper
};

processBranches = par(i, N, fdnBranch(i));

// Normalized Hadamard (ro.hadamard is unnormalized: gain sqrt(8))
matrixMix = ro.hadamard(N) : par(i, N, /(sqrt(N)));

injectLines(L, R) = (L, R, L + R, L - R, L, R, L + R, L - R) : par(i, N, *(0.35));

// Inputs to (A ~ B): B's 8 outputs feed A's first 8 inputs; injection is the last 8.
// Branches sit in the forward path so the wet taps are delayed, not the raw input.
fdnLoop = (ro.interleave(N, 2) : par(i, N, +) : processBranches) ~ matrixMix;

// ==========================================
// OUTPUT
// ==========================================
downmix(x1, x2, x3, x4, x5, x6, x7, x8) = (x1 + x3 + x5 + x7) * 0.25, (x2 + x4 + x6 + x8) * 0.25;

tiltEQ = par(i, 2, tiltOne)
with {
    tiltOne = _ <: fi.lowpass(1, 1000) * (1.8 - tilt * 1.6),
                   fi.highpass(1, 1000) * (0.2 + tilt * 1.6) :> _;
};

wet = par(i, 2, pDelay) : injectLines : fdnLoop : downmix : tiltEQ;

dryWet(dl, dr, wl, wr) = dl * (1 - mix) + wl * mix, dr * (1 - mix) + wr * mix;

process = _, _ <: _, _, wet : dryWet;
