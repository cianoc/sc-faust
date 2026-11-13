// The UGen is SMGemini. Short name: scsynth rejects UGen names of 32+ characters.
declare name "SMGemini";
declare description "Gemini: sixteen modulated delays, scattered by a butterfly of rotations. A model of Valhalla DSP's free ValhallaSupermassive (mode 0); not affiliated with Valhalla DSP";

// Build for SuperCollider with build_sc.sh (keep valhalla_ugen.lib and
// valhalla_sm_270.lib in the same folder as this file):
//     ./build_sc.sh sm_gemini.dsp
// Controls, memory and notes: see valhalla_ugen.lib.

vu = library("valhalla_ugen.lib");
process = vu.ugen(0);
