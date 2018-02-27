function [init_sz, final_sz] = ideal_size_dagnn(net, max_sz)

final_sz = forward_dagnn(net, max_sz);
init_sz = backward_dagnn(net, final_sz);
while ~all(init_sz <= max_sz)
    final_sz = final_sz - 1;
    init_sz = backward_dagnn(net, final_sz);
end

end

function n = forward_dagnn(net, n)
    pre_l = [];
    for i = 1:numel(net.layers)
        if i>=2
           % judge the layer is or not the child of the previous layer
           if ~ismember(pre_l.outputs, net.layers(i).inputs)
               continue;
           end
        end
        l = net.layers(i).block;
        switch class(l)
            case 'dagnn.Conv'
                pad = l.pad(1);
                m = l.size(1:2);
                k = l.stride(1);
                n = filter(n, pad, m, k);
            case 'dagnn.Pooling'
                pad = l.pad(1);
                m = l.poolSize;
                k = l.stride(1);                
                n = filter(n, pad, m, k);
        end        
        layer_name = net.layers(i).name;
        pre_l = net.layers(i);
    end
end

function n = backward_dagnn(net, n)
    aft_l = [];
    for i = numel(net.layers):-1:1
        if i<numel(net.layers)
           % judge the layer is or not the child of the previous layer
           if ~ismember(net.layers(i).outputs, aft_l.inputs)
               continue;
           end
        end
        l = net.layers(i).block;
        switch class(l)
            case 'dagnn.Conv'
                pad = l.pad(1);
                m = l.size(1:2);
                k = l.stride(1);
                n = unfilter(n, pad, m, k);
            case 'dagnn.Pooling'
                pad = l.pad(1);
                m = l.poolSize;
                k = l.stride(1); 
                n = unfilter(n, pad, m, k);
        end
        layer_name = net.layers(i).name;
        aft_l = net.layers(i);
    end
end

function n = filter(n, pad, m, k)
assert(numel(pad) == 1);
n = floor((n + 2*pad - m) / k) + 1;
end

function n = unfilter(n, pad, m, k)
assert(numel(pad) == 1);
n = k*(n - 1) + m - 2*pad;
end
