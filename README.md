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

`X`

Like `cx`, but for Visual mode.

`cxc`

Clear any {motion} pending for exchange.

### Some notes

* If you're using the same motion again (e.g. exchanging two words using
  `cxiw`), you can use `.` the second time.
* If one region is fully contained within the other, it will replace the
  containing region.

Example
-------

To exchange two words, place your cursor on the first word and type `cxiw`.
Then move to the second word and type `cxiw` again. Note: the {motion} used in
the first and second use of `cx` don't have to be the same.

More
----

Check out these other resources for more information:

* [Swapping two regions of text with exchange.vim][e65]

[e65]: http://vimcasts.org/episodes/swapping-two-regions-of-text-with-exchange-vim

Troubleshooting
---------------

More details and troubleshooting can be found in the [Wiki][wiki].

[wiki]: https://github.com/tommcdo/vim-exchange/wiki

Installation
------------

If you don't have a preferred installation method, I recommend
installing [pathogen.vim](https://github.com/tpope/vim-pathogen), and
then simply copy and paste:

    cd ~/.vim/bundle
    git clone git://github.com/tommcdo/vim-exchange.git

Once help tags have been generated, you can view the manual with
`:help exchange`.
