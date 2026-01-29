
UTSuite LLMPlugin Utility Tests

" Tests for logic found in the the 'import/utils.vim' script.

"-------------------------------------------------------------------------------------------------------------------

" =================
" ===           ===
" ===  Imports  ===
" ===           ===
" =================
" This section contains all script imports that are needed for the test execution.

" Import the 'import/utils.vim' script so that we can access its declarations for testing.
import 'utils.vim' as util

" Import the 'import/test/test_utils.vim' script so that we have access to additional testing utility functions.
import 'test/test_utils.vim' as testutil



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
    " NOTE: Since we need to restore values at the end of testing (and this will be done by a completely different
    "       function execution) we need to store the "restore_values_dict" returned to us in a script-scope variable.
    let s:restore_values_dict = s:testutil.ResetGlobalVars()

endfunction


"
" =========================================  Start Standalone Tests  =========================================
"


" *******************************************
" ****  IsDebugEnabled() Function Tests  ****
" *******************************************

" This test asserts the proper operation of function IsDebugEnabled().  To do this the test will assert that such
" function returns back a value of 1 (i.e., "true") when global variable 'g:llmchat_debug_mode_target' has been set to a
" non-empty value and that it returns back 0 (i.e., "false") otherwise.
function s:TestIsDebugEnabled()
    " Backup any value that might be currently held by variable 'g:llmchat_debug_mode_target' then set the variable
    " to hold the empty string.
    let l:llmchat_debug_mode_target_value = ''    " Assume the variable is set to the empty string by default

    if exists("g:llmchat_debug_mode_target")
        let l:llmchat_debug_mode_target_value = g:llmchat_debug_mode_target
    endif

    let g:llmchat_debug_mode_target = ''


    " Assert that a call made to function IsDebugEnabled() will return back a value of 0 (false).
    AssertEquals(0, s:util.IsDebugEnabled())


    " Unset variable 'g:llmchat_debug_mode_target'.
    unlet g:llmchat_debug_mode_target


    " Assert that function IsDebugEnabled() still returns a value of 0 (false).
    AssertEquals(0, s:util.IsDebugEnabled())


    " Now set variable 'g:llmchat_debug_mode_target' to have some non-empty value.  Note that it doesn't matter what
    " that value happens to be for this test as function IsDebugEnabled() does not check what it is.
    let g:llmchat_debug_mode_target = "abcdefg"


    " Assert that function IsDebugEnabled() now returns a value of 1 (true).
    AssertEquals(1, s:util.IsDebugEnabled())


    " Restore the prior value held by variable 'g:llmchat_debug_mode_target' now that the test execution has completed.
    let g:llmchat_debug_mode_target = l:llmchat_debug_mode_target_value

endfunction



" *****************************************
" ****  WriteToDebug() Function Tests  ****
" *****************************************

" This test asserts the proper operation of function WriteToDebug() when no global debug target is defined.  For such
" case the test expects to see the function exit quietly without taking any further action.
function s:TestWriteToDebugWithNoDebugTarget()
    " Backup any value that might currently be held by variable 'g:llmchat_debug_mode_target' then set the variable
    " to hold the empty string.
    let l:llmchat_debug_mode_target_value = ''    " Assume the variable is set to the empty string by default

    if exists("g:llmchat_debug_mode_target")
        let l:llmchat_debug_mode_target_value = g:llmchat_debug_mode_target
    endif

    let g:llmchat_debug_mode_target = ''

    " Store the current number of open editor windows in a variable for later verification.
    let l:curr_win_count = winnr('$')

    " Invoke the WriteToDebug() function with some test message.
    call s:util.WriteToDebug("Some test message")

    " Assert that the number of open editor windows did NOT change.  This simply shows that the function execution made
    " no attempt to open any new window when it ran.
    AssertEquals(l:curr_win_count, winnr('$'))

    " NOTE: There is really no way we can verify that a file wasn't written somewhere so we will have to be content with
    "       showing that there appears to be no change to the editor state AND the function completed successfully as it
    "       should.

    " Restore the original value for varible 'g:llmchat_debug_mode_target' now that the test is complete.
    let g:llmchat_debug_mode_target = l:llmchat_debug_mode_target_value

endfunction


" This test asserts the proper operation of function WriteToDebug() when the global debug target has been set to a value
" of the form "@N" (where 'N' is an integer value indicating the number of the buffer to write debug messages to).  If
" working correctly than the function should output a message passed to it into this buffer and return focus back to the
" window that was open before the call.  Note that for this case the debug buffer setup for use will be loaded but will
" NOT be displayed by any current window in the editor.
function s:TestWriteToDebugWithBufferTargetAndNoBufferWindow()
    " Ask Vim for the name of a temporary file and store this into a local variable.
    let l:temp_file_name = tempname()

    " Store the ID of the current window so that we can navigate back to it later in the test.
    let l:orig_win_id = winnr()

    " Load the temporary file into a new buffer WITHOUT switching to that buffer in the active window
    let l:buff_num = bufadd(l:temp_file_name)
    call bufload(l:buff_num)

    " Backup any value that might currently be held by variable 'g:llmchat_debug_mode_target' then set the variable
    " to hold the number of the new buffer (prefixed with an '@' symbol); this will cause that buffer to behave as the
    " destination for our "debug" output.
    let l:llmchat_debug_mode_target_value = ''    " Assume the variable is set to the empty string by default

    if exists("g:llmchat_debug_mode_target")
        let l:llmchat_debug_mode_target_value = g:llmchat_debug_mode_target
    endif

    let g:llmchat_debug_mode_target = '@' .. l:buff_num

    " Invoke the WriteToDebug() function with a known test message.
    let l:test_message = "Some test message value."

    call s:util.WriteToDebug(l:test_message)

    " Verify that AFTER calling the WriteToDebug() function the window focus was returned to our original window.
    AssertEquals(l:orig_win_id, winnr())

    " Retrieve all content from the new buffer created earlier, join it together, and assert that it is equal to the
    " 'l:test_message' that was written.
    "
    " NOTE: We expect the buffer content to begin with an empty line; this is a side effect of the 'put' command used
    "       to populate the debug buffer with content inside the WriteToDebug() function; essentially content is added
    "       below the first line leaving it empty (in this case because the buffer was empty).
    "
    let l:debug_buff_content = join(getbufline(l:buff_num, 1, '$'), "\n")

    call s:testutil.AssertEqualTextBlocks(expand('<sflnum>') - 9, '', "\n" .. l:test_message, l:debug_buff_content)

    " Now write a second, known message to the WriteToDebug() function.
    let l:test_message_2 = "A second debug message\nspanning multiple\nlines"

    call s:util.WriteToDebug(l:test_message_2)

    " Again, assert that our window focus was returned after calling the debug function.
    AssertEquals(l:orig_win_id, winnr())

    " Retrieve all content from the new buffer created earlier, join it together, and assert that it is the combination
    " of both messages that were provided to the debug function.
    let l:debug_buff_content = join(getbufline(l:buff_num, 1, '$'), "\n")

    call s:testutil.AssertEqualTextBlocks(expand('<sflnum>') - 9,
                                        \ '',
                                        \ "\n" .. l:test_message .. "\n" .. l:test_message_2,
                                        \ l:debug_buff_content)

    " Cleanup - Take the following actions to cleanup after this test execution:
    "
    "  1). Forcefully close the debug buffer that was created WITHOUT saving any of its content.
    "  2). Restore the original value for varible 'g:llmchat_debug_mode_target' now that the test is complete.
    "  3). Remove the tempoary file from disk.
    "
    execute "bd! " .. l:buff_num
    let g:llmchat_debug_mode_target = l:llmchat_debug_mode_target_value
    call delete(l:temp_file_name)

endfunction


" This test asserts the proper operation of function WriteToDebug() when the global debug target has been set to a value
" of the form "@N" (where 'N' is an integer value indicating the number of the buffer to write debug messages to).  If
" working correctly than the function should output a message passed to it into this buffer and return focus back to the
" window that was open before the call.  Note that for this case the debug buffer setup for use will be loaded and shown
" within a window but such window will NOT be the currently active window.
function s:TestWriteToDebugWithBufferTargetAndInactiveBufferWindow()
    " Ask Vim for the name of a temporary file and store this into a local variable.
    let l:temp_file_name = tempname()

    " Store the ID of the current window so that we can navigate back to it later in the test.
    let l:orig_win_id = winnr()

    " Load the temporary file whose name was requested from Vim into a new split.  This will create a new buffer to hold
    " the file AND will display that buffer in its own window.  Note that when we open the split our window focus will
    " shift away making the window holding our debug buffer active.  For this test we don't want to leave this as the
    " active window so we need to shift the focus back to the original window before proceeding.
    execute "split " .. l:temp_file_name
    let l:buff_num = bufnr()
    call win_gotoid(l:orig_win_id)

    " Backup any value that might currently be held by variable 'g:llmchat_debug_mode_target' then set the variable
    " to hold the number of the new buffer (prefixed with an '@' symbol); this will cause that buffer to behave as the
    " destination for our "debug" output.
    let l:llmchat_debug_mode_target_value = ''    " Assume the variable is set to the empty string by default

    if exists("g:llmchat_debug_mode_target")
        let l:llmchat_debug_mode_target_value = g:llmchat_debug_mode_target
    endif

    let g:llmchat_debug_mode_target = '@' .. l:buff_num

    " Invoke the WriteToDebug() function with a known test message.
    let l:test_message = "Some test message value."

    call s:util.WriteToDebug(l:test_message)

    " Verify that AFTER calling the WriteToDebug() function the window focus was returned to our original window.
    AssertEquals(l:orig_win_id, winnr())

    " Retrieve all content from the new buffer created earlier, join it together, and assert that it is equal to the
    " 'l:test_message' that was written.
    "
    " NOTE: We expect the buffer content to begin with an empty line; this is a side effect of the 'put' command used
    "       to populate the debug buffer with content inside the WriteToDebug() function; essentially content is added
    "       below the first line leaving it empty (in this case because the buffer was empty).
    "
    let l:debug_buff_content = join(getbufline(l:buff_num, 1, '$'), "\n")

    call s:testutil.AssertEqualTextBlocks(expand('<sflnum>') - 9,
                                        \ '',
                                        \ "\n" .. l:test_message,
                                        \ l:debug_buff_content)

    " Now write a second, known message to the WriteToDebug() function.
    let l:test_message_2 = "A second debug message\nspanning multiple\nlines"

    call s:util.WriteToDebug(l:test_message_2)

    " Again, assert that our window focus was returned after calling the debug function.
    AssertEquals(l:orig_win_id, winnr())

    " Retrieve all content from the new buffer created earlier, join it together, and assert that it is the combination
    " of both messages that were provided to the debug function.
    let l:debug_buff_content = join(getbufline(l:buff_num, 1, '$'), "\n")

    call s:testutil.AssertEqualTextBlocks(expand('<sflnum>') - 9,
                                        \ '',
                                        \ "\n" .. l:test_message .. "\n" .. l:test_message_2,
                                        \ l:debug_buff_content)

    " Cleanup - Take the following actions to cleanup after this test execution:
    "
    "  1). Forcefully close the debug buffer that was created WITHOUT saving any of its content.
    "  2). Restore the original value for variable 'g:llmchat_debug_mode_target' now that the test is complete.
    "  3). Remove the tempoary file from disk.
    "
    execute "bd! " .. l:buff_num
    let g:llmchat_debug_mode_target = l:llmchat_debug_mode_target_value
    call delete(l:temp_file_name)

endfunction


" This test asserts the proper operation of function WriteToDebug() when the global debug target has been set to a value
" of the form "@N" (where 'N' is an integer value indicating the number of the buffer to write debug messages to).  If
" working correctly than the function should output a message passed to it and return focus back to the window that was
" open before the call.  Note that for this case the debug buffer setup for use will be loaded and will also be
" displayed within the currently active window.
function s:TestWriteToDebugWithBufferTargetAndActiveBufferWindow()
    " Ask Vim for the name of a temporary file and store this into a local variable.
    let l:temp_file_name = tempname()

    " Store the ID of the current window so that we can navigate back to it later in the test.
    let l:orig_win_id = winnr()

    " Load the temporary file whose name was requested from Vim into a new split.  This will create a new buffer to hold
    " the file AND will display that buffer in its own window.  Note that when we open the split our window focus will
    " shift away making the window holding our debug buffer active.  For this test that leaves us in the state we want
    " to be in so we won't take any action to correct it (i.e., the "debug" buffer should be the active window when
    " we start making calls to the function to output debug messages).
    execute "split " .. l:temp_file_name
    let l:buff_num = bufnr()

    " Backup any value that might currently be held by variable 'g:llmchat_debug_mode_target' then set the variable
    " to hold the number of the new buffer (prefixed with an '@' symbol); this will cause that buffer to behave as the
    " destination for our "debug" output.
    let l:llmchat_debug_mode_target_value = ''    " Assume the variable is set to the empty string by default

    if exists("g:llmchat_debug_mode_target")
        let l:llmchat_debug_mode_target_value = g:llmchat_debug_mode_target
    endif

    let g:llmchat_debug_mode_target = '@' .. l:buff_num

    " Invoke the WriteToDebug() function with a known test message.
    let l:test_message = "Some test message value."

    call s:util.WriteToDebug(l:test_message)

    " Verify that AFTER calling the WriteToDebug() function the window focus was returned to our original window.
    AssertEquals(l:orig_win_id, winnr())

    " Retrieve all content from the new buffer created earlier, join it together, and assert that it is equal to the
    " 'l:test_message' that was written.
    "
    " NOTE: We expect the buffer content to begin with an empty line; this is a side effect of the 'put' command used
    "       to populate the debug buffer with content inside the WriteToDebug() function; essentially content is added
    "       below the first line leaving it empty (in this case because the buffer was empty).
    "
    let l:debug_buff_content = join(getbufline(l:buff_num, 1, '$'), "\n")

    call s:testutil.AssertEqualTextBlocks(expand('<sflnum>') - 9, '', "\n" .. l:test_message, l:debug_buff_content)

    " Now write a second, known message to the WriteToDebug() function.
    let l:test_message_2 = "A second debug message\nspanning multiple\nlines"

    call s:util.WriteToDebug(l:test_message_2)

    " Again, assert that our window focus was returned after calling the debug function.
    AssertEquals(l:orig_win_id, winnr())

    " Retrieve all content from the new buffer created earlier, join it together, and assert that it is the combination
    " of both messages that were provided to the debug function.
    let l:debug_buff_content = join(getbufline(l:buff_num, 1, '$'), "\n")

    call s:testutil.AssertEqualTextBlocks(expand('<sflnum>') - 9,
                                        \ '',
                                        \ "\n" .. l:test_message .. "\n" .. l:test_message_2,
                                        \ l:debug_buff_content)

    " Cleanup - Take the following actions to cleanup after this test execution:
    "
    "  1). Forcefully close the debug buffer that was created WITHOUT saving any of its content.
    "  2). Restore the original value for variable 'g:llmchat_debug_mode_target' now that the test is complete.
    "  3). Remove the tempoary file from disk.
    "
    execute "bd! " .. l:buff_num
    let g:llmchat_debug_mode_target = l:llmchat_debug_mode_target_value
    call delete(l:temp_file_name)

endfunction


" This test asserts the proper operation of function WriteToDebug() when the debug target specified is a file path.  If
" working properly the test expects to see the function append the message given to it to the target file then exit
" normally.
function s:TestWriteToDebugWithFileTarget()
    " Ask Vim for the name of a temporary file and store this into a local variable.
    let l:temp_file_name = tempname()

    " Backup any value that might be currently held by variable 'g:llmchat_debug_mode_target' then set the variable
    " to hold the name of the temporary file that Vim gave us.
    let l:llmchat_debug_mode_target_value = ''    " Assume the variable is set to the empty string by default

    if exists("g:llmchat_debug_mode_target")
        let l:llmchat_debug_mode_target_value = g:llmchat_debug_mode_target
    endif

    let g:llmchat_debug_mode_target = l:temp_file_name

    " Invoke the WriteToDebug() function with a known test message.
    let l:test_message = "Some test message value."

    call s:util.WriteToDebug(l:test_message)

    " Read all content from the temporary file, joining all lines together with newline sequences, and assert that it is
    " equal to the test message that was written.
    call s:testutil.AssertEqualTextBlocks(expand('<sflnum>') - 9,
                                        \ '',
                                        \ join(readfile(l:temp_file_name), "\n"),
                                        \ l:test_message)

    " Now write a second, known message to the WriteToDebug() function.
    let l:test_message_2 = "A second debug message\nspanning multiple\nlines"

    call s:util.WriteToDebug(l:test_message_2)

    " Read all content from the temporary file, joining all lines together with newline sequences, and assert that it is
    " equal to the joined content of both debug messages written.
    call s:testutil.AssertEqualTextBlocks(expand('<sflnum>') - 9,
                                        \ '',
                                        \ join(readfile(l:temp_file_name), "\n"),
                                        \ l:test_message .. "\n" .. l:test_message_2)

    " Cleanup - Take the following actions to cleanup after this test execution:
    "
    "  1). Restore the original value for variable 'g:llmchat_debug_mode_target' now that the test is complete.
    "  2). Remove the tempoary file from disk.
    "
    let g:llmchat_debug_mode_target = l:llmchat_debug_mode_target_value
    call delete(l:temp_file_name)

endfunction



" ********************************************
" ****  FormatTextLines() Function Tests  ****
" ********************************************

" This test will assert the proper operation of function FormatTextLines() by confirming its behavior under all the
" following conditions:
"
"   1). A line in the given 'raw_text' does NOT exceed the 'max_len' value given.
"   2). A line in the given 'raw_text' DOES exceed the 'max_len' given AND contains spaces before that length is
"       reached.
"   3). A line in the given 'raw_text' DOES exceed the 'max_len' given but only contains spaces AFTER that length
"       has been exceeded.
"   4). A line in the given 'raw_text' DOES exceed the 'max_len' given and contains NO spaces at all.
"
function s:TestFormatTextLines()
    " Define an input text block that contains examples of each condition we want to check the function behavior for.
    let l:input_text = "shorter than" ..
                   \ "\nexact max len  " ..
                   \ "\nlonger than max length with earlier spaces" ..
                   \ "\nLongerThanMaxLength with no earlier spaces" ..
                   \ "\nLongerThanMaxLengthWithNoSpaces" ..
                   \ "\nLonger   than   max   with   multiple   spaces   "

    " Invoke the FormatTextLines() function to process our test input text and return to us the formatted result.
    let l:actual_result = s:util.FormatTextLines(l:input_text, 15)

    " Verify that the result returned from function FormatTextLines() matches to what we expected to see.
    let l:expected_result = [ "shorter than",
                            \ "exact max len  ",
                            \ "longer than max",
                            \ "length with",
                            \ "earlier spaces",
                            \ "LongerThanMaxLength",
                            \ "with no earlier",
                            \ "spaces",
                            \ "LongerThanMaxLengthWithNoSpaces",
                            \ "Longer   than  ",
                            \ "max   with  ",
                            \ "multiple  ",
                            \ "spaces   " ]

    call s:testutil.AssertEqualLists(expand('<sflnum>') - 9, '', l:expected_result, l:actual_result)

endfunction



" ****************************************************
" ****  ParseChatBufferToBlocks() Function Tests  ****
" ****************************************************

" This test will attempt to invoke function ParseChatBufferToBlocks() to parse the content of a chat document that
" contains only the minimal information required to be considered valid.  If the function is working properly than the
" parse should succeed and should return a parse dictionary containing the expected information.
function s:TestParseChatBufferToBlocksWithMinimalDoc()
    " Begin by defining the most minimal chat document possible while still being valid (i.e., while still including
    " information deemed as required by the parsing process).
    let l:min_chat_doc = "Server Type: Ollama" ..
                     \ "\nServer URL: https://example.com" ..
                     \ "\nModel ID: Foo" ..
                     \ "\n* ENDSETUP *"

    " Open a new buffer then write the content of variable "l:min_chat_doc" to it.  Note that we will use the 'put!'
    " command so that content is inserted BEFORE the first line in the buffer and we'll leave the trailing newline
    " resulting from the downshift of the first buffer line.
    new
    silent! put! = l:min_chat_doc

    " Invoke the ParseChatBufferToBlocks() function to parse the content of the new buffer and return back to us a parse
    " dictionary containing the resulting data.  Note that we expect focus in the editor has already shifted to the new
    " buffer when the 'new' command was run earlier.
    let l:actual_parse_dict = s:util.ParseChatBufferToBlocks()

    " Now define an expected parse dictionary and show that the 'l:actual_parse_dict' returned from parsing the buffer
    " content is identical to it.
    let l:expected_parse_dict = {
                              \   "header":
                              \     {
                              \       "server type": "Ollama",
                              \       "server url": "https://example.com",
                              \       "model id": "Foo"
                              \     }
                              \ }

    call s:testutil.AssertEqualDictionaries(expand('<sflnum>') - 9, '', l:expected_parse_dict, l:actual_parse_dict)

    " Finally cleanup by performing the following tasks:
    "
    "  1). Forcefully delete the new buffer without saving its content.
    "
    bd!

endfunction


" This test will attempt to invoke function ParseChatBufferToBlocks() to parse the content of a chat document that
" contains the maximal set of information allowed while still being considered valid.  If the function is working
" properly than the parse should succeed and should return a parse dictionary containing the expected information.
function s:TestParseChatBufferToBlocksWithMaxDoc()
    " Begin by defining a "maximal" chat document (i.e., a document containing at least one example of all allowed
    " content structures).
    let l:max_chat_doc =
          \ "# A comment line in the header" ..
        \ "\n# followed by another commentline" ..
        \ "\nServer Type: Ollama" ..
        \ "\nServer URL: https://foo.com:45678/some/api/path" ..
        \ "\nModel ID: Some Model" ..
        \ "\nOption: a=b" ..
        \ "\nOption: name with spaces = value with spaces" ..
        \ "\n#Option: w=y" ..
        \ "\nUse Auth Token: True" ..
        \ "\nAuth Token: 3jdu93nfk3h" ..
        \ "\nShow Reasoning: medium" ..
        \ "\n" ..
        \ "\nSystem Prompt:   You are a helpful, knowledgable, and respectful" ..
        \ "\nassistant that will respond to any asked questions to the best" ..
        \ "\nof your ability.   " ..
        \ "\n" ..
        \ "\n" ..
        \ "\n********************** ENDSETUP *************" ..
        \ "\n" ..
        \ "\n     # Floating comment (indented rather than left aligned)" ..
        \ "\n" ..
        \ "\n# Immediately following message style" ..
        \ "\n>>>Hello how are you today?     " ..
        \ "\n<<<" ..
        \ "\n" ..
        \ "\n=>>I am an AI so I don't have any feelings." ..
        \ "\nHow can I help you today?" ..
        \ "\n<<=" ..
        \ "\n" ..
        \ "\n----------------------" ..
        \ "\n" ..
        \ "\n#Next line message style - Also contains leading and trailing whitespace" ..
        \ "\n>>>" ..
        \ "\n     Yes, I would like to know that the secret to life happens" ..
        \ "\nto be.  Can you give me some insight?    " ..
        \ "\n<<<" ..
        \ "\n" ..
        \ "\n#Assistant response with leading and trailing whitespace" ..
        \ "\n=>>" ..
        \ "\n     That is a great question!  Unfortunately I don't have an answer" ..
        \ "\nto give you; life seems to be what you make of it.    " ..
        \ "\n<<=" ..
        \ "\n" ..
        \ "\n----------------------" ..
        \ "\n" ..
        \ "\n#Unfinished chat interaction (1) resources given and (2) with no assistant response." ..
        \ "\n>>>    I'm told this paper might know; can you read it" ..
        \ "\nand let me know what you think?   " ..
        \ "\n[f:document_1]" ..
        \ "\n[f:https://some.domain:4568/knowledge/collection/id]   " ..
        \ "\n     [c:foo]   "


    " Open a new buffer then write the content of variable "l:max_chat_doc" to it.  Note that we will use the 'put!'
    " command so that content is inserted BEFORE the first line in the buffer and we'll leave the trailing newline
    " resulting from the downshift of the first buffer line (the parse should ignore such line so we should not need to
    " exert any special effort here cleaning it up).
    new
    silent! put! = l:max_chat_doc

    " Invoke the ParseChatBufferToBlocks() function to parse the content of the new buffer and return back to us a parse
    " dictionary containing the resulting data.  Note that we expect focus in the editor has already shifted to the new
    " buffer when the 'new' command was run earlier.
    let l:actual_parse_dict = s:util.ParseChatBufferToBlocks()

    " Now define an expected parse dictionary and show that the 'l:actual_parse_dict' returned from parsing the buffer
    " content is identical to it.
    let l:expected_parse_dict = {
                              \   "header":
                              \     {
                              \       "server type": "Ollama",
                              \       "server url": "https://foo.com:45678/some/api/path",
                              \       "model id": "Some Model",
                              \       "use auth": "true",
                              \       "auth key": "3jdu93nfk3h",
                              \       "show thinking": "medium",
                              \       "system prompt": "You are a helpful, knowledgable, and respectful " ..
                              \                        "assistant that will respond to any asked questions to the " ..
                              \                        "best of your ability.",
                              \       "options":
                              \          {
                              \            "a": "b",
                              \            "name with spaces": "value with spaces"
                              \          }
                              \     },
                              \   "messages" :
                              \     [
                              \       {
                              \         "user": "Hello how are you today?",
                              \         "assistant": "I am an AI so I don't have any feelings. " ..
                              \                      "How can I help you today?"
                              \       },
                              \       {
                              \         "user": "Yes, I would like to know that the secret to life happens " ..
                              \                 "to be.  Can you give me some insight?",
                              \         "assistant": "That is a great question!  Unfortunately I don't have an " ..
                              \                      "answer to give you; life seems to be what you make of it."
                              \       },
                              \       {
                              \         "user": "I'm told this paper might know; can you read it and let me know " ..
                              \                 "what you think?",
                              \         "user_resources":
                              \           [
                              \             "f:document_1",
                              \             "f:https://some.domain:4568/knowledge/collection/id",
                              \             "c:foo"
                              \           ]
                              \       }
                              \     ],
                              \   "flags":
                              \     {
                              \       "no-user-message-close": ""
                              \     }
                              \ }

    call s:testutil.AssertEqualDictionaries(expand('<sflnum>') - 9, '', l:expected_parse_dict, l:actual_parse_dict)

    " Finally, cleanup by performing the following tasks:
    "
    "  1). Forcefully delete the new buffer without saving its content.
    "
    bd!

endfunction


" This test will attempt to invoke function ParseChatBufferToBlocks() to parse the content of a new chat buffer that has
" been initialized via template (for example the initialization performed when an empty chat is created via the commands
" in this plugin).  If the template and function are working as expected than the parse should be successful and should
" return back a parse dictionary holding expected content.
function s:TestParseChatBufferToBlocksWithDefaultDoc()
    " Execute the 'NewChat' command to (1) bring up a new, default-initialized chat log within its own split and (2)
    " to change the focus context to that split.
    NewChat

    " Retrieve a dictionary that links each global variable known to this plugin to their expected defaults; this will
    " be used later when assigning defaults ot the parse dictionary data.
    let l:global_var_defaults = s:testutil.GetGlobalVariableDefaults()

    " Now invoke the ParseChatBufferToBlocks() function and assert that the parse dictionary returned matches to an
    " expected dictionary.
    let l:actual_parse_dictionary = s:util.ParseChatBufferToBlocks()

    let l:expected_parse_dictionary = {
                                    \   "header":
                                    \     {
                                    \       "server type": l:global_var_defaults["g:llmchat_default_server_type"],
                                    \       "server url": l:global_var_defaults["g:llmchat_default_server_url"],
                                    \       "model id": "<REQUIRED - Please Fill In>",
                                    \       "use auth": "false"
                                    \     }
                                    \ }

    call s:testutil.AssertEqualDictionaries(expand('<sflnum>') - 9,
                                         \  '',
                                         \  l:expected_parse_dictionary,
                                         \  l:actual_parse_dictionary)

    " Close out the new chat buffer as part of final cleanup after the test.
    bd!

endfunction


" This test will attempt to show that the parsing process defined by function ParseChatBufferToBlocks() handles
" whitespace occurring within user and assistant messages in a prescribed manner.  To do this the test will invoke the
" parsing function with a known buffer content then it will assert that the following within the parse result:
"
"   1). Leading and trailing whitespace in both user and assistant messages is removed.
"   2). Newline characters at the end of non-whitespace lines are removed and replaced with a single space.
"   3). Empty and whitespace only lines that occur within the message are preserved but are represented by a pair
"       of newline characters.
"   4). Any whitespace occurring before or after a double pair of newlines (representing an empty line) is removed.
"
function s:TestParseChatBufferToBlocksWhitespaceHandling()
    " Define an example chat log content in which the user/assistant messages have whitespace that will be operated on
    " when the chat content is parsed.
    let l:example_chat_doc =
      \   "Server Type: Ollama" ..
      \ "\nServer URL: https://localhost" ..
      \ "\nModel ID: Some Model" ..
      \ "\n* ENDSETUP *" ..
      \ "\n>>>     A user message with leading and trailing whitespace.       " ..
      \ "\n<<<" ..
      \ "\n=>>     An assistant response with leading and trailing whitespace.   " ..
      \ "\n<<=" ..
      \ "\n>>>A user message    " ..
      \ "\n      " ..
      \ "\ncontaining a couple " ..
      \ "\n" ..
      \ "\nempty lines" ..
      \ "\n<<<" ..
      \ "\n=>>An assistant message   " ..
      \ "\n        " ..
      \ "\ncontaining a couple  " ..
      \ "\n" ..
      \ "\nempty lines" ..
      \ "\n<<=" ..
      \ "\n>>>A user message containing    " ..
      \ "\n    embedded whitespace sequences   " ..
      \ "\n" ..
      \ "\n        And some inset text.   " ..
      \ "\n<<<" ..
      \ "\n=>>An assistant message containing     " ..
      \ "\n     embedded whitespace sequences   " ..
      \ "\n" ..
      \ "\n        And some inset text.   " ..
      \ "\n<<=" ..
      \ "\n>>>" ..
      \ "\n    A trailing user message" ..
      \ "\n" ..
      \ "\ncontaining a blank line." ..
      \ "\n" ..
      \ "\n<<<"

    " Open a new buffer then write the content of variable 'l:example_chat_doc' to it.  Note that we will use the 'put!'
    " command so that content is inserted BEFORE the first line in the buffer and we'll leave the trailing newline
    " resulting from the downshift of the first buffer line (the parse should ignore this so there should not need to be
    " any special effort exerted here in cleaning it up).
    new
    silent! put! = l:example_chat_doc

    " Invoke the ParseChatBufferBlocks() function to parse the content of the new buffer and return back to us a parse
    " dictionary containing the resulting data.  Note that we expect focus in the editor has already shifted to the new
    " buffer when the 'new' command was run earlier.
    let l:actual_parse_dict = s:util.ParseChatBufferToBlocks()

    " Now define an expected parse dictionary and show that the 'l:actual_parse_dict' returned from parsing the new
    " buffer content is identical to it.
    let l:expected_parse_dict = {
                              \   "header":
                              \     {
                              \       "server type": "Ollama",
                              \       "server url": "https://localhost",
                              \       "model id": "Some Model"
                              \     },
                              \   "messages":
                              \     [
                              \       {
                              \         "user": "A user message with leading and trailing whitespace.",
                              \         "assistant" : "An assistant response with leading and trailing whitespace."
                              \       },
                              \       {
                              \         "user": "A user message" ..
                              \                 "\n" ..
                              \                 "\ncontaining a couple" ..
                              \                 "\n" ..
                              \                 "\nempty lines",
                              \         "assistant": "An assistant message" ..
                              \                      "\n" ..
                              \                      "\ncontaining a couple" ..
                              \                      "\n" ..
                              \                      "\nempty lines"
                              \       },
                              \       {
                              \         "user": "A user message containing   " ..
                              \                 "      embedded whitespace sequences" ..
                              \                 "\n" ..
                              \                 "\n        And some inset text.",
                              \         "assistant": "An assistant message containing     " ..
                              \                      "      embedded whitespace sequences" ..
                              \                      "\n" ..
                              \                      "\n        And some inset text."
                              \       },
                              \       {
                              \         "user": "A trailing user message" ..
                              \                 "\n" ..
                              \                 "\ncontaining a blank line." ..
                              \                 "\n"
                              \       }
                              \     ]
                              \ }

    call s:testutil.AssertEqualDictionaries(expand('<sflnum>') - 9, '', l:expected_parse_dict, l:actual_parse_dict)

    " Finally, cleanup by performing the following tasks:
    "
    "  1). Forcefully delete the new buffer without saving its content.
    "
    bd!

endfunction


" This test asserts the behavior of function ParseChatBufferToBlocks() when the 'header_only_parse' argument passed to
" it has a value of 'true'.  In such a case we expect to see the parsing execution process and return ONLY the header
" content from the chat buffer even when message content is present.
function s:TestParseChatBufferToBlocksWithHeaderOnlyParse()
    " Define an example chat log document that contains both header and message content.  Additionally we will include a
    " number of lines within the header intended to demonstrate well targeted parsing (for example valid declarations
    " that are commented out and which should therefore not appear in the parse results).
    let l:example_chat_doc =
      \ "#Commented out declarations that should NOT be processed." ..
      \ "\n#Server Type: Open-WebUI" ..
      \ "\n#Server URL: http://bad-url/" ..
      \ "\n#Model ID: Bad Model ID" ..
      \ "\n#Use Auth Token: true" ..
      \ "\n#Auth Token: Bad Token" ..
      \ "\n#Option: nope=bad" ..
      \ "\n" ..
      \ "\nServer Type: Ollama" ..
      \ "\nServer URL: http://my-server.com/A/B?foo=abc" ..
      \ "\nModel ID: Good Model" ..
      \ "\nUse Auth Token: FALSE" ..
      \ "\nOption: abc=xyz" ..
      \ "\nSystem Prompt: Single line system prompt" ..
      \ "\n" ..
      \ "\n* ENDSETUP *" ..
      \ "\n>>>User message 1" ..
      \ "\n<<<" ..
      \ "\n=>>Assistant response 1" ..
      \ "\n<<="

    " Open a new buffer then write the content of variable 'l:example_chat_doc' to it.  Note that we will use the 'put!'
    " command so that content is inserted BEFORE the first line in the buffer and we'll leave the trailing newline
    " resulting from the downshift of the first buffer line (the parse should ignore this so there should not need to be
    " any special effort exerted here in cleaning it up).
    new
    silent! put! = l:example_chat_doc

    " Invoke the ParseChatBufferBlocks() function to parse the content of the new buffer using the "header_only_parse"
    " mode.  Note that we expect focus in the editor to already be on our test buffer as this should have occurred when
    " the 'new' command was run.
    let l:actual_parse_dict = s:util.ParseChatBufferToBlocks(1)

    " Now define an expected parse dictionary and show that the 'l:actual_parse_dict' returned from the parsing process
    " is identical to it.
    let l:expected_parse_dict = {
                              \   "header":
                              \     {
                              \       "server type": "Ollama",
                              \       "server url": "http://my-server.com/A/B?foo=abc",
                              \       "model id": "Good Model",
                              \       "use auth": "false",
                              \       "system prompt": "Single line system prompt",
                              \       "options":
                              \         {
                              \           "abc": "xyz"
                              \         }
                              \     }
                              \ }

    call s:testutil.AssertEqualDictionaries(expand('<sflnum>') - 9, '', l:expected_parse_dict, l:actual_parse_dict)

    " Finally, cleanup by performing the following tasks:
    "
    "  1). Forcefully delete the new buffer without saving its content.
    "
    bd!

endfunction


" This test verifies the behavior of function ParseChatBufferToBlocks() when the chat messages it is invoked to parse
" contain special escape sequences.  If working properly the test expects to see the parse complete successfully and the
" resulting parse dictionary should contain the correct unescaped text for the given sequences.
function s:TestParseChatBufferToBlocksWithSpecialEscapes()
    " Define an example chat log document that contains chat messages with special escapes in their content.
    let l:example_chat_doc =
      \   "Server Type: Ollama" ..
      \ "\nServer URL: https://localhost" ..
      \ "\nModel ID: Some Model" ..
      \ "\n* ENDSETUP *" ..
      \ "\n>>>" ..
      \ "\nA user message that contains the following escaped sequences:" ..
      \ "\n\\>>>" ..
      \ "\n\\<<<" ..
      \ "\n\\=>>" ..
      \ "\n\\<<=" ..
      \ "\n\\n" ..
      \ "\nThis should not cause any trouble for the parsing and such sequences" ..
      \ "\nshould be properly unescaped by the parsing logic." ..
      \ "\n<<<" ..
      \ "\n=>>An assistant message that contains the following escaped sequences:" ..
      \ "\n\\>>>" ..
      \ "\n\\<<<" ..
      \ "\n\\=>>" ..
      \ "\n\\<<=" ..
      \ "\n\\n" ..
      \ "\nThis should not cause any trouble for the parsing and such sequences" ..
      \ "\nshould be properly unescaped by the parsing logic." ..
      \ "\n<<=" ..
      \ "\n>>>User message showing *escaped* escape sequences:" ..
      \ "\n\\\\>>>" ..
      \ "\n\\\\<<<" ..
      \ "\n\\\\=>>" ..
      \ "\n\\\\<<=" ..
      \ "\n\\\\n" ..
      \ "\nAgain, should cause no problem for the parsing and should be unescaped" ..
      \ "\nto the escape sequences." ..
      \ "\n<<<" ..
      \ "\n=>>Assistant message showing *escaped* escape sequences:" ..
      \ "\n\\\\>>>" ..
      \ "\n\\\\<<<" ..
      \ "\n\\\\=>>" ..
      \ "\n\\\\<<=" ..
      \ "\n\\\\n" ..
      \ "\nAgain, should cause no problem for the parsing and should be unescaped" ..
      \ "\nto the escape sequences"..
      \ "\n<<="

    " Open a new buffer then write the content of variable 'l:example_chat_doc' to it.  Note that we will use the 'put!'
    " command so that content is inserted BEFORE the first line in the buffer and we'll leave the trailing newline
    " resulting from the downshift of the first buffer line (the parse should ignore this so there should not need to
    " be any special effort exerted here in cleaning it up).
    new
    silent! put! = l:example_chat_doc

    " Invoke the ParseChatBufferBlocks() function to parse the content of the new buffer and return back to us a parse
    " dictionary containing the resulting data.  Note that we expect focus in the editor has already shifted to the new
    " buffer when the 'new' command was run earlier.
    let l:actual_parse_dict = s:util.ParseChatBufferToBlocks()

    " Now define an expected parse dictionary and show that the 'l:actual_parse_dict' returned from parsing the new
    " buffer content is identical to it.
    let l:expected_parse_dict = {
                              \   "header":
                              \     {
                              \       "server type": "Ollama",
                              \       "server url": "https://localhost",
                              \       "model id": "Some Model"
                              \     },
                              \   "messages":
                              \     [
                              \       {
                              \         "user": "A user message that contains the following escaped sequences: " ..
                              \                 ">>> <<< =>> <<= \n This should not cause any trouble for the " ..
                              \                 "parsing and such sequences should be properly unescaped by the " ..
                              \                 "parsing logic.",
                              \         "assistant" : "An assistant message that contains the following escaped " ..
                              \                       "sequences: >>> <<< =>> <<= \n This should not cause any " ..
                              \                       "trouble for the parsing and such sequences should be " ..
                              \                       "properly unescaped by the parsing logic."
                              \       },
                              \       {
                              \         "user": "User message showing *escaped* escape sequences: \\>>> \\<<< \\=>> " ..
                              \                 "\\<<= \\\n Again, should cause no problem for the parsing and " ..
                              \                 "should be unescaped to the escape sequences.",
                              \         "assistant": "Assistant message showing *escaped* escape sequences: \\>>> " ..
                              \                      "\\<<< \\=>> \\<<= \\\n Again, should cause no problem for the " ..
                              \                      "parsing and should be unescaped to the escape sequences"
                              \       }
                              \     ]
                              \ }

    call s:testutil.AssertEqualDictionaries(expand('<sflnum>') - 9, '', l:expected_parse_dict, l:actual_parse_dict)

    " Finally, cleanup by performing the following tasks:
    "
    "  1). Forcefully delete the new buffer without saving its content.
    "
    bd!

endfunction


" This test asserts that function ParseChatBufferToBlocks() throws an exception with an expected error message when the
" buffer content being processed is missing a server type declaration in its header.
function s:TestParseChatBufferToBlocksWithMissingServerType()
    " Define an invalid chat log document that contains a header with no server type declaration.
    let l:bad_chat_doc =
      \   "Server URL: https://localhost" ..
      \ "\nModel ID: Some model"  ..
      \ "\n* ENDSETUP *"

    " Open a new buffer then write the content of variable 'l:bad_chat_doc' to it.  Note that we will use the 'put!'
    " command so that content is inserted BEFORE the first line in the buffer and we'll leave the trailing newline
    " resulting from the downshift of the first buffer line (the parse should ignore this so there should not need to be
    " any special effort exerted here in cleaning it up).
    new
    silent! put! = l:bad_chat_doc

    " Invoke the ParseChatBufferBlocks() function and assert that an exception is thrown whose message indicates the
    " fault we're expecting to see.
    try
        call s:util.ParseChatBufferToBlocks()

        " If the logic comes here than fail the test; we should have seen an exception thrown during parse which would
        " make this line unreachable.
        call s:testutil.Fail(expand('<sflnum>') - 9,
                           \ "Expected to see an exception thrown from function ParseChatBufferToBlocks() when it " ..
                           \ "was invoked to parse the content of a chat buffer whose header section lacked a " ..
                           \ "server type declaration; however, no exception occurred.")

    catch /\c[error].*no 'server type:' declaration found.*/
        " The caught exception has a message that matches the expression we were looking for; assume that the test was
        " successful and take no further action.
    endtry

    " Cleanup - Forcefully close out the new buffer that was created to hold the test document.
    bd!

endfunction


" This test asserts that function ParseChatBufferToBlocks() throws an exception with an expected error message when the
" buffer content being processed is missing a server URL declaration in its header.
function s:TestParseChatBufferToBlocksWithMissingServerURL()
    " Define an invalid chat log document that contains a header with no server URL declaration.
    let l:bad_chat_doc =
      \   "Server Type: Ollama" ..
      \ "\nModel ID: Some model"  ..
      \ "\n* ENDSETUP *"

    " Open a new buffer then write the content of variable 'l:bad_chat_doc' to it.  Note that we will use the 'put!'
    " command so that content is inserted BEFORE the first line in the buffer and we'll leave the trailing newline
    " resulting from the downshift of the first buffer line (the parse should ignore this so there should not need to be
    " any special effort exerted here in cleaning it up).
    new
    silent! put! = l:bad_chat_doc

    " Invoke the ParseChatBufferBlocks() function and assert that an exception is thrown whose message indicates the
    " fault we're expecting to see.
    try
        call s:util.ParseChatBufferToBlocks()

        " If the logic comes here than fail the test; we should have seen an exception thrown during parse which would
        " make this line unreachable.
        call s:testutil.Fail(expand('<sflnum>') - 9,
                           \ "Expected to see an exception thrown from function ParseChatBufferToBlocks() when it " ..
                           \ "was invoked to parse the content of a chat buffer whose header section lacked a " ..
                           \ "server URL declaration; however, no exception occurred.")

    catch /\c[error].*no 'server url:' declaration found.*/
        " The caught exception has a message that matches the expression we were looking for; assume that the test was
        " successful and take no further action.
    endtry

    " Cleanup - Forcefully close out the new buffer that was created to hold the test document.
    bd!

endfunction


" This test asserts that function ParseChatBufferToBlocks() throws an exception with an expected error message when the
" buffer content being processed is missing a model ID declaration in its header.
function s:TestParseChatBufferToBlocksWithMissingModelID()
    " Define an invalid chat log document that contains a header with no model ID declaration.
    let l:bad_chat_doc =
      \   "Server Type: Ollama" ..
      \ "\nServer URL: http://localhost/"  ..
      \ "\n* ENDSETUP *"

    " Open a new buffer then write the content of variable 'l:bad_chat_doc' to it.  Note that we will use the 'put!'
    " command so that content is inserted BEFORE the first line in the buffer and we'll leave the trailing newline
    " resulting from the downshift of the first buffer line (the parse should ignore this so there should not need to be
    " any special effort exerted here in cleaning it up).
    new
    silent! put! = l:bad_chat_doc

    " Invoke the ParseChatBufferBlocks() function and assert that an exception is thrown whose message indicates the
    " fault we're expecting to see.
    try
        call s:util.ParseChatBufferToBlocks()

        " If the logic comes here than fail the test; we should have seen an exception thrown during parse which would
        " make this line unreachable.
        call s:testutil.Fail(expand('<sflnum>') - 9,
                           \ "Expected to see an exception thrown from function ParseChatBufferToBlocks() when it " ..
                           \ "was invoked to parse the content of a chat buffer whose header section lacked a model " ..
                           \ "ID declaration; however, no exception occurred.")

    catch /\c[error].*no 'model id:' declaration found.*/
        " The caught exception has a message that matches the expression we were looking for; assume that the test was
        " successful and take no further action.
    endtry

    " Cleanup - Forcefully close out the new buffer that was created to hold the test document.
    bd!

endfunction


" This test asserts that function ParseChatBufferToBlocks() throws an exception with an expected error message when the
" buffer content being processed contains duplicate server type declarations in its header.
function s:TestParseChatBufferToBlocksWithDuplicateServerTypeDecl()
    " Define an invalid chat log document that contains a header with duplicate server type declarations.
    let l:bad_chat_doc =
      \   "Server Type: Ollama" ..
      \ "\nServer URL: http://localhost/"  ..
      \ "\nModel ID: Some model" ..
      \ "\nServer Type: Some Type" ..
      \ "\n* ENDSETUP *"

    " Open a new buffer then write the content of variable 'l:bad_chat_doc' to it.  Note that we will use the 'put!'
    " command so that content is inserted BEFORE the first line in the buffer and we'll leave the trailing newline
    " resulting from the downshift of the first buffer line (the parse should ignore this so there should not need to be
    " any special effort exerted here in cleaning it up).
    new
    silent! put! = l:bad_chat_doc

    " Invoke the ParseChatBufferBlocks() function and assert that an exception is thrown whose message indicates the
    " fault we're expecting to see.
    try
        call s:util.ParseChatBufferToBlocks()

        " If the logic comes here than fail the test; we should have seen an exception thrown during parse which would
        " make this line unreachable.
        call s:testutil.Fail(expand('<sflnum>') - 9,
                           \ "Expected to see an exception thrown from function ParseChatBufferToBlocks() when it " ..
                           \ "was invoked to parse the content of a chat buffer whose header section contained " ..
                           \ "duplicate server type declarations; however, no exception occurred.")

    catch /\c[error].*duplicate 'server type'.*/
        " The caught exception has a message that matches the expression we were looking for; assume that the test
        " was successful and take no further action.
    endtry

    " Cleanup - Forcefully close out the new buffer that was created to hold the test document.
    bd!

endfunction


" This test asserts that function ParseChatBufferToBlocks() throws an exception with an expected error message when the
" buffer content being processed contains a server type declaration whose associated value is empty.
function s:TestParseChatBufferToBlocksWithEmptyServerTypeDecl()
    " Define an invalid chat log document that contains a header with an empty server type declaration.
    let l:bad_chat_doc =
      \   "Server Type:" ..
      \ "\nServer URL: http://localhost/"  ..
      \ "\nModel ID: Some model" ..
      \ "\n* ENDSETUP *"

    " Open a new buffer then write the content of variable 'l:bad_chat_doc' to it.  Note that we will use the 'put!'
    " command so that content is inserted BEFORE the first line in the buffer and we'll leave the trailing newline
    " resulting from the downshift of the first buffer line (the parse should ignore this so there should not need to be
    " any special effort exerted here in cleaning it up).
    new
    silent! put! = l:bad_chat_doc

    " Invoke the ParseChatBufferBlocks() function and assert that an exception is thrown whose message indicates the
    " fault we're expecting to see.
    try
        call s:util.ParseChatBufferToBlocks()

        " If the logic comes here than fail the test; we should have seen an exception thrown during parse which would
        " make this line unreachable.
        call s:testutil.Fail(expand('<sflnum>') - 9,
                           \ "Expected to see an exception thrown from function ParseChatBufferToBlocks() when it " ..
                           \ "was invoked to parse the content of a chat buffer whose header section contained an " ..
                           \ "empty server type declaration; however, no exception occurred.")

    catch /\c[error].*'server type'.*an empty value.*/
        " The caught exception has a message that matches the expression we were looking for; assume that the test
        " was successful and take no further action.
    endtry

    " Cleanup - Forcefully close out the new buffer that was created to hold the test document.
    bd!

endfunction


" This test asserts that function ParseChatBufferToBlocks() throws an exception with an expected error message when the
" buffer content being processed contains a duplicate server URL declaration in its header.
function s:TestParseChatBufferToBlocksWithDuplicateServerURLDecl()
    " Define an invalid chat log document that contains a header with duplicate server URL declarations.
    let l:bad_chat_doc =
      \   "Server Type: Ollama" ..
      \ "\nServer URL: http://localhost/"  ..
      \ "\nModel ID: Some model" ..
      \ "\nServer URL: https://foo.bar.com/bs" ..
      \ "\n* ENDSETUP *"

    " Open a new buffer then write the content of variable 'l:bad_chat_doc' to it.  Note that we will use the 'put!'
    " command so that content is inserted BEFORE the first line in the buffer and we'll leave the trailing newline
    " resulting from the downshift of the first buffer line (the parse should ignore this so there should not need to be
    " any special effort exerted here in cleaning it up).
    new
    silent! put! = l:bad_chat_doc

    " Invoke the ParseChatBufferBlocks() function and assert that an exception is thrown whose message indicates the
    " fault we're expecting to see.
    try
        call s:util.ParseChatBufferToBlocks()

        " If the logic comes here than fail the test; we should have seen an exception thrown during parse which would
        " make this line unreachable.
        call s:testutil.Fail(expand('<sflnum>') - 9,
                           \ "Expected to see an exception thrown from function " ..
                           \ "LLMChat#send_chat#ParseChatBufferToBlocks() when it was invoked to parse the content " ..
                           \ "of a chat buffer whose header section contained duplicate server URL declarations; " ..
                           \ "however, no exception occurred.")

    catch /\c[error].*duplicate 'server url'.*/
        " The caught exception has a message that matches the expression we were looking for; assume that the test was
        " successful and take no further action.
    endtry

    " Cleanup - Forcefully close out the new buffer that was created to hold the test document.
    bd!

endfunction


" This test asserts that function ParseChatBufferToBlocks() throws an exception with an expected error message when the
" buffer content being processed contains a server URL declaration in its header whose value is empty.
function s:TestParseChatBufferToBlocksWithEmptyServerURLDecl()
    " Define an invalid chat log document that contains a header with an empty server url declaration.
    let l:bad_chat_doc =
      \   "Server Type: Ollama" ..
      \ "\nServer URL:"  ..
      \ "\nModel ID: Some model" ..
      \ "\n* ENDSETUP *"

    " Open a new buffer then write the content of variable 'l:bad_chat_doc' to it.  Note that we will use the 'put!'
    " command so that content is inserted BEFORE the first line in the buffer and we'll leave the trailing newline
    " resulting from the downshift of the first buffer line (the parse should ignore this so there should not need to be
    " any special effort exerted here in cleaning it up).
    new
    silent! put! = l:bad_chat_doc

    " Invoke the ParseChatBufferBlocks() function and assert that an exception is thrown whose message indicates the
    " fault we're expecting to see.
    try
        call s:util.ParseChatBufferToBlocks()

        " If the logic comes here than fail the test; we should have seen an exception thrown during parse which would
        " make this line unreachable.
        call s:testutil.Fail(expand('<sflnum>') - 9,
                           \ "Expected to see an exception thrown from function ParseChatBufferToBlocks() when it " ..
                           \ "was invoked to parse the content of a chat buffer whose header section contained an " ..
                           \ "empty server URL declaration; however, no exception occurred.")

    catch /\c[error].*'server url'.*an empty value.*/
        " The caught exception has a message that matches the expression we were looking for; assume that the test
        " was successful and take no further action.
    endtry

    " Cleanup - Forcefully close out the new buffer that was created to hold the test document.
    bd!

endfunction


" This test asserts that function ParseChatBufferToBlocks() throws an exception with an expected error message when the
" buffer content being processed contains a duplicate model ID declaration in its header.
function s:TestParseChatBufferToBlocksWithDuplicateModelIDDecl()
    " Define an invalid chat log document that contains a header with duplicate model ID declarations.
    let l:bad_chat_doc =
      \   "Server Type: Ollama" ..
      \ "\nServer URL: http://localhost/"  ..
      \ "\nModel ID: Some model" ..
      \ "\nModel ID: gemeni" ..
      \ "\n* ENDSETUP *"

    " Open a new buffer then write the content of variable 'l:bad_chat_doc' to it.  Note that we will use the 'put!'
    " command so that content is inserted BEFORE the first line in the buffer and we'll leave the trailing newline
    " resulting from the downshift of the first buffer line (the parse should ignore this so there should not need to be
    " any special effort exerted here in cleaning it up).
    new
    silent! put! = l:bad_chat_doc

    " Invoke the ParseChatBufferBlocks() function and assert that an exception is thrown whose message indicates the
    " fault we're expecting to see.
    try
        call s:util.ParseChatBufferToBlocks()

        " If the logic comes here than fail the test; we should have seen an exception thrown during parse which would
        " make this line unreachable.
        call s:testutil.Fail(expand('<sflnum>') - 9,
                           \ "Expected to see an exception thrown from function ParseChatBufferToBlocks() when it " ..
                           \ "was invoked to parse the content of a chat buffer whose header section contained " ..
                           \ "duplicate model ID declarations; however, no exception occurred.")

    catch /\c[error].*duplicate 'model id'.*/
        " The caught exception has a message that matches the expression we were looking for; assume that the test
        " was successful and take no further action.
    endtry

    " Cleanup - Forcefully close out the new buffer that was created to hold the test document.
    bd!

endfunction


" This test asserts that function ParseChatBufferToBlocks() throws an exception with an expected error message when the
" buffer content being processed has a model ID declaration in its header whose value is empty.
function s:TestParseChatBufferToBlocksWithEmptyModelIDDecl()
    " Define an invalid chat log document that contains a header with an empty model ID declaration.
    let l:bad_chat_doc =
      \   "Server Type: Ollama" ..
      \ "\nServer URL: http://localhost/"  ..
      \ "\nModel ID:" ..
      \ "\n* ENDSETUP *"

    " Open a new buffer then write the content of variable 'l:bad_chat_doc' to it.  Note that we will use the 'put!'
    " command so that content is inserted BEFORE the first line in the buffer and we'll leave the trailing newline
    " resulting from the downshift of the first buffer line (the parse should ignore this so there should not need to be
    " any special effort exerted here in cleaning it up).
    new
    silent! put! = l:bad_chat_doc

    " Invoke the ParseChatBufferBlocks() function and assert that an exception is thrown whose message indicates the
    " fault we're expecting to see.
    try
        call s:util.ParseChatBufferToBlocks()

        " If the logic comes here than fail the test; we should have seen an exception thrown during parse which would
        " make this line unreachable.
        call s:testutil.Fail(expand('<sflnum>') - 9,
                           \ "Expected to see an exception thrown from function ParseChatBufferToBlocks() when it " ..
                           \ "was invoked to parse the content of a chat buffer whose header section contained an " ..
                           \ "empty model ID declaration; however, no exception occurred.")

    catch /\c[error].*'model id'.*an empty value.*/
        " The caught exception has a message that matches the expression we were looking for; assume that the test
        " was successful and take no further action.
    endtry

    " Cleanup - Forcefully close out the new buffer that was created to hold the test document.
    bd!

endfunction


" This test asserts that function ParseChatBufferToBlocks() throws an exception with an expected error message when the
" buffer content being processed has a duplicate "Use Auth Token" declaration in its header.
function s:TestParseChatBufferToBlocksWithDuplicateUseAuthDecl()
    " Define an invalid chat log document that contains a header with duplicate "Use Auth Token" declarations.
    let l:bad_chat_doc =
      \   "Server Type: Ollama" ..
      \ "\nServer URL: http://localhost/"  ..
      \ "\nUse Auth Token: false" ..
      \ "\nModel ID: Some model" ..
      \ "\nUse Auth Token: true" ..
      \ "\n* ENDSETUP *"

    " Open a new buffer then write the content of variable 'l:bad_chat_doc' to it.  Note that we will use the 'put!'
    " command so that content is inserted BEFORE the first line in the buffer and we'll leave the trailing newline
    " resulting from the downshift of the first buffer line (the parse should ignore this so there should not need to be
    " any special effort exerted here in cleaning it up).
    new
    silent! put! = l:bad_chat_doc

    " Invoke the ParseChatBufferBlocks() function and assert that an exception is thrown whose message indicates the
    " fault we're expecting to see.
    try
        call s:util.ParseChatBufferToBlocks()

        " If the logic comes here than fail the test; we should have seen an exception thrown during parse which would
        " make this line unreachable.
        call s:testutil.Fail(expand('<sflnum>') - 9,
                           \ "Expected to see an exception thrown from function " ..
                           \ "LLMChat#send_chat#ParseChatBufferToBlocks() when it was invoked to parse the content " ..
                           \ "of a chat buffer whose header section contained duplicate auth use declarations; " ..
                           \ "however, no exception occurred.")

    catch /\c[error].*duplicate 'use auth token'.*/
        " The caught exception has a message that matches the expression we were looking for; assume that the test
        " was successful and take no further action.
    endtry

    " Cleanup - Forcefully close out the new buffer that was created to hold the test document.
    bd!

endfunction


" This test asserts that function ParseChatBufferToBlocks() throws an exception with an expected error message when the
" buffer content being processed has a "Use Auth Token" declaration that holds an invalid value.
function s:TestParseChatBufferToBlocksWithBadUseAuthDecl()
    " Define an invalid chat log document that contains a header with a 'Use Auth Token' declaration whose value is bad.
    let l:bad_chat_doc =
      \   "Server Type: Ollama" ..
      \ "\nServer URL: http://localhost/"  ..
      \ "\nModel ID: Some model" ..
      \ "\nUse Auth Token: Mary had a little lamb" ..
      \ "\n* ENDSETUP *"

    " Open a new buffer then write the content of variable 'l:bad_chat_doc' to it.  Note that we will use the 'put!'
    " command so that content is inserted BEFORE the first line in the buffer and we'll leave the trailing newline
    " resulting from the downshift of the first buffer line (the parse should ignore this so there should not need to be
    " any special effort exerted here in cleaning it up).
    new
    silent! put! = l:bad_chat_doc

    " Invoke the ParseChatBufferBlocks() function and assert that an exception is thrown whose message indicates the
    " fault we're expecting to see.
    try
        call s:util.ParseChatBufferToBlocks()

        " If the logic comes here than fail the test; we should have seen an exception thrown during parse which would
        " make this line unreachable.
        call s:testutil.Fail(expand('<sflnum>') - 9,
                           \ "Expected to see an exception thrown from function ParseChatBufferToBlocks() when it " ..
                           \ "was invoked to parse the content of a chat buffer whose header section contained an " ..
                           \ "auth use declaration with an invalid value; however, no exception occurred.")

    catch /\c[error].*'use auth token'.*invalid value.*/
        " The caught exception has a message that matches the expression we were looking for; assume that the test
        " was successful and take no further action.
    endtry

    " Cleanup - Forcefully close out the new buffer that was created to hold the test document.
    bd!

endfunction


" This test asserts that function ParseChatBufferToBlocks() throws an exception with an expected error message when the
" buffer content being processed contains a duplicate "Auth Token" declaration in its header.
function s:TestParseChatBufferToBlocksWithDuplicateAuthTokenDecl()
    " Define an invalid chat log document that contains a header with duplicate auth token declarations.
    let l:bad_chat_doc =
      \   "Server Type: Ollama" ..
      \ "\nServer URL: http://localhost/"  ..
      \ "\nModel ID: Some model" ..
      \ "\nAuth Token: First Token" ..
      \ "\nAuth Token: Second Token" ..
      \ "\n* ENDSETUP *"

    " Open a new buffer then write the content of variable 'l:bad_chat_doc' to it.  Note that we will use the 'put!'
    " command so that content is inserted BEFORE the first line in the buffer and we'll leave the trailing newline
    " resulting from the downshift of the first buffer line (the parse should ignore this so there should not need to be
    " any special effort exerted here in cleaning it up).
    new
    silent! put! = l:bad_chat_doc

    " Invoke the ParseChatBufferBlocks() function and assert that an exception is thrown whose message indicates the
    " fault we're expecting to see.
    try
        call s:util.ParseChatBufferToBlocks()

        " If the logic comes here than fail the test; we should have seen an exception thrown during parse which would
        " make this line unreachable.
        call s:testutil.Fail(expand('<sflnum>') - 9,
                           \ "Expected to see an exception thrown from function ParseChatBufferToBlocks() when it " ..
                           \ "was invoked to parse the content of a chat buffer whose header section contained " ..
                           \ "duplicate auth token declarations; however, no exception occurred.")

    catch /\c[error].*duplicate 'auth token'.*/
        " The caught exception has a message that matches the expression we were looking for; assume that the test
        " was successful and take no further action.
    endtry

    " Cleanup - Forcefully close out the new buffer that was created to hold the test document.
    bd!

endfunction


" This test asserts that function ParseChatBufferToBlocks() throws an exception with an expected error message when the
" buffer content being processed contains a duplicate system prompt declaration in its header.
function s:TestParseChatBufferToBlocksWithDuplicateSystemPromptDecl()
    " Define an invalid chat log document that contains a header with duplicate system prompt declarations.
    let l:bad_chat_doc =
      \   "Server Type: Ollama" ..
      \ "\nServer URL: http://localhost/"  ..
      \ "\nModel ID: Some model" ..
      \ "\nSystem Prompt: You are a helpful assistant" ..
      \ "\n" ..
      \ "\nSystem Prompt: You are a bane to all you meet." ..
      \ "\n" ..
      \ "\n* ENDSETUP *"

    " Open a new buffer then write the content of variable 'l:bad_chat_doc' to it.  Note that we will use the 'put!'
    " command so that content is inserted BEFORE the first line in the buffer and we'll leave the trailing newline
    " resulting from the downshift of the first buffer line (the parse should ignore this so there should not need to be
    " any special effort exerted here in cleaning it up).
    new
    silent! put! = l:bad_chat_doc

    " Invoke the ParseChatBufferBlocks() function and assert that an exception is thrown whose message indicates the
    " fault we're expecting to see.
    try
        call s:util.ParseChatBufferToBlocks()

        " If the logic comes here than fail the test; we should have seen an exception thrown during parse which would
        " make this line unreachable.
        call s:testutil.Fail(expand('<sflnum>') - 9,
                           \ "Expected to see an exception thrown from function ParseChatBufferToBlocks() when it " ..
                           \ "was invoked to parse the content of a chat buffer whose header section contained " ..
                           \ "duplicate system prompt declarations; however, no exception occurred.")

    catch /\c[error].*duplicate 'system prompt:'.*/
        " The caught exception has a message that matches the expression we were looking for; assume that the test
        " was successful and take no further action.
    endtry

    " Cleanup - Forcefully close out the new buffer that was created to hold the test document.
    bd!

endfunction


" This test asserts that function ParseChatBufferToBlocks() throws an exception with an expected error message when the
" buffer content being processed contains a duplicate option declaration in its header (i.e., an option declaration that
" uses the same "name" segment in its value as another option).
function s:TestParseChatBufferToBlocksWithDuplicateOptionDecl()
    " Define an invalid chat log document that contains a header with duplicate option declarations.
    let l:bad_chat_doc =
      \   "Server Type: Ollama" ..
      \ "\nServer URL: http://localhost/"  ..
      \ "\nModel ID: Some model" ..
      \ "\nOption: abc=123" ..
      \ "\nOption: xyz=345" ..
      \ "\nOption: abc=ABC" ..
      \ "\n* ENDSETUP *"

    " Open a new buffer then write the content of variable 'l:bad_chat_doc' to it.  Note that we will use the 'put!'
    " command so that content is inserted BEFORE the first line in the buffer and we'll leave the trailing newline
    " resulting from the downshift of the first buffer line (the parse should ignore this so there should not need to be
    " any special effort exerted here in cleaning it up).
    new
    silent! put! = l:bad_chat_doc

    " Invoke the ParseChatBufferBlocks() function and assert that an exception is thrown whose message indicates the
    " fault we're expecting to see.
    try
        call s:util.ParseChatBufferToBlocks()

        " If the logic comes here than fail the test; we should have seen an exception thrown during parse which would
        " make this line unreachable.
        call s:testutil.Fail(expand('<sflnum>') - 9,
                           \ "Expected to see an exception thrown from function ParseChatBufferToBlocks() when it " ..
                           \ "was invoked to parse the content of a chat buffer whose header section contained " ..
                           \ "duplicate option declarations; however, no exception occurred.")

    catch /\c[error].*more than one option.*name 'abc'.*/
        " The caught exception has a message that matches the expression we were looking for; assume that the test
        " was successful and take no further action.
    endtry

    " Cleanup - Forcefully close out the new buffer that was created to hold the test document.
    bd!

endfunction


" This test asserts that function ParseChatBufferToBlocks() throws an exception with an expected error message when the
" buffer content being processed contains a duplicate show reasoning declaration in its header.
function s:TestParseChatBufferToBlocksWithDuplicateShowReasoningDecl()
    " Define an invalid chat log document that contains a header with duplicate show reasoning declarations.
    let l:bad_chat_doc =
      \   "Server Type: Ollama" ..
      \ "\nShow Reasoning: true" ..
      \ "\nServer URL: http://localhost/"  ..
      \ "\nModel ID: Some model" ..
      \ "\nShow Reasoning: true" ..
      \ "\n* ENDSETUP *"

    " Open a new buffer then write the content of variable 'l:bad_chat_doc' to it.  Note that we will use the 'put!'
    " command so that content is inserted BEFORE the first line in the buffer and we'll leave the trailing newline
    " resulting from the downshift of the first buffer line (the parse should ignore this so there should not need to be
    " any special effort exerted here in cleaning it up).
    new
    silent! put! = l:bad_chat_doc

    " Invoke the ParseChatBufferBlocks() function and assert that an exception is thrown whose message indicates the
    " fault we're expecting to see.
    try
        call s:util.ParseChatBufferToBlocks()

        " If the logic comes here than fail the test; we should have seen an exception thrown during parse which would
        " make this line unreachable.
        call s:testutil.Fail(expand('<sflnum>') - 9,
                           \ "Expected to see an exception thrown from function ParseChatBufferToBlocks() when it " ..
                           \ "was invoked to parse the content of a chat buffer whose header section contained " ..
                           \ "duplicate show reasoning declarations; however, no exception occurred.")

    catch /\c[error].*duplicate 'show reasoning'.*/
        " The caught exception has a message that matches the expression we were looking for; assume that the test
        " was successful and take no further action.
    endtry

    " Cleanup - Forcefully close out the new buffer that was created to hold the test document.
    bd!

endfunction


" This test asserts that function ParseChatBufferToBlocks() throws an exception with an expected error message when the
" buffer content being processed has a "show reasoning" declaration in its header whose value is empty.
function s:TestParseChatBufferToBlocksWithEmptyShowReasoningDecl()
    " Define an invalid chat log document that contains a header with a show reasoning declaration whose value is empty.
    let l:bad_chat_doc =
      \   "Server Type: Ollama" ..
      \ "\nServer URL: http://localhost/"  ..
      \ "\nModel ID: Some model" ..
      \ "\nShow Reasoning:    " ..
      \ "\n* ENDSETUP *"

    " Open a new buffer then write the content of variable 'l:bad_chat_doc' to it.  Note that we will use the 'put!'
    " command so that content is inserted BEFORE the first line in the buffer and we'll leave the trailing newline
    " resulting from the downshift of the first buffer line (the parse should ignore this so there should not need to be
    " any special effort exerted here in cleaning it up).
    new
    silent! put! = l:bad_chat_doc

    " Invoke the ParseChatBufferBlocks() function and assert that an exception is thrown whose message indicates the
    " fault we're expecting to see.
    try
        call s:util.ParseChatBufferToBlocks()

        " If the logic comes here than fail the test; we should have seen an exception thrown during parse which would
        " make this line unreachable.
        call s:testutil.Fail(expand('<sflnum>') - 9,
                           \ "Expected to see an exception thrown from function ParseChatBufferToBlocks() when it " ..
                           \ "was invoked to parse the content of a chat buffer whose header section contained " ..
                           \ "a show reasoning declaration with an empty value; however, no exception occurred.")

    catch /\c[error].*show reasoning.*empty value.*/
        " The caught exception has a message that matches the expression we were looking for; assume that the test
        " was successful and take no further action.
    endtry

    " Cleanup - Forcefully close out the new buffer that was created to hold the test document.
    bd!

endfunction


" This test asserts that function ParseChatBufferToBlocks() throws an exception with an expected error message when the
" buffer content being processing contains a user message with invalid resource references.
function s:TestParseChatBufferToBlocksWithInvalidResourceReferences()
    " Define an invalid chat document whose content holds an improperly formatted resource reference within a user
    " message.
    let l:bad_chat_doc =
      \   "Server Type: Ollama" ..
      \ "\nServer URL: http://localhost/"  ..
      \ "\nModel ID: Some model" ..
      \ "\n* ENDSETUP *" ..
      \ "\n>>>Some user message" ..
      \ "\n[Bad Resource Ref]"


    " Open a new buffer then write the content of variable 'l:bad_chat_doc' to it.  Note that we will use the 'put!'
    " command so that content is inserted BEFORE the first line in the buffer and we'll leave the trailing newline
    " resulting from the downshift of the first buffer line (the parse should ignore this so there should not need to be
    " any special effort exerted here in cleaning it up).
    new
    silent! put! = l:bad_chat_doc

    " Invoke the ParseChatBufferBlocks() function and assert that an exception is thrown whose message indicates the
    " fault we're expecting to see.
    try
        call s:util.ParseChatBufferToBlocks()

        " If the logic comes here than fail the test; we should have seen an exception thrown during parse which would
        " make this line unreachable.
        call s:testutil.Fail(expand('<sflnum>') - 9,
                           \ "Expected to see an exception thrown from function ParseChatBufferToBlocks() when it " ..
                           \ "was invoked to parse the content of a chat buffer that contained an improperly " ..
                           \ "defined resource reference; however, no exception occurred.")

    catch /\c[error].*resource reference.*format was invalid.*/
        " The caught exception has a message that matches the expression we were looking for; assume that the test
        " was successful and take no further action.
    endtry

    " Cleanup - Forcefully close out the new buffer that was created to hold the test document.
    bd!

endfunction


" This test asserts that function ParseChatBufferToBlocks() throws an exception with an expected error message when the
" buffer content being processed contains "unexpected text" in its header (i.e., text that is not associated with any
" supported grammatical header structure such as a declaration, comment, etc).
function s:TestParseChatBufferToBlocksWithUnexpectedHeaderContent()
    " Define a chat log document that contains a header with unexpected text (i.e., text that is outside the context of
    " any supported syntactic structure).
    let l:bad_chat_doc =
      \   "Server Type: Ollama" ..
      \ "\nServer URL: http://localhost/"  ..
      \ "\nModel ID: Some model" ..
      \ "\nJust some random text stuffed in here :-)" ..
      \ "\n* ENDSETUP *"

    " Open a new buffer then write the content of variable 'l:bad_chat_doc' to it.  Note that we will use the 'put!'
    " command so that content is inserted BEFORE the first line in the buffer and we'll leave the trailing newline
    " resulting from the downshift of the first buffer line (the parse should ignore this so there should not need to be
    " any special effort exerted here in cleaning it up).
    new
    silent! put! = l:bad_chat_doc

    " Invoke the ParseChatBufferBlocks() function and assert that an exception is thrown whose message indicates the
    " fault we're expecting to see.
    try
        call s:util.ParseChatBufferToBlocks()

        " If the logic comes here than fail the test; we should have seen an exception thrown during parse which would
        " make this line unreachable.
        call s:testutil.Fail(expand('<sflnum>') - 9,
                           \ "Expected to see an exception thrown from function ParseChatBufferToBlocks() when it " ..
                           \ "was invoked to parse the content of a chat buffer whose header section contained " ..
                           \ "unexpected text data; however, no exception occurred.")

    catch /\c[error].*unexpected text.*/
        " The caught exception has a message that matches the expression we were looking for; assume that the test
        " was successful and take no further action.
    endtry

    " Cleanup - Forcefully close out the new buffer that was created to hold the test document.
    bd!

endfunction


" This test asserts that function ParseChatBufferToBlocks() throws an exception with an expected error message when the
" buffer content being processed contains an empty assistant message.
function s:TestParseChatBufferToBlocksWithEmptyAssistantMessageFault()
    " Define an invalid chat log document that contains an empty assistant message.
    let l:bad_chat_doc =
      \   "Server Type: Ollama" ..
      \ "\nServer URL: https://localhost" ..
      \ "\nModel ID: Some Model" ..
      \ "\n* ENDSETUP *" ..
      \ "\n>>>User message 1" ..
      \ "\n<<<" ..
      \ "\n" ..
      \ "\n#Empty Assistant Message - This shouldn't happen so we consider it an error condition." ..
      \ "\n=>>" ..
      \ "\n<<="

    " Open a new buffer then write the content of variable 'l:bad_chat_doc' to it.  Note that we will use the 'put!'
    " command so that content is inserted BEFORE the first line in the buffer and we'll leave the trailing newline
    " resulting from the downshift of the first buffer line (the parse should ignore this so there should not need to be
    " any special effort exerted here in cleaning it up).
    new
    silent! put! = l:bad_chat_doc

    " Invoke the ParseChatBufferBlocks() function and assert that an exception is thrown whose message indicates the
    " fault we're expecting to see.
    try
        call s:util.ParseChatBufferToBlocks()

        " If the logic comes here than fail the test; we should have seen an exception thrown during parse which would
        " make this line unreachable.
        call s:testutil.Fail(expand('<sflnum>') - 9,
                           \ "Expected to see an exception thrown from function ParseChatBufferToBlocks() when it " ..
                           \ "was invoked to parse the content of a chat buffer with an empty assistant message; " ..
                           \ "however, no exception occurred.")

    catch /\c[error].*missing the content of the assistant message.*/
        " The caught exception has a message that matches the expression we were looking for; assume that the test
        " was successful and take no further action.
    endtry

    " Cleanup - Forcefully close out the new buffer that was created to hold the test document.
    bd!

endfunction


" This test asserts that an exception is thrown from function ParseChatBufferToBlocks() when the buffer content being
" processed contains two back-to-back user messages (i.e., the expected assistant messsage between such chat messages
" does not exist).
function s:TestParseChatBufferToBlocksWithMissingAssistantMessageFault()
    " Define an invalid chat log document that contains a missing assistant message.
     let l:bad_chat_doc =
      \   "Server Type: Ollama" ..
      \ "\nServer URL: https://localhost" ..
      \ "\nModel ID: Some Model" ..
      \ "\n* ENDSETUP *" ..
      \ "\n>>>User message 1" ..
      \ "\n<<<" ..
      \ "\n" ..
      \ "\n>>>User message 2" ..
      \ "\n<<<"

    " Open a new buffer then write the content of variable 'l:bad_chat_doc' to it.  Note that we will use the 'put!'
    " command so that content is inserted BEFORE the first line in the buffer and we'll leave the trailing newline
    " resulting from the downshift of the first buffer line (the parse should ignore this so there should not need to be
    " any special effort exerted here in cleaning it up).
    new
    silent! put! = l:bad_chat_doc

    " Invoke the ParseChatBufferBlocks() function and assert that an exception is thrown whose message indicates the
    " fault we're expecting to see.
    try
        call s:util.ParseChatBufferToBlocks()

        " If the logic comes here than fail the test; we should have seen an exception thrown during parse which would
        " make this line unreachable.
        call s:testutil.Fail(expand('<sflnum>') - 9,
                           \ "Expected to see an exception thrown from function ParseChatBufferToBlocks() when it " ..
                           \ "was invoked to parse the content of a chat buffer with a missing assistant message; " ..
                           \ "however, no exception occurred.")

    catch /\c[error].*without any assistant message being present.*/
        " The caught exception has a message that matches the expression we were looking for; assume that the test
        " was successful and take no further action.
    endtry

    " Cleanup - Forcefully close out the new buffer that was created to hold the test document.
    bd!

endfunction


" This test asserts that an exception is thrown from function ParseChatBufferToBlocks() when the buffer content being
" processed contains an interaction block that is missing a user message.  Note that the following two cases will be
" handled by the test:
"
"   1). The first interaction in the file is missing the user message.
"   2). An interaction beyond the first is missing the user message.
"
function s:TestParseChatBufferToBlocksWithMissingUserMessageFault()
    " -------------------------------------------------------------------------
    " --- Condition #1 - First user message in the chat document is missing ---
    " -------------------------------------------------------------------------

    " Define an invalid chat log document that contains only an assistant message (the initial user message is missing).
    let l:bad_chat_doc =
      \   "Server Type: Ollama" ..
      \ "\nServer URL: https://localhost" ..
      \ "\nModel ID: Some Model" ..
      \ "\n* ENDSETUP *" ..
      \ "\n" ..
      \ "\n=>>That is a great question!  In order to break out of a for loop you can use the 'break' instruction." ..
      \ "\n<<="

    " Open a new buffer then write the content of variable 'l:bad_chat_doc' to it.  Note that we will use the 'put!'
    " command so that content is inserted BEFORE the first line in the buffer and we'll leave the trailing newline
    " resulting from the downshift of the first buffer line (the parse should ignore this so there should not need to be
    " any special effort exerted here in cleaning it up).
    new
    silent! put! = l:bad_chat_doc

    " Invoke the ParseChatBufferBlocks() function and assert that an exception is thrown whose message indicates the
    " fault we're expecting to see.
    try
        call s:util.ParseChatBufferToBlocks()

        " If the logic comes here than fail the test; we should have seen an exception thrown during parse which would
        " make this line unreachable.
        call s:testutil.Fail(expand('<sflnum>') - 9,
                           \ "Expected to see an exception thrown from function ParseChatBufferToBlocks() when it " ..
                           \ "was invoked to parse the content of a chat buffer whose initial user message was " ..
                           \ "missing; however, no exception occurred.")

    catch /\c[error].*missing a user message.*/
        " The caught exception has a message that matches the expression we were looking for; assume that the test
        " was successful and take no further action.
    endtry

    " Cleanup - Forcefully close out the new buffer that was created to hold the test document.
    bd!


    " --------------------------------------------------------------------------------------------
    " --- Condition #2 - The user message is missing from an interaction that is NOT the first ---
    " --------------------------------------------------------------------------------------------

    " Define a chat log document that contains a missing user message somewhere within the messages content.
    let l:bad_chat_doc =
      \   "Server Type: Ollama" ..
      \ "\nServer URL: https://localhost" ..
      \ "\nModel ID: Some Model" ..
      \ "\n* ENDSETUP *" ..
      \ "\n" ..
      \ "\n>>>User message 1" ..
      \ "\n<<<" ..
      \ "\n" ..
      \ "\n=>>Assistant answer 1" ..
      \ "\n<<=" ..
      \ "\n" ..
      \ "\n=>>Assistant answer 2" ..
      \ "\n<<="

    " Open a new buffer then write the content of variable 'l:bad_chat_doc' to it.  Note that we will use the 'put!'
    " command so that content is inserted BEFORE the first line in the buffer and we'll leave the trailing newline
    " resulting from the downshift of the first buffer line (the parse should ignore this so there should not need to be
    " any special effort exerted here in cleaning it up).
    new
    silent! put! = l:bad_chat_doc

    " Invoke the ParseChatBufferBlocks() function and assert that an exception is thrown whose message indicates the
    " fault we're expecting to see.
    try
        call s:util.ParseChatBufferToBlocks()

        " If the logic comes here than fail the test; we should have seen an exception thrown during parse which would
        " make this line unreachable.
        let l:test_fail_message =
        call s:testutil.Fail(expand('<sflnum>') - 9,
                           \ "Expected to see an exception thrown from function ParseChatBufferToBlocks() when it " ..
                           \ "was invoked to parse the content of a chat buffer whose initial user message was " ..
                           \ "missing; however, no exception occurred.")

    catch /\c[error].*missing a user message.*/
        " The caught exception has a message that matches the expression we were looking for; assume that the test
        " was successful and take no further action.
    endtry

    " Cleanup - Forcefully close out the new buffer that was created to hold the test document.
    bd!

endfunction


" This test asserts that an expected exception is thrown from function ParseChatBufferToBlocks() when the buffer content
" being processed contains unexpected text within the body section of the chat log document (for example arbitrary text
" that is outside the context of a user or assistant message and which is NOT a separator).
function s:TestParseChatBufferToBlocksWithUnexpectedTextContent()
    " Define an invalid chat log document that contains unexpected text between the user and assistant messages.
    let l:bad_chat_doc =
      \   "Server Type: Ollama" ..
      \ "\nServer URL: https://localhost" ..
      \ "\nModel ID: Some Model" ..
      \ "\n* ENDSETUP *" ..
      \ "\n" ..
      \ "\n>>User message 1" ..
      \ "\n<<<" ..
      \ "\n" ..
      \ "\n-- Unexpected text" ..
      \ "\n=>>Assistant response 1" ..
      \ "\n<<="


    " Open a new buffer then write the content of variable 'l:bad_chat_doc' to it.  Note that we will use the 'put!'
    " command so that content is inserted BEFORE the first line in the buffer and we'll leave the trailing newline
    " resulting from the downshift of the first buffer line (the parse should ignore this so there should not need to be
    " any special effort exerted here in cleaning it up).
    new
    silent! put! = l:bad_chat_doc

    " Invoke the ParseChatBufferBlocks() function and assert that an exception is thrown whose message indicates the
    " fault we're expecting to see.
    try
        call s:util.ParseChatBufferToBlocks()

        " If the logic comes here than fail the test; we should have seen an exception thrown during parse which would
        " make this line unreachable.
        call s:testutil.Fail(expand('<sflnum>') - 9,
                           \ "Expected to see an exception thrown from function ParseChatBufferToBlocks() when it " ..
                           \ "was invoked to parse the content of a chat buffer whose body contained unexpected " ..
                           \ "text (i.e., text that was NOT a comment or separator and which occurred outside the " ..
                           \ "context of a chat message); however, no exception occurred.")

    catch /\c[error].*unexpected text.*/
        " The caught exception has a message that matches the expression we were looking for; assume that the test
        " was successful and take no further action.
    endtry

    " Cleanup - Forcefully close out the new buffer that was created to hold the test document.
    bd!

endfunction


" This test asserts that an expected exception is thrown from function ParseChatBufferToBlocks() when the buffer content
" being processed lacks the ending separator for the header (this means that the parse will never exit the header
" section during execution).
function s:TestParseChatBufferToBlocksWithMissingHeaderSep()
    " Define an invalid chat log document that lacks the separator between the header and body portions of the content.
    let l:bad_chat_doc =
      \   "Server Type: Ollama" ..
      \ "\nServer URL: https://localhost" ..
      \ "\nModel ID: Some Model" ..
      \ "\n"

    " Open a new buffer then write the content of variable 'l:bad_chat_doc' to it.  Note that we will use the 'put!'
    " command so that content is inserted BEFORE the first line in the buffer and we'll leave the trailing newline
    " resulting from the downshift of the first buffer line (the parse should ignore this so there should not need to be
    " any special effort exerted here in cleaning it up).
    new
    silent! put! = l:bad_chat_doc

    " Invoke the ParseChatBufferBlocks() function and assert that an exception is thrown whose message indicates the
    " fault we're expecting to see.
    try
        call s:util.ParseChatBufferToBlocks()

        " If the logic comes here than fail the test; we should have seen an exception thrown during parse which would
        " make this line unreachable.
        call s:testutil.Fail(expand('<sflnum>') - 9,
                           \ "Expected to see an exception thrown from function ParseChatBufferToBlocks() when it " ..
                           \ "was invoked to parse the content of a chat buffer that lacked the required separator " ..
                           \ "at the end of the document header section; however, no exception occurred.")

    catch /\c[error].* endsetup .*/
        " The caught exception has a message that matches the expression we were looking for; assume that the test
        " was successful and take no further action.
    endtry

    " Cleanup - Forcefully close out the new buffer that was created to hold the test document.
    bd!

endfunction


" This test asserts that an expected exception is thrown from function ParseChatBufferToBlocks() when the last message
" in the buffer being processed is an assistant message and such message is missing its closing delimiter..
function s:TestParseChatBufferToBlocksWithMissingAssistantMessageClosingDelimiter()
    " Define an invalid chat log document in which the last message is an assistant response which lacks its closing
    " delimiter.
    let l:bad_chat_doc =
      \   "Server Type: Ollama" ..
      \ "\nServer URL: https://localhost" ..
      \ "\nModel ID: Some Model" ..
      \ "\n***** ENDSETUP *****" ..
      \ "\n" ..
      \ "\n>>>User message 1" ..
      \ "\n<<<" ..
      \ "\n" ..
      \ "\n=>>Assistant response 1"

    " Open a new buffer then write the content of variable 'l:bad_chat_doc' to it.  Note that we will use the 'put!'
    " command so that content is inserted BEFORE the first line in the buffer and we'll leave the trailing newline
    " resulting from the downshift of the first buffer line (the parse should ignore this so there should not need to be
    " any special effort exerted here in cleaning it up).
    new
    silent! put! = l:bad_chat_doc

    " Invoke the ParseChatBufferBlocks() function and assert that an exception is thrown whose message indicates the
    " fault we're expecting to see.
    try
        call s:util.ParseChatBufferToBlocks()

        " If the logic comes here than fail the test; we should have seen an exception thrown during parse which would
        " make this line unreachable.
        call s:testutil.Fail(expand('<sflnum>') - 9,
                           \ "Expected to see an exception thrown from function ParseChatBufferToBlocks() when it " ..
                           \ "was invoked to parse the content of a chat buffer whose last assistant response " ..
                           \ "lacked its closing delimiter; however, no exception occurred.")

    catch /\c[error].*.*st assistant response.*/
        " The caught exception has a message that matches the expression we were looking for; assume that the test
        " was successful and take no further action.
    endtry

    " Cleanup - Forcefully close out the new buffer that was created to hold the test document.
    bd!

endfunction



" *****************************************
" ****  GetAuthToken() Function Tests  ****
" *****************************************

" This test asserts the behavior of function GetAuthToken() when the chat buffer in use explicitly indicates that no
" authorization is required when contacting the remote LLM server.  If working properly the test expects to see the
" function execution exit normally and return back the special value '-' (which indicates auth is not needed).
function s:TestGetAuthTokenWithExplicitDisablingOfAuth()
    " Define a partial parse dictionary which only contains the required header fields as well as the field indicating
    " that authorization for LLM server requests should not be used.
    let l:test_parse_dict = {
                          \   "header":
                          \   {
                          \     "server type": "Ollama",
                          \     "server url": "https://localhost",
                          \     "model id": "Test Model",
                          \     "use auth": "false"
                          \   }
                          \ }

    " Invoke the GetAuthToken() function and assert that the expected value is returned.
    AssertEquals("-", s:util.GetAuthToken(l:test_parse_dict))

endfunction


" This test asserts the behavior of function GetAuthToken() when the chat buffer in use does NOT specify whether or not
" authentication is needed for calls to the remote LLM server but the editor state indicates auth is not needed (i.e.,
" the 'g:llmchat_apikey_file' is not set any no explicit auth token was given in the chat header content).  If working
" properly the test expects to see the function execution exit normally and return back the special value '-' (which
" indicates auth is not needed).
function s:TestGetAuthTokenWithImplicitDisablingOfAuth()
    " Set the 'g:llmchat_apikey_file' to the empty string to ensure that no auth file is specified for use.
    let g:llmchat_apikey_file = ''

    " Define a partial parse dictionary which only contains the required header fields.
    let l:test_parse_dict = {
                          \   "header":
                          \   {
                          \     "server type": "Ollama",
                          \     "server url": "https://localhost",
                          \     "model id": "Test Model",
                          \   }
                          \ }

    " Invoke the GetAuthToken() function and assert that the expected value is returned.
    AssertEquals("-", s:util.GetAuthToken(l:test_parse_dict))

    " Restore the 'g:llmchat_apikey_file' variable back to the test default setting so that we don't impact any other
    " test executions.
    let l:global_var_defaults = s:testutil.GetGlobalVariableDefaults()
    let g:llmchat_apikey_file = l:global_var_defaults["g:llmchat_apikey_file"]

endfunction


" This test asserts the behavior of function GetAuthToken() when the chat buffer in use does NOT specify whether or not
" authentication is needed for calls to the remote LLM server but the chat buffer DOES define an auth token to use.  In
" this case the test expects to see the function execution exit normally and return back the auth token that is
" explicitly specified within the chat.
function s:TestGetAuthTokenWithImplicitEnabledAuthViaChatToken()
    " Define a partial parse dictionary that defines an auth token to use in addition to the required header fields.
    " Note that the field specifying whether or not to use auth will be absent.
     let l:test_parse_dict = {
                          \   "header":
                          \   {
                          \     "server type": "Ollama",
                          \     "server url": "https://localhost",
                          \     "model id": "Test Model",
                          \     "auth key": "AuthKeyValue"
                          \   }
                          \ }

    " Invoke the GetAuthToken() function and assert that the expected value is returned.
    AssertEquals("AuthKeyValue", s:util.GetAuthToken(l:test_parse_dict))

endfunction


" This test asserts the behavior of function GetAuthToken() when the chat buffer in use explicitly notes that
" authentication is required AND the chat buffer includes a chat token.  For such case the test expects to see the
" function execution complete normally and the token explicitly defined within the chat should be returned.
function s:TestGetAuthTokenWithAuthExplicitlyEnabledAndExplicitChatToken()
    " Define a partial parse dictionary that specifies (1) that auth IS required and (2) the auth token to use in
    " addition to the other required header fields.
     let l:test_parse_dict = {
                          \   "header":
                          \   {
                          \     "server type": "Ollama",
                          \     "server url": "https://localhost",
                          \     "model id": "Test Model",
                          \     "use auth": "true",
                          \     "auth key": "AuthKeyValue"
                          \   }
                          \ }

    " Invoke the GetAuthToken() function and assert that the expected value is returned.
    AssertEquals("AuthKeyValue", s:util.GetAuthToken(l:test_parse_dict))

endfunction


" This test asserts the behavior of function GetAuthToken() when the chat buffer in use explicitly notes that
" authentication is required and the buffer-local auth variable has been set (no explicit chat token will be present in
" this case).  If working properly the function execution should complete normally and the value held by the
" buffer-local auth variable should be returned.
function s:TestGetAuthTokenWithAuthExplicitlyEnabledAndBufferLocalAuthValue()
    " Set variable 'b:llmchat_auth_token' to a locally known testing value.  Note that we will backup the original
    " value held by such variable before making the change and will restore the original value upon conclusion of the
    " test.
    let l:orig_llmchat_auth_token = ''    " Assume the variable was set to the empty string by default.
    if exists("b:llmchat_auth_token") && b:llmchat_auth_token != ''
        " In this case the 'b:llmchat_auth_token' was defined and set to a non-empty value so we will backup such value
        " using a locally held variable before proceeding with the test.
        let l:orig_llmchat_auth_token = b:llmchat_auth_token

    endif

    let b:llmchat_auth_token = "The buffer-local token value"


    " Define a partial parse dictionary that indicates auth is required in addition to specifying the required header
    " fields.
     let l:test_parse_dict = {
                          \   "header":
                          \   {
                          \     "server type": "Ollama",
                          \     "server url": "https://localhost",
                          \     "model id": "Test Model",
                          \     "use auth": "true",
                          \   }
                          \ }

    " Invoke the GetAuthToken() function and assert that the expected value is returned.
    AssertEquals(b:llmchat_auth_token, s:util.GetAuthToken(l:test_parse_dict))

    " Restore the original value back to variable 'b:llmchat_auth_token'.
    let b:llmchat_auth_token = l:orig_llmchat_auth_token

endfunction


" This test asserts the behavior of function GetAuthToken() when the chat buffer in use explicitly notes that
" authentication is required and the global auth file variable has been set (no explicit chat token nor buffer-local
" auth will be available in this case).  If working properly the function execution should complete normally and the
" value held the file referenced by the global auth file variable should be returned.
function s:TestGetAuthTokenWithAuthExplicitlyEnabledAndGlobalAuthSet()
    " Request a temporary file from Vim and then output a known testing token value to such file.
    let l:test_token_value = "The test token value"
    let l:temp_file_name = tempname()
    call writefile([l:test_token_value], l:temp_file_name)

    " Set the 'g:llmchat_apikey_file' to hold the temporary file name obtained from Vim earlier.
    let g:llmchat_apikey_file = l:temp_file_name

    " Define a partial parse dictionary that indicates auth is required in addition to specifying the required header
    " fields.
    let l:test_parse_dict = {
                          \   "header":
                          \   {
                          \     "server type": "Ollama",
                          \     "server url": "https://localhost",
                          \     "model id": "Test Model",
                          \     "use auth": "true",
                          \   }
                          \ }

    " Invoke the GetAuthToken() function and assert that the expected value is returned.
    AssertEquals(l:test_token_value, s:util.GetAuthToken(l:test_parse_dict))


    " Cleanup - Remove the temporary file used to hold the test token then restore variable 'g:llmchat_apikey_file' back
    "           to its default testing value.
    call delete(l:temp_file_name)

    let l:global_var_defaults = s:testutil.GetGlobalVariableDefaults()
    let g:llmchat_apikey_file = l:global_var_defaults["g:llmchat_apikey_file"]

endfunction


" This test asserts the behavior of function GetAuthToken() when the chat buffer in use does not define if auth is
" required but the global auth file variable has been set.  If working properly the function execution should complete
" normally and the value held by the file referenced by the global auth file variable should be returned.
function s:TestGetAuthTokenWithAuthImplicitlyEnabledAndGlobalAuthSet()
    " Request a temporary file from Vim and then output a known testing token value to such file.
    let l:test_token_value = "The test token value"
    let l:temp_file_name = tempname()
    call writefile([l:test_token_value], l:temp_file_name)

    " Set the 'g:llmchat_apikey_file' to hold the temporary file name obtained from Vim earlier.
    let g:llmchat_apikey_file = l:temp_file_name

    " Define a partial parse dictionary that specifies the required header fields only (no indication is given as to
    " whether or not auth is required nor is any explicit token given).
    let l:test_parse_dict = {
                          \   "header":
                          \   {
                          \     "server type": "Ollama",
                          \     "server url": "https://localhost",
                          \     "model id": "Test Model",
                          \   }
                          \ }

    " Invoke the GetAuthToken() function and assert that the expected value is returned.
    AssertEquals(l:test_token_value, s:util.GetAuthToken(l:test_parse_dict))


    " Cleanup - Remove the temporary file used to hold the test token then restore variable 'g:llmchat_apikey_file' back
    "           to its default testing value.
    call delete(l:temp_file_name)

    let l:global_var_defaults = s:testutil.GetGlobalVariableDefaults()
    let g:llmchat_apikey_file = l:global_var_defaults["g:llmchat_apikey_file"]

endfunction


" This test assert the behavior of function GetAuthToken() when the chat buffer in use explicitly notes that auth is
" required but NO auth token can be resolved (i.e., the chat does NOT provide any token to use and neither the
" buffer-local auth variable nor the global auth file variable are set).  For such case an exception should be thrown
" with a message indicating that token resolution has failed.
function s:TestGetAuthTokenWithExplicitlyEnabledAuthAndFailedTokenResolution()
    " Define a partial parse dictionary that indicates auth is required in addition to specifying the required header
    " fields.
    let l:test_parse_dict = {
                          \   "header":
                          \   {
                          \     "server type": "Ollama",
                          \     "server url": "https://localhost",
                          \     "model id": "Test Model",
                          \     "use auth": "true",
                          \   }
                          \ }

    try
        " Attempt to invoke the GetAuthToken() function; this should prompt an exception to be thrown as there should be
        " no way for the function to resolve the auth token to be used.
        call s:util.GetAuthToken(l:test_parse_dict)


        " If the test logic reaches this point than fail the test; the proper behavior would have been for the
        " GetAuthToken() to throw an exception which would have made this statement unreachable.
        call s:testutil.Fail(expand('<sflnum>') - 9,
                           \ "Expected to see an exception thrown from function send_chat#GetAuthToken() when it " ..
                           \ "was invoked in a way that (1) the function call understood that auth was required but " ..
                           \ "(2) there was way to resolve the auth token to return; however, no exception occurred.")

    catch /\c[error].*no token.*could be resolved.*/
        " If the logic comes here than we seem to have caught an exception that indicates the fault we were hoping
        " to prompt; allow the test to proceed as the logic being verified appears to be working.
    endtry

endfunction



" ********************************************
" ****  ParseChatOption() Function Tests  ****
" ********************************************

" This test asserts the behavior of function ParseChatOption() when it is provided with a valid option definition to
" parse.  The function execution should complete normally and return a 2-element list holding expected values if the
" logic is working as intended.
function s:TestParseChatOptionWithValidArgs()
    " ---------------------------------------------------------------------
    " --- Condition #1 - No Whitespace in Option Name or Value Segments ---
    " ---------------------------------------------------------------------
    " Invoke the ParseChatOption() function using an 'option_text' argument that holds a valid definition and whose
    " name/value segments contain no whitespace.
    let l:result_list = s:util.ParseChatOption("Option:abc=def", 0)

    AssertEquals("abc", l:result_list[0])
    AssertEquals("def", l:result_list[1])


    " ----------------------------------------------------------------------------
    " --- Condition #2 - Whitespace Used Within Option Name and Value Segments ---
    " ----------------------------------------------------------------------------
    " Invoke the ParseChatOption() function using an 'option_text' argument that holds a valid definition and whose
    " name/value segments contain internal whitespace (i.e., whitespace that belongs to either the name or the value
    " segment).
    let l:result_list = s:util.ParseChatOption("Option:a b  c=d e  f", 0)

    AssertEquals("a b  c", l:result_list[0])
    AssertEquals("d e  f", l:result_list[1])


    " ------------------------------------------------------------------------------------------------------
    " --- Condition #3 - Whitespace Used In Option Name and Value Along with Leading/Trailing Whitespace ---
    " ------------------------------------------------------------------------------------------------------
    " Invoke the ParseChatOption() function using an 'option_text' argument that holds a valid definition and whose
    " name/value segments contain internal whitespace (i.e., whitespace that belongs to either the name or value
    " segment) as well as leading and trailing whitespace (i.e., whitespace that should be removed).
    let l:result_list = s:util.ParseChatOption("Option:   a  b c   =    d  e f     ", 0)

    AssertEquals("a  b c", l:result_list[0])
    AssertEquals("d  e f", l:result_list[1])

endfunction


" This test asserts that an exception is thrown from function ParseChatOption() when it is invoked to parse an option
" definition that has no '=' symbol within its value.
function s:TestParseChatOptionWithMissingValueSeparator()
    try
        " Try invoking the ParseChatOption() function using an 'option_text' argument whose value lacks an '=' symbol.
        call s:util.ParseChatOption("Option: abcdefg", 0)

        " If the logic reaches this point than fail the test.  We expected to see an exception thrown if the logic was
        " working correctly so this line should never be reached.
        call s:testutil.Fail(expand('<sflnum>') - 9,
                           \ "Expected to see an exception thrown from the ParseChatOption() function when the " ..
                           \ "'option_text' argument given to it consisted of an option declaration whose value " ..
                           \ "was NOT in a=b format; however, no exception occurred.")

    catch /\c[error].*no '=' symbol.*/
        " If the logic comes here than we've caught an exception whose message holds the identifier fragments we were
        " looking for; assume that things are working as intended and allow the test to pass.
    endtry

endfunction


" This test asserts that an exception is thrown from function ParseChatOption() when it is invoked to parse an option
" definition whose associated value has no "name" segment.
function s:TestParseChatOptionWithMissingNameSegment()
    try
        " Try invoking the ParseChatOption() function using an 'option_text' argument whose value lacks a 'name'
        " segment.
        call s:util.ParseChatOption("Option: =abcdefg", 0)

        " If the logic reaches this point than fail the test.  We expected to see an exception thrown if the logic was
        " working correctly so this line should never be reached.
        call s:testutil.Fail(expand('<sflnum>') - 9,
                           \ "Expected to see an exception thrown from the ParseChatOption() function when the " ..
                           \ "'option_text' argument given to it consisted of an option declaration whose value was " ..
                           \ "lacking a non-empty 'name' segment; however, no exception occurred.")

    catch /\c[error].*'name'.*was absent.*/
        " If the logic comes here than we've caught an exception whose message holds the identifier fragments we were
        " looking for; assume that things are working as intended and allow the test to pass.
    endtry

endfunction


" This test asserts that an exception is thrown from function ParseChatOption() when it is invoked to parse an option
" definition whose associated value has no "value" segment.
function s:TestParseChatOptionWithMissingValueSegment()
    try
        " Try invoking the ParseChatOption() function using an 'option_text' argument whose value lacks a 'value'
        " segment.
        call s:util.ParseChatOption("Option: abcdefg=  ", 0)

        " If the logic reaches this point than fail the test.  We expected to see an exception thrown if the logic was
        " working correctly so this line should never be reached.
        call s:testutil.Fail(expand('<sflnum>') - 9,
                           \ "Expected to see an exception thrown from the ParseChatOption() function when the " ..
                           \ "'option_text' argument given to it consisted of an option declaration whose value " ..
                           \ "was lacking a non-empty 'value' segment; however, no exception occurred.")

    catch /\c[error].*'value'.*was absent.*/
        " If the logic comes here than we've caught an exception whose message holds the identifier fragments we were
        " looking for; assume that things are working as intended and allow the test to pass.
    endtry

endfunction



" ***************************************************
" ****  EscapeSpecialSequences() Function Tests  ****
" ***************************************************

" This test asserts the proper operation of function EscapeSpecialSequences().  To do this the test will invoke the
" function using a number of various input strings and it will then assert that the outputs returned match to expected
" result values (where such results show what escaping should have been performed if any).
function s:TestEscapeSpecialSequences()
    " Define a list that will contain the sequence of input text values this test will use for verifying the proper
    " behavior of the EscapeSpecialSequences() function.
    let l:input_list =
      \ [
      \   "Some text that has NO sequences to escape.",
      \   ">>>",
      \   "<<<",
      \   "=>>",
      \   "<<=",
      \   "[",
      \   ">>>Multiple >>> tokens to escape>>>",
      \   "<<<Multiple <<<< tokens to escape<<<",
      \   "=>>Multiple =>> tokens to escape=>>",
      \   "<<=Multiple <<= tokens to escape<<=",
      \   "Mixed <<= tokens<<<within the text=>> value.",
      \   "\\>>> Escaped \\<<< escape \\=>> sequences \\<<= within text."
      \ ]

    " Define a list that will contain the sequence of expected output values the test expects to see the
    " EscapeSpecialSequences() function return during testing.  Note that this list is paired to the 'l:input_list' by
    " index such that the input value at index N in that list should have the expected output value from index N in this
    " list.
    let l:expected_list =
      \ [
      \   "Some text that has NO sequences to escape.",
      \   "\\>>>",
      \   "\\<<<",
      \   "\\=>>",
      \   "\\<<=",
      \   "\\[",
      \   "\\>>>Multiple \\>>> tokens to escape\\>>>",
      \   "\\<<<Multiple \\<<<< tokens to escape\\<<<",
      \   "\\=>>Multiple \\=>> tokens to escape\\=>>",
      \   "\\<<=Multiple \\<<= tokens to escape\\<<=",
      \   "Mixed \\<<= tokens\\<<<within the text\\=>> value.",
      \   "\\\\>>> Escaped \\\\<<< escape \\\\=>> sequences \\\\<<= within text."
      \ ]

    " Now cycle over each value held by the 'l:input_list', pass each one to the EscapeSpecialSequences() function,
    " and assert that an expected output result is returned.
    let l:test_cntr = 0
    let l:test_input_size = len(l:input_list)

    while l:test_cntr < l:test_input_size
        let l:actual_result = s:util.EscapeSpecialSequences(l:input_list[l:test_cntr])
        if l:actual_result !=# l:expected_list[l:test_cntr]
            " In this case the actual output obtained did NOT match to what we expected.  Construct a meaningful
            " failure message for the test and then call a utliity function to mark the failure.
            let l:failure_message = "Test failed for condition " .. l:test_cntr .. "; expected to see '" ..
                                 \  l:expected_list[l:test_cntr] .. "' returned but instead recevied '" ..
                                 \  l:actual_result .. "'"

            " NOTE: The vim-UT plugin does not handle message reporting well when such messages contain newline
            "       sequences; make sure to escape all such sequences in the message before failing the test.
            call s:testutil.Fail(expand('<sflnum>') - 9, substitute(l:failure_message, '\v\n', "\\n", "g"))

        endif

        " Increment the 'l:test_cntr' by 1 before the next loop iteration.
        let l:test_cntr = l:test_cntr + 1

    endwhile

endfunction



" *****************************************************
" ****  UnescapeSpecialSequences() Function Tests  ****
" *****************************************************

" This test asserts the proper operation of function UnescapeSpecialSequences().  To do this the test will invoke the
" function using a number of various input strings and it will then assert that the outputs returned match to expected
" result values (where such results show what unescaping should have been performed if any).
function s:TestUnescapeSpecialSequences()
    " Define a list that will contain the sequence of input text values this test will use for verifying the proper
    " behavior of the UnescapeSpecialSequences() function.
    let l:input_list =
      \ [
      \   "Some text that has NO sequences to unescape.",
      \   "\\>>>",
      \   "\\<<<",
      \   "\\=>>",
      \   "\\<<=",
      \   "\\[",
      \   "\\>>>Multiple \\>>> tokens to escape\\>>>",
      \   "\\<<<Multiple \\<<<< tokens to escape\\<<<",
      \   "\\=>>Multiple \\=>> tokens to escape\\=>>",
      \   "\\<<=Multiple \\<<= tokens to escape\\<<=",
      \   "Mixed \\<<= tokens\\<<<within the text\\=>> value.",
      \   "\\\\>>> Escaped \\\\<<< escape \\\\=>> sequences\\\\[ \\\\<<= within text.",
      \   "Text with an escaped \\n sequence.",
      \   "Text \\n with \\n many \\n escaped \\n newlines"
      \ ]


    " Define a list that will contain the sequence of expected output values the test expects to see the
    " UnescapeSpecialSequences() function return during testing.  Note that this list is paired to the 'l:input_list' by
    " index such that the input value at index N in that list should have the expected output value from index N in this
    " list.
    let l:expected_list =
      \ [
      \   "Some text that has NO sequences to unescape.",
      \   ">>>",
      \   "<<<",
      \   "=>>",
      \   "<<=",
      \   "[",
      \   ">>>Multiple >>> tokens to escape>>>",
      \   "<<<Multiple <<<< tokens to escape<<<",
      \   "=>>Multiple =>> tokens to escape=>>",
      \   "<<=Multiple <<= tokens to escape<<=",
      \   "Mixed <<= tokens<<<within the text=>> value.",
      \   "\\>>> Escaped \\<<< escape \\=>> sequences\\[ \\<<= within text.",
      \   "Text with an escaped \n sequence.",
      \   "Text \n with \n many \n escaped \n newlines"
      \ ]

    " Now cycle over each value held by the 'l:input_list', pass each one to the UnescapeSpecialSequences() function,
    " and assert that an expected output result is returned.
    let l:test_cntr = 0
    let l:test_input_size = len(l:input_list)

    while l:test_cntr < l:test_input_size
        let l:actual_result = s:util.UnescapeSpecialSequences(l:input_list[l:test_cntr])
        if l:actual_result !=# l:expected_list[l:test_cntr]
            " In this case the actual output obtained did NOT match to what we expected.  Construct a meaningful
            " failure message for the test and then call a utliity function to mark the failure.
            let l:failure_message = "Test failed for condition " .. l:test_cntr .. "; expected to see '" ..
                                 \  l:expected_list[l:test_cntr] .. "' returned but instead recevied '" ..
                                 \  l:actual_result .. "'"

            " NOTE: The vim-UT plugin does not handle message reporting well when such messages contain newline
            "       sequences; make sure to escape all such sequences in the message before failing the test.
            call s:testutil.Fail(expand('<sflnum>') - 9, substitute(l:failure_message, '\v\n', "\\n", "g"))

        endif

        " Increment the 'l:test_cntr' by 1 before the next loop iteration.
        let l:test_cntr = l:test_cntr + 1

    endwhile

endfunction


"
" =========================================  End Standalone Tests  =========================================
"


" This function is responsible for restoring the editor state following the execution of the unit tests in this file.
" Primarily this will consist of taking the following actions:
"
"   1). Check for the existance of script local "backup variables" that were used to preserve editor state information
"       during the execution of function BeforeAll() and restore the values they hold to the appropriate global scope
"       variables.
"
function s:AfterAll()
    " Call a test utility function to handle the value restoration to any global variable that was reset when this test
    " began execution.
    call s:testutil.RestoreGlobalVars(s:restore_values_dict)

endfunction

