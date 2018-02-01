load temp.mat 

img_path = crops_x_string{1};
img_path = strrep(img_path, 'ILSVRC2015_curated', 'ILSVRC2015');
img_path = strrep(img_path, '.00.crop.x.jpg', '.JPEG');

im = imread(img_path);

opts.exemplarSize = 127;
opts.instanceSize = 551;

[im_crop_z, bbox_z, pad_z, im_crop_x, bbox_x, pad_x] = get_crops(im, double(objects.z{1}.extent), ...
    exemplar_size, instance_size, context_amount);

% -----------------------------------------------------------------------------------------------------------------------
function [bbox_z, bbox_x] = get_objects_extent_crop(object_z_extent, object_x_extent, crop_z, crop_x)
% Compute objects bbox within crops
% bboxes are returned as [xmin, ymin, width, height]
% -----------------------------------------------------------------------------------------------------------------------
    % enforce the size_z and size_x
    size_z = crop_z;
    size_x = crop_x;
    
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


% -------------------------------------------------------------------------------------------------------------------
function [im_crop_z, bbox_z, pad_z, im_crop_x, bbox_x, pad_x] = get_crops(im, extent, size_z, size_x, context_amount)
% -------------------------------------------------------------------------------------------------------------------
    %% Get exemplar sample
    % take bbox with context for the exemplar

    bbox = double(extent);
    [cx, cy, w, h] = deal(bbox(1)+bbox(3)/2, bbox(2)+bbox(4)/2, bbox(3), bbox(4));
    wc_z = w + context_amount*(w+h);
    hc_z = h + context_amount*(w+h);
    s_z = sqrt(single(wc_z*hc_z));
    scale_z = size_z / s_z;
    [im_crop_z, left_pad_z, top_pad_z, right_pad_z, bottom_pad_z] = get_subwindow_avg(im, [cy cx], [size_z size_z], [round(s_z) round(s_z)]);
    pad_z = ceil([scale_z*(left_pad_z+1) scale_z*(top_pad_z+1) size_z-scale_z*(right_pad_z+left_pad_z) size_z-scale_z*(top_pad_z+bottom_pad_z+1)]);
    %% Get instance sample
    d_search = (size_x - size_z)/2;
    pad = d_search/scale_z;
    s_x = s_z + 2*pad;
    scale_x = size_x / s_x;
    [im_crop_x, left_pad_x, top_pad_x, right_pad_x, bottom_pad_x] = get_subwindow_avg(im, [cy cx], [size_x size_x], [round(s_x) round(s_x)]);
    pad_x = ceil([scale_x*(left_pad_x+1) scale_x*(top_pad_x+1) size_x-scale_x*(right_pad_x+left_pad_x) size_x-scale_x*(top_pad_x+bottom_pad_x+1)]);
    % Size of object within the crops
    ws_z = w * scale_z;
    hs_z = h * scale_z;
    ws_x = w * scale_x;
    hs_x = h * scale_x;
    bbox_z = [(size_z-ws_z)/2, (size_z-hs_z)/2, ws_z, hs_z];
    bbox_x = [(size_x-ws_x)/2, (size_x-hs_x)/2, ws_x, hs_x];
end

% ---------------------------------------------------------------------------------------------------------------
function [im_patch, left_pad, top_pad, right_pad, bottom_pad] = get_subwindow_avg(im, pos, model_sz, original_sz)
%GET_SUBWINDOW_AVG Obtain image sub-window, padding with avg channel if area goes outside of border
% ---------------------------------------------------------------------------------------------------------------

    avg_chans = [mean(mean(im(:,:,1))) mean(mean(im(:,:,2))) mean(mean(im(:,:,3)))];

    if isempty(original_sz)
        original_sz = model_sz;
    end
    sz = original_sz;
    im_sz = size(im);
    %make sure the size is not too small
    assert(all(im_sz(1:2) > 2));
    c = (sz+1) / 2;

    %check out-of-bounds coordinates, and set them to avg_chans
    context_xmin = round(pos(2) - c(2));
    context_xmax = context_xmin + sz(2) - 1;
    context_ymin = round(pos(1) - c(1));
    context_ymax = context_ymin + sz(1) - 1;
    left_pad = double(max(0, 1-context_xmin));
    top_pad = double(max(0, 1-context_ymin));
    right_pad = double(max(0, context_xmax - im_sz(2)));
    bottom_pad = double(max(0, context_ymax - im_sz(1)));

    context_xmin = context_xmin + left_pad;
    context_xmax = context_xmax + left_pad;
    context_ymin = context_ymin + top_pad;
    context_ymax = context_ymax + top_pad;

    if top_pad || left_pad
        R = padarray(im(:,:,1), [top_pad left_pad], avg_chans(1), 'pre');
        G = padarray(im(:,:,2), [top_pad left_pad], avg_chans(2), 'pre');
        B = padarray(im(:,:,3), [top_pad left_pad], avg_chans(3), 'pre');
        im = cat(3, R, G, B);
    end

    if bottom_pad || right_pad
        R = padarray(im(:,:,1), [bottom_pad right_pad], avg_chans(1), 'post');
        G = padarray(im(:,:,2), [bottom_pad right_pad], avg_chans(2), 'post');
        B = padarray(im(:,:,3), [bottom_pad right_pad], avg_chans(3), 'post');
        im = cat(3, R, G, B);
    end

    xs = context_xmin : context_xmax;
    ys = context_ymin : context_ymax;

    im_patch_original = im(ys, xs, :);
    if ~isequal(model_sz, original_sz)
        im_patch = imresize(im_patch_original, model_sz);
    else
        im_patch = im_patch_original;
    end
end