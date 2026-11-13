import("stdfaust.lib");

dwell = vslider("dwell", 0.3, 0.0, 1.0, 0);
blend = vslider("blend", 0.3, 0.0, 1.0, 0);
tone = vslider("tone", 0.3, 0.0, 1.0, 0);
tension = vslider("tension", 0.3, 0.0, 1.0, 0);
springs = nentry("springs", 0, 0, 2, 1);

process(in) =  in : re.springreverb(dwell, blend, tone, tension, springs);

