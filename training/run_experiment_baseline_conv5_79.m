function run_experiment_baseline_conv5_79(imdb_video)
%% Experiment entry point

    opts.gpus = 4;

    if nargin < 1
        imdb_video = [];
    end

    opts.join.method = 'xcorr';
    opts.branch.conf.num_out = [96 256 384 384 32];
    opts.branch.conf.num_in = [3 48 256 192 192];
    opts.branch.conf.conv_stride = [2 1 1 1 1];
    opts.branch.conf.pool_stride = [2 1];
 
    opts.exemplarSize = 79;
    opts.instanceSize = 159;
    
    opts.train.numEpochs = 100;
   
    opts.augment.grayscale = 1.0;
    
    opts.augment.inverse = 0.5;
    opts.augment.invprob = 0.5;
    opts.augment.input_method = 'resize';
    
    opts.expDir = 'data/conv5_inverse_0.5_79_resize';

    experiment(imdb_video, opts);

end

