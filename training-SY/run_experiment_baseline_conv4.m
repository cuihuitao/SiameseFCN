function run_experiment_baseline_conv4(imdb_video)
%% Experiment entry point

    opts.gpus = 1;

    if nargin < 1
        imdb_video = [];
    end
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   
    opts.join.method = 'xcorr';
    opts.branch.conf.num_out = [96 256 384 32];
    opts.branch.conf.num_in = [3 48 256 192];
    opts.branch.conf.conv_stride = [2 1 1 1];
    opts.branch.conf.pool_stride = [2 1];
    opts.branch.conf.last_layer = 'conv4';
 
    opts.exemplarSize = 127;
    opts.train.numEpochs = 100;
    
    opts.augment.grayscale = 1.0;
    
    opts.augment.inverse = 0.5;
    opts.augment.invprob = 0.5;
    
    opts.expDir = 'data/conv4_inverse_0.5';

    experiment(imdb_video, opts);

end

