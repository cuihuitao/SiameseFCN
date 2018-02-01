function [state result] = drawRect(img, rectVec, showOrNot)

%img: input color image
%rectVec: input vector of rect draw on image. element in rectVec: x, y,
%width, height


rgb = [255 0 0];
result = img;

[imgH, imgW] = size(img);

if size(img,3) == 3 %draw on color image
    for k=1:3
        for i=1:size(rectVec,1)
            if( rectVec(i,1)>=0 && rectVec(i,2)>=0 && rectVec(i,1)+rectVec(i,3)<=imgW && rectVec(i,2)+rectVec(i,4)<=imgH )
                result( rectVec(i,2),rectVec(i,1):(rectVec(i,1)+rectVec(i,3)),k ) = rgb(1,k);%top line
                result( rectVec(i,2)+1,rectVec(i,1):(rectVec(i,1)+rectVec(i,3)),k ) = rgb(1,k);
                
                result( rectVec(i,2)+rectVec(i,4),rectVec(i,1):(rectVec(i,1)+rectVec(i,3)),k ) = rgb(1,k);%bottom line
                result( rectVec(i,2)+rectVec(i,4)-1,rectVec(i,1):(rectVec(i,1)+rectVec(i,3)),k ) = rgb(1,k);
                
                result( rectVec(i,2):rectVec(i,2)+rectVec(i,4), rectVec(i,1),k ) = rgb(1,k);%left line
                result( rectVec(i,2):rectVec(i,2)+rectVec(i,4), rectVec(i,1)+1,k ) = rgb(1,k);
                
                result( rectVec(i,2):rectVec(i,2)+rectVec(i,4), rectVec(i,1)+rectVec(i,3),k ) = rgb(1,k);%right line
                result( rectVec(i,2):rectVec(i,2)+rectVec(i,4), rectVec(i,1)+rectVec(i,3)-1,k ) = rgb(1,k);
                
            end
        end
    end
end

state = 1;

if showOrNot == 1
    figure;
    imshow(result);
end