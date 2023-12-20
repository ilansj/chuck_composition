//PLUCKS
fun void plucks(dur myDur, int intensity) {
    SawOsc s => ResonZ f => ADSR env => NRev r => Chorus c => Dyno comp => Pan2 p => dac;

    //compressor settings
    1::ms => comp.attackTime;
    500::ms => comp.releaseTime;
    0.08 => comp.thresh;
    10 => comp.ratio;

    0.02 => r.mix;
    3 => c.modFreq;
    0.001 + 0.005*intensity => c.modDepth;
    0.8 => c.mix;
    // set filter cutoff and q
    2000 => f.freq;
    1 => f.Q;
    // set envelope
    env.set(1::ms, 60::ms, 0, 1::ms);
    // set note length
    120::ms => dur T;
    // spawn a parallel shred controlling the filter and panning of each note
    spork ~ filter_and_pan(f, T, p, intensity);
    //taking care of duration
    now => time myBeg;
    myBeg + myDur => time myEnd;

    //creating arrays for the two chords I want to arpeggiate
    [60, 64, 67, 71, 74, 78] @=> int cMaj11[];
    [62, 66, 69, 73, 76, 83] @=> int dMaj9[];

    //variables for notes
    int note;
    float velo;
    while (now < myEnd) {
        for(int i; i < 32; i++) {
            Math.random2(0, 5) => note;
            Math.random2f(3.0, 4.0)*0.1 => velo;
            play(s, env, cMaj11[note], velo, T, 1);
        }
        for(int i; i < 32; i++) {
            Math.random2(0, 5) => note;
            Math.random2f(3.0, 4.0)*0.1 => velo;
            play(s, env, dMaj9[note], velo, T, 1);
        }
    }
}
// filter and pan function for plucks
fun void filter_and_pan(ResonZ f, dur T, Pan2 p, int intensity) {
    TriOsc lfo => blackhole;
    T => lfo.period;
    int i;
    while (true) {
        0 => i;
        Math.random2f(10, intensity*150) => float c;
        Math.random2f(-0.7, 0.7) => p.pan;
        while (i < 120) {
            (lfo.last() - 1)/(-2)*c + c/2 => f.freq;
            1::ms => now;
            i++;
        }
    }
}
// play function for all saw instruments
fun void play(SawOsc s, ADSR env, float pitch, float velocity, dur T, int MIDI) {
    // set pitch based on whether or not its a MIDI input or a freq input
    if (MIDI == 1) {
        pitch => Std.mtof => s.freq;
    } else {
        pitch => s.freq;
    }
    // set velocity (really just changing gain here)
    velocity => s.gain;
    // open envelope (start attack)
    env.keyOn();
    // wait through A+D+S, before R
    T-env.releaseTime() => now;
    // close envelope (start release)
    env.keyOff();
    // wait for release
    env.releaseTime() => now;
}

fun void pad(dur myDur, float pitch, float pan, float gain, int intensity) {
    SawOsc s => ResonZ f => ADSR env => NRev r => Dyno comp => Pan2 p =>  dac;

    //slammed compressor settings (essentially a limiter)
    1::ms => comp.attackTime;
    500::ms => comp.releaseTime;
    0.03 => comp.thresh;
    10 => comp.ratio;

    pan => p.pan;
    0.3 => r.mix;
    1 => f.Q;
    env.set(800::ms, 2::second, 0.5, 500::ms);
    3.84::second => dur T;

    //spawn lfo shred
    spork ~update_filter(f, intensity);

    now => time myBeg;
    myBeg + myDur => time myEnd;
    while (now < myEnd) {
        play(s, env, pitch, gain, T, 0);
    }
}

fun void update_filter(ResonZ f, int intensity) {
    SinOsc lfo => blackhole;
    (1/intensity)::second => lfo.period;
    while (true) {
    //lfo controlling part of the filter
        ((lfo.last() - 1)/(-2))*20*intensity + 100 => f.freq;
        20::ms => now;
    }
}

fun void chord1(int intensity) {
    [48, 64, 71] @=> int cMaj7[];
    //iterating through the array of chord tones
    for (int i; i < 3; i++) {
        spork ~pad(3.84::second, Std.mtof(cMaj7[i]), 0, 0.06, intensity);
        //detuning and panning duplicates of the same note
        spork ~pad(3.84::second, Std.mtof(cMaj7[i]) + 0.8, 0.5, 0.03, intensity);
        spork ~pad(3.84::second, Std.mtof(cMaj7[i]) - 0.8, -0.5, 0.03, intensity);
    }
}

fun void chord2(int intensity) {
    [50, 66, 73] @=> int dMaj7[];
    //iterating through the array of chord tones
    for (int i; i < 3; i++) {
        spork ~pad(3.84::second, Std.mtof(dMaj7[i]), 0, 0.06, intensity);
        //detuning and panning duplicates of the same note
        spork ~pad(3.84::second, Std.mtof(dMaj7[i]) + 0.8, 0.5, 0.03, intensity);
        spork ~pad(3.84::second, Std.mtof(dMaj7[i]) - 0.8, -0.5, 0.03, intensity);
    }
}

fun void moog_bass(dur T, float pitch, float gain) {
    Moog m => ADSR e => LPF f => dac;
    e.set(1.5::second, 3000::ms, 0, 500::ms);
    100 => f.freq;

    //moog settings
    0.05 => m.filterSweepRate;
    0.8 => m.filterQ;
    0 => m.vibratoFreq;
    0 => m.vibratoGain;

    //convert form MIDI to frequency
    pitch => Std.mtof => m.freq;
    gain => m.gain;
    1 => m.afterTouch;

    //moog requires the note on function along with key on
    m.noteOn(1);
    e.keyOn();
    T/2 => now;
    0.5 => m.afterTouch;
    T/2 => now;
    m.noteOff(1);
    e.keyOff();
}

fun void hihat() {
    //assign 16th note to a variable for easier use
    120::ms => dur s;
    Noise n => ADSR e => HPF h => NRev r => dac;
    0.01 => r.mix;
    2000 => h.freq;
    //for loop with hihat pattern using random function to determine note velocity
    for (int i; i < 2; i++) {
        e.set(1::ms, 20::ms, 0, 0::ms);
        for (int j; j < 7; j++) {
            s => now;
            play_hat(n, e, Math.random2f(0,0.5), s);
            play_hat(n, e, Math.random2f(0.4,0.8), s);
            play_hat(n, e, Math.random2f(0,0.5), s);
        }
        s => now;
        play_hat(n, e, Math.random2f(0,0.5), s);
        play_hat(n, e, Math.random2f(0.4,0.8), s);
        e.set(1::ms, 20::ms, 1, 0::ms);
        play_hat(n, e, Math.random2f(0.3,0.6), s);
    }
}

//function that plays hihat
fun void play_hat(Noise n, ADSR env, float velocity, dur T) {
    velocity*0.03 => n.gain;
    env.keyOn();
    T-env.releaseTime() => now;
    env.keyOff();
    env.releaseTime() => now;
}

fun void kick() {
    //set 8th note to a variable
    240::ms => dur T;
    SinOsc kick => ADSR e => LPF f => dac;
    0.2 => kick.gain;
    500 => f.freq;
    e.set(1::ms, 80::ms, 0, 0::ms);

    //spawn pitch envelope shred
    spork ~pitch_envelope(kick, T, 200);

    //loop pattern with a for loop
    for (int i; i < 4; i++) {
        e.keyOn();
        T => now;
        e.keyOff();
        T*4 => now;
        e.keyOn();
        T => now;
        e.keyOff();
        T*2 => now;
    }
}

fun void pitch_envelope(SinOsc s, dur T, float pitch) {
    SinOsc lfo => blackhole;
    //make the lfo period longer than the duration so that the pitch is only going down during the kick sound
    T => lfo.period;
    int i;
    while (true) {
        ((lfo.last() - 1)/(-2))*pitch + 50 => s.freq;
        1::samp => now;
    }
}

fun void snare() {
    60::ms => dur T;
    Noise snare => ADSR e => LPF f => PRCRev r => LPF snareEQ => dac;
    8000 => snareEQ.freq;
    0.01 => r.mix;

    //higher Q to make more a resonant sound
    2 => f.Q;
    e.set(4::ms, 18::ms, 0, 0::ms);

    //spawn filter envelope shred
    spork ~snare_filter_envelope(snare, T, f);

    //for loop playing snares
    for (int i; i < 2; i++) {
        T*2 => now;
        //0 in the last parameter means it is always played, 1 means it is sometimes played
        play_snare(snare, e, 1, 5, T, 1);
        play_snare(snare, e, 1, 7, T, 0);

        T*2 => now;
        play_snare(snare, e, 1, 5, T, 1);
        play_snare(snare, e, 1, 5, T, 0);
        play_snare(snare, e, 1, 1, T, 1);

        T*2 => now;
        play_snare(snare, e, 1, 5, T, 1);
        play_snare(snare, e, 1, 7, T, 0);

        T*2 => now;
        play_snare(snare, e, 1, 5, T, 1);
        play_snare(snare, e, 1, 5, T, 0);
        play_snare(snare, e, 1, 1, T, 1);
    }
}

fun void play_snare (Noise snare, ADSR e, float gain, int beats, dur T, int randomize) {
    //adds more noise to create the 'buzz' of the snare
    Noise buzz => ADSR buzz_env => HPF buzz_h => LPF buzz_l => dac;
    buzz_env.set(2::ms, 100::ms, 0, 0::ms);
    6000 => buzz_h.freq;
    600 => buzz_l.freq;

    //senses if the note should be played for certain or randomized
    if (randomize == 1) {
        //random within a random to decrease odds of a 1 but maintain the two results
        Math.random2(0,Math.random2(0,1)) => int r;
        r*0.25 => snare.gain;
        r*0.5 => buzz.gain;
    } else {
        0.25 => snare.gain;
        0.5 => buzz.gain;
    }
    buzz_env.keyOn();
    e.keyOn();
    T => now;
    buzz_env.keyOff();
    e.keyOff();
    T*beats => now;
}

fun void snare_filter_envelope(Noise n, dur T, LPF f) {
    SinOsc lfo => blackhole;
    T => lfo.period;
    int i;
    while (true) {
        ((lfo.last() - 1)/(-2))*4000 + 500 => f.freq;
        1::samp => now;
    }
}

fun void laser() {
    SinOsc laser => ADSR e => Echo d => PRCRev r => dac;

    d => d;
    0.005 => laser.gain;
    0.1 => d.mix;
    0.1 => r.mix;

    e.set(20::ms, Math.random2(30, 400)::ms, 0, 0::ms);
 
    spork ~laser_pitch_envelope(laser);

    e.keyOn();
    10::second => now;
}

fun void laser_pitch_envelope(SinOsc s) {
    SinOsc lfo => blackhole;
    200::ms => lfo.period;
    while (true) {
        ((lfo.last() - 1)/(-2))*10000 + 500 => s.freq;
        1::ms => now;
    }
}

fun void bells() {
    //using a bell from the FM libary in Chuck
    BeeThree b => ADSR e => Echo d => PRCRev r => LPF f => dac;
    8000 => f.freq;
    0.1 => d.mix;
    //dotted 8th note delay with feedback
    360::ms => d.delay;
    d => Gain feedback => d;
    0.8 => feedback.gain;

    0.2 => r.mix;
    0.018 => b.gain;
    e.set(10::ms, 200::ms, 0, 0::ms);
    [62, 66, 69, 71, 74, 78, 81, 83] @=> int melody[];

    for (int i; i < 6; i++) {
        melody[Math.random2(0,7)] => Std.mtof => b.freq;
        b.noteOn(1);
        e.keyOn();
        //repeating every 6 beats
        5.76::second => now;
    }
    //more time to allow delay to ring out without a harsh click
    10::second => now;
}

fun void constant_texture(dur myDur) {
    Impulse i => ResonZ f => PRCRev r => Pan2 p => dac;

    0.01 => r.mix;
    10 => f.Q;

    now => time myBeg;
    myBeg + myDur => time myEnd;

    while(now < myEnd) {
        Math.random2f(2000, 5000)=> f.freq;
        Math.random2f(-1, 1) => p.pan;
        //gain values are the inputs for next
        Math.random2f(0.2, 0.5) => i.next;
        //randomize time between impulses
        Math.random2f(30, 200)::ms => now;
    }
}

//ADD THIS CODE TO RECORD THE COMPOSITION TO A FILE
// dac => WvOut out => blackhole;
// me.sourceDir() + "filename" => string _capture;
// _capture => out.wavFilename;

//PLAY SONG
spork ~constant_texture(76::second);
spork ~plucks(7.68::second, 1);
chord1(1);
//keep time running in the background
3.84::second => now;
chord2(1);
3.84::second => now;
spork ~hihat();
spork ~plucks(7.68::second, 1);
chord1(1);
3.84::second => now;
chord2(1);
3.84::second => now;

spork ~snare();
spork ~kick();
spork ~hihat();
spork ~plucks(7.68::second, 2);
chord1(2);
3.84::second => now;
chord2(3);
3.84::second => now;
spork ~snare();
spork ~kick();
spork ~hihat();
spork ~plucks(7.68::second, 2);
chord1(4);
3.84::second => now;
chord2(5);
3.84::second => now;

spork ~snare();
spork ~kick();
spork ~hihat();
spork ~plucks(7.68::second, 3);
spork ~moog_bass(3.84::second, 24, 0.2);
chord1(6);
3.84::second => now;
spork ~moog_bass(3.84::second, 26, 0.2);
chord2(7);
3.84::second => now;
spork ~snare();
spork ~kick();
spork ~hihat();
spork ~plucks(7.68::second, 3);
spork ~moog_bass(3.84::second, 24, 0.2);
chord1(8);
3.84::second => now;
spork ~moog_bass(3.84::second, 26, 0.2);
chord2(9);
3.72::second => now;
spork ~laser();
0.12::second => now;

spork ~bells();

spork ~snare();
spork ~kick();
spork ~hihat();
spork ~plucks(7.68::second, 4);
spork ~moog_bass(3.84::second, 24, 0.15);
3.84::second => now;
spork ~moog_bass(3.84::second, 26, 0.15);
3.84::second => now;
spork ~snare();
spork ~kick();
spork ~hihat();
spork ~plucks(7.68::second, 4);
spork ~moog_bass(3.84::second, 24, 0.15);
3.84::second => now;
spork ~moog_bass(3.84::second, 26, 0.15);
3.84::second => now;

spork ~laser();
spork ~plucks(7.68::second, 3);
chord1(1);
3.84::second => now;
chord2(1);
3.84::second => now;
spork ~snare();
spork ~kick();
spork ~hihat();
spork ~plucks(7.68::second, 3);
spork ~moog_bass(3.84::second, 24, 0.15);
chord1(1);
3.84::second => now;
spork ~moog_bass(3.84::second, 26, 0.15);
chord2(1);
3.84::second => now;
spork ~laser();
//time at the end to let delays and reverbs ring out
10::second => now;