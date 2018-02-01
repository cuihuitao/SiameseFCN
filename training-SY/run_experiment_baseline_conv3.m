function run_experiment_baseline_conv3(imdb_video)
%% Experiment entry point

    opts.gpus = 2;

    if nargin < 1
        imdb_video = [];
    end
    
    opts.join.method = 'xcorr';
    opts.branch.conf.num_out = [96 256 32];
    opts.branch.conf.num_in = [3 48 256];
    opts.branch.conf.conv_stride = [2 1 1];
    opts.branch.conf.pool_stride = [2 1];
    opts.branch.conf.last_layer = 'conv3';
    
    opts.exemplarSize = 127;
    opts.instanceSize = 255;
    opts.train.numEpochs = 100;
    
    opts.augment.grayscale = 1.0;
    
    opts.augment.inverse = 0.5;
    opts.augment.invprob = 0.5;
    opts.augment.input_method = 'crop';
    
    opts.setVALtoTRAIN = true;
    
    opts.expDir = 'data/conv3_inverse_0.5_trainval';

    experiment(imdb_video, opts);

end

