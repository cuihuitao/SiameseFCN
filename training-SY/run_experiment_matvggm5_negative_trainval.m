function run_experiment_matvggm5_negative_trainval(imdb_video)
%% Experiment entry point

    opts.gpus = 4;

    if nargin < 1
        imdb_video = [];
    end
    
    opts.join.method = 'xcorr';
    opts.branch.conf.last_layer = 'conv5_conv';
    opts.branch.type = 'matvggm5';
   
    opts.exemplarSize = 127;
    opts.instanceSize = 255;
    opts.train.batchSize = 8;
    opts.train.numEpochs = 100;
    
    opts.augment.grayscale = 1.0;
    
    opts.augment.inverse = 0.5;
    opts.augment.invprob = 0.5;
    opts.augment.input_method = 'crop';    % this variable used to get the input image when changing the exemplar or instance size
    
    opts.negatives = 0.5;  % fraction of negative pair in one batch
    
    opts.setVALtoTRAIN = true;   % use trainval set to train the net
    
    opts.expDir = 'data/matvggm5_inverse_0.5_negative_0.5_trainval';

    experiment(imdb_video, opts);

end

