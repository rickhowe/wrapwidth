" wrapwidth.vim : Wraps long lines visually at a specific column
"
" Last Change: 2023/12/16
" Version:     2.0
" Author:      Rick Howe (Takumi Ohtani) <rdcxy754@ybb.ne.jp>
" Copyright:   (c) 2023 by Rick Howe
" License:     MIT

if exists('g:loaded_wrapwidth') ||
            \!(has('textprop') && has('patch-9.0.0067') || has('nvim-0.10.0'))
  finish
endif
let g:loaded_wrapwidth = 2.0

let s:save_cpo = &cpoptions
set cpo&vim

command! -nargs=1 -bar Wrapwidth call wrapwidth#ToggleWrapwidth(<args>)

let &cpoptions = s:save_cpo
unlet s:save_cpo

" vim: ts=2 sw=0 sts=-1 et
