function videoTrack(name_video, frame_w, frame_h)
	vr = VideoRecorder(name_video, 'Format', 'mov');

	run('IntraFace/install.m');
	cd IntraFace;
	[Models,option] = xx_initialize;
	cd ..;

	InputVideo.fh = figure('name', 'InputVideo');
	InputVideo.im_h = imshow(zeros(frame_h, frame_w, 3));

	set(InputVideo.fh,'KeyPressFcn',@pb_kpf);

	save_flag = false;
	stop_pressed = false;
	bool = false;

	frame_num = 0;

	cap = cv.VideoCapture(0);
	cap.set('FrameWidth', frame_w);
	cap.set('FrameHeight', frame_h);
	hold on;

	cnt = 0;

	while ~stop_pressed
		im = cap.read;

		if save_flag
			cnt = cnt + 1;
			vr.addFrame(im);
		end

		set(InputVideo.im_h, 'cdata', im);

		if save_flag && ~bool
			InputVideo.rec_h = plot(frame_w - 15, 15, 'r*', 'markersize', 13);
			bool = true;
		elseif ~save_flag && bool
			delete(InputVideo.rec_h);
			bool = false;
		end

		drawnow;
	end
	close;
	clear vr;
	disp(cnt);

	function [] = pb_kpf(varargin)
		% Callback for pushbutton
		if strcmp(varargin{2}.Key, 'escape') == 1
			stop_pressed = true;
		end
		if strcmp(varargin{2}.Key, 'space') == 1
			save_flag = ~save_flag;
		end
	end
end
