" wrapwidth.vim : Wraps long lines visually at a specific column
"
" Last Change: 2023/11/15
" Version:     1.5
" Author:      Rick Howe (Takumi Ohtani) <rdcxy754@ybb.ne.jp>
" Copyright:   (c) 2023 by Rick Howe
" License:     MIT

let s:save_cpo = &cpoptions
set cpo&vim

let s:ww = 'wrapwidth'

function! wrapwidth#WrapWidth(ww) abort
  if type(a:ww) == type(0)
    let bv = getbufvar(bufnr('%'), '')
    let ww = has_key(bv, s:ww) ? bv[s:ww] : 0
    if a:ww != ww
      let zz = (a:ww != 0) * 2 + (ww != 0)      " 1:delete, 2:add, 3:change
      if zz == 1 | unlet bv[s:ww] | else | let bv[s:ww] = a:ww | endif
      call s:ShowWrapWidth(zz)
      call s:SetEvent()
    endif
  else
    echohl ErrorMsg | echo 'argument is not number' | echohl None
  endif
endfunction

function! s:ShowWrapWidth(zz) abort
  let cw = win_getid() | let cb = winbufnr(cw)
  if a:zz == 1 || a:zz == 3         " delete or change
    call s:Prop_remove(cb)
  endif
  call s:Prop_type(cb, a:zz)
  if a:zz == 2 || a:zz == 3         " add or change
    let ww = getbufvar(cb, s:ww, 0)
    if ww != 0
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
        for ln in range(1, line('$'))
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
            call s:Prop_add(cb, ln, bc, repeat(sp, sw + vd))
            let vc += tn
            let bs = bc
          endwhile
        endfor
      endif
    endif
  endif
endfunction

function! s:SetEvent() abort
  let bl = filter(range(1, bufnr('$')), 'getbufvar(v:val, s:ww, 0) != 0')
  let ac = ['augroup ' . s:ww, 'autocmd!']
  if !empty(bl)
    " shane: adding 'BufEnter' is to make it work when/if switched buf by 'c-^'
    for ev in ['OptionSet', 'WinScrolled', 'TextChanged,InsertLeave', 'BufEnter']
      let [ea, eb] = ['autocmd ' . ev, 'call s:CheckEvent(''' . ev[0] . ''')']
      if ev[0] == 'T' || ev[0] == 'B'
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
  elseif a:ev == 'T'      " TextChanged or InsertLeave
    let wl += [cw]
  elseif a:ev == 'B'      " BufEnter
    let wl += [cw]
  endif
  " select one win per buf (in case of splitted)
  let bw = {}
  for wn in wl
    let bn = winbufnr(wn)
    if !has_key(bw, bn) | let bw[bn] = [] | endif | let bw[bn] += [wn]
  endfor
  for wl in values(bw)
    call win_execute((index(wl, cw) != -1) ? cw : wl[-1],
                                                  \'call s:ShowWrapWidth(3)')
  endfor
endfunction

if has('nvim')
  let s:ns = nvim_create_namespace(s:ww)

  function! s:Prop_type(bn, zz) abort
    if a:zz != 1
      let s:hl = get(b:, s:ww . '_hl', get(g:, s:ww . '_hl', ''))
      if hlID(s:hl) == 0 | let s:hl = 'NonText' | endif
    endif
  endfunction

  function! s:Prop_add(bn, ln, co, tx) abort
    call nvim_buf_set_extmark(a:bn, s:ns, a:ln - 1, a:co - 1,
                      \#{virt_text: [[a:tx, s:hl]], virt_text_pos: 'inline'})
  endfunction

  function! s:Prop_remove(bn) abort
    for id in nvim_buf_get_extmarks(a:bn, s:ns, 0, -1, {})
      call nvim_buf_del_extmark(a:bn, s:ns, id[0])
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
    call prop_remove(#{type: s:ww, bufnr: a:bn, all: 1})
  endfunction
endif

let &cpoptions = s:save_cpo
unlet s:save_cpo

" vim: ts=2 sw=0 sts=-1 et
