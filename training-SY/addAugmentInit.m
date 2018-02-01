function addAugment = addAugmentInit()
%ADDAUGMENT Summary of this function goes here
%   Detailed explanation goes here
    % control doing the add augment or not
    addAugment.flag = 1; 
    %% add data augmentation settings
    addAugment.random_num_of_methods =5;
    addAugment.min_value = 0;
    addAugment.max_value = 255;
    % blur
    addAugment.blur = [];
    addAugment.blur.flag = 1;
    addAugment.blur.methods = [];
    addAugment.blur.methods.gaussian = [];
    addAugment.blur.methods.gaussian.name = 'gaussian';
    addAugment.blur.methods.gaussian.min_sigma = 0;
    addAugment.blur.methods.gaussian.max_sigma = 3.0;
    addAugment.blur.methods.gaussian.kernel_size = 3;
    addAugment.blur.methods.average = [];    
    addAugment.blur.methods.average.name = 'average';
    addAugment.blur.methods.average.min_kernel_size = 2;
    addAugment.blur.methods.average.max_kernel_size = 7;
    addAugment.blur.methods.median = [];    
    addAugment.blur.methods.median.name = 'median';
    addAugment.blur.methods.median.min_kernel_size = 3;
    addAugment.blur.methods.median.max_kernel_size = 11;
    % sharpen    
    addAugment.sharpen = [];    
    addAugment.sharpen.flag = 1;
    addAugment.sharpen.min_alpha = 0;
    addAugment.sharpen.max_alpha = 1.0;
    addAugment.sharpen.min_lightness = 0.75;
    addAugment.sharpen.max_lightness = 1.5;
    % emboss    
    addAugment.emboss = [];    
    addAugment.emboss.flag = 1;
    addAugment.emboss.min_alpha = 0;
    addAugment.emboss.max_alpha = 1.0;
    addAugment.emboss.min_strength = 0;
    addAugment.emboss.max_strength = 2.0;
    % edge    
    addAugment.edgeDetect = [];    
    addAugment.edgeDetect.flag = 1;
    addAugment.edgeDetect.methods = [];
    addAugment.edgeDetect.methods.edges = [];
    addAugment.edgeDetect.methods.edges.min_alpha = 0;
    addAugment.edgeDetect.methods.edges.max_alpha = 0.7;
    addAugment.edgeDetect.methods.direct_edges = [];
    addAugment.edgeDetect.methods.direct_edges.min_alpha = 0;
    addAugment.edgeDetect.methods.direct_edges.max_alpha = 0.7;
    addAugment.edgeDetect.methods.direct_edges.min_direction = 0;
    addAugment.edgeDetect.methods.direct_edges.max_direction= 1.0;
    % for additiveGaussianNoise    
    addAugment.additiveGaussianNoise = [];    
    addAugment.additiveGaussianNoise.flag = 1;
    addAugment.additiveGaussianNoise.min_scale = 0;
    addAugment.additiveGaussianNoise.max_scale = 0.05*255;
    addAugment.additiveGaussianNoise.per_channel = [];
    % for dropout    
    addAugment.dropout = [];    
    addAugment.dropout.flag = 1;
    addAugment.dropout.min_p = 0.001;
    addAugment.dropout.max_p = 0.1;
    addAugment.dropout.per_channel = 0.5;
    % for invert    
    addAugment.invert = [];    
    addAugment.invert.flag = 0;
    addAugment.invert.p = 0.5;
    addAugment.invert.per_channel = false;
    % for add    
    addAugment.add = [];    
    addAugment.add.flag = 1;
    addAugment.add.a = -10;
    addAugment.add.b = 10;
    addAugment.add.per_channel = 0.5;
    % for multiply    
    addAugment.multiply = [];    
    addAugment.multiply.flag = 1;
    addAugment.multiply.min_scale = 0.5;
    addAugment.multiply.max_scale = 1.5;
    addAugment.multiply.per_channel = 0.5;
    % for contrastNormalization    
    addAugment.contrastNormalization = [];    
    addAugment.contrastNormalization.flag = 1;
    addAugment.contrastNormalization.min_alpha = 0.5;
    addAugment.contrastNormalization.max_alpha = 1.5;
    addAugment.contrastNormalization.per_channel = 0.5;
    % for grayScale    
    addAugment.grayScale = [];    
    addAugment.grayScale.flag = 1;
    addAugment.grayScale.min_alpha = 0;
    addAugment.grayScale.max_alpha = 1.0;
    addAugment.grayScale.eps = 0.001;
    % for gamma adjust
    addAugment.gammaAdjust = [];
    addAugment.gammaAdjust.flag = 1;
    addAugment.gammaAdjust.min_gamma = 0.4;
    addAugment.gammaAdjust.max_gamma = 2.5;
end

