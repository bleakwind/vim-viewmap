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
let g:viewmap_enabled   = get(g:, 'viewmap_enabled',    0)
let g:viewmap_width     = get(g:, 'viewmap_width',      20)
let g:viewmap_updelay   = get(g:, 'viewmap_updelay',    200)
let g:viewmap_hlalpha   = get(g:, 'viewmap_hlalpha',    0.3)

let g:viewmap_state     = 0
let g:viewmap_data      = {}
let g:viewmap_bufnr     = -1
let g:viewmap_winid     = -1
let g:viewmap_timer     = -1
let g:viewmap_hlname    = 'ViewmapHighlight'
let g:viewmap_chars     = {'0000':' ', '1000':'⠁', '0100':'⠂', '0010':'⠄', '0001':'⡀', '1100':'⠃', '0110':'⠆', '0011':'⡄',
                         \ '1010':'⠅', '1001':'⡁', '0101':'⡂', '1110':'⠇', '1101':'⡃', '1011':'⡅', '0111':'⡆', '1111':'⡇'}

" ============================================================================
" viewmap detail
" g:viewmap_enabled = 1
" ============================================================================
if exists('g:viewmap_enabled') && g:viewmap_enabled == 1

    " --------------------------------------------------
    " viewmap#Open
    " --------------------------------------------------
    function! viewmap#Open() abort
        if viewmap#IsVisible() || &diff | return | endif

        execute 'vertical rightbelow '.g:viewmap_width.' new'
        let g:viewmap_bufnr = bufnr('%')
        let g:viewmap_winid = win_getid()

        call win_execute(g:viewmap_winid, 'setlocal buftype=nofile bufhidden=wipe nobuflisted noswapfile')
        call win_execute(g:viewmap_winid, 'setlocal nowrap nonumber norelativenumber winfixwidth')
        call win_execute(g:viewmap_winid, 'setlocal nocursorline nocursorline nocursorcolumn nolist nofoldenable')
        call win_execute(g:viewmap_winid, 'setlocal foldcolumn=0 colorcolumn=')
        call win_execute(g:viewmap_winid, 'file vim-viewmap')

        wincmd p

        augroup viewmap_cmd_bas
            autocmd!
            autocmd BufReadPost,BufWritePost,FileChangedShellPost * call viewmap#SafeUpdateCon(1)
            autocmd BufEnter * call viewmap#SafeUpdateCon(0)
            autocmd BufDelete * call viewmap#DeleteCon(expand('<abuf>'))
            autocmd WinScrolled * call viewmap#SafeUpdatePos()
            autocmd WinClosed * if win_getid() == g:viewmap_winid | let g:viewmap_winid = -1 | endif
        augroup END

        call viewmap#SafeUpdateCon(0)
    endfunction

    " --------------------------------------------------
    " viewmap#Close
    " --------------------------------------------------
    function! viewmap#Close() abort
        if !viewmap#IsVisible() | return | endif

        if g:viewmap_timer != -1
            call timer_stop(g:viewmap_timer)
            let g:viewmap_timer = -1
        endif

        augroup viewmap_cmd_bas
            autocmd!
        augroup END

        if win_id2win(g:viewmap_winid) > 0
            call win_execute(g:viewmap_winid, 'quit')
        endif

        let g:viewmap_bufnr = -1
        let g:viewmap_winid = -1
    endfunction

    " --------------------------------------------------
    " viewmap#MixWhite
    " --------------------------------------------------
    function! viewmap#MixWhite(color, alpha) abort
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
            let l:hl_vmbg = viewmap#MixWhite(l:hl_guibg, g:viewmap_hlalpha)
        endif
        if l:hl_vmfg =~? '^#[0-9a-fA-F]\{6}$' && l:hl_vmbg =~? '^#[0-9a-fA-F]\{6}$'
            execute 'hi default '.g:viewmap_hlname.' guifg='.l:hl_vmfg.' guibg='.l:hl_vmbg
        else
            execute 'hi default link '.g:viewmap_hlname.' Visual'
        endif
    endfunction

    " --------------------------------------------------
    " viewmap#IsVisible
    " --------------------------------------------------
    function! viewmap#IsVisible() abort
        return g:viewmap_winid != -1 && win_id2win(g:viewmap_winid) > 0
    endfunction

    " --------------------------------------------------
    " viewmap#IsInwindow
    " --------------------------------------------------
    function! viewmap#IsInwindow() abort
        return win_getid() == g:viewmap_winid
    endfunction

    " --------------------------------------------------
    " viewmap#UpdateCon
    " --------------------------------------------------
    function! viewmap#UpdateCon(type = 0) abort
        if !viewmap#IsVisible() || &diff || viewmap#IsInwindow() | return | endif

        let l:save_lazyredraw = &lazyredraw
        set lazyredraw

        let l:win_bufnr = winbufnr(win_getid())
        let l:win_width = winwidth(win_getid())

        let l:win_topline = line('w0')
        let l:win_botline = line('w$')
        let l:win_allline = line('$')

        let l:thumb_scale = 4
        let l:thumb_width = max([1, g:viewmap_width - 0])
        let l:thumb_lines = (l:win_allline + 3) / 4

        if !has_key(g:viewmap_data, l:win_bufnr) || a:type == 1
            let g:viewmap_data[l:win_bufnr] = []
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
                        let l:buffer_beg = l:search_beg == -1 ? len(l:tlist[ic]) : l:search_beg
                        let l:buffer_end = l:search_end > 0 ? l:search_end - 1 : 0
                        let l:thumb_beg = l:buffer_beg / l:thumb_scale
                        let l:thumb_end = l:buffer_end / l:thumb_scale
                        if l:tlist[ic] == ''
                            let l:clist[ic] = 0
                        elseif iw >= l:thumb_beg && iw <= l:thumb_end
                            let l:clist[ic] = 1
                        else
                            let l:clist[ic] = 0
                        endif
                    endfor
                    let l:tdata .= get(g:viewmap_chars, join(l:clist, ''), ' ')
                endfor
                call add(g:viewmap_data[l:win_bufnr], l:tdata)
            endfor
        endif

        call win_execute(g:viewmap_winid, 'setlocal modifiable')
        call win_execute(g:viewmap_winid, 'silent %delete _')
        call win_execute(g:viewmap_winid, 'call setline(1, '.string(g:viewmap_data[l:win_bufnr]).')')
        call win_execute(g:viewmap_winid, 'setlocal nomodifiable')

        let &lazyredraw = l:save_lazyredraw
        call viewmap#SafeUpdatePos()
    endfunction

    " --------------------------------------------------
    " viewmap#DeleteCon
    " --------------------------------------------------
    function! viewmap#DeleteCon(buf) abort
        let l:bufnbr = str2nr(a:buf)
        if has_key(g:viewmap_data, l:bufnbr)
            unlet g:viewmap_data[l:bufnbr]
        endif
    endfunction

    " --------------------------------------------------
    " viewmap#UpdatePos
    " --------------------------------------------------
    function! viewmap#UpdatePos() abort
        if !viewmap#IsVisible() || &diff || viewmap#IsInwindow() | return | endif

        let l:win_topline = line('w0')
        let l:win_botline = line('w$')
        let l:win_allline = line('$')

        let l:thumb_scale = 4
        let l:thumb_lines = line('$', g:viewmap_winid)

        if l:thumb_lines > 0
            let l:thumb_hitop = max([1, float2nr(floor(l:win_topline * 1.0 / l:thumb_scale))])
            let l:thumb_hibot = max([1, float2nr(ceil(l:win_botline * 1.0 / l:thumb_scale))])
            let l:thumb_hitop = min([l:thumb_lines, l:thumb_hitop])
            let l:thumb_hibot = min([l:thumb_lines, l:thumb_hibot])

            if l:thumb_hitop > l:thumb_hibot
                let [l:thumb_hitop, l:thumb_hibot] = [l:thumb_hibot, l:thumb_hitop]
            endif

            call win_execute(g:viewmap_winid, "if exists('w:viewmap_hlmatch') | call matchdelete(w:viewmap_hlmatch) | endif")
            call win_execute(g:viewmap_winid, 'unlet! w:viewmap_hlmatch')

            if l:thumb_hitop <= l:thumb_hibot && l:thumb_hitop > 0 && l:thumb_hibot <= l:thumb_lines
                let l:hl_range = range(l:thumb_hitop, l:thumb_hibot)
                if !empty(l:hl_range)
                    call win_execute(g:viewmap_winid, 'let w:viewmap_hlmatch = matchaddpos("'.g:viewmap_hlname.'", '.string(l:hl_range).', 10)')
                endif
            endif

            let l:thumb_winhgt = winheight(g:viewmap_winid)
            if l:thumb_winhgt > 0 && l:thumb_hitop > 0 && l:thumb_hibot > 0
                let l:thumb_hicent = (l:thumb_hitop + l:thumb_hibot) / 2
                let l:thumb_toppos = max([1, l:thumb_hicent - (l:thumb_winhgt / 2) + &scrolloff])
                let l:thumb_toppos = min([l:thumb_lines - l:thumb_winhgt + 1 + &scrolloff, l:thumb_toppos])
                if l:thumb_toppos > 0
                    call win_execute(g:viewmap_winid, 'call cursor('.l:thumb_toppos.', 1)')
                    call win_execute(g:viewmap_winid, 'normal! zt')
                endif
            endif
        endif
    endfunction

    " --------------------------------------------------
    " viewmap#SafeUpdateCon
    " --------------------------------------------------
    function! viewmap#SafeUpdateCon(type = 0) abort
        if !viewmap#IsVisible() || &diff || viewmap#IsInwindow() | return | endif
        if g:viewmap_timer != -1
            call timer_stop(g:viewmap_timer)
            let g:viewmap_timer = -1
        endif
        let g:viewmap_timer = timer_start(g:viewmap_updelay, {-> execute('call viewmap#UpdateCon('.a:type.')', '')})
    endfunction

    " --------------------------------------------------
    " viewmap#SafeUpdatePos
    " --------------------------------------------------
    function! viewmap#SafeUpdatePos() abort
        if !viewmap#IsVisible() || &diff || viewmap#IsInwindow() | return | endif
        call timer_start(0, {-> execute('call viewmap#UpdatePos()', '')})
    endfunction

    " --------------------------------------------------
    " viewmap#OpenState
    " --------------------------------------------------
    function! viewmap#OpenState() abort
        call viewmap#SetHlcolor()
        call viewmap#Open()
        let g:viewmap_state = 1
    endfunction

    " --------------------------------------------------
    " viewmap#CloseState
    " --------------------------------------------------
    function! viewmap#CloseState() abort
        call viewmap#Close()
        let g:viewmap_state = 0
    endfunction

    " --------------------------------------------------
    " viewmap#ToggleState
    " --------------------------------------------------
    function! viewmap#ToggleState() abort
        if viewmap#IsVisible()
            call viewmap#CloseState()
        else
            call viewmap#SetHlcolor()
            call viewmap#OpenState()
        endif
    endfunction

    " --------------------------------------------------
    " viewmap_cmd_diff
    " --------------------------------------------------
    augroup viewmap_cmd_diff
        autocmd!
        autocmd OptionSet diff
                    \ if v:option_new && viewmap#IsVisible() |
                    \     call timer_start(0, {-> execute('call viewmap#Close()', '')}) |
                    \ elseif !v:option_new && !viewmap#IsVisible() && g:viewmap_state == 1 |
                    \     call timer_start(0, {-> execute('call viewmap#Open()', '')}) |
                    \ endif
    augroup END

    " --------------------------------------------------
    " command
    " --------------------------------------------------
    command! -bar ViewmapOpen call viewmap#OpenState()
    command! -bar ViewmapClose call viewmap#CloseState()
    command! -bar ViewmapToggle call viewmap#ToggleState()

endif

" ============================================================================
" Other
" ============================================================================
let &cpoptions = s:save_cpo
unlet s:save_cpo
