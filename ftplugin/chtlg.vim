" This script will run anytime that the filetype for a buffer has been set to 'ftplugin'.  Note that any logic added
" to this script should always be appropriate to run for any chat log file regardless of whether such file is empty or
" contains data.


" Initialize Buffer - Call a function that will check to see if the current buffer is empty and if so will populate it
"                     with the basic skeleton structure for a chat log file (i.e., the required header elements and an
"                     initial user message start token).
call LLMChat#new_chat#InitializeChatBuffer()


" Setup a custom folding definition created specifically for chatlog files.  Note that this can be disabled by changing
" the value used for 'g:llmchat_use_chat_folding' to 0 either in the plugin code or in your ~/.vimrc file.
if g:llmchat_use_chat_folding

    setlocal foldmethod=expr
    setlocal foldexpr=LLMChat#folding#GetFoldLevel(v:lnum)

endif


" Setup the format options and comments defaults for chat log files.  This will include the following:
"
"   Format Options:
"     c  - Automatically wrap comments when a comment line exceeds 'textwidth' characters in size
"     j  - Remove comment leaders (i.e., '#' characters) when joining together comment lines.
"     l  - Don't break existing long lines when going into insert mode
"     o  - Automatically insert the comment leader on a new line created by 'o' or 'O' in normal mode when the command
"          is issued from a comment line.
"     q  - Allow the formatting of comments when the 'gq' command is issued.
"     r  - Automatically insert the comment leader on a new line created by pressing <Enter> from a comment line.
"     t  - Auto-wrap text based on the 'textwidth' setting.
"
"  Comments: Any line that starts with a '#' character should be recognized as a comment line.
"
setlocal formatoptions=cjloqrt
setlocal comments=:#

