Expander : MultiOutUGen
{
  *ar { | in1, in2, in3, in4, type(0.0), ratio(1.0), thresh(-40.0), range(40.0), att(1.0), hold(0.0), rel(100.0), knee(6.0), post(0.0), link(1.0) |
      ^this.multiNew('audio', in1, in2, in3, in4, type, ratio, thresh, range, att, hold, rel, knee, post, link)
  }

  *kr { | in1, in2, in3, in4, type(0.0), ratio(1.0), thresh(-40.0), range(40.0), att(1.0), hold(0.0), rel(100.0), knee(6.0), post(0.0), link(1.0) |
      ^this.multiNew('control', in1, in2, in3, in4, type, ratio, thresh, range, att, hold, rel, knee, post, link)
  } 

  checkInputs {
    if (rate == 'audio', {
      4.do({|i|
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

  name { ^"Expander" }


  info { ^"Generated with Faust" }
}

