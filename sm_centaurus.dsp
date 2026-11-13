// The UGen is SMCentaurus. Short name: scsynth rejects UGen names of 32+ characters.
declare name "SMCentaurus";
declare description "Centaurus: four serial four-channel matrix allpasses. A model of Valhalla DSP's free ValhallaSupermassive (mode 2); not affiliated with Valhalla DSP";

// Build for SuperCollider with build_sc.sh (keep valhalla_ugen.lib and
// valhalla_sm_270.lib in the same folder as this file):
//     ./build_sc.sh sm_centaurus.dsp
// Controls, memory and notes: see valhalla_ugen.lib.

vu = library("valhalla_ugen.lib");
process = vu.ugen(2);
