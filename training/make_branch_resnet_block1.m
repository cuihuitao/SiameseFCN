function net = make_branch_resnet_block1_nodilation(varargin)
    opts.exemplarSize = [77 77];
    opts.instanceSize = [153 153];
    opts.last_layer = 'conv2_1_sum';
    
    opts.cudnnWorkspaceLimit = 1024*1024*1024 ; % 1GB
    opts = vl_argparse(opts, varargin) ;

    if numel(opts.exemplarSize) == 1
        opts.exemplarSize = [opts.exemplarSize, opts.exemplarSize];
    end
    if numel(opts.instanceSize) == 1
        opts.instanceSize = [opts.instanceSize, opts.instanceSize];
    end

    net = create_resnet(opts);
    
    % Check if the receptive field covers full image
    [ideal_exemplar, ~] = ideal_size_dagnn(net, opts.exemplarSize);
    [ideal_instance, ~] = ideal_size_dagnn(net, opts.instanceSize);
    assert(sum(opts.exemplarSize==ideal_exemplar)==2, 'exemplarSize is not ideal.');
    assert(sum(opts.instanceSize==ideal_instance)==2, 'instanceSize is not ideal.');

end

% --------------------------------------------------------------------
function net = create_resnet(opts)
    net = dagnn.DagNN();
    lastAdded.var = 'input';
    lastAdded.depth = 3;
% -------------------------------------
% Add input section
% -------------------------------------
    [net, lastAdded] = Conv(net, ...
                            'conv1', 7, 64, lastAdded, opts, ...
                            'relu', true, ...
                            'bias', false, ...
                            'downsample', true);
    net.addLayer(...
               'conv1_pool', ...
               dagnn.Pooling('poolSize', [3 3], ...
                             'stride', 2, ...
                             'pad', 1,  ...
                             'method', 'max'), ...
               lastAdded.var, ...
               'conv1') ;
    lastAdded.var = 'conv1';
% -------------------------------------
% Add intermediate sections
% -------------------------------------
    for s = 2:2
        switch s
            case 2, sectionLen = 1 ; % 3 => we change it to 1 for just one block
            case 3, sectionLen = 4 ; % 8 ;
            case 4, sectionLen = 6 ; % 23 ; % 36 ;
            case 5, sectionLen = 3 ;
        end
        %-------------------------------------------------
        % Add intermediate segments for each section
        for l = 1:sectionLen
            depth = 2^(s+4) ;
            sectionInput = lastAdded ;
            name = sprintf('conv%d_%d', s, l)  ;

            % Optional adapter layer
            if l == 1
                [net, lastAdded] = Conv(net, ...
                                        [name '_adapt_conv'], 1, 2^(s+6), lastAdded, opts, ...
                                        'downsample', s >= 3, ...
                                        'relu', false) ;
            end
            sumInput = lastAdded ;
            % ABC: 1x1, 3x3, 1x1; downsample if first segment in section from
            % section 2 onwards.
            lastAdded = sectionInput ;
            [net, lastAdded] = Conv(net, ...
                                    [name 'a'], 1, 2^(s+4), lastAdded, opts) ;
            [net, lastAdded] = Conv(net, ...
                                    [name 'b'], 3, 2^(s+4), lastAdded, opts, ...
                                    'downsample', (s >= 3) & l == 1) ;
            [net, lastAdded] = Conv(net, ...
                                    [name 'c'], 1, 2^(s+6), lastAdded, opts, ...
                                    'relu', false) ;
            % Sum layer
            net.addLayer([name '_sum'] , ...
                         dagnn.Sum(), ...
                         {sumInput.var, lastAdded.var}, ...
                         [name '_sum']) ;
            lastAdded.var = name ;
        end
    end
    
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
  net.addLayer([name  '_conv'], ...
               dagnn.Conv('size', [ksize ksize lastAdded.depth depth], ...
                          'stride', stride, ....
                          'pad', (ksize - 1) / 2, ...
                          'hasBias', args.bias, ...
                          'opts', {'cudnnworkspacelimit', opts.cudnnWorkspaceLimit}), ...
               lastAdded.var, ...
               [name '_conv'], ...
               pars) ;
  net.addLayer([name '_bn'], ...
               dagnn.BatchNorm('numChannels', depth, 'epsilon', 1e-5), ...
               [name '_conv'], ...
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