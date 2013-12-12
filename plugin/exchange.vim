function! s:exchange(x, y)
	let a = getpos("'a")
	let b = getpos("'b")
	let reg = getreg('"')
	let reg_mode = getregtype('"')

	call setpos("'a", a:y[2])
	call setpos("'b", a:y[3])
	call setreg('"', a:x[0], a:x[1])
	silent exe "normal! `a" . a:y[1] . "`b\"\"p"

	call setpos("'a", a:x[2])
	call setpos("'b", a:x[3])
	call setreg('"', a:y[0], a:y[1])
	silent exe "normal! `a" . a:x[1] . "`b\"\"p"

	call setpos("'a", a)
	call setpos("'b", b)
	call setreg('"', reg, reg_mode)
endfunction

function! s:exchange_get(type, vis)
	let reg = getreg('"')
	let reg_mode = getregtype('"')
	let selection = &selection
	let &selection = 'inclusive'
	if a:vis
		let type = a:type
		let [start, end] = s:store_pos("'<", "'>")
		silent exe "normal! `<" . a:type . "`>y"
	elseif a:type == 'line'
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
	let text = getreg('@')
	call setreg('"', reg, reg_mode)
	let &selection = selection
	return [text, type, start, end]
endfunction

function! s:exchange_set(type, ...)
	if !exists('b:exchange')
		let b:exchange = s:exchange_get(a:type, a:0)
	else
		let exchange1 = b:exchange
		let exchange2 = s:exchange_get(a:type, a:0)

		let cmp = s:compare(exchange1, exchange2)
		if cmp == 0
			echohl WarningMsg | echo "Exchange aborted: overlapping text" | echohl None
			return s:exchange_clear()
		elseif cmp > 0
			let [exchange1, exchange2] = [exchange2, exchange1]
		endif

		call s:exchange(exchange1, exchange2)
		call s:exchange_clear()
	endif
endfunction

function! s:exchange_clear()
	unlet! b:exchange
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
			return 0
		endif
		let cmp = xs[2] - ys[2]
		return cmp == 0 ? -1 : cmp
	endif

	" TODO: Compare a blockwise region with a linewise or characterwise region.
	" NOTE: Comparing blockwise with characterwise has one exception:
	"       When the characterwise region spans only one line, it is like blockwise.

	" Compare two linewise or characterwise regions.
	if (s:compare_pos(xs, ye) <= 0 && s:compare_pos(ys, xe) <= 0) || (s:compare_pos(ys, xe) <= 0 && s:compare_pos(xs, ye) <= 0)
		" x and y overlap in buffer.
		return 0
	endif

	return s:compare_pos(xs, ys)
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

nnoremap <silent> <Plug>Exchange :<C-u>set opfunc=<SID>exchange_set<CR>g@
vnoremap <silent> <Plug>Exchange :<C-u>call <SID>exchange_set(visualmode(), 1)<CR>
nnoremap <silent> <Plug>ExchangeClear :<C-u>call <SID>exchange_clear()<CR>
nnoremap <silent> <Plug>ExchangeLine :<C-u>set opfunc=<SID>exchange_set<CR>g@_

if exists('g:exchange_no_mappings')
	finish
endif

nmap cx <Plug>Exchange
vmap cx <Plug>Exchange
nmap cxc <Plug>ExchangeClear
nmap cxx <Plug>ExchangeLine
