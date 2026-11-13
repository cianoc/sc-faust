CompRMSFBLimMono : UGen
{
  *ar { | in1, ratio(1.0), thresh(-20.0), limit(-1.0), limrel(50.0), att(5.0), rel(100.0), knee(6.0), autogain(0.0), mode(1.0), time(2.0), gate(-50.0), max_makeup(24.0) |
      ^this.multiNew('audio', in1, ratio, thresh, limit, limrel, att, rel, knee, autogain, mode, time, gate, max_makeup)
  }

  *kr { | in1, ratio(1.0), thresh(-20.0), limit(-1.0), limrel(50.0), att(5.0), rel(100.0), knee(6.0), autogain(0.0), mode(1.0), time(2.0), gate(-50.0), max_makeup(24.0) |
      ^this.multiNew('control', in1, ratio, thresh, limit, limrel, att, rel, knee, autogain, mode, time, gate, max_makeup)
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

  name { ^"CompRMSFBLimMono" }


  info { ^"Generated with Faust" }
}

