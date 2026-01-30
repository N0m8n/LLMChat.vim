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
    setlocal foldexpr=LLMChatFolding(v:lnum)

endif
