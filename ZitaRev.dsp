// The UGen is ZitaRev. Short name: scsynth rejects UGen names of 32+ characters.
declare name "ZitaRev";
declare description "Stereo zita-rev1 reverb (re.zita_rev1_stereo) with zita-rev1's EQ, dry/wet mix and level, for SuperCollider";
declare zita_rev_fdn author "Julius O. Smith III";
declare zita_rev_fdn license "MIT-style STK-4.3 license";

// Build for SuperCollider with build_sc.sh (Apple Silicon: scalar code, no -ftz,
// fixed architecture file, no -ffast-math):
//     ./build_sc.sh zita_rev.dsp
// After rebuilding, check the argument order and names in the generated .sc class.
//
// Inputs: L, R. Outputs: L, R (dry + reverb, mixed by `mix`).
//
// The reverb is re.zita_rev1_stereo as in the current faustlibraries (reverbs.lib
// commits of 2026-10-03, "zita_rev1 matches zita-rev1"), copied here because
// Faust 2.70's version differs from zita-rev1 in ways you can hear:
// * Pre-delay buffer of 8192 samples: delays are cut short above 85 ms at 96 kHz
//   and 43 ms at 192 kHz. Here 32768 samples (100 ms at 192 kHz is 19200).
// * Inputs fed to the 8 delay lanes as L,R,-L,-R,L,R,-L,-R; zita-rev1 feeds
//   lanes 0-3 from L (+,+,-,-) and lanes 4-7 from R, which keeps L and R apart.
// * Each feedback loop one sample longer than zita-rev1's.
// * HF damping above 0.49 x the sample rate wrapped around (cos of an angle past
//   Nyquist); zita-rev1 treats it as Nyquist (no extra HF damping).
// * Fixed output gain 0.37; zita-rev1 scales the reverb by 1/sqrt(mid RT60), so
//   longer decays don't get louder.
// The EQ and the dry/wet law are zita-rev1's, as in dm.zita_rev1.

import("stdfaust.lib");

//============================ UI ======================================
// Every control has an explicit [n] index so the UGen argument order is fixed.
// Ranges and defaults are zita-rev1's (and dm.zita_rev1's), except `level`
// (default 0 dB here) and `mix`, which is zita-rev1's Wet/Dry Mix rescaled to
// 0 = dry .. 1 = wet (zita-rev1's -1 = wet .. +1 = dry; same law, see below).
//
// `mix` and `level` are smoothed (they are plain gains). The reverb and EQ
// controls are not: smoothing them would recompute the filter coefficients of
// 8 delay lanes every sample. They change once per block, which is fine for
// the decay and EQ controls; a change of `delay` jumps the pre-delay and can click.
smooth0(x) = f ~ _
with { c = 1 - 44.1/ma.SR; f(y) = ba.if(ba.time == 0, x, c*y + (1 - c)*x); };

rdel   = hslider("[00]delay",    40,   20,   100,  1);      // ms before the reverb begins
f1     = hslider("[01]lfX",      200,  50,   1000, 1);      // Hz, low/mid crossover
t60dc  = hslider("[02]lowRT",    3,    1,    8,    0.01);   // s, low-band RT60
t60m   = hslider("[03]midRT",    2,    1,    8,    0.01);   // s, mid-band RT60
f2     = hslider("[04]hfDamp",   6000, 1500, 23520, 1);     // Hz where the HF RT60 is half the mid RT60
eq1f   = hslider("[05]eq1Freq",  160,  40,   2500, 1);      // Hz
eq1l   = hslider("[06]eq1Level", 0,    -15,  15,   0.1);    // dB
eq2f   = hslider("[07]eq2Freq",  2500, 160,  10000, 1);     // Hz
eq2l   = hslider("[08]eq2Level", 0,    -15,  15,   0.1);    // dB
mix    = hslider("[09]mix",      0.5,  0,    1,    0.01) : smooth0;              // 0 = dry, 1 = wet
gain   = hslider("[10]level",    0,    -70,  40,   0.1) : smooth0 : ba.db2linear; // dB

fsmax = 48000.0;   // highest sample rate supported (sizes the delay lines)

//====================== Reverb (current reverbs.lib) ===================
zita_rev_fdn(f1,f2,t60dc,t60m,fsmax) =
  ((si.bus(2*N) :> allpass_combs(N) : feedbackmatrix(N)) ~
   (delayfilters(N,freqs,durs) : fbdelaylines(N)))
with {
  N = 8;

  // Delay-line lengths in seconds:
  apdelays = (0.020346, 0.024421, 0.031604, 0.027333, 0.022904,
              0.029291, 0.013458, 0.019123); // feedforward delays in seconds
  tdelays = (0.153129, 0.210389, 0.127837, 0.256891, 0.174713,
             0.192303, 0.125000, 0.219991); // total delays in seconds
  tdelay(i) = floor(0.5 + ma.SR*ba.take(i+1,tdelays)); // samples
  apdelay(i) = floor(0.5 + ma.SR*ba.take(i+1,apdelays));
  fbdelay(i) = tdelay(i) - apdelay(i);
  // Since SR is not bounded at compile time, fsmax sizes the delay lines:
  tdelaymaxfs(i) = floor(0.5 + fsmax*ba.take(i+1,tdelays));
  apdelaymaxfs(i) = floor(0.5 + fsmax*ba.take(i+1,apdelays));
  fbdelaymaxfs(i) = tdelaymaxfs(i) - apdelaymaxfs(i);
  nextpow2(x) = ceil(log(x)/log(2.0));
  maxapdelay(i) = int(2.0^max(1.0,nextpow2(apdelaymaxfs(i))));
  maxfbdelay(i) = int(2.0^max(1.0,nextpow2(fbdelaymaxfs(i))));

  apcoeff(i) = select2(i&1,0.6,-0.6);  // allpass comb-filter coefficient
  allpass_combs(N) =
    par(i,N,(fi.allpass_comb(maxapdelay(i),apdelay(i),apcoeff(i))));
  // The ~ feedback adds one sample: each loop is tdelay(i) samples, as in zita-rev1
  fbdelaylines(N) = par(i,N,(de.delay(maxfbdelay(i),(fbdelay(i)-1))));
  freqs = (f1,f2); durs = (t60dc,t60m);
  delayfilters(N,freqs,durs) = par(i,N,filter(i,freqs,durs));
  feedbackmatrix(N) = ro.hadamard(N);

  staynormal = 10.0^(-20); // let signals decay well below LSB, but not to zero

  special_lowpass(g,f) = si.smooth(p) with {
    // unity-dc-gain lowpass needs gain g at frequency f => quadratic formula:
    p = mbo2 - sqrt(max(0,mbo2*mbo2 - 1.0)); // other solution is unstable
    mbo2 = (1.0 - gs*c)/(1.0 - gs); // NOTE: must ensure |g|<1 (t60m finite)
    gs = g*g;
    // zita-rev1 (reverb.cc, Reverb::prepare) puts f above 0.49 SR at Nyquist:
    c = select2(f > 0.49*ma.SR, cos(2.0*ma.PI*f/float(ma.SR)), -1.0);
  };

  filter(i,freqs,durs) = lowshelf_lowpass(i)/sqrt(float(N))+staynormal
  with {
    lowshelf_lowpass(i) = gM*low_shelf1_l(g0/gM,f(1)):special_lowpass(gM,f(2));
    low_shelf1_l(G0,fx,x) = x + (G0-1)*fi.lowpass(1,fx,x);
    g0 = g(0,i);
    gM = g(1,i);
    f(k) = ba.take(k,freqs);
    dur(j) = ba.take(j+1,durs);
    n60(j) = dur(j)*ma.SR; // decay time in samples
    g(j,i) = exp(-3.0*log(10.0)*tdelay(i)/n60(j));
  };
};

// Input delay: rdel ms (rounded to the nearest sample), scaled by 0.3.
zita_in_delay(rdel) = zita_delay_mono(rdel), zita_delay_mono(rdel) with {
  zita_delay_mono(rdel) = de.delay(32768,floor(0.5+ma.SR*rdel*0.001)) * 0.3; // 100 ms at 192 kHz is 19200 samples
};

// Lanes 0-3 from L as +,+,-,- and lanes 4-7 from R as +,+,-,-, as in zita-rev1.
zita_distrib2(N) = par(c, 2, _ <: si.bus(N/4), par(j, N/4, *(-1)));

// Reverb only (no dry). The input delay is rdel - 20 ms, so the first echoes of
// the diffusion allpasses (13 to 32 ms) arrive about rdel ms after the input.
zita_rev1_stereo(rdel,f1,f2,t60dc,t60m,fsmax) =
   zita_in_delay(rdel - 20)
 : zita_distrib2(N)
 : zita_rev_fdn(f1,f2,t60dc,t60m,fsmax)
 : output2(N)
with {
 N = 8;
 output2(N) = outmix(N) : *(t1),*(t1);
 // zita-rev1: 0.7*m*(2-m)/sqrt(rtmid), here at its default mix m = 0.5
 t1 = 0.525/sqrt(t60m);
 outmix(4) = !,ro.butterfly(2),!; // x1+x2, x1-x2, as in zita-rev1
 outmix(N) = outmix(N/2),par(i,N/2,!);
};

//====================== EQ, mix and level (as dm.zita_rev1) ============
// Regalia-Mitra peaking EQ with its bandwidth tied to the gain, as in zita-rev1.
pareq_stereo(eqf,eql) = fi.peak_eq_rm(eql,eqf,tpbt), fi.peak_eq_rm(eql,eqf,tpbt)
with {
  tpbt = wcT/sqrt(max(0,g)); // tan(PI*B/SR), B bw in Hz (Q^2 ~ g/4)
  wcT = 2*ma.PI*eqf/ma.SR;   // peak frequency in rad/sample
  g = ba.db2linear(eql);     // peak gain
};
out_eq = pareq_stereo(eq1f,eq1l) : pareq_stereo(eq2f,eq2l);

// zita-rev1's mix law (reverb.cc) with m = mix: dry gain 1 - m^2, wet gain
// 0.7 m (2-m)/sqrt(t60m), of which zita_rev1_stereo applies 0.525/sqrt(t60m).
// m = 0.5 is zita-rev1's default (dry 0.75, wet 0.525/sqrt(t60m)).
dry_wet(dl,dr,wl,wr) = dl*gd + wl*gw, dr*gd + wr*gw
with {
  gd = (1.0 - mix)*(1.0 + mix);
  gw = mix*(2.0 - mix)/0.75;
};

//====================== Process ========================================
process(l, r) = dry_wet(l, r, wl, wr) : *(gain), *(gain)
with {
  w  = (l, r) : zita_rev1_stereo(rdel,f1,f2,t60dc,t60m,fsmax) : out_eq;
  wl = w : _, !;
  wr = w : !, _;
};