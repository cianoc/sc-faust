import("stdfaust.lib");

pre_low     = vslider("[00]pre-low",     0.3, 0.0, 1.0, 0);
pre_high    = vslider("[01]pre-high",    0.3, 0.0, 1.0, 0);
low_cut     = vslider("[02]low-cut",     0.3, 0.0, 1.0, 0);
hi_cut      = vslider("[03]hi-cut",      0.3, 0.0, 1.0, 0);
low_gain    = vslider("[04]low-gain",    0.3, 0.0, 1.0, 0);
hi_gain     = vslider("[05]hi-gain",     0.3, 0.0, 1.0, 0);
chorus_amt  = vslider("[06]chorus_amt",  0.3, 0.0, 1.0, 0);
chorus_freq = vslider("[07]chorus_freq", 0.3, 0.0, 1.0, 0);
pre_delay   = vslider("[08]pre-delay",   0.3, 0.0, 1.0, 0);
time        = vslider("[09]time",        0.3, 0.0, 1.0, 0);
size        = vslider("[10]size",        0.3, 0.0, 1.0, 0);
wet         = vslider("[11]wet",         0.3, 0.0, 1.0, 0);

process = re.vital_rev(pre_low, pre_high, low_cut, hi_cut, low_gain, hi_gain,
                       chorus_amt, chorus_freq, pre_delay, time, size, wet);