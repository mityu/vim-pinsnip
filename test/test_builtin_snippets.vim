const s:assert = themis#helper('assert')
const s:suite = themis#suite('built-in snippets')
call themis#func_alias(s:assert)
call themis#func_alias(s:suite)

function s:parse_snip_line(text) abort
  const idx = stridx(a:text, g:pinsnip#cursor_placeholder)
  if idx == -1
    return [a:text, v:null]
  else
    const text = strpart(a:text, 0, idx) .. strpart(a:text, idx + strlen(g:pinsnip#cursor_placeholder))
    return [text, idx + 1]
  endif
endfunction

function s:parse_into_sections(lines) abort
  const tactics = ['input', 'output', 'description', 'skip']
  let sections = []
  let sec = v:null
  let skip_body = v:false

  let errs = []
  let l:AddErr = {nr, msg -> add(errs, $'at line {nr}: {msg}')}

  for [nr, text] in a:lines->mapnew({ i, v -> [i + 1, v] })
    if skip_body && text =~# '^\t'
      continue
    else
      let skip_body = v:false
    endif

    let tactic = tolower(matchstr(text, '^\w*'))
    if index(tactics, tactic) != -1
      if sec isnot v:null
        call add(sections, sec)
      endif
      let sec = #{
        \ line: nr,
        \ tactic: tactic,
        \ trailing_text: matchstr(text, '^\w*:\?\s*\zs.*$'),
        \ body: [],
        \ }
    elseif text =~# '^\t'
      " Section body text
      if sec is v:null
        let skip_body = v:true
        call l:AddErr(nr, 'Section body definition appears out of section.')
        continue
      endif
      call add(sec.body, text[1 :])
    elseif text =~# '^#' || text ==# ''
      " Empty line or comment line ends the current section.
      if sec isnot v:null
        call add(sections, sec)
        let sec = v:null
      endif
    else
      call l:AddErr(nr, 'Invalid format of line.')
    endif
  endfor

  if sec isnot v:null
    call add(sections, sec)
  endif

  if !empty(errs)
    return [v:null, errs]
  endif
  return [sections, v:null]
endfunction

function s:parse_into_cases_from_sections(sections) abort
  let errs = []
  let cases = []
  let case = {}
  let erroneous = v:false
  const l:AddErr = {nr, msg -> [extend(l:, #{ erroneous: v:true }, 'force'), add(errs, $'at line {nr}: {msg}')]}

  for sec in a:sections
    if has_key(case, sec.tactic)
      call l:AddErr(sec.line, $'Duplicate section found: {sec.tactic}')
    endif

    if sec.tactic == 'output' && !has_key(case, 'input')
      call l:AddErr(sec.line, 'No corresponding input section found for this output section.')
      let case = {}
    endif

    if index(['input', 'output'], sec.tactic) == -1
      if !empty(sec.body)
        call l:AddErr(sec.line, $'Tactic "{sec.tactic}" cannot have section body.')
      endif

      if has_key(case, 'input') || has_key(case, 'output')
        call l:AddErr(sec.line, $'Tactic "{sec.tactic}" must be placed before both "input" and "output" section.')
      endif
    endif

    if !has_key(case, 'line')
      let case.line = sec.line
    endif

    if !erroneous
      if index(['input', 'output'], sec.tactic) == -1
        let case[sec.tactic] = sec.trailing_text
      else
        let snip = #{ text: [] }
        for [nr, text] in sec.body->mapnew({ i, v -> [sec.line + i + 1, v] })
          let [text, col] = s:parse_snip_line(text)
          call add(snip.text, text)
          if col isnot v:null
            if has_key(snip, 'cursor')
              call l:AddErr(nr, 'Cursor position specifier appears two or more times.')
            else
              let snip.cursor = [len(snip.text), col]
            endif
          endif
        endfor
        if !has_key(snip, 'cursor')
          call l:AddErr(sec.line, $'Cursor position is not specified in this {sec.tactic} section.')
        endif

        let case[sec.tactic] = snip
      endif
    endif

    if has_key(case, 'input') && has_key(case, 'output')
      call add(cases, case)
      let case = {}
    endif
  endfor

  if !empty(case)
    call l:AddErr(case.line, $'Incomplete definition of section')
  endif

  if !empty(errs)
    return [v:null, errs]
  endif
  return [cases, v:null]
endfunction

function s:parse_test_suite(file) abort
  const l:ErrText = {errs -> $"While parsing {a:file}:\n{errs->mapnew({_, v -> $"\t{v}"})->join("\n")}"}

  const [sections, errs] = s:parse_into_sections(readfile(a:file))
  if errs isnot v:null
    throw l:ErrText(errs)
  endif

  unlet errs
  const [cases, errs] = s:parse_into_cases_from_sections(sections)
  if errs isnot v:null
    throw l:ErrText(errs)
  endif

  return cases
endfunction

function s:run_test_case(case) abort
  if has_key(a:case, 'skip')
    call s:assert.skip(a:case.skip)
  else
    const info_on_failure = $"# INPUT: \n{a:case.input.text->mapnew({_, v -> $"\t{v}"})->join("\n")}"
    call InvokeExpand(a:case.input,
      \ {-> s:assert.equals(GetBufState(), a:case.output, info_on_failure)})
  endif
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

      " Force shiftwidth() to return &tabstop to make internal indentation
      " generator to use tab for indentation.
      set shiftwidth=0
      set noexpandtab
    endfunction

    for [i, case] in cases->map({i, v -> [i + 1, v]})
      let key = $'case-{i}'
      if has_key(case, 'description')
        let key = $'{key} ({case.description})'
      endif
      let child[key] = function('s:run_test_case', [case])
    endfor
  endfor
endfunction
