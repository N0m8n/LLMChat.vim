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
"
" The proper way to override a variable from this file is to declare such variable inside your ~/.vimrc file and then
" provide the value you would like to use there.  Such declarations should have a form like the following:
"
"   let <NAME> = <VALUE>
"
" Make sure to keep data types the same which means that if you see the value in this value wrapped within quote
" characters than you need to do the same in your own declaration; if you see the value declared without quotes than
" declare it the same in your override.
"
" As a concrete example of this, assume that we wish to override the "g:llmchat_default_server_type" variable so that
" it specifies "Open WebUI" by default.  To do this we would create a statement in the ~/.vimrc file that looks
" like the following:
"
"   let g:llmchat_default_server_type = "Open WebUI"
"
" Note that we surround the value in quote characters because we see that is the way that a default value was assigned
" to it within this file.
"

" -----------------------------------------------------

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


" This variable specifies the name of a "default" message register that should be used any time that a send chat event
" takes place.  A "message register" is a register in Vim that a copy of the latest LLM response should be written into
" once received during a chat interaction.  When such register is to be used than the value of this variable MUST be set
" to one of the following:
"
"   1). A lowecase letter (a-z)
"   2). An uppercase letter (A-Z)
"   3). " (which refers to the "unnamed" register)
"
" If no message register is to be used than this variable must have the empty string set as its value.  Note that any
" value set for this variable will be applied to *all* chat interactions run by the plugin (for chat-specific settings
" please refer to the help file for chat header option 'Message Register').
if ! exists("g:llmchat_default_message_register")
    let g:llmchat_default_message_register = ''
endif


" This variable specifies the maximum length of chat history to use as context when submitting new messages to the
" remote LLM.  A value of 0 or less indicates that ALL available chat history should be included on each chat request
" made.  A positive value of 1 more more indicates that only the specified number of message pairings (i.e., sets of
" user messages and assistant responses), beginning from the most recent and going backwards in the chat history,
" should be included.  Note that this setting does NOT impact the chat history being kept within the log file itself; it
" only effects the number of those messages that are included for context when new chats are sent to the LLM.
if ! exists("g:llmchat_max_context_messages")
    let g:llmchat_max_context_messages = 0
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


" This variable specifies what width (in terms of extra lines) to expect to be added to the vertical space consumption
" when windows are split horizontally.  Ultimately this value supplements the window height calculation logic which
" tries to figure out exactly how high (in text lines) that the full editor interface happens to be for the proper
" display of popup dialogs.  When you are using custom display elements, such as a status line, that will appear between
" windows which are horizontally split than you need to set the value of this variable to be equal to how many text
" lines that such display element takes up.  Note that this only needs to specify the space consumed between two
" windows as the space taken will be inferred for more than a single split (for example if you are using a custom
" status line that takes up 1 text row of space and appears each time that the window is horizontally split than you
" would just set this value to 1).
if ! exists("g:llmchat_h_disp_elem_aug_value")
    let g:llmchat_h_disp_elem_aug_value = 0
endif


" This variable adjusts the maximum allowed vertical size of popup dialogs created by this plugin and can help to fix
" incorrect display issues (for example if the bottom of a popup dialog falls below the bottom of the editor window).
" The value given is taken as a raw adjustment in terms of text lines so a negative value will shrink the popup
" window's maximum vertical size by the given amount and a positive value will increase the maximum vertical size
" allowed.
"
" Note that adjusting the maximum size for a popup window via this value does not effect your ability to see larger
" blocks of content nor does it force all popup windows that are displayed to suddenly become larger or smaller.  This
" specifically addresses the condition when a popup window will no longer grow vertically and will instead shift to
" allowing you to scroll through its content using the standard motion keys.
if ! exists("g:llmchat_h_win_adjust")
    let g:llmchat_h_win_adjust = 0
endif


" This variable allows for thousands separators to be inserted into the numbers displayed by popup dialogs in this
" plugin.  Currently the display only affects values seen to be integer types and will not format floating point
" values.  The character held by this variable will become the separator used for thousands marks within numbers so
" it may be adjusted to any desired separator.  Note that setting this variable to the empty string will disable the
" insertion of thousands separators and will cause integer values to be displayed as raw numbers.
if ! exists("g:llmchat_thousands_sep_char")
    let g:llmchat_thousands_sep_char = ','
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



" ================================================
" ====                                        ====
" ====  Internal Global Variable Definitions  ====
" ====                                        ====
" ================================================
"
" The variables in this section are considered "internal" from the perspective that plugin users should NOT be
" overriding them or directly setting them.  These variables will be controlled by commands or processes inside the
" plugin and are only declared global due to the nature of their use.


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


" This command is used to list the LLM models that are supported for use on the remote server.  When run, the command
" will execute a cURL call to query models from the server then it will display a listing of those models in a popup
" dialog.  You can navigate within the popup dialog by using the 'j' and 'k' keys (or arrow keys) and can use the
" 'x' key to exit the popup without making a selection.  Additionally you can press the '?' key while highlighting
" the display name for any model in order to see the detail information that was returned from the server for that
" model.  If you press the <Enter> or <Space> keys while in the model listing dialog than the identifier for that
" model, as recognized by the remote server, will be copied to the default, no-name register (i.e., register " just
" as content would be copied to if performing a yank operation).  This will allow you to easily paste the ID for the
" model anywhere you like; typically into the chat log document itself to finish configuring it for a chat session.
" If you would like the model ID placed in a register other than " you may pass the name of that register to this
" command when invoked; it supports the use of any of the standard user registers identified by the letters A-Z and
" a-z.
"
" Note that when run this command (1) must be run while a chat log is the active document and (2) such chat log must
" have, at minimum, the server type and server URL options fully filled in as both will be required to query for the
" model listing.
"
" Examples:
"    :ListChatModels     <== Query for and show LLM models available; place any selection name in the " register.
"    :ListChatModels a   <== Query for and show LLM models available; place any selection name into register 'a'.
"
command -nargs=? ListChatModels call LLMChat#get_models#FetchModels(<f-args>)


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

