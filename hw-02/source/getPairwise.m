function [ pairwise ] = getPairwise(n_rows, n_cols)
	n_elem = n_rows * n_cols;

	% Формирование блока блочной матрицы парных потенциалов
	% [1 1 0 0 ... 0 0 0 0]
	% [1 1 1 0 ... 0 0 0 0]
	% [0 1 1 1 ... 0 0 0 0]
	% [...................]
	% [0 0 0 0 ... 1 1 1 0]
	% [0 0 0 0 ... 0 1 1 1]
	% [0 0 0 0 ... 0 0 1 1]
	% Вариант для разреженной матрицы
	n_block = n_cols * 3 - 2;
	block_row = zeros(1, n_block);
	block_col = zeros(1, n_block);
	cnt = 1;
	for a = 1:n_cols
		if a == 1
			block_row(cnt) = a;
			block_col(cnt) = a;
			cnt = cnt + 1;
			block_row(cnt) = a;
			block_col(cnt) = a + 1;
			cnt = cnt + 1;
		elseif a == n_cols
			block_row(cnt) = a;
			block_col(cnt) = a - 1;
			cnt = cnt + 1;
			block_row(cnt) = a;
			block_col(cnt) = a;
			cnt = cnt + 1;
		else
			block_row(cnt) = a;
			block_col(cnt) = a - 1;
			cnt = cnt + 1;
			block_row(cnt) = a;
			block_col(cnt) = a;
			cnt = cnt + 1;
			block_row(cnt) = a;
			block_col(cnt) = a + 1;
			cnt = cnt + 1;
		end
	end

	% Формирование центрального блока блочной матрицы парных потенциалов
	% [0 1 0 0 ... 0 0 0 0]
	% [1 0 1 0 ... 0 0 0 0]
	% [0 1 0 1 ... 0 0 0 0]
	% [...................]
	% [0 0 0 0 ... 1 0 1 0]
	% [0 0 0 0 ... 0 1 0 1]
	% [0 0 0 0 ... 0 0 1 0]
	% Вариант для разреженной матрицы
	cent_n_block = n_cols * 3 - 2;
	cent_block_row = zeros(1, cent_n_block);
	cent_block_col = zeros(1, cent_n_block);
	cnt = 1;
	for a = 1:n_cols
		if a == 1
			cent_block_row(cnt) = a;
			cent_block_col(cnt) = a;
			cnt = cnt + 1;
			cent_block_row(cnt) = a;
			cent_block_col(cnt) = a + 1;
			cnt = cnt + 1;
		elseif a == n_cols
			cent_block_row(cnt) = a;
			cent_block_col(cnt) = a - 1;
			cnt = cnt + 1;
			cent_block_row(cnt) = a;
			cent_block_col(cnt) = a;
			cnt = cnt + 1;
		else
			cent_block_row(cnt) = a;
			cent_block_col(cnt) = a - 1;
			cnt = cnt + 1;
			cent_block_row(cnt) = a;
			cent_block_col(cnt) = a;
			cnt = cnt + 1;
			cent_block_row(cnt) = a;
			cent_block_col(cnt) = a + 1;
			cnt = cnt + 1;
		end
	end

	% Формирование разреженной матрицы парных потенциалов
	rows = zeros(1, (n_rows * cent_n_block + 2 * (n_rows - 1) * n_block));
	cols = zeros(1, (n_rows * cent_n_block + 2 * (n_rows - 1) * n_block));
	vals = ones(1, (n_rows * cent_n_block + 2 * (n_rows - 1) * n_block));
	cnt = 1;
	for a = 1:n_rows
		if a == 1
			rows(cnt : (cnt + cent_n_block - 1)) = cent_block_row + (a - 1) * n_cols;
			cols(cnt : (cnt + cent_n_block - 1)) = cent_block_col + (a - 1) * n_cols;
			cnt = cnt + cent_n_block;
			rows(cnt : (cnt + n_block - 1)) = block_row + (a - 1) * n_cols;
			cols(cnt : (cnt + n_block - 1)) = block_col + a * n_cols;
			cnt = cnt + n_block;
		elseif a == n_rows
			rows(cnt : (cnt + n_block - 1)) = block_row + (a - 1) * n_cols;
			cols(cnt : (cnt + n_block - 1)) = block_col + (a - 2) * n_cols;
			cnt = cnt + n_block;
			rows(cnt : (cnt + cent_n_block - 1)) = cent_block_row + (a - 1) * n_cols;
			cols(cnt : (cnt + cent_n_block - 1)) = cent_block_col + (a - 1) * n_cols;
			cnt = cnt + cent_n_block;
		else
			rows(cnt : (cnt + n_block - 1)) = block_row + (a - 1) * n_cols;
			cols(cnt : (cnt + n_block - 1)) = block_col + (a - 2) * n_cols;
			cnt = cnt + n_block;
			rows(cnt : (cnt + cent_n_block - 1)) = cent_block_row + (a - 1) * n_cols;
			cols(cnt : (cnt + cent_n_block - 1)) = cent_block_col + (a - 1) * n_cols;
			cnt = cnt + cent_n_block;
			rows(cnt : (cnt + n_block - 1)) = block_row + (a - 1) * n_cols;
			cols(cnt : (cnt + n_block - 1)) = block_col + a * n_cols;
			cnt = cnt + n_block;
		end
	end

	pairwise = sparse(rows, cols, vals);

end