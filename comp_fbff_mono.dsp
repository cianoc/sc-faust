// The UGen is CompFBFFMono. Short name: scsynth rejects UGen names of 32+ characters.
declare name "CompFBFFMono";
declare description "Mono compressor that crossfades between feedforward and feedback detection (after co.FBFFcompressor_N_chan), with signal-driven makeup gain";

// Build for SuperCollider with build_sc.sh (Apple Silicon: scalar code, no -ftz,
// fixed architecture file, no -ffast-math):
//     ./build_sc.sh comp_fbff_mono.dsp
// After rebuilding, check the argument order and names in the generated .sc class.
//
// Based on the structure of co.FBFFcompressor_N_chan, with these differences:
// * FBFF runs 0 = feedforward, 1 = feedback, as that function's documentation
//   says. (In Faust 2.70 the library function actually runs the other way:
//   0 = feedback, 1 = feedforward.)
// * Each path gets the strength that gives the same ratio, so the static
//   ratio is `ratio` at every FBFF setting and FBFF only changes the character.
//   (The library uses strength x 3 for the feedback path, which only roughly
//   matches.)
// * The gain is exposed so the autogain can use it.

import("stdfaust.lib");

au = library("autogain.lib");

//============================ UI ======================================
// Every control has an explicit [n] index so the UGen argument order is fixed.
// Continuous controls are smoothed so control-rate changes from SuperCollider
// don't cause zipper noise. `smooth0` starts at the control's value instead
// of 0, so a new synth doesn't begin with a burst of uncompressed signal.
smooth0(x) = f ~ _
with { c = 1 - 44.1/ma.SR; f(y) = ba.if(ba.time == 0, x, c*y + (1 - c)*x); };

// type: 0 = compressor (ratio 1..100)
//       1 = limiter    (`ratio` is ignored): infinity:1 on the feedforward
//                       path, 100:1 on the feedback path (a feedback loop
//                       can't reach infinity:1)
// There is no overcompress type: the feedback path can't make the output fall
// as the input rises.
//
// High ratios with "post" off and FBFF towards 1 follow the waveform and add
// distortion. "post" on is cleaner.
type     = nentry("[00]type", 0, 0, 1, 1);
ratio    = hslider("[01]ratio", 1, 1, 100, 0.01);
thresh   = hslider("[02]thresh", -20, -60, 0, 0.01) : smooth0;
att      = hslider("[03]att", 5, 0.1, 200, 0.01) * 0.001;
rel      = hslider("[04]rel", 100, 1, 2000, 0.01) * 0.001;
knee     = hslider("[05]knee", 6, 0, 24, 0.01) : smooth0;
prePost  = checkbox("[06]post");
fbff     = hslider("[07]FBFF", 0, 0, 1, 0.01) : smooth0;   // 0 = feedforward, 1 = feedback

autoOn = checkbox("[08]Autogain");
agMode = nentry("[09]Mode[style:menu{'Average GR':0;'Level match':1}]", 1, 0, 1, 1);
agT    = hslider("[10]Time [unit:s]", 2, 0.5, 10, 0.01);   // short times undo the compression
gateDb = hslider("[11]Gate [unit:dBFS]", -50, -90, 0, 0.01);
maxMk  = hslider("[12]Max makeup [unit:dB]", 24, 0, 48, 0.01);

// Strengths that give the same ratio R on each path:
//   feedforward: R = 1/(1 - s)  ->  s = 1 - 1/R
//   feedback:    R = 1 + s      ->  s = R - 1
// With these, any FBFF mix also gives exactly R above the knee.
maxRatio = 100;
r     = min(max(ratio, 1), maxRatio);
sFF   = select2(type, 1 - 1/r, 1)            : smooth0;
sFB   = select2(type, r - 1, maxRatio - 1)   : smooth0;

//====================== Gain computers =================================
// Level -> gain in dB (<= 0).
gcFF = co.peak_compression_gain_mono_db(sFF, thresh, att, rel, knee, prePost);
gcFB = co.peak_compression_gain_mono_db(sFB, thresh, att, rel, knee, prePost);

//====================== FB/FF loop =====================================
// The feedforward detector reads the input; the feedback detector reads the
// previous output sample (before makeup). Their gains are crossfaded in dB.
// Input: x. Outputs: y (compressed), g (gain in dB).
fbffcomp(x) = step ~ _
with {
  step(fy) = x * ba.db2linear(g), g
  with { g = (x : gcFF) * (1 - fbff) + (fy : gcFB) * fbff; };
};

//====================== Adaptive autogain ==============================
// Settings from the Autogain controls. Inputs: pIn, pOut, gr -> linear gain.
makeup = au.makeup(autoOn, agMode, agT, gateDb, maxMk);

//====================== FB/FF compressor + autogain ====================
// There is no sidechain input: the feedback path has to read the
// compressor's own output.
process(x) = y * mk
with {
  c  = fbffcomp(x);
  y  = c : _, !;
  g  = c : !, _;
  mk = makeup(x*x,             // input power
              y*y,             // output power, before makeup
              0 - g);          // gain reduction (dB, >= 0)
};
