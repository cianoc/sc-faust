// The UGen is CompRMSMono. Short name: scsynth rejects UGen names of 32+ characters.
declare name "CompRMSMono";
declare description "Mono feedforward compressor built on co.RMS_compression_gain_mono_db, with signal-driven makeup gain";

// Build for SuperCollider with build_sc.sh (Apple Silicon: scalar code, no -ftz,
// fixed architecture file, no -ffast-math):
//     ./build_sc.sh comp_rms_mono.dsp
// After rebuilding, check the argument order and names in the generated .sc class.

// Based on co.RMS_compression_gain_mono_db, with one difference:
// * RMS detector: a one-pole mean-square average (time constant `rel`)
//   instead of ba.slidingRMS. ba.slidingRMS integrates x^2 without limit; in
//   single precision (as in SuperCollider) the sum stops changing after about
//   15 minutes of a -6 dBFS signal, the RMS then reads 0 and compression stops.
//   Its window also needs up to 2 MB from scsynth's real-time
//   memory pool. The one-pole average is stable and needs no buffer; its
//   window is exponential rather than rectangular.
// As in the library, `rel` is the RMS time constant, `att` smooths the level
// (post off) or the gain (post on), and the release is set by the RMS averaging.

import("stdfaust.lib");

au = library("autogain.lib");

//============================ UI ======================================
// Every control has an explicit [n] index so the UGen argument order is fixed.
// Continuous controls are smoothed so control-rate changes from SuperCollider
// don't cause zipper noise (the gain computer reacts instantly to these when
// "post" is off). `smooth0` starts at the control's value instead of 0, so a
// new synth doesn't begin with a burst of uncompressed signal.
smooth0(x) = f ~ _
with { c = 1 - 44.1/ma.SR; f(y) = ba.if(ba.time == 0, x, c*y + (1 - c)*x); };

// type: 0 = compressor   (ratio 1..100 -> strength 0..0.99)
//       1 = limiter      (strength 1, infinite ratio; `ratio` is ignored)
//       2 = overcompress (ratio 1..100 -> strength 1..1.99; output falls as
//                         input rises above threshold; higher ratio = stronger)
type     = nentry("[00]type", 0, 0, 2, 1);
ratio    = hslider("[01]ratio", 1, 1, 100, 0.01);
thresh   = hslider("[02]thresh", -20, -60, 0, 0.01) : smooth0;
att      = hslider("[03]att", 5, 0.1, 200, 0.01) * 0.001;
rel      = hslider("[04]rel", 100, 1, 2000, 0.01) * 0.001;    // RMS time constant
knee     = hslider("[05]knee", 6, 0, 24, 0.01) : smooth0;
prePost  = checkbox("[06]post");

// Autogain assumes the sidechain carries the same signal as the main input.
// With a different sidechain signal (e.g. ducking), turn autogain off: both
// modes would add the ducking back over `Time` seconds.
autoOn = checkbox("[07]Autogain");
agMode = nentry("[08]Mode[style:menu{'Average GR':0;'Level match':1}]", 1, 0, 1, 1);
agT    = hslider("[09]Time [unit:s]", 2, 0.5, 10, 0.01);   // short times undo the compression
gateDb = hslider("[10]Gate [unit:dBFS]", -50, -90, 0, 0.01);
maxMk  = hslider("[11]Max makeup [unit:dB]", 24, 0, 48, 0.01);

r = max(ratio, 1);
strength = select3(type, 1 - 1/r, 1, 2 - 1/r) : smooth0;

//====================== RMS gain computer ==============================
// Static curve, as in co.RMS_compression_gain_mono_db.
gainComputer(level) =
    select3((level > (thresh - knee/2)) + (level > (thresh + knee/2)),
            0,
            (level - thresh + knee/2) : pow(2) / (2 * max(ma.EPSILON, knee)),
            level - thresh)
    : max(0) * -strength;

// Detector input -> gain in dB (<= 0). Same smoothing as the library:
// post off: attack smoothing on the RMS level; post on: attack smoothing on
// the gain.
rmsGain(x) = x * x : si.smooth(ba.tau2pole(rel)) : sqrt
           : ba.bypass1(prePost, si.onePoleSwitching(att, 0))
           : max(1e-10) : ba.linear2db : gainComputer
           : ba.bypass1(prePost != 1, si.onePoleSwitching(0, att));

gc = rmsGain;

//====================== Adaptive autogain ==============================
// Settings from the Autogain controls. Inputs: pIn, pOut, gr -> linear gain.
makeup = au.makeup(autoOn, agMode, agT, gateDb, maxMk);

//====================== Feedforward compressor + autogain ==============
// Inputs: x = signal to compress; s = detector (sidechain) input.
// For normal compression, feed the main input into s as well.
process(x, s) = y * mk
with {
  g  = s : gc;                 // feedforward: the detector reads the sidechain
  y  = x * ba.db2linear(g);
  mk = makeup(x*x,             // input power
              y*y,             // output power, before makeup
              0 - g);          // gain reduction (dB, >= 0)
};
