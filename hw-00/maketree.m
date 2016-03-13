function maketree(in_dir)
	points = load([in_dir(1 : (length(in_dir) - 1)) '_inf.mat']);
	points = points.points;

	n_files = size(points);
	n_files = n_files(1);

	X = zeros(98, n_files);

	for i = 1:n_files
		X(:, i) = points{i}(:);
	end

	tree = vl_kdtreebuild(X);
	save([in_dir(1:(length(in_dir) - 1)) '_tree.mat'], 'X', 'tree');
end