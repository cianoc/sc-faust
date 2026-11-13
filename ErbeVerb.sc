ErbeVerb : MultiOutUGen
{
  *ar { | in1, in2, mix(0.5), size(0.5), decay(0.6), absorb(0.5), tilt(0.5), predelay(0.05), argotic(0.0), modrate(1.0), moddepth(0.2) |
      ^this.multiNew('audio', in1, in2, mix, size, decay, absorb, tilt, predelay, argotic, modrate, moddepth)
  }

  *kr { | in1, in2, mix(0.5), size(0.5), decay(0.6), absorb(0.5), tilt(0.5), predelay(0.05), argotic(0.0), modrate(1.0), moddepth(0.2) |
      ^this.multiNew('control', in1, in2, mix, size, decay, absorb, tilt, predelay, argotic, modrate, moddepth)
  } 

  checkInputs {
    if (rate == 'audio', {
      2.do({|i|
        if (inputs.at(i).rate != 'audio', {
          ^(" input at index " + i + "(" + inputs.at(i) + 
            ") is not audio rate");
        });
      });
    });
    ^this.checkValidInputs
  }

  init { | ... theInputs |
      inputs = theInputs
      ^this.initOutputs(2, rate)
  }

  name { ^"ErbeVerb" }


  info { ^"Generated with Faust" }
}

