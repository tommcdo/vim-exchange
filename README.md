exchange.vim
============

Easy text exchange operator for Vim.

Mappings
--------

`cx`

On the first use, define the first {motion} to exchange. On the second use,
define the second {motion} and perform the exchange.

The operator can also be used from visual mode.

`cxx`

Like `cx`, but use the current line.

`cxc`

Clear any {motion} pending for exchange.

Example
-------

To exchange two words, place your cursor on the first word and type `cxiw`.
Then move to the second word and type `cxiw` again. Note: the {motion} used in
the first and second use of `cx` don't have to be the same.

Installation
------------

If you don't have a preferred installation method, I recommend
installing [pathogen.vim](https://github.com/tpope/vim-pathogen), and
then simply copy and paste:

    cd ~/.vim/bundle
    git clone git://github.com/tommcdo/vim-exchange.git

Once help tags have been generated, you can view the manual with
`:help exchange`.
