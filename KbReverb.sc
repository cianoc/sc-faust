KbReverb : MultiOutUGen
{
  *ar { | in1, in2, rt(0.3), damp(0.3) |
      ^this.multiNew('audio', in1, in2, rt, damp)
  }

  *kr { | in1, in2, rt(0.3), damp(0.3) |
      ^this.multiNew('control', in1, in2, rt, damp)
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

  name { ^"KbReverb" }


  info { ^"Generated with Faust" }
}

