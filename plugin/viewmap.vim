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
let s:viewmap_bufnr     = -1
let s:viewmap_winid     = -1
let s:viewmap_timer     = -1
let g:viewmap_hlname    = 'ViewmapHighlight'
let s:viewmap_chars     = {'0000':' ', '1000':'⠁', '0100':'⠂', '0010':'⠄', '0001':'⡀', '1100':'⠃', '0110':'⠆', '0011':'⡄',
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
        let s:viewmap_bufnr = bufnr('%')
        let s:viewmap_winid = win_getid()

        call win_execute(s:viewmap_winid, 'setlocal buftype=nofile bufhidden=wipe nobuflisted noswapfile')
        call win_execute(s:viewmap_winid, 'setlocal nowrap nonumber norelativenumber winfixwidth')
        call win_execute(s:viewmap_winid, 'setlocal nocursorline nocursorcolumn nolist nofoldenable')
        call win_execute(s:viewmap_winid, 'setlocal foldcolumn=0 colorcolumn=')
        call win_execute(s:viewmap_winid, 'file vim-viewmap')

        wincmd p

        augroup ViewmapCmdOpen
            autocmd!
            autocmd BufReadPost,BufWritePost,FileChangedShellPost * call viewmap#SafeUpdateCon(1)
            autocmd BufEnter * call viewmap#SafeUpdateCon(0)
            autocmd BufDelete * call viewmap#DeleteCon(expand('<abuf>'))
            autocmd WinScrolled * call viewmap#SafeUpdatePos()
            autocmd WinClosed * if win_getid() == s:viewmap_winid | let s:viewmap_winid = -1 | endif
        augroup END

        call viewmap#SafeUpdateCon(0)
    endfunction

    " --------------------------------------------------
    " viewmap#Close
    " --------------------------------------------------
    function! viewmap#Close() abort
        if !viewmap#IsVisible() | return | endif

        if s:viewmap_timer != -1
            call timer_stop(s:viewmap_timer)
            let s:viewmap_timer = -1
        endif

        augroup ViewmapCmdClose
            autocmd!
        augroup END
        augroup! ViewmapCmdClose

        if win_id2win(s:viewmap_winid) > 0
            call win_execute(s:viewmap_winid, 'quit')
        endif

        let s:viewmap_bufnr = -1
        let s:viewmap_winid = -1
    endfunction

    " --------------------------------------------------
    " viewmap#ColorMixwhite
    " --------------------------------------------------
    function! viewmap#ColorMixwhite(color, alpha) abort
        let res_color = a:color
        if a:color =~? '^#[0-9a-fA-F]\{6}$' && a:alpha >= 0.0 && a:alpha <= 1.0
            let r = str2nr(a:color[1:2], 16)
            let g = str2nr(a:color[3:4], 16)
            let b = str2nr(a:color[5:6], 16)

            let mixed_r = float2nr(r * (1.0 - a:alpha) + 255 * a:alpha)
            let mixed_g = float2nr(g * (1.0 - a:alpha) + 255 * a:alpha)
            let mixed_b = float2nr(b * (1.0 - a:alpha) + 255 * a:alpha)

            let mixed_r = max([0, min([255, mixed_r])])
            let mixed_g = max([0, min([255, mixed_g])])
            let mixed_b = max([0, min([255, mixed_b])])

            let res_color = printf('#%02X%02X%02X', mixed_r, mixed_g, mixed_b)
        endif
        return res_color
    endfunction

    " --------------------------------------------------
    " viewmap#GetHlcolor
    " --------------------------------------------------
    function! viewmap#GetHlcolor(sort, type) abort
        let ret_color = ''
        let gui_color = synIDattr(synIDtrans(hlID('Normal')), a:sort, a:type)
        if !empty(gui_color) && gui_color != -1
            let ret_color = gui_color
        endif
        return ret_color
    endfunction

    " --------------------------------------------------
    " viewmap#SetHlcolor
    " --------------------------------------------------
    function! viewmap#SetHlcolor() abort
        let hl_vmfg = ''
        let hl_vmbg = ''
        let hl_guifg = viewmap#GetHlcolor('fg', 'gui')
        let hl_guibg = viewmap#GetHlcolor('bg', 'gui')
        if !empty(hl_guifg)
            let hl_vmfg = hl_guifg
        endif
        if !empty(hl_guibg)
            let hl_vmbg = viewmap#ColorMixwhite(hl_guibg, g:viewmap_hlalpha)
        endif
        if hl_vmfg =~? '^#[0-9a-fA-F]\{6}$' && hl_vmbg =~? '^#[0-9a-fA-F]\{6}$'
            execute 'highlight default '.g:viewmap_hlname.' guifg='.hl_vmfg.' guibg='.hl_vmbg
        else
            execute 'highlight default link '.g:viewmap_hlname.' Visual'
        endif
    endfunction

    " --------------------------------------------------
    " viewmap#IsVisible
    " --------------------------------------------------
    function! viewmap#IsVisible() abort
        return s:viewmap_winid != -1 && win_id2win(s:viewmap_winid) > 0
    endfunction

    " --------------------------------------------------
    " viewmap#IsInwindow
    " --------------------------------------------------
    function! viewmap#IsInwindow() abort
        return win_getid() == s:viewmap_winid
    endfunction

    " --------------------------------------------------
    " viewmap#UpdateCon
    " --------------------------------------------------
    function! viewmap#UpdateCon(type = 0) abort
        if !viewmap#IsVisible() || &diff || viewmap#IsInwindow() | return | endif

        let save_lazyredraw = &lazyredraw
        set lazyredraw

        let win_bufnr = winbufnr(win_getid())
        let win_width = winwidth(win_getid())

        let win_topline = line('w0')
        let win_botline = line('w$')
        let win_allline = line('$')

        let thumb_scale = 4
        let thumb_width = max([1, g:viewmap_width - 0])
        let thumb_lines = (win_allline + 3) / 4

        if !has_key(g:viewmap_data, win_bufnr) || a:type == 1
            let g:viewmap_data[win_bufnr] = []
            for record in range(0, thumb_lines - 1)
                let tlist = []
                for offset in range(0, 3)
                    let lnum = record * 4 + offset + 1
                    call add(tlist, lnum <= win_allline ? getbufline(win_bufnr, lnum)[0] : '')
                endfor
                let tdata = ''
                for col in range(0, thumb_width - 1)
                    let char_list = [0, 0, 0, 0]
                    for i in range(0, 3)
                        let search_beg = match(tlist[i], '[^ \t]')
                        let search_end = strdisplaywidth(tlist[i])
                        let buffer_beg = search_beg == -1 ? len(tlist[i]) : search_beg
                        let buffer_end = search_end > 0 ? search_end - 1 : 0
                        let thumb_beg = buffer_beg/thumb_scale
                        let thumb_end = buffer_end/thumb_scale
                        if tlist[i] == ''
                            let char_list[i] = 0
                        elseif col >= thumb_beg && col <= thumb_end
                            let char_list[i] = 1
                        else
                            let char_list[i] = 0
                        endif
                    endfor
                    let tdata .= get(s:viewmap_chars, join(char_list, ''), ' ')
                endfor
                call add(g:viewmap_data[win_bufnr], tdata)
            endfor
        endif

        call win_execute(s:viewmap_winid, 'setlocal modifiable')
        call win_execute(s:viewmap_winid, 'silent %delete _')
        call win_execute(s:viewmap_winid, 'call setline(1, '.string(g:viewmap_data[win_bufnr]).')')
        call win_execute(s:viewmap_winid, 'setlocal nomodifiable')

        let &lazyredraw = save_lazyredraw
        call viewmap#SafeUpdatePos()
    endfunction

    " --------------------------------------------------
    " viewmap#DeleteCon
    " --------------------------------------------------
    function! viewmap#DeleteCon(bufnr) abort
        let bufnr = str2nr(a:bufnr)
        if has_key(g:viewmap_data, bufnr)
            unlet g:viewmap_data[bufnr]
        endif
    endfunction

    " --------------------------------------------------
    " viewmap#UpdatePos
    " --------------------------------------------------
    function! viewmap#UpdatePos() abort
        if !viewmap#IsVisible() || &diff || viewmap#IsInwindow() | return | endif

        let win_topline = line('w0')
        let win_botline = line('w$')
        let win_allline = line('$')

        let thumb_scale = 4
        let thumb_lines = line('$', s:viewmap_winid)

        if thumb_lines > 0
            let thumb_hitop = max([1, float2nr(floor(win_topline * 1.0 / thumb_scale))])
            let thumb_hibot = max([1, float2nr(ceil(win_botline * 1.0 / thumb_scale))])
            let thumb_hitop = min([thumb_lines, thumb_hitop])
            let thumb_hibot = min([thumb_lines, thumb_hibot])

            if thumb_hitop > thumb_hibot
                let [thumb_hitop, thumb_hibot] = [thumb_hibot, thumb_hitop]
            endif

            call win_execute(s:viewmap_winid, 'if exists("w:viewmap_hlmatch") | call matchdelete(w:viewmap_hlmatch) | endif')
            call win_execute(s:viewmap_winid, 'unlet! w:viewmap_hlmatch')

            if thumb_hitop <= thumb_hibot && thumb_hitop > 0 && thumb_hibot <= thumb_lines
                let highlight_range = range(thumb_hitop, thumb_hibot)
                if !empty(highlight_range)
                    call win_execute(s:viewmap_winid, 'let w:viewmap_hlmatch = matchaddpos("'.g:viewmap_hlname.'", '.string(highlight_range).', 10)')
                endif
            endif

            let thumb_winhgt = winheight(s:viewmap_winid)
            if thumb_winhgt > 0 && thumb_hitop > 0 && thumb_hibot > 0
                let thumb_hicent = (thumb_hitop + thumb_hibot) / 2
                let thumb_toppos = max([1, thumb_hicent - (thumb_winhgt / 2) + &scrolloff])
                let thumb_toppos = min([thumb_lines - thumb_winhgt + 1 + &scrolloff, thumb_toppos])
                if thumb_toppos > 0
                    call win_execute(s:viewmap_winid, 'call cursor('.thumb_toppos.', 1)')
                    call win_execute(s:viewmap_winid, 'normal! zt')
                endif
            endif
        endif
    endfunction

    " --------------------------------------------------
    " viewmap#SafeUpdateCon
    " --------------------------------------------------
    function! viewmap#SafeUpdateCon(type = 0) abort
        if !viewmap#IsVisible() || &diff || viewmap#IsInwindow() | return | endif
        if s:viewmap_timer != -1
            call timer_stop(s:viewmap_timer)
            let s:viewmap_timer = -1
        endif
        let s:viewmap_timer = timer_start(g:viewmap_updelay, {-> execute('call viewmap#UpdateCon('.a:type.')', '')})
    endfunction

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
    " ViewmapCmdDiffmode
    " --------------------------------------------------
    augroup ViewmapCmdDiffmode
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

