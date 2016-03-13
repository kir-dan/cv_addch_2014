function videoToPictures(video_name)
	run('IntraFace/install.m');
	cd IntraFace;
	[Models,option] = xx_initialize;
	cd ..;

	mkdir(video_name(1:(length(video_name) - 4)));
	vp = VideoPlayer(video_name);
	cnt = 0;

	while (true)
		cnt = cnt + 1;   
		imwrite(vp.Frame, [video_name(1:(length(video_name) - 4)) '\out' num2str(cnt) '.bmp']);
		
		if (~vp.nextFrame)
			 break;
		end
	end
end