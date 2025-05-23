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

" ============================================================================
" setting list
" ============================================================================
if !exists('g:viewmap_enabled')
    let g:viewmap_enabled = 1
endif
if !exists('g:viewmap_width')
    let g:viewmap_width = 20
endif
if !exists('g:viewmap_updelay')
    let g:viewmap_updelay = 200
endif
if !exists('g:viewmap_highlight')
    let g:viewmap_highlight = 'ViewmapHighlight'
    highlight default link ViewmapHighlight Visual
endif

if !exists('g:viewmap_state')
    let g:viewmap_state = 0
endif
if !exists('g:viewmap_data')
    let g:viewmap_data = {}
endif

let s:viewmap_bufnr = -1
let s:viewmap_winid = -1
let s:viewmap_timer = -1
let s:viewmap_chars = {'0000':' ', '1000':'⠁', '0100':'⠂', '0010':'⠄', '0001':'⡀', '1100':'⠃', '0110':'⠆', '0011':'⡄',
                     \ '1010':'⠅', '1001':'⡁', '0101':'⡂', '1110':'⠇', '1101':'⡃', '1011':'⡅', '0111':'⡆', '1111':'⡇'}

" ============================================================================
" function detail
" ============================================================================
if exists('g:viewmap_enabled') && g:viewmap_enabled == 1

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

        augroup ViewmapAutocmd
            autocmd!
            autocmd BufReadPost,BufWritePost,FileChangedShellPost * call viewmap#SafeUpdateCon(1)
            autocmd BufEnter * call viewmap#SafeUpdateCon(0)
            autocmd BufDelete * call viewmap#DeleteCon(expand('<abuf>'))
            autocmd WinScrolled * call viewmap#SafeUpdatePos()
            autocmd WinClosed * if win_getid() == s:viewmap_winid | let s:viewmap_winid = -1 | endif
        augroup END

        call viewmap#SafeUpdateCon(0)
    endfunction

    function! viewmap#Close() abort
        if !viewmap#IsVisible() | return | endif

        if s:viewmap_timer != -1
            call timer_stop(s:viewmap_timer)
            let s:viewmap_timer = -1
        endif

        augroup ViewmapAutocmd
            autocmd!
        augroup END
        augroup! ViewmapAutocmd

        if win_id2win(s:viewmap_winid) > 0
            call win_execute(s:viewmap_winid, 'quit')
        endif

        let s:viewmap_bufnr = -1
        let s:viewmap_winid = -1
    endfunction

    function! viewmap#IsVisible() abort
        return s:viewmap_winid != -1 && win_id2win(s:viewmap_winid) > 0
    endfunction

    function! viewmap#IsInwindow() abort
        return win_getid() == s:viewmap_winid
    endfunction

    function! viewmap#UpdateCon(type = 0) abort
        if !viewmap#IsVisible() || &diff || viewmap#IsInwindow() | return | endif

        let l:save_lazyredraw = &lazyredraw
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
                        let buffer_beg = match(tlist[i], '[^ \t]') == -1 ? len(tlist[i]) : match(tlist[i], '[^ \t]')
                        let buffer_end = strdisplaywidth(tlist[i]) > 0 ? strdisplaywidth(tlist[i]) - 1 : 0
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

        let &lazyredraw = l:save_lazyredraw
        call viewmap#SafeUpdatePos()
    endfunction

    function! viewmap#DeleteCon(bufnr) abort
        let l:bufnr = str2nr(a:bufnr)
        if has_key(g:viewmap_data, l:bufnr)
            unlet g:viewmap_data[l:bufnr]
        endif
    endfunction

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

            call win_execute(s:viewmap_winid, 'if exists("w:viewmap_highlight") | call matchdelete(w:viewmap_highlight) | endif')
            call win_execute(s:viewmap_winid, 'unlet! w:viewmap_highlight')

            if thumb_hitop <= thumb_hibot && thumb_hitop > 0 && thumb_hibot <= thumb_lines
                let highlight_range = range(thumb_hitop, thumb_hibot)
                if !empty(highlight_range)
                    call win_execute(s:viewmap_winid, 'let w:viewmap_highlight = matchaddpos("'.g:viewmap_highlight.'", '.string(highlight_range).', 10)')
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

    " ============================================================================
    " diff mode
    " ============================================================================
    augroup ViewmapDiffmode
        autocmd!
        autocmd OptionSet diff
                    \ if v:option_new && viewmap#IsVisible() |
                    \     call timer_start(0, {-> execute('call viewmap#Close()', '')}) |
                    \ elseif !v:option_new && !viewmap#IsVisible() && g:viewmap_state == 1 |
                    \     call timer_start(0, {-> execute('call viewmap#Open()', '')}) |
                    \ endif
    augroup END

    " ============================================================================
    " interface list
    " ============================================================================
    function! viewmap#OpenState() abort
        call viewmap#Open()
        let g:viewmap_state = 1
    endfunction

    function! viewmap#CloseState() abort
        call viewmap#Close()
        let g:viewmap_state = 0
    endfunction

    function! viewmap#ToggleState() abort
        if viewmap#IsVisible()
            call viewmap#CloseState()
        else
            call viewmap#OpenState()
        endif
    endfunction

    command! -bar ViewmapOpen call viewmap#OpenState()
    command! -bar ViewmapClose call viewmap#CloseState()
    command! -bar ViewmapToggle call viewmap#ToggleState()

endif
