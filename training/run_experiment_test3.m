function run_experiment_baseline_conv4(imdb_video)
%% Experiment entry point

    opts.gpus = 1;

    if nargin < 1
        imdb_video = [];
    end
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   
    opts.join.method = 'xcorr';
    opts.branch.conf.num_out = [64, 128, 256];
    opts.branch.conf.num_in = [ 3,  64, 128];
    opts.branch.conf.conv_stride = [ 2,   1,   1];
    opts.branch.conf.pool_stride = [ 2];                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      0            
    opts.branch.conf.last_layer = 'merge3';
    
    opts.branch.type = 'test3';
 
    opts.exemplarSize = 77;
    opts.instanceSize = 157;
    opts.train.batchSize = 2;
    opts.train.numEpochs = 100;
    
    opts.augment.grayscale = 1.0;
    
    opts.augment.inverse = 0.5;
    opts.augment.invprob = 0.5;

    experiment_demo(imdb_video, opts);

end

