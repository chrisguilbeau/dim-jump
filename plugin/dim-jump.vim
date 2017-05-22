if exists('g:loaded_dimjump')
  finish
endif
let g:loaded_dimjump = 1

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

let s:transforms = {
      \ 'clojure': 'substitute(JJJ,".*/","","")',
      \ 'ruby': 'substitute(JJJ,"^:","","")'
      \ }
function s:prune(kw)
  if has_key(s:transforms,&ft)
    return eval(substitute(s:transforms[&ft],'JJJ',string(a:kw),'g'))
  endif
  return a:kw
endfunction

let s:preferred = 'grep'
let s:searchprg  = {
      \ 'rg': {'opts': ' --color never --no-heading --type %:e '},
      \ 'grep': {'opts': ' -rnH --include=*.%:e '},
      \ 'ag': {'opts': ' --nocolor --nogroup --%:e '}
      \ }

function s:Grep(searcher,regparts,token)
  let grepr = &grepprg
  let args = ''
  if len(a:regparts)
    if a:searcher ==# 'grep'
      let args = '-E -e '.join(map(a:regparts,'shellescape(v:val)'),' -e ')
    else
      let args = shellescape(join(a:regparts,'|'))
    endif
    if &isk =~ '\%(^\|,\)-'
      if a:searcher ==# 'ag'
        let args = substitute(args,'\\j','(?!|[^\\w-])','g')
      else
        let args = substitute(args,'\\j','($|[^\\w-])','g')
      endif
    endif
  endif
  let &grepprg = escape(a:searcher
        \ . substitute(s:searchprg[a:searcher].opts
        \ . args
        \ , 'JJJ','$*','g'), '|')
  exe 'grep ' . a:token
  let &grepprg = grepr
endfunction

function s:GotoDefCword()
  if !exists('b:dim_jump_lang')
    let b:dim_jump_lang = filter(deepcopy(s:defs),'v:val.language ==? &ft')
  endif
  let patterns = []
  for d in b:dim_jump_lang
    if index(d.supports,s:preferred) != -1
      call add(patterns,d.regex)
    endif
  endfor
  call s:Grep(s:preferred,patterns,s:prune(expand('<cword>')))
endfunction

command DimJumpPos call <SID>GotoDefCword()
