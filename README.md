exchange.vim
============

Easy text exchange operator for Vim.

Mappings
--------

`cx`

On the first use, define the first {motion} to exchange. On the second use,
define the second {motion} and perform the exchange.

`cxx`

Like `cx`, but use the current line.

`cxc`

Clear any {motion} pending for exchange.

### Notes about the mappings

* `cx` can also be used from visual mode, which is sometimes easier than coming
  up with the right {motion}
* If you're using the same motion again (e.g. exchanging two words using
  `cxiw`), you can use `.` the second time.

Example
-------

To exchange two words, place your cursor on the first word and type `cxiw`.
Then move to the second word and type `cxiw` again. Note: the {motion} used in
the first and second use of `cx` don't have to be the same.

Caveats
-------

### Visual mapping causes delay for change operator

As noted in [Issue #11][iss11], the visual mapping for `cx` can cause a delay
if you want to use `c` from visual mode. This is because Vim is waiting for a
delay (specified by `'timeoutlen'`) before using the `c` command instead of
using `cx`.  For more details, see [:help 'timeoutlen'][timeoutlen].

There are two potential solutions for this.

#### Changing timeout length

Set `'timeoutlen'` to a smaller value so that the delay is less noticeable.

    set timeoutlen=250

#### Changing default visual mapping

Change the default visual mapping to something that doesn't begin with `c` (or
any other existing operator).

    vmap <Leader>cx <Plug>Exchange

[iss11]: https://github.com/tommcdo/vim-exchange/issues/11
[timeoutlen]: http://vimdoc.sourceforge.net/htmldoc/options.html#'timeoutlen'

Installation
------------

If you don't have a preferred installation method, I recommend
installing [pathogen.vim](https://github.com/tpope/vim-pathogen), and
then simply copy and paste:

    cd ~/.vim/bundle
    git clone git://github.com/tommcdo/vim-exchange.git

Once help tags have been generated, you can view the manual with
`:help exchange`.
