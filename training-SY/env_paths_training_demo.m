function opts = env_paths_training_demo(opts)

    %opts.rootDataDir = 'E:/Projects_temp_lz/SiameseFC/ILSVRC2015_curated/Data/VID/trainval/'; % where the training set is
    opts.rootDataDir = 'E:/Projects_temp_lz/SiameseFC-SY/OriginalData-curation/trainval';
    opts.imdbVideoPath = '../ILSVRC15-curation-SY/imdb_folder-SY.mat'; % where the training set metadata are
    opts.imageStatsPath = '../ILSVRC15-curation-SY/ILSVRC2015.stats.mat'; % where the training set stats are
    opts.pretrainModelPath = './data/pretrain/matvgg5_pre.mat';  %where the pretrain model are
end
