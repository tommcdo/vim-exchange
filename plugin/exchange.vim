let s:enable_highlighting = 1

function! s:exchange(x, y, reverse, expand)
	let reg_z = s:save_reg('z')
	let reg_unnamed = s:save_reg('"')
	let reg_star = s:save_reg('*')
	let reg_plus = s:save_reg('+')
	let selection = &selection
	set selection=inclusive

	" Compare using =~ because "'==' != 0" returns 0
	let indent = s:get_setting('exchange_indent', 1) !~ 0 && a:x.type ==# 'V' && a:y.type ==# 'V'

	if indent
		let xindent = matchstr(getline(nextnonblank(a:y.start.line)), '^\s*')
		let yindent = matchstr(getline(nextnonblank(a:x.start.line)), '^\s*')
	endif

	let view = winsaveview()

	call s:setpos("'[", a:y.start)
	call s:setpos("']", a:y.end)
	call setreg('z', a:x.text, a:x.type)
	silent execute "normal! `[" . a:y.type . "`]\"zp"

	if !a:expand
		call s:setpos("'[", a:x.start)
		call s:setpos("']", a:x.end)
		call setreg('z', a:y.text, a:y.type)
		silent execute "normal! `[" . a:x.type . "`]\"zp"
	endif

	if indent
		let xlines = 1 + a:x.end.line - a:x.start.line
		let ylines = a:expand ? xlines : 1 + a:y.end.line - a:y.start.line
		if !a:expand
			call s:reindent(a:x.start.line, ylines, yindent)
		endif
		call s:reindent(a:y.start.line - xlines + ylines, xlines, xindent)
	endif

	call winrestview(view)

	if !a:expand
		call s:fix_cursor(a:x, a:y, a:reverse)
	endif

	let &selection = selection
	call s:restore_reg('z', reg_z)
	call s:restore_reg('"', reg_unnamed)
	call s:restore_reg('*', reg_star)
	call s:restore_reg('+', reg_plus)
endfunction

function! s:fix_cursor(x, y, reverse)
	if a:reverse
		call cursor(a:x.start.line, a:x.start.column)
	else
		if a:x.start.line == a:y.start.line
			let horizontal_offset = a:x.end.column - a:y.end.column
			call cursor(a:x.start.line, a:x.start.column - horizontal_offset)
		elseif (a:x.end.line - a:x.start.line) != (a:y.end.line - a:y.start.line)
			let vertical_offset = a:x.end.line - a:y.end.line
			call cursor(a:x.start.line - vertical_offset, a:x.start.column)
		endif
	endif
endfunction

function! s:reindent(start, lines, new_indent)
	if s:get_setting('exchange_indent', 1) == '=='
		let lnum = nextnonblank(a:start)
		if lnum == 0 || lnum > a:start + a:lines - 1
			return
		endif
		let line = getline(lnum)
		execute "silent normal! " . lnum . "G=="
		let new_indent = matchstr(getline(lnum), '^\s*')
		call setline(lnum, line)
	else
		let new_indent = a:new_indent
	endif
	let indent = matchstr(getline(nextnonblank(a:start)), '^\s*')
	if strdisplaywidth(new_indent) > strdisplaywidth(indent)
		for lnum in range(a:start, a:start + a:lines - 1)
			if lnum =~ '\S'
				call setline(lnum, new_indent . getline(lnum)[len(indent):])
			endif
		endfor
	elseif strdisplaywidth(new_indent) < strdisplaywidth(indent)
		let can_dedent = 1
		for lnum in range(a:start, a:start + a:lines - 1)
			if stridx(getline(lnum), new_indent) != 0 && nextnonblank(lnum) == lnum
				let can_dedent = 0
			endif
		endfor
		if can_dedent
			for lnum in range(a:start, a:start + a:lines - 1)
				if stridx(getline(lnum), new_indent) == 0
					call setline(lnum, new_indent . getline(lnum)[len(indent):])
				endif
			endfor
		endif
	endif
endfunction

function! s:exchange_get(type, vis)
	let reg = s:save_reg('"')
	let reg_star = s:save_reg('*')
	let reg_plus = s:save_reg('+')
	if a:vis
		let type = a:type
		let [start, end] = s:store_pos("'<", "'>")
		silent normal! gvy
		if &selection ==# 'exclusive' && start != end
			let end.column -= len(matchstr(@@, '\_.$'))
		endif
	else
		let selection = &selection
		let &selection = 'inclusive'
		if a:type == 'line'
			let type = 'V'
			let [start, end] = s:store_pos("'[", "']")
			silent execute "normal! '[V']y"
		elseif a:type == 'block'
			let type = "\<C-V>"
			let [start, end] = s:store_pos("'[", "']")
			silent execute "normal! `[\<C-V>`]y"
		else
			let type = 'v'
			let [start, end] = s:store_pos("'[", "']")
			silent execute "normal! `[v`]y"
		endif
		let &selection = selection
	endif
	let text = getreg('@')
	call s:restore_reg('"', reg)
	call s:restore_reg('*', reg_star)
	call s:restore_reg('+', reg_plus)
	return {
	\	'text': text,
	\	'type': type,
	\	'start': start,
	\	'end': s:apply_type(end, type)
	\ }
endfunction

function! s:exchange_set(type, ...)
	if !exists('b:exchange')
		let b:exchange = s:exchange_get(a:type, a:0)
		let b:exchange_matches = s:highlight(b:exchange)
		" Tell tpope/vim-repeat that '.' should repeat the Exchange motion
		silent! call repeat#invalidate()
	else
		let exchange1 = b:exchange
		let exchange2 = s:exchange_get(a:type, a:0)
		let reverse = 0
		let expand = 0

		let cmp = s:compare(exchange1, exchange2)
		if cmp == 'overlap'
			echohl WarningMsg | echo "Exchange aborted: overlapping text" | echohl None
			return s:exchange_clear()
		elseif cmp == 'outer'
			let [expand, reverse] = [1, 1]
			let [exchange1, exchange2] = [exchange2, exchange1]
		elseif cmp == 'inner'
			let expand = 1
		elseif cmp == 'gt'
			let reverse = 1
			let [exchange1, exchange2] = [exchange2, exchange1]
		endif

		call s:exchange(exchange1, exchange2, reverse, expand)
		call s:exchange_clear()
	endif
endfunction

function! s:exchange_clear()
	unlet! b:exchange
	if exists('b:exchange_matches')
		call s:highlight_clear(b:exchange_matches)
		unlet b:exchange_matches
	endif
endfunction

function! s:save_reg(name)
	try
		return [getreg(a:name), getregtype(a:name)]
	catch /.*/
		return ['', '']
	endtry
endfunction

function! s:restore_reg(name, reg)
	silent! call setreg(a:name, a:reg[0], a:reg[1])
endfunction

function! s:highlight(exchange)
	let regions = []
	if a:exchange.type == "\<C-V>"
		let blockstartcol = virtcol([a:exchange.start.line, a:exchange.start.column])
		let blockendcol = virtcol([a:exchange.end.line, a:exchange.end.column])
		if blockstartcol > blockendcol
			let [blockstartcol, blockendcol] = [blockendcol, blockstartcol]
		endif
		let regions += map(range(a:exchange.start.line, a:exchange.end.line), '[v:val, blockstartcol, v:val, blockendcol]')
	else
		let [startline, endline] = [a:exchange.start.line, a:exchange.end.line]
		if a:exchange.type ==# 'v'
			let startcol = virtcol([a:exchange.start.line, a:exchange.start.column])
			let endcol = virtcol([a:exchange.end.line, a:exchange.end.column])
		elseif a:exchange.type ==# 'V'
			let startcol = 1
			let endcol = virtcol([a:exchange.end.line, '$'])
		endif
		let regions += [[startline, startcol, endline, endcol]]
	endif
	return map(regions, 's:highlight_region(v:val)')
endfunction

function! s:highlight_region(region)
	let pattern = '\%'.a:region[0].'l\%'.a:region[1].'v\_.\{-}\%'.a:region[2].'l\(\%>'.a:region[3].'v\|$\)'
	return matchadd('_exchange_region', pattern)
endfunction

function! s:highlight_clear(match)
	for m in a:match
		silent! call matchdelete(m)
	endfor
endfunction

function! s:highlight_toggle(...)
	if a:0 == 1
		let s:enable_highlighting = a:1
	else
		let s:enable_highlighting = !s:enable_highlighting
	endif
	execute 'highlight link _exchange_region' (s:enable_highlighting ? 'ExchangeRegion' : 'None')
endfunction

" Return < 0 if x comes before y in buffer,
"        = 0 if x and y overlap in buffer,
"        > 0 if x comes after y in buffer
function! s:compare(x, y)
	" Compare two blockwise regions.
	if a:x.type == "\<C-V>" && a:y.type == "\<C-V>"
		if s:intersects(a:x, a:y)
			return 'overlap'
		endif
		let cmp = a:x.start.column - a:y.start.column
		return cmp <= 0 ? 'lt' : 'gt'
	endif

	" TODO: Compare a blockwise region with a linewise or characterwise region.
	" NOTE: Comparing blockwise with characterwise has one exception:
	"       When the characterwise region spans only one line, it is like blockwise.

	" Compare two linewise or characterwise regions.
	if s:compare_pos(a:x.start, a:y.start) <= 0 && s:compare_pos(a:x.end, a:y.end) >= 0
		return 'outer'
	elseif s:compare_pos(a:y.start, a:x.start) <= 0 && s:compare_pos(a:y.end, a:x.end) >= 0
		return 'inner'
	elseif (s:compare_pos(a:x.start, a:y.end) <= 0 && s:compare_pos(a:y.start, a:x.end) <= 0)
	\	|| (s:compare_pos(a:y.start, a:x.end) <= 0 && s:compare_pos(a:x.start, a:y.end) <= 0)
		" x and y overlap in buffer.
		return 'overlap'
	endif

	let cmp = s:compare_pos(a:x.start, a:y.start)
	return cmp == 0 ? 'overlap' : cmp < 0 ? 'lt' : 'gt'
endfunction

function! s:compare_pos(x, y)
	if a:x.line == a:y.line
		return a:x.column - a:y.column
	else
		return a:x.line - a:y.line
	endif
endfunction

function! s:intersects(x, y)
	if a:x.end.column < a:y.start.column || a:x.end.line < a:y.start.line
	\	|| a:x.start.column > a:y.end.column || a:x.start.line > a:y.end.line
		return 0
	else
		return 1
	endif
endfunction

function! s:apply_type(pos, type)
	let pos = a:pos
	if a:type ==# 'V'
		let pos.column = col([pos.line, '$'])
	endif
	return pos
endfunction

function! s:store_pos(start, end)
	return [s:getpos(a:start), s:getpos(a:end)]
endfunction

function! s:getpos(mark)
	let pos = getpos(a:mark)
	let result = {}
	return {
	\	'buffer': pos[0],
	\	'line': pos[1],
	\	'column': pos[2],
	\	'offset': pos[3]
	\ }
endfunction

function! s:setpos(mark, pos)
	call setpos(a:mark, [a:pos.buffer, a:pos.line, a:pos.column, a:pos.offset])
endfunction

function! s:create_map(mode, lhs, rhs)
	if !hasmapto(a:rhs, a:mode)
		execute a:mode.'map '.a:lhs.' '.a:rhs
	endif
endfunction

function! s:get_setting(setting, default)
	return get(b:, a:setting, get(g:, a:setting, a:default))
endfunction

highlight default link ExchangeRegion IncSearch
highlight default link _exchange_region ExchangeRegion

nnoremap <silent> <expr> <Plug>(Exchange) ':<C-u>set operatorfunc=<SID>exchange_set<CR>'.(v:count1 == 1 ? '' : v:count1).'g@'
vnoremap <silent> <Plug>(Exchange) :<C-u>call <SID>exchange_set(visualmode(), 1)<CR>
nnoremap <silent> <Plug>(ExchangeClear) :<C-u>call <SID>exchange_clear()<CR>
nnoremap <silent> <expr> <Plug>(ExchangeLine) ':<C-u>set operatorfunc=<SID>exchange_set<CR>'.(v:count1 == 1 ? '' : v:count1).'g@_'

command! -bar XchangeHighlightToggle call s:highlight_toggle()
command! -bar XchangeHighlightEnable call s:highlight_toggle(1)
command! -bar XchangeHighlightDisable call s:highlight_toggle(0)

XchangeHighlightEnable

command! -bar XchangeClear call s:exchange_clear()

if exists('g:exchange_no_mappings')
	finish
endif

call s:create_map('n', 'cx', '<Plug>(Exchange)')
call s:create_map('x', 'X', '<Plug>(Exchange)')
call s:create_map('n', 'cxc', '<Plug>(ExchangeClear)')
call s:create_map('n', 'cxx', '<Plug>(ExchangeLine)')
