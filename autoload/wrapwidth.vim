" wrapwidth.vim : Wraps long lines visually at a specific column
"
" Last Change: 2024/01/07
" Version:     3.0
" Author:      Rick Howe (Takumi Ohtani) <rdcxy754@ybb.ne.jp>
" Copyright:   (c) 2023-2024 by Rick Howe
" License:     MIT

let s:save_cpo = &cpoptions
set cpo&vim

let s:ww = 'wrapwidth'
let s:wh = 'wrapwidth_hl'

function! wrapwidth#Wrapwidth(sl, el, ww) abort
  if type(a:ww) == type(0)
    let cw = win_getid() | let cb = winbufnr(cw)
    let bv = getbufvar(cb, '')
    let ll = range(a:sl, a:el)
    let on = (a:ww != 0)
    if on || has_key(bv, s:ww)
      if on
        if !has_key(bv, s:ww)
          call s:ClearUntyped(cb)
          let bv[s:ww] = #{lw: {}, wd: winwidth(cw), ch: [], lc: 0}
          call s:SetProptype(cb, 1)
          call s:SetListener(cb, 1)
        endif
        for ln in filter(ll,
                \'!has_key(bv[s:ww].lw, v:val) || bv[s:ww].lw[v:val] != a:ww')
          let bv[s:ww].lw[ln] = a:ww
        endfor
      endif
      call s:SetWrapwidth(on, ll)
      if !on
        for ln in filter(ll, 'has_key(bv[s:ww].lw, v:val)')
          unlet bv[s:ww].lw[ln]
        endfor
        if empty(bv[s:ww].lw)
          call s:SetListener(cb, 0)
          call s:SetProptype(cb, 0)
          unlet bv[s:ww]
          call s:ClearUntyped(cb)
        endif
      endif
      call s:SetEvent(on)
    endif
  else
    echohl ErrorMsg | echo 'argument is not number' | echohl None
  endif
endfunction

function! s:SetWrapwidth(on, ll) abort
  let cw = win_getid() | let cb = winbufnr(cw)
  let on = a:on && &wrap && !&binary && !&compatible && !&paste
  if on
    let wi = getwininfo(cw)[0]
    let tl = wi.width - wi.textoff
    if &list
      let ex = matchstr(&listchars, 'extends:\zs.\{-}\ze\(,\|$\)')
      let ex = empty(ex) ? ' ' : (ex[0] == '\') ? nr2char('0x' . ex[2:]) : ex
    endif
    let kt = &linebreak && !empty(&breakat)
    if kt
      let kp = '[' . escape(&breakat, ']^-\') . ']'
      let kq = '.*' . kp . '\ze\%(' . kp . '\)\@!.'
    endif
    let tn = tl + ((&cpoptions =~ 'n' &&
                            \(&number || &relativenumber)) ? &numberwidth : 0)
  endif
  let bw = getbufvar(cb, s:ww)
  for ln in a:ll
    call s:Propremove(cb, ln)
    if on && has_key(bw.lw, ln)
      let ww = bw.lw[ln]
      let [tw, wm] = (0 < ww) ? [ww, tl - ww] : [tl + ww, -ww]
      if 0 < tw && 0 < wm
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
            let kx = matchend(tx[: bc - 2], kq, bs - 1)
            if kx != -1
              let bc = kx + 1
              let vd = vc - virtcol([ln, bc], 1)[0]
            endif
          endif
          let tz = repeat(' ', wm + vd)
          if !empty(tz)
            if &list && 0 <= vd
              let tz = substitute(tz, '\%' . (vd + 1) . 'c.', ex, '')
            endif
            call s:Propadd(cb, ln, bc, tz)
          endif
          let vc += tn
          let bs = bc
        endwhile
      endif
    endif
  endfor
endfunction

let s:wv = extend(#{-1: 'OptionSet', -2: 'WinScrolled', 1: 'TextChanged',
                            \2: 'InsertLeave', 3: 'WinEnter', 4: 'BufEnter'},
                                      \!has('nvim') ? #{5: 'BufUnload'} : {})

function! s:SetEvent(on) abort
  let ac = ['augroup ' . s:ww, 'autocmd!']
  let bl = filter(range(1, bufnr('$')), '!empty(getbufvar(v:val, s:ww, {}))')
  if !empty(bl)
    for [en, ev] in items(s:wv)
      let [ea, eb] = ['autocmd ' . ev, 'call s:CheckEvent(' . en . ')']
      if 0 < en
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

function! s:CheckEvent(en) abort
  let cw = win_getid() | let cb = winbufnr(cw)
  let wl = []
  let ev = s:wv[a:en]
  if ev == 'OptionSet'
    if v:option_old != v:option_new
      let op = expand('<amatch>')
      for [gl, ol] in items(#{m: ['showbreak', 'listchars'],
                        \g: ['breakat', 'cpoptions', 'display', 'ambiwidth'],
                \l: ['wrap', 'list', 'tabstop', 'vartabstop', 'linebreak',
                \'breakindent', 'breakindentopt', 'number', 'relativenumber',
                \'numberwidth', 'foldcolumn', 'signcolumn', 'statuscolumn']})
        if index(ol, op) != -1
          if gl == 'm' | let gl = v:option_type[0] | endif
          let wl += (gl == 'l') ? [cw] : map(getwininfo(), 'v:val.winid')
          break
        endif
      endfor
    endif
  elseif ev == 'TextChanged' || ev == 'InsertLeave'
    if !has('nvim') | call listener_flush(cb) | endif
    let bw = getbufvar(cb, s:ww)
    let ul = []
    for [sl, el, na] in bw.ch
      " find updated (changed and added) lines
      let ul += filter(range(sl, el - 1 + na), 'index(ul, v:val) == -1')
      if na != 0
        " remove deleted lines
        if na < 0
          for ln in filter(range(sl, el - 1),
                    \'has_key(bw.lw, v:val) && empty(s:Proplist(cb, v:val))')
            unlet bw.lw[ln]
          endfor
        endif
        " shift up or down unchanged lines
        let lw = {}
        for ln in filter(keys(bw.lw), 'el <= str2nr(v:val)')
          let lw[ln + na] = bw.lw[ln] | unlet bw.lw[ln]
        endfor
        call extend(bw.lw, lw)
        " copy to added broken lines by CR
        if 0 < na && sl < el && has_key(bw.lw, sl)
          for ln in filter(range(el, el - 1 + na),
                  \'!has_key(bw.lw, v:val) && !empty(s:Proplist(cb, v:val))')
            let bw.lw[ln] = bw.lw[sl]
          endfor
        endif
      endif
    endfor
    if !empty(ul) | let wl += [cw] | endif
    let bw.ch = []
  elseif ev == 'WinScrolled'
    let wl += map(filter(keys(v:event),
            \'v:val != "all" && v:event[v:val].width != 0'), 'str2nr(v:val)')
  elseif ev == 'WinEnter' || ev == 'BufEnter'
    let bw = getbufvar(cb, s:ww)
    if bw.wd != winwidth(cw) | let wl += [cw] | endif
  elseif ev == 'BufUnload'
    let cb = str2nr(expand('<abuf>'))
    call s:SetListener(cb, 0)
    let bv = getbufvar(cb, '')
    if has_key(bv, s:ww) | unlet bv[s:ww] | endif
    call s:SetEvent(0)
  endif
  if !empty(wl)
    " execute on one window per buffer (in case of split)
    let bz = {}
    for wn in wl
      let bn = winbufnr(wn)
      if !empty(getbufvar(bn, s:ww, {}))
        let bz[bn] = (has_key(bz, bn) ? bz[bn] : []) + [wn]
      endif
    endfor
    for bn in keys(bz)
      let wn = (index(bz[bn], cw) != -1) ? cw : bz[bn][-1]
      call win_execute(wn, 'call s:SetWrapwidth(1,
                              \exists("ul") ? ul : range(1, line("$", wn)))')
      let bw = getbufvar(str2nr(bn), s:ww) | let bw.wd = winwidth(wn)
    endfor
  endif
endfunction

if has('nvim')
  let s:wn = nvim_create_namespace(s:ww)
  let s:cb = 'wrapwidth_cb'

  function! s:SetListener(bn, on) abort
    let bw = getbufvar(a:bn, s:ww)
    if a:on && bw.lc == 0
      let bw.lc = 1
      let bv = getbufvar(a:bn, '')
      if !has_key(bv, s:cb)
        " do never attach a callback duplicately!
        let bv[s:cb] = bv.changedtick
        lua vim.api.nvim_buf_attach(vim.api.nvim_eval('a:bn'), false,
                    \ {on_lines = function(_, bn, _, sl, el, ul, ...)
                    \ return vim.fn.ListenBuf(bn, sl + 1, el + 1, ul - el, {})
                    \ end})
      endif
    elseif !a:on && bw.lc != 0
      let bw.lc = 0
    endif
  endfunction

  function! ListenBuf(bn, sl, el, na, ch) abort
    let ng = v:false
    let bw = getbufvar(a:bn, s:ww)
    if !empty(bw)
      let bw.ch += [[a:sl, a:el, a:na]]
    else
      " a callback must return v:true to detach itself when wrapwidth is
      " disabled, no function like listener_remove() in nvim
      let bv = getbufvar(a:bn, '')
      if has_key(bv, s:cb) | unlet bv[s:cb] | let ng = v:true | endif
    endif
    return ng
  endfunction

  function! s:SetProptype(bn, on) abort
  endfunction

  function! s:Propadd(bn, ln, co, tx) abort
    let hl = getbufvar(a:bn, s:wh, get(g:, s:wh, ''))
    if hlID(hl) == 0 | let hl = 'NonText' | endif
    call nvim_buf_set_extmark(a:bn, s:wn, a:ln - 1, a:co - 1,
                          \#{virt_text: [[a:tx, hl]], virt_text_pos: 'inline',
                                  \undo_restore: v:false, invalidate: v:true})
  endfunction

  function! s:Propremove(bn, ln) abort
    for id in s:Proplist(a:bn, a:ln)
      call nvim_buf_del_extmark(a:bn, s:wn, id[0])
    endfor
  endfunction

  function! s:Proplist(bn, ln) abort
    return nvim_buf_get_extmarks(a:bn, s:wn, [a:ln - 1, 0], [a:ln - 1, -1], {})
  endfunction

  function! s:ClearUntyped(bn) abort
  endfunction
else
  call prop_type_add(s:ww, #{highlight: 'NonText'})

  function! s:SetListener(bn, on) abort
    let bw = getbufvar(a:bn, s:ww)
    if a:on && bw.lc == 0
      let bw.lc = listener_add('s:ListenBuf', a:bn)
    elseif !a:on && bw.lc != 0
      call listener_remove(bw.lc)
      let bw.lc = 0
    endif
  endfunction

  function! s:ListenBuf(bn, sl, el, na, ch) abort
    let bw = getbufvar(a:bn, s:ww)
    if !empty(bw)
      let bw.ch += map(copy(a:ch), '[v:val.lnum, v:val.end, v:val.added]')
    endif
  endfunction

  function! s:SetProptype(bn, on) abort
    let pt = prop_type_get(s:ww, #{bufnr: a:bn})
    if a:on && empty(pt)
      let hl = getbufvar(a:bn, s:wh, get(g:, s:wh, ''))
      if hlID(hl) == 0 | let hl = 'NonText' | endif
      call prop_type_add(s:ww, #{bufnr: a:bn, highlight: hl})
    elseif !a:on && !empty(pt)
      call prop_type_delete(s:ww, #{bufnr: a:bn})
    endif
  endfunction

  function! s:Propadd(bn, ln, co, tx) abort
    call prop_add(a:ln, a:co, #{bufnr: a:bn, type: s:ww, text: a:tx})
  endfunction

  function! s:Propremove(bn, ln) abort
    if !empty(s:Proplist(a:bn, a:ln))
      call prop_remove(#{bufnr: a:bn, type: s:ww, all: 1}, a:ln)
    endif
  endfunction

  function! s:Proplist(bn, ln) abort
    return prop_list(a:ln, #{bufnr: a:bn, types: [s:ww]})
  endfunction

  function! s:ClearUntyped(bn) abort
    for pr in filter(prop_list(1, #{bufnr: a:bn, end_lnum: -1}),
                                                  \'!has_key(v:val, "type")')
      call prop_clear(pr.lnum, pr.lnum, #{bufnr: a:bn})
    endfor
  endfunction
endif

let &cpoptions = s:save_cpo
unlet s:save_cpo

" vim: ts=2 sw=0 sts=-1 et
