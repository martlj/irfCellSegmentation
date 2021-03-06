function varargout = watershedBasedSegmentation(varargin)
%watershedOverPrepSteps Watershed transform for cell detection
%   watershedOverPrepSteps(image, feature) plots the watershed transform
%   and bounding boxes for specified image and feature image. Saves
%   bounding boxes to a file.
%
%   watershedOverPrepSteps(image, feature, filename) saves bounding boxes
%   to the specified file
%
%   watershedOverPrepSteps(image, feature, filename, flag) shows
%   intermediate results depending on boolean variable flag. Default is
%   true.
%
%   watershedOverPrepSteps(image, feature, filename, flag, range) filters
%   cells with area between range(1) and range(2). Defaults are 10 and 0.25
%   * numRows * numCols.
%
%   watershedOverPrepSteps(image, feature, filename, flag, range,
%   filename2) saves ROIs to filename2
%
%   h = watershedOverPrepSteps(...) outputs the figure handle for watershed
%   results
%
%   See also watershed

% jd, Jun-2015

% Watershed over prep steps

% Inputs to this operation:
% -------------------------
% numCols (width of prepocessedImage)
% prepocessedImage (result of pre-processing step)
% imageFeature (result of LoG)

% Outputs:
% --------
% output_boundingboxes.mat

% Modified variables:
% -------------------
% showIntermediateResults
% handles.bBoxFileName
% handles.hWatershedResults


if nargin > 1
    
    % Image w/ corrected illumination/contrast
    preprocessedImage = varargin{1};
    
    % Feature for cell/cytoplasm
    imageFeature = varargin{2};
    
else
        
    error('watershedOverPrepSteps: Wrong number of input arguments.')
    
end

if nargin > 2
    
    bBoxFileName = varargin{3};
    
else
    
    bBoxFileName = 'output_boundingboxes.mat';
    
end

if nargin > 3
    
    showIntermediateResults = varargin{4};

else
    
    showIntermediateResults = true;

end

% Get image size
numRows = size(preprocessedImage, 1);
numCols = size(preprocessedImage, 2);


if nargin > 4
    
    areaRange = varargin{5};
    minCellArea = areaRange(1);
    maxCellArea = areaRange(2);
    
else
    
    minCellArea = 10;
    maxCellArea = 0.25 * numRows * numCols;
    
end

if nargin > 5
    
    segmentation_options = varargin{6};
    
else
    
    segmentation_options.foregroundThresh = 0.92;
    segmentation_options.mergeRegions = true;
    segmentation_options.mergeIntersectionRatio = 0.33;
    segmentation_options.filterSmallRegions = true;
    segmentation_options.saveResults = true;
    
    warning('watershedBasedSegmentation: Using default params.');
    
end


% ------------------------------------------------------------------------
% Setup

useDistanceTransform = true;
useDistanceTransformOverForeground = true;

% ------------------------------------------------------------------------
% Candidate non cell pixels (Gaussian filter)

sigma = 0.01 * numCols;

imFilter = fspecial('gaussian', round(6 * sigma), sigma);

smoothImage = imfilter(double(preprocessedImage), imFilter);

imMax = max(smoothImage(:));
imMin = min(smoothImage(:));
smoothImage = (smoothImage - imMin)/(imMax - imMin);

if showIntermediateResults
    figure(1), imshow(smoothImage),
%     title('Low resolution version of image (smoothImage)')
    set(1, 'Name', ['Low resolution version of image (smoothImage)']);
end

% -------------------------
% Get threshold

% less than or equal to threshold for background
lambda = 0.1;
lowThreshold = (1 - lambda) * min(smoothImage(:)) + lambda * max(smoothImage(:));
candidateNonCellPixels = im2bw(imcomplement(smoothImage), imcomplement(min(max(lowThreshold,0),1)));

se = strel('disk', 20);
candidateNonCellPixels = imopen(candidateNonCellPixels, se);

if useDistanceTransform
    
    % Apply distance transform to candidateNonCellPixels
    
    if showIntermediateResults
        figure(2), imshow(candidateNonCellPixels), 

        set(2, 'Name', ['candidateNonCellPixels opening']);
    end
    
    if ~useDistanceTransformOverForeground

        % Distance transform applied to candidateNonCellPixels:
        D = bwdist(imcomplement(candidateNonCellPixels));

        if showIntermediateResults
            figure(3), imagesc(D),

            set(3, 'Name', ['distance transform of candidateNonCellPixels (D)']);
            colormap gray
            axis off
            axis image
        end

        DL = watershed(D);
        candidateNonCellPixels = DL == 0;
    end
    
end

candidateCellPixels = cdfBasedThreshold(imageFeature, segmentation_options.foregroundThresh);

if useDistanceTransform
    
    % Apply distance transform to candidateNonCellPixels
    
    if useDistanceTransformOverForeground

        % Distance transform applied to candidateCellPixels:
        D = bwdist(candidateCellPixels);

        if showIntermediateResults
            figure(3), imagesc(D),

            set(3, 'Name', ['distance transform of candidateCellPixels (D)']);
            colormap gray
            axis off
            axis image
        end

        DL = watershed(D);
        candidateNonCellPixels = DL == 0;
    end
    
end

if showIntermediateResults
    figure(4), imshow(candidateCellPixels),
    set(4, 'Name', ['candidateCellPixels']);
    
    figure(5), imshow(candidateNonCellPixels),
    set(5, 'Name', ['candidateNonCellPixels']);
end

% -------------------------
% Gradient

imageFeature = adapthisteq(imageFeature);

gradientMagnitude = GradMagn(imageFeature);
gradientMagnitude2 = imimposemin(gradientMagnitude, candidateNonCellPixels | candidateCellPixels);

if showIntermediateResults
    figure(6), imshow(gradientMagnitude),
    set(6, 'Name', ['gradientMagnitude']);

    figure(7), imshow(gradientMagnitude2),
    set(7, 'Name', ['gradientMagnitude2']);
end

watershedLabels = watershed(gradientMagnitude2);


% -------------------------
% Plot watershed results

if showIntermediateResults

    hWatershedAndDetectionsFigure = figure(8);
    hold off
    imshow(preprocessedImage),
    hold on

    rgbLabels = label2rgb(watershedLabels,'jet',[.5 .5 .5]);
    hImage = imshow(rgbLabels,'InitialMagnification','fit');
    set(hImage, 'AlphaData', 0.2);

    % title('Watershed Transform-Based Detection (Only Large-Label-Area Boxes Removed)')
    set(hWatershedAndDetectionsFigure, 'Name', ...
        ['Watershed Transform-Based Detection (Only Large-Label-Area Boxes Removed)']);
end

% -------------------------
% Figures

if showIntermediateResults

    hWatershedTransformFigure = figure(9);
    hold off
    imshow(preprocessedImage)
    hold on
    hImage = imshow(rgbLabels,'InitialMagnification','fit');
    set(hImage, 'AlphaData', 0.2);
    set(hWatershedTransformFigure, 'Name', ['Image and Superimposed Watershed Transform']);


    hSegmentationFigure = figure(10);
    hold off
    imshow(preprocessedImage)
    hold on
    set(hSegmentationFigure, 'Name', ['Image and Watershed Transform-Based Segmentation']);


    hWatershedBasedDetectionFigure = figure(11);
    hold off
    imshow(preprocessedImage)
    hold on
    set(hWatershedBasedDetectionFigure, 'Name', ['Image and Size-Filtered Watershed Transform-Based Detections']);

end


%% Get bounding boxes of watershed labels


candidateStats = regionprops(watershedLabels, 'Area', 'BoundingBox', 'PixelIdxList');


% --- Filter/remove large labels/boxes ---

idx = [candidateStats.Area] <= maxCellArea;
allBoundingBoxes = {candidateStats.BoundingBox};

% Save the bounding boxes of those objects (only large-label-area boxes removed)
initBoundingBoxAnnotations = {candidateStats(idx).BoundingBox};

% Backup watershed labels
initWatershedLabels = watershedLabels;

% Switch off discarded labels here:
% idxLabelsToBeSwitchedOff = [candidateStats.Area] > maxCellArea;

rectLineWidth = 1;

% Draw detections before filtering (only large-label-area boxes removed)
if showIntermediateResults

    figure(hWatershedAndDetectionsFigure)
    
end

numLabels = length(allBoundingBoxes);

if showIntermediateResults

    for i=1:length(allBoundingBoxes)

        if idx(i)

            rectangle('Position', allBoundingBoxes{i}, ...
                'EdgeColor', [1 0 1], 'LineWidth', rectLineWidth);

            h = text(allBoundingBoxes{i}(1), ...
                allBoundingBoxes{i}(2) - 8, num2str(i), ...
                'color', [1 0 1]);
        end
    end

end

% --- Merge/combine labels/boxes ---

% Merge/combine objects:
if segmentation_options.mergeRegions

    [boundingBoxAnnotations, mergedBoxes, newIdx] = ...
        boxSetMerge(allBoundingBoxes, idx, segmentation_options.mergeIntersectionRatio);
    
end

% --- Actually merge labels ---

% Mark labels to be merged
labelsToBeMerged = 1:length(idx);
labelsToBeMerged = labelsToBeMerged(mergedBoxes ~= 0);  % these labels survive
labelsToBeAbsorved = mergedBoxes(mergedBoxes ~= 0);  % these label id's are lost

for i = 1:length(labelsToBeAbsorved)

    watershedLabels(watershedLabels == labelsToBeAbsorved(i)) = labelsToBeMerged(i);
end

% Join regions with the same label. Idea: Get a convex region.
turnMergedRegionsIntoConvex = true;
if turnMergedRegionsIntoConvex
    mergedCandidateStats = regionprops(watershedLabels, 'Area', 'ConvexHull');

    for i = 1:length(labelsToBeMerged)

        regionConvexHull = mergedCandidateStats(labelsToBeMerged(i)).ConvexHull;
        roiLogical = poly2mask(regionConvexHull(:,1), ...
            regionConvexHull(:,2), ...
            numRows, numCols);
        watershedLabels(roiLogical) = labelsToBeMerged(i);

    end
end

% --- Removing ... and wrong sizes ---
% These line can be deleted:
% [boundingBoxAnnotations, didDiscardBoxes] = ...
%     boxSetAnalysis(boundingBoxAnnotations, ...
%     minCellArea, maxCellArea);


% --- Filter/remove small labels/boxes ---

% Idea:
% -----
% After merging, small-area labels which remain under area threshold,
% should be removed. Area of small-area labels which were merged should be
% re evaluated.
% This information can be obtained from (a) sum of the two merged regions,
% (b) *** flag merged regions not to be discarded ***

if segmentation_options.filterSmallRegions
    
    candidateStatsBeforeRemovingSmall = regionprops(watershedLabels, 'Area');
    idxSmall = [candidateStatsBeforeRemovingSmall.Area] < minCellArea;  % this was 900

    % Assumption: Regions of merged boxes are not small. To do: More realistic.
    idxSmallToBeDeleted = idxSmall & (mergedBoxes == 0);

    % This marks small-area labels to be deleted
    newIdx = newIdx & ~idxSmallToBeDeleted;

end

% --- Actually delete unwanted labels ---

labelsToBeDeleted = 1:length(idx);
labelsToBeDeleted = labelsToBeDeleted(~newIdx);

localDebugFlag = false;
if localDebugFlag && showIntermediateResults
    
    hDebug = figure(15);
    
end

for i = 1:length(labelsToBeDeleted)
    if localDebugFlag && showIntermediateResults

        imagesc(watershedLabels)
        
        labelsToBeDeleted(i)
%         pause
    end
        
%     watershedLabels(watershedLabels == objectLabels(labelsToBeDeleted(i))) = 0;
    watershedLabels(watershedLabels == labelsToBeDeleted(i)) = 0;
end



%% --- Draw segmentations ---

newRGBLabels = label2rgb(watershedLabels,'jet',[.5 .5 .5]);

if segmentation_options.saveResults
    
    fileNameParts = strsplit(bBoxFileName, '.');
    fileNameParts{1} = [fileNameParts{1} '-rgb-labels'];
    outFileName = [fileNameParts{1} '.png'];
    imwrite(newRGBLabels, outFileName)

end

if showIntermediateResults
    
    figure(hSegmentationFigure)
    hImage = imshow(newRGBLabels,'InitialMagnification','fit');
    set(hImage, 'AlphaData', 0.2);

end

% --- Draw filtered detections which were not discarded ---

if showIntermediateResults
    
    figure(hWatershedBasedDetectionFigure)
    for i=1:length(boundingBoxAnnotations)

        if newIdx(i)
            rectangle('Position', boundingBoxAnnotations{i}, ...
                'EdgeColor', [1 0 1], 'LineWidth', rectLineWidth);

            if localDebugFlag
                i
    %             pause
            end

        end
    end

end

% -------------------------
% Save and output

if segmentation_options.saveResults
    
    activeBoxes = newIdx;

    save(bBoxFileName, 'boundingBoxAnnotations', 'activeBoxes');
    
end


if nargout > 0
    
    if showIntermediateResults
        varargout{1} = hWatershedBasedDetectionFigure;
    end
    
end

if nargout > 1
    
    varargout{2} = watershedLabels;
    
end

if nargout > 2
    
    if showIntermediateResults
        varargout{3} = hSegmentationFigure;
    end
    
end



