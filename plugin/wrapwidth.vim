" wrapwidth.vim : Wraps long lines visually at a specific column
"
" Last Change: 2024/01/22
" Version:     3.1
" Author:      Rick Howe (Takumi Ohtani) <rdcxy754@ybb.ne.jp>
" Copyright:   (c) 2023-2024 by Rick Howe
" License:     MIT

if exists('g:loaded_wrapwidth') ||
            \!(has('textprop') && has('patch-9.0.0917') || has('nvim-0.10.0'))
  finish
endif
let g:loaded_wrapwidth = 3.1

let s:save_cpo = &cpoptions
set cpo&vim

command! -range=% -nargs=1 -bar Wrapwidth
                          \ call wrapwidth#Wrapwidth(<line1>, <line2>, <args>)

let &cpoptions = s:save_cpo
unlet s:save_cpo

" vim: ts=2 sw=0 sts=-1 et
