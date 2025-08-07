" wrapwidth.vim : Wraps long lines virtually at a specific column
"
" Last Change: 2025/08/07
" Version:     3.5
" Author:      Rick Howe (Takumi Ohtani) <rdcxy754@ybb.ne.jp>
" Copyright:   (c) 2023-2025 by Rick Howe
" License:     MIT

let s:save_cpo = &cpoptions
set cpo&vim

let s:ww = 'wrapwidth'
let s:wh = 'wrapwidth_hl'
let s:ws = 'wrapwidth_sign'
let s:wn = 'wrapwidth_number'

function! wrapwidth#Wrapwidth(sl, el, ww) abort
  let ww = str2nr(a:ww)
  if ww != 0 || a:ww == '0'
    let cw = win_getid() | let cb = winbufnr(cw)
    call s:CleanProp(cb)
    let bv = getbufvar(cb, '')
    let ll = range(a:sl, a:el)
    let on = (ww != 0)
    if on || has_key(bv, s:ww)
      if on
        if !has_key(bv, s:ww)
          let wi = getwininfo(cw)[0]
          let bv[s:ww] = #{lw: {}, wd: wi.width, to: wi.textoff, ch: [], lc: 0}
          call s:SetProptype(cb, 1)
          call s:SetListener(cb, 1)
        endif
        for ln in filter(ll, '!has_key(bv[s:ww].lw, v:val) ||
                                                  \bv[s:ww].lw[v:val] != ww')
          let bv[s:ww].lw[ln] = ww
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
        endif
      endif
      call s:SetEvent(on)
    endif
  elseif a:ww == v:null
    if has('nvim') || has('patch-9.0.1762')
      call s:RedrawWrapwidth(a:sl, a:el)
    else
      echohl ErrorMsg | echo 'patch 9.0.1762 is required' | echohl None
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
    let lb = &linebreak && !empty(&breakat)
    if lb
      let le = escape(&breakat, ']^-\')
      let lp = '^.*[' . le . ']\zs[^' . le . ']'
    endif
    let tn = tl + ((&cpoptions !~# 'n') ? 0 :
                          \&number ? max([len(line('$')) + 1, &numberwidth]) :
                                          \&relativenumber ? &numberwidth : 0)
    call s:ChangeProptype(cb)
    let ws = getbufvar(cb, s:ws, get(g:, s:ws, ''))
    let CountHidden = [{_ -> 0}, 's:CountSynHidden', 's:CountTSHidden']
                  \[(&conceallevel < 2) ? 0 : exists('b:current_syntax') ? 1 :
                            \has('nvim') && exists('b:ts_highlight') ? 2 : 0]
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
        let nu = 1
        while vc < virtcol([ln, '$'])
          let bc = virtcol2col(cw, ln, vc)
          let [vs, ve] = virtcol([ln, bc], 1)
          let vd = vc - vs
          if 0 < vd && bc <= bs
            " wrap at a next to a single multicolumn char (^I/<xx>/nonASCII)
            if virtcol([ln, '$']) - ve < 2 | break | endif
            let bc += len(strcharpart(tx[bc - 1 :], 0, 1))
            let vd = -(ve - vc + 1)
          endif
          if lb
            " find post-broken chars to fill until vc
            let tz = ''
            for ch in split(strcharpart(tx[bc - 1 :], 1, vd), '\zs')
              if vd < strwidth(tz . ch) | break | endif
              let tz .= ch
            endfor
            " wrap at a char next to a rightmost breakat char
            let lx = match(tx[: bc - 1 + max([vd, len(tz)])], lp, bs - 1)
            if lx != -1
              let bc = lx + 1
              let vd = vc - virtcol([ln, bc], 1)[0]
            endif
          endif
          if 0 < wm + vd
            let wn = getbufvar(cb, s:wn, get(g:, s:wn, 0)) ? nu : ''
            let wv = min([wm, wm + vd])
            let [cs, cn] = [split(ws, '\zs'), split(wn, '\zs')]
            let [ss, sn, is, in] = ['', '', 0, -1]
            while 0 < wv
              let wx = wv
              if is < len(cs)
                let wc = strwidth(cs[is])
                if wc <= wv
                  let ss .= cs[is] | let is += 1 | let wv -= wc
                endif
              endif
              if -in <= len(cn)
                let wc = strwidth(cn[in])
                if wc <= wv
                  let sn = cn[in] . sn | let in -= 1 | let wv -= wc
                endif
              endif
              if wx == wv | break | endif
            endwhile
            " adjust virtual spaces with hidden concealed chars if any
            let nh = call(CountHidden, [ln, bs, bc - 1])
            let tz = repeat(' ', vd + nh) . ss . repeat(' ', wv - nh) . sn
            call s:Propadd(cb, ln, bc, tz)
          endif
          let vc += tn
          let bs = bc
          let nu += 1
        endwhile
      endif
    endif
  endfor
endfunction

function! s:RedrawWrapwidth(sl, el) abort
  let cw = win_getid() | let cb = winbufnr(cw)
  let bw = getbufvar(cb, s:ww)
  if !empty(bw)
    let [tw, to] = (&cpoptions =~ 'n') ? [bw.wd, bw.to] : [bw.wd - bw.to, 0]
    let vt = s:FindProp(cb, a:sl, a:el)
    let rl = []
    for [ln, co, vw] in vt.1
      if index(rl, ln) == -1 &&
                            \(virtcol([ln, co], 1)[0] + vw - 1 + to) % tw != 0
        let rl += [ln]      " ww vt shown but not at the right edge
      endif
    endfor
    call map(vt.1, 'v:val[0]')
    for [ln, co, vw] in vt.0
      if index(vt.1 + rl, ln) == -1
        let rl += [ln]      " other vt shown but not in ww vt line
      endif
    endfor
    for ln in map(keys(bw.lw), 'str2nr(v:val)')
      if index(vt.1 + rl, ln) == -1
        let rl += [ln]      " ww vt not shown
      endif
    endfor
    call s:SetWrapwidth(1, rl)
  endif
endfunction

let s:ev = [['BufDelete', 'l'], ['BufHidden', 'l'], ['BufUnload', 'l'],
              \['BufWinEnter', 'l'], ['WinEnter', 'l'], ['TextChanged', 'l'],
              \['TextChangedI', 'l'], ['OptionSet', 'g'], ['WinResized', 'g']]

function! s:SetEvent(on) abort
  let ac = []
  let bl = filter(range(1, bufnr('$')), '!empty(getbufvar(v:val, s:ww))')
  if !empty(bl)
    for en in range(len(s:ev))
      let [ev, gl] = s:ev[en]
      if gl == 'l'
        for bn in bl | let ac += [[ev, '<buffer=' . bn . '>', en]] | endfor
      else
        let ac += [[ev, '*', en]]
      endif
    endfor
    call map(ac, '"autocmd " . v:val[0] . " " . v:val[1] .
                                    \" call s:CheckEvent(" . v:val[2] . ")"')
  endif
  let ac = ['augroup ' . s:ww, 'autocmd!'] + ac + ['augroup END'] +
                                      \(empty(ac) ? ['augroup! ' . s:ww] : [])
  call execute(ac)
endfunction

function! s:CheckEvent(en) abort
  let cw = win_getid() | let cb = winbufnr(cw)
  let wl = []
  let ev = s:ev[a:en][0]
  if ev == 'OptionSet'
    if v:option_old != v:option_new
      let op = expand('<amatch>')
      for [gl, ol] in items(#{m: ['showbreak', 'listchars'],
                        \g: ['breakat', 'cpoptions', 'display', 'ambiwidth'],
                    \l: ['wrap', 'list', 'tabstop', 'vartabstop', 'linebreak',
          \'breakindent', 'breakindentopt', 'concealcursor', 'conceallevel']})
        " check if text display is changed
        if index(ol, op) != -1
          if gl == 'm' | let gl = v:option_type[0] | endif
          let wl += (gl == 'l') ? [cw] : map(getwininfo(), 'v:val.winid')
          break
        endif
      endfor
      if empty(wl)
        " check if textoff is changed (eg: number, foldcolumn)
        let wi = getwininfo(cw)[0]
        let bw = getbufvar(cb, s:ww)
        if !empty(bw) && bw.to != wi.textoff
          let wl += [cw]
          let bw.to = wi.textoff
        endif
      endif
    endif
  elseif ev == 'TextChanged' || ev == 'TextChangedI'
    if !has('nvim') | call listener_flush(cb) | endif
    let bw = getbufvar(cb, s:ww)
    let ul = []
    for [sl, el, na] in bw.ch
      if na < 0
        " remove deleted lines
        for ln in filter(range(sl, el - 1), 'has_key(bw.lw, v:val)')
          if empty(s:Proplist(cb, ln)) | unlet bw.lw[ln] | endif
        endfor
      endif
      if na != 0
        " shift up or down unchanged lines
        let lw = {}
        for ln in filter(keys(bw.lw), 'el <= str2nr(v:val)')
          let lw[ln + na] = bw.lw[ln] | unlet bw.lw[ln]
        endfor
        call extend(bw.lw, lw)
      endif
      if 0 < na
        let sw = has_key(bw.lw, sl - 1) ? bw.lw[sl - 1] : 0
        let ew = has_key(bw.lw, el + na) ? bw.lw[el + na] : 0
        if sl < el
          " copy sl wrapwidth to broken lines (eg: a/i + \n)
          let ww = has_key(bw.lw, sl) ? bw.lw[sl] : 0
        else
          " copy sl-1/el+na same wrapwidth to added lines
          let ww = (sl - 1 < 1) ? ew :
                                  \(line('$') < el + na || sw == ew) ? sw : 0
        endif
        for ln in range(sl, el - 1 + na)
          let bw.lw[ln] = empty(s:Proplist(cb, ln)) ? ww :
                                        \(sw != 0) ? sw : (ew != 0) ? ew : ww
          if bw.lw[ln] == 0 | unlet bw.lw[ln] | endif
        endfor
      endif
      " find changed and added lines shifted by deleted lines
      if 0 <= na
        let ul += filter(range(sl, el - 1 + na), 'index(ul, v:val) == -1')
      else
        call map(ul, '(sl < v:val || el - 1 < v:val) ? v:val + na : v:val')
      endif
    endfor
    if !empty(ul) | let wl += [cw] | endif
    let bw.ch = []
  elseif ev == 'WinResized'
    for wn in v:event.windows
      let bn = winbufnr(wn)
      let bw = getbufvar(bn, s:ww)
      if !empty(bw) && bw.wd != winwidth(wn)
        let wl += [wn]
        let bw.wd = winwidth(wn)
      endif
    endfor
  elseif ev == 'WinEnter' || ev == 'BufWinEnter'
    if ev == 'BufWinEnter' | call s:SetProptype(cb, 1) | endif
    let bw = getbufvar(cb, s:ww)
    if bw.wd != winwidth(cw)
      let wl += [cw]
      let bw.wd = winwidth(cw)
    endif
  elseif ev == 'BufHidden' || ev == 'BufUnload' || ev == 'BufDelete'
    let cb = str2nr(expand('<abuf>'))
    if ev == 'BufDelete'
      call s:SetListener(cb, 0)
      let bv = getbufvar(cb, '')
      if has_key(bv, s:ww) | unlet bv[s:ww] | endif
      call s:SetEvent(0)
    else
      let bw = getbufvar(cb, s:ww)
      let bw.wd = 0
    endif
  endif
  if !empty(wl)
    " execute on one window per buffer (in case of split)
    let bz = {}
    for wn in wl
      let bn = winbufnr(wn)
      if !empty(getbufvar(bn, s:ww))
        let bz[bn] = (has_key(bz, bn) ? bz[bn] : []) + [wn]
      endif
    endfor
    for bn in keys(bz)
      let wn = (index(bz[bn], cw) != -1) ? cw : bz[bn][-1]
      call win_execute(wn, 'call s:SetWrapwidth(1,
                              \exists("ul") ? ul : range(1, line("$", wn)))')
    endfor
  endif
endfunction

function! s:CountSynHidden(ln, sc, ec) abort
  let nh = 0
  for co in range(a:sc, a:ec)
    let sc = synconcealed(a:ln, co)
    if sc[0] == 1 && empty(sc[1]) | let nh += 1 | endif
  endfor
  return nh
endfunction

if has('nvim')
  let s:ns = nvim_create_namespace(s:ww)
  let s:cb = 'wrapwidth_cb'

  function! s:CountTSHidden(ln, sc, ec) abort
    let nh = 0
    for co in range(a:sc, a:ec)
      for ct in v:lua.vim.treesitter.get_captures_at_pos(0, a:ln - 1, co - 1)
        if type(ct.metadata) == type({}) &&
                \has_key(ct.metadata, 'conceal') && empty(ct.metadata.conceal)
          let nh += 1
        endif
      endfor
    endfor
    return nh
  endfunction

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
                            \ return vim.fn['wrapwidth#ListenBufchange']
                            \ (bn, sl + 1, el + 1, ul - el, {}) end})
      endif
    elseif !a:on && bw.lc != 0
      let bw.lc = 0
    endif
  endfunction

  function! wrapwidth#ListenBufchange(bn, sl, el, na, ch) abort
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
    let bw = getbufvar(a:bn, s:ww)
    if a:on | let bw.hl = 'NonText' | else | unlet bw.hl | endif
  endfunction

  function! s:ChangeProptype(bn) abort
    let hl = getbufvar(a:bn, s:wh, get(g:, s:wh, ''))
    if hlID(hl) != 0
      let bw = getbufvar(a:bn, s:ww) | let bw.hl = hl
    endif
  endfunction

  function! s:Propadd(bn, ln, co, tx) abort
    let bw = getbufvar(a:bn, s:ww)
    call nvim_buf_set_extmark(a:bn, s:ns, a:ln - 1, a:co - 1,
                      \#{virt_text: [[a:tx, bw.hl]], virt_text_pos: 'inline',
                                                        \invalidate: v:true})
  endfunction

  function! s:Propremove(bn, ln) abort
    for id in s:Proplist(a:bn, a:ln)
      call nvim_buf_del_extmark(a:bn, s:ns, id[0])
    endfor
  endfunction

  function! s:Proplist(bn, ln) abort
    return nvim_buf_get_extmarks(a:bn, s:ns, [a:ln - 1, 0], [a:ln - 1, -1], {})
  endfunction

  function! s:CleanProp(bn) abort
    for id in filter(nvim_buf_get_extmarks(a:bn, s:ns, 0, -1,
                                                        \#{details: v:true}),
                \'has_key(v:val[3], "invalid") && v:val[3].invalid == v:true')
      call nvim_buf_del_extmark(a:bn, s:ns, id[0])
    endfor
  endfunction

  function! s:FindProp(bn, sl, el) abort
    let vt = #{0: [], 1: []}
    for [id, ln, co, dt] in nvim_buf_get_extmarks(a:bn, -1,
                          \[a:sl - 1, 0], [a:el - 1, -1], #{details: v:true})
      let ww = (dt.ns_id == s:ns)
      let vt[ww] += [[ln + 1, co + 1, ww ? strwidth(dt.virt_text[0][0]) : 0]]
    endfor
    return vt
  endfunction
else
  function! s:SetListener(bn, on) abort
    let bw = getbufvar(a:bn, s:ww)
    if a:on && bw.lc == 0
      let bw.lc = listener_add('s:ListenBufchange', a:bn)
    elseif !a:on && bw.lc != 0
      call listener_remove(bw.lc)
      let bw.lc = 0
    endif
  endfunction

  function! s:ListenBufchange(bn, sl, el, na, ch) abort
    let bw = getbufvar(a:bn, s:ww)
    if !empty(bw)
      let bw.ch += map(copy(a:ch), '[v:val.lnum, v:val.end, v:val.added]')
    endif
  endfunction

  function! s:SetProptype(bn, on) abort
    let pt = prop_type_get(s:ww, #{bufnr: a:bn})
    if a:on && empty(pt)
      call prop_type_add(s:ww, #{bufnr: a:bn, highlight: 'NonText'})
    elseif !a:on && !empty(pt)
      call prop_type_delete(s:ww, #{bufnr: a:bn})
    endif
  endfunction

  function! s:ChangeProptype(bn) abort
    let hl = getbufvar(a:bn, s:wh, get(g:, s:wh, ''))
    if hlID(hl) != 0
      call prop_type_change(s:ww, #{bufnr: a:bn, highlight: hl})
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
    return (getbufinfo(a:bn)[0].linecount < a:ln) ? [] :
                              \prop_list(a:ln, #{bufnr: a:bn, types: [s:ww]})
  endfunction

  function! s:CleanProp(bn) abort
    for pr in filter(prop_list(1, #{bufnr: a:bn, end_lnum: -1}),
                                                  \'!has_key(v:val, "type")')
      call prop_clear(pr.lnum, pr.lnum, #{bufnr: a:bn})
    endfor
  endfunction

  function! s:FindProp(bn, sl, el) abort
    let vt = #{0: [], 1: []}
    for pr in prop_list(a:sl, #{bufnr: a:bn, end_lnum: a:el})
      let ww = (pr.type == s:ww)
      let vt[ww] += [[pr.lnum, pr.col, ww ? strwidth(pr.text) : 0]]
    endfor
    return vt
  endfunction
endif

let &cpoptions = s:save_cpo
unlet s:save_cpo

" vim: ts=2 sw=0 sts=-1 et
