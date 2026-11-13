SMGemini : MultiOutUGen
{
  *ar { | in1, in2, mix(0.5), delay(200.0), warp(0.3), feedback(0.6), density(0.3), width(1.0), lowcut(10.0), highcut(20000.0), modrate(0.5), moddepth(0.2) |
      ^this.multiNew('audio', in1, in2, mix, delay, warp, feedback, density, width, lowcut, highcut, modrate, moddepth)
  }

  *kr { | in1, in2, mix(0.5), delay(200.0), warp(0.3), feedback(0.6), density(0.3), width(1.0), lowcut(10.0), highcut(20000.0), modrate(0.5), moddepth(0.2) |
      ^this.multiNew('control', in1, in2, mix, delay, warp, feedback, density, width, lowcut, highcut, modrate, moddepth)
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

  name { ^"SMGemini" }


  info { ^"Generated with Faust" }
}

