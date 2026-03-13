scriptencoding utf-8

" IME制御: Normalモードに戻る際に英数入力へ切り替え
autocmd InsertLeave * :call system("osascript -e 'tell application \"System Events\" to key code 102'")

" Options
set noswapfile
set ruler
set cmdheight=2
set laststatus=2
set title
set wildmenu
set showcmd
" 検索結果をハイライト表示
set hlsearch
set number
" インデント設定
set tabstop=2
set shiftwidth=2
set expandtab
" set tag
set tags=~/.tags

" Start dein.vim Setting
let s:dein_dir = expand('~/.cache/dein')
let s:dein_repo_dir = s:dein_dir . '/repos/github.com/Shougo/dein.vim'

" dein.vim がなければ自動インストール
if !isdirectory(s:dein_repo_dir)
  execute '!git clone https://github.com/Shougo/dein.vim' s:dein_repo_dir
endif
execute 'set runtimepath+=' . s:dein_repo_dir

if dein#load_state(s:dein_dir)
  call dein#begin(s:dein_dir)

  " dein.vim 自身を管理
  call dein#add(s:dein_repo_dir)

  " add plugins

  " NERDTree
  call dein#add('scrooloose/nerdtree')

  " AutoClose
  call dein#add('Townk/vim-autoclose')

  " solarized
  call dein#add('altercation/vim-colors-solarized')
  " mustang
  call dein#add('croaker/mustang-vim')
  " jellybeans
  call dein#add('nanotech/jellybeans.vim')
  " molokai
  call dein#add('tomasr/molokai')

  call dein#add('Shougo/unite.vim')
  call dein#add('ujihisa/unite-colorscheme')

  " 行末の半角スペースを可視化
  call dein#add('bronson/vim-trailing-whitespace')

  " Git
  call dein#add('tpope/vim-fugitive')

  " for Rails
  call dein#add('tpope/vim-rails')

  " for Ruby -- auto add end
  call dein#add('tpope/vim-endwise')

  " for Ruby -- auto add comment on/off
  call dein#add('tomtom/tcomment_vim')

  " for Ruby indent guide
  call dein#add('nathanaelkane/vim-indent-guides')

  " add color for log
  call dein#add('vim-scripts/AnsiEsc.vim')

  " add neosnippet
  call dein#add('Shougo/neosnippet')
  call dein#add('Shougo/neosnippet-snippets')

  call dein#end()
  call dein#save_state()
endif

" 未インストールのプラグインがあればインストール
if dein#check_install()
  call dein#install()
endif

" Required:
filetype plugin indent on

" auto vim-indent-guides on
let g:indent_guides_enable_on_vim_startup = 1

" http://inari.hatenablog.com/entry/2014/05/05/231307
" """"""""""""""""""""""""""""""
" " 全角スペースの表示
" """"""""""""""""""""""""""""""
function! ZenkakuSpace()
  highlight ZenkakuSpace cterm=underline ctermfg=lightblue guibg=darkgray
endfunction

if has('syntax')
  augroup ZenkakuSpace
    autocmd!
      autocmd ColorScheme * call ZenkakuSpace()
      autocmd VimEnter,WinEnter,BufRead * let w:m1=matchadd('ZenkakuSpace', '　')
    augroup END
    call ZenkakuSpace()
endif
"""""""""""""""""""""""""""""""

""""""
" 順方向に補完候補を選択するには<c-n>とする。
" 逆方向に補完候補を選択するには<c-p>とする。(※<c-○>はCtrl + ○という意味。)
" 補完候補から入力を決定するにはTabを押す。<Tab>を押すごとにマーカーごとにジャンプができる。
""""""

" grep検索の実行後にQuickFix Listを表示する
autocmd QuickFixCmdPost *grep* cwindow

" ステータス行に現在のgitブランチを表示する
if isdirectory(expand('~/.cache/dein/repos/github.com/tpope/vim-fugitive'))
  set statusline+=%{fugitive#statusline()}
endif

" setting neosnippet
" Plugin key-mappings.
imap <C-k>     <Plug>(neosnippet_expand_or_jump)
smap <C-k>     <Plug>(neosnippet_expand_or_jump)
xmap <C-k>     <Plug>(neosnippet_expand_target)

" SuperTab like snippets behavior.
imap <expr><TAB> neosnippet#expandable_or_jumpable() ?
\ "\<Plug>(neosnippet_expand_or_jump)"
\: pumvisible() ? "\<C-n>" : "\<TAB>"
smap <expr><TAB> neosnippet#expandable_or_jumpable() ?
\ "\<Plug>(neosnippet_expand_or_jump)"
\: "\<TAB>"

" For snippet_complete marker.
if has('conceal')
  set conceallevel=2 concealcursor=i
endif

" End dein.vim Setting

" Color Scheme Setting

"colorscheme evening
colorscheme jellybeans
if !has('nvim')
  if &term =~ "xterm-256color" || &term =~ "screen-256color"
    set t_Co=256
    set t_Sf=[3%dm
    set t_Sb=[4%dm
  elseif &term =~ "xterm-color"
    set t_Co=8
    set t_Sf=[3%dm
    set t_Sb=[4%dm
  endif
endif

syntax enable
hi PmenuSel cterm=reverse ctermfg=33 ctermbg=222 gui=reverse guifg=#3399ff guibg=#f0e68c

" Using the mouse on a terminal.
if has('mouse')
  set mouse=a
  if !has('nvim')
    if has('mouse_sgr')
      set ttymouse=sgr
      " I couldn't use has('mouse_sgr')
    elseif v:version > 703 || v:version is 703 && has('patch632')
      set ttymouse=sgr
    else
      set ttymouse=xterm2
    endif
  endif
endif
