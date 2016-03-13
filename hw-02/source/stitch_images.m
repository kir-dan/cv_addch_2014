function stitch_images(in_dir, in_mode)
	files = dir(in_dir);
	files = files(3:length(files));

	if in_mode == 1
		maskFiles = files(2:2:length(files));
		files = files(1:2:length(files));
	end

	n_files = length(files);
	% Считывание изображений в память
		images = cell(n_files, 1);
		for i = 1:n_files
			images{i} = im2double(imread([in_dir files(i).name]));
		end

		n_rows = length(images{1}(:, 1));
		n_cols = length(images{1});
		n_elem = n_rows * n_cols;
	% -------------------------------

	% Считывание мазков в память
	if in_mode == 1
		strokes = cell(n_files, 1);
		for i = 1:n_files
			strokes{i} = im2double(imread([in_dir maskFiles(i).name]));
			strokes{i} = strokes{i}(:, :, 1);
		end
	end
	% -------------------------------

	blackMask = cell(n_files, 1);
	tmpBlackMask = cell(n_files, 1);

	for a = 1:n_files
		tmpBlackMask{a} = (images{a} == 0);
		blackMask{a} = ((tmpBlackMask{a}(:, :, 1) + ...
			tmpBlackMask{a}(:, :, 2) + tmpBlackMask{a}(:, :, 3)) == 3);
	end

	SE = strel('disk', 75);
	box = ones(75, 75);

	for a = 1:n_files
		blackMask{a} = imopen(blackMask{a}, SE);
		perimeter = imdilate(blackMask{a}, SE) - blackMask{a};
		tmp = conv2(blackMask{a} + 1, box, 'same') .* perimeter;
		if max(max(tmp)) ~= 0
			tmp = tmp / max(max(tmp));
		else
			tmp = zeros(n_rows, n_cols);
		end
		blackMask{a} = blackMask{a} + tmp;
		if in_mode == 1
			blackMask{a} = blackMask{a} - strokes{a};
		end
	end

	%for a = 1:n_files
	%	blackMask{a} = imopen(blackMask{a}, SE);
	%	if in_mode == 1
	%		blackMask{a} = blackMask{a} + imdilate(blackMask{a}, SE);
	%		blackMask{a} = blackMask{a} - strokes{a};
	%	else
	%		perimeter = imdilate(blackMask{a}, SE) - blackMask{a};
	%		tmp = conv2(blackMask{a} + 1, box, 'same') .* perimeter;
	%		tmp = tmp / max(max(tmp));
	%		blackMask{a} = 2 * blackMask{a} + tmp;
	%	end
	%end

	% Подготовка данных для GCMex
		% Вытягивание изображений в строку
		strImages = cell(n_files, 1);
		strBlackMask = cell(n_files, 1);

		for i = 1:n_files
			strImages{i} = grayscale(images{i});
			strImages{i} = (strImages{i}(:))';
			strBlackMask{i} = blackMask{i}(:, :, 1);
			strBlackMask{i} = (strBlackMask{i}(:))';
		end

		% Формирование матрицы унарных потенциалов
		unary = zeros(n_files, n_elem);
		for a = 1:n_files
			unary(a, :) = strBlackMask{a} * 255 * n_elem;
		end

		% Формирование матрицы парных потенциалов
		pairwise = getPairwise(n_rows, n_cols);

		[labels energyBefore energyAfter] = GCMex(zeros(n_elem, 1), ...
			unary, pairwise, single(zeros(n_files)), 0, int32(n_files), ...
			strImages);
	%----------------------------

	label = zeros(n_rows, n_cols);
	for i = 1:n_rows
		for j = 1:n_cols
			label(i, j) = labels((j - 1) * n_rows + i);
		end
	end

	mask = cell(n_files, 1);
	for a = 1:n_files
		mask{a} = zeros(n_rows, n_cols, 3);
	end

	for i = 1:n_rows
		for j = 1:n_cols
			mask{label(i,j) + 1}(i, j, :) = [1, 1, 1];
		end
	end

	%res = zeros(n_rows, n_cols, 3);
	%resMask = zeros(n_rows, n_cols, 3);

	%for i = 1:n_rows
	%	for j = 1:n_cols
	%		res(i, j, :) = images{label(i,j) + 1}(i, j, :);
	%	end
	%end

	%grandMask = ones(n_rows, n_cols, 3);

	%for a = n_files:-1:1
	%	res = pyrBlend(res, images{a}, grandMask - mask{a}, mask{a});
	%end

	res = pyrBlend(images, mask);

	imwrite(res, 'out_img.bmp');
	imshow(res);
end

function [grayImg] = grayscale(img)
	grayImg = 0.299 * img(:, :, 1) + ...
				0.587 * img(:, :, 2) + 0.114 * img(:, :, 3);
end
