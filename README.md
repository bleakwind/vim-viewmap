# vim-viewmap

## Sidebar thumbnail navigation for Vim
Viewmap is a lightweight Vim plugin that displays a real-time code thumbnail in a sidebar, providing a bird's-eye view of your document structure. It renders compressed text representations using Unicode Braille patterns, allowing you to quickly navigate large files while preserving spatial awareness.

## Features
- **Native**: 100% Vimscript, zero dependencies
- **Instant Overview**: See your entire file at a glance
- **Pixel-Perfect Preview**: Braille-pattern rendering preserves code structure
- **Zero Lag**: Optimized for buttery-smooth scrolling
- **Non-Invasive**: 20px slim sidebar that auto-hides in diff mode

## Screenshot
![Viewmap Screenshot](https://github.com/bleakwind/vim-viewmap/blob/main/vim-viewmap.png)

## Requirements
Vim 8.1+ (needs win_execute() and timer support)

## Installation
```vim
" Using Vundle
Plugin 'bleakwind/vim-viewmap'
```

And Run:
```vim
:PluginInstall
```

## Configuration
Add these to your `.vimrc`:
```vim
" Set 1 enable viewmap (default: 0)
let g:viewmap_enabled = 1
" Set sidebar width (default: 20)
let g:viewmap_width = 20
" Set update delay in milliseconds (default: 200)
let g:viewmap_updelay = 200
" Set highlight alpha (default: group is Normal, bg alpha is 0.3)
let g:viewmap_hlalpha = 0.3
```

Highlight configuration
```vim
" Set highlight details (will override g:viewmap_hlalpha)
hi ViewmapHighlight ctermfg=White ctermbg=Blue cterm=NONE guifg=#FFFFFF guibg=#6A5ACD gui=NONE
```

## Usage
| Command | Description |
| ---- | ---- |
| `:ViewmapOpen` | Open the thumbnail sidebar |
| `:ViewmapClose` | Close the thumbnail sidebar |
| `:ViewmapToggle` | Toggle the thumbnail sidebar |

## License
BSD 2-Clause - See LICENSE file

