" wrapwidth.vim : Wraps long lines visually at a specific column
"
" Last Change: 2023/10/21
" Version:     1.2
" Author:      Rick Howe (Takumi Ohtani) <rdcxy754@ybb.ne.jp>
" Copyright:   (c) 2023 by Rick Howe
" License:     MIT

let s:save_cpo = &cpoptions
set cpo&vim

let s:ww = 'wrapwidth'

function! wrapwidth#WrapWidth(ww) abort
  if type(a:ww) == type(0)
    let ww = getbufvar(bufnr('%'), s:ww, 0)
    if a:ww != ww
      let zz = (a:ww != 0) * 2 + (ww != 0)      " 1:delete, 2:add, 3:change
      if 0 < zz | call s:ShowWrapWidth(a:ww, zz) | endif
      call s:SetEvent()
    endif
  else
    echohl ErrorMsg | echo 'argument is not number' | echohl None
  endif
endfunction

function! s:ShowWrapWidth(ww, zz) abort
  let cw = win_getid() | let cb = winbufnr(cw)
  if a:zz == 1 || a:zz == 3         " delete or change
    let bv = getbufvar(cb, '') | if has_key(bv, s:ww) | unlet bv[s:ww] | endif
    call s:Prop_remove(cb)
  endif
  call s:Prop_type(cb, a:zz)
  if a:zz == 2 || a:zz == 3         " add or change
    call setbufvar(cb, s:ww, a:ww)
    let wi = getwininfo(cw)[0]
    let tl = wi.width - wi.textoff
    let tw = (0 < a:ww) ? a:ww : tl + a:ww
    let sw = tl - tw
    if &wrap && 0 < tw && 0 < sw
      let sp = matchstr(&listchars, 'extends:\zs.\ze')
      if !&list || empty(sp) | let sp = ' ' | endif
      if &linebreak | let kp = '[' . escape(&breakat, ']^-\') . ']' | endif
      let tn = tl + ((&cpoptions =~ 'n' &&
                            \(&number || &relativenumber)) ? &numberwidth : 0)
      for ln in range(1, line('$'))
        let tx = getline(ln)
        if &linebreak | let ks = 0 | endif
        let vc = tw + 1
        while vc < virtcol([ln, '$'])
          let bc = virtcol2col(cw, ln, vc)
          " should wrap at next char of breakat/tab if tw/sw is on its spaces
          let vx = 0
          if &linebreak
            if tx[bc - 1] =~ kp && bc == virtcol2col(cw, ln, vc - 1)
              let bc += 1 | let vx = 1
            else
              let kx = matchend(tx[: bc - 2], '.*\zs' . kp, ks)
              if kx != -1 | let bc = kx + 1 | let vx = 1 | endif
            endif
            let ks = bc - 1
          elseif (!&list || &listchars =~ 'tab') &&
                      \tx[bc - 1] == "\t" && bc == virtcol2col(cw, ln, vc - 1)
            let bc += 1 | let vx = 1
          endif
          call s:Prop_add(cb, ln, bc,
                          \repeat(sp, sw - (vx ? virtcol([ln, bc]) - vc : 0)))
          let vc += tn
        endwhile
      endfor
    endif
  endif
endfunction

function! s:SetEvent() abort
  let bl = filter(range(1, bufnr('$')), 'getbufvar(v:val, s:ww, 0) != 0')
  let ac = ['augroup ' . s:ww, 'autocmd!']
  if !empty(bl)
    for ev in ['OptionSet', 'WinScrolled', 'TextChanged']
      let [ea, eb] = ['autocmd ' . ev, 'call s:CheckEvent(''' . ev[0] . ''')']
      if ev[0] == 'T'
        for bn in bl | let ac += [ea . ' <buffer='. bn . '> ' . eb] | endfor
      else
        let ac += [ea . ' * ' . eb]
      endif
    endfor
  endif
  let ac += ['augroup END']
  if empty(bl) | let ac += ['augroup! ' . s:ww] | endif
  call execute(ac)
endfunction

function! s:CheckEvent(ev) abort
  let cw = win_getid()
  let wl = []
  if a:ev == 'O'          " OptionSet
    if v:option_old != v:option_new
      let op = expand('<amatch>')
      let gl = (index(['wrap', 'linebreak', 'breakindent', 'breakindentopt',
            \'list', 'number', 'relativenumber', 'numberwidth', 'foldcolumn',
                  \'signcolumn', 'tabstop', 'vartabstop'], op) != -1) ? 'l' :
                          \(index(['breakat', 'cpoptions'], op) != -1) ? 'g' :
        \(index(['showbreak', 'listchars'], op) != -1) ? v:option_type[0] : ''
      let wl += (gl == 'g') ? map(getwininfo(), 'v:val.winid') :
                                                      \(gl == 'l') ? [cw] : []
    endif
  elseif a:ev == 'W'      " WinScrolled
    for wn in keys(v:event)
      if wn != 'all' && v:event[wn].width != 0 | let wl += [eval(wn)] | endif
    endfor
  elseif a:ev == 'T'      " TextChanged
    let wl += [cw]
  endif
  " select one win per buf (in case of splitted)
  let bw = {}
  for wn in wl
    let bn = winbufnr(wn)
    if !has_key(bw, bn) | let bw[bn] = [] | endif | let bw[bn] += [wn]
  endfor
  for [bn, wl] in items(bw)
    let ww = getbufvar(eval(bn), s:ww, 0)
    if ww != 0
      call win_execute((index(wl, cw) != -1) ? cw : wl[-1],
                                              \'call s:ShowWrapWidth(ww, 3)')
    endif
  endfor
endfunction

if has('nvim')
  let s:ns = nvim_create_namespace(s:ww)

  function! s:Prop_type(bn, zz) abort
  endfunction

  function! s:Prop_add(bn, ln, co, tx) abort
    let hl = get(b:, s:ww . '_hl', get(g:, s:ww . '_hl', ''))
    if hlID(hl) == 0 | let hl = 'NonText' | endif
    call nvim_buf_set_extmark(a:bn, s:ns, a:ln - 1, a:co - 1,
                        \#{virt_text: [[a:tx, hl]], virt_text_pos: 'inline'})
  endfunction

  function! s:Prop_remove(bn) abort
    for id in nvim_buf_get_extmarks(a:bn, s:ns, 0, -1, {})
      call nvim_buf_del_extmark(a:bn, s:.ns, id[0])
    endfor
  endfunction
else
  call prop_type_add(s:ww, #{})

  function! s:Prop_type(bn, zz) abort
    let pt = prop_type_get(s:ww, #{bufnr: a:bn})
    if a:zz == 1                    " delete
      if !empty(pt) | call prop_type_delete(s:ww, #{bufnr: a:bn}) | endif
    else                            " add or change
      let hl = get(b:, s:ww . '_hl', get(g:, s:ww . '_hl', ''))
      if hlID(hl) == 0 | let hl = 'NonText' | endif
      call call(empty(pt) ? 'prop_type_add' : 'prop_type_change',
                                      \[s:ww, #{bufnr: a:bn, highlight: hl}])
    endif
  endfunction

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
