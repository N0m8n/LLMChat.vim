" This script will setup the filetype assignment for any new file opened in Vim having the extension .chtlg
" ("chat log") OR any buffer opened for a new file which does not yet exist on disk and which will be saved with a
" .chtlg extension.

" Define an autocommand that when starting to edit a new file (BufNewFile) OR when starting to edit a new buffer after
" reading an existing file (BufRead) AND such file has the extension ".chtlg" then set the filetype to 'chtlg'.  This
" is important to engage things like chat initialization, syntax highlighting, etc.
autocmd BufNewFile,BufRead *.chtlg set filetype=chtlg


" Tweak the 'shortmess' option so that we don't have to hit enter each time that a new, empty chat buffer is created.
" Without this you will get a message like "40 new lines" with a request to press <Enter> if you try to open an empty
" or non-existant chat log with commands like ":e", ":split", ":vsplit", etc.  It is annoying to press enter just to
" acknowledge that the chat buffer was auto-initialized so we will disable that.
set shortmess+=F


" Setup the syntax file to be used for chat logs by default.
set syntax=chtlog

