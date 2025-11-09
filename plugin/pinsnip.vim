 augroup plugin-pinsnip
   autocmd!
   autocmd FileType * call pinsnip#load(expand('<amatch>'))
 augroup END

inoremap <silent> <Plug>(pinsnip-expand) <C-r>=pinsnip#expand()<CR>

" command! -bar -bang -nargs=1 -complete=filetype PinsnipLoad
"   \ call pinsnip#Load(<q-args>, <bang>v:true, v:true)
