%startup;

clear all; clc;

netpath = 'data/resnet_block1.mat';
net = load(netpath);

%net = net.net;
br1_out = net.getVarIndex('br1_out');
br2_out = net.getVarIndex('br2_out');

