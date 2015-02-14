let s:enable_highlighting = 1

function! s:exchange(x, y, reverse, expand)
	let reg_z = s:save_reg('z')
	let reg_unnamed = s:save_reg('"')
	let reg_star = s:save_reg('*')
	let reg_plus = s:save_reg('+')
	let selection = &selection
	set selection=inclusive

	call setpos("'[", a:y[2])
	call setpos("']", a:y[3])
	call setreg('z', a:x[0], a:x[1])
	silent exe "normal! `[" . a:y[1] . "`]\"zp"

	if !a:expand
		call setpos("'[", a:x[2])
		call setpos("']", a:x[3])
		call setreg('z', a:y[0], a:y[1])
		silent exe "normal! `[" . a:x[1] . "`]\"zp"
	endif

	if a:reverse
		call cursor(a:x[2][1], a:x[2][2])
	else
		call cursor(a:y[2][1], a:y[2][2])
	endif

	let &selection = selection
	call s:restore_reg('z', reg_z)
	call s:restore_reg('"', reg_unnamed)
	call s:restore_reg('*', reg_star)
	call s:restore_reg('+', reg_plus)
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
			let end[2] -= len(matchstr(@@, '\_.$'))
		endif
	else
		let selection = &selection
		let &selection = 'inclusive'
		if a:type == 'line'
			let type = 'V'
			let [start, end] = s:store_pos("'[", "']")
			silent exe "normal! '[V']y"
		elseif a:type == 'block'
			let type = "\<C-V>"
			let [start, end] = s:store_pos("'[", "']")
			silent exe "normal! `[\<C-V>`]y"
		else
			let type = 'v'
			let [start, end] = s:store_pos("'[", "']")
			silent exe "normal! `[v`]y"
		endif
		let &selection = selection
	endif
	let text = getreg('@')
	call s:restore_reg('"', reg)
	call s:restore_reg('*', reg_star)
	call s:restore_reg('+', reg_plus)
	return [text, type, start, end]
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

function! s:exchange_clear(...)
	unlet! b:exchange
	if exists('b:exchange_matches')
		call s:highlight_clear(b:exchange_matches)
		unlet b:exchange_matches
	endif
	if a:0
		echohl WarningMsg | echo ":ExchangeClear will be deprecated in favor of :XchangeClear" | echohl None
	endif
endfunction

function! s:save_reg(name)
	return [getreg(a:name), getregtype(a:name)]
endfunction

function! s:restore_reg(name, reg)
	silent! call setreg(a:name, a:reg[0], a:reg[1])
endfunction

function! s:highlight(exchange)
	let [text, type, start, end] = a:exchange
	let regions = []
	if type == "\<C-V>"
		let blockstartcol = virtcol([start[1], start[2]])
		let blockendcol = virtcol([end[1], end[2]])
		if blockstartcol > blockendcol
			let [blockstartcol, blockendcol] = [blockendcol, blockstartcol]
		endif
		let regions += map(range(start[1], end[1]), '[v:val, blockstartcol, v:val, blockendcol]')
	else
		let [startline, endline] = [start[1], end[1]]
		if type ==# 'v'
			let startcol = virtcol([startline, start[2]])
			let endcol = virtcol([endline, end[2]])
		elseif type ==# 'V'
			let startcol = 1
			let endcol = virtcol([end[1], '$'])
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
	let [xs, xe, xm, ys, ye, ym] = [a:x[2], a:x[3], a:x[1], a:y[2], a:y[3], a:y[1]]
	let xe = s:apply_mode(xe, xm)
	let ye = s:apply_mode(ye, ym)

	" Compare two blockwise regions.
	if xm == "\<C-V>" && ym == "\<C-V>"
		if s:intersects(xs, xe, ys, ye)
			return 'overlap'
		endif
		let cmp = xs[2] - ys[2]
		return cmp <= 0 ? 'lt' : 'gt'
	endif

	" TODO: Compare a blockwise region with a linewise or characterwise region.
	" NOTE: Comparing blockwise with characterwise has one exception:
	"       When the characterwise region spans only one line, it is like blockwise.

	" Compare two linewise or characterwise regions.
	if s:compare_pos(xs, ys) <= 0 && s:compare_pos(xe, ye) >= 0
		return 'outer'
	elseif s:compare_pos(ys, xs) <= 0 && s:compare_pos(ye, xe) >= 0
		return 'inner'
	elseif (s:compare_pos(xs, ye) <= 0 && s:compare_pos(ys, xe) <= 0) || (s:compare_pos(ys, xe) <= 0 && s:compare_pos(xs, ye) <= 0)
		" x and y overlap in buffer.
		return 'overlap'
	endif

	let cmp = s:compare_pos(xs, ys)
	return cmp == 0 ? 'overlap' : cmp < 0 ? 'lt' : 'gt'
endfunction

function! s:compare_pos(x, y)
	if a:x[1] == a:y[1]
		return a:x[2] - a:y[2]
	else
		return a:x[1] - a:y[1]
	endif
endfunction

function! s:intersects(xs, xe, ys, ye)
	if a:xe[2] < a:ys[2] || a:xe[1] < a:ys[1] || a:xs[2] > a:ye[2] || a:xs[1] > a:ye[1]
		return 0
	else
		return 1
	endif
endfunction

function! s:apply_mode(pos, mode)
	let pos = a:pos
	if a:mode ==# 'V'
		let pos[2] = col([pos[1], '$'])
	endif
	return pos
endfunction

function! s:store_pos(start, end)
	return [getpos(a:start), getpos(a:end)]
endfunction

function! s:create_map(mode, lhs, rhs)
	if !hasmapto(a:rhs, a:mode)
		execute a:mode.'map '.a:lhs.' '.a:rhs
	endif
endfunction

highlight default link ExchangeRegion IncSearch

nnoremap <silent> <Plug>(Exchange) :<C-u>set opfunc=<SID>exchange_set<CR>g@
vnoremap <silent> <Plug>(Exchange) :<C-u>call <SID>exchange_set(visualmode(), 1)<CR>
nnoremap <silent> <Plug>(ExchangeClear) :<C-u>call <SID>exchange_clear()<CR>
nnoremap <silent> <Plug>(ExchangeLine) :<C-u>set opfunc=<SID>exchange_set<CR>g@_

command! XchangeHighlightToggle call s:highlight_toggle()
command! XchangeHighlightEnable call s:highlight_toggle(1)
command! XchangeHighlightDisable call s:highlight_toggle(0)

XchangeHighlightEnable

command! ExchangeClear call s:exchange_clear(1)
command! XchangeClear call s:exchange_clear()

if exists('g:exchange_no_mappings')
	finish
endif

call s:create_map('n', 'cx', '<Plug>(Exchange)')
call s:create_map('x', 'X', '<Plug>(Exchange)')
call s:create_map('n', 'cxc', '<Plug>(ExchangeClear)')
call s:create_map('n', 'cxx', '<Plug>(ExchangeLine)')
