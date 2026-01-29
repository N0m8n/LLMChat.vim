" This script provides support for syntax highlighting in chat log files.
"
" NOTE: The leading '\v...' in syntax match expressions tells Vim that we want to use "very magic" mode when evaluating
"       the regex.
"

" Add delimiter fragments to the "error" group; at least when they begin at the start of the line.  These are
" relatively hard to see so calling them out early should help make the plugin more user friendly.
syn match LLMChatOptionErrors '\v^[=>]\>[^>]?'
syn match LLMChatOptionErrors '\v^\<\<[^<=]?'


" Add syntax higlighting for the various chat delimiters used to define where user and assistant messages start/end.
syn match LLMChatDelimiters '\v^\>\>\>'
syn match LLMChatDelimiters '\v^\<\<\<'
syn match LLMChatDelimiters '\v^\=\>\>'
syn match LLMChatDelimiters '\v^\<\<\='


" Add syntax highlighting for escape sequences recognized within the context of the chat log document.
syn match LLMChatEscapeSeqs '\v\\\>\>\>'
syn match LLMChatEscapeSeqs '\v\\\<\<\<'
syn match LLMChatEscapeSeqs '\v\\\=\>\>'
syn match LLMChatEscapeSeqs '\v\\\<\<\='
syn match LLMChatEscapeSeqs '\v\\n'
syn match LLMChatEscapeSeqs '\v\\\['


" Add syntax highlighting for resources included into a chat message.
syn match LLMChatResources '\v^\s*\[.*\]\s*$'


" Add syntax highlighting for the kinds of separators that you can use inside a chat log file (i.e, the header separator
" and arbitrary chat separator lines).
syn match LLMChatSeparators '\v^\s*\-+\s*$'
syn match LLMChatSeparators '\v^\s*\*+ ENDSETUP \*+\s*$'


" Add syntax highlighting for the key words found within the header section of the chat log file.
syn match LLMChatOptionKeywords '\v^\s*Server Type\:' skipwhite
syn match LLMChatOptionKeywords '\v\s*Server URL\:' skipwhite
syn match LLMChatOptionKeywords '\v\s*Model ID\:' skipwhite
syn match LLMChatOptionKeywords '\v\s*Use Auth Token\:' skipwhite
syn match LLMChatOptionKeywords '\v\s*Auth Token\:' skipwhite
syn match LLMChatOptionKeywords '\v\s*Option\:' skipwhite
syn match LLMChatOptionKeywords '\v\s*System Prompt\:' skipwhite
syn match LLMChatOptionKeywords '\v\s*Show Reasoning\:' skipwhite


" Add syntax highlighting for comments found within the chat log file.
syn match LLMChatComments '\v^\s*#.*$'


" Flag closing separators followed by text as errors.  Note that this is at the bottom (rather than the top next to the
" other errors) so that the line flagging takes priority over other syntax matches.
syn match LLMChatOptionErrors '\v^\<\<\<\s*\S+'
syn match LLMChatOptionErrors '\v^\<\<\=\s*\S+'


" Flag the default model ID token (i.e., the token use when no default model ID has been configured) that is inserted
" into a templated chat document as invalid.  This is just meant to call user attention to the fact that the model ID
" value inserted must be removed and replaced.
syn match LLMChatOptionErrors '\v\<REQUIRED - Please Fill In\>'


" Add syntax highlighting for the "reasoning" output written to a chat log.
syn region LLMChatReasoningText start="\v^\#\=\>\>REASONING.*$"  end="\v^\#\<\<\=REASONING.*$"


" Link syntax groups to the appropriate highlight groups to use.
highlight link LLMChatOptionErrors Error
highlight link LLMChatDelimiters Keyword
highlight link LLMChatResources Include
highlight link LLMChatSeparators Delimiter
highlight link LLMChatOptionKeywords Identifier
highlight link LLMChatComments Comment
highlight link LLMChatEscapeSeqs Special
highlight link LLMChatReasoningText SpecialComment


