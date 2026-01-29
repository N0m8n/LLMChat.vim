
UTSuite LLMPlugin New and Open Chat Tests

" Tests for functionality found in the 'autoload/LLMChat/new_chat.vim' script.

"-------------------------------------------------------------------------------------------------------------------

" =================
" ===           ===
" ===  Imports  ===
" ===           ===
" =================
" This section contains all script imports that are needed for the test execution.

" Import the 'import/test/test_utils.vim' script so that we have access to additional testing utility functions.
import 'test/test_utils.vim' as testutil



"
" =====================================
" ===                              ====
" ===  Test Function Declarations  ====
" ===                              ====
" =====================================
" This section of the file contains the main testing functions as well as immediate test support functions like Setup(),
" Teardown(), etc.


" This function is responsible for preparing the current editor state for execution of the unit tests in this file.
" Primarily this will consist of taking the following actions:
"
"   1). Find any global variable recognized by the plugin whose value is NOT assigned to the default as found in the
"       plugin/LLMChat.vim file and backup the currently stored value within an appropriate script-local variable.
"
"   2). Reset all variables whose values were backed up in step #1 such that the plugin assigned default value is
"       restored.
"
" Why are all the variable backups and resets necessary?  Ultimately the Vim installation we use may have preferences
" setup in a file like .vimrc that may change the plugin values currently in use by the editor.  For testing buffer
" related actions this can cause unexpected results which would then fail the associated test (even if the actual plugin
" logic is working as expected).  To avoid this we will carefully adjust the editor's global state prior to running any
" tests then we will restore this state after testing completes.
function s:BeforeAll()
    " Invoke a testing utility function that will handle checking the values for all global plugin variables and
    " resetting those with custom values back to their expected defaults.  This utility will then return back to us a
    " dictionary containing the original values for all variables that were reset so that we can restore these at
    " conclusion of the test.
    "
    "NOTE: Since we need to restore values at the end of testing (and this will be done by a completely different
    "      function execution) we need to store the "restore_values_dict" returned to us in a script-scope variable.
    let s:restore_values_dict = s:testutil.ResetGlobalVars()

endfunction


" This function executes immediately before each test function in this suite and takes the following actions:
"
"   1). Reset all global plugin variables back to their "default" values.  This ensures that any changes made to the
"       values held by such variables are cleared before the next test execution takes place.
"
function! s:Setup()
    " Reset all global plugin variables back to the default values expected by this testing script.  Why are we doing
    " this here when we already to it in the BeforeAll() function?  The reason is that we may have a test failure that
    " changed one of these values and if we don't reset before the next test execution we may impact the expected
    " setup for that test.  Note that we ignore any returned "restore" dictionary in this case as the values it would
    " hold come from the testing.
    call s:testutil.ResetGlobalVars()

endfunction


"
" =========================================  Start Standalone Tests  =========================================
"


" This test asserts the behavior of the "NewChat" command when it is executed (1) without any additional arguments and
" (2) uses all default values for the global plugin variables.  If working properly the command should open a new split
" then initialize the buffer in that split to contain a templated definition for a chat document.  Additionally the
" command should leave (1) the active buffer context on the new chat document and (2) should leave the cursor positioned
" at the first required header definition that has no usable default given.
function s:TestNewChatCommandWithNoArgsAndDefaults()
    " Store the ID for the current buffer.  We do this so we can show that, after running the "NewChat" command, the
    " context has shifted to a new buffer.
    let l:orig_buffer_id = bufnr('%')

    " Execute the 'NewChat' command without any arguments to open a new buffer that is not associated with any save
    " file.
    NewChat

    " Assert that the active buffer is now different than our original buffer.
    let l:new_buff_id = bufnr('%')
    AssertDiffers(l:orig_buffer_id, l:new_buff_id)

    " Assert that the new buffer has no filepath associated with it.
    AssertEquals('', expand("#" .. l:new_buff_id .. ":p"))

    " Assert that the cursor is positioned on the line starting with 'Model ID:' as this should be the first required
    " header declaration that has no acceptable default.
    "
    " NOTE: The '.' argument given to function getline(..) is a special value that means "the number where the cursor
    "       is currently positioned).
    "
    " NOTE 2: The assertion for the content of the line containing the cursor is a little awkward since there doesn't
    "         seem to be a function in Vim that will match a regex to a string and return back a boolean indicating
    "         matching.  So in leu of this we will instead take the content of the line containing the cursor, try to
    "         expression match what we think should be there, then assert that the match is what we think it is.
    "
    let l:curr_line_value = getline('.')
    AssertEquals("Model ID:", matchstr(l:curr_line_value, '\v^Model ID\:', '', ''))

    " Assert that the full content of the buffer matches to an expected text block.
    let l:expected_buff_text =
          \ "#" ..
        \ "\n# BEGIN CHAT LOG HEADER SECTION..." ..
        \ "\n#" ..
        \ "\n" ..
        \ "\nServer Type: Ollama" ..
        \ "\nServer URL: http://localhost:11434" ..
        \ "\nModel ID: <REQUIRED - Please Fill In>" ..
        \ "\nUse Auth Token: false" ..
        \ "\n" ..
        \ "\n#" ..
        \ "\n# Additional, but optional, header declarations:" ..
        \ "\n#" ..
        \ "\n### The system prompt to be used during the chat.  Note that this option may contain a value" ..
        \ "\n### which spans multiple lines and for this reason the option declaration MUST be followed by" ..
        \ "\n### an empty line to serve as the option's ending delmiter." ..
        \ "\n#System Prompt: <PROMPT> " ..
        \ "\n#" ..
        \ "\n#" ..
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
        \ "\n********* ENDSETUP *********" ..
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
        \ "\n>>>"

    " NOTE: The "expand('<sflnum>')" function does NOT return the correct line number for error reporting and this can
    "       make the unit test results difficult to read since the error would be called out in the wrong location.  It
    "       is assumed that this happens because this file is translated to an actual script that is then run by the
    "       test execution and the line number reported comes from that secondary script.  It was noted, however, that
    "       the value returned by "expand('<sflnum>')" was consistently a value of 9 larger than what we need the line
    "       number reported as (at least in this suite) so for now we will just subtract 9 to correct the value.
    call s:testutil.AssertBufferContents(expand('<sflnum>') - 9, l:new_buff_id, l:expected_buff_text)

    " Close out the new chat buffer as part of final cleanup after the test.
    bd!

endfunction


" This test asserts the behavior of the "NewChat" command when it is executed (1) with the path to a non-existant file
" and (2) when all default values are in use for the global plugin variables.  If working properly the command should
" open a new split then initialize the buffer in that split to contain a templated definition for a chat document.
" Additionally the command should leave (1) the active buffer context on the new chat document and (2) should leave the
" cursor positioned at the first required header definition that has no usable default given.
function s:TestNewChatCommandWithNonExistantFileAndDefaults()
    " Store the ID for the current buffer.  We do this so we can show that, after running the "NewChat" command, the
    " context has shifted to a new buffer.
    let l:orig_buffer_id = bufnr('%')

    " Define the path to a file we expect does NOT exist then assert that no such file can be found on the local
    " system.  To create such a path we will expand the path to this script file then append to it some fake extension.
    " This scheme is not fool-proof but since Vim does not seem to have any facility for generating UUID/GUID tokens
    " (and the need here doesn't seem strong enough to couple testing to the presence of a shell utility like 'uuidgen')
    " we'll try to work with what we've got.  Ultimately the created path *should* go to a location within the testing
    " assets for this plugin so ensuring that no such file exists should be within the realm of reason.
    "
    " NOTE: To test if the file exists we will try to use the 'filereadable()' function since it seems a pure function
    "       for determining file existance isn't available.  This unfortunately only returns "true" if the file exists
    "       AND is readable... but for our purposes here it should be fine.
    "
    let l:nonexistant_file_path = expand('%:p') .. "-NONEXISTANT.file"
    AssertTxt(!filereadable(l:nonexistant_file_path),
            \ "Expected to find no file at system path '" .. l:nonexistant_file_path ..
            \ "' but an actual file existed; unable to ensure the required prerequisite conditions for this test.")

    " Execute the 'NewChat' command with the path to a non-existant file.
    "
    " NOTE: Surrounding the 'l:nonexistant_file_path' with quotes to account for possible spaces within the name caused
    "       problems with resolving the absolute file path via the expand() function.  Essentially the path expansion
    "       didn't seem to acknowledge the quotes as bounding delimiters and instead tried to integrate them into the
    "       path name itself.  For this reason no quoting is used here with the assumption that the generated path won't
    "       have any spaces that we need to worry about.  Maybe the wrong approach was being used to deal with spaces
    "       in the path?  If test breakages begin occuring than this issue will need to be revisited...
    execute "NewChat " .. l:nonexistant_file_path

    " Assert that the active buffer is now different than our original buffer.
    let l:new_buff_id = bufnr('%')
    AssertDiffers(l:orig_buffer_id, l:new_buff_id)

    " Assert that the new buffer is associated with the non-existant file path.
    AssertEquals(l:nonexistant_file_path, expand("#" .. l:new_buff_id .. "%:p"))

    " Assert that the cursor is positioned on the line starting with 'Model ID:' as this should be the first required
    " header declaration that has no acceptable default.
    "
    " NOTE: The '.' argument given to function getline(..) is a special value that means "the number where the cursor
    "       is currently positioned).
    "
    " NOTE 2: The assertion for the content of the line containing the cursor is a little awkward since there doesn't
    "         seem to be a function in Vim that will match a regex to a string and return back a boolean indicating
    "         matching.  So in leu of this we will instead take the content of the line containing the cursor, try to
    "         expression match what we think should be there, then assert that the match is what we think it is.
    "
    let l:curr_line_value = getline('.')
    AssertEquals("Model ID:", matchstr(l:curr_line_value, '\v^Model ID\:', '', ''))

    " Assert that the full content of the buffer matches to an expected text block.
    let l:expected_buff_text =
          \ "#" ..
        \ "\n# BEGIN CHAT LOG HEADER SECTION..." ..
        \ "\n#" ..
        \ "\n" ..
        \ "\nServer Type: Ollama" ..
        \ "\nServer URL: http://localhost:11434" ..
        \ "\nModel ID: <REQUIRED - Please Fill In>" ..
        \ "\nUse Auth Token: false" ..
        \ "\n" ..
        \ "\n#" ..
        \ "\n# Additional, but optional, header declarations:" ..
        \ "\n#" ..
        \ "\n### The system prompt to be used during the chat.  Note that this option may contain a value" ..
        \ "\n### which spans multiple lines and for this reason the option declaration MUST be followed by" ..
        \ "\n### an empty line to serve as the option's ending delmiter." ..
        \ "\n#System Prompt: <PROMPT> " ..
        \ "\n#" ..
        \ "\n#" ..
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
        \ "\n********* ENDSETUP *********" ..
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
        \ "\n>>>"

    " NOTE: The "expand('<sflnum>')" function does NOT return the correct line number for error reporting and this can
    "       make the unit test results difficult to read since the error would be called out in the wrong location.  It
    "       is assumed that this happens because this file is translated to an actual script that is then run by the
    "       test execution and the line number reported comes from that secondary script.  It was noted, however, that
    "       the value returned by "expand('<sflnum>')" was consistently a value of 9 larger than what we need the line
    "       number reported as (at least in this suite) so for now we will just subtract 9 to correct the value.
    call s:testutil.AssertBufferContents(expand('<sflnum>') - 9, l:new_buff_id, l:expected_buff_text)

    " Close out the new chat buffer as part of final cleanup after the test.
    bd!

endfunction


" This test asserts the behavior of the "NewChat" command when it is executed (1) with the path to an existing, but
" empty file and (2) when all default values are in use for the global plugin variables.  If working properly the
" command should open a new split then initialize the buffer in that split to contain a templated definition for a chat
" document.  Additionally the command should leave (1) the active buffer context on the new chat document and (2) should
" leave the cursor positioned at the first required header definition that has no usable default given.
function s:TestNewChatCommandWithExistingEmptyFileAndDefaults()
    " Store the ID for the current buffer.  We do this so we can show that, after running the "NewChat" command, the
    " context has shifted to a new buffer.
    let l:orig_buffer_id = bufnr('%')

    " Create a new temporary file on disk that simply holds the empty string then assert that such file (1) exists and
    " (2) is readable (note that we will use the 'filereadable()' function to determine this).
    let l:temp_file = tempname()

    call writefile([""], l:temp_file)
    AssertTxt(filereadable(l:temp_file),
            \ "Expected to find an empty file at system path '" .. l:temp_file .. "' but no actual file existed.")

    " Execute the 'NewChat' command with the path to the empty, temporary file.
    "
    " NOTE: Surrounding the 'l:temp_file' with quotes to account for possible spaces within the name caused problems
    "       with resolving the absolute file path via the expand() function.  Essentially the path expansion didn't seem
    "       to acknowledge the quotes as bounding delimiters and instead tried to integrate them into the path name
    "       itself.  For this reason no quoting is used here with the assumption that the temporary file won't have any
    "       spaces within its path that we need to worry about.  Maybe the wrong approach was being used to deal with
    "       spaces in the path?  If test breakages begin occuring than this issue will need to be revisited...
    execute "NewChat " .. l:temp_file

    " Assert that the active buffer is now different than our original buffer.
    let l:new_buff_id = bufnr('%')
    AssertDiffers(l:orig_buffer_id, l:new_buff_id)

    " Assert that the new buffer is associated with the temporary file path.
    AssertEquals(l:temp_file, expand("#" .. l:new_buff_id .. "%:p"))

    " Assert that the cursor is positioned on the line starting with 'Model ID:' as this should be the first required
    " header declaration that has no acceptable default.
    "
    " NOTE: The '.' argument given to function getline(..) is a special value that means "the number where the cursor
    "       is currently positioned).
    "
    " NOTE 2: The assertion for the content of the line containing the cursor is a little awkward since there doesn't
    "         seem to be a function in Vim that will match a regex to a string and return back a boolean indicating
    "         matching.  So in leu of this we will instead take the content of the line containing the cursor, try to
    "         expression match what we think should be there, then assert that the match is what we think it is.
    "
    let l:curr_line_value = getline('.')
    AssertEquals("Model ID:", matchstr(l:curr_line_value, '\v^Model ID\:', '', ''))

    " Assert that the full content of the buffer matches to an expected text block.
    let l:expected_buff_text =
          \ "#" ..
        \ "\n# BEGIN CHAT LOG HEADER SECTION..." ..
        \ "\n#" ..
        \ "\n" ..
        \ "\nServer Type: Ollama" ..
        \ "\nServer URL: http://localhost:11434" ..
        \ "\nModel ID: <REQUIRED - Please Fill In>" ..
        \ "\nUse Auth Token: false" ..
        \ "\n" ..
        \ "\n#" ..
        \ "\n# Additional, but optional, header declarations:" ..
        \ "\n#" ..
        \ "\n### The system prompt to be used during the chat.  Note that this option may contain a value" ..
        \ "\n### which spans multiple lines and for this reason the option declaration MUST be followed by" ..
        \ "\n### an empty line to serve as the option's ending delmiter." ..
        \ "\n#System Prompt: <PROMPT> " ..
        \ "\n#" ..
        \ "\n#" ..
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
        \ "\n********* ENDSETUP *********" ..
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
        \ "\n>>>"

    " NOTE: The "expand('<sflnum>')" function does NOT return the correct line number for error reporting and this can
    "       make the unit test results difficult to read since the error would be called out in the wrong location.  It
    "       is assumed that this happens because this file is translated to an actual script that is then run by the
    "       test execution and the line number reported comes from that secondary script.  It was noted, however, that
    "       the value returned by "expand('<sflnum>')" was consistently a value of 9 larger than what we need the line
    "       number reported as (at least in this suite) so for now we will just subtract 9 to correct the value.
    call s:testutil.AssertBufferContents(expand('<sflnum>') - 9, l:new_buff_id, l:expected_buff_text)

    " Close out the new chat buffer and remove the temporary file created earlier as part of final cleanup after the
    " test.
    bd!
    call delete(l:temp_file)

endfunction


" This test asserts the behavior of the "NewChat" command when it is executed (1) with the path to an existing,
" non-empty file and (2) when all default values are in use for the global plugin variables.  If working properly the
" command should open a new split and ONLY set the buffer filetype to 'chtlg'; it should NOT make any changes to the
" actual content of the loaded file.  Note that cursor position is not verified in this case since we do not attempt
" to move the cursor within chat buffers that already contain information.
function s:TestNewChatCommandWithExistingNonEmptyFileAndDefaults()
    " Store the ID for the current buffer.  We do this so we can show that, after running the "NewChat" command, the
    " context has shifted to a new buffer.
    let l:orig_buffer_id = bufnr('%')

    " Create a new temporary file on disk that will have the file extension '.chtlg' AND which will be non-empty.  Note
    " that the actual content of the file doesn't matter so we will just output some test string to it rather than a
    " real chat log.  After the file is written just verify that it exists on disk and is readable.
    let l:temp_file = tempname()

    let l:test_file_content = "Some test content so that the file is non-empty."
    call writefile([l:test_file_content], l:temp_file)
    AssertTxt(filereadable(l:temp_file),
            \ "Expected to find an empty file at system path '" .. l:temp_file .. "' but no actual file existed.")

    " Execute the 'NewChat' command with the path to the empty, temporary file.
    "
    " NOTE: Surrounding the 'l:temp_file' with quotes to account for possible spaces within the name caused problems
    "       with resolving the absolute file path via the expand() function.  Essentially the path expansion didn't seem
    "       to acknowledge the quotes as bounding delimiters and instead tried to integrate them into the path name
    "       itself.  For this reason no quoting is used here with the assumption that the temporary file won't have any
    "       spaces within its path that we need to worry about.  Maybe the wrong approach was being used to deal with
    "       spaces in the path?  If test breakages begin occuring than this issue will need to be revisited...
    execute "NewChat " .. l:temp_file

    " Assert that the active buffer is now different than our original buffer.
    let l:new_buff_id = bufnr('%')
    AssertDiffers(l:orig_buffer_id, l:new_buff_id)

    " Assert that the new buffer is associated with the temporary file path.
    AssertEquals(l:temp_file, expand("#" .. l:new_buff_id .. "%:p"))

    " Assert that the buffer still contains is original data without any additions or modifications having been made
    " by the plugin.  When non-empty chat logs are loaded for use (either via the "NewChat" command or via any other
    " means) they should NEVER be changed by the plugin.
    "
    "NOTE: The "expand('<sflnum>')" function does NOT return the correct line number for error reporting and this can
    "      make the unit test results difficult to read since the error would be called out in the wrong location.  It
    "      is assumed that this happens because this file is translated to an actual script that is then run by the
    "      test execution and the line number reported comes from that secondary script.  It was noted, however, that
    "      the value returned by "expand('<sflnum>')" was consistently a value of 9 larger than what we need the line
    "      number reported as (at least in this suite) so for now we will just subtract 9 to correct the value.
    call s:testutil.AssertBufferContents(expand('<sflnum>') - 9, l:new_buff_id, l:test_file_content)

    " Close out the new chat buffer and remove the temporary file created earlier as part of final cleanup after the
    " test.
    bd!
    call delete(l:temp_file)

endfunction


" This test asserts the behavior of the "NewChat" command when it is executed (1) without any additional arguments and
" (2) with a non-empty setting for the 'g:llmchat_default_model_id' global plugin variable.  If working properly the
" command should open a new split then initialize the buffer in that split to contain a templated definition for a chat
" log document.  Additionally the command should leave (1) the active buffer context on the new chat document and (2)
" should leave the cursor positioned at the end of the last line in the document.
function s:TestNewChatCommandWithNoArgsAndNonDefaultModelID()
    " Set the 'g:llmchat_default_model_id' global plugin variable to a known and non-empty value.
    let g:llmchat_default_model_id = "DefaultModel"

    " Store the ID for the current buffer.  We do this so we can show that, after running the "NewChat" command, the
    " context has shifted to a new buffer.
    let l:orig_buffer_id = bufnr('%')

    " Execute the 'NewChat' command without any arguments to open a new buffer that is not associated with any save
    " file.
    NewChat

    " Assert that the active buffer is now different than our original buffer.
    let l:new_buff_id = bufnr('%')
    AssertDiffers(l:orig_buffer_id, l:new_buff_id)

    " Assert that the new buffer has no filepath associated with it.
    AssertEquals('', expand("#" .. l:new_buff_id .. ":p"))

    " Assert that the cursor is positioned on the last line of the new chat buffer and at the end of the opening '>>>'
    " sequence for the first user message.
    "
    " NOTE: The '.' argument given to function getline(..) is a special value that means "the number where the cursor
    "       is currently positioned).
    "
    let l:curr_line_value = getline('.')
    AssertEquals(line('.'), line('$'))       "Cursor is on the last line in the buffer
    AssertEquals(4, col('.'))                "Cursor is positioned AFTER the end of the '>>>' sequence.
    AssertEquals(">>>", curr_line_value)     "Current line actually holds the opening message sequence '>>>'

    " Assert that the full content of the buffer matches to an expected text block.
    let l:expected_buff_text =
          \ "#" ..
        \ "\n# BEGIN CHAT LOG HEADER SECTION..." ..
        \ "\n#" ..
        \ "\n" ..
        \ "\nServer Type: Ollama" ..
        \ "\nServer URL: http://localhost:11434" ..
        \ "\nModel ID: " .. g:llmchat_default_model_id ..
        \ "\nUse Auth Token: false" ..
        \ "\n" ..
        \ "\n#" ..
        \ "\n# Additional, but optional, header declarations:" ..
        \ "\n#" ..
        \ "\n### The system prompt to be used during the chat.  Note that this option may contain a value" ..
        \ "\n### which spans multiple lines and for this reason the option declaration MUST be followed by" ..
        \ "\n### an empty line to serve as the option's ending delmiter." ..
        \ "\n#System Prompt: <PROMPT> " ..
        \ "\n#" ..
        \ "\n#" ..
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
        \ "\n********* ENDSETUP *********" ..
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
        \ "\n>>>"

    " NOTE: The "expand('<sflnum>')" function does NOT return the correct line number for error reporting and this can
    "       make the unit test results difficult to read since the error would be called out in the wrong location.  It
    "       is assumed that this happens because this file is translated to an actual script that is then run by the
    "       test execution and the line number reported comes from that secondary script.  It was noted, however, that
    "       the value returned by "expand('<sflnum>')" was consistently a value of 9 larger than what we need the line
    "       number reported as (at least in this suite) so for now we will just subtract 9 to correct the value.
    call s:testutil.AssertBufferContents(expand('<sflnum>') - 9, l:new_buff_id, l:expected_buff_text)

    " Close out the new chat buffer and reset the value for global variable 'g:llmchat_default_model_id' back to its
    " expected default as part of final cleanup after the test.
    bd!

    let l:global_var_defaults = s:testutil.GetGlobalVariableDefaults()
    let g:llmchat_default_model_id = l:global_var_defaults["g:llmchat_default_model_id"]

endfunction


" This test asserts the behavior of the "NewChat" command when it is executed (1) without any additional arguments and
" (2) with a non-empty setting for the 'g:llmchat_default_system_prompt' global plugin variable.  If working properly
" the command should open a new split then initialize the buffer in that split to contain a teplated definition for a
" chat log document.  Note that the system prompt held by the 'g:llmchat_default_system_prompt' variable should appear
" within this templated output and NO information about the system prompt should be given in the template's header
" comments.  Finally the command should leave (1) the active buffer context on the new chat document and (2) the
" cursor should be positioned at the first required head definition that has no usable default given.
function s:TestNewChatCommandWithNoArgsAndNonDefaultSystemPrompt()
    " Set the 'g:llmchat_default_system_prompt' global plugin variable to a known and non-empty value.
    let g:llmchat_default_system_prompt = "You are a helpful and thoughtful assistant."

    " Store the ID for the current buffer.  We do this so we can show that, after running the "NewChat" command, the
    " context has shifted to a new buffer.
    let l:orig_buffer_id = bufnr('%')

    " Execute the 'NewChat' command without any arguments to open a new buffer that is not associated with any save
    " file.
    NewChat

    " Assert that the active buffer is now different than our original buffer.
    let l:new_buff_id = bufnr('%')
    AssertDiffers(l:orig_buffer_id, l:new_buff_id)

    " Assert that the new buffer has no filepath associated with it.
    AssertEquals('', expand("#" .. l:new_buff_id .. ":p"))

    " Assert that the cursor is positioned on the line starting with 'Model ID:' as this should be the first required
    " header declaration that has no acceptable default.
    "
    " NOTE: The '.' argument given to function getline(..) is a special value that means "the number where the cursor
    "       is currently positioned).
    "
    " NOTE 2: The assertion for the content of the line containing the cursor is a little awkward since there doesn't
    "         seem to be a function in Vim that will match a regex to a string and return back a boolean indicating
    "         matching.  So in leu of this we will instead take the content of the line containing the cursor, try to
    "         expression match what we think should be there, then assert that the match is what we think it is.
    "
    let l:curr_line_value = getline('.')
    AssertEquals("Model ID:", matchstr(l:curr_line_value, '\v^Model ID\:', '', ''))

    " Assert that the full content of the buffer matches to an expected text block.
    let l:expected_buff_text =
          \ "#" ..
        \ "\n# BEGIN CHAT LOG HEADER SECTION..." ..
        \ "\n#" ..
        \ "\n" ..
        \ "\nServer Type: Ollama" ..
        \ "\nServer URL: http://localhost:11434" ..
        \ "\nModel ID: <REQUIRED - Please Fill In>" ..
        \ "\nUse Auth Token: false" ..
        \ "\nSystem Prompt: " .. g:llmchat_default_system_prompt ..
        \ "\n" ..
        \ "\n" ..
        \ "\n" ..
        \ "\n#" ..
        \ "\n# Additional, but optional, header declarations:" ..
        \ "\n#" ..
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
        \ "\n********* ENDSETUP *********" ..
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
        \ "\n>>>"

    " NOTE: The "expand('<sflnum>')" function does NOT return the correct line number for error reporting and this can
    "       make the unit test results difficult to read since the error would be called out in the wrong location.  It
    "       is assumed that this happens because this file is translated to an actual script that is then run by the
    "       test execution and the line number reported comes from that secondary script.  It was noted, however, that
    "       the value returned by "expand('<sflnum>')" was consistently a value of 9 larger than what we need the line
    "       number reported as (at least in this suite) so for now we will just subtract 9 to correct the value.
    call s:testutil.AssertBufferContents(expand('<sflnum>') - 9, l:new_buff_id, l:expected_buff_text)

    " Cleanup - Restore the testing default value back to variable 'g:llmchat_default_system_prompt' then close out the
    "           new chat buffer as part of final cleanup after the test.
    let l:global_var_defaults = s:testutil.GetGlobalVariableDefaults()
    let g:llmchat_default_system_prompt = l:global_var_defaults["g:llmchat_default_system_prompt"]

    bd!

endfunction


"
" =========================================  End Standalone Tests  =========================================
"

" This teardown function takes the following actions after the execution of each standalone test function in this suite:
"
"   1). Execute a 'stopinsert' mode to ensure that we have switched back to normal mode before the next test execution.
"       Opening a split for testing will switch the mode to insert and we should not assume that tests are always able
"       to clean this up before they terminate.
"
function s:Teardown()
    " Make sure that we've switched the editor back to normal mode before we move forward with the next test.
    silent! stopinsert

endfunction


" This function is responsible for restoring the editor state following the execution of the unit tests in this file.
" Primarily this will consist of taking the following actions:
"
"   1). Check for the existance of script local "backup variables" that were used to preserve editor state information
"       during the execution of function BeforeAll() and restore the values they hold to the appropriate global scope
"       variables.
"
function s:XAfterAll()
    " Call a test utility function to handle the value restoration to any global variable that was reset when this test
    " began execution.
    call s:testutil.RestoreGlobalVars(s:restore_values_dict)

endfunction

