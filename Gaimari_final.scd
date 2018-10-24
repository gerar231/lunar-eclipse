(

//////////////// DEFINE VARIABLES ////////////////

var score;
var synthDef, sgsSynthDef, rmblnSynth, fmSynthDef, fmblnSynthDef, agsSynthDef;
var noteParams, start, dur, ris, dec, gain;
var noteFreqs, noteFormFreqs, noteQs;
var noteParamsFunc, noteParamsFunc2, additiveFunc;
var numOctDivisions, numNotes;
var formData1, formData2, formData3;
var fadeIn, fadeDur, sus1, trans, sus2, ampEnv;

// helper functions
var sinCosPanLaw;

// vars for NRT output
var outputPath, headerFormat, sampleFormat, sampleRate, numOutputChannels;

// waveform analysis vars
var path, skipTime, freq, periods, window;
var introSample, harmonics;

// EllipticalFm
var ellipSynth;
var fmFreqs, blnFreqs, fmGains, blnGains;

/////////////// SET VARIABLE VALUES ///////////////

// set the NRT vars here...
outputPath = "~/Desktop/Gaimari_final.wav"; // output file path
headerFormat = "WAV";                 // soundfile header format
sampleFormat = "int24";               // soundfile sample format
sampleRate = 44100;                   // sample rate
numOutputChannels = 2;                // stereo --> 2 channels

// create a score
score = CtkScore.new;

/////////////// DEFINE SYNTH HELPER FUNCTIONS ///////////////

// sine-cosine panning law coefficient function
// angle argument in degrees
sinCosPanLaw = { arg angleInDegrees = 0;
	var angleInRadians;
	var theta;

	angleInRadians = angleInDegrees/180*pi;

	theta = pi/4 - angleInRadians;

	[theta.cos, theta.sin]
};

///////////////// DEFINE SYNTHS //////////////////


// FM Synth
fmSynthDef = CtkSynthDef.new(\myFMSynth, {arg dur, gain, ampEnv, freq = 440.0, carRatio = 1, modRatio = 1, modIndex = 1.0,  panL = 0.0, panR = 0.0;

    // variables
    var bus = 0;      // var to specify output bus: first output
    var carOsc, modOsc;  // oscillators
    var out;          // output!
    var amp;          // a few vars for synthesis
    var carFreq, modFreq;
    var modDev;
    var modEnv;       // ... for modulation envelope
	var carOscL, carOscR; // for ellipitical panning

    // initial calcs
    amp = gain.dbamp; // convert from gain in dB to linear amplitude scale
    carFreq = carRatio * freq;
    modFreq = modRatio * freq;
    modDev = modIndex * modFreq;

    // the modulation envelope
    modEnv = EnvGen.kr(
        Env.sine(1.0),
        timeScale: dur
    );

    modOsc = SinOsc.ar(modFreq, 0, modDev * modEnv);     // simple modulator (single sinusoid)
    carOsc = SinOsc.ar(carFreq + modOsc, 0, amp);        // simple carrier (single sinusoid)

    // apply the amplitude envelope

	carOscL = (ampEnv * carOsc) * panL;

	carOscR = (ampEnv * carOsc) * panR;


    // expand to two channels - panning
	out = [carOscL, carOscR];  // <-- Panning happens here!

    // out!!
    Out.ar(bus, out)
});


// FM NOISE SYNTH
fmblnSynthDef = CtkSynthDef.new(\myFMBLNSynth, {arg dur, gain, ampEnv, noiFreq = 440.0, modIndex = 1.0,  panL = 0.0, panR = 0.0;

    // variables
    var bus = 0;      // var to specify output bus: first output
    var noise, carOsc;
    var out;          // output!
    var amp;          // a few vars for synthesis
    var modDev;
	var carOscL, carOscR; // for ellipitical panning

    // initial calcs
    amp = gain.dbamp; // convert from gain in dB to linear amplitude scale
    modDev = modIndex * noiFreq;

    noise = LFNoise2.ar(noiFreq, modDev);       // (linear interpolation sample-and-hold noise)
    carOsc = SinOsc.ar(noise, 0, amp);          // simple carrier (single sinusoid)

    // apply the amplitude envelope
    carOsc = ampEnv * carOsc;

	carOscL = (ampEnv * carOsc) * panL;

	carOscR = (ampEnv * carOsc) * panR;

    // expand to two channels - panning
	out = [carOscL, carOscR];  // <-- Panning happens here!

    // out!!
    Out.ar(bus, out)
});

// Synchronous Granular Synthesis (SGS) synthDef
// NOTE: this synthDef is named sgsSynthDef
sgsSynthDef = CtkSynthDef.new(\myGrainSinSynth, {arg dur, gain, ampEnv, freq = 440.0, formFreq = 1760.0, q = 1.0,  panAngle = 0.0, fadeDur = 0.0, fadeIn = 0.0;

	// variables
	var bus = 0;      // var to specify output bus: first output
	var trigger;
	var granSig;
	var out;          // output!
	var amp;          // a few vars for synthesis
	var grainDur, grainFreq, envFreq, wavFreq;
	var crossFadeInEnv;       // var for envelope signal

	// rmbln variables
	var noise, carOsc;
	var carFreq, noiFreq;


	// initial calcs
	amp = gain.dbamp; // convert from gain in dB to linear amplitude scale
	grainFreq = freq;
	envFreq = q.reciprocal * (formFreq/2);
	wavFreq = formFreq;
	grainDur = envFreq.reciprocal;

	crossFadeInEnv = EnvGen.kr(
		Env([0,0,1,1], [fadeIn, fadeDur, 1 - fadeIn - fadeDur], \lin),
		timeScale: dur
	);

	// granular (grain frequency) trigger
	trigger = Impulse.ar(grainFreq);

	// granular synthesis
	granSig = GrainSin.ar(trigger: trigger, dur: grainDur, freq: wavFreq);

	// apply the amplitude envelope
	granSig = amp * granSig;

	// <------ RMBLN START ------>

	// rmbln calcs
	carFreq = formFreq;       // assign carrier frequency to formFreq
	noiFreq = carFreq/(2*q);  // calculate noiFreq

	noise = LFNoise2.ar(noiFreq);              // (quadratic interpolation sample-and-hold noise)
	carOsc = SinOsc.ar(carFreq);               // simple carrier (single sinusoid)

	// apply the amplitude envelope and Ring Modulate
	noise = amp * noise * carOsc;

	// <------ RMBLN END ------>


	// expand to two channels - panning
	out = sinCosPanLaw.value(panAngle) * (((granSig * (crossFadeInEnv.sqrt)) + (noise * ((1 - crossFadeInEnv).sqrt))) * ampEnv);  // <-- Panning happens here!

	// out!!
	Out.ar(bus, out)
});


agsSynthDef = CtkSynthDef.new(\myGrainSinSynth, {arg dur, gain, ampEnv, freq = 440.0, formFreq = 1760.0, q = 1.0,  panAngle = 0.0;

    // variables
    var bus = 0;      // var to specify output bus: first output
    var trigger;
    var granSig;
    var out;          // output!
    var amp;          // a few vars for synthesis
    var grainDur, grainFreq, envFreq, wavFreq;


    // initial calcs
    amp = gain.dbamp; // convert from gain in dB to linear amplitude scale
    grainFreq = freq;
    envFreq = q.reciprocal * (formFreq/2);
    wavFreq = formFreq;
    grainDur = envFreq.reciprocal;

    // the amplitude envelope nested in the UGen that synthesises the envelope

    // granular (grain frequency) trigger
    trigger = Dust.ar(grainFreq); // <-- Dust gives us an asynchronous trigger!

    // granular synthesis
    granSig = GrainSin.ar(trigger: trigger, dur: grainDur, freq: wavFreq);

    // apply the amplitude envelope
    granSig = amp * ampEnv * granSig;

    // expand to two channels - panning
    out = sinCosPanLaw.value(panAngle) * granSig;  // <-- Panning happens here!

    // out!!
    Out.ar(bus, out)
});


///////////////// CREATE SCORE POPULATING FUNCTIONS //////////////////

// note parameter function - function to parse note parameter list...
// ... calls additiveFunc to create score
noteParamsFunc = { arg mySynthDef, myParams, formData;

	// iterate through noteParams array - call additiveFunc
	myParams.do({arg params;
		additiveFunc.value(
			mySynthDef: mySynthDef,          // mySynthDef
			start: params.at(0),             // starttime
			dur: params.at(1),               // dur
			gain: params.at(2),              // gain
			ris: params.at(3),               // ris
			dec: params.at(4),               // dec
			freq: params.at(5),              // freq
			formData: formData               // formData
		);
	});
};

// note parameter function - function to parse note parameter list...
// ... calls additiveFunc to create score
noteParamsFunc2 = { arg mySynthDef, myParams, formData1, formData2, sus1, trans, sus2;

	// create envelopes from formData
	var formData = [formData1, formData1, formData2, formData2];
	var formSizes = formData.shape;
	formData = formData.lace.lace.reshape(formSizes.at(2), formSizes.at(1), formSizes.at(0)).lace.reshape(formSizes.at(1), formSizes.at(2), formSizes.at(0));

	formData.do({arg item, i;
		item.do({arg item2, j;
			formData.at(i).put(j, Env(formData.at(i).at(j), [sus1, trans, sus2], 8));
		});
	});
	// iterate through noteParams array - call additiveFunc
	myParams.do({arg params;
		additiveFunc.value(
			mySynthDef: mySynthDef,          // mySynthDef
			start: params.at(0),             // starttime
			dur: params.at(1),               // dur
			gain: params.at(2),              // gain
			ampEnv: params.at(3),
			freq: params.at(4),              // freq
			fadeDur: params.at(5),           // cross fader duration
			fadeIn: params.at(6),            // start of cross fade
			formData: formData               // formData
		);
	});
};


// mySynthDef = synthType (regular or BLN), myParams = [gain, ris, dec, freq, carRatio, modRatio, modIndex], length = length of one cycle,
// numCycles = number of consecutive cycles
// clockwise = true if clockwise false if counter clockwise ellipse panning
// gap = % of time the sound is not heard by user
// most low level params accept envelopes
ellipSynth = {arg start, mySynthDef, myParams, minV, cycleLength, numCycles, gap, clockwise;

	// create envelopes for panning
	var panL, panR;
	var outputL, outputR;
	var dur = numCycles * cycleLength;
	var hang = (1 - gap) / 3;
	// create left envelope array via iteration

	panL = [[1, minV, minV, 1, 1], [hang, gap, hang, hang, 0.0]];
	panR = [[1, 1, minV, minV, 1], [hang, hang, gap, hang, 0.0]];
	(numCycles - 1).do({arg i;
		panL.put(0, panL.at(0)++[1, minV, minV, 1, 1]);
		panL.put(1, panL.at(1)++[hang, gap, hang, hang, 0.0]);
		panR.put(0, panR.at(0)++[1, 1, minV, minV, 1]);
		panR.put(1, panR.at(1)++[hang, hang, gap, hang, 0.0]);
	});

	panL.at(1).removeAt(panL.at(1).size - 1); // remove last time value
	panR.at(1).removeAt(panR.at(1).size - 1); // remove last time value

	// switches left and right if false
	if(clockwise == False, {
		var temp = panL;
		panL = panR;
		panR = temp;
	});

	outputL = CtkControl.env(Env(panL.at(0), panL.at(1), \sin), timeScale: cycleLength);
	outputR = CtkControl.env(Env(panR.at(0), panR.at(1), \sin), timeScale: cycleLength);

	// for fm synth using bln noise
	if (mySynthDef == fmblnSynthDef, {
		score.add(
			fmblnSynthDef.note(
				starttime: start,        // start
				duration: dur            // dur
			).dur_(dur)                  // dur
			.gain_(CtkControl.env(myParams.at(0), timeScale: dur))
			.ampEnv_(CtkControl.env(myParams.at(1), timeScale: dur))
			.noiFreq_(CtkControl.env(myParams.at(2), timeScale: dur))
			.modIndex_(CtkControl.env(myParams.at(3), timeScale: dur))
			.panL_(outputL)
			.panR_(outputR)
		)
	});

	// for regular fmSynth
	if (mySynthDef == fmSynthDef, {
		score.add(
			fmSynthDef.note(
				starttime: start,        // start
				duration: dur            // dur
			).dur_(dur)                  // dur
			.gain_(CtkControl.env(myParams.at(0), timeScale: dur))
			.ampEnv_(CtkControl.env(myParams.at(1), timeScale: dur))
			.freq_(CtkControl.env(myParams.at(2), timeScale: dur))
			.carRatio_(CtkControl.env(myParams.at(3), timeScale: dur))
			.modRatio_(CtkControl.env(myParams.at(4), timeScale: dur))
			.modIndex_(CtkControl.env(myParams.at(5), timeScale: dur))
			.panL_(outputL)
			.panR_(outputR)
		);
	});
};



// function to add individual notes to our score for additive synthesis
additiveFunc = {arg mySynthDef, start, dur, gain, ampEnv, freq = 440.0, fadeDur = 0.0, fadeIn = 0.0, formData; // pass in values

	// iterate through the partialData array to generate individual notes to add to the score
	formData.do({arg thisFormData, i;
		var thisFormFreq, thisFormGain, thisFormQ;

		// retreive formant freq, gain, Q (potentially as envelopes)

		if(thisFormData.at(0).isKindOf(Env), {
			thisFormFreq = CtkControl.env(thisFormData.at(0), timeScale: dur);
		}, {
			thisFormFreq = thisFormData.at(0);
		});

		if(thisFormData.at(1).isKindOf(Env), {
			thisFormGain = CtkControl.env(thisFormData.at(1), levelBias: gain, timeScale: dur);
		}, {
			thisFormGain = gain + thisFormData.at(1);
		});

		if(thisFormData.at(2).isKindOf(Env), {
			thisFormQ = CtkControl.env(thisFormData.at(2), timeScale: dur);
		}, {
			thisFormQ = thisFormData.at(2);
		});

		// create a note for each formant...
		if ( mySynthDef == sgsSynthDef,   // check if tonal or noise
			{
				score.add(                       // <--- for TONAL formants
					mySynthDef.note(             // mySynthDef
						starttime: start,        // start
						duration: dur            // dur
					).dur_(dur)                  // dur
					.gain_(thisFormGain)         // gain
					.ampEnv_(ampEnv)
					.freq_(freq)                 // freq
					.formFreq_(thisFormFreq)     // formFreq
					.q_(thisFormQ)               // q
					.fadeIn_(fadeIn)
					.fadeDur_(fadeDur)
				)
		});

	});
};
///////////////// ANALYZE WAVEFORMS //////////////////


///////////////// SET PARAMETER VALUES //////////////////

//////// O to N SGS SYNTH: 1st Half ////////////////

// Formant Data
// [[ formFreq, formGain, formQ ], ... ]

// Male Sung Vowel O - D&J p230
formData1 = [
	[  325.0,   0.0, 2.00 ], // 1st formant
	[  700.0, -12.0, 3.00 ], // 2nd formant
	[ 2550.0, -26.0, 5.00 ], // 3rd formant
	[ 2850.0, -22.0, 5.00 ], // 4th formant
	[ 3100.0, -28.0, 5.00 ]  // 5th formant
];


//Formant data for male sung consonant N - estimated from http://clas.mq.edu.au/speech/acoustics/speech_spectra/nasal_stops.html
formData2 = [
	[  200.0,   0.0, 4.00 ], // 1st formant
	[ 2000.0, -55.0, 6.00 ], // 2nd formant
	[ 2600.0, -45.0, 10.00 ], // 3rd formant
	[ 3600.0, -60.0, 10.00 ], // 4th formant
	[ 4800.0, -65.0, 10.00 ]  // 5th formant
];

start = 0;
dur = 90;
gain = -13;
ampEnv = CtkControl.env(Env.sinLFO(Env([1, 150], [1], 6), 0, Env([0, 0.8, 1, 1, 0], [0.01, 0.79, 0.05, 0.1, 0.05], 6)), timeScale: dur);
fadeIn = 0.4; // start of cross fade
fadeDur = 0.2; // cross fade duration
sus1 = 0.4; // sustain formData1
trans = 0.2; // transition between formData
sus2 = 0.4; // sustain formData2
numOctDivisions = 0;
numNotes = numOctDivisions + 1; // ascend a whole octave
noteFreqs = 110.0 * Array.geom(numNotes, 1, 2.pow(1/(numOctDivisions)));
synthDef = sgsSynthDef;

// -------------------------------------------
// use -collect (iteration!) to pack into array, noteParams
noteParams = numNotes.collect({arg i;
	Array.with(start + (i * dur), dur, gain, ampEnv, noteFreqs.at(i), fadeDur, fadeIn)
});

// add formant to score
noteParamsFunc2.value(mySynthDef: synthDef, myParams: noteParams, formData1: formData1, formData2: formData2, sus1: sus1, trans: trans, sus2: sus2);


//////// N to O SGS SYNTH: 2nd Half ////////////////

start = 95;
dur = 90;
gain = -13;
ampEnv = CtkControl.env(Env.sinLFO(Env([1, 150], [1], 6), 0, Env([0, 1, 1, 0], [0.01, 0.89, 0.1], 6)), timeScale: dur);
fadeIn = 0.4; // start of cross fade
fadeDur = 0.2; // cross fade duration
sus1 = 0.4; // sustain formData1
trans = 0.2; // transition between formData
sus2 = 0.4; // sustain formData2
numOctDivisions = 0;
numNotes = numOctDivisions + 1; // ascend a whole octave
noteFreqs = 110.0 * Array.geom(numNotes, 1, 2.pow(1/(numOctDivisions)));
synthDef = sgsSynthDef;

// -------------------------------------------
// use -collect (iteration!) to pack into array, noteParams
noteParams = numNotes.collect({arg i;
	Array.with(start + (i * dur), dur, gain, ampEnv, noteFreqs.at(i), fadeDur, fadeIn)
});

// add formant to score
noteParamsFunc2.value(mySynthDef: synthDef, myParams: noteParams, formData1: formData1, formData2: formData2, sus1: sus1, trans: trans, sus2: sus2);


//////// INTRO VOICE ////////////////


// Formant Data
// [[ formFreq, formGain, formQ ], ... ]

// Example 1
// Formant data for male sung vowel O D&G p.230
formData2 = [
	[  325.0,   0.0, 2.00 ], // 1st formant
	[  700.0, -12.0, 3.00 ], // 2nd formant
	[ 2550.0, -26.0, 5.00 ], // 3rd formant
	[ 2850.0, -22.0, 5.00 ], // 4th formant
	[ 3100.0, -28.0, 5.00 ]  // 5th formant
];


// Formant data for male sung consonant N - estimated from http://clas.mq.edu.au/speech/acoustics/speech_spectra/nasal_stops.html
formData1 = [
	[  200.0,   0.0, 2.00 ], // 1st formant
	[  2000.0,  -55.0, 3.00 ], // 2nd formant
	[ 2600.0, -45.0, 3.00 ], // 3rd formant
	[ 3600.0, -60.0, 3.00 ], // 4th formant
	[ 4800.0, -65.0, 3.00 ]  // 5th formant
];

start = 0;
dur = 10;
gain = -10;
ampEnv = CtkControl.env(Env([0, 1, 1, 0], [0.3, 0.6, 0.1], 6), timeScale: dur);
fadeIn = 0.3; // start of cross fade
fadeDur = 0.3; // cross fade duration
sus1 = 0.3; // sustain formData1
trans = 0.3; // transition between formData
sus2 = 0.4; // sustain formData2
numOctDivisions = 0;
numNotes = numOctDivisions + 1; // ascend a whole octave
noteFreqs = 110.0 * Array.geom(numNotes, 1, 2.pow(1/(numOctDivisions)));
synthDef = sgsSynthDef;   // <--- This is our "data of interest", choose TONAL formants

// -------------------------------------------
// use -collect (iteration!) to pack into array, noteParams
noteParams = numNotes.collect({arg i;
	Array.with(start + (i * dur), dur, gain, ampEnv, noteFreqs.at(i), fadeDur, fadeIn)
});

// add formant to score
noteParamsFunc2.value(mySynthDef: synthDef, myParams: noteParams, formData1: formData1, formData2: formData2, sus1: sus1, trans: trans, sus2: sus2);

///////////////// EVALUATE FUNCTIONS //////////////////

/*
template myParams for elliptical synth with regular FM
noteParams = [
	Env([], [], \lin), // gain
    Env([], [], \lin), // ampEnv
	Env([], [], \lin), // freq
	Env([], [], \lin), // carRatio
	Env([], [], \lin), // modRatio
	Env([], [], \lin)  // modIndex
];

template myParams for elliptical synth with FM bln
noteParams = [
	Env([], [], \lin), // gain
    Env([], [], \lin),  // ampEnv
	Env([], [], \lin), // noiFreq
	Env([], [], \lin)  // modIndex
];

template for elliptical synth
ellipSynth.value(
	start: 0.0,
	mySynthDef: fmSynthDef,
	myParams: noteParams,
    minV: 0.0,
	cycleLength: 30.0,
	numCycles: 10,
	gap: 0.1,
	clockwise: True
);
*/


fmFreqs = [
	69,
	98.736866596263,
	141.28940326447,
	202.18076755926,
	289.31442717143,
];

fmFreqs = fmFreqs.reverse;

blnFreqs = [
	69,
	98.736866596263,
	141.28940326447,
	202.18076755926,
	289.31442717143,
];

fmGains = [
	-10,
	-12,
	-14,
	-16,
	-18
];

blnGains = [
	-25,
	-22.5,
	-20,
	-17.5,
	-30
];

blnFreqs = blnFreqs * 2;

// reduce volume for clipping
blnGains = blnGains - 1;
fmGains = fmGains -1;

//////// SECTIONS 1 -> 12 /////////



// FM 1
6.do({arg i;
	var n = 1;
	var c1, c2;

	if(i.mod(2) == 0, {
		c1 = (i/2)*(1 + n) + 1;
		c2 = ((i + 1 + 1)/2) * (1 + n) - 1;
	}, {
		c1 = ((i + 1)/2) * (1 + n) - 1;
		c2 = ((i + 1)/2) * (1 + n) + 1;
	});

	noteParams = [
		Env([fmGains.at(0), fmGains.at(0)], [1], \lin), // gain
		Env([0, 1, 1, 0], [0.2, 0.6, 0.2], \sin),
		Env([fmFreqs.at(0), fmFreqs.at(0)], [1], \lin), // freq
		Env([c1, c2], [1], \sin), // carRatio
		Env([1 + n, 1 + n], [1], \lin), // modRatio
		Env([1, 1], [1], \lin)  // modIndex
	];

	ellipSynth.value(
		start: 7.5 + (15 * i),
		mySynthDef: fmSynthDef,
		myParams: noteParams,
		minV: 0.0,
		cycleLength: (7.5 / 12),
		numCycles: 12,
		gap: 0.0,
		clockwise: True
	);
});

// FMBLN 10
6.do({arg i;
	var n = 1;
	var c1, c2;

	noteParams = [
		Env([blnGains.at(0), blnGains.at(0)], [1], \lin), // gain
		Env([0, 1, 1, 0], [0.1, 0.8, 0.1], 8), // ampEnv
		Env([blnFreqs.at(0), blnFreqs.at(0)], [1], \lin), // noiFreq
		Env([7 - i,  6 - i], [1], 8)  // modIndex
	];

	ellipSynth.value(
		start: 7.5 + (15 * i),
		mySynthDef: fmblnSynthDef,
		myParams: noteParams,
		minV: 0.1,
		cycleLength: 7.5,
		numCycles: 1,
		gap: 0.4,
		clockwise: False
	);
});

// FM 2
4.do({arg i;
	var n = 2;
	var c1, c2;

	if(i.mod(2) == 0, {
		c1 = (i/2)*(1 + n) + 1;
		c2 = ((i + 1 + 1)/2) * (1 + n) - 1;
	}, {
		c1 = ((i + 1)/2) * (1 + n) - 1;
		c2 = ((i + 1)/2) * (1 + n) + 1;
	});

	noteParams = [
		Env([fmGains.at(1), fmGains.at(1)], [1], \lin), // gain
		Env([0, 1, 1, 0], [0.2, 0.6, 0.2], \sin),
		Env([fmFreqs.at(1), fmFreqs.at(1)], [1], \lin), // freq
		Env([c2, c1, c2], [0.5, 0.5], \sin), // carRatio
		Env([1 + n, 1 + n], [1], \lin), // modRatio
		Env([1, 1], [1], \lin)  // modIndex
	];

	ellipSynth.value(
		start: 7.5 + (22.5 * i),
		mySynthDef: fmSynthDef,
		myParams: noteParams,
		minV: 0.0,
		cycleLength: (15 / 12),
		numCycles: 12,
		gap: 0.1,
		clockwise: True
	);
});

// FMBLN 9
4.do({arg i;
	var n = 2;
	var c1, c2;

	noteParams = [
		Env([blnGains.at(1), blnGains.at(1)], [1], \lin), // gain
		Env([0, 1, 1, 0], [0.1, 0.8, 0.1], 7),
		Env([blnFreqs.at(1), blnFreqs.at(1)], [1], \lin), // freq
		Env([i, i + 1], [1], 7)  // modIndex
	];

	ellipSynth.value(
		start: 7.5 + (22.5 * i),
		mySynthDef: fmblnSynthDef,
		myParams: noteParams,
		minV: 0.05,
		cycleLength: 15,
		numCycles: 1,
		gap: 0.3,
		clockwise: False
	);
});

// FM 3
3.do({arg i;
	var n = 3;
	var c1, c2;

	if(i.mod(2) == 0, {
		c1 = (i/2)*(1 + n) + 1;
		c2 = ((i + 1 + 1)/2) * (1 + n) - 1;
	}, {
		c1 = ((i + 1)/2) * (1 + n) - 1;
		c2 = ((i + 1)/2) * (1 + n) + 1;
	});

	noteParams = [
		Env([fmGains.at(2), fmGains.at(2)], [1], \lin), // gain
		Env([0, 1, 1, 0], [0.2, 0.6, 0.2], \sin),
		Env([fmFreqs.at(2), fmFreqs.at(2)], [1], \lin), // freq
		Env([c1, c2], [1], \sin), // carRatio
		Env([1 + n, 1 + n], [1], \lin), // modRatio
		Env([1, i, i, 1], [0.4, 0.2, 0.4], \sin)  // modIndex
	];

	ellipSynth.value(
		start: 7.5 + (30 * i),
		mySynthDef: fmSynthDef,
		myParams: noteParams,
		minV: 0.0,
		cycleLength: (22.5 / 6),
		numCycles: 6,
		gap: 0.2,
		clockwise: True
	);
});

// FMBLN 8
3.do({arg i;
	var n = 3;
	var c1, c2;

	noteParams = [
		Env([blnGains.at(2), blnGains.at(2)], [1], \lin), // gain
		Env([0, 1, 1, 0], [0.1, 0.8, 0.1], 6),
		Env([blnFreqs.at(2), blnFreqs.at(2)], [1], \lin), // freq
		Env([7 - i, 6 - i], [1], 6)  // modIndex
	];

	ellipSynth.value(
		start: 7.5 + (30 * i),
		mySynthDef: fmblnSynthDef,
		myParams: noteParams,
		minV: 0.025,
		cycleLength: 22.5,
		numCycles: 1,
		gap: 0.2,
		clockwise: False
	);
});

// FM 4
2.do({arg i;
	var n = 4;
	var c1, c2;

	if(i.mod(2) == 0, {
		c1 = (i/2)*(1 + n) + 1;
		c2 = ((i + 1 + 1)/2) * (1 + n) - 1;
	}, {
		c1 = ((i + 1)/2) * (1 + n) - 1;
		c2 = ((i + 1)/2) * (1 + n) + 1;
	});

	noteParams = [
		Env([fmGains.at(3), fmGains.at(3)], [1], \lin), // gain
		Env([0, 1, 1, 0], [0.2, 0.6, 0.2], \sin),
		Env([fmFreqs.at(3), fmFreqs.at(3)], [1], \lin), // freq
		Env([c2, c1, c2], [0.5, 0.5], \sin), // carRatio
		Env([1 + n, 1 + n], [1], \lin), // modRatio
		Env([1, i, i, 1], [0.4, 0.2, 0.4], \sin)  // modIndex
	];

	ellipSynth.value(
		start: 7.5 + (37.5 * i),
		mySynthDef: fmSynthDef,
		myParams: noteParams,
		minV: 0.0,
		cycleLength: (37.5 / 2),
		numCycles: 2,
		gap: 0.3,
		clockwise: True
	);
});

// FM BLN 7
2.do({arg i;
	var n = 4;
	var c1, c2;

	noteParams = [
		Env([blnGains.at(3), blnGains.at(3)], [1], \lin), // gain
		Env([0, 1, 1, 0], [0.1, 0.8, 0.1], 5),
		Env([blnFreqs.at(3), blnFreqs.at(3)], [1], \lin), // freq
		Env([i, i + 1], [1], 5)  // modIndex
	];

	ellipSynth.value(
		start: 7.5 + (37.5 * i),
		mySynthDef: fmblnSynthDef,
		myParams: noteParams,
		minV: 0.0125,
		cycleLength: 37.5,
		numCycles: 1,
		gap: 0.1,
		clockwise: False
	);
});

// FM 5
1.do({arg i;
	var n = 5;
	var c1, c2;

	if(i.mod(2) == 0, {
		c1 = (i/2)*(1 + n) + 1;
		c2 = ((i + 1 + 1)/2) * (1 + n) - 1;
	}, {
		c1 = ((i + 1)/2) * (1 + n) - 1;
		c2 = ((i + 1)/2) * (1 + n) + 1;
	});

	noteParams = [
		Env([fmGains.at(4), fmGains.at(4)], [1], \lin), // gain // breaking pattern for noise control
		Env([0, 1, 1, 0], [0.2, 0.6, 0.2], \sin),
		Env([fmFreqs.at(4), fmFreqs.at(4)], [1], \lin), // freq
		Env([c1, c2], [1], \sin), // carRatio
		Env([1 + n, 1 + n], [1], \lin), // modRatio
		Env([1, i, i, 1], [0.4, 0.2, 0.4], \sin)  // modIndex
	];

	ellipSynth.value(
		start: 0.0,
		mySynthDef: fmSynthDef,
		myParams: noteParams,
		minV: 0.0,
		cycleLength: 90,
		numCycles: 1,
		gap: 0.4,
		clockwise: True
	);
});

// FM BLN 6
1.do({arg i;
	var n = 5;
	var c1, c2;

	noteParams = [
		Env([blnGains.at(4), blnGains.at(4)], [1], \lin), // gain // breaking pattern for noise control
		Env([0, 1, 1, 0], [0.1, 0.8, 0.1], 4),
		Env([blnFreqs.at(4), blnFreqs.at(4)], [1], \lin), // freq
		Env([7 - i, 6 - i], [1], 4)  // modIndex
	];

	ellipSynth.value(
		start: 0.0,
		mySynthDef: fmblnSynthDef,
		myParams: noteParams,
		minV: 0.0,
		cycleLength: 90,
		numCycles: 1,
		gap: 0.0,
		clockwise: False
	);
});


// MIDDLE SECTION

dur = 9;

score.add(
	agsSynthDef.note(
		starttime: 87,        // start
		duration: dur            // dur
	).dur_(dur)                  // dur
	.gain_(-14)
	.ampEnv_(CtkControl.env(Env([0, 1, 1, 0], [0.1, 0.8, 0.1], \lin), timeScale: dur))
	.freq_(CtkControl.env(Env([440, 440], [1], \lin), timeScale: dur))
	.formFreq_(CtkControl.env(Env([1760, 1760], [1], \lin), timeScale: dur))
	.q_(CtkControl.env(Env([1, 2, 1], [0.1, 0.8, 0.1], \lin), timeScale: dur))
);


//////// SECTIONS 13 -> 24 /////////

// FM 1
1.do({arg i;
	var n = 1;
	var c1, c2;

	if(i.mod(2) == 0, {
		c1 = (i/2)*(1 + n) + 1;
		c2 = ((i + 1 + 1)/2) * (1 + n) - 1;
	}, {
		c1 = ((i + 1)/2) * (1 + n) - 1;
		c2 = ((i + 1)/2) * (1 + n) + 1;
	});
	noteParams = [
		Env([fmGains.at(0), fmGains.at(0)], [1], \lin), // gain
		Env([0, 1, 1, 0], [0.2, 0.6, 0.2], \sin),
		Env([fmFreqs.at(0), fmFreqs.at(0)], [1], \lin), // freq
		Env([c2, c1], [1], \sin), // carRatio
		Env([1 + n, 1 + n], [1], \lin), // modRatio
		Env([i, 1, 1, i], [0.4, 0.2, 0.4], \sin)  // modIndex
	];

	ellipSynth.value(
		start: 95,
		mySynthDef: fmSynthDef,
		myParams: noteParams,
		minV: 0.0,
		cycleLength: 90,
		numCycles: 1,
		gap: 0.4,
		clockwise: False
	);
});

// FMBLN 10
1.do({arg i;
	var n = 1;
	var c1, c2;

	noteParams = [
		Env([blnGains.at(0), blnGains.at(0)], [1], \lin), // gain
		Env([0, 1, 1, 0], [0.2, 0.6, 0.2], 4), // ampEnv
		Env([blnFreqs.at(0), blnFreqs.at(0)], [1], \lin), // noiFreq
		Env([6 - i,  7 - i], [1], 4)  // modIndex
	];

	ellipSynth.value(
		start: 95,
		mySynthDef: fmblnSynthDef,
		myParams: noteParams,
		minV: 0.0,
		cycleLength: 90,
		numCycles: 1,
		gap: 0.0,
		clockwise: True
	);
});

// FM 2
2.reverseDo({arg i;
	var n = 2;
	var c1, c2;

	if(i.mod(2) == 0, {
		c1 = (i/2)*(1 + n) + 1;
		c2 = ((i + 1 + 1)/2) * (1 + n) - 1;
	}, {
		c1 = ((i + 1)/2) * (1 + n) - 1;
		c2 = ((i + 1)/2) * (1 + n) + 1;
	});

	noteParams = [
		Env([fmGains.at(1), fmGains.at(1)], [1], \lin), // gain
		Env([0, 1, 1, 0], [0.2, 0.6, 0.2], \sin),
		Env([fmFreqs.at(1), fmFreqs.at(1)], [1], \lin), // freq
		Env([c2, c1, c2], [0.5, 0.5], \sin), // carRatio
		Env([1 + n, 1 + n], [1], \lin), // modRatio
		Env([i, 1, 1, i], [0.4, 0.2, 0.4], \sin)  // modIndex
	];

	i = 1 - i;

	ellipSynth.value(
		start: 95 + (37.5 * i),
		mySynthDef: fmSynthDef,
		myParams: noteParams,
		minV: 0.0,
		cycleLength: (37.5 / 2),
		numCycles: 2,
		gap: 0.3,
		clockwise: False
	);
});

// FMBLN 9
2.reverseDo({arg i;
	var n = 2;
	var c1, c2;

	noteParams = [
		Env([blnGains.at(1), blnGains.at(1)], [1], \lin), // gain
		Env([0, 1, 1, 0], [0.1, 0.8, 0.1], 5),
		Env([blnFreqs.at(1), blnFreqs.at(1)], [1], \lin), // freq
		Env([i + 1, i], [1], 5)  // modIndex
	];

	i = 1 - i;

	ellipSynth.value(
		start: 95 + (37.5 * i),
		mySynthDef: fmblnSynthDef,
		myParams: noteParams,
		minV: 0.0125,
		cycleLength: 37.5,
		numCycles: 1,
		gap: 0.1,
		clockwise: True
	);
});

// FM 3
3.reverseDo({arg i;
	var n = 3;
	var c1, c2;

	if(i.mod(2) == 0, {
		c1 = (i/2)*(1 + n) + 1;
		c2 = ((i + 1 + 1)/2) * (1 + n) - 1;
	}, {
		c1 = ((i + 1)/2) * (1 + n) - 1;
		c2 = ((i + 1)/2) * (1 + n) + 1;
	});

	noteParams = [
		Env([fmGains.at(2), fmGains.at(2)], [1], \lin), // gain
		Env([0, 1, 1, 0], [0.2, 0.6, 0.2], \sin),
		Env([fmFreqs.at(2), fmFreqs.at(2)], [1], \lin), // freq
		Env([c2, c1], [1], \sin), // carRatio
		Env([1 + n, 1 + n], [1], \lin), // modRatio
		Env([i, 1, 1, i], [0.4, 0.2, 0.4], \sin)  // modIndex
	];

	i = 2 - i;

	ellipSynth.value(
		start: 95 + (30 * i),
		mySynthDef: fmSynthDef,
		myParams: noteParams,
		minV: 0.0,
		cycleLength: (22.5 / 6),
		numCycles: 6,
		gap: 0.2,
		clockwise: False
	);
});

// FMBLN 8
3.reverseDo({arg i;
	var n = 3;
	var c1, c2;

	noteParams = [
		Env([blnGains.at(2), blnGains.at(2)], [1], \lin), // gain
		Env([0, 1, 1, 0], [0.1, 0.8, 0.1], 6),
		Env([blnFreqs.at(2), blnFreqs.at(2)], [1], \lin), // freq
		Env([6 - i, 7 - i], [1], 6)  // modIndex
	];

	i = 2 - i;

	ellipSynth.value(
		start: 95 + (30 * i),
		mySynthDef: fmblnSynthDef,
		myParams: noteParams,
		minV: 0.025,
		cycleLength: 22.5,
		numCycles: 1,
		gap: 0.2,
		clockwise: True
	);
});

// FM 4
4.reverseDo({arg i;
	var n = 4;
	var c1, c2;

	if(i.mod(2) == 0, {
		c1 = (i/2)*(1 + n) + 1;
		c2 = ((i + 1 + 1)/2) * (1 + n) - 1;
	}, {
		c1 = ((i + 1)/2) * (1 + n) - 1;
		c2 = ((i + 1)/2) * (1 + n) + 1;
	});

	noteParams = [
		Env([fmGains.at(3), fmGains.at(3)], [1], \lin), // gain
		Env([0, 1, 1, 0], [0.2, 0.6, 0.2], \sin),
		Env([fmFreqs.at(3), fmFreqs.at(3)], [1], \lin), // freq
		Env([c2, c1, c2], [0.5, 0.5], \sin), // carRatio
		Env([1 + n, 1 + n], [1], \lin), // modRatio
		Env([1, 1], [1], \lin)  // modIndex
	];

	i = 3 - i;

	ellipSynth.value(
		start: 95 + (22.5 * i),
		mySynthDef: fmSynthDef,
		myParams: noteParams,
		minV: 0.0,
		cycleLength: (15 / 12),
		numCycles: 12,
		gap: 0.1,
		clockwise: False
	);
});

// FM BLN 7
4.reverseDo({arg i;
	var n = 4;
	var c1, c2;

	i = 4 - i;

	noteParams = [
		Env([blnGains.at(3), blnGains.at(3)], [1], \lin), // gain
		Env([0, 1, 1, 0], [0.1, 0.8, 0.1], 7),
		Env([blnFreqs.at(3), blnFreqs.at(3)], [1], \lin), // freq
		Env([i + 1, i], [1], 7)  // modIndex
	];

	i = 3 - i;

	ellipSynth.value(
		start: 95 + (22.5 * i),
		mySynthDef: fmblnSynthDef,
		myParams: noteParams,
		minV: 0.05,
		cycleLength: 15,
		numCycles: 1,
		gap: 0.3,
		clockwise: True
	);
});

// FM 5
6.reverseDo({arg i;
	var n = 5;
	var c1, c2;

	if(i.mod(2) == 0, {
		c1 = (i/2)*(1 + n) + 1;
		c2 = ((i + 1 + 1)/2) * (1 + n) - 1;
	}, {
		c1 = ((i + 1)/2) * (1 + n) - 1;
		c2 = ((i + 1)/2) * (1 + n) + 1;
	});

	noteParams = [
		Env([fmGains.at(4), fmGains.at(4)], [1], \lin), // gain // breaking pattern for noise control
		Env([0, 1, 1, 0], [0.2, 0.6, 0.2], \sin),
		Env([fmFreqs.at(4), fmFreqs.at(4)], [1], \lin), // freq
		Env([c2, c1], [1], \sin), // carRatio
		Env([1 + n, 1 + n], [1], \lin), // modRatio
		Env([1, 1], [1], \lin)  // modIndex
	];

	i = 5 - i;

	ellipSynth.value(
		start: 95 + (15 * i),
		mySynthDef: fmSynthDef,
		myParams: noteParams,
		minV: 0.0,
		cycleLength: (7.5 / 12),
		numCycles: 12,
		gap: 0.0,
		clockwise: False
	);
});

// FM BLN 6
6.reverseDo({arg i;
	var n = 5;
	var c1, c2;

	noteParams = [
		Env([blnGains.at(4), blnGains.at(4)], [1], \lin), // gain // breaking pattern for noise control
		Env([0, 1, 1, 0], [0.1, 0.8, 0.1], 8),
		Env([blnFreqs.at(4), blnFreqs.at(4)], [1], \lin), // freq
		Env([6 - i, 7 - i], [1], 8)  // modIndex
	];

	i = 5 - i;

	ellipSynth.value(
		start: 95 + (15 * i),
		mySynthDef: fmblnSynthDef,
		myParams: noteParams,
		minV: 0.1,
		cycleLength: 7.5,
		numCycles: 1,
		gap: 0.4,
		clockwise: True
	);
});


///////////////// RENDER THE SCORE //////////////////

// write score to sound file with the -write message
score.write(
	path: outputPath.standardizePath,
	sampleRate: sampleRate,
	headerFormat: headerFormat,
	sampleFormat: sampleFormat,
	options: ServerOptions.new.numOutputBusChannels_(numOutputChannels)
);
)
SFPlayer("~/Desktop/Gaimari_final.wav".standardizePath).gui;