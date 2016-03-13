function [ imgo ] = pyrBlend(images, mask)
	level = 5;
	tmp = size(images);
	n_images = tmp(1);
	limg = cell(n_images, 1);
	for i = 1:size(images)
		limg{i} = genPyr(images{i},'lap',level);
	end
	n_rows = length(images{1}(:, 1));
	n_cols = length(images{1});
	n_elem = n_rows * n_cols;

	blurh = fspecial('gauss',30,15);
	for i = 1:n_images
		mask{i} = imfilter(mask{i}, blurh, 'replicate');
	end

	limgo = cell(1,level); % the blended pyramid
	for p = 1:level
		[Mp Np ~] = size(limg{1}{p});
		limgo{p} = limg{1}{p}.*imresize(mask{1},[Mp Np]);
		for i = 2:n_images
			limgo{p} = limgo{p} + limg{i}{p}.*imresize(mask{i},[Mp Np]);
		end
	end
	imgo = pyrReconstruct(limgo);
	%figure,imshow(imgo) % blend by pyramid
	%imgo1 = maska.*imga+maskb.*imgb;
	%figure,imshow(imgo1) % blend by feathering
end