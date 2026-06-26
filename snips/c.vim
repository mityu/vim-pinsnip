function s:include_guard(line) abort
  const fname = bufname('%')->fnamemodify(':t')
  if fname ==# '' || fnamemodify(fname, ':e') !~? '^h'
    " No filename or non header file.  Do not apply.
    return v:false
  endif

  const guardian = fname->toupper()->tr('.-', '__') .. '_'  " Include guard
  const snip = [
    \  $'#ifndef {guardian}',
    \  $'#define {guardian}',
    \  '',
    \  g:pinsnip#cursor_placeholder,
    \  '',
    \  $'#endif  // {guardian}'
    \ ]
  if stridx(snip[0], a:line) == -1
    return v:false
  endif
  call pinsnip#apply_snip(snip)
  return v:true
endfunction

function s:include_directive(comparison) abort
  if a:comparison !~# '\v^#\s*in%[clude]' || a:comparison =~# '\v^#\s*include\s*\<'
    return v:false
  endif
  const padding = matchstr(a:comparison, '\v^#\zs\*\zein')
  call pinsnip#apply_snip([$'#{padding}include <{g:pinsnip#cursor_placeholder}>'])
  return v:true
endfunction

function s:source_code_template(comparison) abort
  " This snippet works like a template; apply this when only the cursor line
  " is modified.
  if !(prevnonblank(line('.') - 1) == 0 && nextnonblank(line('.') + 1) == 0)
    return v:false
  endif
  const snip = [
  \  '#include <stdio.h>',
  \  '',
  \  'int main(void) {',
  \  "\tputs(\"Hello\");" .. g:pinsnip#cursor_placeholder,
  \  '}'
  \ ]

  if stridx(snip[0], a:comparison) == -1
    return v:false
  endif
  call pinsnip#apply_snip(snip)
  return v:true
endfunction

call pinsnip#add_snippets_for_filetype('c', [
  \ function('s:include_guard'),
  \ function('s:include_directive'),
  \ function('s:source_code_template'),
  \ ])
