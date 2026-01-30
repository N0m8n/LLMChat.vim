" This script file defines all assets that should be loaded by Vim on startup for using the LLMChat plugin.  In general
" this includes command definitions and global variables that users can override to control various behaviors of the
" plugin.  Code controlling specific actions to be taken by the plugin will be pulled from autoloaded scripts as needed
" during runtime.

" =======================================
" ====                               ====
" ====  Global Variable Definitions  ====
" ====                               ====
" =======================================
"
" This section contains the global variable definitions used by the plugin.  These variables are generally employed to
" control various behaviors and may be (or in some cases *MUST BE*) overridden by users for customization.  See the
" comments above each variable block for a summary of what the variable is used to control.  Note that the variables
" declared here contain default values which may or may not be suitable for use depending on their nature; variable
" setting will also always defer to existing values such that variables are ONLY set if no value for such variable has
" been defined yet.


" This variable defines the default for the "type" of server that we will be interacting through in order to converse
" with an LLM.  Currently two options exist that can be used:
"
"    "Ollama" - This value specifies that we will be interacting with the API provided by an Ollama server
"               (https://ollama.com/)
"
"    "Open WebUI" - This value specifies that we will be interacting with the API provided by an Open WebUI server
"                   (https://docs.openwebui.com/)
"
if ! exists("g:llmchat_default_server_type")
    let g:llmchat_default_server_type = "Ollama"
endif


" This variable defines the default base URL that will be used in order to interact with the server hosting the LLM.
" The default provided here matches to the default URL used to access a locally hosted Ollama server.
if ! exists("g:llmchat_default_server_url")
    let g:llmchat_default_server_url = "http://localhost:11434"
endif


" This variable specifies the value to be used for the model ID in any chat by default.  Note that when set to the
" empty string than no model ID information will be populated when a new chat is started.
if ! exists("g:llmchat_default_model_id")
    let g:llmchat_default_model_id = ''
endif


" This variable specifies the value to be used for any system prompt that should be defaulted to if a specific prompt
" is not defined within a chat.  Note that when set to the empty string than no system prompt will be used unless
" specifically set within the chat header information.
if ! exists("g:llmchat_default_system_prompt")
    let g:llmchat_default_system_prompt = ''
endif


" This variable specifies the path to a local file whose content should be used as an API key.  It can be defined any
" time that (1) the server hosting the LLM requires authentication and (2) you don't want to set this up on a per-chat
" basis.  Be aware that currently the referenced file must be in plain text so this option should not be considered
" secure.
"
" When this variable has been set to the empty string than no API key will be loaded for use by default and API requests
" will be made without any authentication (note that this behavior can still be overridden on a per-chat basis).
if ! exists("g:llmchat_apikey_file")
    let g:llmchat_apikey_file = ""
endif


" This variable specifies whether or not a new, empty chat that is opened by the plugin should automatically set the
" mode to insert.  In general it is expected that this is the most user friendly thing to do so that the user can
" immediately begin typing messages.  Some users, however, may have trouble adjusting to the sudden switch in mode and
" can disable this behavior if it is unwanted.  Defining this variable to have a value of 1 enables t" mode switching
" and setting the value to 0 disables it.
if ! exists("g:llmchat_open_new_chats_in_insert_mode")
    let g:llmchat_open_new_chats_in_insert_mode = 1
endif


" This variable specifies whether or not new, empty chats that are initialized by the plugin should be displayed as
" "fully expanded".  When this variable has been given a value of 1 than a new chat log will be shown with all
" folds fully expanded so that the entire template content for the new chat can be easily seen.  When this variable
" has been given a value of 0 than a new chat log will be shown with all folds fully closed.
"
" For new users it is useful to leave this value set to its default so that help information about the chat log and
" its structure can be seen directly in the document itself.  Familiar users may dislike the display of so much
" information that they are already familiar with and may prefer to start new documents will all of this hidden.
if ! exists("g:llmchat_fully_expand_new_chats")
    let g:llmchat_fully_expand_new_chats = 1
endif


" This variable specifies what type of split should be opened when the ":NewChat" command is executed.  Possible
" values are enumerated below:
"
"   horizontal - Open a horizontal split for new chats
"   vertical - Open a new vertical split for new chats
"
if ! exists("g:llmchat_chat_split_type")
    let g:llmchat_chat_split_type = "horizontal"
endif


" This variable specifies how long (in terms of total characters) to make the division bar placed between the chat
" header and the main chat document body (i.e., the "* ENDSETUP *" line).  Note that values below 12 will be ignored
" and such line will be output exactly as "* ENDSETUP *" (smaller sizes cannot be accomodated without truncating the
" minimum line token itself).  Sizes larger than 12 will be accomdated by adding '*' characters to the front and back
" of the token until the total line size specified is taken.
if ! exists("g:llmchat_header_sep_size")
    let g:llmchat_header_sep_size = 28
endif


" This variable specifies how long (in terms of total characters) to make the division bars placed between each chat
" interactions (i.e, sequences of "-" ).  Values of 1 or greater will result in the output of separator bars having
" the specified length whereas values of 0 or less will cause no separator bars to be output.
"
if ! exists("g:llmchat_separator_bar_size")
    let g:llmchat_separator_bar_size = 28
endif


" This variable specifies the style to be used when writing received assistant messages into the chat buffer.  When
" given a value of 1 than the start of an assistant message will begin on the same line as the opening chat delmiter and
" when given a value of 0 the start of the message will be pushed to the line under the opening delimiter.
"
" Graphically this looks like the following:
"
"    *When set to 0:
"
"         =>>
"         Start of assistant message.
"
"    *When set to 1:
"
"         =>> Start of assistant message.
"
" Note that this setting only controls how the assistant message follows the chat start delmiter; the ending delimiter
" must still always appear by itself to ensure proper parsing recognition.
if ! exists("g:llmchat_assistant_message_follow_style")
    let g:llmchat_assistant_message_follow_style = 0
endif


" This variable specifies whether or not to use "streaming" mode when interacting with the remote LLM server.  Streaming
" essentially returns back fragments of a response that need to be stitched back together before the response message
" can be written to the chat buffer.  Non-streaming mode provides back a single, complete response that is almost
" always significantly smaller in size than the same response data when streaming.  Since this plugin cannot currently
" participate in an HTTP interaction it generally makes sense to use non-streaming mode as all data in either mode
" will need to be fully written out by cURL before we can start processing it.
"
" Why have this as an option if using streaming mode provides no advantage?  Unfortunately in testing it was found that
" some LLM server release versions do not work as expected in non-streaming mode and may return back empty responses
" (this was, for example, seen when testing against Ollama version 0.12.6 and using specific models).  For such cases,
" where only streaming mode is available (..or works..) than this provides a work around option when interacting with
" the server.
"
" To enable streaming mode set the value of this variable to 1 and to disable such mode set the value to 0.  Note that
" if a server does not support both streaming and non-streaming modes than the setting will be ignored and the logic
" will use whatever mode is appropriate for interactions.
if ! exists("g:llmchat_use_streaming_mode")
    let g:llmchat_use_streaming_mode = 0
endif


" This variable specifies whether or not to use the custom folding feature that has been defined by this plugin for
" chat log files.  When set to a value of 1 than custom folding will be enabled (the default) and if set to 0 than
" folding will be disabled.
if ! exists("g:llmchat_use_chat_folding")
    let g:llmchat_use_chat_folding = 1
endif


" This variable holds a string detailing any "additional" settings or flags that should be passed to the cURL commands
" run by this plugin.  Ultimately this provides a means by which to pass things like timeout settings, retries,
" certificate handling, etc, that may be relevant to the interactions you need to perform.  By default the variable is
" initialized to the empty string which will add nothing to the cURL command; when set to a non-empty value the
" value will be added, *verbatim*, to the curl command arguments.
if ! exists("g:llmchat_curl_extra_args")
    let g:llmchat_curl_extra_args = ''
endif


" This variable specifies the "target" for debug mode to use.  A target can either be (1) a buffer or (2) a file and
" defines where debug information output from the plugin will be written.  When targeting a buffer the value provided
" for this variable must have the form "@N" when 'N' is the number of an open buffer in the editor.  When targeting
" a file than this variable must be set to the path of the file that content should be written to.  Note that in file
" mode content is always appended so it is the user's responsibility to decide when and if the debug file content
" should be cleaned up.
"
" If this variable is set to the empty string (the default) than debug mode will be disabled.
if ! exists("g:llmchat_debug_mode_target")
    let g:llmchat_debug_mode_target = ''
endif


" ===============================
" ====                       ====
" ====  Command Definitions  ====
" ====                       ====
" ===============================
"
" This section contains the command definitions provided by this plugin; see the comments above each for a brief summary
" of what the command does.


" This statement defines a new command ('NewChat') that will allow a user to open a new chat window as either a
" vertical or horizontal split (depending on the value set for variable 'g:llmchat_chat_split_type' when the command is
" invoked).  An optional filepath argument may be passed to the command which will have the following effect:
"
"   No Filepath Given - In this case the command will open a new, default chat window that has no associated file path
"                       on disk.  Should the user choose to save the content of this chat they will need to provide a
"                       path to the 'w' command on save.
"
"   Non-Existant Path Given - In this case a new, empty chat window will be opened but the content of such window is
"                             already associated with the path on disk at which it would be saved.
"
"   Existing Path Given - In this case the content of the specified window will be loaded into the newly created chat
"                         window split.
"
" Examples:
"   :NewChat                 [Opens a new split in the editor and loads a default chat template for use into the split.]
"   :NewChat /path/to/file   [Opens a new split whose content will be the content from the given file path.]
"
command -nargs=? -complete=file NewChat call LLMChat#new_chat#OpenNewChatSplit(<f-args>)


" This statement defines a new command ('SendChat') that triggers a "chat interaction" (i.e., the submission of a chat
" message to a remote LLM server and the receipt of a response) from the content of a chat log document.  Note that
" the command requires no arguments and must be executed with the window holding the chat log as active.
command -nargs=0 SendChat call LLMChat#send_chat#InitiateChatInteraction()


" This is a convenience command that will set a buffer-local variable with the authorization token that should be
" used for LLM interactions initiated by the chat held by that buffer.  Note that any authorization token set will
" ONLY be accessible from the chat held by the active buffer when this command was run (no other loaded chat will be
" able to source or use such token).  Additionally the set token will only be available in the current Vim runtime
" unless using plugins that will persist the state of buffer local variables.  Note that multiple invocations of this
" command will result in the value of the buffer-local variable being set to the token provided on the last invocation
" made (token values given to previous command invocations will be overwritten with only the value given to the most
" recent command execution being retained).
"
" When invoked this command must be given a single argument that is the authorization token to be used.
"
" Examples:
"   :SetAuthToken  abc123    [Sets the token to use as 'abc123'; for requests this will be embedded as a bearer token
"                             value (e.g., "Authorization: Bearer abc123')]
"
command -nargs=1 SetAuthToken execute "let b:llmchat_auth_token='<args>' | echo 'Buffer-local token set!'"


" This command can be used to abort a running chat submission (i.e., an open interaction with a remote LLM server
" initiated via the 'SendChat' command) and to cleanup after the abort has completed.  Execution of this command
" effectively cancels off the cURL call that was being used to perform the chat submission then performs cleanup so
" that a new chat submission can be requested.  This can be useful in siutations where an unexpectedly large model was
" loaded and the LLM server is taking an unreasonable amount of time to respond.  Rather than being blocked from
" submitting any new chat requests until the remote server finally replies you can abort the submission with this
" command then configure the use of a smaller model before trying again.
command -nargs=0 AbortChatExec call LLMChat#send_chat#AbortRunningChatExec()


" This is a convenience command for setting the debug target to be used by this plugin.  The "target" is the
" destination to which debug output will be sent and can be any of the following:
"
"   <NONE> - When no debug target is set (for instance by running this command with no arguments) than debug mode
"            will be disabled and no messages will be output.
"
"   Buffer - When the argument given to this command is a String having the form "@N", where "N" is the numeric ID of
"            an available buffer, than debug output will be written to the end of the specified buffer when produced.
"
"   File - When the argument given to this command is a non-empty String whose form is NOT "@N" then the value will be
"          intepreted as a file path.  Any debug output produced will then be appended to the end of the file at
"          the specified path.
"
" This command can be invoked at any time and will switch the debug target currently in use.
command -nargs=? -complete=file SetDebugTarget execute "let g:llmchat_debug_mode_target='<args>' | " ..
                                                     \ "echo ('<args>' == '' ? \"Debug disabled\" : \"Debug Enabled\")"



" =====================
" ====             ====
" ====  Functions  ====
" ====             ====
" =====================

" This section contains a small subset of functions that should always be loaded when Vim starts.  Note that the
" majority of functions should be pushed out to either (1) autoload scripts or (2) vim9script library files in order
" to not effect the Vim startup time and to avoid unnecessarily cluttering memory with things that aren't immediately
" needed.


" This function provides the basis for a custom folding method appropriate to chat log files.  In its current
" implementation the function will create folds according to the following rules:
"
"   1). The first line of all comment blocks (i.e., sequences of 2 or more consecutive comment lines) can be rolled
"       up into a single fold.
"
"   2). All message exchanges (i.e., pairings of user messages and their assistant responses) can be rolled up into
"       a single fold.
"
"   3). Within any message exchange the assistant message can be rolled up into its own fold as well (so a second
"       level fold within the message exhange fold).
"
" On invocation the operation of this function will attempt to determine what "fold level" to assign the line whose
" number has been provided as argument "line_num".  The method will then return a resolved "fold level" for the line
" that adheres to the level types as specified in help section 'fold-expr'.
"
" In order to use this function for folding the following must be set in Vim for a buffer containing a chat log file:
"
"   setlocal foldmethod=expr
"   setlocal foldexpr=LLMChatFolding(v:lnum)
"
" Arguments:
"   line_num - The line number that this function should determine the fold level for.
"
" Returns: A string value representing the "fold level" for the line as per the accepted fold levels documented in
"          help section 'fold-expr'.
"
function! LLMChatFolding(line_num)
    " Fetch the text from the 'line_num' given and then determine what folding level should be assigned.
    let l:line_text = getline(a:line_num)

    " Assume that we want to return "-1" (intentially forced to be a string) by default as this will be the majority
    " case for most lines in the file.  Essentially this tells Vim to look at the fold level for the line above or below
    " the current line and assign whichever value is smaller.  For more details see 'help fold-expr'.
    let l:fold_level = "-1"


    " Now setup fold levels so that the following goals are met:
    "
    "   1). First level folds should roll up comments and individual chat exchanges (i.e., separate pairings of
    "       user/assistant messages).
    "
    "   2). Second level folds should roll up assistant messages only.
    "
    " Note that for chat messages we want to expose the first line of the actual message text in the fold rollup so
    " that there is some reference as to what the message was.  This can be a bit tricky since users can format their
    " chats according to their own preference and may even change the chat log content to be contradictory to some
    " global settings like 'g:llmchat_assistant_message_follow_style'.
    "
    " To meet this goal we will therefore check for text that follows the opening message delimiter (both for user and
    " assistant messages) and, if found, we will set the line we found this in as the start of the fold.  If we don't
    " see any characters (other than whitespace) follow the delimiter than we will set the next line down as the start
    " of the fold.
    "
    " Note that this scheme isn't perfect and some users could include multiple lines of whitespace between the
    " opening delimiter and the start of their actual message.  For now we're not worried about this case as we expect
    " most users to either start their message immediately after the delmiter or on the line under it.
    "
    if l:line_text =~ '\v^\>\>\>\s*\S+(.)*'
        " In this case we found the opening delimiter for a user message AND such delimiter was followed by at least
        " one non-whitespace character.  Assume that this should be the start of a fold and update the value held by
        " variable 'l:fold_level' accordingly.
        let l:fold_level = ">1"

    elseif a:line_num > 1 && getline(a:line_num - 1) =~ '\v^\>\>\>\s*$'
        " In this case we found a line that was immediately preceeded by a line containing ONLY the opening delimiter
        " for a user message (and possibly some trailing whitespace); for such a case assume that the current line
        " should open a fold and update variable 'l:fold_level' accordingly.
        let l:fold_level = ">1"

    elseif l:line_text =~ '\v^\=\>\>\s*\S+(.)*'
        " In this case we found the opening delimiter for an assistant message AND such delmiter was followed by at
        " least one non-whitespace character.  Assume that this should be the start of a fold and update the value held
        " by variable 'l:fold_level' accordingly.
        let l:fold_level = ">2"

    elseif a:line_num > 1 && getline(a:line_num -1) =~ '\v^\=\>\>\s*$'
        " In this case we found a line that was immediately preceeded by a line containing ONLY the opening delimiter
        " for an assistant message (and possibly some trailing whitespace); for such a case assume that the current
        " line should open a fold and update variable 'l:fold_level' accordingly.
        let l:fold_level = ">2"

    elseif getline(a:line_num + 1) =~ '\v^\<\<\=(.)*'
        " In this case we encountered a line whose next line closes out an assistant message; go ahead and close out
        " the second level fold as the next line will need to close out the first level fold.
        let l:fold_level = "<2"

    elseif l:line_text =~ '\v^\<\<\=\s*'
        " We have found a line that contains the assistant message closing delimiter so close out the first level
        " fold.
        let l:fold_level = "<1"

    elseif l:line_text =~ '\v\s*\*+ ENDSETUP \*+\s*'
        " Always mark the delimiter line between the header and body portions of the document as fold level 0.
        let l:fold_level = "0"

    elseif l:line_text =~ '\v\s*\#(.)*'
        " If the logic comes here than we've found a comment line.  To properly process comments we need to determine
        " a few things like:
        "
        "   * Is this just a single comment line or part of a block?
        "   * If part of a block is this comment line the start?  the end?  somewhere in the middle?
        "
        " Thankfully all of these questions can be asked fairly simply inside some if conditions provided we know the
        " following:
        "
        "   1). Does the current comment line have a previous comment line above it?
        "   2). Does the current comment line have another comment line below it?
        "
        " Create some variables that will store the answers to these questions as Vimscript booleans before proceeding
        " further (where Vimscript uses 0 to mean 'false' and anything else to mean 'true')
        let l:prior_line = a:line_num - 1
        let l:next_line = a:line_num + 1

        let l:has_above_comment = l:prior_line > 0 && getline(l:prior_line) =~ '\v\s*\#(.)*' ? 1 : 0
        let l:has_below_comment = getline(l:next_line) =~ '\v\s*\#(.)*' ? 1 : 0


        " Now determine the folding level based on whether the current line was preceeded by a comment and if it has
        " a comment following it.  The goal is to have the following as as result:
        "
        "   1). Single line comments should be left defaulted to "-1".
        "   2). Comment blocks (i.e., two or more comment lines together) should have the first line of the block
        "       marked as the fold start and the last line of the block marked as the fold end.  All lines in between
        "       the start and end should be given a fold level of 1.
        "
        if ! l:has_above_comment && l:has_below_comment
            let l:fold_level = ">1"

        elseif l:has_above_comment && ! l:has_below_comment
            let l:fold_level = "<1"

        elseif l:has_above_comment && l:has_below_comment
            let l:fold_level = 1

        endif

    endif


    "Return the resolved fold level back to the caller.
    return l:fold_level

endfunction

