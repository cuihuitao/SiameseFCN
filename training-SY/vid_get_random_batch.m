% -----------------------------------------------------------------------------------------------------------------------
function [imout_z, imout_x, labels, sizes_z, sizes_x] = vid_get_random_batch(imdb, imdb_video, batch, data_dir, varargin)
% Return batch of pairs of input (z and x) and labels
% (Sizes are returned as [height, width])
% -----------------------------------------------------------------------------------------------------------------------
    % Defines
    POS_PAIR = 1;
    EASY_NEG_PAIR = 2;
    HARD_NEG_PAIR = 3;
    RGB = 1;
    GRAY = 2;
    ORI = 1;
    INV = 2;   % inverser pair
    AUG = 2;   % augmentation pair (augment the input_x)
    TRAIN_SET = 1;
    VAL_SET = 2;
    % Default parameters
    opts.loss = 'simple';
    opts.exemplarSize = [];
    opts.instanceSize = [];
    opts.frameRange = 50;
    opts.negatives = 0;
    opts.hardNegatives = 0;
    opts.hardneg.distNeg = 25;
    opts.hardneg.pos = [1 127 1 127; 129 255 1 127; 1 127 129 255; 129 255 129 255];
    opts.subMean = false;
    opts.colorRange = 255; % Adjust range from [0, 255] to [0, colorRange].
    opts.stats.rgbMean_z = [];
    opts.stats.rgbVariance_z = [];
    opts.stats.rgbMean_x = [];
    opts.stats.rgbVariance_x = [];
    opts.augment.translate = false;
    opts.augment.maxTranslate = []; % empty means no max
    opts.augment.stretch = false;
    opts.augment.maxStretch = 0.1;
    opts.augment.color = false;
    opts.augment.grayscale = 0;
    opts.augment.inverse = 0;
    opts.augment.invprob = 0.5;
    opts.augment.input_method = 'crop';
    opts.augment.extraAug = 0;
    opts.addAugment = addAugmentInit();
    
    opts.prefetch = false;
    opts.numThreads = 12;
    opts = vl_argparse(opts, varargin);
% -----------------------------------------------------------------------------------------------------------------------
    % Determine the set (e.g. train or val) of the batch.
    batch_set = imdb.images.set(batch(1));
    % Check all images in the batch are from the same set.
    assert(all(batch_set == imdb.images.set(batch)));

    batch_size = numel(batch);
    % Determine type of each pair
    % positive pair: both crops contain object
    % easy negative pair: from different videos
    % hard negative pair: from same video, z is taken from background and > opts.frameRange apart from x

    % Decide types of pairs with given probabilities

    p = [opts.negatives, opts.hardNegatives];
    pair_types_neg = datasample(1:3, batch_size, 'Weights', [1-sum(p), p]);
    % Decide rgb vs gray with given probabilities
    pair_types_rgb = datasample(1:2, batch_size, 'Weights', [1-opts.augment.grayscale opts.augment.grayscale]);
    % Decide ori vs extra_aug with given probabilities
    pair_types_aug = datasample(1:2, batch_size, 'Weights', [1-opts.augment.extraAug opts.augment.extraAug]);
    % Decide ori vs inverse with given probabilities
    pair_types_inv = datasample(1:2, batch_size, 'Weights', [1-opts.augment.inverse opts.augment.inverse]);
    % hard negatives sampling parameters
    %
% -----------------------------------------------------------------------------------------------------------------------
    % randomize a subset of the imdb of batch_size - decide set of videos to sample from
    % NOTE: the purpose of imdb is to preserve compatibility with MatConvNet cnn_train_dag,
    % it just defines size of an epoch and the type of batch (train/val).
    ids_set = find(imdb_video.set==batch_set);
    % sample one video for each pair plus one for each negative sample
    num_easy_neg = numel(find(pair_types_neg==EASY_NEG_PAIR));
    rnd_videos = datasample(ids_set, batch_size+num_easy_neg, 'Replace', false);
    ids_pairs = rnd_videos(1:batch_size);
    ids_neg = rnd_videos(batch_size+1:end);
    
    % Initialize pairs
    % First load location for all pairs, all images will be loaded at once with vl_imreadjpeg
    % objects contains metadata for all the pairs of the batch
    objects = struct();
    objects.set = batch_set * uint8(ones(1, batch_size));
    objects.z = cell(1, batch_size);
    objects.x = cell(1, batch_size);
    % crops locations
    crops_z_string = cell(1, batch_size);
    crops_x_string = cell(1, batch_size);
    labels = zeros(1, batch_size);
    % final augmented crops
    imout_z = zeros(opts.exemplarSize, opts.exemplarSize, 3, batch_size, 'single');
    imout_x = zeros(opts.instanceSize, opts.instanceSize, 3, batch_size, 'single');

    neg = 0;
    for i = 1:batch_size
        switch pair_types_neg(i)
        % Crops from same videos, centered on the object
        case POS_PAIR
            labels(i) = 1;
            [objects.z{i}, objects.x{i}] = choose_pos_pair(imdb_video, ids_pairs(i), opts.frameRange);
        % Crops from different videos, centered of the object
        case EASY_NEG_PAIR
            neg = neg + 1;
            labels(i) = -1;
            [objects.z{i}, objects.x{i}] = choose_easy_neg_pair(imdb_video,  ids_pairs(i), ids_neg(neg));
        % Crops from same video: x centered on object, z taken from background as specified by opts.hard_neg
        case HARD_NEG_PAIR
            labels(i) = -1;
            [objects.z{i}, objects.x{i}] = choose_hard_neg_pair(imdb_video, ids_set, opts.hardneg.distNeg);
        otherwise
            error('invalid pair type');
        end
    end

    % get absolute paths of crops locations
    for i=1:batch_size
        % NOTE: doing the experiments for CVPR'17 we realized that using the large 255x255 crops and then extracting the inner 127x127 during training
        %  gives slightly better results than using the offline saved 127x127 crops. Probably because these are slight off-centered. 
        if pair_types_neg(i)==HARD_NEG_PAIR
            crops_z_string{i} = [strrep(fullfile(data_dir, objects.z{i}.model_frame_path), '.JPEG','') '.' num2str(objects.z{i}.track_id, '%02d') '.crop.z.jpg'];
        else
            crops_z_string{i} = [strrep(fullfile(data_dir, objects.z{i}.model_frame_path), '.JPEG','') '.' num2str(objects.z{i}.track_id, '%02d') '.crop.x.jpg'];
        end
        
        crops_x_string{i} = [strrep(fullfile(data_dir, objects.x{i}.real_frame_path), '.JPEG','') '.' num2str(objects.x{i}.track_id, '%02d') '.crop.x.jpg'];
        
        % for test in window environment
        %if ~isempty(strfind(crops_z_string{i}, '_train_'))
        %    crops_z_string{i} = strrep(crops_z_string{i}, 'trainval', 'train');
        %else
        %    crops_z_string{i} = strrep(crops_z_string{i}, 'trainval', 'val');
        %    crops_z_string{i} = strrep(crops_z_string{i}, 'ILSVRC2015_VID_val_0000\', '');
        %end
        
        %if ~isempty(strfind(crops_x_string{i}, '_train_'))
        %    crops_x_string{i} = strrep(crops_x_string{i}, 'trainval', 'train');
        %else
        %    crops_x_string{i} = strrep(crops_x_string{i}, 'trainval', 'val');
        %    crops_x_string{i} = strrep(crops_x_string{i}, 'ILSVRC2015_VID_val_0000\', '');
        %end
        
        % for test SY data format
        crops_x_string{i} = strrep(crops_x_string{i}, 'RotateImage', 'ModelRealImage');
        crops_z_string{i} = strrep(crops_x_string{i}, 'crop.x', 'crop.z');
        
    end
    % prepare all the files to read
    files = [crops_z_string crops_x_string];

    % prefetch is used to load images in a separate thread
    if opts.prefetch
        error('to implement');
    end
    
    %fprintf('%s\n', crops_z_string{1});
    %fprintf('%s\n', crops_x_string{1});

    % read all the crops efficiently
    crops = vl_imreadjpeg(files, 'numThreads', opts.numThreads);
    crops_z = crops(1:batch_size);
    crops_x = crops(batch_size+1 : end);
    clear crops
    % -----------------------------------------------------------------------------------------------------------------------
    % Data augmentation
    % Only augment during training.
    if batch_set == TRAIN_SET
        aug_opts = opts.augment;
        add_aug_opts = opts.addAugment;
    else
        aug_opts = struct('translate', false, ...
                          'maxTranslate', 0, ...
                          'stretch', false, ...
                          'maxStretch', 0, ...
                          'color', false, ...
                          'input_method', opts.augment.input_method);
        add_aug_opts = struct();
    end

    aug_z = @(crop, add_aug_opts) acquire_augment(crop, opts.exemplarSize, opts.stats.rgbVariance_z, aug_opts, add_aug_opts);
    aug_x = @(crop, add_aug_opts) acquire_augment(crop, opts.instanceSize, opts.stats.rgbVariance_x, aug_opts, add_aug_opts);

    for i=1:batch_size
        switch pair_types_aug(i)
            case ORI
                add_aug_opts.flag = 0;
            case AUG
                add_aug_opts.flag = 1;
        end
        if batch_set == VAL_SET
            add_aug_opts.flag = 0;
        end
        tmp_x = aug_x(crops_x{i}, add_aug_opts);
        % here we don not add extra augmentattion for exemplar
        add_aug_opts.flag = 0;
        switch pair_types_neg(i)
            case {POS_PAIR, EASY_NEG_PAIR}
                tmp_z = aug_z(crops_z{i}, add_aug_opts);
            case HARD_NEG_PAIR
                % For the hard negative pairs the exemplar has to be extracted from corners of corresponding search area.
                rand_pos = randi(size(opts.hardneg.pos,1));
                p = opts.hardneg.pos(rand_pos, :);
                neg_z = crops_z{i}(p(1):p(2), p(3):p(4), :);
                tmp_z = aug_z(neg_z, add_aug_opts);
                % test
                %figure(1), imshow(crops_x{i}/255)
                %figure(2), imshow(crops_z{i}/255)
                %figure(3), imshow(neg_z/255)
        end
        
        switch pair_types_rgb(i)
            case RGB
                imout_z(:,:,:,i) = tmp_z;
                imout_x(:,:,:,i) = tmp_x;
            case GRAY
                % vl_imreadjpeg returns images in [0, 255] with class single.
                imout_z(:,:,:,i) = repmat(rgb2gray(tmp_z/255)*255, [1 1 3]);
                imout_x(:,:,:,i) = repmat(rgb2gray(tmp_x/255)*255, [1 1 3]);
        end
        
        switch pair_types_inv(i)
            case ORI
                %imout_z(:,:,:,i) = imout_z(:,:,:,i);
                %imout_x(:,:,:,i) = imout_x(:,:,:,i);
            case INV
                prob = rand(1);
                if prob<=opts.augment.invprob
                    imout_z(:,:,:,i) = 255-imout_z(:,:,:,i);
                else
                    imout_x(:,:,:,i) = 255-imout_x(:,:,:,i);
                end
                %figure; imshow(imout_z(:,:,:,i)/255);
                %figure; imshow(imout_x(:,:,:,i)/255);
        end

        if opts.subMean
            % Sanity check - mean should be in range 0-255!
            means = [opts.stats.rgbMean_z(:); opts.stats.rgbMean_x(:)];
            lower = 0.2 * 255;
            upper = 0.8 * 255;
            if ~all((lower <= means) & (means <= upper))
                error('mean does not seem to for pixels in 0-255');
            end
            imout_z = bsxfun(@minus, imout_z, reshape(opts.stats.rgbMean_z, [1 1 3]));
            imout_x = bsxfun(@minus, imout_x, reshape(opts.stats.rgbMean_x, [1 1 3]));
        end
        imout_z = imout_z / 255 * opts.colorRange;
        imout_x = imout_x / 255 * opts.colorRange;
        %figure(1), imshow(imout_z(:,:,:,i)/255);
        %figure(2), imshow(imout_x(:,:,:,i)/255);
    end

    sizes_z = zeros(2, batch_size);
    sizes_x = zeros(2, batch_size);
    for i = 1:batch_size
        if ~(labels(i) > 0)
            continue
        end

        % compute bounding boxes of objects within crops x and z
        switch(opts.augment.input_method)
            case 'crop'
                [bbox_z, bbox_x] = get_objects_extent_crop(double(objects.z{i}.extent), double(objects.x{i}.extent), opts.exemplarSize, opts.instanceSize);
            case 'resize'
                [bbox_z, bbox_x] = get_objects_extent_resize(double(objects.z{i}.extent), double(objects.x{i}.extent), opts.exemplarSize, opts.instanceSize);
        end
        % only store h and w
        sizes_z(:,i) = bbox_z([4 3]);
        sizes_x(:,i) = bbox_x([4 3]);

%         % test
%         close all
%         figure(i), imshow(imout_x(:,:,:,i)/255); hold on
%         rect_x = [255/2-bbox_x(3)/2 255/2-bbox_x(4)/2 bbox_x(3) bbox_x(4)];
%         figure(i), rectangle('Position',rect_x, 'LineWidth',2','EdgeColor','y'); hold off
%         fprintf('\n%d:    %.2f  %.2f', i, bbox_x(4), bbox_x(3));
    end
end


% -----------------------------------------------------------------------------------------------------------------------
function [z, x] = choose_pos_pair(imdb_video, rand_vid, frameRange)
% Get positive pair with crops from same videos, centered on the object
% -----------------------------------------------------------------------------------------------------------------------
    valid_trackids = find(imdb_video.valid_trackids(:, rand_vid) > 1);
    assert(~isempty(valid_trackids), 'No valid trackids for a video in the batch.');
    rand_trackid_z = datasample(valid_trackids, 1);
    % pick valid exemplar from the random trackid
    rand_z = datasample(imdb_video.valid_per_trackid{rand_trackid_z, rand_vid}, 1);
    % pick valid instance within frameRange seconds from the exemplar, excluding the exemplar itself
    % add by lz. if we train sy data, we can remove the following codes
    %possible_x_pos = (1:numel(imdb_video.valid_per_trackid{rand_trackid_z, rand_vid}));
    %[~, rand_z_pos] = ismember(rand_z, imdb_video.valid_per_trackid{rand_trackid_z, rand_vid});
    %possible_x_pos = possible_x_pos([max(rand_z_pos-frameRange, 1):(rand_z_pos-1), (rand_z_pos+1):min(rand_z_pos+frameRange, numel(possible_x_pos))]);
    %possible_x = imdb_video.valid_per_trackid{rand_trackid_z, rand_vid}(possible_x_pos);
    %assert(~isempty(possible_x), 'No valid x for the chosen z.');
    %rand_x = datasample(possible_x, 1);
    %assert(imdb_video.objects{rand_vid}{rand_x}.valid, 'error picking rand x.');
    z = imdb_video.objects{rand_vid}{rand_z};
    x = z;
end


% -----------------------------------------------------------------------------------------------------------------------
function [z, x] = choose_easy_neg_pair(imdb_video, rand_vid, rand_neg_vid)
% Get negative pair with crops from diffeent videos, centered on the object
% -----------------------------------------------------------------------------------------------------------------------
    % get the exemplar
    valid_trackids_z = find(imdb_video.valid_trackids(:, rand_vid) > 1);
    assert(~isempty(valid_trackids_z), 'No valid trackids for a video in the batch.');
    rand_trackid_z = datasample(valid_trackids_z, 1);
    rand_z = datasample(imdb_video.valid_per_trackid{rand_trackid_z, rand_vid}, 1);
    z = imdb_video.objects{rand_vid}{rand_z};
    % get the instance
    valid_trackids_x = find(imdb_video.valid_trackids(:, rand_neg_vid) > 1);
    assert(~isempty(valid_trackids_x), 'No valid trackids for a video in the batch.');
    rand_trackid_x = datasample(valid_trackids_x, 1);
    rand_x = datasample(imdb_video.valid_per_trackid{rand_trackid_x, rand_neg_vid}, 1);
    x = imdb_video.objects{rand_neg_vid}{rand_x};
end


% -----------------------------------------------------------------------------------------------------------------------
function [z, x] = choose_hard_neg_pair(imdb_video, ids_set, dist_neg)
% -----------------------------------------------------------------------------------------------------------------------
    found = false;
    trials = 0;
    % try with new videos until at least one valid position for the negative is found
    while ~found && trials<100
        trials = trials+1;
        % pick a random video
        rand_vid = datasample(ids_set, 1);
        valid_trackids = find(imdb_video.valid_trackids(:, rand_vid) > 1);
        assert(~isempty(valid_trackids), 'No valid trackids for a video in the batch.');
        rand_trackid_x = datasample(valid_trackids, 1);
        % pick valid search area from the random trackid
        possible_x = imdb_video.valid_per_trackid{rand_trackid_x, rand_vid};
        npx = numel(possible_x);
        rand_x = datasample(possible_x, 1);
        % pick  negative exemplar z > 2*dist_neg from the search area
        pos_x = find(possible_x==rand_x);
        % remove candidates z from a region of 2*dist_neg around X
        possible_x(max(1,pos_x-dist_neg):min(npx, pos_x+dist_neg)) = [];
        if ~isempty(possible_x)
            rand_z = datasample(possible_x, 1);
            found = true;
        end
    end
    assert(trials<100, 'valid conditions for negative pairs are too strict.');
    z = imdb_video.objects{rand_vid}{rand_z};
    x = imdb_video.objects{rand_vid}{rand_x};
end

% -----------------------------------------------------------------------------------------------------------------------
function imo = acquire_augment(im, imageSize, rgbVariance, aug_opts, add_aug_opts)
% Apply transformations and augmentations to original crops
% -----------------------------------------------------------------------------------------------------------------------
    if numel(imageSize) == 1
        imageSize = [imageSize, imageSize];
    end
    if numel(aug_opts.maxTranslate) == 1
        aug_opts.maxTranslate = [aug_opts.maxTranslate, aug_opts.maxTranslate];
    end

    imt = im;
    if size(imt,3) == 1
        imt = cat(3, imt, imt, imt);
    end

    w = size(imt,2) ;
    h = size(imt,1) ;
    cx = (w+1)/2;
    cy = (h+1)/2;

    if aug_opts.stretch
        scale = (1+aug_opts.maxStretch*(-1+2*rand(2,1)));
        sz = round(min(imageSize(1:2)' .* scale, [h;w]));
    else
        sz = imageSize;
    end

    if aug_opts.translate
        if isempty(aug_opts.maxTranslate)
            % Take any crop within the image.
            dx = randi(w - sz(2) + 1, 1) ;
            dy = randi(h - sz(1) + 1, 1) ;
        else
            % Take crop within maxTranslate of center.
            mx = min(aug_opts.maxTranslate(2), floor((w-sz(2))/2));
            my = min(aug_opts.maxTranslate(1), floor((h-sz(1))/2));
            % Check bounds:
            % dx = (w+1)/2 - (sz(2)-1)/2 - (w-sz(2))/2
            %    = (w+1 - sz(2)+1 - w+sz(2))/2
            %    = 1 + (w - sz(2) - w+sz(2))/2
            %    = 1
            % dx + sz(2)-1 = (w+1)/2 - (sz(2)-1)/2 + (w-sz(2))/2 + sz(2)-1
            %              = (w+1 - sz(2)+1 + w-sz(2) + 2*sz(2)-2)/2
            %              = (w - sz(2) + w-sz(2) + 2*sz(2))/2
            %              = (w + w)/2
            %              = w
            dx = cx - (sz(2)-1)/2 + randi([-mx, mx], 1);
            dy = cy - (sz(1)-1)/2 + randi([-my, my], 1);
        end
    else
        % Take crop at center.
        dx = cx - (sz(2)-1)/2;
        dy = cy - (sz(1)-1)/2;
    end

    % flip = rand > 0.5 ;
    % if flip, sx = fliplr(sx) ; end
    
    if ~aug_opts.color
        switch aug_opts.input_method
            case 'crop'
                sx = round(linspace(dx, dx+sz(2)-1, imageSize(2))) ;
                sy = round(linspace(dy, dy+sz(1)-1, imageSize(1))) ;
                imo = imt(sy,sx,:);
                imo = add_augment(imo, add_aug_opts);  % add your augment code in this function
            case 'resize'
                imo = imresize(imt, [imageSize(2), imageSize(1)]);
                imo = add_augment(imo, add_aug_opts);  % add your augment code in this function
        end
    else
        offset = reshape(rgbVariance * randn(3,1), 1,1,3);
        switch aug_opts.input_method
            case 'crop'
                sx = round(linspace(dx, dx+sz(2)-1, imageSize(2)));
                sy = round(linspace(dy, dy+sz(1)-1, imageSize(1)));
                imo = bsxfun(@minus, imt(sy,sx,:), offset);
                imo = add_augment(imo, add_aug_opts);  % add your augment code in this function
            case 'resize'
                imo = bsxfun(@minus,imresize(imt, [imageSize(2), imageSize(1)]), offset);
                imo = add_augment(imo, add_aug_opts);  % add your augment code in this function
        end
    end
end

function imo = add_augment(im, add_aug_opts)
    % judge if there has add_aug_opts or not
    if isempty(add_aug_opts) || add_aug_opts.flag == 0
        imo = im;
    else
        imo = im;
        %% here we get the default aug opts
        aug_params = [];
        aug_params.blur = add_aug_opts.blur;
        aug_params.sharpen = add_aug_opts.sharpen;
        aug_params.emboss = add_aug_opts.emboss;
        aug_params.edgeDetect = add_aug_opts.edgeDetect;
        aug_params.additiveGaussianNoise = add_aug_opts.additiveGaussianNoise;
        aug_params.dropout = add_aug_opts.dropout;
        aug_params.invert = add_aug_opts.invert;
        aug_params.add = add_aug_opts.add;
        aug_params.multiply = add_aug_opts.multiply;
        aug_params.contrastNormalization = add_aug_opts.contrastNormalization;
        aug_params.grayScale = add_aug_opts.grayScale;
        aug_params.gammaAdjust = add_aug_opts.gammaAdjust;
        aug_params.default_methods = {'blur', 'sharpen', 'emboss', ...
                                      'edgeDetect', 'additiveGaussianNoise', ...
                                      'dropout', 'invert', 'add', 'multiply', ...
                                      'contrastNormalization', 'grayScale', ...
                                      'gammaAdjust'};
        aug_params.random_num_of_methods = add_aug_opts.random_num_of_methods;
        aug_params.min_value = add_aug_opts.min_value;
        aug_params.max_value = add_aug_opts.max_value;
        %% get the aug methods from setting
        apply_methods = choose_by_flag(aug_params);
        assert(aug_params.random_num_of_methods <= size(apply_methods, 2));
       %% for augmetation, we just randomly do 0~andom_num_of_methods of them.
        method_random_indexs = randperm(size(apply_methods, 2));
        method_random_indexs = method_random_indexs(1:aug_params.random_num_of_methods);
        for i = 1:randi(aug_params.random_num_of_methods)    % here use randi to control the num of final applied augment methods
            method = apply_methods{method_random_indexs(i)};
            switch method
                case 'blur'
                    blur_types = {'gaussian', 'average', 'median'};
                    blur_random_index = randi([1, size(blur_types, 2)], 1);
                    switch blur_types{blur_random_index}
                        case 'gaussian'
                            %fprintf('gaussian\n');
                            imo = gaussianBlur(imo, aug_params.blur.methods.gaussian);
                        case 'average'
                            %fprintf('average\n');
                            imo = averageBlur(imo, aug_params.blur.methods.average);
                        case 'median'
                            %fprintf('median\n');
                            imo = medianBlur(imo, aug_params.blur.methods.median);
                        otherwise
                            % do nothing here
                    end
                case 'sharpen'
                    imo = sharpen(imo, aug_params.sharpen);
                case 'emboss'
                    imo = emboss(imo, aug_params.emboss);
                case 'edgeDetect'
                    edgeDetect_types = {'edges', 'direct_edges'};
                    edgeDetect_random_index = randi([1, size(edgeDetect_types, 2)], 1);
                    switch edgeDetect_types{edgeDetect_random_index}
                        case 'edges'
                            imo = edges(im, aug_params.edgeDetect.methods.edges);
                        case 'direct_edges'
                            imo = directedEdges(im, aug_params.edgeDetect.methods.direct_edges);
                        otherwise
                            % do nothing here
                    end
                case 'additiveGaussianNoise'
                    %fprintf('additiveGaussianNoise\n');
                    imo = additiveGaussianNoise(im, aug_params.additiveGaussianNoise, aug_params.min_value, aug_params.max_value);
                case 'dropout'
                    imo = dropout(im, aug_params.dropout, aug_params.min_value, aug_params.max_value);
                case 'invert'
                    imo = invert(im, aug_params.invert, aug_params.min_value, aug_params.max_value);
                case 'add'                    
                    %fprintf('add\n');
                    imo = add(im, aug_params.add, aug_params.min_value, aug_params.max_value);
                case 'multiply'                    
                    %fprintf('multiply\n');
                    imo = multiply(im, aug_params.multiply, aug_params.min_value, aug_params.max_value);
                case 'contrastNormalization'                    
                    %fprintf('contrastNormalization\n');
                    imo = contrastNormalization(im, aug_params.contrastNormalization, aug_params.min_value, aug_params.max_value);
                case 'grayScale'                    
                    %fprintf('grayScale\n');
                    imo = grayScale(im, aug_params.grayScale, aug_params.min_value, aug_params.max_value);
                case 'gammaAdjust'                  
                    %fprintf('gammaAdjust\n');
                    imo = gammaAdjust(im, aug_params.gammaAdjust);
                otherwise
                    % do noting here
            end
        end
    end
end

% -----------------------------------------------------------------------------------------------------------------------
function apply_methods = choose_by_flag(aug_params)
%% choose the aug methods from default
% -----------------------------------------------------------------------------------------------------------------------
    default_methods = aug_params.default_methods;
    apply_methods = {};
    j = 1;
    for i = 1:size(default_methods, 2)
        switch(default_methods{i})
            case 'blur'
                if aug_params.blur.flag == 1
                    apply_methods{j} =  'blur';
                    j = j+1;
                end
            case 'sharpen'
                if aug_params.sharpen.flag == 1
                    apply_methods{j} =  'sharpen';
                    j = j+1;
                end
            case 'emboss'
                if aug_params.emboss.flag == 1
                    apply_methods{j} =  'emboss';
                    j = j+1;
                end
            case 'edgeDetect'
                if aug_params.edgeDetect.flag == 1
                    apply_methods{j} =  'edgeDetect';
                    j = j+1;
                end
            case 'additiveGaussianNoise'
                if aug_params.additiveGaussianNoise.flag == 1
                    apply_methods{j} =  'additiveGaussianNoise';
                    j = j+1;
                end
            case 'dropout'
                if aug_params.dropout.flag == 1
                    apply_methods{j} =  'dropout';
                    j = j+1;
                end
            case 'invert'
                if aug_params.invert.flag == 1
                    apply_methods{j} =  'invert';
                    j = j+1;
                end
            case 'add'
                if aug_params.add.flag == 1
                    apply_methods{j} =  'add';
                    j = j+1;
                end
            case 'multiply'
                if aug_params.multiply.flag == 1
                    apply_methods{j} =  'multiply';
                    j = j+1;
                end
            case 'contrastNormalization'
                if aug_params.contrastNormalization.flag == 1
                    apply_methods{j} =  'contrastNormalization';
                    j = j+1;
                end
            case 'grayScale'
                if aug_params.grayScale.flag == 1
                    apply_methods{j} =  'grayScale';
                    j = j+1;
                end
            case 'gammaAdjust'
                if aug_params.gammaAdjust.flag == 1
                    apply_methods{j} = 'gammaAdjust';
                    j = j+1;
                end
        end
    end
end

% -----------------------------------------------------------------------------------------------------------------------
function imo = gaussianBlur(im, gaussian_opts)
% gaussian filter for the image
% -----------------------------------------------------------------------------------------------------------------------
    min_sigma = gaussian_opts.min_sigma;
    max_sigma = gaussian_opts.max_sigma;
    kernel_size = gaussian_opts.kernel_size;
    sigma = random('uniform', min_sigma, max_sigma, 1);
    H = fspecial('gaussian', [kernel_size, kernel_size], sigma);
    imo = imfilter(im, H, 'replicate');
end

% -----------------------------------------------------------------------------------------------------------------------
function imo = averageBlur(im, average_opts)
% average filter for the image
% -----------------------------------------------------------------------------------------------------------------------
    min_kernel_size = average_opts.min_kernel_size;
    max_kernel_size = average_opts.max_kernel_size;
    kernel_size = randi([min_kernel_size, max_kernel_size], 1);
    H = fspecial('average', [kernel_size, kernel_size]);
    imo = imfilter(im, H, 'replicate');
end

% -----------------------------------------------------------------------------------------------------------------------
function imo = medianBlur(im, median_opts)
% median filter for the image
% -----------------------------------------------------------------------------------------------------------------------
    min_kernel_size = median_opts.min_kernel_size;
    max_kernel_size = median_opts.max_kernel_size;
    kernel_size = randi([min_kernel_size, max_kernel_size], 1);
    kernel_size = fix(kernel_size/2)*2+1;  % keep an odd number
    imo = medfilt3(im, [kernel_size, kernel_size, size(im, 3)]);
end

% -----------------------------------------------------------------------------------------------------------------------
function imo = sharpen(im, sharpen_opts)
% sharpen for the image
% -----------------------------------------------------------------------------------------------------------------------
    min_alpha = sharpen_opts.min_alpha;
    max_alpha = sharpen_opts.max_alpha;
    min_lightness = sharpen_opts.min_lightness;
    max_lightness = sharpen_opts.max_lightness;
    alpha = random('uniform', min_alpha, max_alpha, 1);
    lightness = random('uniform', min_lightness, max_lightness, 1);
    matrix_nochange = [0, 0, 0;
                       0, 1, 0;
                       0, 0, 0];
    matrix_effect = [-1, -1, -1;
                     -1, 8+lightness, -1;
                     -1, -1, -1];
    H = (1-alpha) * matrix_nochange + alpha * matrix_effect;
    imo = imfilter(im, H, 'replicate');
end

% -----------------------------------------------------------------------------------------------------------------------
function imo = emboss(im, emboss_opts)
% emboss for the image
% -----------------------------------------------------------------------------------------------------------------------
    min_alpha = emboss_opts.min_alpha;
    max_alpha = emboss_opts.max_alpha;
    min_strength = emboss_opts.min_strength;
    max_strength = emboss_opts.max_strength;
    alpha = random('uniform', min_alpha, max_alpha, 1);
    strength = random('uniform', min_strength, max_strength, 1);
    matrix_nochange = [0, 0, 0;
                       0, 1, 0;
                       0, 0, 0];
    matrix_effect = [-1-strength, 0-strength, 0;
                     0-strength, 1, 0+strength;
                     0, 0+strength, 1+strength];
    H = (1-alpha) * matrix_nochange + alpha * matrix_effect;
    imo = imfilter(im, H, 'replicate');
end

% -----------------------------------------------------------------------------------------------------------------------
function imo = edges(im, edges_opts)
% edges for the image
% -----------------------------------------------------------------------------------------------------------------------
    min_alpha = edges_opts.min_alpha;
    max_alpha = edges_opts.max_alpha;
    alpha = random('uniform', min_alpha, max_alpha, 1);
    matrix_nochange = [0, 0, 0;
                       0, 1, 0;
                       0, 0, 0];
    matrix_effect = [0, 1, 0;
                     1, -4, 1;
                     0, 1, 0];
    H = (1-alpha) * matrix_nochange + alpha * matrix_effect;
    imo = imfilter(im, H, 'replicate');
end

% -----------------------------------------------------------------------------------------------------------------------
function imo = directedEdges(im, direct_edges_opts)
% directed edges for the image
% -----------------------------------------------------------------------------------------------------------------------
    min_alpha = direct_edges_opts.min_alpha;
    max_alpha = direct_edges_opts.max_alpha;
    min_direction = direct_edges_opts.min_direction;
    max_direction = direct_edges_opts.max_direction;
    alpha = random('uniform', min_alpha, max_alpha, 1);
    direction = random('uniform', min_direction, max_direction, 1);
    matrix_nochange = [0, 0, 0;
                       0, 1, 0;
                       0, 0, 0];
    deg = mod(fix(direction*360), 360);
    rad = deg * pi / 180;
    x = cos(rad - 0.5*pi);
    y = sin(rad - 0.5*pi);
    direction_vector = [x, y];
    matrix_effect = [0, 0, 0;
                     0, 0, 0;
                     0, 0, 0];
    x = [0, 1, 2];
    y = [0, 1, 2];
    for i = 1:3
        for j=1:3
            cell_vector = [x(i)-1, y(j)-1];
            if ~all(cell_vector==[0, 0])
                distance_deg = 180 * acos(dot(cell_vector, direction_vector)/sqrt(dot(cell_vector, cell_vector))/sqrt(dot(direction_vector, direction_vector))) / pi;
                distance = distance_deg / 180;
                similarity = (1-distance)^4;
                matrix_effect(y(j)+1, x(i)+1) = similarity;
            end
        end
    end
    matrix_effect = matrix_effect / sum(sum(matrix_effect));
    matrix_effect = matrix_effect * (-1);
    matrix_effect(2, 2) = 1;
    H = (1-alpha) * matrix_nochange + alpha * matrix_effect;
    imo = imfilter(im, H, 'replicate');
end

% -----------------------------------------------------------------------------------------------------------------------
function imo = additiveGaussianNoise(im, additiveGaussianNoise_opts, min_value, max_value)
% additiveGaussianNoise for the image
% -----------------------------------------------------------------------------------------------------------------------
    min_scale = additiveGaussianNoise_opts.min_scale;
    max_scale = additiveGaussianNoise_opts.max_scale;
    per_channel = additiveGaussianNoise_opts.per_channel;
    scale = random('uniform', min_scale, max_scale, 1);
    prob = random('uniform', 0, 1.0, 1);
    if prob < per_channel
        sample = normrnd(0, scale, size(im, 1), size(im, 2));
        samples = cat(3, sample, sample, sample);
    else
        samples = normrnd(0, scale, size(im, 1), size(im, 2), size(im, 3));
    end
    imo = double(im) + samples;
    imo(imo>max_value) = max_value;
    imo(imo<min_value) = min_value;
    imo = single(imo);
end

% -----------------------------------------------------------------------------------------------------------------------
function imo = dropout(im, dropout_opts, min_value, max_value)
% dropout for the image
% -----------------------------------------------------------------------------------------------------------------------
    min_p = dropout_opts.min_p;
    max_p = dropout_opts.max_p;
    per_channel = dropout_opts.per_channel;
    per_channel = binornd(1, per_channel, 1);
    if per_channel == 1
        samples = binornd(1, random('uniform', 1-max_p, 1-min_p, 1), size(im, 1), size(im, 2), 3);
    else
        sample = binornd(1, random('uniform', 1-max_p, 1-min_p, 1), size(im, 1), size(im, 2), 1);
        samples = cat(3, sample, sample, sample);
    end
    imo = im .* samples;
    imo(imo>max_value) = max_value;
    imo(imo<min_value) = min_value;
    imo = single(imo);
end

% -----------------------------------------------------------------------------------------------------------------------
function imo = invert(im, invert_opts, min_value, max_value)
% invert for the image
% -----------------------------------------------------------------------------------------------------------------------
    imo = double(im);
    p = invert_opts.p;
    per_channel = invert_opts.per_channel;
    per_channel = binornd(1, per_channel, 1);
    if per_channel == 1
        p_samples = binornd(1, p, 1, 3);
        for i = 1:size(p_samples, 2)
            if p_samples(i)>0.5
                image_c = imo(:,:,i);
                distance_from_min = abs(image_c - min_value);
                imo(:,:,i) = -1*distance_from_min + max_value;
            end
        end
    else
        p_sample = binornd(1, p, 1);
        if p_sample > 0.5
            distance_from_min = abs(imo - min_value);
            imo  = -1*distance_from_min + max_value;
        end
    end
    imo(imo>max_value) = max_value;
    imo(imo<min_value) = min_value;
    imo = single(imo);    
end

% -----------------------------------------------------------------------------------------------------------------------
function imo = add(im, add_opts, min_value, max_value)
% add for the image
% -----------------------------------------------------------------------------------------------------------------------
    imo = double(im);
    a = add_opts.a;
    b = add_opts.b;
    per_channel = add_opts.per_channel;
    per_channel = binornd(1, per_channel, 1);
    if per_channel == 1
        samples = randi([a, b+1], 1, 3);
        for i = 1:size(samples, 2)
            imo(:,:,i) = imo(:,:,i)+samples(i);
        end
    else
        sample = randi([a, b+1], 1, 1);
        imo = imo + sample;
    end
    imo(imo>max_value) = max_value;
    imo(imo<min_value) = min_value;
    imo = single(imo);    
end

% -----------------------------------------------------------------------------------------------------------------------
function imo = multiply(im, multiply_opts, min_value, max_value)
% multiply for the image
% -----------------------------------------------------------------------------------------------------------------------
    imo = double(im);
    min_scale = multiply_opts.min_scale;
    max_scale = multiply_opts.max_scale;
    per_channel = multiply_opts.per_channel;
    per_channel = binornd(1, per_channel, 1);
    if per_channel == 1
        samples = random('uniform', min_scale, max_scale, 1, 3);
        for i = 1:size(samples, 2)
            imo(:,:,i) = samples(i)*imo(:,:,i);
        end
    else
        sample = random('uniform', min_scale, max_scale, 1);
        imo = sample*imo;
    end
    imo(imo>max_value) = max_value;
    imo(imo<min_value) = min_value;
    imo = single(imo);    
end

% -----------------------------------------------------------------------------------------------------------------------
function imo = contrastNormalization(im, contrastNormalization_opts, min_value, max_value)
% contrastNormalization for the image
% -----------------------------------------------------------------------------------------------------------------------
    imo = double(im);
    min_alpha = contrastNormalization_opts.min_alpha;
    max_alpha = contrastNormalization_opts.max_alpha;
    per_channel = contrastNormalization_opts.per_channel;
    per_channel = binornd(1, per_channel, 1);
    if per_channel == 1
        alphas = random('uniform', min_alpha, max_alpha, 1, 3);
        for i = 1:size(alphas, 2)
            imo(:,:,i) = alphas(i) * (imo(:,:,i)-128) + 128;
        end
    else
        alpha = random('uniform', min_alpha, max_alpha, 1);
        imo = alpha * (imo - 128) + 128;
    end
    imo(imo>max_value) = max_value;
    imo(imo<min_value) = min_value;
    imo = single(imo);    
end

% -----------------------------------------------------------------------------------------------------------------------
function imo = grayScale(im, garyScale_opts, min_value, max_value)
% grayScale for the image
% -----------------------------------------------------------------------------------------------------------------------
    min_alpha = garyScale_opts.min_alpha;
    max_alpha = garyScale_opts.max_alpha;
    eps = garyScale_opts.eps;
    alpha = random('uniform', min_alpha, max_alpha, 1);
    im_to_cs = single(rgb2gray(uint8(im)));
    im_to_cs = cat(3, im_to_cs, im_to_cs, im_to_cs);
    if alpha >= 1-eps
        imo = im_to_cs;
    elseif alpha <= eps
        imo = im;
    else
        imo = alpha * im_to_cs + (1-alpha) * im;
    end
    imo(imo>max_value) = max_value;
    imo(imo<min_value) = min_value;
end

% -----------------------------------------------------------------------------------------------------------------------
function imo = gammaAdjust(im, gammaAdjust_opts)
% gamma adjust for the image
    min_gamma = gammaAdjust_opts.min_gamma;
    max_gamma = gammaAdjust_opts.max_gamma;
    gamma = random('uniform', min_gamma, max_gamma, 1);
    im_gray = rgb2gray(uint8(im));
    imo = single(imadjust(im_gray, [], [], gamma));
    imo = cat(3, imo, imo, imo);
end

% -----------------------------------------------------------------------------------------------------------------------
function [bbox_z, bbox_x] = get_objects_extent_crop(object_z_extent, object_x_extent,crop_z, crop_x)
% Compute objects bbox within crops
% bboxes are returned as [xmin, ymin, width, height]
% -----------------------------------------------------------------------------------------------------------------------
    % enforce the size_z and size_x
    size_z = 127;
    size_x = 255;
    
    % TODO: this should passed from experiment as default
    context_amount = 0.5;

    % getting in-crop object extent for Z
    [w_z, h_z] = deal(object_z_extent(3), object_z_extent(4));
    wc_z = w_z + context_amount*(w_z+h_z);
    hc_z = h_z + context_amount*(w_z+h_z);
    s_z = sqrt(wc_z*hc_z);
    scale_z = size_z / s_z;
    ws_z = w_z * scale_z;
    hs_z = h_z * scale_z;
    bbox_z = [(crop_z-ws_z)/2, (crop_z-hs_z)/2, ws_z, hs_z];

    % getting in-crop object extent for X
    [w_x, h_x] = deal(object_x_extent(3), object_x_extent(4));
    wc_x = w_x + context_amount*(w_x+h_x);
    hc_x = h_x + context_amount*(w_x+h_x);
    s_xz = sqrt(wc_x*hc_x);
    scale_xz = size_z / s_xz;

    d_search = (size_x - size_z)/2;
    pad = d_search/scale_xz;
    s_x = s_xz + 2*pad;
    scale_x = size_x / s_x;
    ws_x = w_x * scale_x;
    hs_x = h_x * scale_x;
    bbox_x = [(crop_x-ws_x)/2, (crop_x-hs_x)/2, ws_x, hs_x];
end

% -----------------------------------------------------------------------------------------------------------------------
function [bbox_z, bbox_x] = get_objects_extent_resize(object_z_extent, object_x_extent, size_z, size_x)
% Compute objects bbox within crops
% bboxes are returned as [xmin, ymin, width, height]
% -----------------------------------------------------------------------------------------------------------------------
    % TODO: this should passed from experiment as default
    context_amount = 0.5;

    % getting in-crop object extent for Z
    [w_z, h_z] = deal(object_z_extent(3), object_z_extent(4));
    wc_z = w_z + context_amount*(w_z+h_z);
    hc_z = h_z + context_amount*(w_z+h_z);
    s_z = sqrt(wc_z*hc_z);
    scale_z = size_z / s_z;
    ws_z = w_z * scale_z;
    hs_z = h_z * scale_z;
    bbox_z = [(size_z-ws_z)/2, (size_z-hs_z)/2, ws_z, hs_z];

    % getting in-crop object extent for X
    [w_x, h_x] = deal(object_x_extent(3), object_x_extent(4));
    wc_x = w_x + context_amount*(w_x+h_x);
    hc_x = h_x + context_amount*(w_x+h_x);
    s_xz = sqrt(wc_x*hc_x);
    scale_xz = size_z / s_xz;

    d_search = (size_x - size_z)/2;
    pad = d_search/scale_xz;
    s_x = s_xz + 2*pad;
    scale_x = size_x / s_x;
    ws_x = w_x * scale_x;
    hs_x = h_x * scale_x;
    bbox_x = [(size_x-ws_x)/2, (size_x-hs_x)/2, ws_x, hs_x];
end
