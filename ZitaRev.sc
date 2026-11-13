ZitaRev : MultiOutUGen
{
  *ar { | in1, in2, delay(40.0), lfx(200.0), lowrt(3.0), midrt(2.0), hfdamp(6000.0), eq1freq(160.0), eq1level(0.0), eq2freq(2500.0), eq2level(0.0), mix(0.5), level(0.0) |
      ^this.multiNew('audio', in1, in2, delay, lfx, lowrt, midrt, hfdamp, eq1freq, eq1level, eq2freq, eq2level, mix, level)
  }

  *kr { | in1, in2, delay(40.0), lfx(200.0), lowrt(3.0), midrt(2.0), hfdamp(6000.0), eq1freq(160.0), eq1level(0.0), eq2freq(2500.0), eq2level(0.0), mix(0.5), level(0.0) |
      ^this.multiNew('control', in1, in2, delay, lfx, lowrt, midrt, hfdamp, eq1freq, eq1level, eq2freq, eq2level, mix, level)
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

  name { ^"ZitaRev" }


  info { ^"Generated with Faust" }
}

