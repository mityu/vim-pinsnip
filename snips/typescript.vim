function s:import(line) abort
  " Complete `import` statement.
  const r = '\v^im%[port]%(\s*(\{[^}]*}|\*\s+as\s+\w+))?%(\s+f%[rom])?\s*("[^"]*"?)?\s*;?\s*$'
  const m = matchlist(a:line, r)
  if empty(m)
    return v:false
  endif

  let [imports, path] = m[1 : 2]
  let needCursorPlaceHolder = v:true
  if path !~# '^".*"$'
    if path ==# ''
      let path = $'"{g:pinsnip#cursor_placeholder}"'
    else
      let path ..= g:pinsnip#cursor_placeholder .. '"'
    endif
    let needCursorPlaceHolder = v:false
  endif

  if imports ==# ''
    if needCursorPlaceHolder
      let imports = '{' .. g:pinsnip#cursor_placeholder .. '}'
      let needCursorPlaceHolder = v:false
    else
      let imports = '{}'
    endif
  elseif needCursorPlaceHolder
    if imports =~# '^{'
      const [pre, suf] = split(imports, '\ze\s*}$')
      let imports = pre .. g:pinsnip#cursor_placeholder .. suf
    else
      let imports ..= g:pinsnip#cursor_placeholder
    endif
    let needCursorPlaceHolder = v:false
  endif

  const snip = $'import {imports} from {path};'
  call pinsnip#apply_snip([snip])
  return v:true
endfunction

" TODO: Port more snippets

call pinsnip#add_snippets_for_filetype('typescript', [
  \ function('s:import'),
  \ ])
