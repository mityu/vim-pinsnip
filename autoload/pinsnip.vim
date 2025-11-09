const g:pinsnip#cursor_placeholder = '<<+CURSOR+>>'
const s:builtin_snip_dir = fnamemodify(expand('<script>:p:h:h'), ':p') .. 'snips'
let s:snips = {}

function! s:get_one_indent_string() abort
  if &expandtab || strdisplaywidth("\t") != shiftwidth()
    return repeat(' ', shiftwidth())
  endif
  return "\t"
endfunction

function! s:error(msg) abort
  echohl ErrorMsg
  echomsg '[pinsnip] ' . a:msg
  echohl NONE
endfunction

function! s:warning(msg) abort
  echohl WarningMsg
  echomsg '[pinsnip] ' . a:msg
  echohl NONE
endfunction

function! s:get_snippets(ft) abort
  if has_key(s:snips, a:ft)
    return s:snips[a:ft]
  endif
  return []
endfunction

function! s:apply_providers(ft, comparison) abort
  let providers = s:get_snippets(a:ft)
  for F in providers
    if call(F, [a:comparison])
      return v:true
    endif
  endfor
  return v:false
endfunction

" Trigger postfix snippet expansion.
function! pinsnip#expand() abort
  let comparison = trim(getline('.'))
  if comparison ==# ''
    call s:warning('Empty pattern')
    return ''
  endif

  if s:apply_providers(&l:filetype, comparison)
    return ''
  endif

  if s:apply_providers('_', comparison)
    return ''
  endif

  call s:error('Snippet not found: ' . comparison)
  return ''
endfunction

" Replace current line using given lines.
function! pinsnip#apply_snip(snip_given) abort
  const current_indent = matchstr(getline('.'), '^\s*')
  let snip = copy(a:snip_given)

  call map(snip, {idx, line ->
        \ current_indent . substitute(line, "^\t*\t", s:get_one_indent_string(), 'g')})

  call add(snip, current_indent)

  let cursor_line = -1
  let cursor_col = strlen(snip[-1])

  for line in snip
    let idx = stridx(line, g:pinsnip#cursor_placeholder)
    let cursor_line += 1
    if idx >= 0
      let cursor_col = idx
      let snip[cursor_line] =
            \ strpart(line, 0, idx) . strpart(line, idx + strlen(g:pinsnip#cursor_placeholder))
      call remove(snip, -1)
      break
    endif
  endfor

  if mode() ==# 'i'
    let cursor_col += 1
  endif

  call append('.', snip)
  delete _
  call cursor(line('.') + cursor_line, cursor_col)

  if exists('#User#PinsnipApplyPost')
    doautocmd <nomodeline> User PinsnipApplyPost
  endif
endfunction

function! pinsnip#add_snippets_for_filetype(filetype, snips) abort
  if !has_key(s:snips, a:filetype)
    let s:snips[a:filetype] = []
  endif
  if !(type(a:snips) == v:t_list && reduce(a:snips, { acc, v -> acc && type(v) == v:t_func }, v:true))
    call s:error('"snips" must have type list<func>.')
    return
  endif
  call extend(s:snips[a:filetype], copy(a:snips))
endfunction

" TODO: Implement function to merge other filetypes' snippets.

function! pinsnip#load(filetype, reload = v:false, manual = v:false) abort
  " TODO: Handle a:reload and a:manual
  if has_key(s:snips, a:filetype)
    return
  endif

  let snipdirs = []
  if exists('g:pinsnip_snippet_dirs')
    let snipdirs = g:pinsnip_snippet_dirs
  else
    let snipdirs = [s:builtin_snip_dir]
  endif

  for snipdir in snipdirs
    let src = $'{fnamemodify(snipdir, ':p')}{a:filetype}.vim'
    if filereadable(src)
      source `=src`
    endif
  endfor
endfunction

function pinsnip#builtin_snippet_dir() abort
  return s:builtin_snip_dir
endfunction
