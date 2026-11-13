// The UGen is SMLyra. Short name: scsynth rejects UGen names of 32+ characters.
declare name "SMLyra";
declare description "Lyra: four modulated delays with a four-channel scattering matrix. A model of Valhalla DSP's free ValhallaSupermassive (mode 6); not affiliated with Valhalla DSP";

// Build for SuperCollider with build_sc.sh (keep valhalla_ugen.lib and
// valhalla_sm_270.lib in the same folder as this file):
//     ./build_sc.sh sm_lyra.dsp
// Controls, memory and notes: see valhalla_ugen.lib.

vu = library("valhalla_ugen.lib");
process = vu.ugen(6);
