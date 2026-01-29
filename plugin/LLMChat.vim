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
" given a value of 1 than the start of a message will be pushed to the line after the opening chat delimiter and when
" set to 0 than the start of a message will come immediately after the opening delimiter.
"
" Graphically this looks like the following:
"
"    *When set to 1:
"
"         =>>
"         Start of assistant message.
"
"    *When set to 0:
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

