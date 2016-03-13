function makemat(in_dir)
	run('IntraFace/install.m');
	cd IntraFace;
	[Models,option] = xx_initialize;
	cd ..;

	face_size = 96;

	files = dir(in_dir);
	files = files(3:length(files));
	n_files = length(files);

	points = cell(n_files, 1);
	shifts = cell(n_files, 1);

	cnt = 0;
	line = round(n_files / 1000);
	disp(line);
	portion = 0;
	for i = 1:n_files
		cnt = cnt + 1;
		if cnt == line
			cnt = 0;
			portion = portion + 1;
			disp([num2str(portion) '/1000']);
		end

		image = imread([in_dir files(i).name]);
		[X Y ~] = size(image);
		output = xx_track_detect(Models, image, [], option);

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

			shifts{i} = [left top koef_w koef_h right bot X Y];
			points{i} = coord;
		else
			shifts{i} = [0 0 0 0 0 0];
			points{i} = zeros(49, 2);
		end
	end

	save([in_dir(1:(length(in_dir) - 1)) '_shf.mat'], 'shifts');
	save([in_dir(1:(length(in_dir) - 1)) '_inf.mat'], 'points');
end