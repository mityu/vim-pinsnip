function s:snip_iferr(comparison) abort
  const r = '^\v(}\s*else\s+)?if(\s*.{-};)?\s*%(e%[rr]\s*%(!=\s*nil\s*)?(\S+)?)'

  const m = matchlist(a:comparison, r)
  if empty(m)
    return v:false
  endif

  const [else_unit, initializer, kind] = m[1 : 3]
  let snip = [$'{else_unit}if{initializer} err != nil {{']
  if kind !=# ''
    let processes = [
      \  'return err',
      \  'fmt.Println(err)',
      \  'log.Fatal(err)',
      \  'panic(err)',
      \  't.Error(err)',
      \  't.Fatal(err)',
      \ ]
    for p in processes
      if stridx(tolower(p), kind) != -1
        eval snip->add("\t" .. p)
        break
      endif
    endfor
  endif
  if len(snip) == 1
    eval snip->add("\treturn " .. g:pinsnip#cursor_placeholder)
  endif
  eval snip->add('}')
  call pinsnip#apply_snip(snip)
  return v:true
endfunction

function s:gen_lambda_var_decl(line) abort
  const r = '^\v((\w|_)+)\s*:\=\s*func\((.{-})\)\s*(\S+|\(%(\s*\S+)+\s*\))?\s*\{\s*$'
  const m = matchlist(a:line, r)
  if empty(m)
    return v:false
  endif
  const fun_name = m[1]
  const fun_args = m[3]
  const fun_ret  = m[4]
  const fun_arg_types = substitute(
    \ ',' .. fun_args,
    \ '\v(%(\s*,\s*%(\w|_)+)+)\s+(\S+)\ze%(,|$)',
    \ {-> (repeat([submatch(2)], count(submatch(1), ',')) + [''])->join(', ')},
    \ 'g')[: -3]

  const fun_decl_var = trim($'var {fun_name} func({fun_arg_types}) {fun_ret}')
  const fun_decl_body = $'{trim($'{fun_name} = func({fun_args}) {fun_ret}')} {{{g:pinsnip#cursor_placeholder}'

  call pinsnip#apply_snip([fun_decl_var, fun_decl_body])
  return v:true
endfunction

call pinsnip#add_snippets_for_filetype('go', [
  \ function('s:snip_iferr'),
  \ function('s:gen_lambda_var_decl'),
  \ ])
