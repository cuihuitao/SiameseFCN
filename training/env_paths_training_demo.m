function opts = env_paths_training_demo(opts)

    opts.rootDataDir = '/home/yangruyin/data/ILSVRC2015_curated/Data/VID/trainval/'; % where the training set is
    opts.imdbVideoPath = '../ILSVRC15-curation/imdb_video_demo.mat'; % where the training set metadata are
    opts.imageStatsPath = '../ILSVRC15-curation/ILSVRC2015.stats.mat'; % where the training set stats are

end
