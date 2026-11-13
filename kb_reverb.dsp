import("stdfaust.lib");

rt = vslider("[00]rt", 0.3, 0.0, 1.0, 0);
damp = vslider("[01]damp", 0.3, 0.0, 1.0, 0);

process =  re.kb_rom_rev1(rt, damp);
