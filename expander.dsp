// The UGen is Expander. Short name: scsynth rejects UGen names of 32+ characters.
declare name "Expander";
declare description "Stereo feedforward expander / gate / upward compressor with sidechain inputs, after co.expanderSC_N_chan";

// Build for SuperCollider with build_sc.sh (Apple Silicon: scalar code, no -ftz,
// fixed architecture file, no -ffast-math):
//     ./build_sc.sh expander.dsp
// After rebuilding, check the argument order and names in the generated .sc class.
//
// Inputs: xL, xR = signal to process; sL, sR = detector (sidechain) input.
// For normal expansion, feed the main input into sL, sR as well.
//
// Based on co.expanderSC_N_chan (Faust 2.70), with these differences:
// * Knee: the library divides by min(ma.EPSILON, knee*-2), which is 0 when
//   knee = 0 (a constant 0 knee won't even compile). This uses
//   min(-ma.EPSILON, knee*-2).
// * Hold: the library uses ba.slidingMax over `hold` seconds. With hold = 0
//   its window is empty, the level reads -infinity and the expander applies
//   the full range all the time (it mutes the signal). The window also costs
//   about 16 bytes per sample of maximum hold, from scsynth's real-time
//   memory pool. This uses a peak hold instead: the level is held for `hold`
//   seconds after each new peak, then follows the signal. It needs no buffer,
//   has no maximum, and hold = 0 means no hold.
// * Sidechain: separate sidechain inputs per channel, instead of the
//   library's SCswitch / single SCsignal.
// * `ratio` and `type` instead of a raw strength (see below), and `range` is
//   entered as a positive number of dB.
//
// No autogain: makeup gain doesn't fit an expander. "Average GR" would raise
// the loud, unexpanded parts by the average expansion depth, and "Level match"
// would stay near 0 dB because the loud parts dominate the input power.

import("stdfaust.lib");

//============================ UI ======================================
// Every control has an explicit [n] index so the UGen argument order is fixed.
// Continuous controls are smoothed so control-rate changes from SuperCollider
// don't cause zipper noise. `smooth0` starts at the control's value instead
// of 0, so a new synth doesn't begin with a jump.
smooth0(x) = f ~ _
with { c = 1 - 44.1/ma.SR; f(y) = ba.if(ba.time == 0, x, c*y + (1 - c)*x); };

// type: 0 = expander          (below thresh, 1:ratio downward expansion)
//       1 = gate              (strength 100, as the library suggests; `ratio`
//                              is ignored; `range` sets the depth)
//       2 = upward compressor (below thresh, ratio:1 upward compression;
//                              `range` limits the boost)
type     = nentry("[00]type", 0, 0, 2, 1);
ratio    = hslider("[01]ratio", 1, 1, 100, 0.01);
thresh   = hslider("[02]thresh", -40, -90, 0, 0.01) : smooth0;
range    = hslider("[03]range", 40, 0, 120, 0.01) : smooth0;     // max expansion (or boost) in dB
att      = hslider("[04]att", 1, 0.1, 200, 0.01) * 0.001;        // coming out of expansion
hold     = hslider("[05]hold", 0, 0, 2000, 0.01) * 0.001;        // after each peak
rel      = hslider("[06]rel", 100, 1, 2000, 0.01) * 0.001;       // going into expansion
knee     = hslider("[07]knee", 6, 0, 24, 0.01) : smooth0;
prePost  = checkbox("[08]post");
link     = hslider("[09]link", 1, 0, 1, 0.01) : smooth0;

r = max(ratio, 1);
strength = select3(type, r - 1, 100, 0 - (1 - 1/r)) : smooth0;

//====================== Expansion gain computer ========================
// Static curve, as in co.peak_expansion_gain_mono_db (knee division fixed).
gainComputer(level) =
    select3((level > (thresh - knee/2)) + (level > (thresh + knee/2)),
            level - thresh,
            (level - thresh - knee/2) : pow(2) / min(0 - ma.EPSILON, knee * -2),
            0)
    * abs(strength) : max(0 - range) * (-1 + 2*(strength > 0));

// Peak hold: holds each new peak for `hold` seconds, then follows the input.
peakHold(x) = (f ~ (_, _)) : (_, !)
with {
  n = hold * ma.SR;
  f(h, c) = ba.if(rst, x, ba.if(c < n, h, x)), ba.if(rst, 0, c + 1)
  with { rst = x >= h; };
};

// As in the library: the attack/release swap for upward compression.
attG = select2(strength > 0, rel, att);
relG = select2(strength > 0, att, rel);

// Detector input -> gain in dB (<= 0 for expansion, >= 0 for upward compression).
expGain(x) = x : abs : peakHold
           : ba.bypass1(prePost, si.lag_ud(att, rel))
           : max(1e-10) : ba.linear2db : gainComputer
           : ba.bypass1(prePost != 1, si.lag_ud(attG, relG));

// Two channels, linked as in co.peak_expansion_gain_N_chan_db: crossfade
// between each channel's gain and the larger (least reduced) of the two.
gc(a, b) = linkTo(gA, m), linkTo(gB, m)
with {
  gA = expGain(a);
  gB = expGain(b);
  m  = max(gA, gB);
  linkTo(g, m) = g + link * (m - g);
};

//====================== Process ========================================
process(xL, xR, sL, sR) = xL * ba.db2linear(gL), xR * ba.db2linear(gR)
with {
  g  = (sL, sR) : gc;
  gL = g : _, !;
  gR = g : !, _;
};
