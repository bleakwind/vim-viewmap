" vim: set expandtab tabstop=4 softtabstop=4 shiftwidth=4: */
"
" +--------------------------------------------------------------------------+
" | $Id: viewmap.vim 2025-05-23 02:30:17 Bleakwind Exp $                     |
" +--------------------------------------------------------------------------+
" | Copyright (c) 2008-2025 Bleakwind(Rick Wu).                              |
" +--------------------------------------------------------------------------+
" | This source file is viewmap.vim.                                         |
" | This source file is release under BSD license.                           |
" +--------------------------------------------------------------------------+
" | Author: Bleakwind(Rick Wu) <bleakwind@qq.com>                            |
" +--------------------------------------------------------------------------+
"

if exists('g:viewmap_plugin') || &compatible
    finish
endif
let g:viewmap_plugin = 1

scriptencoding utf-8

let s:save_cpo = &cpoptions
set cpoptions&vim

" ============================================================================
" viewmap setting
" ============================================================================
" public setting - [g:viewmap_position:left|right]
let g:viewmap_enabled       = get(g:, 'viewmap_enabled',        0)
let g:viewmap_autostart     = get(g:, 'viewmap_autostart',      0)
let g:viewmap_position      = get(g:, 'viewmap_position',       'right')
let g:viewmap_winwidth      = get(g:, 'viewmap_winwidth',       20)
let g:viewmap_updelay       = get(g:, 'viewmap_updelay',        200)
let g:viewmap_hlalpha       = get(g:, 'viewmap_hlalpha',        0.3)

" plugin variable
let s:viewmap_bufnbr        = -1
let s:viewmap_winidn        = -1
let s:viewmap_state         = 0
let s:viewmap_data          = {}
let s:viewmap_timer         = -1
let s:viewmap_hlname        = 'ViewmapHighlight'
let s:viewmap_chars         = {'0000':' ', '1000':'⠁', '0100':'⠂', '0010':'⠄', '0001':'⡀', '1100':'⠃', '0110':'⠆', '0011':'⡄',
                             \ '1010':'⠅', '1001':'⡁', '0101':'⡂', '1110':'⠇', '1101':'⡃', '1011':'⡅', '0111':'⡆', '1111':'⡇'}

" ============================================================================
" viewmap detail
" g:viewmap_enabled = 1
" ============================================================================
if exists('g:viewmap_enabled') && g:viewmap_enabled ==# 1

    " --------------------------------------------------
    " viewmap#IsVisible
    " --------------------------------------------------
    function! viewmap#IsVisible() abort
        return s:viewmap_winidn != -1 && win_id2win(s:viewmap_winidn) > 0
    endfunction

    " --------------------------------------------------
    " viewmap#IsInwindow
    " --------------------------------------------------
    function! viewmap#IsInwindow() abort
        return win_getid() ==# s:viewmap_winidn
    endfunction

    " --------------------------------------------------
    " viewmap#OpenWin
    " --------------------------------------------------
    function! viewmap#OpenWin() abort
        if !viewmap#IsVisible() && !&diff
            " get message
            let l:orig_winidn = win_getid()

            " open win
            if g:viewmap_position ==# 'left'
                execute 'silent! topleft vnew vim-viewmap | vertical resize '.g:viewmap_winwidth
            else
                execute 'silent! botright vnew vim-viewmap | vertical resize '.g:viewmap_winwidth
            endif

            let s:viewmap_bufnbr = bufnr('%')
            let s:viewmap_winidn = win_getid()

            " set option
            call win_execute(s:viewmap_winidn, 'setlocal buftype=nofile bufhidden=hide noswapfile nobuflisted nomodifiable')
            call win_execute(s:viewmap_winidn, 'setlocal nonumber norelativenumber nolist nocursorline nocursorcolumn nospell')
            call win_execute(s:viewmap_winidn, 'setlocal nowrap nofoldenable foldcolumn=0 signcolumn=no colorcolumn=')
            call win_execute(s:viewmap_winidn, 'setlocal filetype=viewmap')
            call win_execute(s:viewmap_winidn, 'file vim-viewmap')

            " set win
            if g:viewmap_position ==# 'left'
                call win_execute(s:viewmap_winidn, 'setlocal winfixwidth')
            else
                call win_execute(s:viewmap_winidn, 'setlocal winfixwidth')
            endif

            " back win
            if l:orig_winidn != 0 && win_id2win(l:orig_winidn) != 0
                call win_gotoid(l:orig_winidn)
            endif

            " set autocmd
            augroup viewmap_cmd_bas
                autocmd!
                autocmd BufReadPost,BufWritePost,FileChangedShellPost * call viewmap#SafeUpdateCon(1)
                autocmd BufEnter * call viewmap#SafeUpdateCon(0)
                autocmd BufDelete * call viewmap#DeleteCon(expand('<abuf>'))
                autocmd WinScrolled * call viewmap#SafeUpdatePos()
                autocmd WinClosed * if win_getid() ==# s:viewmap_winidn | let s:viewmap_winidn = -1 | endif
            augroup END
        endif
        call viewmap#SafeUpdateCon(0)
    endfunction

    " --------------------------------------------------
    " viewmap#CloseWin
    " --------------------------------------------------
    function! viewmap#CloseWin() abort
        if viewmap#IsVisible()

            if s:viewmap_timer != -1
                call timer_stop(s:viewmap_timer)
                let s:viewmap_timer = -1
            endif

            augroup viewmap_cmd_bas
                autocmd!
            augroup END

            if win_id2win(s:viewmap_winidn) > 0
                call win_execute(s:viewmap_winidn, 'quit')
            endif

            let s:viewmap_bufnbr = -1
            let s:viewmap_winidn = -1
        endif
    endfunction

    " --------------------------------------------------
    " viewmap#UpdateWidth
    " --------------------------------------------------
    function! viewmap#UpdateWidth() abort
        if viewmap#IsVisible()
            " get win
            let l:orig_winidn = win_getid()
            " set win
            call win_gotoid(s:viewmap_winidn)
            execute 'vertical resize '.g:viewmap_winwidth
            " back win
            if l:orig_winidn != 0 && win_id2win(l:orig_winidn) != 0
                call win_gotoid(l:orig_winidn)
            endif
        endif
    endfunction

    " --------------------------------------------------
    " viewmap#UpdateCon
    " --------------------------------------------------
    function! viewmap#UpdateCon(type = 0) abort
        if viewmap#IsVisible() && !&diff && !viewmap#IsInwindow()

            let l:save_lazyredraw = &lazyredraw
            set lazyredraw

            let l:win_bufnr = winbufnr(win_getid())
            let l:win_width = winwidth(win_getid())

            let l:win_topline = line('w0')
            let l:win_botline = line('w$')
            let l:win_allline = line('$')

            let l:thumb_scale = 4
            let l:thumb_width = max([1, g:viewmap_winwidth - 0])
            let l:thumb_lines = (l:win_allline + 3) / 4

            if !has_key(s:viewmap_data, l:win_bufnr) || a:type ==# 1
                let s:viewmap_data[l:win_bufnr] = []
                for il in range(0, l:thumb_lines - 1)
                    let l:tlist = []
                    for ic in range(0, 3)
                        let l:lnum = il * 4 + ic + 1
                        call add(l:tlist, l:lnum <= l:win_allline ? getbufline(l:win_bufnr, l:lnum)[0] : '')
                    endfor
                    let l:tdata = ''
                    for iw in range(0, l:thumb_width - 1)
                        let l:clist = [0, 0, 0, 0]
                        for ic in range(0, 3)
                            let l:search_beg = match(l:tlist[ic], '[^ \t]')
                            let l:search_end = strdisplaywidth(l:tlist[ic])
                            let l:buffer_beg = l:search_beg ==# -1 ? len(l:tlist[ic]) : l:search_beg
                            let l:buffer_end = l:search_end > 0 ? l:search_end - 1 : 0
                            let l:thumb_beg = l:buffer_beg / l:thumb_scale
                            let l:thumb_end = l:buffer_end / l:thumb_scale
                            if l:tlist[ic] ==# ''
                                let l:clist[ic] = 0
                            elseif iw >= l:thumb_beg && iw <= l:thumb_end
                                let l:clist[ic] = 1
                            else
                                let l:clist[ic] = 0
                            endif
                        endfor
                        let l:tdata .= get(s:viewmap_chars, join(l:clist, ''), ' ')
                    endfor
                    call add(s:viewmap_data[l:win_bufnr], l:tdata)
                endfor
            endif

            call win_execute(s:viewmap_winidn, 'setlocal modifiable')
            call win_execute(s:viewmap_winidn, 'silent %delete _')
            call win_execute(s:viewmap_winidn, 'call setline(1, '.string(s:viewmap_data[l:win_bufnr]).')')
            call win_execute(s:viewmap_winidn, 'setlocal nomodifiable')

            let &lazyredraw = l:save_lazyredraw
            call viewmap#SafeUpdatePos()
        endif
    endfunction

    " --------------------------------------------------
    " viewmap#DeleteCon
    " --------------------------------------------------
    function! viewmap#DeleteCon(buf) abort
        let l:bufnbr = str2nr(a:buf)
        if has_key(s:viewmap_data, l:bufnbr)
            unlet s:viewmap_data[l:bufnbr]
        endif
    endfunction

    " --------------------------------------------------
    " viewmap#UpdatePos
    " --------------------------------------------------
    function! viewmap#UpdatePos() abort
        if viewmap#IsVisible() && !&diff && !viewmap#IsInwindow()

            let l:win_topline = line('w0')
            let l:win_botline = line('w$')
            let l:win_allline = line('$')

            let l:thumb_scale = 4
            let l:thumb_lines = line('$', s:viewmap_winidn)

            if l:thumb_lines > 0
                let l:thumb_hitop = max([1, float2nr(floor(l:win_topline * 1.0 / l:thumb_scale))])
                let l:thumb_hibot = max([1, float2nr(ceil(l:win_botline * 1.0 / l:thumb_scale))])
                let l:thumb_hitop = min([l:thumb_lines, l:thumb_hitop])
                let l:thumb_hibot = min([l:thumb_lines, l:thumb_hibot])

                if l:thumb_hitop > l:thumb_hibot
                    let [l:thumb_hitop, l:thumb_hibot] = [l:thumb_hibot, l:thumb_hitop]
                endif

                call win_execute(s:viewmap_winidn, "if exists('w:viewmap_hlmatch') | call matchdelete(w:viewmap_hlmatch) | endif")
                call win_execute(s:viewmap_winidn, 'unlet! w:viewmap_hlmatch')

                if l:thumb_hitop <= l:thumb_hibot && l:thumb_hitop > 0 && l:thumb_hibot <= l:thumb_lines
                    let l:hl_range = range(l:thumb_hitop, l:thumb_hibot)
                    if !empty(l:hl_range)
                        call win_execute(s:viewmap_winidn, 'let w:viewmap_hlmatch = matchaddpos("'.s:viewmap_hlname.'", '.string(l:hl_range).', 10)')
                    endif
                endif

                let l:thumb_winhgt = winheight(s:viewmap_winidn)
                if l:thumb_winhgt > 0 && l:thumb_hitop > 0 && l:thumb_hibot > 0
                    let l:thumb_hicent = (l:thumb_hitop + l:thumb_hibot) / 2
                    let l:thumb_toppos = max([1, l:thumb_hicent - (l:thumb_winhgt / 2) + &scrolloff])
                    let l:thumb_toppos = min([l:thumb_lines - l:thumb_winhgt + 1 + &scrolloff, l:thumb_toppos])
                    if l:thumb_toppos > 0
                        call win_execute(s:viewmap_winidn, 'keepjumps call setpos(".", [0, '.l:thumb_toppos.', 1, 0])')
                        call win_execute(s:viewmap_winidn, 'normal! zt')
                    endif
                endif
            endif
        endif
    endfunction

    " --------------------------------------------------
    " viewmap#SafeUpdateCon
    " --------------------------------------------------
    function! viewmap#SafeUpdateCon(type = 0) abort
        if viewmap#IsVisible() && !&diff && !viewmap#IsInwindow()
            if s:viewmap_timer != -1
                call timer_stop(s:viewmap_timer)
                let s:viewmap_timer = -1
            endif
            let s:viewmap_timer = timer_start(g:viewmap_updelay, {-> viewmap#UpdateCon(a:type)})
        endif
    endfunction

    " --------------------------------------------------
    " viewmap#SafeUpdatePos
    " --------------------------------------------------
    function! viewmap#SafeUpdatePos() abort
        if viewmap#IsVisible() && !&diff && !viewmap#IsInwindow()
            call timer_start(0, {-> viewmap#UpdatePos()})
        endif
    endfunction

    " --------------------------------------------------
    " viewmap#Open
    " --------------------------------------------------
    function! viewmap#Open() abort
        call viewmap#SetHlcolor()
        call viewmap#OpenWin()
        let s:viewmap_state = 1
    endfunction

    " --------------------------------------------------
    " viewmap#Close
    " --------------------------------------------------
    function! viewmap#Close() abort
        call viewmap#CloseWin()
        let s:viewmap_state = 0
    endfunction

    " --------------------------------------------------
    " viewmap#Toggle
    " --------------------------------------------------
    function! viewmap#Toggle() abort
        if viewmap#IsVisible()
            call viewmap#Close()
        else
            call viewmap#SetHlcolor()
            call viewmap#Open()
        endif
    endfunction

    " --------------------------------------------------
    " viewmap#ColorMask
    " --------------------------------------------------
    function! viewmap#ColorMask(color, alpha) abort
        let l:res_color = a:color
        if a:color =~? '^#[0-9a-fA-F]\{6}$' && a:alpha >= 0.0 && a:alpha <= 1.0
            let l:r = str2nr(a:color[1:2], 16)
            let l:g = str2nr(a:color[3:4], 16)
            let l:b = str2nr(a:color[5:6], 16)

            let l:mixed_r = float2nr(l:r * (1.0 - a:alpha) + 255 * a:alpha)
            let l:mixed_g = float2nr(l:g * (1.0 - a:alpha) + 255 * a:alpha)
            let l:mixed_b = float2nr(l:b * (1.0 - a:alpha) + 255 * a:alpha)

            let l:mixed_r = max([0, min([255, l:mixed_r])])
            let l:mixed_g = max([0, min([255, l:mixed_g])])
            let l:mixed_b = max([0, min([255, l:mixed_b])])

            let l:res_color = printf('#%02X%02X%02X', l:mixed_r, l:mixed_g, l:mixed_b)
        endif
        return l:res_color
    endfunction

    " --------------------------------------------------
    " viewmap#GetHlcolor
    " --------------------------------------------------
    function! viewmap#GetHlcolor(sort, type) abort
        let l:ret_color = ''
        let l:gui_color = synIDattr(synIDtrans(hlID('Normal')), a:sort, a:type)
        if !empty(l:gui_color) && l:gui_color != -1
            let l:ret_color = l:gui_color
        endif
        return l:ret_color
    endfunction

    " --------------------------------------------------
    " viewmap#SetHlcolor
    " --------------------------------------------------
    function! viewmap#SetHlcolor() abort
        let l:hl_vmfg = ''
        let l:hl_vmbg = ''
        let l:hl_guifg = viewmap#GetHlcolor('fg', 'gui')
        let l:hl_guibg = viewmap#GetHlcolor('bg', 'gui')
        if !empty(l:hl_guifg)
            let l:hl_vmfg = l:hl_guifg
        endif
        if !empty(l:hl_guibg)
            let l:hl_vmbg = viewmap#ColorMask(l:hl_guibg, g:viewmap_hlalpha)
        endif
        if l:hl_vmfg =~? '^#[0-9a-fA-F]\{6}$' && l:hl_vmbg =~? '^#[0-9a-fA-F]\{6}$'
            execute 'hi default '.s:viewmap_hlname.' guifg='.l:hl_vmfg.' guibg='.l:hl_vmbg
        else
            execute 'hi default link '.s:viewmap_hlname.' Visual'
        endif
    endfunction

    " --------------------------------------------------
    " viewmap_cmd_diff
    " --------------------------------------------------
    augroup viewmap_cmd_diff
        autocmd!
        autocmd WinEnter * call viewmap#UpdateWidth()
        if g:viewmap_autostart ==# 1
            autocmd VimEnter * call timer_start(0, {-> viewmap#Open()})
        endif
        autocmd OptionSet diff
                    \ if v:option_new && viewmap#IsVisible() |
                    \     call timer_start(0, {-> viewmap#CloseWin()}) |
                    \ elseif !v:option_new && !viewmap#IsVisible() && s:viewmap_state ==# 1 |
                    \     call timer_start(0, {-> viewmap#OpenWin()}) |
                    \ endif
    augroup END

    " --------------------------------------------------
    " command
    " --------------------------------------------------
    command! -bar ViewmapOpen call viewmap#Open()
    command! -bar ViewmapClose call viewmap#Close()
    command! -bar ViewmapToggle call viewmap#Toggle()

endif

" ============================================================================
" Other
" ============================================================================
let &cpoptions = s:save_cpo
unlet s:save_cpo
