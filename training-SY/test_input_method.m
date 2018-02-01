load temp.mat 

%{
img_z = imout_z(:,:,:,1);
img_x = imout_x(:,:,:,1);

[bbox_z, bbox_x] = get_objects_extent_crop(double(objects.z{1}.extent), ...
               double(objects.x{1}.extent), opts.exemplarSize, opts.instanceSize);

bbox_z = uint32(bbox_z);
bbox_x = uint32(bbox_x);

[state_z, result_z] = drawRect(img_z/255, bbox_z, 1);
[state_x, result_x] = drawRect(img_x/255, bbox_x, 1);
%}

img_z = crops_z{1};
cx = 128;
cy = 128;
dx = cx - (127-1)/2;
dy = cy - (127-1)/2;
sx = round(linspace(dx, dx+127-1, 127)) ;
sy = round(linspace(dy, dy+127-1, 127)) ;
img_z = img_z(sy,sx,:);
img_x = crops_x{1};

img_z = imresize(img_z, [opts.exemplarSize, opts.exemplarSize]);
img_x = imresize(img_x, [opts.instanceSize, opts.instanceSize]);

[bbox_z, bbox_x] = get_objects_extent_resize(double(objects.z{1}.extent), ...
    double(objects.x{1}.extent), opts.exemplarSize, opts.instanceSize);

bbox_z = uint32(bbox_z);
bbox_x = uint32(bbox_x);

[state_z, result_z] = drawRect(img_z/255, bbox_z, 1);
[state_x, result_x] = drawRect(img_x/255, bbox_x, 1);

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
