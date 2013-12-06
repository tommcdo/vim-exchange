function! s:exchange_set(type, ...)
	if !exists('b:exchange')
		let b:exchange = s:get_exchange(a:type, a:0)
	else
		let exchange1 = b:exchange
		let exchange2 = s:get_exchange(a:type, a:0)

		let cmp = s:compare(exchange1, exchange2)
		if cmp == 0
			echoerr "Exchange aborted: overlapping text"
		elseif cmp > 0
			let [exchange1, exchange2] = [exchange2, exchange1]
		endif

		call s:exchange(exchange1, exchange2)
		call s:exchange_clear()
	endif
endfunction

" Return -1 if x comes before y in buffer,
"         0 if x and y overlap in buffer,
"         1 if x comes after y in buffer
function! s:compare(x, y)
	let [xs, xe, ys, ye] = [a:x[2], a:x[3], a:y[2], a:y[3]]
	" TODO: Write this function
	return -1
endfunction

function! s:exchange(x, y)
	let a = getpos("'a")
	let b = getpos("'b")
	let reg = @@

	call setpos("'a", a:y[2])
	call setpos("'b", a:y[3])
	let @@ = a:x[0]
	silent exe "normal! `a" . a:y[1] . "`bp"

	call setpos("'a", a:x[2])
	call setpos("'b", a:x[3])
	let @@ = a:y[0]
	silent exe "normal! `a" . a:x[1] . "`bp"

	call setpos("'a", a)
	call setpos("'b", b)
	let @@ = reg
endfunction

function! s:get_exchange(type, vis)
	let reg = @@
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
		let type = '\<C-V>'
		let [start, end] = s:store_pos("'[", "']")
		silent exe "normal! `[\<C-V>`]y"
	else
		let type = 'v'
		let [start, end] = s:store_pos("'[", "']")
		silent exe "normal! `[v`]y"
	endif
	let text = @@
	let @@ = reg
	let &selection = selection
	return [text, type, start, end]
endfunction

function! s:store_pos(start, end)
	return [getpos(a:start), getpos(a:end)]
endfunction

function! s:exchange_clear()
	unlet! b:exchange
endfunction

nnoremap <silent> <Plug>Exchange :<C-u>set opfunc=<SID>exchange_set<CR>g@
vnoremap <silent> <Plug>Exchange :<C-u>call <SID>exchange_set(visualmode(), 1)<CR>
nnoremap <silent> <Plug>ExchangeClear :<C-u>call <SID>exchange_clear()<CR>

nmap cx <Plug>Exchange
vmap cx <Plug>Exchange
nmap cxc <Plug>ExchangeClear
