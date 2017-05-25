if exists('g:loaded_dimjump')
  finish
endif
let g:loaded_dimjump = 1

function s:prog()
  if get(b:,'preferred_searcher') !~# '^\%([ar]g\|\%(git-\)\=grep\)$'
    if system('git rev-parse --is-inside-work-tree')[:-2] ==# 'true'
      let b:preferred_searcher = 'git-grep'
    elseif exists('s:ag') || executable('ag')
      let s:ag = 1
      let b:preferred_searcher = 'ag'
    elseif exists('s:rg') || executable('rg')
      let s:rg = 1
      let b:preferred_searcher = 'rg'
    elseif exists('s:grep') || executable('grep')
      let s:grep = 1
      let b:preferred_searcher = 'grep'
      if !exists('s:gnu')
        let s:gnu = systemlist('grep --version')[0] =~# 'GNU'
      endif
    else
      throw 'no search program available'
    endif
  endif
endfunction

let s:timeout = executable('timeout') ? 'timeout 5 ' : executable('gtimeout') ? 'gtimeout 5 ' : ''

try
  let s:defs = json_decode(join(readfile(fnamemodify(expand('<sfile>:p:h:h'),':p').'jump-extern-defs.json')))
catch
  try
    let s:strdefs = join(readfile(fnamemodify(expand('<sfile>:p:h:h'),':p').'jump-extern-defs.json'))
    sandbox let s:defs = eval(s:strdefs)
  catch
    unlet! s:defs
    finish
  finally
    unlet! s:strdefs
  endtry
endtry

call map(s:defs,'filter(v:val,''v:key !~# "\\v^%(tests|not)$"'')')

let s:transforms = {
      \ 'clojure': 'substitute(JJJ,".*/","","")',
      \ 'ruby': 'substitute(JJJ,"^:","","")'
      \ }
function s:prune(kw)
  if has_key(s:transforms,&ft)
    return eval(substitute(s:transforms[&ft],'\CJJJ',string(a:kw),'g'))
  endif
  return a:kw
endfunction

let s:searchprg  = {
      \ 'rg': {'opts': ' --no-messages --color never --vimgrep -g ''*.%:e'' -e '},
      \ 'grep': {'opts': ' --no-messages -rnH --color=never --include=''*.%:e'' -E -e '},
      \ 'git-grep': {'opts': ' --untracked --line-number --no-color -E -e '},
      \ 'ag': {'opts': ' --silent --nocolor --vimgrep -G ''.*\.%:e$'' '}
      \ }

function s:Grep(searcher,regparts,token)
  let grepf = &errorformat
  set errorformat&vim
  let args = "'\\bJJJ\\b'"
  if !empty(a:regparts)
    if a:searcher =~# 'grep'
      if a:searcher =~# 'git'
        let args = shellescape(join(a:regparts,'|'))
      else
        let args = join(map(deepcopy(a:regparts),'shellescape(v:val)'),' -e ')
        if s:gnu
          let args = substitute(args,'\C\\s','[[:space:]]','g')
        endif
      endif
    else
      let args = shellescape(join(a:regparts,'|'))
    endif
    if &isk =~ '\%(^\|,\)-'
      if a:searcher ==# 'ag'
        let args = substitute(args,'\C\\j','(?!|[^\\w-])','g')
      else
        let args = substitute(args,'\C\\j','($|[^\\w-])','g')
      endif
    else
      let args = substitute(args,'\C\\j','\\b','g')
    endif
  endif
  if a:searcher ==# 'git-grep'
    let args .= " -- '*.".expand('%:e')."'"
  endif
  let grepcmd = s:timeout . tr(a:searcher,'-',' ')
        \ . substitute(substitute(s:searchprg[a:searcher]['opts']
        \ , '\C%:e', '\=expand(submatch(0))', 'g')
        \ . args
        \ , '\CJJJ', a:token, 'g')
  silent! cexpr system(grepcmd)
  let &errorformat = grepf
endfunction

function s:GotoDefCword()
  call s:prog()
  let kw = s:prune(expand('<cword>'))
  if kw isnot ''
    if !exists('b:dim_jump_lang')
      let b:dim_jump_lang = filter(map(deepcopy(s:defs,1)
            \ ,'v:val.language ==? &ft && index(v:val.supports, b:preferred_searcher) != -1 ? v:val.regex : ""')
            \ ,'v:val isnot ""')
    endif
    call s:Grep(b:preferred_searcher, b:dim_jump_lang, kw)
  endif
endfunction

command DimJumpPos call <SID>GotoDefCword()
