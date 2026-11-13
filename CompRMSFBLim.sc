CompRMSFBLim : MultiOutUGen
{
  *ar { | in1, in2, ratio(1.0), thresh(-20.0), limit(-1.0), limrel(50.0), att(5.0), rel(100.0), knee(6.0), link(1.0), autogain(0.0), mode(1.0), time(2.0), gate(-50.0), max_makeup(24.0) |
      ^this.multiNew('audio', in1, in2, ratio, thresh, limit, limrel, att, rel, knee, link, autogain, mode, time, gate, max_makeup)
  }

  *kr { | in1, in2, ratio(1.0), thresh(-20.0), limit(-1.0), limrel(50.0), att(5.0), rel(100.0), knee(6.0), link(1.0), autogain(0.0), mode(1.0), time(2.0), gate(-50.0), max_makeup(24.0) |
      ^this.multiNew('control', in1, in2, ratio, thresh, limit, limrel, att, rel, knee, link, autogain, mode, time, gate, max_makeup)
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

  name { ^"CompRMSFBLim" }


  info { ^"Generated with Faust" }
}

