function rename(in_dir)
	files = dir(in_dir);
	files = files(4:length(files));
	n_files = length(files);
	
	for i = 1 : n_files
		if i < 10
			movefile([in_dir '/' files(i).name], [in_dir '/00' num2str(i) '.bmp']);
		elseif i < 100
			movefile([in_dir '/' files(i).name], [in_dir '/0' num2str(i) '.bmp']);
		else
			movefile([in_dir '/' files(i).name], [in_dir '/' num2str(i) '.bmp']);
		end
	end
end