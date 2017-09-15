if exists('g:loaded_dimjump')
  finish
endif
let g:loaded_dimjump = 1

let [s:ag, s:rg, s:grep] = ['', '', '']
function s:prog()
  if get(b:,'preferred_searcher') !~# '^\%([ar]g\|\%(git-\)\=grep\)$'
    if system('git rev-parse --is-inside-work-tree')[:-2] is# 'true'
      let b:preferred_searcher = 'git-grep'
      return
    elseif empty(s:ag.s:rg.s:grep)
      for p in ['ag', 'rg', 'grep']
        if executable(p)
          let s:{p} = p
          let s:gnu = p ==# 'grep' && systemlist('grep --version')[0] =~# 'GNU'
          break
        endif
      endfor
    endif
    let b:preferred_searcher = matchstr([s:ag, s:rg, s:grep],'.')
  endif
endfunction

let s:timeout = executable('timeout') ? 'timeout 5 ' : executable('gtimeout') ? 'gtimeout 5 ' : ''

let s:f = expand('<sfile>:p:h:h')
function s:loaddefs()
  if !exists('s:defs')
    try
      if exists('*json_decode')
        let s:defs = json_decode(join(readfile(fnamemodify(s:f,':p').'jump-extern-defs.json')))
      else
        let l:strdefs = join(readfile(fnamemodify(s:f,':p').'jump-extern-defs.json'))
        sandbox let s:defs = eval(l:strdefs)
        unlet! l:strdefs
      endif
    catch
      unlet! l:strdefs
      let s:defs = {}
    endtry
    call map(s:defs,'filter(v:val,''v:key !~# "^\\%(tests\\|not\\)$"'')')
  endif
  return s:defs
endfunction


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

function s:Grep(token)
  let grepf = &errorformat
  set errorformat&vim
  let args = "'\\bJJJ\\b'"
  if !empty(b:dim_jump_lang)
    if b:preferred_searcher ==# 'grep'
      let args = join(map(deepcopy(b:dim_jump_lang),'shellescape(v:val)'),' -e ')
      if s:gnu
        let args = substitute(args,'\C\\s','[[:space:]]','g')
      endif
    else
      let args = shellescape(join(b:dim_jump_lang,'|'))
    endif
    if '-' =~ '\k'
      if b:preferred_searcher ==# 'ag'
        let args = substitute(args,'\C\\j','(?!|[^\\w-])','g')
      else
        let args = substitute(args,'\C\\j','($|[^\\w-])','g')
      endif
    else
      let args = substitute(args,'\C\\j','\\b','g')
    endif
  endif
  if b:preferred_searcher ==# 'git-grep'
    let args .= " -- '*.".expand('%:e')."'"
  endif
  let grepcmd = s:timeout . tr(b:preferred_searcher,'-',' ')
        \ . substitute(substitute(s:searchprg[b:preferred_searcher]['opts']
        \ , '\C%:e', '\=expand(submatch(0))', 'g')
        \ . args
        \ , '\CJJJ', a:token, 'g')
  let prev = getqflist()
  silent! cexpr system(grepcmd)
  call setqflist(prev,'r')
  let &errorformat = grepf
endfunction

function s:GotoDefCword()
  let kw = s:prune(expand('<cword>'))
  if kw isnot ''
    call s:prog()
    if !exists('b:dim_jump_lang')
      let b:dim_jump_lang = filter(map(deepcopy(s:loaddefs(),1)
            \ ,'v:val.language ==? &ft && index(v:val.supports, b:preferred_searcher) != -1 ? v:val.regex : ""')
            \ ,'v:val isnot ""')
      if empty(s:defs)
        norm! 1gD
        return
      endif
    endif
    call s:Grep(kw)
  endif
endfunction

command DimJumpPos call <SID>GotoDefCword()
