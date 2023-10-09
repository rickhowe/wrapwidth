" wrapwidth.vim : Wraps long lines visually at a specific column
"
" Last Change: 2023/10/09
" Version:     1.0
" Author:      Rick Howe (Takumi Ohtani) <rdcxy754@ybb.ne.jp>
" Copyright:   (c) 2023 by Rick Howe
" License:     MIT

let s:save_cpo = &cpoptions
set cpo&vim

let s:ww = 'wrapwidth'

function! wrapwidth#ToggleWrapwidth(ww) abort
  let cw = win_getid()
  if a:ww == getwinvar(cw, s:ww, 0) | return | endif
  for wn in win_findbuf(winbufnr(cw))
    if a:ww == 0
      let wv = getwinvar(wn, '')
      if has_key(wv, s:ww) | unlet wv[s:ww] | endif
    else
      call setwinvar(wn, s:ww, a:ww)
    endif
  endfor
  call s:SetEvent()
  call s:Wrapwidth()
endfunction

function! s:Wrapwidth() abort
  let cw = win_getid() | let cb = winbufnr(cw)
  call s:Prop_remove(cb)
  let ww = getwinvar(cw, s:ww, 0)
  if ww == 0 | return | endif
  let wi = getwininfo(cw)[0]
  let tl = wi.width - wi.textoff
  let tw = (0 < ww) ? ww : tl + ww
  if &wrap && 0 < tw && tw < tl
    let ex = matchstr(&listchars, 'extends:\zs.\ze')
    if !&list || empty(ex) | let ex = ' ' | endif
    if &linebreak
      let kp = '\V\%\(' . join(split(&breakat, '\zs'), '\|') . '\)'
    endif
    for ln in range(1, line('$'))
      let tx = getline(ln)
      let kl = []
      if &linebreak
        let ks = 0
        while 1
          let ks = matchend(tx, kp, ks)
          if ks != -1 | let kl += [ks] | else | break | endif
        endwhile
      endif
      let vc = tw + 1
      while vc < virtcol([ln, '$'])
        let bc = virtcol2col(cw, ln, vc)
        if (!&list || &listchars =~ 'tab') && tx[bc - 1] == "\t" ||
                              \!empty(kl) && bc == virtcol2col(cw, ln, vc - 1)
          let bc += 1
        endif
        if !empty(kl)
          let ki = 0
          while ki < len(kl) && kl[ki] < bc | let ki += 1 | endwhile
          if 0 < ki | let bc = kl[ki - 1] + 1 | let kl = kl[ki :] | endif
        endif
        call s:Prop_add(cb, ln, bc,
                              \repeat(ex, tl - tw - (virtcol([ln, bc]) - vc)))
        let vc += (&cpoptions =~ 'n') ? wi.width : tl
      endwhile
    endfor
  endif
endfunction

function! s:SetEvent() abort
  let bl = []
  for bi in getbufinfo()
    if !empty(filter(bi.windows, 'getwinvar(v:val, s:ww, 0) != 0'))
      let bl += [bi.bufnr]
    endif
  endfor
  let ac = ['augroup ' . s:ww, 'autocmd!']
  if !empty(bl)
    for [en, ev] in items({1: 'OptionSet', 2: 'WinResized', 3: 'TextChanged'})
      if en == 3
        for bn in bl
          let ac += ['autocmd ' . ev . ' <buffer='. bn .
                                          \'>  call s:CheckEvent(' . en . ')']
        endfor
      else
        let ac += ['autocmd ' . ev . ' * call s:CheckEvent(' . en . ')']
      endif
    endfor
  endif
  let ac += ['augroup END']
  if empty(bl) | let ac += ['augroup! ' . s:ww] | endif
  call execute(ac)
endfunction

function! s:CheckEvent(en) abort
  let cw = win_getid()
  let wl = []
  if a:en == 1          " OptionSet
    let op = expand('<amatch>')
    if v:option_old != v:option_new
      if index(['wrap', 'linebreak', 'breakindent', 'breakindentopt', 'list',
                    \'number', 'relativenumber', 'numberwidth', 'foldcolumn',
                            \'signcolumn', 'tabstop', 'vartabstop'], op) != -1
        let wl += [cw]
      elseif index(['breakat', 'showbreak', 'listchars', 'cpoptions'], op) != -1
        let wl += map(getwininfo(), 'v:val.winid')
      endif
    endif
  elseif a:en == 2      " WinResized
    let wl += v:event.windows
  elseif a:en == 3      " TextChanged
    let wl += [cw]
  endif
  if 1 < len(wl)
    let ci = index(wl, cw)
    if 0 <= ci | unlet wl[ci] | let wl += [cw] | endif
  endif
  for wn in wl
    let ww = getwinvar(wn, s:ww, 0)
    if ww != 0
      for wx in win_findbuf(winbufnr(wn))
        if wn != wx && ww != getwinvar(wx, s:ww, 0)
          call setwinvar(wx, s:ww, ww)
        endif
      endfor
      call win_execute(wn, 'call s:Wrapwidth()')
    endif
  endfor
endfunction

if has('nvim')
  let s:ns = nvim_create_namespace(s:ww)

  function! s:Prop_add(bn, ln, co, tx) abort
    call nvim_buf_set_extmark(a:bn, s:ns, a:ln - 1, a:co - 1,
                  \#{virt_text: [[a:tx, 'NonText']], virt_text_pos: 'inline'})
  endfunction

  function! s:Prop_remove(bn) abort
    for id in nvim_buf_get_extmarks(a:bn, s:ns, 0, -1, {})
      call nvim_buf_del_extmark(a:bn, s:.ns, id[0])
    endfor
  endfunction
else
  if !empty(prop_type_get(s:ww))
    call prop_type_delete(s:ww)
  endif
  call prop_type_add(s:ww, #{highlight: 'NonText'})

  function! s:Prop_add(bn, ln, co, tx) abort
    call prop_add(a:ln, a:co, #{type: s:ww, bufnr: a:bn, text: a:tx})
  endfunction

  function! s:Prop_remove(bn) abort
    let [ln, co] = [1, 1]
    while 1
      let pp = prop_find(#{type: s:ww, bufnr: a:bn, lnum: ln, col: co})
      if empty(pp) | break | endif
      call prop_remove(#{type: s:ww, bufnr: a:bn}, pp.lnum)
      let [ln, co] = [pp.lnum, pp.col + 1]
    endwhile
  endfunction
endif

let &cpoptions = s:save_cpo
unlet s:save_cpo

" vim: ts=2 sw=0 sts=-1 et
