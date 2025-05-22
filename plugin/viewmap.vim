" vim: set expandtab tabstop=4 softtabstop=4 shiftwidth=4: */
"
" +--------------------------------------------------------------------------+
" | $Id: viewmap.vim 2025-05-21 10:06:29 Bleakwind Exp $                     |
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

let s:viewmap_bufnr = -1
let s:viewmap_winid = -1
let s:last_topline = -1
let s:last_botline = -1
let s:update_timer = -1
let s:block_chars = {'0000':' ', '1000':'⠁', '0100':'⠂', '0010':'⠄', '0001':'⡀', '1100':'⠃', '0110':'⠆', '0011':'⡄',
                   \ '1010':'⠅', '1001':'⡁', '0101':'⡂', '1110':'⠇', '1101':'⡃', '1011':'⡅', '0111':'⡆', '1111':'⡇'}

" ============================================================================
" function detail
" ============================================================================
function! viewmap#Open() abort
    if viewmap#IsVisible() || &diff | return | endif

    execute 'vertical rightbelow ' . g:viewmap_width . ' new'
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
        autocmd BufEnter,BufWritePost,FileChangedShellPost * call viewmap#SafeUpdateContent()
        autocmd WinScrolled * call viewmap#SafeUpdatePosition()
        autocmd WinClosed * if win_getid() == s:viewmap_winid | let s:viewmap_winid = -1 | endif
    augroup END

    call viewmap#UpdateContent()
endfunction

function! viewmap#Close() abort
    if !viewmap#IsVisible() | return | endif

    if s:update_timer != -1
        call timer_stop(s:update_timer)
        let s:update_timer = -1
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

function! viewmap#UpdateContent() abort
    if !viewmap#IsVisible() || &diff || viewmap#IsInwindow() | return | endif

    let l:save_lazyredraw = &lazyredraw
    set lazyredraw

    let win_bufnr = winbufnr(win_getid())
    let win_width = winwidth(win_getid())
    let win_lines = line('$')

    let thumb_width = max([1, g:viewmap_width - 0])
    "let thumb_scale = max([1, win_width / thumb_width])
    let thumb_scale = 4
    let thumb_line = (win_lines + 3) / 4
    let thumb_cont = []

    for record in range(0, thumb_line - 1)
        let llist = []
        for offset in range(0, 3)
            let lnum = record * 4 + offset + 1
            call add(llist, lnum <= win_lines ? getbufline(win_bufnr, lnum)[0] : '')
        endfor
        let lcont = ''
        for col in range(0, thumb_width - 1)
            let char_list = [0, 0, 0, 0]
            for i in range(0, 3)
                let buffer_beg = match(llist[i], '[^ \t]') == -1 ? len(llist[i]) : match(llist[i], '[^ \t]')
                let buffer_end = strdisplaywidth(llist[i]) > 0 ? strdisplaywidth(llist[i]) - 1 : 0
                let thumb_beg = buffer_beg/thumb_scale
                let thumb_end = buffer_end/thumb_scale
                if llist[i] == ''
                    let char_list[i] = 0
                elseif col >= thumb_beg && col <= thumb_end
                    let char_list[i] = 1
                else
                    let char_list[i] = 0
                endif
            endfor
            let lcont .= get(s:block_chars, join(char_list, ''), ' ')
        endfor
        call add(thumb_cont, lcont)
    endfor

    call win_execute(s:viewmap_winid, 'setlocal modifiable')
    call win_execute(s:viewmap_winid, 'silent %delete _')
    call win_execute(s:viewmap_winid, 'call setline(1, ' . string(thumb_cont) . ')')
    call win_execute(s:viewmap_winid, 'setlocal nomodifiable')

    let &lazyredraw = l:save_lazyredraw
    call viewmap#UpdatePosition()
endfunction

function! viewmap#UpdatePosition() abort
    if !viewmap#IsVisible() || &diff || viewmap#IsInwindow() | return | endif

    let topline = line('w0')
    let botline = line('w$')
    let win_lines = line('$')
    let thumb_line = line('$', s:viewmap_winid)

    if thumb_line > 0
        let scale_factor = max([1, float2nr(ceil(win_lines * 1.0 / thumb_line))])
        let thumb_top = max([1, float2nr(floor(topline * 1.0 / scale_factor))])
        let thumb_bot = max([1, float2nr(ceil(botline * 1.0 / scale_factor))])
        let thumb_top = min([thumb_line, thumb_top])
        let thumb_bot = min([thumb_line, thumb_bot])

        if thumb_top > thumb_bot
            let [thumb_top, thumb_bot] = [thumb_bot, thumb_top]
        endif

        call win_execute(s:viewmap_winid, 'if exists("w:viewmap_highlight") | call matchdelete(w:viewmap_highlight) | endif')
        call win_execute(s:viewmap_winid, 'unlet! w:viewmap_highlight')

        if thumb_top <= thumb_bot && thumb_top > 0 && thumb_bot <= thumb_line
            let highlight_range = range(thumb_top, thumb_bot)
            if !empty(highlight_range)
                call win_execute(s:viewmap_winid, 'let w:viewmap_highlight = matchaddpos("'.g:viewmap_highlight.'", '.string(highlight_range).', 10)')
            endif
        endif

        let win_height = winheight(s:viewmap_winid)
        if win_height > 0 && thumb_top > 0 && thumb_bot > 0
            let center_pos = (thumb_top + thumb_bot) / 2
            let target_pos = max([1, center_pos - win_height / 2])
            let target_pos = min([thumb_line - win_height + 1, target_pos])
            if target_pos > 0
                call win_execute(s:viewmap_winid, 'call cursor(' . target_pos . ', 1)')
                call win_execute(s:viewmap_winid, 'normal! zt')
            endif
        endif
    endif

    let s:last_topline = topline
    let s:last_botline = botline
endfunction

function! viewmap#SafeUpdateContent() abort
    if !viewmap#IsVisible() || &diff || viewmap#IsInwindow() | return | endif
    if s:update_timer != -1
        call timer_stop(s:update_timer)
        let s:update_timer = -1
    endif
    let s:update_timer = timer_start(g:viewmap_updelay, {-> viewmap#UpdateContent()})
endfunction

function! viewmap#SafeUpdatePosition() abort
    if !viewmap#IsVisible() || &diff || viewmap#IsInwindow() | return | endif
    call viewmap#UpdatePosition()
endfunction

" ============================================================================
" diff mode
" ============================================================================
augroup ViewmapDiffmode
    autocmd!
    autocmd OptionSet diff
                \ if v:option_new && viewmap#IsVisible() |
                \     call timer_start(0, {-> viewmap#Close()}) |
                \ elseif !v:option_new && !viewmap#IsVisible() && g:viewmap_state == 1 |
                \     call timer_start(0, {-> viewmap#Open()}) |
                \ endif
augroup END

" ============================================================================
" interface list
" ============================================================================
function! viewmap#OpenState() abort
    call viewmap#Open()
    let g:viewmap_state = 1
    call viewmap#SafeUpdateContent()
    call viewmap#SafeUpdatePosition()
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

