function net = make_branch_test3_nodilation(varargin)
    opts.exemplarSize = [77 77];
    opts.instanceSize = [157 157];
    opts.last_layer = 'merge3';
    opts.num_out     = [64, 128, 256];
    opts.num_in      = [ 3,  64, 128];
    opts.conv_stride = [ 2,   1,   1];
    opts.pool_stride = [ 2 ];
    opts.scale = 1 ;
    opts.initBias = 0.1 ;
    opts.weightDecay = 1 ;
    opts.weightInitMethod = 'gaussian';
    opts.batchNormalization = false ;
    opts.cudnnWorkspaceLimit = 1024*1024*1024 ; % 1GB
    opts = vl_argparse(opts, varargin) ;

    if numel(opts.exemplarSize) == 1
        opts.exemplarSize = [opts.exemplarSize, opts.exemplarSize];
    end
    if numel(opts.instanceSize) == 1
        opts.instanceSize = [opts.instanceSize, opts.instanceSize];
    end

    net = struct();

    net.layers = {} ;

    for i = 1:numel(opts.num_out)
        switch i
            case 1
                net = add_block(net, opts, '1', 5, 5, ...
                                opts.num_in(i), opts.num_out(i), ...
                                opts.conv_stride(i), 2, 1) ;
                net = add_norm(net, opts, '1') ;
                net.layers{end+1} = struct('type', 'pool', 'name', 'pool1', ...
                                           'method', 'max', ...
                                           'pool', [3 3], ...
                                           'stride', opts.pool_stride(i), ...
                                           'pad', 1) ;
            case 2
                net = add_block(net, opts, '2', 3, 3, ...
                                opts.num_in(i), opts.num_out(i), ...
                                opts.conv_stride(i), 1, 1) ;
                net = add_norm(net, opts, '2') ;
            case 3
                net = add_block(net, opts, '3', 3, 3, ...
                                opts.num_in(i), opts.num_out(i), ...
                                opts.conv_stride(i), 1, 1) ;
        end
    end
    
    % Check if the receptive field covers full image
    [ideal_exemplar, ~] = ideal_size(net, opts.exemplarSize);
    [ideal_instance, ~] = ideal_size(net, opts.instanceSize);
    assert(sum(opts.exemplarSize==ideal_exemplar)==2, 'exemplarSize is not ideal.');
    assert(sum(opts.instanceSize==ideal_instance)==2, 'instanceSize is not ideal.');
    
    % Fill in default values
    net = vl_simplenn_tidy(net);
    
    % change simplenn to dagnn
    if ~isa(net, 'dagnn.DagNN')
        net = dagnn.DagNN.fromSimpleNN(net);
    end
    
    net = merge_layer(net, opts, '3');

    ind = find(arrayfun(@(l) strcmp(l.name, opts.last_layer), net.layers));
    if numel(ind) ~= 1
        error(sprintf('could not find one layer: %s', opts.last_layer));
    end
    net.layers = net.layers(1:ind);

end

% --------------------------------------------------------------------
function net = add_block(net, opts, id, h, w, in, out, stride, pad, dilate)
% --------------------------------------------------------------------
    convOpts = {'CudnnWorkspaceLimit', opts.cudnnWorkspaceLimit} ;
    net.layers{end+1} = struct('type', 'conv', 'name', sprintf('conv%s', id), ...
                               'weights', {{init_weight(opts, h, w, in, out, 'single'), ...
                                            zeros(out, 1, 'single')}}, ...
                               'stride', stride, ...
                               'pad', pad, ...
                               'dilate', dilate, ...
                               'learningRate', [1 2], ...
                               'weightDecay', [opts.weightDecay 0], ...
                               'opts', {convOpts}) ;
    if opts.batchNormalization
        net.layers{end+1} = struct('type', 'bnorm', 'name', sprintf('bn%s',id), ...
                                   'weights', {{ones(out, 1, 'single'), ...
                                                zeros(out, 1, 'single'), ...
                                                zeros(out, 2, 'single')}}, ...
                                   'learningRate', [2 1 0.05], ...
                                   'weightDecay', [0 0]) ;
    end
    net.layers{end+1} = struct('type', 'relu', 'name', sprintf('relu%s',id)) ;
end

% --------------------------------------------------------------------
function net = add_norm(net, opts, id)
% --------------------------------------------------------------------
    if ~opts.batchNormalization
      net.layers{end+1} = struct('type', 'normalize', ...
                                 'name', sprintf('norm%s', id), ...
                                 'param', [5 1 0.0001/5 0.75]) ;
    end
end

% --------------------------------------------------------------------
function net = add_dropout(net, opts, id)
% --------------------------------------------------------------------
    net.layers{end+1} = struct('type', 'dropout', ...
                                 'name', sprintf('dropout%s', id), ...
                                 'rate', 0.5) ;
end

function net = merge_layer(net, opts, id)
    net.addLayer('merge3', dagnn.Concat(), {'x4', 'x9'}, {'x10'})    
end
