function net = make_branch_airnet_nodilation(varargin)
    opts.exemplarSize = [127 127];
    opts.instanceSize = [255 255];
    opts.last_layer = 'conv5b';
    
    opts.cudnnWorkspaceLimit = 1024*1024*1024 ; % 1GB
    opts = vl_argparse(opts, varargin) ;

    if numel(opts.exemplarSize) == 1
        opts.exemplarSize = [opts.exemplarSize, opts.exemplarSize];
    end
    if numel(opts.instanceSize) == 1
        opts.instanceSize = [opts.instanceSize, opts.instanceSize];
    end

    net = create_airnet(opts);
    
    net = net2last_layer(net, opts.last_layer);
    
    % Check if the receptive field covers full image
    [ideal_exemplar, ~] = ideal_size_dagnn(net, opts.exemplarSize);
    [ideal_instance, ~] = ideal_size_dagnn(net, opts.instanceSize);
    assert(sum(opts.exemplarSize==ideal_exemplar)==2, 'exemplarSize is not ideal.');
    assert(sum(opts.instanceSize==ideal_instance)==2, 'instanceSize is not ideal.');

end

% --------------------------------------------------------------------
function net = create_airnet(opts)
    net = dagnn.DagNN();
    lastAdded.var = 'input';
    lastAdded.depth = 3;
    
    % conv1
    [net, lastAdded] = Conv(net, ...
                            'conv1', 7, 64, lastAdded, opts, ...
                            'relu', true, ...
                            'bias', false, ...
                            'downsample', true);
    [net, lastAdded] = Pool(net, 'conv1', 2, 2, 0, 'max', lastAdded);  
    % conv2
    [net, lastAdded] = ResBlock(net, 'conv2a', 64, 1, true, lastAdded, opts);
    [net, lastAdded] = ResBlock(net, 'conv2b', 64, 1, false, lastAdded, opts);
    % conv3
    [net, lastAdded] = ResBlock(net, 'conv3a', 128, 1, true, lastAdded, opts);
    [net, lastAdded] = InceptionResBlock(net, 'conv3b', 128, lastAdded, opts);
    % conv4
    [net, lastAdded] = ResBlock(net, 'conv4a', 256, 1, true, lastAdded, opts);
    [net, lastAdded] = InceptionResBlock(net, 'conv4b', 256, lastAdded, opts);
    % conv5
    [net, lastAdded] = ResBlock(net, 'conv5a', 384, 1, true, lastAdded, opts);
    [net, lastAdded] = InceptionResBlock(net, 'conv5b', 384, lastAdded, opts);
    
    net.initParams() ;
end

function [net, lastAdded] = Conv(net, name, ksize, depth, lastAdded, opts, varargin)
% Helper function to add a Convolutional + BatchNorm + ReLU
% sequence to the network.
  args.relu = true ;
  args.downsample = false ;
  args.bias = false ;
  args = vl_argparse(args, varargin) ;
  if args.downsample, stride = 2 ; else stride = 1 ; end
  if args.bias, pars = {[name '_f'], [name '_b']} ; else pars = {[name '_f']} ; end
  net.addLayer(name, ...
               dagnn.Conv('size', [ksize ksize lastAdded.depth depth], ...
                          'stride', stride, ....
                          'pad', (ksize - 1) / 2, ...
                          'hasBias', args.bias, ...
                          'opts', {'cudnnworkspacelimit', opts.cudnnWorkspaceLimit}), ...
               lastAdded.var, ...
               name, ...
               pars) ;
  net.addLayer([name '_bn'], ...
               dagnn.BatchNorm('numChannels', depth, 'epsilon', 1e-5), ...
               name, ...
               [name '_bn'], ...
               {[name '_bn_w'], [name '_bn_b'], [name '_bn_m']}) ;
  lastAdded.depth = depth ;
  lastAdded.var = [name '_bn'] ;
  if args.relu
    net.addLayer([name '_relu'] , ...
                 dagnn.ReLU(), ...
                 lastAdded.var, ...
                 [name '_relu']) ;
    lastAdded.var = [name '_relu'] ;
  end
end

function [net, lastAdded] = Pool(net, name, ksize, stride, pad, method, lastAdded)
% Helper function to add a Pool
% sequence to the network.
  net.addLayer([name '_pool'], ...
               dagnn.Pooling('poolSize', [ksize ksize], ...
                             'stride', stride, ...
                             'pad', pad,  ...
                             'method', method), ...
               lastAdded.var, ...
               [name '_pool']) ;
  lastAdded.var = [name '_pool'];
end

function [net, lastAdded] = ResBlock(net, name, depth, stride, force_branch1, lastAdded, opts) 
    downsample_flag = false;
    if stride == 2
        downsample_flag = true;
    end
    shortcut = lastAdded;
    [net, lastAdded] = Conv(net, ...
                            [name, '_branch2a'], 3, depth, lastAdded, opts, ...
                            'relu', true, ...
                            'bias', false, ...
                            'downsample', downsample_flag);
    [net, lastAdded] = Conv(net, ...
                            [name, '_branch2b'], 3, depth, lastAdded, opts, ...
                            'relu', false, ...
                            'bias', false, ...
                            'downsample', false);
    if stride ~= 1 || force_branch1
        [net, shortcut] = Conv(net, ...
                            [name, '_branch1'], 1, depth, shortcut, opts, ...
                            'relu', false, ...
                            'bias', false, ...
                            'downsample', downsample_flag);
    end
    % Sum layer
    net.addLayer(name , ...
                 dagnn.Sum(), ...
                 {shortcut.var, lastAdded.var}, ...
                 name) ;
    lastAdded.depth = shortcut.depth + lastAdded.depth;
    lastAdded.var = name;
    net.addLayer([name, '_relu'], ...
                 dagnn.ReLU(), ...
                 lastAdded.var, ...
                 [name '_relu']) ;
    lastAdded.var = [name '_relu'] ;
end

function [net, lastAdded] = InceptionResBlock(net, name, depth, lastAdded, opts)
    shortcut1 = lastAdded;
    [net, lastAdded] = Conv(net, ...
                            [name, '_1x1'], 1, depth, lastAdded, opts, ...
                            'relu', true, ...
                            'bias', false, ...
                            'downsample', false);
    shortcut2_1 = lastAdded;
    shortcut2_2 = lastAdded;
    [net, shortcut2_1] = Conv(net, ...
                              [name, '_3x3_reduce'], 3, depth/2, shortcut2_1, opts, ...
                              'relu', true, ...
                              'bias', false, ...
                              'downsample', false);
    [net, shortcut2_1] = Conv(net, ...
                              [name, '_3x3_a'], 3, depth, shortcut2_1, opts, ...
                              'relu', true, ...
                              'bias', false, ...
                              'downsample', false);
    [net, shortcut2_2] = Conv(net, ...
                          [name, '_3x3_b'], 3, depth, shortcut2_2, opts, ...
                          'relu', true, ...
                          'bias', false, ...
                          'downsample', false); 
    % Sum layer
    net.addLayer([name, '_concat'] , ...
                 dagnn.Sum(), ...
                 {lastAdded.var, shortcut2_1.var, shortcut2_2.var}, ...
                 [name, '_concat']) ;
    lastAdded.depth = lastAdded.depth + shortcut2_1.depth + shortcut2_2.depth;
    lastAdded.var = [name, '_concat'];
    [net, lastAdded] = Conv(net, ...
                                [name, '_reduce'], 3, depth, lastAdded, opts, ...         
                                'relu', false, ...
                                'bias', false, ...
                                'downsample', false); 
    net.addLayer(name , ...
                 dagnn.Sum(), ...
                 {lastAdded.var, shortcut1.var}, ...
                 name) ;    
    lastAdded.depth = depth + depth;
    lastAdded.var = name;
    net.addLayer([name, '_relu'], ...
                 dagnn.ReLU(), ...
                 lastAdded.var, ...
                 [name '_relu']) ;
    lastAdded.var = [name '_relu'] ;
end

function net = net2last_layer(net, last_layer)
    layers = net.layers;
    
    index = find(arrayfun(@(l) strcmp(l.name, last_layer), layers));
    for i = length(layers):-1:index+1
        net.removeLayer(layers(i).name)
    end
    
    net.rebuild();
end