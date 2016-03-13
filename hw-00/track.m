function track(out_dir, frame_w, frame_h)

	mkdir(out_dir(1:(length(out_dir) - 1)));

	SCRsize = get(0, 'ScreenSize');
	screen_w = SCRsize(3);
	screen_h = SCRsize(4);

	run('IntraFace/install.m');
	cd IntraFace;
	[Models,option] = xx_initialize;
	cd ..;

	InputVideo.fh = figure('name', 'InputVideo', ...
		'position', ...
		[(screen_w / 2 - frame_w) ((screen_h - frame_h) / 2) frame_w frame_h]);
	InputVideo.ax = axes('Parent', InputVideo.fh);
	InputVideo.im_h = imshow(zeros(frame_h, frame_w, 3));

	set(InputVideo.fh,'KeyPressFcn',@pb_kpf);

	save_pressed = false;
	stop_pressed = false;
	drawed = false;
	output.pred = [];

	frame_num = 0;

	cap = cv.VideoCapture(0);
	cap.set('FrameWidth', frame_w);
	cap.set('FrameHeight', frame_h);
	hold on;

	while ~stop_pressed
		im = cap.read;
		if isempty(im), error('can not read stream from camera'); end
	
		output = xx_track_detect(Models,im,output.pred,option);

		if save_pressed
			if output.pred
				frame_num = frame_num + 1;
				imwrite(im, [out_dir 'out' num2str(frame_num) '.bmp']);
				points = output.pred;
				%save([out_dir 'out' num2str(frame_num) 'inf.mat'], 'points');
				save_pressed = false;
				disp(frame_num);
			end
		end
		save_pressed = false;

		set(InputVideo.im_h, 'cdata', im);
		if isempty(output.pred)
			if drawed, delete_handlers(); end
		else
			update_GUI();
		end

		drawnow;
	end
	close; close;

	function delete_handlers() 
		delete(InputVideo.pts_h); 
		drawed = false;
	end

	function update_GUI()
		if drawed % faster to update than to creat new drawings
			% update tracked points
			set(InputVideo.pts_h, 'xdata', output.pred(:,1), 'ydata',output.pred(:,2));
		else
			% create tracked points drawing
			InputVideo.pts_h = plot(output.pred(:,1), output.pred(:,2), 'g*', 'markersize',2);
			drawed = true;
		end
	end

	function [] = pb_kpf(varargin)
		% Callback for pushbutton
		if strcmp(varargin{2}.Key, 'escape') == 1
			stop_pressed = true;
		end
		if strcmp(varargin{2}.Key, 'space') == 1
			save_pressed = true;
		end
	end
end
