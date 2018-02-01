function run_experiment_baseline_conv5_negative_extraAug(imdb_video)
%% Experiment entry point

    opts.gpus = 3;

    if nargin < 1
        imdb_video = [];
    end

    opts.join.method = 'xcorr';
    opts.branch.conf.num_out = [96 256 384 384 32];
    opts.branch.conf.num_in = [3 48 256 192 192];
    opts.branch.conf.conv_stride = [2 1 1 1 1];
    opts.branch.conf.pool_stride = [2 1];
    
    opts.exemplarSize = 127;
    opts.instanceSize = 255;
    
    opts.train.numEpochs = 100;
   
    opts.augment.grayscale = 1.0;  
    opts.augment.inverse = 0.5;
    opts.augment.invprob = 0.5;
         
    opts.negatives = 0.5;
    
    opts.augment.extraAug = 0.5;
    opts.addAugment.random_num_of_methods = 3;
    opts.addAugment.invert.flag = 0;
    
    opts.expDir = 'data/conv5_inverse_0.5_negatives_0.5_extraAug_0.5';
    
    experiment(imdb_video, opts);

end

