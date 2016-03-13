function faces(in_dir, frame_w, frame_h)
	% Size of window, which include face [face_size face_size]
	face_size = 96;

	% Read informaton of images (base)
	imageFiles = dir([in_dir]);
	imageFiles = imageFiles(3:length(imageFiles));
	n_files = length(imageFiles);

	% Read kd-tree from mat-file
	tree = load([in_dir(1 : (length(in_dir) - 1)) '_tree.mat']);
	X = tree.X;
	tree = tree.tree;

	% Read shifts from mat-file (shifts of face window from borders)
	shifts = load([in_dir(1 : (length(in_dir) - 1)) '_shf.mat']);
	shifts = shifts.shifts;

	% Install libraries
	run('IntraFace/install.m');
	run('vlfeat-0.9.20/toolbox/vl_setup.m');
	cd IntraFace;
	[Models,option] = xx_initialize;
	cd ..;

	% Create figure, which consist result_video
	result_video.fh = figure('name', 'Result', 'menubar', 'none', ...
		'numbertitle', 'off');
	result_video.im_h = imshow(zeros(frame_h, frame_w, 3));
	set(result_video.fh,'KeyPressFcn',@pb_kpf);

	stop_pressed = false;
	points.pred = [];
	face_vector = zeros(98, 1);
	mb = MultibandBlending();

	% Create camera object
	cap = cv.VideoCapture(0);
	cap.set('FrameWidth', frame_w);
	cap.set('FrameHeight', frame_h);
	hold on;

	% Operating cycle
	while ~stop_pressed
		input_frame = cap.read;
		[frame_h frame_w ~] = size(input_frame);
		if isempty(input_frame), error('can not read stream from camera'); end
	
		points = xx_track_detect(Models, input_frame, points.pred, option);

		% Determination of required image
		res_num = 0;
		if points.pred
			left = min(points.pred(:, 1));
			top = min(points.pred(:, 2));

			points_coord = points.pred;
			points_coord(:, 1) = points.pred(:, 1) - left;
			points_coord(:, 2) = points.pred(:, 2) - top;

			right = max(points_coord(:, 1));
			bot = max(points_coord(:, 2));

			koef_w = face_size / right;
			koef_h = face_size / bot;
			points_coord(:, 1) = points_coord(:, 1) .* koef_w;
			points_coord(:, 2) = points_coord(:, 2) .* koef_h;

			face_vector(:, 1) = points_coord(:);
			[index dist] = vl_kdtreequery(tree, X, face_vector);
			res_num = index;
		end

		if res_num ~= 0
			pnts = reshape(X(:, res_num), [49 2]);

			image = imread([in_dir imageFiles(res_num).name]);

			% Determination mask of face in input frame
			hullpos_coord = convhull(double(points.pred(:, 1)), ...
				double(points.pred(:, 2)));
			hull_coord = zeros(length(hullpos_coord), 2);
			for i = 1:length(hullpos_coord)
				hull_coord(i, 1) = points.pred(hullpos_coord(i), 1);
				hull_coord(i, 2) = points.pred(hullpos_coord(i), 2);
			end
			mask = poly2mask(hull_coord(:, 1), hull_coord(:, 2), ...
				frame_h, frame_w);

			% Calculate ungles of faces in input frame and base image
			border_face = round(bot / face_size * 15);
			border_target = round(shifts{res_num}(6) / face_size * 15);

			left_input = max(1, round(left) - border_face);
			top_input = max(1, round(top) - border_face);
			right_input =  min(frame_w , round(left + right) + ...
				border_face);
			bot_input = min(frame_h, round(top + bot) + ...
				round(border_face));

			left_base = max(1, round(shifts{res_num}(1)) - border_target);
			top_base = max(1, round(shifts{res_num}(2)) - border_target);
			right_base = min(round(shifts{res_num}(8)), ...
				round(shifts{res_num}(1) + shifts{res_num}(5)) + ...
				border_target);
			bot_base = min(round(shifts{res_num}(7)), ...
				round(shifts{res_num}(2) + shifts{res_num}(6)) + ...
				round(border_target));

			% Allocation of face in input frame, base image and mask window
			input_face = input_frame(top_input : bot_input, ...
				left_input : right_input, :);
			[width_face height_face ~] = size(input_face);
			input_face = imresize(input_face, ...
				[face_size face_size]);

			base_face = image(top_base : bot_base, ...
				left_base : right_base, :);
			base_face = imresize(base_face, [face_size face_size]);

			mask_face = mask(top_input : bot_input, ...
				left_input : right_input, :);
			mask_face = imresize(mask_face, [face_size face_size]);

			% Statistical correction of base face
			base_face = round(statcorr(input_face, base_face, mask_face));
			mask_face = imdilate(mask_face, strel('disk', 4));

			% Turn of base face
			tform = fitgeotrans(pnts, points_coord, ...
			 'NonreflectiveSimilarity');
			base_face = imwarp(base_face, tform, 'OutputView', ...
				imref2d(size(input_face)));

			% New black image, which consist only base face;
			% and mask of face in input frame
			image_res = zeros(frame_h, frame_w, 3);
			base_face = imresize(base_face, [width_face height_face]);
			image_res(top_input : bot_input, ...
				left_input : right_input, :) = base_face;

			mask_res = zeros(frame_h, frame_w);
			mask_face = imresize(mask_face, [width_face height_face]);
			mask_res(top_input : bot_input, ...
				left_input : right_input, :) = mask_face;

			% Result image
			result = mb.stitchMask(double(input_frame) / 255, ...
				double(image_res) / 255, mask_res);
		else
			result = input_frame;
		end

		% Postprocessing of result image
		h = fspecial('gaussian', [3 3], 0.5);
		result = imfilter(result, h, 'replicate');
		set(result_video.im_h, 'cdata', result);

		drawnow;
	end
	close;

	% Function of statistical correction
	function [res] = statcorr(src, dst, msk)
		src = double(src); dst = double(dst);

		l = [[0.3811 0.5783 0.0402]; [0.1967 0.7244 0.0782]; ...
			[0.0241 0.1288 0.8444]];
		a = [[1/sqrt(3) 0 0]; [0 1/sqrt(6) 0]; [0 0 1/sqrt(2)]];
		b = double([[1 1 1]; [1 1 -2]; [1 -1 0]]);
		c = a * b;

		tmp = src;
		src(:, :, 1) = l(1, 1) * tmp(:, :, 1) + l(1, 2) * tmp(:, :, 2) ...
			+ l(1, 3) * tmp(:, :, 3);
		src(:, :, 2) = l(2, 1) * tmp(:, :, 1) + l(2, 2) * tmp(:, :, 2) ...
			+ l(2, 3) * tmp(:, :, 3);
		src(:, :, 3) = l(3, 1) * tmp(:, :, 1) + l(3, 2) * tmp(:, :, 2) ...
			+ l(3, 3) * tmp(:, :, 3);
		src = log(src + 1);
		tmp = src;
		src(:, :, 1) = c(1, 1) * tmp(:, :, 1) + c(1, 2) * tmp(:, :, 2) ...
			+ c(1, 3) * tmp(:, :, 3);
		src(:, :, 2) = c(2, 1) * tmp(:, :, 1) + c(2, 2) * tmp(:, :, 2) ...
			+ c(2, 3) * tmp(:, :, 3);
		src(:, :, 3) = c(3, 1) * tmp(:, :, 1) + c(3, 2) * tmp(:, :, 2) ...
			+ c(3, 3) * tmp(:, :, 3);

		tmp = dst;
		dst(:, :, 1) = l(1, 1) * tmp(:, :, 1) + l(1, 2) * tmp(:, :, 2) ...
			+ l(1, 3) * tmp(:, :, 3);
		dst(:, :, 2) = l(2, 1) * tmp(:, :, 1) + l(2, 2) * tmp(:, :, 2) ...
			+ l(2, 3) * tmp(:, :, 3);
		dst(:, :, 3) = l(3, 1) * tmp(:, :, 1) + l(3, 2) * tmp(:, :, 2) ...
			+ l(3, 3) * tmp(:, :, 3);
		dst = log(dst + 1);
		tmp = dst;
		dst(:, :, 1) = c(1, 1) * tmp(:, :, 1) + c(1, 2) * tmp(:, :, 2) ...
			+ c(1, 3) * tmp(:, :, 3);
		dst(:, :, 2) = c(2, 1) * tmp(:, :, 1) + c(2, 2) * tmp(:, :, 2) ...
			+ c(2, 3) * tmp(:, :, 3);
		dst(:, :, 3) = c(3, 1) * tmp(:, :, 1) + c(3, 2) * tmp(:, :, 2) ...
			+ c(3, 3) * tmp(:, :, 3);

		tmp = src;
		tmp(:, :, 1) = M(src(:, :, 1), msk) + (dst(:, :, 1) ...
			- M(dst(:, :, 1), msk)) * D(src(:, :, 1), msk) ...
			/ D(dst(:, :, 1), msk);
		tmp(:, :, 2) = M(src(:, :, 2), msk) + (dst(:, :, 2) ...
			- M(dst(:, :, 2), msk)) * D(src(:, :, 2), msk) ...
			/ D(dst(:, :, 2), msk);
		tmp(:, :, 3) = M(src(:, :, 3), msk) + (dst(:, :, 3) ...
			- M(dst(:, :, 3), msk)) * D(src(:, :, 3), msk) ...
			/ D(dst(:, :, 3), msk);
		dst = tmp;

		l = l^(-1); a = a^(-1); b = b^(-1); c = b * a;
		tmp = dst;
		dst(:, :, 1) = c(1, 1) * tmp(:, :, 1) + c(1, 2) * tmp(:, :, 2) ...
			+ c(1, 3) * tmp(:, :, 3);
		dst(:, :, 2) = c(2, 1) * tmp(:, :, 1) + c(2, 2) * tmp(:, :, 2) ...
			+ c(2, 3) * tmp(:, :, 3);
		dst(:, :, 3) = c(3, 1) * tmp(:, :, 1) + c(3, 2) * tmp(:, :, 2) ...
			+ c(3, 3) * tmp(:, :, 3);
		dst = exp(dst);
		tmp = dst;
		dst(:, :, 1) = l(1, 1) * tmp(:, :, 1) + l(1, 2) * tmp(:, :, 2) ...
			+ l(1, 3) * tmp(:, :, 3);
		dst(:, :, 2) = l(2, 1) * tmp(:, :, 1) + l(2, 2) * tmp(:, :, 2) ...
			+ l(2, 3) * tmp(:, :, 3);
		dst(:, :, 3) = l(3, 1) * tmp(:, :, 1) + l(3, 2) * tmp(:, :, 2) ...
			+ l(3, 3) * tmp(:, :, 3);

		dst(dst < 0) = 0;
		dst(dst > 255) = 255;

		res = dst;
	end

	function [resM] = M(imgc, mskc)
		resM = sum(imgc .* mskc) / sum(mskc);
	end

	function [resD] = D(imgc, mskc)
		m = M(imgc, mskc);
		resD = sqrt(sum(((imgc - m).^2) .* mskc) / sum(mskc));
	end

	function [] = pb_kpf(varargin)
		% Callback for pushbutton
		if strcmp(varargin{2}.Key, 'escape')==1
			stop_pressed = true;
		end
	end
end
