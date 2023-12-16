" wrapwidth.vim : Wraps long lines visually at a specific column
"
" Last Change: 2023/12/16
" Version:     2.0
" Author:      Rick Howe (Takumi Ohtani) <rdcxy754@ybb.ne.jp>
" Copyright:   (c) 2023 by Rick Howe
" License:     MIT

let s:save_cpo = &cpoptions
set cpo&vim

let s:ww = 'wrapwidth'
let s:wh = 'wrapwidth_hl'
let s:wl = 'wrapwidth_ls'

function! wrapwidth#ToggleWrapwidth(ww) abort
  if type(a:ww) == type(0)
    let bv = getbufvar(bufnr('%'), '')
    if a:ww != (has_key(bv, s:ww) ? bv[s:ww] : 0)
      let on = (a:ww != 0)       "0:delete, 1:add/change
      if on
        let bv[s:ww] = a:ww
        call s:SetProptype(on)
      endif
      call s:ShowWrapwidth(on)
      if !on
        call s:SetProptype(on)
        unlet bv[s:ww]
      endif
      call s:SetListener(on)
      call s:SetEvent(on)
    endif
  else
    echohl ErrorMsg | echo 'argument is not number' | echohl None
  endif
endfunction

function! s:ShowWrapwidth(on, ...) abort
  let cw = win_getid() | let cb = winbufnr(cw)
  let ll = (0 < a:0 && type(a:1) == type([])) ? a:1 : range(1, line('$'))
  for ln in ll | call s:Propremove(cb, ln) | endfor
  if a:on
    let ww = getbufvar(cb, s:ww, 0)
    let wi = getwininfo(cw)[0]
    let tl = wi.width - wi.textoff
    let [tw, sw] = (0 < ww) ? [ww, tl - ww] : [tl + ww, -ww]
    if &wrap && 0 < tw && 0 < sw
      let kt = &linebreak && !empty(&breakat)
      let sp = matchstr(&listchars, 'extends:\zs.\ze')
      if !&list || empty(sp) | let sp = ' ' | endif
      if kt
        let kp = '[' . escape(&breakat, ']^-\') . ']'
        let kq = '.*' . kp . '\ze\%(' . kp . '\)\@!.'
      endif
      let tn = tl + ((&cpoptions =~ 'n' &&
                            \(&number || &relativenumber)) ? &numberwidth : 0)
      for ln in ll
        let tx = getline(ln)
        let vc = tw + 1
        let bs = 1
        while vc < virtcol([ln, '$'])
          let bc = virtcol2col(cw, ln, vc)
          let [vs, ve] = virtcol([ln, bc], 1)
          let vd = vc - vs
          if 0 < vd && (bc <= bs || kt && tx[bc - 1] =~ kp &&
                                              \!(&list && tx[bc - 1] == "\t"))
            " wrap at a next of:
            " a single multicolumn char (^I/<xx>/nonASCII)
            " a breakat char, except a printable tab in list mode
            if virtcol([ln, '$']) - ve < 2 | break | endif
            let bc += len(strcharpart(tx[bc - 1 :], 0, 1))
            let vd = -(ve - vc + 1)
          endif
          if kt
            " find and wrap at a rightmost breakat char
            let kx = matchend(tx[: bc - 1], kq, bs - 1)
            if kx != -1
              let bc = kx + 1
              let vd = vc - virtcol([ln, bc])
            endif
          endif
          call s:Propadd(cb, ln, bc, repeat(sp, sw + vd))
          let vc += tn
          let bs = bc
        endwhile
      endfor
    endif
  endif
endfunction

function! s:SetEvent(on) abort
  let bl = filter(range(1, bufnr('$')), 'getbufvar(v:val, s:ww, 0) != 0')
  let ac = ['augroup ' . s:ww, 'autocmd!']
  if !empty(bl)
    for ev in ['OptionSet', 'WinScrolled', 'TextChanged,InsertLeave']
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
  let ll = 1
  let wl = []
  if a:ev == 'O'          " OptionSet
    if v:option_old != v:option_new
      let op = expand('<amatch>')
      for [gl, ol] in [['l', ['wrap', 'list', 'tabstop', 'vartabstop',
                                \'linebreak', 'breakindent', 'breakindentopt',
                                \'number', 'relativenumber', 'numberwidth',
                                \'foldcolumn', 'signcolumn', 'statuscolumn']],
                    \['g', ['breakat', 'cpoptions', 'display', 'ambiwidth']],
                    \['m', ['showbreak', 'listchars']]]
        if index(ol, op) != -1
          if gl == 'm' | let gl = v:option_type[0] | endif
          let wl += (gl == 'l') ? [cw] : map(getwininfo(), 'v:val.winid')
          break
        endif
      endfor
    endif
  elseif a:ev == 'W'      " WinScrolled
    for wn in keys(v:event)
      if wn != 'all' && v:event[wn].width != 0 | let wl += [eval(wn)] | endif
    endfor
  elseif a:ev == 'T'      " TextChanged/InsertLeave
    let cb = winbufnr(cw)
    if !has('nvim') | call listener_flush(cb) | endif
    let lt = getbufvar(cb, s:wl)
    let ll = []
    for ch in lt.ch
      for ln in range(ch[0], ch[1] - 1 + ch[2])
        if index(ll, ln) == -1 | let ll += [ln] | endif
      endfor
    endfor
    if !empty(ll) | let wl += [cw] | endif
    let lt.ch = []
  endif
  " select one win per buf (in case of splitted)
  let bw = {}
  for wn in wl
    let bn = winbufnr(wn)
    if getbufvar(bn, s:ww, 0) != 0
      let bw[bn] = (has_key(bw, bn) ? bw[bn] : []) + [wn]
    endif
  endfor
  for wl in values(bw)
    call win_execute((index(wl, cw) != -1) ? cw : wl[-1],
                                              \'call s:ShowWrapwidth(1, ll)')
  endfor
endfunction

if has('nvim')
  let s:wx = 'wrapwidth_lsx'

  function! s:SetListener(on) abort
    let cb = bufnr('%')
    let bv = getbufvar(cb, '')
    if a:on && !has_key(bv, s:wl)
      let bv[s:wl] = #{ch: []}
      if !has_key(bv, s:wx)
        let bv[s:wx] = bv.changedtick
        lua vim.api.nvim_buf_attach(vim.api.nvim_eval('cb'), false,
            \ {on_lines = function(st, bn, _, sl, el, ul, ...)
            \ return vim.fn.WrapwidthListener(bn, sl + 1, el + 1, ul - el, st)
            \ end})
      endif
    elseif !a:on && has_key(bv, s:wl)
      unlet bv[s:wl]
    endif
  endfunction

  function! WrapwidthListener(bn, sl, el, na, ch) abort
    let ng = v:false
    let bv = getbufvar(a:bn, '')
    if has_key(bv, s:wl)
      let bv[s:wl].ch += [[a:sl, a:el, a:na]]
    else
      if has_key(bv, s:wx) | unlet bv[s:wx] | let ng = v:true | endif
    endif
    return ng
  endfunction

  function! s:SetProptype(on) abort
  endfunction

  function! s:Propadd(bn, ln, co, tx) abort
    let hl = getbufvar(a:bn, s:wh, get(g:, s:wh, ''))
    if hlID(hl) == 0 | let hl = 'NonText' | endif
    call nvim_buf_set_extmark(a:bn, s:wn, a:ln - 1, a:co - 1,
                          \#{virt_text: [[a:tx, hl]], virt_text_pos: 'inline',
                                            \undo_restore: 0, invalidate: 1})
  endfunction

  function! s:Propremove(bn, ln) abort
    for id in nvim_buf_get_extmarks(a:bn, s:wn,
                                          \[a:ln - 1, 0], [a:ln - 1, -1], {})
      call nvim_buf_del_extmark(a:bn, s:wn, id[0])
    endfor
  endfunction

  let s:wn = nvim_create_namespace(s:ww)
else
  function! s:SetListener(on) abort
    let cb = bufnr('%')
    let bv = getbufvar(cb, '')
    if a:on && !has_key(bv, s:wl)
      let bv[s:wl] = #{ch: [], id: listener_add('s:WrapwidthListener', cb)}
    elseif !a:on && has_key(bv, s:wl)
      call listener_remove(bv[s:wl].id)
      unlet bv[s:wl]
    endif
  endfunction

  function! s:WrapwidthListener(bn, sl, el, na, ch) abort
    let lt = getbufvar(a:bn, s:wl)
    if !empty(lt)
      let lt.ch += map(copy(a:ch), '[v:val.lnum, v:val.end, v:val.added]')
    endif
  endfunction

  function! s:SetProptype(on) abort
    let cb = bufnr('%')
    let pt = prop_type_get(s:ww, #{bufnr: cb})
    if a:on
      let hl = get(b:, s:wh, get(g:, s:wh, ''))
      if hlID(hl) == 0 | let hl = 'NonText' | endif
      if empty(pt)
        " clear accidentally untyped garbage prop here
        for gp in filter(prop_list(1, #{bufnr: cb, end_lnum: -1}),
                                                  \'!has_key(v:val, "type")')
          call prop_clear(gp.lnum, gp.lnum, #{bufnr: cb})
        endfor
        call prop_type_add(s:ww, #{bufnr: cb, highlight: hl})
      elseif pt.highlight != hl
        call prop_type_change(s:ww, #{bufnr: cb, highlight: hl})
      endif
    else
      if !empty(pt) | call prop_type_delete(s:ww, #{bufnr: cb}) | endif
    endif
  endfunction

  function! s:Propadd(bn, ln, co, tx) abort
    call prop_add(a:ln, a:co, #{type: s:ww, bufnr: a:bn, text: a:tx})
  endfunction

  function! s:Propremove(bn, ln) abort
    if !empty(prop_list(a:ln, #{types: [s:ww], bufnr: a:bn}))
      call prop_remove(#{type: s:ww, bufnr: a:bn, all: 1}, a:ln)
    endif
  endfunction

  call prop_type_add(s:ww, #{})
endif

let &cpoptions = s:save_cpo
unlet s:save_cpo

" vim: ts=2 sw=0 sts=-1 et
