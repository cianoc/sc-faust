SpringReverb : UGen
{
  *ar { | in1, blend(0.3), dwell(0.3), springs(0.0), tension(0.3), tone(0.3) |
      ^this.multiNew('audio', in1, blend, dwell, springs, tension, tone)
  }

  *kr { | in1, blend(0.3), dwell(0.3), springs(0.0), tension(0.3), tone(0.3) |
      ^this.multiNew('control', in1, blend, dwell, springs, tension, tone)
  } 

  checkInputs {
    if (rate == 'audio', {
      1.do({|i|
        if (inputs.at(i).rate != 'audio', {
          ^(" input at index " + i + "(" + inputs.at(i) + 
            ") is not audio rate");
        });
      });
    });
    ^this.checkValidInputs
  }

  name { ^"SpringReverb" }


  info { ^"Generated with Faust" }
}

