function faces_offline(in_video, in_dir)
	face_size = 96;

	imageFiles = dir([in_dir]);
	imageFiles = imageFiles(3:length(imageFiles));
	n_files = length(imageFiles);

	tree = load([in_dir(1 : (length(in_dir) - 1)) '_tree.mat']);
	X = tree.X;
	tree = tree.tree;

	shifts = load([in_dir(1 : (length(in_dir) - 1)) '_shf.mat']);
	shifts = shifts.shifts;

	run('IntraFace/install.m');
	run('vlfeat-0.9.20/toolbox/vl_setup.m');
	cd IntraFace;
	[Models,option] = xx_initialize;
	cd ..;

	output.pred = [];
	face_vector = zeros(98, 1);
	mb = MultibandBlending();

	vr = VideoRecorder([in_video(1:(length(in_video) - 4)) '_result'], 'Format', 'mov');
	vp = VideoPlayer(in_video);

	cnt = 0;

	while true
		cnt = cnt + 1;
		disp(cnt);
		im = vp.Frame;
		[frame_h frame_w ~] = size(im);
		im = uint8(im * 255);

		output = xx_track_detect(Models, im, output.pred, option);

		res_num = 0;
		if output.pred
			left = min(output.pred(:, 1));
			top = min(output.pred(:, 2));

			coord = output.pred;
			coord(:, 1) = output.pred(:, 1) - left;
			coord(:, 2) = output.pred(:, 2) - top;

			right = max(coord(:, 1));
			bot = max(coord(:, 2));

			koef_w = face_size / right;
			koef_h = face_size / bot;
			coord(:, 1) = coord(:, 1) .* koef_w;
			coord(:, 2) = coord(:, 2) .* koef_h;

			face_vector(:, 1) = coord(:);
			[index dist] = vl_kdtreequery(tree, X, face_vector);
			res_num = index;
		end

		if res_num ~= 0
			pnts = reshape(X(:, res_num), [49 2]);
			tform = fitgeotrans(pnts, coord, 'NonreflectiveSimilarity');

			image = imread([in_dir imageFiles(res_num).name]);

			hullpos_coord = convhull(double(output.pred(:, 1)), double(output.pred(:, 2)));
			hull_coord = zeros(length(hullpos_coord), 2);
			for i = 1:length(hullpos_coord)
				hull_coord(i, 1) = output.pred(hullpos_coord(i), 1);
				hull_coord(i, 2) = output.pred(hullpos_coord(i), 2);
			end
			mask_coord = poly2mask(hull_coord(:, 1), hull_coord(:, 2), frame_h, frame_w);

			border_face = round(bot / face_size * 15);
			border_target = round(shifts{res_num}(6) / face_size * 15);

			left_face = max(1, round(left) - border_face);
			top_face = max(1, round(top) - border_face);
			right_face =  min(frame_w , round(left + right) + border_face);
			bot_face = min(frame_h, round(top + bot) + round(border_face));

			left_target = max(1, round(shifts{res_num}(1)) - border_target);
			top_target = max(1, round(shifts{res_num}(2)) - border_target);
			right_target = min(round(shifts{res_num}(8)), round(shifts{res_num}(1) + shifts{res_num}(5)) + border_target);
			bot_target = min(round(shifts{res_num}(7)), round(shifts{res_num}(2) + shifts{res_num}(6)) + round(border_target));

			im_face = im(top_face : bot_face, left_face : right_face, :);
			[width_face height_face ~] = size(im_face);
			im_face = imresize(im_face, [face_size face_size]);

			image_face = image(top_target : bot_target, left_target : right_target, :);
			image_face = imresize(image_face, [face_size face_size]);

			mask_face = mask_coord(top_face : bot_face, left_face : right_face, :);
			mask_face = imresize(mask_face, [face_size face_size]);

			image_face = round(statcorr(im_face, image_face, mask_face));
			mask_face = imdilate(mask_face, strel('disk', 4));
			image_face = imwarp(image_face, tform, 'OutputView', imref2d(size(im_face)));

			image_res = zeros(frame_h, frame_w, 3);
			image_face = imresize(image_face, [width_face height_face]);
			image_res(top_face : bot_face, left_face : right_face, :) = image_face;

			mask_res = zeros(frame_h, frame_w);
			mask_face = imresize(mask_face, [width_face height_face]);
			mask_res(top_face : bot_face, left_face : right_face, :) = mask_face;

			im = mb.stitchMask(double(im) / 255, double(image_res) / 255, mask_res);
			%new_face = imresize(new_face, [width_face height_face]);
			%new_face(new_face < 0) = 0;
			%new_face(new_face > 1) = 1;

			%im(top_face : bot_face, left_face : right_face, :) = new_face * 255;
		end

		h = fspecial('gaussian', [3 3], 0.5);
		im = imfilter(im, h, 'replicate');

		vr.addFrame(im);
		vp + 1;
		if (~vp.nextFrame)
			clear vr;
			break;
		end
	end

	function [res] = statcorr(src, dst, msk)
		src = double(src); dst = double(dst);

		l = [[0.3811 0.5783 0.0402]; [0.1967 0.7244 0.0782]; [0.0241 0.1288 0.8444]];
		a = [[1/sqrt(3) 0 0]; [0 1/sqrt(6) 0]; [0 0 1/sqrt(2)]];
		b = double([[1 1 1]; [1 1 -2]; [1 -1 0]]);
		c = a * b;

		tmp = src;
		src(:, :, 1) = l(1, 1) * tmp(:, :, 1) + l(1, 2) * tmp(:, :, 2) + l(1, 3) * tmp(:, :, 3);
		src(:, :, 2) = l(2, 1) * tmp(:, :, 1) + l(2, 2) * tmp(:, :, 2) + l(2, 3) * tmp(:, :, 3);
		src(:, :, 3) = l(3, 1) * tmp(:, :, 1) + l(3, 2) * tmp(:, :, 2) + l(3, 3) * tmp(:, :, 3);
		src = log(src + 1);
		tmp = src;
		src(:, :, 1) = c(1, 1) * tmp(:, :, 1) + c(1, 2) * tmp(:, :, 2) + c(1, 3) * tmp(:, :, 3);
		src(:, :, 2) = c(2, 1) * tmp(:, :, 1) + c(2, 2) * tmp(:, :, 2) + c(2, 3) * tmp(:, :, 3);
		src(:, :, 3) = c(3, 1) * tmp(:, :, 1) + c(3, 2) * tmp(:, :, 2) + c(3, 3) * tmp(:, :, 3);

		tmp = dst;
		dst(:, :, 1) = l(1, 1) * tmp(:, :, 1) + l(1, 2) * tmp(:, :, 2) + l(1, 3) * tmp(:, :, 3);
		dst(:, :, 2) = l(2, 1) * tmp(:, :, 1) + l(2, 2) * tmp(:, :, 2) + l(2, 3) * tmp(:, :, 3);
		dst(:, :, 3) = l(3, 1) * tmp(:, :, 1) + l(3, 2) * tmp(:, :, 2) + l(3, 3) * tmp(:, :, 3);
		dst = log(dst + 1);
		tmp = dst;
		dst(:, :, 1) = c(1, 1) * tmp(:, :, 1) + c(1, 2) * tmp(:, :, 2) + c(1, 3) * tmp(:, :, 3);
		dst(:, :, 2) = c(2, 1) * tmp(:, :, 1) + c(2, 2) * tmp(:, :, 2) + c(2, 3) * tmp(:, :, 3);
		dst(:, :, 3) = c(3, 1) * tmp(:, :, 1) + c(3, 2) * tmp(:, :, 2) + c(3, 3) * tmp(:, :, 3);

		tmp = src;
		tmp(:, :, 1) = M(src(:, :, 1), msk) + (dst(:, :, 1) - M(dst(:, :, 1), msk)) * ...
			D(src(:, :, 1), msk) / D(dst(:, :, 1), msk);
		tmp(:, :, 2) = M(src(:, :, 2), msk) + (dst(:, :, 2) - M(dst(:, :, 2), msk)) * ...
			D(src(:, :, 2), msk) / D(dst(:, :, 2), msk);
		tmp(:, :, 3) = M(src(:, :, 3), msk) + (dst(:, :, 3) - M(dst(:, :, 3), msk)) * ...
			D(src(:, :, 3), msk) / D(dst(:, :, 3), msk);
		dst = tmp;

		l = l^(-1); a = a^(-1); b = b^(-1); c = b * a;
		tmp = dst;
		dst(:, :, 1) = c(1, 1) * tmp(:, :, 1) + c(1, 2) * tmp(:, :, 2) + c(1, 3) * tmp(:, :, 3);
		dst(:, :, 2) = c(2, 1) * tmp(:, :, 1) + c(2, 2) * tmp(:, :, 2) + c(2, 3) * tmp(:, :, 3);
		dst(:, :, 3) = c(3, 1) * tmp(:, :, 1) + c(3, 2) * tmp(:, :, 2) + c(3, 3) * tmp(:, :, 3);
		dst = exp(dst);
		tmp = dst;
		dst(:, :, 1) = l(1, 1) * tmp(:, :, 1) + l(1, 2) * tmp(:, :, 2) + l(1, 3) * tmp(:, :, 3);
		dst(:, :, 2) = l(2, 1) * tmp(:, :, 1) + l(2, 2) * tmp(:, :, 2) + l(2, 3) * tmp(:, :, 3);
		dst(:, :, 3) = l(3, 1) * tmp(:, :, 1) + l(3, 2) * tmp(:, :, 2) + l(3, 3) * tmp(:, :, 3);

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
end
