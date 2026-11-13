// The UGen is CompFB. Short name: scsynth rejects UGen names of 32+ characters.
declare name "CompFB";
declare description "Stereo feedback compressor built on co.peak_compression_gain_N_chan_db, with signal-driven makeup gain";

// Build for SuperCollider with build_sc.sh (Apple Silicon: scalar code, no -ftz,
// fixed architecture file, no -ffast-math):
//     ./build_sc.sh comp_fb.dsp
// After rebuilding, check the argument order and names in the generated .sc class.

import("stdfaust.lib");

au = library("autogain.lib");

//============================ UI ======================================
// Every control has an explicit [n] index so the UGen argument order is fixed.
// Continuous controls are smoothed so control-rate changes from SuperCollider
// don't cause zipper noise. `smooth0` starts at the control's value instead
// of 0, so a new synth doesn't begin with a burst of uncompressed signal.
smooth0(x) = f ~ _
with { c = 1 - 44.1/ma.SR; f(y) = ba.if(ba.time == 0, x, c*y + (1 - c)*x); };

// In a feedback loop the gain computer sees the *output* level, so a gain law
// with strength s gives a ratio of 1 + s (not 1/(1 - s) as in feedforward).
// `ratio` here is the real feedback ratio: strength = ratio - 1.
//
// type: 0 = compressor (ratio 1..100)
//       1 = limiter    (ratio 100:1; `ratio` is ignored). A feedback loop can't
//                       reach infinity:1, and higher strengths only add ripple.
// There is no overcompress type: a feedback loop can't make the output fall as
// the input rises.
//
// High ratios with "post" off follow the waveform and add distortion
// (about 6 dB of gain ripple at 100:1 on a 100 Hz sine). "post" on is cleaner.
type     = nentry("[00]type", 0, 0, 1, 1);
ratio    = hslider("[01]ratio", 1, 1, 100, 0.01);
thresh   = hslider("[02]thresh", -20, -60, 0, 0.01) : smooth0;
att      = hslider("[03]att", 5, 0.1, 200, 0.01) * 0.001;
rel      = hslider("[04]rel", 100, 1, 2000, 0.01) * 0.001;
knee     = hslider("[05]knee", 6, 0, 24, 0.01) : smooth0;
prePost  = checkbox("[06]post");
link     = hslider("[07]link", 1, 0, 1, 0.01) : smooth0;

autoOn = checkbox("[08]Autogain");
agMode = nentry("[09]Mode[style:menu{'Average GR':0;'Level match':1}]", 1, 0, 1, 1);
agT    = hslider("[10]Time [unit:s]", 2, 0.5, 10, 0.01);   // short times undo the compression
gateDb = hslider("[11]Gate [unit:dBFS]", -50, -90, 0, 0.01);
maxMk  = hslider("[12]Max makeup [unit:dB]", 24, 0, 48, 0.01);

maxRatio = 100;
r = min(max(ratio, 1), maxRatio);
strength = select2(type, r - 1, maxRatio - 1) : smooth0;

//====================== Stereo gain computer ===========================
// Detector levels (a, b) -> left and right gains in dB (<= 0), linked by `link`.
gc = co.peak_compression_gain_N_chan_db(strength, thresh, att, rel, knee, prePost, link, 2);

//====================== Feedback loop ==================================
// The detector reads the previous output sample (before makeup).
// Inputs: xL, xR. Outputs: yL, yR (compressed), gL, gR (gains in dB).
fbcomp(xL, xR) = step ~ (_, _)
with {
  step(fyL, fyR) = xL * ba.db2linear(gL), xR * ba.db2linear(gR), gL, gR
  with { g = (fyL, fyR) : gc; gL = g : _, !; gR = g : !, _; };
};

//====================== Adaptive autogain ==============================
// Settings from the Autogain controls. Inputs: pIn, pOut, gr -> linear gain.
makeup = au.makeup(autoOn, agMode, agT, gateDb, maxMk);

//====================== Feedback compressor + autogain =================
// There is no sidechain input: in a feedback design the detector has to read
// the compressor's own output.
process(xL, xR) = yL * mk, yR * mk
with {
  c  = fbcomp(xL, xR);
  yL = c : _, !, !, !;
  yR = c : !, _, !, !;
  gL = c : !, !, _, !;
  gR = c : !, !, !, _;

  mk = makeup((xL*xL + xR*xR) / 2,      // input power
              (yL*yL + yR*yR) / 2,      // output power, before makeup
              0 - (gL + gR) / 2);       // gain reduction (dB, >= 0)
};
