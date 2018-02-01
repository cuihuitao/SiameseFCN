function run_experiment_resnet_block1(imdb_video)
%% Experiment entry point

    opts.gpus = 3;

    if nargin < 1
        imdb_video = [];
    end
    
    opts.branch.conf.last_layer = 'conv2_1_sum';
    opts.branch.type = 'resnet_block1';
   
    opts.exemplarSize = 125;
    opts.instanceSize = 253;
    opts.train.batchSize = 4;
    opts.train.numEpochs = 100;
    
    opts.augment.grayscale = 1.0;
    
    opts.augment.inverse = 0.5;
    opts.augment.invprob = 0.5;
    
    opts.expDir = 'data/resnet_block1_inverse_0.5';

    experiment(imdb_video, opts);

end

