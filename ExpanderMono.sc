ExpanderMono : UGen
{
  *ar { | in1, in2, type(0.0), ratio(1.0), thresh(-40.0), range(40.0), att(1.0), hold(0.0), rel(100.0), knee(6.0), post(0.0) |
      ^this.multiNew('audio', in1, in2, type, ratio, thresh, range, att, hold, rel, knee, post)
  }

  *kr { | in1, in2, type(0.0), ratio(1.0), thresh(-40.0), range(40.0), att(1.0), hold(0.0), rel(100.0), knee(6.0), post(0.0) |
      ^this.multiNew('control', in1, in2, type, ratio, thresh, range, att, hold, rel, knee, post)
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

  name { ^"ExpanderMono" }


  info { ^"Generated with Faust" }
}

