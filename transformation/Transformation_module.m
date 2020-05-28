% Transform Performance RNN drum tracks

% Requires MIDI Toolbox (Toiviainen, P., & Eerola, T., 2016)

% 1. Read MIDI file
% 2. Quantize
% 3. Select segments based on rules
% 4. Reorder segments
% 5. Sequencer
% 6. Write MIDI file

% Information columns contained in notematrices:
% ONSET (BEATS) | DURATION (BEATS) | MIDI channel | PITCH | VELOCITY | ONSET (SEC) | DURATION (SEC)

clear all

%% 1. Read MIDI file

midifile = readmidi('performance_rnn_03.mid');

% Trim silence from beginning
trimmedfile = trim(midifile);

% Set channel to 9 (to avoid piano if the NN model was not primed with a drum file when generating input file)
trimmedfile = setvalues(trimmedfile,'chan',9);

%% 2. Quantize notes

beat = 1/16;
quanttrimfile = quantize(trimmedfile, beat);

% Plot piano roll visualization
% pianoroll(trimmedfile)

%% 3. Select segments based on rules

% Find segment probabilities
segprobs = segmentprob(quanttrimfile,1.0);

% Set probability threshold for segment inpoints
inpoints = find(segprobs > 0.60);

% Get indices for outpoints (next probability over zero after inpoint divided by 2)
for j = inpoints:length(segprobs)
    outpoints = inpoints + find(segprobs > 0, 1) / 2;
    if outpoints(end,1) > length(quanttrimfile)
        outpoints(end,1) = length(quanttrimfile);
    end
end

% Use in/out indices to segment notematrix
segmats = cell(length(inpoints),1);

for k = 1:length(inpoints)
    segmats{k} = quanttrimfile(inpoints(k):outpoints(k),:);
end

% Choose only segments containing bass drum (36) pitches
wantdrums = [36];
segpits = cell(length(segmats),1);

for l = 1:length(segmats)
    pitches = pitch(segmats{l});
    if all(ismember(wantdrums,pitches))
        segpits{l} = segmats{l};
    end
end

% Remove empty cells from cell array
segpits = segpits(~cellfun('isempty',segpits));

%% 4. Reorder segments by relative entropy, descending

entvals = zeros(length(segpits),1);

for p = 1:length(segpits)
    entvals(p,1) = entropy(segpits{p});
end

[~, eidx] = sort(nonzeros(entvals),'descend');
segent = segpits(eidx(1:length(entvals)));

%% 5.1 Sequencer

% To rearrange sequence, modify seqidx values
seqidx = [1; 1; 1; 2; 1; 1; 1; 3; 4; 4; 4; 5; 4; 4; 4; 6];

%% 5.2 Uncomment to override entropy ordering and randomize segment indices

% segidx = randperm(length(segent));
% 
% Ab = segidx(1);x
% Af = segidx(2);
% Af2 = segidx(3);
% Bb = segidx(4);
% Bf = segidx(5);
% Bf2 = segidx(6);
% 
% % To rearrange sequence, modify seqidx values
% seqidx = [Ab; Ab; Ab; Af; Ab; Ab; Ab; Af2; Bb; Bb; Bb; Bf; Bb; Bb; Bb; Bf2];

%% 5.3 Create cell array containing segments

seq = cell(length(segent),1);
seq = segent(seqidx(1:length(seqidx)));

% Trim segment start times to zero
for o = 1:length(seq)
    seq{o} = trim(seq{o});
end

%% 5.4 Shift segments so they play sequentially, not all at the same time

% Initialize
shifts = zeros(length(seq),1);
sidx = 6;

% Calculate shifts
for n = 2:length(seq)
    shifts(n) = seq{n-1}(end,sidx) + (seq{n-1}(end,sidx+1) * beat); 
    % Onset + (duration values * beat resolution) from previous segment
    shifts(n) = shifts(n-1)+shifts(n);
    % Sum two previous shift values     
end

% Shift segments
for i = 1:length(seq)
    seq{i}(:,sidx) = seq{i}(:,sidx)+shifts(i);
end

%% 6. Write MIDI file

seqmat = cell(length(seq),1);

for m = 1:length(seq)
    seqmat(m) = seq(m);
end

seqmat = cell2mat(seqmat);

transformed = writemidi(seqmat,'transformed_01.mid',120);