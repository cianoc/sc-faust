VitalReverb : MultiOutUGen
{
  *ar { | in1, in2, pre_low(0.3), pre_high(0.3), low_cut(0.3), hi_cut(0.3), low_gain(0.3), hi_gain(0.3), chorus_amt(0.3), chorus_freq(0.3), pre_delay(0.3), time(0.3), size(0.3), wet(0.3) |
      ^this.multiNew('audio', in1, in2, pre_low, pre_high, low_cut, hi_cut, low_gain, hi_gain, chorus_amt, chorus_freq, pre_delay, time, size, wet)
  }

  *kr { | in1, in2, pre_low(0.3), pre_high(0.3), low_cut(0.3), hi_cut(0.3), low_gain(0.3), hi_gain(0.3), chorus_amt(0.3), chorus_freq(0.3), pre_delay(0.3), time(0.3), size(0.3), wet(0.3) |
      ^this.multiNew('control', in1, in2, pre_low, pre_high, low_cut, hi_cut, low_gain, hi_gain, chorus_amt, chorus_freq, pre_delay, time, size, wet)
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

  name { ^"VitalReverb" }


  info { ^"Generated with Faust" }
}

