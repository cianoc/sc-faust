// The UGen is CompRMSFBLimMono. Short name: scsynth rejects UGen names of 32+ characters.
declare name "CompRMSFBLimMono";
declare description "Mono RMS feedback compressor into a peak limiter that feeds back into the compressor (after co.RMS_FBcompressor_peak_limiter_N_chan), with signal-driven makeup gain";

// Build for SuperCollider with build_sc.sh (Apple Silicon: scalar code, no -ftz,
// fixed architecture file, no -ffast-math):
//     ./build_sc.sh comp_rms_fb_lim_mono.dsp
// After rebuilding, check the argument order and names in the generated .sc class.
//
// Signal flow:
//   x -> RMS FB compressor -> makeup -> peak limiter -> out
//                ^                              |
//                +--- limited signal, without --+
//                     the makeup, fed back
//
// Based on the structure of co.RMS_FBcompressor_peak_limiter_N_chan, with
// these differences:
// * RMS detector: a one-pole mean-square average (time constant `rel`)
//   instead of ba.slidingRMS. ba.slidingRMS integrates x^2 without limit; in
//   single precision (as in SuperCollider) the sum stops changing after about
//   15 minutes of a -6 dBFS signal, the RMS then reads 0 and compression stops.
//   Its window also needs up to 2 MB from scsynth's real-time memory pool.
//   The one-pole average is stable and needs no buffer; its window is
//   exponential rather than rectangular.
// * `ratio` is the real feedback ratio (strength = ratio - 1), because in a
//   feedback loop a strength s gives a ratio of 1 + s.
// * The makeup gain sits before the limiter, so it can't push peaks past
//   `limit`. The signal fed back to the compressor is the limited signal
//   without the makeup, which is what the library feeds back when there is
//   no makeup.
// * The compressor gain is exposed so the autogain can use it. Autogain only
//   measures the compressor; the limiter is left as a safety stage.
// * The limiter has its own release, `limRel`. The library uses min(att, rel),
//   so a fast compressor attack also gave the limiter a release of a few ms,
//   which distorts bass: on a 50 Hz tone limited by 5 dB, THD was 13.4 % with a
//   5 ms release and 2.4 % with 50 ms.

import("stdfaust.lib");

au = library("autogain.lib");

//============================ UI ======================================
// Every control has an explicit [n] index so the UGen argument order is fixed.
// Continuous controls are smoothed so control-rate changes from SuperCollider
// don't cause zipper noise. `smooth0` starts at the control's value instead
// of 0, so a new synth doesn't begin with a burst of uncompressed signal.
smooth0(x) = f ~ _
with { c = 1 - 44.1/ma.SR; f(y) = ba.if(ba.time == 0, x, c*y + (1 - c)*x); };

ratio    = hslider("[00]ratio", 1, 1, 100, 0.01);
thresh   = hslider("[01]thresh", -20, -60, 0, 0.01) : smooth0;
threshLim= hslider("[02]limit", -1, -60, 0, 0.01) : smooth0;    // limiter threshold (dBFS)
limRel   = hslider("[03]limRel", 50, 1, 1000, 0.01) * 0.001;    // limiter release
att      = hslider("[04]att", 5, 0.1, 200, 0.01) * 0.001;
rel      = hslider("[05]rel", 100, 1, 2000, 0.01) * 0.001;      // RMS time constant
knee     = hslider("[06]knee", 6, 0, 24, 0.01) : smooth0;       // the limiter uses half this

autoOn = checkbox("[07]Autogain");
agMode = nentry("[08]Mode[style:menu{'Average GR':0;'Level match':1}]", 1, 0, 1, 1);
agT    = hslider("[09]Time [unit:s]", 2, 0.5, 10, 0.01);   // short times undo the compression
gateDb = hslider("[10]Gate [unit:dBFS]", -50, -90, 0, 0.01);
maxMk  = hslider("[11]Max makeup [unit:dB]", 24, 0, 48, 0.01);

maxRatio = 100;
strength = min(max(ratio, 1), maxRatio) - 1 : smooth0;          // feedback: ratio = 1 + strength

//====================== RMS compressor gain ============================
// Static curve, as in co.RMS_compression_gain_mono_db.
gainComputer(level) =
    select3((level > (thresh - knee/2)) + (level > (thresh + knee/2)),
            0,
            (level - thresh + knee/2) : pow(2) / (2 * max(ma.EPSILON, knee)),
            level - thresh)
    : max(0) * -strength;

// Level -> gain in dB (<= 0): mean-square average over `rel`, then the
// library's attack smoothing (instant release).
rmsGain(x) = x * x : si.smooth(ba.tau2pole(rel)) : sqrt
           : si.onePoleSwitching(att, 0) : max(1e-10) : ba.linear2db : gainComputer;

//====================== Peak limiter gain ==============================
// As in the library: strength 1, instant attack, half the knee; release
// `limRel` (the library uses min(att, rel)).
limGain = co.peak_compression_gain_mono_db(1, threshLim, 0, limRel, knee * 0.5, 0);

//====================== Adaptive autogain ==============================
// Settings from the Autogain controls. Inputs: pIn, pOut, gr -> linear gain.
makeup = au.makeup(autoOn, agMode, agT, gateDb, maxMk);

//====================== Compressor + limiter loop ======================
// Outputs: fb (fed back), out.
loop(x) = step ~ _
with {
  step(fy) = fb, out
  with {
    gc  = fy : rmsGain;
    yc  = x * ba.db2linear(gc);                // compressed, before makeup
    mk  = makeup(x*x, yc*yc, 0 - gc);          // input power, compressor output power, GR
    gl  = ba.db2linear(yc * mk : limGain);     // limiter sees the made-up signal
    out = yc * mk * gl;
    fb  = yc * gl;                             // limited, without the makeup
  };
};

//====================== Process ========================================
// There is no sidechain input: the compressor has to read its own output.
process(x) = loop(x) : !, _;
