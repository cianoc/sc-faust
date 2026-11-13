// The UGen is SMAnnihilator. Short name: scsynth rejects UGen names of 32+ characters.
declare name "SMAnnihilator";
declare description "Great Annihilator: a plain four-channel stage and three matrix allpasses inside a global feedback loop (can sustain at feedback 1, like the plug-in). A model of Valhalla DSP's free ValhallaSupermassive (mode 4); not affiliated with Valhalla DSP";

// Build for SuperCollider with build_sc.sh (keep valhalla_ugen.lib and
// valhalla_sm_270.lib in the same folder as this file):
//     ./build_sc.sh sm_annihilator.dsp
// Controls, memory and notes: see valhalla_ugen.lib.

vu = library("valhalla_ugen.lib");
process = vu.ugen(4);
