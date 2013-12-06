function! s:exchange_set(type, ...)
	let sel_save = &selection
	let &selection = "inclusive"
	let reg_save = @@

	if !exists('b:exchange_text')
		if a:0
			call s:store_pos(a:type, "'<", "'>")
			silent exe "normal! `<" . a:type . "`>y"
		elseif a:type == 'line'
			call s:store_pos('V', "'[", "']")
			silent exe "normal! '[V']y"
		elseif a:type == 'block'
			call s:store_pos('\<C-V>', "'[", "']")
			silent exe "normal! `[\<C-V>`]y"
		else
			call s:store_pos('v', "'[", "']")
			silent exe "normal! `[v`]y"
		endif
		let b:exchange_text = @@
	else
		let @@ = b:exchange_text
		if a:0
			silent exe "normal! `<" . a:type . "`>y"
		elseif a:type == 'line'
			silent exe "normal! '[V']y"
		elseif a:type == 'block'
			silent exe "normal! `[\<C-V>`]y"
		else
			silent exe "normal! `[v`]y"
		endif
		let exchange_text = @@
		let @@ = b:exchange_text
		silent exe "normal! gvp"
		let @@ = exchange_text
		call s:exchange()
		call s:exchange_clear()
	endif

	let &selection = sel_save
	let @@ = reg_save
endfunction

function! s:exchange()
	let x = getpos("'x")
	let a = getpos("'a")
	let b = getpos("'b")
	call setpos("'a", b:exchange_start)
	call setpos("'b", b:exchange_end)
	silent exe "normal! mx`a" . b:exchange_mode . "`bp`x"
	call setpos("'a", a)
	call setpos("'b", b)
	call setpos("'x", x)
endfunction

function! s:store_pos(mode, start, end)
	let b:exchange_mode = a:mode
	let b:exchange_start = getpos(a:start)
	let b:exchange_end = getpos(a:end)
endfunction

function! s:exchange_clear()
	unlet! b:exchange_mode
	unlet! b:exchange_start
	unlet! b:exchange_end
	unlet! b:exchange_text
endfunction

nnoremap <silent> <Plug>Exchange :<C-u>set opfunc=<SID>exchange_set<CR>g@
vnoremap <silent> <Plug>Exchange :<C-u>call <SID>exchange_set(visualmode(), 1)<CR>
nnoremap <silent> <Plug>ExchangeClear :<C-u>call <SID>exchange_clear()<CR>

nmap cx <Plug>Exchange
vmap cx <Plug>Exchange
nmap cxc <Plug>ExchangeClear
