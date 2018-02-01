%startup;

clear all; clc;

netpath = 'data/matvgg5-test.mat';
net = load(netpath);
net = net.net;
net = dagnn.DagNN.loadobj(net) ;

for i=1:length(net.vars)
    net.vars(i).precious = 1;
end
net.mode = 'test';

br1_out = net.getVarIndex('br1_out');
br2_out = net.getVarIndex('br2_out');

exemplar = single(ones(127, 127, 3));
instance = single(ones(255, 255, 3));

net.eval({'exemplar', exemplar, 'instance', instance}) ;
 
exemplar_out = net.vars(br1_out).value;
instance_out = net.vars(br2_out).value;

exemplar_out(1:5, 1:5, 1)