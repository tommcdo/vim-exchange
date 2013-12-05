exchange.vim
============

Easy text exchange operator for Vim.

Mappings
--------

`cx`

On the first use, define the first {motion} to exchange. On the second use, define the second {motion} and perform the exchange.

`cxc`

Clear any {motion} pending for exchange.

Example
-------

To exchanges two words, place your cursor on the first word and type `cxiw`. Then move to the second word and type `cxiw` again. Note: the {motion} used in the first and second use of `cx` don't have to be the same.
