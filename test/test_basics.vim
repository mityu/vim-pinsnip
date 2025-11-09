const s:suite = themis#suite('basic functionalities')
const s:assert = themis#helper('assert')
call themis#func_alias(s:suite)
call themis#func_alias(s:assert)

function s:suite.before() abort
  let snips = []
  eval snips->add({_ -> pinsnip#apply_snip(['if-cond', "\tbody<<+CURSOR+>>", 'end'])})
  call pinsnip#add_snippets_for_filetype('ft-for-test', snips)
endfunction

function s:suite.after() abort
  %bwipeout!
endfunction

function s:suite.__test__() abort
  let suites = [
    \ #{
    \   et: v:false,
    \   sw: 2,
    \   before: #{
    \     text: ["if-"],
    \     cursor: [1, 4],
    \   },
    \   after: #{
    \     text: ["if-cond", "\tbody", "end"],
    \     cursor: [2, 6],
    \   },
    \ },
    \ #{
    \   et: v:false,
    \   sw: 2,
    \   before: #{
    \     text: ["\tif-"],
    \     cursor: [1, 5],
    \   },
    \   after: #{
    \     text: ["\tif-cond", "\t\tbody", "\tend"],
    \     cursor: [2, 7],
    \   },
    \ },
    \ #{
    \   et: v:true,
    \   sw: 2,
    \   before: #{
    \     text: ["if-"],
    \     cursor: [1, 4],
    \   },
    \   after: #{
    \     text: ["if-cond", "  body", "end"],
    \     cursor: [2, 7],
    \   },
    \ },
    \ #{
    \   et: v:true,
    \   sw: 2,
    \   before: #{
    \     text: ["  if-"],
    \     cursor: [1, 6],
    \   },
    \   after: #{
    \     text: ["  if-cond", "    body", "  end"],
    \     cursor: [2, 9],
    \   },
    \ },
    \ #{
    \   et: v:true,
    \   sw: 5,
    \   before: #{
    \     text: ["     if-"],
    \     cursor: [1, 9],
    \   },
    \   after: #{
    \     text: ["     if-cond", "          body", "     end"],
    \     cursor: [2, 15],
    \   },
    \ },
    \ ]
  for suite in suites
    let child = themis#suite($'et={suite.et}, sw={suite.sw}')
    function child.before() abort closure
      set filetype=ft-for-test
      if suite.et
        set expandtab
      else
        set noexpandtab
      endif
      execute $'set shiftwidth={suite.sw}'
    endfunction

    function child.expand() abort closure
      call InvokeExpand(suite.before, {-> 
            \ s:assert.equals(GetBufState(), suite.after)
            \ })
    endfunction

    function child.after() abort closure
      %bwipeout!
    endfunction

    call themis#func_alias(child)
  endfor
endfunction
