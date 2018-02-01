function run_experiment_matvggm5(imdb_video)
%% Experiment entry point

    opts.gpus = 2;

    if nargin < 1
        imdb_video = [];
    end
    
    opts.branch.conf.last_layer = 'conv5_conv';
    opts.branch.type = 'matvggm5';
   
    opts.exemplarSize = 127;
    opts.instanceSize = 255;
    opts.train.batchSize = 8;
    opts.train.numEpochs = 100;
    
    opts.augment.grayscale = 1.0;
    
    opts.augment.inverse = 0.5;
    opts.augment.invprob = 0.5;
    
    opts.expDir = 'data/matvggm5_inverse_0.5';

    experiment(imdb_video, opts);

end

