OTT : MultiOutUGen
{
  *ar { | in1, in2, depth(1.0), time(1.0), ingain(0.0), outgain(0.0), upward(1.0), downward(1.0), threshl(1.0), threshm(1.0), threshh(1.0), gainl(0.0), gainm(0.0), gainh(0.0), bypupl(0.0), bypupm(0.0), bypuph(0.0), bypdnl(0.0), bypdnm(0.0), bypdnh(0.0) |
      ^this.multiNew('audio', in1, in2, depth, time, ingain, outgain, upward, downward, threshl, threshm, threshh, gainl, gainm, gainh, bypupl, bypupm, bypuph, bypdnl, bypdnm, bypdnh)
  }

  *kr { | in1, in2, depth(1.0), time(1.0), ingain(0.0), outgain(0.0), upward(1.0), downward(1.0), threshl(1.0), threshm(1.0), threshh(1.0), gainl(0.0), gainm(0.0), gainh(0.0), bypupl(0.0), bypupm(0.0), bypuph(0.0), bypdnl(0.0), bypdnm(0.0), bypdnh(0.0) |
      ^this.multiNew('control', in1, in2, depth, time, ingain, outgain, upward, downward, threshl, threshm, threshh, gainl, gainm, gainh, bypupl, bypupm, bypuph, bypdnl, bypdnm, bypdnh)
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

  name { ^"OTT" }


  info { ^"Generated with Faust" }
}

