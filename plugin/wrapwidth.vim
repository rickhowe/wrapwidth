" wrapwidth.vim : Wraps long lines visually at a specific column
"
" Last Change: 2024/02/17
" Version:     3.2
" Author:      Rick Howe (Takumi Ohtani) <rdcxy754@ybb.ne.jp>
" Copyright:   (c) 2023-2024 by Rick Howe
" License:     MIT

if exists('g:loaded_wrapwidth') ||
            \!(has('textprop') && has('patch-9.0.0917') || has('nvim-0.10.0'))
  finish
endif
let g:loaded_wrapwidth = 3.2

let s:save_cpo = &cpoptions
set cpo&vim

command! -range=% -nargs=? -bang -bar Wrapwidth
    \ call wrapwidth#Wrapwidth(<line1>, <line2>, <bang>1 ? <q-args> : v:null)

let &cpoptions = s:save_cpo
unlet s:save_cpo

" vim: ts=2 sw=0 sts=-1 et
