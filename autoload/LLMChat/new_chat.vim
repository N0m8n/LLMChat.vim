" This file contains the logic needed to create new chat buffers via custom commands defined in the main plugin
" script.


" ================================
" ====                        ====
" ====  Function Definitions  ====
" ====                        ====
" ================================

" This function is responsible for opening a new split (either vertically or horizontally depending on the value held
" by global variable 'g:llmchat_chat_split_type') that can be used as a new chat window.  Additionally the function
" can accept an optional 'file_path' argument that will have the following effect on its behavior:
"
"   No 'file_path' Given or Provided as the Empty String - In this case the split that is opened will be a new, default
"                                                          chat window that is not associated with any save location on
"       disk.  If the user chooses to save the content of such a split they will need to provide the path directly to
"       the 'w' command when the window content is saved.  This mode of operation is best for a temporary chat interface
"       that the user has no intention of saving and which they intend to discard when finished.
"
"   Non-Existant Path Given - In this case the new split will open as a new, default chat window but will already
"                             be associated with a save location on disk.  This mode of operation is most appropriate
"       for creating a new chat dialog that the user intends to retain over time.
"
"   Existing Path Given - In this case the new split will open and be populated with the content current held by the
"                         provided file.  This case is most appropriate when a user would like to open an existing
"       chat in order to resume the dialog.  Note that a user can also do this by simply opening a file that has been
"       saved with the proper extension or by issuing a split command that will open such file as well.  This is
"       therefore just a convenience mode that rounds out the operation of this function when it is called from the
"       plugin commands.
"
" NOTE: Realisitically, after refactoring, the function provided here is pretty shallow and maybe should be removed?
"       Originally this setup a split and initialized the split to a default chat log which was definitely unique
"       functionality.  However, we wanted ANY EMPTY buffer to be initializable regardless of how it was opened so the
"       logic to do this was moved to its own function and the trigger for it was moved to an 'ftplugin' file.  This
"       means that opening a new split with the "split" or "vsplit" commands and the setting the filetype has the same
"       effect as this function.  Perhaps that could just be condensed into the command definition itself?  There is
"       still the fact that you can decide what type of split you want and the command calling this function will open
"       that type of split on each call... again maybe something that can just be consolidated into the command
"       definition found in the main plugin file?  Not critical as a refactor but something to think about.
"
" Arguments:
" -----------
"  file_path - (Optional) The path to an existing or non-existing file that should be associated with the newly opened
"              chat window.  See the discussion above for details on how the value given effects the function's
"              operation.
"
" Returns: None
"
function LLMChat#new_chat#OpenNewChatSplit(file_path="")
    "NOTE: Explicitly use case insensitive matching for checking what split type that the user perfers.  There is no
    "      logical reason why we need to fail if 'HORIZONTAL' was given, for instance, rather than 'horizontal'; the
    "      meaningful portion of the value (the word) is the same and this is honestly enough.
    if g:llmchat_chat_split_type ==? "horizontal"
        " In this case the user preference is to use horizontal splits for new chats; now we need to check to see if
        " a non-empty 'file_path' was provided so we can resolve whether to use 'split' or 'new' to open up the new
        " split.
        if a:file_path == ""
            let l:split_operator = 'new'
        else
            let l:split_operator = 'split'
        endif

    elseif g:llmchat_chat_split_type ==? "vertical"
        " In this case the user preference is to use vertical splits for new chats; now we need to check to see if a
        " non-empty 'file_path' was provided so we can resolve whether to use 'vsplit' or 'vnew' to open up the new
        " split.
        if a:file_path == ""
            let l:split_operator = 'vnew'
        else
            let l:split_operator = 'vsplit'
        endif

    else
        " In this case the 'g:llmchat_chat_split_type' variable held an invalid value.  Output an error message to the
        " user regarding the fault and take no action.
        echom "ERROR: The value currently held by variable 'g:llmchat_chat_split_type' is invalid; this must be " ..
            \ "set to one of the following values: 'horizontal', 'vertical'.  The current value found was: '" ..
            \ g:llmchat_chat_split_type .. "'"
        return
    endif

    " Form up a command that we will run via the 'execute' command to create the split.  Note that we build this up as
    " a string to avoid deeply nested conditional statements that each take separate actions.
    let l:split_create_cmd = l:split_operator


    " If  a 'file_path' was given to this function then add it as an argument to the split creation command.
    if a:file_path != ""
        let l:split_create_cmd = l:split_create_cmd .. ' ' .. a:file_path
    endif


    " Now use the 'execute' command to create the requested split and to move our focus to such split.  Note that the
    " commands which follow assume we are in the context of the new buffer that is loaded into the split.
    execute l:split_create_cmd


    " Always set the 'filetype' in the new split to 'chtlg'.  This will happen automatically in some cases (for instance
    " if a 'file_path' is given whose file ends with the extension '.chtlg') but for others it won't.  In any event the
    " new chat window should ALWAYS have this filetype assigned so there is no harm in doing it directly.
    "
    " NOTE: Do NOT attempt to initialize the new split here even if it is empty; this will happen automatically when
    "       the 'chtlg.vim' script is called from the 'ftplugin' directory.  By doing this from a file type plugin
    " script (which will run anytime that the filetype has been set to 'chtlg') we don't need to worry about whether the
    " new buffer was opened using this function, opened using the 'split' command, opened with ":e", etc; it will all
    " end up getting handled the same.  The important thing is that the 'filetype' get set properly which is that is
    " handled here.
    set filetype=chtlg

endfunction


" This function is responsible for setting up an empty chat buffer with the basic structure for a valid chat log.  It
" also positions the cursor in the buffer to be at the end of the first user message delimiter (within the chat document
" body) and switches the mode to insert so that a user can immediately begin typing messages.  Note that invocations
" of this function assume that the currently selected buffer is the buffer to be operated on.
"
" If the active buffer is found to be non-empty than no actions will be taken by this function and it will simply exit.
"
" Returns: None.
"
function LLMChat#new_chat#InitializeChatBuffer()
    " Check to see if the currently active buffer is empty; if not than we will take no action and will quietly exit.
    " If the buffer IS completely empty than we will initialize it to contain the basic structure for a new chat log.
    if line('$') == 1 && getline(1) == ''
        " In this case the buffer was found to hold a single line and the content of that line was equal to the empty
        " string; assume the buffer is empty and move forward with populating it to have a basic chat log file.
        let l:init_text = "#" ..
                      \ "\n# BEGIN CHAT LOG HEADER SECTION..." ..
                      \ "\n#" ..
                      \ "\n" ..
                      \ "\nServer Type: " .. g:llmchat_default_server_type ..
                      \ "\nServer URL: " .. g:llmchat_default_server_url

        " Define some variables that control stateful actions during generation of the default chat document content.  A
        " brief summary of what these variables do is given below:
        "
        "  l:show_system_prompt_in_comment  - This controls whether or not we show a message in the comments at the
        "                                     bottom of the header regarding the system prompt.  Essentially if an
        "                                     actual system prompt is output to the document (because a default prompt
        "                                     was configured) than there is no need to show this to the user as a
        "                                     possible option later.  1 means we will show the comment and 0 means we'll
        "                                     turn if off because a real system prompt was written instead.
        "
        "  l:position_cursor_at_end - If the default chat document we create is fully complete than we want to position
        "                             the cursor at the very end of first user message delimiter so that the chat is
        "                             ready to use.  However, if we're missing a required value, such as the Model ID,
        "                             than we want to position the cursor on that line instead so that the user
        "                             understands they need to give a value before they can start chatting.  A value of
        "                             1 means position the cursor so the user is ready to chat and a 0 means position
        "                             the cursor at the first required value the user needs to fill in BEFORE they
        "                             can chat.
        "
        let l:show_system_prompt_in_comment = 1
        let l:position_cursor_at_end = 1


        " Check to see if a default model ID has been specified for use and if so embed this into the header data for
        " the new chat document.  If no default model ID has been given than output a message indicating the user must
        " fill this in manually within the chat header.
        "
        "NOTE: If no default model ID is available than we want to set 'let l:position_cursor_at_end' to 0 so that we
        "      instead position the cursor at the end of the 'Model ID:' declaration line.
        "
        if exists("g:llmchat_default_model_id") && g:llmchat_default_model_id != ''
            let l:init_text = l:init_text .. "\nModel ID: " .. g:llmchat_default_model_id
        else
            let l:init_text = l:init_text .. "\nModel ID: <REQUIRED - Please Fill In>"
            let l:position_cursor_at_end = 0
        endif


        " If the "apikey file" variable was set to a non-empty value than we assume (by default) that auth should be
        " used on the requests; othewise we assume that authentation is not required (again by default for our template
        " output).
        if exists("g:llmchat_apikey_file") && strlen(g:llmchat_apikey_file) > 0
            let l:init_text = l:init_text .. "\nUse Auth Token: true"
        else
            let l:init_text = l:init_text .. "\nUse Auth Token: false"
        endif


        " If the 'g:llmchat_default_system_prompt' variable was set than output the value it holds for the
        " 'System Prompt' header declaration.
        if exists("g:llmchat_default_system_prompt") && g:llmchat_default_system_prompt != ""
            " In this case a default system prompt was available so go ahead and add this to the template information
            " we will be outputting.  Make sure to include a full empty line below it as this is a requirement for
            " parsing.
            let l:init_text = l:init_text .. "\nSystem Prompt: " .. g:llmchat_default_system_prompt .. "\n\n"

            " Make sure to set the 'l:show_system_prompt_in_comment' to 0 so we turn off displaying the system prompt
            " comment in the 'Additionals..' comment section.
            let l:show_system_prompt_in_comment = 0

        endif

        let l:init_text = l:init_text ..
            \ "\n" ..
            \ "\n#" ..
            \ "\n# Additional, but optional, header declarations:" ..
            \ "\n#"

        if l:show_system_prompt_in_comment
            let l:init_text = l:init_text ..
                \ "\n### The system prompt to be used during the chat.  Note that this option may contain a value" ..
                \ "\n### which spans multiple lines and for this reason the option declaration MUST be followed by" ..
                \ "\n### an empty line to serve as the option's ending delmiter." ..
                \ "\n#System Prompt: <PROMPT> " ..
                \ "\n#" ..
                \ "\n#"
        endif

        let l:init_text = l:init_text ..
            \ "\n### The authentication token to use specifically for this chat; overrides any global token given" ..
            \ "\n### by variable 'g:llmchat_apikey_file' or any token set local to the chat buffer.  Obviously this" ..
            \ "\n### option embeds the token within the chat log content so is very insecure; use with discression." ..
            \ "\n#Auth Token: <TOKEN>" ..
            \ "\n#" ..
            \ "\n#" ..
            \ "\n### Sets a an option on the model to be used for the chat; typically this is someting like the" ..
            \ "\n### thinking behavior, model temperature, etc.  For a full list of available options see the" ..
            \ "\n### API documentation for the chat completion endpoint on the LLM server you will be interacting" ..
            \ "\n### with.  NOTE THAT THE ENTIRE DECLARATION NEEDS TO FIT ONTO THE SAME LINE FOR PROPER PARSING." ..
            \ "\n### This declaration can be provided more than once in the header section of a chat log when more" ..
            \ "\n### than one option should be set." ..
            \ "\n#Option: name=value" ..
            \ "\n#" ..
            \ "\n" ..
            \ "\n" ..
            \ s:new_chat_header_separator ..
            \ "\n" ..
            \ "\n#" ..
            \ "\n# BEGIN CHAT LOG BODY SECTION..." ..
            \ "\n#" ..
            \ "\n# === Basic Instructions ===" ..
            \ "\n#" ..
            \ "\n#  Chat Constructs:" ..
            \ "\n#     >>>  Begins a user message to the LLM; may be followed immediately by message text or may." ..
            \ "\n#            appear by itself with message text starting on subsquent lines." ..
            \ "\n#     <<<  Ends a user message block; MUST APPEAR ON ITS OWN LINE WITH NO FOLLOWING TEXT!!!" ..
            \ "\n#     =>>  Begins an assistant response to the last user message entered; may be followed" ..
            \ "\n#            immediately by message text or the message may start on subsequent lines." ..
            \ "\n#     <<=  Ends an assistant message block; MUST APPEAR ON ITS OWN LINE WITH NO FOLLOWING TEXT!!!" ..
            \ "\n#" ..
            \ "\n#  Rules:" ..
            \ "\n#    (1) Messages MUST come in pairs with a user message coming first and an assistant message" ..
            \ "\n#        begin added after a chat interaction is prompted." ..
            \ "\n#    (2) User chats MUST begin with the '>>>' sequence but the ending '<<<' sequence is optional" ..
            \ "\n#        on the last typed chat IF there is no assistant response yet (i.e., if the chat has not" ..
            \ "\n#        yet been sent to the LLM).  Note that such sequence will be filled in automatically if" ..
            \ "\n#        missing once the assistant response is written to the buffer." ..
            \ "\n#" ..
            \ "\n#  See \":help LLMChat\" for full help information" ..
            \ "\n#" ..
            \ "\n" ..
            \ "\n" ..
            \ ">>>"


        " Use 'put!' to avoid placing a newline at the top of the buffer; note that this will have consequences later as
        " it will end up shifting the newline to the end of the file and we'll need to address it when changing the
        " cursor position.
        silent put! = l:init_text


        " Finally move the cursort to the appropriate place in the document; either to the opening of the first user
        " message (if variable 'let l:position_cursor_at_end' was still set to 1) or at the model ID declaration line
        " (if variable 'let l:position_cursor_at_end' was 0).
        if l:position_cursor_at_end
            " In this case we want to move the cursor to the end of the '>>>' sequence on the last line and (optionally)
            " set the buffer to insert mode so that the user is immediately ready to begin typing a message.  Note that
            " because of the 'put!' command executed earlier we will have an unwanted empty line at the bottom of the
            " buffer we need to remove as well.
            "
            "NOTES: To achive what we want here we will take the following actions:
            "
            "         1). Use the 'normal' command to execute the 'G' command mapping (this will move us to the last
            "             line in the buffer), the 'k' command mapping (which will take us up one line above the
            "             bottom), and the 'J' command mapping (which will "join" the empty line at the bottom of the
            "             buffer to the line containing the '>>>' sequence that we want the cursor on).
            "
            "         2). Execute the 'startinsert!' command which (when the '!' is given at the end) behaves as if we
            "             pressed 'A' in insert mode (e.g., performs and "append" operation at the end of the current
            "             line which switches us to insert mode AND moves our cursor where we want it).
            "
            "      Why not just run "normal! GkJA" instead?  It turns out (based on the help information for "normal")
            "      that any command you give to the normal command must be "completed" or it will be ignored.  Switching
            "      to insert mode does not seem to count as a completed command unless you finish your insert and switch
            "      back to normal mode.  Since we want to remain in insert mode we need to use the 'startinsert' command
            "      instead.
            "
            "      ...this note is a bit dated now since the code below has been enhanced to allow the mode switch to be
            "      controlled as a preference (so obviously we wouldn't try to combine the two commands now even if we
            "      could); however, the information in the note is still useful so leaving it alone for now.
            "
            normal! GkJ

            if g:llmchat_open_new_chats_in_insert_mode
                silent! startinsert!
            endif

        else
            " In this case we want to move the cursor to the 'Model ID' line and position it at the end but we also
            " need to address the empty line at the bottom of the file that was introduced with the put command.  To
            " Take care of this we will do the following:
            "
            "  1). Use the 'normal' command to execute 'G' (go to the bottom of the file), 'k' (go up one one),
            "      'J' (to join the "empty" line at the bottom to the line above it containing the '>>>' sequence; this
            "      effectively removes the empty line from the document) then 'gg' to go back up to the top of the
            "      document.
            "
            "  2). Now use the "execute" command to run a second normal command that will search for the 'Model ID'
            "      line and then position our cursor at the end of it.  Note that we use a normal command that is run
            "      from an execute command because (1) the 'normal' command can't interpret special character sequences
            "      like <cr> and (2) we need such a sequence to execute the search.
            "
            " Note that in this case we also won't shift the mode to insert as it isn't clear that is the right thing
            " to do.  We will instead leave the user in normal mode so that they can begin whatever editing action they
            " like to correct the model ID information in the chat.
            normal! GkJgg
            silent execute "normal! /\\v^Model ID\:\<cr>$"

        endif

    endif

endfunction


" This function computes and returns the "separator bar" that should be placed between the header section of a chat log
" document and its body.  During parsing this bar will be searched for and is used to divide the document up for further
" processing.  Note that such bar must be computed at runtime as its final size is configurable via the global
" variable declarations provided by this plugin.
"
" Returns: The separator bar to be used for delmiting the header section of a chat log from its body.
"
function LLMChat#new_chat#GetHeaderSeparatorBar()

    " Define a local variable that will hold the smallest size separator token we can work with.
    let l:separator_bar = "* ENDSETUP *"

    " Now loop using a counter that will walk the difference between the size of the 'l:separator_bar' and the
    " size given by variable 'g:llmchat_separator_bar_size'.  For each difference in size we will alternately add a
    " '*' to the front and then the back of the 'l:separator_bar' value.  Note that if 'l:separator_bar' already has
    " a size larger than that of the 'g:llmchat_separator_bar_size' than no size augmentation will take place.
    let l:append_loc = 0
    let l:separator_size = strlen(l:separator_bar)

    while l:separator_size < g:llmchat_separator_bar_size
        " If 'l:append_loc' is 0 than we will append an '*' to the front of the separator bar value; otherwise we
        " will append the '*' to the back.  Note that after appending the '*' we will flip the value of 'l:append_loc'
        " so that we append to the opposite side of the separator bar value on the next loop.
        if l:append_loc == 0
            let l:separator_bar = '*' .. l:separator_bar
            let l:append_loc = 1
        else
            let l:separator_bar = l:separator_bar .. '*'
            let l:append_loc = 0
        endif

        " Increment the 'l:separator_size' by 1 before the next loop to account for the added character.
        let l:separator_size = l:separator_size + 1

    endwhile

    " Return the fully assembled header separator bar back to the caller.
    return l:separator_bar

endfunction



" ============================
" ====                    ====
" ====  Main Script Logic ====
" ====                    ====
" ============================
"
" The following logic should run any time that this file is sourced by Vim and is typically used for initialization,
" optimization actions, or common values within the script.


" Pre-compute the "ENDSETUP" bar that will be used as the delimiter between the "head" and "body" sections of a chat log
" document.  We will then store the result in a script local variable so that we don't need to re-compute the same
" string value each time a new, empty chat window is opened.
"
"NOTE: We will always check to see if the variable exists before declaring it in case this script manages to get
"      sourced more than once in the same runtime.
"
if !exists("s:new_chat_header_separator")
    let s:new_chat_header_separator = LLMChat#new_chat#GetHeaderSeparatorBar()
endif

