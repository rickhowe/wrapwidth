# wrapwidth

### Wraps long lines visually at a specific column

The `wrap` option is useful but no way to select a column to be wrapped. And
the `textwidth` and `wrapmargin` options break a long line but it is hard
wrapped in insert mode.

![sample0](sample0.png)

This plugin provides the *:Wrapwidth* command to set a column at which a
longer line will be visually wrapped. When `wrap` is on, the required number
of blank spaces are inserted as **virtual-text** at right edge of each screen
line.

![sample1](sample1.png)

![sample2](sample2.png)

While *wrapwidth* is enabled, those virtual spaces will be adjusted with
several options (such as `linebreak`, `showbreak`, `number`, `numberwidth`,
`foldcolumn`, `tabstop`) as well as the change of text and window width, which
affect the way the text is visually displayed.

If a file is big and not necessary to visually wrap all lines at the same
column, it is possible to specify a range to set *wrapwidth* lines.

When `list` is on, an "extends" character specified in `listchars` is shown
at the wrap column in the virtual spaces.

Note that the inline **virtual-text** feature has been implemented in vim
post-9.0 patches and nvim 0.10.0.

#### Command

* `:[range]Wrapwidth N`
  * Set a *wrapwidth* at the N-th column in the current buffer. A longer line
    will be visually wrapped at that column and continued to the next screen
    line. It is possible to specify *wrapwidth* lines in `[range]` (default: all
    lines) in a buffer.
    - N > 0: a text width from left edge of a text, like `textwidth`
    - N < 0: a wrap margin from right edge of a window, like `wrapmargin`
    - N = 0: disables the *wrapwidth*

#### Option

* `b:wrapwidth_hl`, `g:wrapwidth_hl`
  * A highlight group name to make *wrapwidth* virtual spaces visible.
