const s:assert = themis#helper('assert')
const s:suite = themis#suite('built-in snippets')
call themis#func_alias(s:assert)
call themis#func_alias(s:suite)

function s:validate_test_case(file, secline, case) abort
  let errs = []
  if !has_key(a:case.before, 'cursor')
    call add(errs, $'While parsing {a:file}: at line {a:secline.input}: No cursor position specified for this input section.')
  endif
  if !has_key(a:case.after, 'cursor')
    call add(errs, $'While parsing {a:file}: at line {a:secline.output}: No cursor position specified for this output section.')
  endif
  if !empty(errs)
    throw join(errs, "\n")
  endif
endfunction

function s:parse_snip_line(text) abort
  const idx = stridx(a:text, g:pinsnip#cursor_placeholder)
  if idx == -1
    return [a:text, v:null]
  else
    const text = strpart(a:text, 0, idx) .. strpart(a:text, idx + strlen(g:pinsnip#cursor_placeholder))
    return [text, idx + 1]
  endif
endfunction

function s:parse_test_suite(file) abort
  const sec = #{ none: 0, input: 1, output: 2, }
  const lines = readfile(a:file)->map({ i, v -> [i + 1, v] })

  let cases = []
  let section = sec.none
  let secline = #{ input: 0, output: 0 }

  for [nr, text] in lines
    let l:Err = {msg -> $'While parsing {file}: at line {nr}: {msg}'}
    if text =~# '^\t'
      if section == sec.none
        throw l:Err('Started test case definition without section declaration.')
      elseif section == sec.input || section == sec.output
        let case = section == sec.input ? cases[-1].before : cases[-1].after
        let [text, col] = s:parse_snip_line(text[1 :])

        call add(case.text, text)
        if col isnot v:null
          if has_key(case, 'cursor')
            throw l:Err('Cursor position specifier appears second time.')
          endif
          let case.cursor = [len(case.text), col]
        endif
      else
        throw l:Err($'Internal error: unreachable: {expand('<stack>')}')
      endif
    elseif text =~# '^\s'
      throw l:Err('Line must starts with non-whitespace or the tab character.')
    elseif text =~? '^input\>'
      if section == sec.input
        throw l:Err('Missing corresponding output section for this input section.')
      endif

      " Validate the previous test case.
      if !empty(cases)
        call s:validate_test_case(a:file, secline, cases[-1])
      endif

      let section = sec.input
      let secline.input = nr
      let secline.output = 0
      call add(cases, #{ before: #{ text: [] }, after: #{ text: [] }})
    elseif text =~? '^output\>'
      if section == sec.output
        throw l:Err('Missing corresponding input section for this output section.')
      endif
      let section = sec.output
      let secline.output = nr
    elseif text =~# '^#'
      " Do nothing
    elseif text ==# ''
      " The empty line means the end of section.
      let section = sec.none
    else
      throw l:Err($'Unknown directive at the head of line: {matchstr(text, '^\S*')}')
    endif
  endfor

  if !empty(cases)
    call s:validate_test_case(a:file, secline, cases[-1])
  endif
  return cases
endfunction

function s:run_test_case(case) abort
  const info_on_failure = $"# INPUT: \n{a:case.before.text->mapnew({_, v -> $"\t{v}"})->join("\n")}"
  call InvokeExpand(a:case.before, {-> s:assert.equals(GetBufState(), a:case.after, info_on_failure)})
endfunction

function s:suite.before_each() abort
  %bwipeout!
endfunction

function s:suite.after() abort
  %bwipeout!
endfunction

function s:suite.__test_by_testcases__() abort
  const suitefiles = globpath(expand('<script>:p:h'), 'testcases/*.suite', 0, 1)
  for file in suitefiles
    let cases = s:parse_test_suite(file)
    let ft = fnamemodify(file, ':t:r')
    let child = themis#suite($'ft={ft}')

    function child.before_each() abort closure
      if ft !=# '_'
        execute $'set filetype={ft}'
      endif
      set noexpandtab
    endfunction

    for [i, case] in cases->map({i, v -> [i + 1, v]})
      let child[$'case-{i}'] = function('s:run_test_case', [case])
    endfor
  endfor
endfunction
