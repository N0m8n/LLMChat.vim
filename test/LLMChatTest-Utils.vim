
UTSuite LLMChat Utility Tests

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
" ========================================= Start Test Utilities =============================================
"
" This section contains functions that are used to support tests found within this file but which do not perform any
" direct testing themselves.
"

"
function s:DetectVerticalSpaceLossOnSplit(tab_num = tabpagenr())
    " Begin by verifying that the tab whose identifying number was given to us contains ONLY a single window.
    let l:layout_array = winlayout(a:tab_num)

    if len(l:layout_array) != 2 || l:layout_array[0] != "leaf"
        " In this case the layout array indicates that the current tab does not meet the assumptions imposed by this
        " function for proper operation; throw an exception whose message details the problem encountered.
        throw "[ERROR] - The layout array returned from function winlayout() does NOT meet the requirements of " ..
           \ "this function for proper operation.  This array was expected to contain only two elements, the " ..
           \ "first of which should have contained the string 'leaf'; this would have indicated that the tab " ..
           \ "contained a single window that could be used for the necessary computation.  Instead the layout " ..
           \ "array returned for tab " .. tab_num .. " was: " .. string(l:layout_array)

    endif


    " If the logic comes here than we assume that we have verified the tab contains only a single window.  Go ahead
    " and check if the given tab is active and if not than switch to it.
    let l:curr_tab = tabpagenr()
    if l:curr_tab != a:tab_num
        execute 'tabnext ' .. a:tab_num
    endif


    " Now invoke function winheight() and save the number returned as the total height of the tab window.
    let l:initial_win_height = winheight(l:layout_array[1])


    " Split the window in the tab horizontally then lookup the heights for both windows; store these into some
    " local variables for later computation.
    execute "split"
    let l:layout_array = winlayout(a:tab_num)
    let l:win_1_height = winheight(l:layout_array[1][0][1])
    let l:win_2_height = winheight(l:layout_array[1][1][1])


    " Unsplit the tab window so we can return it to its original state.
    execute "hide"


    " Check to see if we changed tabs at the start of the function execution and if so than restore focus to the
    " original tab.
    if l:curr_tab != a:tab_num
        execute 'tabnext ' .. l:curr_tab
    endif


    " Now subtract the sum of the heights of the windows in the horizontal split configuration from the total height
    " of the single window and return the difference.  If no display elements cause a loss of vertical space when a
    " horizontal split is made than 0 will be returned; otherwise the vertical thickness of the visual element that
    " is injected will be returned instead.
    return l:initial_win_height - (l:win_1_height + l:win_2_height)

endfunction


" =========================================== End Test Utilities =============================================


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
        \ "\nMax Context Messages: 3" ..
        \ "\nMessage Register: b" ..
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
        \ "\n     Yes, I would like to know what the secret to life happens      " ..
        \ "\nto be.  Can you give me some insight?    " ..
        \ "\n<<<" ..
        \ "\n" ..
        \ "\n#Assistant response with leading and trailing whitespace" ..
        \ "\n=>>" ..
        \ "\n     That is a great question!  Unfortunately I don't have an    " ..
        \ "\nanswer to give you; life seems to be what you make of it.    " ..
        \ "\n<<=" ..
        \ "\n" ..
        \ "\n----------------------" ..
        \ "\n" ..
        \ "\n#Unfinished chat interaction (1) resources given and (2) with no assistant response." ..
        \ "\n>>>    I'm told this paper might know; can you read it" ..
        \ "\nand let me know what you think?   "


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
                              \       "max context": 3,
                              \       "message register": "b",
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
                              \         "assistant": "I am an AI so I don't have any feelings." ..
                              \                    "\nHow can I help you today?"
                              \       },
                              \       {
                              \         "user": "Yes, I would like to know what the secret to life happens\n" ..
                              \                 "to be.  Can you give me some insight?",
                              \         "assistant": "That is a great question!  Unfortunately I don't have an\n" ..
                              \                      "answer to give you; life seems to be what you make of it."
                              \       },
                              \       {
                              \         "user": "I'm told this paper might know; can you read it\n" ..
                              \                 "and let me know what you think?"
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


" This test will attempt to invoke function ParseChatBufferToBlocks() to parse the content of a new chat buffer holding
" a known good chat document while debug mode is enabled.  If working as expected the parse should succeed and NO debug
" information should be output (debug data should ONLY be written out if the parse fails).
function s:TestParseChatBufferToBlocksWithGoodDocAndDebugModeEnabled()
    " Request the name and path to a temporary file from Vim and then set such temporary file as the target for debug
    " mode (this will implicitly enable debug mode).
    let l:debug_target = tempname()
    let g:llmchat_debug_mode_target = l:debug_target

    " Define a "maximal" chat document (i.e., a document containing at least one example of all allowed content
    " structures).
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
        \ "\nMax Context Messages: 3" ..
        \ "\nMessage Register: B" ..
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
        \ "\n     Yes, I would like to know what the secret to life happens" ..
        \ "\nto be.  Can you give me some insight?    " ..
        \ "\n<<<" ..
        \ "\n" ..
        \ "\n#Assistant response with leading and trailing whitespace" ..
        \ "\n=>>" ..
        \ "\n     That is a great question!  Unfortunately I don't have an" ..
        \ "\nanswer to give you; life seems to be what you make of it.    " ..
        \ "\n<<=" ..
        \ "\n" ..
        \ "\n----------------------" ..
        \ "\n" ..
        \ "\n#Unfinished chat interaction (1) resources given and (2) with no assistant response." ..
        \ "\n>>>    I'm told this paper might know; can you read it" ..
        \ "\nand let me know what you think?   "


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
                              \       "max context": 3,
                              \       "message register": "B",
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
                              \         "assistant": "I am an AI so I don't have any feelings.\n" ..
                              \                      "How can I help you today?"
                              \       },
                              \       {
                              \         "user": "Yes, I would like to know what the secret to life happens\n" ..
                              \                 "to be.  Can you give me some insight?",
                              \         "assistant": "That is a great question!  Unfortunately I don't have an\n" ..
                              \                      "answer to give you; life seems to be what you make of it."
                              \       },
                              \       {
                              \         "user": "I'm told this paper might know; can you read it\n" ..
                              \                 "and let me know what you think?"
                              \       }
                              \     ],
                              \   "flags":
                              \     {
                              \       "no-user-message-close": ""
                              \     }
                              \ }

    call s:testutil.AssertEqualDictionaries(expand('<sflnum>') - 9, '', l:expected_parse_dict, l:actual_parse_dict)

    " Assert that the debug log is NOT readable to Vim (this essentially asserts that no such log exists on disk).
    AssertTxt(!filereadable(l:debug_target),
            \ "Did not expect to find any debug output at path '" .. l:debug_target .. "' but instead found a " ..
            \ "readable file.")

    " Finally, cleanup by performing the following tasks:
    "
    "   1). Forcefully delete the new buffer without saving its content.
    "   2). Unset the 'g:llmchat_debug_mode_target' variable to disable debug mode.
    "   3). Remove the 'l:debug_target' from disk now that testing is complete.
    "
    bd!
    unlet g:llmchat_debug_mode_target
    call delete(l:debug_target)

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

    " Invoke the ParseChatBufferToBlocks() function to parse the content of the new buffer and return back to us a parse
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
                              \         "user": "A user message containing" ..
                              \                 "\n    embedded whitespace sequences" ..
                              \                 "\n" ..
                              \                 "\n        And some inset text.",
                              \         "assistant": "An assistant message containing" ..
                              \                      "\n     embedded whitespace sequences" ..
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

    " Invoke the ParseChatBufferToBlocks() function to parse the content of the new buffer using the "header_only_parse"
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


" This test verifies the behavior of function ParseChatBufferToBlocks() when it is invoked to parse a chat document
" that is missing the 'Model ID' chat option AND the 'require_model' argument was provided as 'false'.
function s:TestParseChatBufferToBlocksWithMissingModelIDAndSuppressedModelIDCheck()
    " Define an example chat log document that contains header only content and which is missing any model ID
    " declaration.
    let l:test_doc = "Server Type: Ollama" ..
                 \ "\nServer URL: https://testllms.com" ..
                 \ "\n**** ENDSETUP ***"


    " Open a new buffer then write the content of variable 'l:test_doc' to it.  Note that we will use the 'put!' command
    " so that content is inserted BEFORE the first line in the buffer and we'll leave the trailing newline resulting
    " from the downshift of the first buffer line (the parse should ignore this so there should not need to be any
    " special effort exerted to clean it up).
    "
    " NOTE: When the 'new' command is run we expect focus to automatically shift to the new testing buffer; for this
    "       reason no code is included to shift focus to the newly opened buffer.
    new
    silent! put! = l:test_doc


    " Invoke the ParseChatBufferToBlocks() function to perform a header-only parse of the new buffer and provide
    " argument 'require_model' as 0 so that model ID validation is disabled.
    let l:actual_parse_dict = s:util.ParseChatBufferToBlocks(1, bufnr(), 0)


    " Now define an expected parse dictionary and show that the 'l:actual_parse_dict' returned earlier from the parsing
    " process is identical to it.
    let l:expected_parse_dict = {
                              \   "header":
                              \   {
                              \     "server type": "Ollama",
                              \     "server url": "https://testllms.com"
                              \   }
                              \ }

    call s:testutil.AssertEqualDictionaries(expand('<sflnum>') - 9, '', l:expected_parse_dict, l:actual_parse_dict)

    " Finally, cleanup by performing the following tasks:
    "
    "  1). Forcefully delete the new buffer without saving its content.
    "
    bd!

endfunction


" This test verifies the behavior of function ParseChatBufferToBlocks() when it is invoked to parse a chat document
" that has an empty value given for its 'Model ID' chat option AND the 'require_model' argument was provided as 'false'.
function s:TestParseChatBufferToBlocksWithEmptyModelIDAndSuppressedModelIDCheck()
    " Define an example chat log document that contains header only content and which has an empty model ID
    " declaration.
    let l:test_doc = "Server Type: Ollama" ..
                 \ "\nServer URL: https://testllms.com" ..
                 \ "\nModel ID: " ..
                 \ "\n**** ENDSETUP ***"


    " Open a new buffer then write the content of variable 'l:test_doc' to it.  Note that we will use the 'put!' command
    " so that content is inserted BEFORE the first line in the buffer and we'll leave the trailing newline resulting
    " from the downshift of the first buffer line (the parse should ignore this so there should not need to be any
    " special effort exerted to clean it up).
    "
    " NOTE: When the 'new' command is run we expect focus to automatically shift to the new testing buffer; for this
    "       reason no code is included to shift focus to the newly opened buffer.
    new
    silent! put! = l:test_doc


    " Invoke the ParseChatBufferToBlocks() function to perform a header-only parse of the new buffer and provide
    " argument 'require_model' as 0 so that model ID validation is disabled.
    let l:actual_parse_dict = s:util.ParseChatBufferToBlocks(1, bufnr(), 0)


    " Now define an expected parse dictionary and show that the 'l:actual_parse_dict' returned earlier from the parsing
    " process is identical to it.
    let l:expected_parse_dict = {
                              \   "header":
                              \   {
                              \     "server type": "Ollama",
                              \     "server url": "https://testllms.com"
                              \   }
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
      \ "\nThis should not cause any trouble for the parsing and such " ..
      \ "\nsequences should be properly unescaped by the parsing logic." ..
      \ "\n<<<" ..
      \ "\n=>>An assistant message that contains the following escaped " ..
      \ "\nsequences:" ..
      \ "\n\\>>>" ..
      \ "\n\\<<<" ..
      \ "\n\\=>>" ..
      \ "\n\\<<=" ..
      \ "\n\\n" ..
      \ "\nThis should not cause any trouble for the parsing and such   " ..
      \ "\nsequences should be properly unescaped by the parsing logic." ..
      \ "\n<<=" ..
      \ "\n>>>User message showing *escaped* escape sequences:" ..
      \ "\n\\\\>>>" ..
      \ "\n\\\\<<<" ..
      \ "\n\\\\=>>" ..
      \ "\n\\\\<<=" ..
      \ "\n\\\\n" ..
      \ "\nAgain, should cause no problem for the parsing and should be" ..
      \ "\nunescaped to the escape sequences." ..
      \ "\n<<<" ..
      \ "\n=>>Assistant message showing *escaped* escape sequences:" ..
      \ "\n\\\\>>>" ..
      \ "\n\\\\<<<" ..
      \ "\n\\\\=>>" ..
      \ "\n\\\\<<=" ..
      \ "\n\\\\n" ..
      \ "\nAgain, should cause no problem for the parsing and should be " ..
      \ "\nunescaped to the escape sequences"..
      \ "\n<<="

    " Open a new buffer then write the content of variable 'l:example_chat_doc' to it.  Note that we will use the 'put!'
    " command so that content is inserted BEFORE the first line in the buffer and we'll leave the trailing newline
    " resulting from the downshift of the first buffer line (the parse should ignore this so there should not need to
    " be any special effort exerted here in cleaning it up).
    new
    silent! put! = l:example_chat_doc

    " Invoke the ParseChatBufferToBlocks() function to parse the content of the new buffer and return back to us a parse
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
                              \         "user": "A user message that contains the following escaped sequences:" ..
                              \               "\n>>>" ..
                              \               "\n<<<" ..
                              \               "\n=>>" ..
                              \               "\n<<=" ..
                              \               "\n" ..
                              \               "\n" ..
                              \               "\nThis should not cause any trouble for the parsing and such" ..
                              \               "\nsequences should be properly unescaped by the parsing logic.",
                              \         "assistant" : "An assistant message that contains the following escaped" ..
                              \                     "\nsequences:" ..
                              \                     "\n>>>" ..
                              \                     "\n<<<" ..
                              \                     "\n=>>" ..
                              \                     "\n<<=" ..
                              \                     "\n" ..
                              \                     "\n" ..
                              \                     "\nThis should not cause any trouble for the parsing and such" ..
                              \                     "\nsequences should be properly unescaped by the parsing logic."
                              \       },
                              \       {
                              \         "user": "User message showing *escaped* escape sequences:" ..
                              \               "\n\\>>>" ..
                              \               "\n\\<<<" ..
                              \               "\n\\=>>" ..
                              \               "\n\\<<=" ..
                              \               "\n\\\n" ..
                              \               "\nAgain, should cause no problem for the parsing and should be" ..
                              \               "\nunescaped to the escape sequences.",
                              \         "assistant": "Assistant message showing *escaped* escape sequences:" ..
                              \                    "\n\\>>>" ..
                              \                    "\n\\<<<" ..
                              \                    "\n\\=>>" ..
                              \                    "\n\\<<=" ..
                              \                    "\n\\\n" ..
                              \                    "\nAgain, should cause no problem for the parsing and should be" ..
                              \                    "\nunescaped to the escape sequences"
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


" This test asserts the proper operation of function ParseChatBufferToBlocks() when the chat buffer being processed
" contains a system prompt with escape sequences in its text.
function s:TestParseChatBufferToBlocksWithSystemPromptContainingEscapeSequences()
    " Define a chat log document that contains a system prompt with escaped special sequences.
    let l:test_chat_doc =
        \   "Server URL: https://somehost" ..
        \ "\nServer Type: Ollama" ..
        \ "\nModel ID: Some model" ..
        \ "\nSystem Prompt: A system prompt" ..
        \ "\n\\n" ..
        \ "\n\\n" ..
        \ "\nthat contains escaped \\>>>" ..
        \ "\n\\n" ..
        \ "\n\\n" ..
        \ "\n\\n" ..
        \ "\nspecial sequences\\n" ..
        \ "\n\\[foo]" ..
        \ "\n" ..
        \ "\n*** ENDSETUP ***"

    " Open a new buffer then write the content of variable 'l:test_chat_doc' to it.  Note that we will use the 'put!'
    " command so that content is inserted BEFORE the first line in the buffer and we'll leave the trailing newline
    " resulting from the downshift of the buffer's initial line (the parse should ignore this so there should not need
    " to be any special effort exerted here in cleaning it up).
    new
    silent! put! = l:test_chat_doc

    " Invoke the ParseChatBufferToBlocks() function to perform a header only parse and store the dictionary that is
    " returned.
    let l:actual_parse_dict = s:util.ParseChatBufferToBlocks(1)

    " Now define an expected parse dictionary and show that the 'l:actual_parse_dict' returned from parsing the chat
    " log document is identical to it.
    let l:expected_parse_dict = {
                              \   "header":
                              \   {
                              \     "server url": "https://somehost",
                              \     "server type": "Ollama",
                              \     "model id": "Some model",
                              \     "system prompt": "A system prompt\n\n" ..
                              \                      " that contains escaped >>>\n\n\n " ..
                              \                      "special sequences\n " ..
                              \                      "[foo]"
                              \   }
                              \ }

    call s:testutil.AssertEqualDictionaries(expand('<sflnum>') - 9, '', l:expected_parse_dict, l:actual_parse_dict)

    " Finally, cleanup by performing the following tasks:
    "
    "  1). Forcefully delete the new buffer without saving its content.
    "
    bd!

endfunction


" This test asserts the proper operation of function ParseChatBufferToBlocks() when the chat buffer being processed
" contains a system prompt with a dynamic embedding reference within it.
function s:TestParseChatBufferToBlocksWithSystemPromptContainingDynamicEmbeddingReference()
    " Create a new buffer then write a set of known lines to it.
    "
    " NOTE: When a new buffer is created it will come with an initial line already and adding content to the buffer via
    "       the 'put' command will shift this line down.  For our purposes here we don't really care that such line is
    "       present but we do need to make sure we account for its presence when we validate the embedding result
    "       later.
    "
    let l:embedding_content = "Some information\nwritten out to a\ntesting buffer.\n" ..
                           \  "Note that special references like\nthe following should NOT be unescaped:" ..
                           \  "\n\\>>>\n\\<<<\n\\=>>\n\\<<=\n\\n"

    new
    silent! put! = l:embedding_content

    " Capture the numerical identifier for the newly created buffer into a local variable for later use.  Note that
    " we assume our focus was shifted to the new buffer when it was created so the logic here will simply store the
    " identifier for the active buffer.
    let l:embedding_buffer = bufnr('')

    " Now define a chat log document that contains a system prompt with a dynamic embedding reference to the
    " previously created buffer.
    let l:test_chat_doc =
        \   "Server URL: https://testdomain.com" ..
        \ "\nServer Type: Open WebUI" ..
        \ "\nModel ID: Test Model" ..
        \ "\nSystem Prompt: A system prompt with the following dynamically embedded text:" ..
        \ "\n[d:@" .. l:embedding_buffer .. "]" ..
        \ "\n" ..
        \ "\n*** ENDSETUP ***"

    " Open another new buffer then write the content of variable 'l:test_chat_doc' to it.  Note that we will use the
    " 'put!' command so that content is inserted BEFORE the first line in the buffer and we'll leave the trailing
    " newline resulting from the downshift of the buffer's initial line (the parse should ignore this so there should
    " not need to be any special effort exerted here in cleaning it up).
    new
    silent! put! = l:test_chat_doc

    " Invoke the ParseChatBufferToBlocks() function to perform a header only parse and store the dictionary that is
    " returned.
    let l:actual_parse_dict = s:util.ParseChatBufferToBlocks(1)

    " Now define an expected parse dictionary and show that the 'l:actual_parse_dict' returned from parsing the chat
    " log document is identical to it.
    let l:expected_parse_dict = {
                              \   "header":
                              \   {
                              \     "server url": "https://testdomain.com",
                              \     "server type": "Open WebUI",
                              \     "model id": "Test Model",
                              \     "system prompt": "A system prompt with the following dynamically embedded text:" ..
                              \                    "\nSome information" ..
                              \                    "\nwritten out to a" ..
                              \                    "\ntesting buffer." ..
                              \                    "\nNote that special references like" ..
                              \                    "\nthe following should NOT be unescaped:" ..
                              \                    "\n\\>>>" ..
                              \                    "\n\\<<<" ..
                              \                    "\n\\=>>" ..
                              \                    "\n\\<<=" ..
                              \                    "\n\\n"
                              \   }
                              \ }

    call s:testutil.AssertEqualDictionaries(expand('<sflnum>') - 9, '', l:expected_parse_dict, l:actual_parse_dict)

    " Finally, cleanup by performing the following tasks:
    "
    "  1). Remove the test buffer containing the dynamic embedding content.
    "  2). Forcefully delete the test chat buffer without saving its content.
    "
    execute "bd! " .. l:embedding_buffer
    bd!

endfunction


" This test asserts the proper operation of function ParseChatBufferToBlocks() when the chat buffer being processed
" contains a dynamic embedding token at the start of its system prompt.
function s:TestParseChatBuferToBlocksWithStartingDynamicEmbeddingInSystemPrompt()
    " Create a new buffer then write a set of known lines to it.
    "
    " NOTE: When a new buffer is created it will come with an initial line already and adding content to the buffer via
    "       the 'put' command will shift this line down.  For our purposes here we don't really care that such line is
    "       present but we do need to make sure we account for its presence when we validate the embedding result
    "       later.
    "
    let l:embedding_content = "Some information\nwritten out to a\ntesting buffer.\n" ..
                            \ "Note that special references like\nthe following should NOT be unescaped:" ..
                            \ "\n\\>>>\n\\<<<\n\\=>>\n\\<<=\n\\n"

    new
    silent! put! = l:embedding_content

    " Capture the numerical identifier for the newly created buffer into a local variable for later use.  Note that
    " we assume our focus was shifted to the new buffer when it was created so the logic here will simply store the
    " identifier for the active buffer.
    let l:embedding_buffer = bufnr('')


    " Now define a chat log document which contains a system prompt that starts with a dynamic embedding reference to
    " the previously created buffer.
    let l:test_chat_doc =
        \   "Server URL: https://testdomain.com" ..
        \ "\nServer Type: Open WebUI" ..
        \ "\nModel ID: Test Model" ..
        \ "\nSystem Prompt: [d:@" .. l:embedding_buffer .. "]" ..
        \ "\nA system prompt string following previously embedded text." ..
        \ "\n" ..
        \ "\n*** ENDSETUP ***"


    " Open another new buffer then write the content of variable 'l:test_chat_doc' to it.  Note that we will use the
    " 'put!' command so that content is inserted BEFORE the first line in the buffer and we'll leave the trailing
    " newline resulting from the downshift of the buffer's initial line (the parse should ignore this so there should
    " not need to be any special effort exerted here in cleaning it up).
    new
    silent! put! = l:test_chat_doc

    " Invoke the ParseChatBufferToBlocks() function to perform a header only parse and store the dictionary that is
    " returned.
    let l:actual_parse_dict = s:util.ParseChatBufferToBlocks(1)

    " Now define an expected parse dictionary and show that the 'l:actual_parse_dict' returned from parsing the chat
    " log document is identical to it.
    let l:expected_parse_dict = {
                              \   "header":
                              \   {
                              \     "server url": "https://testdomain.com",
                              \     "server type": "Open WebUI",
                              \     "model id": "Test Model",
                              \     "system prompt": "\nSome information" ..
                              \                      "\nwritten out to a" ..
                              \                      "\ntesting buffer." ..
                              \                      "\nNote that special references like" ..
                              \                      "\nthe following should NOT be unescaped:" ..
                              \                      "\n\\>>>" ..
                              \                      "\n\\<<<" ..
                              \                      "\n\\=>>" ..
                              \                      "\n\\<<=" ..
                              \                      "\n\\n" ..
                              \                      "\n A system prompt string following previously embedded text."
                              \   }
                              \ }

    call s:testutil.AssertEqualDictionaries(expand('<sflnum>') - 9, '', l:expected_parse_dict, l:actual_parse_dict)

    " Finally, cleanup by performing the following tasks:
    "
    "  1). Remove the test buffer containing the dynamic embedding content.
    "  2). Forcefully delete the test chat buffer without saving its content.
    "
    execute "bd! " .. l:embedding_buffer
    bd!

endfunction


" This test asserts the proper operation of function ParseChatBufferToBlocks() when the chat buffer being processed
" contains a user message that holds a dynamic embedding reference within it.
function s:TestParseChatBufferToBlocksWithUserMessageContainingDynamicEmbeddingReference()
    " Create a new buffer then write a set of known lines to it.
    "
    " NOTE: When a new buffer is created it will come with an initial line already and adding content to the buffer via
    "       the 'put' command will shift this line down.  For our purposes here we don't really care that such line is
    "       present but we do need to make sure we account for its presence when we validate the embedding result
    "       later.
    "
    let l:embedding_content = "Content to be embedded into a\nuser message from another\nbuffer.\n" ..
                            \ "Note that special references like\nthe following should NOT be unescaped:" ..
                            \ "\n\\>>>\n\\<<<\n\\=>>\n\\<<=\n\\n"

    new
    silent! put! = l:embedding_content


    " Capture the numerical identifier for the newly created buffer into a local variable for later use.  Note that
    " we assume our focus was shifted to the new buffer when it was created so the logic here will simply store the
    " identifier for the active buffer.
    let l:embedding_buffer = bufnr('')


    " Now define a chat log document that contains a user message with a dynamic embedding reference to the previously
    " created buffer.
    let l:test_chat_doc =
        \   "Server URL: https://testdomain.com" ..
        \ "\nServer Type: Open WebUI" ..
        \ "\nModel ID: Test Model" ..
        \ "\n*** ENDSETUP ***" ..
        \ "\n>>> A user message that contains the following" ..
        \ "\ndynamic embedding content:" ..
        \ "\n[d:@" .. l:embedding_buffer .. "]" ..
        \ "\n<<<"


    " Open another new buffer then write the content of variable 'l:test_chat_doc' to it.  Note that we will use the
    " 'put!' command so that content is inserted BEFORE the first line in the buffer and we'll leave the trailing
    " newline resulting from the downshift of the buffer's initial line (the parse should ignore this so there should
    " not need to be any special effort exerted here in cleaning it up).
    new
    silent! put! = l:test_chat_doc


    " Invoke the ParseChatBufferToBlocks() function to perform a parse of the chat document buffer content.
    let l:actual_parse_dict = s:util.ParseChatBufferToBlocks()


    " Now define an expected parse dictionary and show that the 'l:actual_parse_dict' returned from parsing the chat
    " log document is identical to it.
    let l:expected_parse_dict = {
                              \   "header":
                              \   {
                              \     "server url": "https://testdomain.com",
                              \     "server type": "Open WebUI",
                              \     "model id": "Test Model",
                              \   },
                              \   "messages":
                              \   [
                              \     {
                              \       "user": "A user message that contains the following" ..
                              \             "\ndynamic embedding content:" ..
                              \             "\nContent to be embedded into a" ..
                              \             "\nuser message from another" ..
                              \             "\nbuffer." ..
                              \             "\nNote that special references like" ..
                              \             "\nthe following should NOT be unescaped:" ..
                              \             "\n\\>>>" ..
                              \             "\n\\<<<" ..
                              \             "\n\\=>>" ..
                              \             "\n\\<<=" ..
                              \             "\n\\n"
                              \     }
                              \   ]
                              \ }

    call s:testutil.AssertEqualDictionaries(expand('<sflnum>') - 9, '', l:expected_parse_dict, l:actual_parse_dict)

    " Finally, cleanup by performing the following tasks:
    "
    "  1). Remove the test buffer containing the dynamic embedding content.
    "  2). Forcefully delete the test chat buffer without saving its content.
    "
    execute "bd! " .. l:embedding_buffer
    bd!

endfunction


" This test asserts the proper operation of function ParseChatBufferToBlocks() when the chat buffer being processed
" contains a dynamic embedding token at the start of a user message.
function s:TestParseChatBufferToBlocksWithStartingDynamicEmbeddingInUserMessage()
    " Create a new buffer then write a set of known lines to it.
    "
    " NOTE: When a new buffer is created it will come with an initial line already and adding content to the buffer via
    "       the 'put' command will shift this line down.  For our purposes here we don't really care that such line is
    "       present but we do need to make sure we account for its presence when we validate the embedding result
    "       later.
    "
    let l:embedding_content = "Content to be embedded into a\nuser message from another\nbuffer.\n" ..
                            \ "Note that special references like\nthe following should NOT be unescaped:" ..
                            \ "\n\\>>>\n\\<<<\n\\=>>\n\\<<=\n\\n"

    new
    silent! put! = l:embedding_content


    " Capture the numerical identifier for the newly created buffer into a local variable for later use.  Note that
    " we assume our focus was shifted to the new buffer when it was created so the logic here will simply store the
    " identifier for the active buffer.
    let l:embedding_buffer = bufnr('')


    " Now define a chat log document which contains a user message that starts with a dynamic embedding reference and
    " output the document to the previously created buffer.
    let l:test_chat_doc =
        \   "Server URL: https://testdomain.com" ..
        \ "\nServer Type: Open WebUI" ..
        \ "\nModel ID: Test Model" ..
        \ "\n*** ENDSETUP ***" ..
        \ "\n>>>[d:@" .. l:embedding_buffer .. "]" ..
        \ "\nA user message that contains a" ..
        \ "\nleading embedding reference." ..
        \ "\n<<<"


    " Open another new buffer then write the content of variable 'l:test_chat_doc' to it.  Note that we will use the
    " 'put!' command so that content is inserted BEFORE the first line in the buffer and we'll leave the trailing
    " newline resulting from the downshift of the buffer's initial line (the parse should ignore this so there should
    " not need to be any special effort exerted here in cleaning it up).
    new
    silent! put! = l:test_chat_doc


    " Invoke the ParseChatBufferToBlocks() function to perform a parse of the chat document buffer content.
    let l:actual_parse_dict = s:util.ParseChatBufferToBlocks()


    " Now define an expected parse dictionary and show that the 'l:actual_parse_dict' returned from parsing the chat
    " log document is identical to it.
    let l:expected_parse_dict = {
                              \   "header":
                              \   {
                              \     "server url": "https://testdomain.com",
                              \     "server type": "Open WebUI",
                              \     "model id": "Test Model",
                              \   },
                              \   "messages":
                              \   [
                              \     {
                              \       "user": "Content to be embedded into a" ..
                              \             "\nuser message from another" ..
                              \             "\nbuffer." ..
                              \             "\nNote that special references like" ..
                              \             "\nthe following should NOT be unescaped:" ..
                              \             "\n\\>>>" ..
                              \             "\n\\<<<" ..
                              \             "\n\\=>>" ..
                              \             "\n\\<<=" ..
                              \             "\n\\n" ..
                              \             "\n" ..
                              \             "\nA user message that contains a" ..
                              \             "\nleading embedding reference."
                              \     }
                              \   ]
                              \ }

    call s:testutil.AssertEqualDictionaries(expand('<sflnum>') - 9, '', l:expected_parse_dict, l:actual_parse_dict)

    " Finally, cleanup by performing the following tasks:
    "
    "  1). Remove the test buffer containing the dynamic embedding content.
    "  2). Forcefully delete the test chat buffer without saving its content.
    "
    execute "bd! " .. l:embedding_buffer
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

    " Invoke the ParseChatBufferToBlocks() function and assert that an exception is thrown whose message indicates the
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


" This test asserts that function ParseChatBufferToBlocks() throws an exception, as well as outputs debug information,
" when the buffer content being processed is missing a server type declaration in its header AND debug mode is enabled.
function s:TestParseChatBufferToBlocksWithMissingServerTypeAndEnabledDebugMode()
    " Request the name and path to a temporary file from Vim and then set such temporary file as the target for debug
    " mode (this will implicitly enable debug mode).
    let l:debug_target = tempname()
    let g:llmchat_debug_mode_target = l:debug_target

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

    " Invoke the ParseChatBufferToBlocks() function and assert that an exception is thrown whose message indicates the
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

    " Assert that the 'l:debug_target' is readable to Vim (i.e., exists on disk) and holds non-empty content.
    AssertTxt(filereadable(l:debug_target),
            \ "Expected to find a debug output file at path '" .. l:debug_target .. "' but no such file existed.")

    let l:debug_text_lines = join(readfile(l:debug_target), "\n")
    AssertTxt(!empty(l:debug_text_lines),
            \ "Expected to find content written to the debug file in use at the completion of testing but such file " ..
            \ "was empty.")

    " Cleanup - Take the following actions now that the test has completed:
    "
    "   1). Forcefully close out the new buffer that was created to hold the test document.
    "   2). Unset the 'g:llmchat_debug_mode_target' variable to disable debug mode.
    "   3). Remove the 'l:debug_target' from disk now that testing is complete.
    "
    bd!
    unlet g:llmchat_debug_mode_target
    call delete(l:debug_target)

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

    " Invoke the ParseChatBufferToBlocks() function and assert that an exception is thrown whose message indicates the
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


" This test asserts that function ParseChatBufferToBlocks() throws an exception, as well as outputs debug information,
" when the buffer content being processed is missing a server URL declaration in its header AND debug mode is enabled.
function s:TestParseChatBufferToBlocksWithMissingServerURLAndEnabledDebugMode()
    " Request the name and path to a temporary file from Vim and then set such temporary file as the target for debug
    " mode (this will implicitly enable debug mode).
    let l:debug_target = tempname()
    let g:llmchat_debug_mode_target = l:debug_target

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

    " Invoke the ParseChatBufferToBlocks() function and assert that an exception is thrown whose message indicates the
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

    " Assert that the 'l:debug_target' is readable to Vim (i.e., exists on disk) and holds non-empty content.
    AssertTxt(filereadable(l:debug_target),
            \ "Expected to find a debug output file at path '" .. l:debug_target .. "' but no such file existed.")

    let l:debug_text_lines = join(readfile(l:debug_target), "\n")
    AssertTxt(!empty(l:debug_text_lines),
            \ "Expected to find content written to the debug file in use at the completion of testing but such file " ..
            \ "was empty.")

    " Cleanup - Take the following actions now that the test has completed:
    "
    "   1). Forcefully close out the new buffer that was created to hold the test document.
    "   2). Unset the 'g:llmchat_debug_mode_target' variable to disable debug mode.
    "   3). Remove the 'l:debug_target' from disk now that testing is complete.
    "
    bd!
    unlet g:llmchat_debug_mode_target
    call delete(l:debug_target)

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

    " Invoke the ParseChatBufferToBlocks() function and assert that an exception is thrown whose message indicates the
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


" This test asserts that function ParseChatBufferToBlocks() throws an exception, as well as outputs debug information,
" when the buffer content being processed is missing a model ID declaration in its header AND debug mode is enabled.
function s:TestParseChatBufferToBlocksWithMissingModelIDAndEnabledDebugMode()
    " Request the name and path to a temporary file from Vim and then set such temporary file as the target for debug
    " mode (this will implicitly enable debug mode).
    let l:debug_target = tempname()
    let g:llmchat_debug_mode_target = l:debug_target

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

    " Invoke the ParseChatBufferToBlocks() function and assert that an exception is thrown whose message indicates the
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

    " Assert that the 'l:debug_target' is readable to Vim (i.e., exists on disk) and holds non-empty content.
    AssertTxt(filereadable(l:debug_target),
            \ "Expected to find a debug output file at path '" .. l:debug_target .. "' but no such file existed.")

    let l:debug_text_lines = join(readfile(l:debug_target), "\n")
    AssertTxt(!empty(l:debug_text_lines),
            \ "Expected to find content written to the debug file in use at the completion of testing but such file " ..
            \ "was empty.")

    " Cleanup - Take the following actions now that the test has completed:
    "
    "   1). Forcefully close out the new buffer that was created to hold the test document.
    "   2). Unset the 'g:llmchat_debug_mode_target' variable to disable debug mode.
    "   3). Remove the 'l:debug_target' from disk now that testing is complete.
    "
    bd!
    unlet g:llmchat_debug_mode_target
    call delete(l:debug_target)

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

    " Invoke the ParseChatBufferToBlocks() function and assert that an exception is thrown whose message indicates the
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


" This test asserts that function ParseChatBufferToBlocks() throws an exception, as well as outputs debug information,
" when the buffer content being processed contains duplicate server type declarations in its header AND debug mode has
" been enabled.
function s:TestParseChatBufferToBlocksWithDuplicateServerTypeDeclAndEnabledDebugMode()
    " Request the name and path to a temporary file from Vim and then set such temporary file as the target for debug
    " mode (this will implicitly enable debug mode).
    let l:debug_target = tempname()
    let g:llmchat_debug_mode_target = l:debug_target

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

    " Invoke the ParseChatBufferToBlocks() function and assert that an exception is thrown whose message indicates the
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

    " Assert that the 'l:debug_target' is readable to Vim (i.e., exists on disk) and holds non-empty content.
    AssertTxt(filereadable(l:debug_target),
            \ "Expected to find a debug output file at path '" .. l:debug_target .. "' but no such file existed.")

    let l:debug_text_lines = join(readfile(l:debug_target), "\n")
    AssertTxt(!empty(l:debug_text_lines),
            \ "Expected to find content written to the debug file in use at the completion of testing but such file " ..
            \ "was empty.")

    " Cleanup - Take the following actions now that the test has completed:
    "
    "   1). Forcefully close out the new buffer that was created to hold the test document.
    "   2). Unset the 'g:llmchat_debug_mode_target' variable to disable debug mode.
    "   3). Remove the 'l:debug_target' from disk now that testing is complete.
    "
    bd!
    unlet g:llmchat_debug_mode_target
    call delete(l:debug_target)

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

    " Invoke the ParseChatBufferToBlocks() function and assert that an exception is thrown whose message indicates the
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


" This test asserts that function ParseChatBufferToBlocks() throws an exception, as well as outputs debug information,
" when the buffer content being processed contains a server type declaration whose associated value is empty AND debug
" mode has been enabled.
function s:TestParseChatBufferToBlocksWithEmptyServerTypeDeclAndEnabledDebugMode()
    " Request the name and path to a temporary file from Vim and then set such temporary file as the target for debug
    " mode (this will implicitly enable debug mode).
    let l:debug_target = tempname()
    let g:llmchat_debug_mode_target = l:debug_target

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

    " Invoke the ParseChatBufferToBlocks() function and assert that an exception is thrown whose message indicates the
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

    " Assert that the 'l:debug_target' is readable to Vim (i.e., exists on disk) and holds non-empty content.
    AssertTxt(filereadable(l:debug_target),
            \ "Expected to find a debug output file at path '" .. l:debug_target .. "' but no such file existed.")

    let l:debug_text_lines = join(readfile(l:debug_target), "\n")
    AssertTxt(!empty(l:debug_text_lines),
            \ "Expected to find content written to the debug file in use at the completion of testing but such file " ..
            \ "was empty.")

    " Cleanup - Take the following actions now that the test has completed:
    "
    "   1). Forcefully close out the new buffer that was created to hold the test document.
    "   2). Unset the 'g:llmchat_debug_mode_target' variable to disable debug mode.
    "   3). Remove the 'l:debug_target' from disk now that testing is complete.
    "
    bd!
    unlet g:llmchat_debug_mode_target
    call delete(l:debug_target)

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

    " Invoke the ParseChatBufferToBlocks() function and assert that an exception is thrown whose message indicates the
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


" This test asserts that function ParseChatBufferToBlocks() throws an exception, as well as outputs debug information,
" when the buffer content being processed contains a duplicate server URL declaration in its header AND debug mode is
" enabled.
function s:TestParseChatBufferToBlocksWithDuplicateServerURLDeclAndEnabledDebugMode()
    " Request the name and path to a temporary file from Vim and then set such temporary file as the target for debug
    " mode (this will implicitly enable debug mode).
    let l:debug_target = tempname()
    let g:llmchat_debug_mode_target = l:debug_target

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

    " Invoke the ParseChatBufferToBlocks() function and assert that an exception is thrown whose message indicates the
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

    " Assert that the 'l:debug_target' is readable to Vim (i.e., exists on disk) and holds non-empty content.
    AssertTxt(filereadable(l:debug_target),
            \ "Expected to find a debug output file at path '" .. l:debug_target .. "' but no such file existed.")

    let l:debug_text_lines = join(readfile(l:debug_target), "\n")
    AssertTxt(!empty(l:debug_text_lines),
            \ "Expected to find content written to the debug file in use at the completion of testing but such file " ..
            \ "was empty.")

    " Cleanup - Take the following actions now that the test has completed:
    "
    "   1). Forcefully close out the new buffer that was created to hold the test document.
    "   2). Unset the 'g:llmchat_debug_mode_target' variable to disable debug mode.
    "   3). Remove the 'l:debug_target' from disk now that testing is complete.
    "
    bd!
    unlet g:llmchat_debug_mode_target
    call delete(l:debug_target)

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

    " Invoke the ParseChatBufferToBlocks() function and assert that an exception is thrown whose message indicates the
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


" This test asserts that function ParseChatBufferToBlocks() throws an exception, as well as outputs debug information,
" when the buffer content being processed contains a server URL declaration in its header whose value is empty AND debug
" mode is enabled.
function s:TestParseChatBufferToBlocksWithEmptyServerURLDeclAndEnabledDebugMode()
    " Request the name and path to a temporary file from Vim and then set such temporary file as the target for debug
    " mode (this will implicitly enable debug mode).
    let l:debug_target = tempname()
    let g:llmchat_debug_mode_target = l:debug_target

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

    " Invoke the ParseChatBufferToBlocks() function and assert that an exception is thrown whose message indicates the
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

    " Assert that the 'l:debug_target' is readable to Vim (i.e., exists on disk) and holds non-empty content.
    AssertTxt(filereadable(l:debug_target),
            \ "Expected to find a debug output file at path '" .. l:debug_target .. "' but no such file existed.")

    let l:debug_text_lines = join(readfile(l:debug_target), "\n")
    AssertTxt(!empty(l:debug_text_lines),
            \ "Expected to find content written to the debug file in use at the completion of testing but such file " ..
            \ "was empty.")


    " Cleanup - Take the following actions now that the test has completed:
    "
    "   1). Forcefully close out the new buffer that was created to hold the test document.
    "   2). Unset the 'g:llmchat_debug_mode_target' variable to disable debug mode.
    "   3). Remove the 'l:debug_target' from disk now that testing is complete.
    "
    bd!
    unlet g:llmchat_debug_mode_target
    call delete(l:debug_target)

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

    " Invoke the ParseChatBufferToBlocks() function and assert that an exception is thrown whose message indicates the
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


" This test asserts that function ParseChatBufferToBlocks() throws an exception, as well as outputs debug information,
" when the buffer content being processed contains a duplicate model ID declaration in its header AND debug mode has
" been enabled.
function s:TestParseChatBufferToBlocksWithDuplicateModelIDDeclAndEnabledDebugMode()
    " Request the name and path to a temporary file from Vim and then set such temporary file as the target for debug
    " mode (this will implicitly enable debug mode).
    let l:debug_target = tempname()
    let g:llmchat_debug_mode_target = l:debug_target

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

    " Invoke the ParseChatBufferToBlocks() function and assert that an exception is thrown whose message indicates the
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

    " Assert that the 'l:debug_target' is readable to Vim (i.e., exists on disk) and holds non-empty content.
    AssertTxt(filereadable(l:debug_target),
            \ "Expected to find a debug output file at path '" .. l:debug_target .. "' but no such file existed.")

    let l:debug_text_lines = join(readfile(l:debug_target), "\n")
    AssertTxt(!empty(l:debug_text_lines),
            \ "Expected to find content written to the debug file in use at the completion of testing but such file " ..
            \ "was empty.")

    " Cleanup - Take the following actions now that the test has completed:
    "
    "   1). Forcefully close out the new buffer that was created to hold the test document.
    "   2). Unset the 'g:llmchat_debug_mode_target' variable to disable debug mode.
    "   3). Remove the 'l:debug_target' from disk now that testing is complete.
    "
    bd!
    unlet g:llmchat_debug_mode_target
    call delete(l:debug_target)

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

    " Invoke the ParseChatBufferToBlocks() function and assert that an exception is thrown whose message indicates the
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


" This test asserts that function ParseChatBufferToBlocks() throws an exception, as well as outputs debug inforamtion,
" when the buffer content being processed has a model ID declaration in its header whose value is empty AND debug mode
" is enabled.
function s:TestParseChatBufferToBlocksWithEmptyModelIDDeclAndEnabledDebugMode()
    " Request the name and path to a temporary file from Vim and then set such temporary file as the target for debug
    " mode (this will implicitly enable debug mode).
    let l:debug_target = tempname()
    let g:llmchat_debug_mode_target = l:debug_target

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

    " Invoke the ParseChatBufferToBlocks() function and assert that an exception is thrown whose message indicates the
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

    " Assert that the 'l:debug_target' is readable to Vim (i.e., exists on disk) and holds non-empty content.
    AssertTxt(filereadable(l:debug_target),
            \ "Expected to find a debug output file at path '" .. l:debug_target .. "' but no such file existed.")

    let l:debug_text_lines = join(readfile(l:debug_target), "\n")
    AssertTxt(!empty(l:debug_text_lines),
            \ "Expected to find content written to the debug file in use at the completion of testing but such file " ..
            \ "was empty.")

    " Cleanup - Take the following actions now that the test has completed:
    "
    "   1). Forcefully close out the new buffer that was created to hold the test document.
    "   2). Unset the 'g:llmchat_debug_mode_target' variable to disable debug mode.
    "   3). Remove the 'l:debug_target' from disk now that testing is complete.
    "
    bd!
    unlet g:llmchat_debug_mode_target
    call delete(l:debug_target)

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

    " Invoke the ParseChatBufferToBlocks() function and assert that an exception is thrown whose message indicates the
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


" This test asserts that function ParseChatBufferToBlocks() throws an exception, as well as outputs debug information,
" when the buffer content being processed has a duplicate "Use Auth Token" declaration in its header AND debug mode is
" enabled.
function s:TestParseChatBufferToBlocksWithDuplicateUseAuthDeclAndEnabledDebugMode()
    " Request the name and path to a temporary file from Vim and then set such temporary file as the target for debug
    " mode (this will implicitly enable debug mode).
    let l:debug_target = tempname()
    let g:llmchat_debug_mode_target = l:debug_target

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

    " Invoke the ParseChatBufferToBlocks() function and assert that an exception is thrown whose message indicates the
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

    " Assert that the 'l:debug_target' is readable to Vim (i.e., exists on disk) and holds non-empty content.
    AssertTxt(filereadable(l:debug_target),
            \ "Expected to find a debug output file at path '" .. l:debug_target .. "' but no such file existed.")

    let l:debug_text_lines = join(readfile(l:debug_target), "\n")
    AssertTxt(!empty(l:debug_text_lines),
            \ "Expected to find content written to the debug file in use at the completion of testing but such file " ..
            \ "was empty.")


    " Cleanup - Take the following actions now that the test has completed:
    "
    "   1). Forcefully close out the new buffer that was created to hold the test document.
    "   2). Unset the 'g:llmchat_debug_mode_target' variable to disable debug mode.
    "   3). Remove the 'l:debug_target' from disk now that testing is complete.
    "
    bd!
    unlet g:llmchat_debug_mode_target
    call delete(l:debug_target)

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

    " Invoke the ParseChatBufferToBlocks() function and assert that an exception is thrown whose message indicates the
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


" This test asserts that function ParseChatBufferToBlocks() throws an exception, as well as outputs debug information,
" when the buffer content being processed has a "Use Auth Token" declaration that holds and invalid value AND debug mode
" is enabled.
function s:TestParseChatBufferToBlocksWithBadUseAuthDeclAndEnabledDebugMode()
    " Request the name and path to a temporary file from Vim and then set such temporary file as the target for debug
    " mode (this will implicitly enable debug mode).
    let l:debug_target = tempname()
    let g:llmchat_debug_mode_target = l:debug_target

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

    " Invoke the ParseChatBufferToBlocks() function and assert that an exception is thrown whose message indicates the
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

    " Assert that the 'l:debug_target' is readable to Vim (i.e., exists on disk) and holds non-empty content.
    AssertTxt(filereadable(l:debug_target),
            \ "Expected to find a debug output file at path '" .. l:debug_target .. "' but no such file existed.")

    let l:debug_text_lines = join(readfile(l:debug_target), "\n")
    AssertTxt(!empty(l:debug_text_lines),
            \ "Expected to find content written to the debug file in use at the completion of testing but such file " ..
            \ "was empty.")

    " Cleanup - Take the following actions now that the test has completed:
    "
    "   1). Forcefully close out the new buffer that was created to hold the test document.
    "   2). Unset the 'g:llmchat_debug_mode_target' variable to disable debug mode.
    "   3). Remove the 'l:debug_target' from disk now that testing is complete.
    "
    bd!
    unlet g:llmchat_debug_mode_target
    call delete(l:debug_target)

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

    " Invoke the ParseChatBufferToBlocks() function and assert that an exception is thrown whose message indicates the
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


" This test asserts that function ParseChatBufferToBlocks() throws an exception, as well as outputs debug information,
" when the buffer content being processed contains a duplciate "Auth Token" declaration in its header AND debug mode is
" enabled.
function s:TestParseChatBufferToBlocksWithDuplicateAuthTokenDeclAndEnabledDebugMode()
    " Request the name and path to a temporary file from Vim and then set such temporary file as the target for debug
    " mode (this will implicitly enable debug mode).
    let l:debug_target = tempname()
    let g:llmchat_debug_mode_target = l:debug_target

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

    " Invoke the ParseChatBufferToBlocks() function and assert that an exception is thrown whose message indicates the
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

    " Assert that the 'l:debug_target' is readable to Vim (i.e., exists on disk) and holds non-empty content.
    AssertTxt(filereadable(l:debug_target),
            \ "Expected to find a debug output file at path '" .. l:debug_target .. "' but no such file existed.")

    let l:debug_text_lines = join(readfile(l:debug_target), "\n")
    AssertTxt(!empty(l:debug_text_lines),
            \ "Expected to find content written to the debug file in use at the completion of testing but such file " ..
            \ "was empty.")

    " Cleanup - Take the following actions now that the test has completed:
    "
    "   1). Forcefully close out the new buffer that was created to hold the test document.
    "   2). Unset the 'g:llmchat_debug_mode_target' variable to disable debug mode.
    "   3). Remove the 'l:debug_target' from disk now that testing is complete.
    "
    bd!
    unlet g:llmchat_debug_mode_target
    call delete(l:debug_target)

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

    " Invoke the ParseChatBufferToBlocks() function and assert that an exception is thrown whose message indicates the
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


" This test asserts that function ParseChatBufferToBlocks() throws an exception, as well as outputs debug information,
" when the buffer content being processed contains a duplicate system prompt declaration in its header AND debug mode is
" enabled.
function s:TestParseChatBufferToBlocksWithDuplicateSystemPromptDeclAndEnabledDebugMode()
    " Request the name and path to a temporary file from Vim and then set such temporary file as the target for debug
    " mode (this will implicitly enable debug mode).
    let l:debug_target = tempname()
    let g:llmchat_debug_mode_target = l:debug_target

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

    " Invoke the ParseChatBufferToBlocks() function and assert that an exception is thrown whose message indicates the
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

    " Assert that the 'l:debug_target' is readable to Vim (i.e., exists on disk) and holds non-empty content.
    AssertTxt(filereadable(l:debug_target),
            \ "Expected to find a debug output file at path '" .. l:debug_target .. "' but no such file existed.")

    let l:debug_text_lines = join(readfile(l:debug_target), "\n")
    AssertTxt(!empty(l:debug_text_lines),
            \ "Expected to find content written to the debug file in use at the completion of testing but such file " ..
            \ "was empty.")

    " Cleanup - Take the following actions now that the test has completed:
    "
    "   1). Forcefully close out the new buffer that was created to hold the test document.
    "   2). Unset the 'g:llmchat_debug_mode_target' variable to disable debug mode.
    "   3). Remove the 'l:debug_target' from disk now that testing is complete.
    "
    bd!
    unlet g:llmchat_debug_mode_target
    call delete(l:debug_target)

endfunction


" This test asserts that function ParseChatBufferToBlocks() throws an exception with an expected error message when the
" buffer content being processed contains a duplicate max context messages declaration in its header.
function s:TestParseChatBufferToBlocksWithDuplicateMaxContextMessagesDecl()
    " Define an invalid chat log document that contains a header with duplicate max context messsages declarations.
    let l:bad_chat_doc =
      \   "Server Type: Ollama" ..
      \ "\nServer URL: http://localhost/"  ..
      \ "\nMax Context Messages: 0" ..
      \ "\nModel ID: Some model" ..
      \ "\nMax Context Messages: 2" ..
      \ "\n* ENDSETUP *"

    " Open a new buffer then write the content of variable 'l:bad_chat_doc' to it.  Note that we will use the 'put!'
    " command so that content is inserted BEFORE the first line in the buffer and we'll leave the trailing newline
    " resulting from the downshift of the first buffer line (the parse should ignore this so there should not need to be
    " any special effort exerted here in cleaning it up).
    new
    silent! put! = l:bad_chat_doc

    " Invoke the ParseChatBufferToBlocks() function and assert that an exception is thrown whose message indicates the
    " fault we're expecting to see.
    try
        call s:util.ParseChatBufferToBlocks()

        " If the logic comes here than fail the test; we should have seen an exception thrown during parse which would
        " make this line unreachable.
        call s:testutil.Fail(expand('<sflnum>') - 9,
                           \ "Expected to see an exception thrown from function ParseChatBufferToBlocks() when it " ..
                           \ "was invoked to parse the content of a chat buffer whose header section contained " ..
                           \ "duplicate max context size declarations; however, no exception occurred.")

    catch /\c[error].*duplicate 'max context messages'.*/
        " The caught exception has a message that matches the expression we were looking for; assume that the test
        " was successful and take no further action.
    endtry

    " Cleanup - Forcefully close out the new buffer that was created to hold the test document.
    bd!

endfunction


" This test asserts that function ParseChatBufferToBlocks() throws an exception, as well as outputs debug information,
" when the buffer content being processed contains a duplicate max context messages declaration in its header AND debug
" mode is enabled.
function s:TestParseChatBufferToBlocksWithDuplicateMaxContextMessagesDeclAndEnabledDebugMode()
    " Request the name and path to a temporary file from Vim and then set such temporary file as the target for debug
    " mode (this will implicitly enable debug mode).
    let l:debug_target = tempname()
    let g:llmchat_debug_mode_target = l:debug_target

    " Define an invalid chat log document that contains a header with duplicate max context messsages declarations.
    let l:bad_chat_doc =
      \   "Server Type: Ollama" ..
      \ "\nServer URL: http://localhost/"  ..
      \ "\nMax Context Messages: 0" ..
      \ "\nModel ID: Some model" ..
      \ "\nMax Context Messages: 2" ..
      \ "\n* ENDSETUP *"

    " Open a new buffer then write the content of variable 'l:bad_chat_doc' to it.  Note that we will use the 'put!'
    " command so that content is inserted BEFORE the first line in the buffer and we'll leave the trailing newline
    " resulting from the downshift of the first buffer line (the parse should ignore this so there should not need to be
    " any special effort exerted here in cleaning it up).
    new
    silent! put! = l:bad_chat_doc

    " Invoke the ParseChatBufferToBlocks() function and assert that an exception is thrown whose message indicates the
    " fault we're expecting to see.
    try
        call s:util.ParseChatBufferToBlocks()

        " If the logic comes here than fail the test; we should have seen an exception thrown during parse which would
        " make this line unreachable.
        call s:testutil.Fail(expand('<sflnum>') - 9,
                           \ "Expected to see an exception thrown from function ParseChatBufferToBlocks() when it " ..
                           \ "was invoked to parse the content of a chat buffer whose header section contained " ..
                           \ "duplicate max context size declarations; however, no exception occurred.")

    catch /\c[error].*duplicate 'max context messages'.*/
        " The caught exception has a message that matches the expression we were looking for; assume that the test
        " was successful and take no further action.
    endtry

    " Assert that the 'l:debug_target' is readable to Vim (i.e., exists on disk) and holds non-empty content.
    AssertTxt(filereadable(l:debug_target),
            \ "Expected to find a debug output file at path '" .. l:debug_target .. "' but no such file existed.")

    let l:debug_text_lines = join(readfile(l:debug_target), "\n")
    AssertTxt(!empty(l:debug_text_lines),
            \ "Expected to find content written to the debug file in use at the completion of testing but such file " ..
            \ "was empty.")

    " Cleanup - Take the following actions now that the test has completed:
    "
    "   1). Forcefully close out the new buffer that was created to hold the test document.
    "   2). Unset the 'g:llmchat_debug_mode_target' variable to disable debug mode.
    "   3). Remove the 'l:debug_target' from disk now that testing is complete.
    "
    bd!
    unlet g:llmchat_debug_mode_target
    call delete(l:debug_target)

endfunction


" This test asserts that function ParseChatBufferToBlocks() throws an exception with an expected error message when the
" buffer content being processed contains a max context message declaration whose value is not parseable to a number.
function s:TestParseChatBufferToBlocksWithBadMaxContextMessagesValue()
    " Define an invalid chat log document that contains a header with a bad max context messsages declaration.
    let l:bad_chat_doc =
      \   "Server Type: Ollama" ..
      \ "\nServer URL: http://localhost/"  ..
      \ "\nModel ID: Some model" ..
      \ "\nMax Context Messages: abc" ..
      \ "\n* ENDSETUP *"

    " Open a new buffer then write the content of variable 'l:bad_chat_doc' to it.  Note that we will use the 'put!'
    " command so that content is inserted BEFORE the first line in the buffer and we'll leave the trailing newline
    " resulting from the downshift of the first buffer line (the parse should ignore this so there should not need to be
    " any special effort exerted here in cleaning it up).
    new
    silent! put! = l:bad_chat_doc

    " Invoke the ParseChatBufferToBlocks() function and assert that an exception is thrown whose message indicates the
    " fault we're expecting to see.
    try
        call s:util.ParseChatBufferToBlocks()

        " If the logic comes here than fail the test; we should have seen an exception thrown during parse which would
        " make this line unreachable.
        call s:testutil.Fail(expand('<sflnum>') - 9,
                           \ "Expected to see an exception thrown from function ParseChatBufferToBlocks() when it " ..
                           \ "was invoked to parse the content of a chat buffer whose header section contained a " ..
                           \ "max context size declaration with a bad value; however, no exception occurred.")

    catch /\c[error].*'max context messages'.*could not be parsed.*/
        " The caught exception has a message that matches the expression we were looking for; assume that the test
        " was successful and take no further action.
    endtry

    " Cleanup - Forcefully close out the new buffer that was created to hold the test document.
    bd!

endfunction


" This test asserts that function ParseChatBufferToBlocks() throws an exception, as well as outputs debug information,
" when the buffer content being processed contains a max context message declaration whose value is not parseable to
" a number AND debug mode is enabled.
function s:TestParseChatBufferToBlocksWithBadMaxContextMessagesValueAndEnabledDebugMode()
    " Request the name and path to a temporary file from Vim and then set such temporary file as the target for debug
    " mode (this will implicitly enable debug mode).
    let l:debug_target = tempname()
    let g:llmchat_debug_mode_target = l:debug_target

    " Define an invalid chat log document that contains a header with a bad max context messsages declaration.
    let l:bad_chat_doc =
      \   "Server Type: Ollama" ..
      \ "\nServer URL: http://localhost/"  ..
      \ "\nModel ID: Some model" ..
      \ "\nMax Context Messages: abc" ..
      \ "\n* ENDSETUP *"

    " Open a new buffer then write the content of variable 'l:bad_chat_doc' to it.  Note that we will use the 'put!'
    " command so that content is inserted BEFORE the first line in the buffer and we'll leave the trailing newline
    " resulting from the downshift of the first buffer line (the parse should ignore this so there should not need to be
    " any special effort exerted here in cleaning it up).
    new
    silent! put! = l:bad_chat_doc

    " Invoke the ParseChatBufferToBlocks() function and assert that an exception is thrown whose message indicates the
    " fault we're expecting to see.
    try
        call s:util.ParseChatBufferToBlocks()

        " If the logic comes here than fail the test; we should have seen an exception thrown during parse which would
        " make this line unreachable.
        call s:testutil.Fail(expand('<sflnum>') - 9,
                           \ "Expected to see an exception thrown from function ParseChatBufferToBlocks() when it " ..
                           \ "was invoked to parse the content of a chat buffer whose header section contained a " ..
                           \ "max context size declaration with a bad value; however, no exception occurred.")

    catch /\c[error].*'max context messages'.*could not be parsed.*/
        " The caught exception has a message that matches the expression we were looking for; assume that the test
        " was successful and take no further action.
    endtry

    " Assert that the 'l:debug_target' is readable to Vim (i.e., exists on disk) and holds non-empty content.
    AssertTxt(filereadable(l:debug_target),
            \ "Expected to find a debug output file at path '" .. l:debug_target .. "' but no such file existed.")

    let l:debug_text_lines = join(readfile(l:debug_target), "\n")
    AssertTxt(!empty(l:debug_text_lines),
            \ "Expected to find content written to the debug file in use at the completion of testing but such file " ..
            \ "was empty.")

    " Cleanup - Take the following actions now that the test has completed:
    "
    "   1). Forcefully close out the new buffer that was created to hold the test document.
    "   2). Unset the 'g:llmchat_debug_mode_target' variable to disable debug mode.
    "   3). Remove the 'l:debug_target' from disk now that testing is complete.
    "
    bd!
    unlet g:llmchat_debug_mode_target
    call delete(l:debug_target)

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

    " Invoke the ParseChatBufferToBlocks() function and assert that an exception is thrown whose message indicates the
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


" This test asserts that function ParseChatBufferToBlocks() throws an exception, as well as outputs debug information,
" when the buffer content being processed contains a duplicate option declaration in its header (i.e., an option
" declaration that uses the same "name" segment in its value as another option) AND debug mode is enabled.
function s:TestParseChatBufferToBlocksWithDuplicateOptionDeclAndEndabledDebugMode()
    " Request the name and path to a temporary file from Vim and then set such temporary file as the target for debug
    " mode (this will implicitly enable debug mode).
    let l:debug_target = tempname()
    let g:llmchat_debug_mode_target = l:debug_target

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

    " Invoke the ParseChatBufferToBlocks() function and assert that an exception is thrown whose message indicates the
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

    " Assert that the 'l:debug_target' is readable to Vim (i.e., exists on disk) and holds non-empty content.
    AssertTxt(filereadable(l:debug_target),
            \ "Expected to find a debug output file at path '" .. l:debug_target .. "' but no such file existed.")

    let l:debug_text_lines = join(readfile(l:debug_target), "\n")
    AssertTxt(!empty(l:debug_text_lines),
            \ "Expected to find content written to the debug file in use at the completion of testing but such file " ..
            \ "was empty.")

    " Cleanup - Take the following actions now that the test has completed:
    "
    "   1). Forcefully close out the new buffer that was created to hold the test document.
    "   2). Unset the 'g:llmchat_debug_mode_target' variable to disable debug mode.
    "   3). Remove the 'l:debug_target' from disk now that testing is complete.
    "
    bd!
    unlet g:llmchat_debug_mode_target
    call delete(l:debug_target)

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

    " Invoke the ParseChatBufferToBlocks() function and assert that an exception is thrown whose message indicates the
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


" This test asserts that function ParseChatBufferToBlocks() throws an exception, as well as outputs debug information,
" when the buffer content being processed contains a duplicate show reasoning declaration in its header AND debug mode
" is enabled.
function s:TestParseChatBufferToBlocksWithDuplicateShowReasoningDeclAndEnabledDebugMode()
    " Request the name and path to a temporary file from Vim and then set such temporary file as the target for debug
    " mode (this will implicitly enable debug mode).
    let l:debug_target = tempname()
    let g:llmchat_debug_mode_target = l:debug_target

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

    " Invoke the ParseChatBufferToBlocks() function and assert that an exception is thrown whose message indicates the
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

    " Assert that the 'l:debug_target' is readable to Vim (i.e., exists on disk) and holds non-empty content.
    AssertTxt(filereadable(l:debug_target),
            \ "Expected to find a debug output file at path '" .. l:debug_target .. "' but no such file existed.")

    let l:debug_text_lines = join(readfile(l:debug_target), "\n")
    AssertTxt(!empty(l:debug_text_lines),
            \ "Expected to find content written to the debug file in use at the completion of testing but such file " ..
            \ "was empty.")

    " Cleanup - Take the following actions now that the test has completed:
    "
    "   1). Forcefully close out the new buffer that was created to hold the test document.
    "   2). Unset the 'g:llmchat_debug_mode_target' variable to disable debug mode.
    "   3). Remove the 'l:debug_target' from disk now that testing is complete.
    "
    bd!
    unlet g:llmchat_debug_mode_target
    call delete(l:debug_target)

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

    " Invoke the ParseChatBufferToBlocks() function and assert that an exception is thrown whose message indicates the
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


" This test asserts that function ParseChatBufferToBlocks() throws an exception, as well as outputs debug information,
" when the buffer content being processed has a "show reasoning" declaration in its header whose value is empty AND
" debug mode is enabled.
function s:TestParseChatBufferToBlocksWithEmptyShowReasoningDeclAndEnabledDebugMode()
    " Request the name and path to a temporary file from Vim and then set such temporary file as the target for debug
    " mode (this will implicitly enable debug mode).
    let l:debug_target = tempname()
    let g:llmchat_debug_mode_target = l:debug_target

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

    " Invoke the ParseChatBufferToBlocks() function and assert that an exception is thrown whose message indicates the
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

    " Assert that the 'l:debug_target' is readable to Vim (i.e., exists on disk) and holds non-empty content.
    AssertTxt(filereadable(l:debug_target),
            \ "Expected to find a debug output file at path '" .. l:debug_target .. "' but no such file existed.")

    let l:debug_text_lines = join(readfile(l:debug_target), "\n")
    AssertTxt(!empty(l:debug_text_lines),
            \ "Expected to find content written to the debug file in use at the completion of testing but such file " ..
            \ "was empty.")

    " Cleanup - Take the following actions now that the test has completed:
    "
    "   1). Forcefully close out the new buffer that was created to hold the test document.
    "   2). Unset the 'g:llmchat_debug_mode_target' variable to disable debug mode.
    "   3). Remove the 'l:debug_target' from disk now that testing is complete.
    "
    bd!
    unlet g:llmchat_debug_mode_target
    call delete(l:debug_target)

endfunction


" This test asserts that function ParseChatBufferToBlocks() throws an exception with an expected error message when the
" buffer content being processed contains a duplicate message register declaration in its header.
function s:TestParseChatBufferToBlocksWithDuplicateMessageRegisterDecl()
    " Define an invalid chat log document that contains a header with duplicate message register declarations.
    let l:bad_chat_doc =
        \   "Server Type: Ollama" ..
        \ "\nMessage Register: a" ..
        \ "\nServer URL: https://testllm.net/" ..
        \ "\nModel ID: Test model" ..
        \ "\nMessage Register: b" ..
        \ "\n* ENDSETUP *"

    " Open a new buffer then write the content of variable 'l:bad_chat_doc' to it.  Note that we will use the 'put!'
    " command so that content is inserted BEFORE the first line in the buffer and we'll leave the trailing newline
    " resulting from the downshift of the first buffer line (the parse should ignore this so there should not need to be
    " any special effort exerted here in cleaning it up).
    new
    silent! put! = l:bad_chat_doc

    " Invoke the ParseChatBufferToBlocks() function and assert that an exception is thrown whose message indicates the
    " fault we're expecting to see.
    try
        call s:util.ParseChatBufferToBlocks()

        " If the logic comes here than fail the test; we should have seen an exception thrown during parse which would
        " make this line unreachable.
        call s:testutil.Fail(expand('<sflnum>') - 9,
                           \ "Expected to see an exception thrown from function ParseChatBufferToBlocks() when it " ..
                           \ "was invoked to parse the content of a chat buffer whose header section contained " ..
                           \ "duplicate message register declarations; however, no exception occurred.")

    catch /\c[error].*duplicate 'message register'.*/
        " The caught exception has a message that matches the expression we were looking for; assume that the test
        " was succesful and take no further action.
    endtry

    " Cleanup - Forcefully close out the new buffer that was created to hold the test document.
    bd!

endfunction


" This test asserts that function ParseChatBufferToBlocks() throws an exception, as well as outputs debug information,
" when the buffer content being processed contains a duplicate message register declaration in its header AND debug mode
" is enabled.
function s:TestParseChatBufferToBlocksWithDuplicateMessageRegisterDeclAndEnabledDebugMode()
    " Request the name and path to a temporary file from Vim and then set such temporary file as the target for debug
    " mode (this will implicitly enable debug mode).
    let l:debug_target = tempname()
    let g:llmchat_debug_mode_target = l:debug_target

    " Define an invalid chat log document that contains a header with duplicate message register declarations.
    let l:bad_chat_doc =
        \   "Server Type: Ollama" ..
        \ "\nMessage Register: a" ..
        \ "\nServer URL: https://testllm.net/" ..
        \ "\nModel ID: Test model" ..
        \ "\nMessage Register: b" ..
        \ "\n* ENDSETUP *"

    " Open a new buffer then write the content of variable 'l:bad_chat_doc' to it.  Note that we will use the 'put!'
    " command so that content is inserted BEFORE the first line in the buffer and we'll leave the trailing newline
    " resulting from the downshift of the first buffer line (the parse should ignore this so there should not need to be
    " any special effort exerted here in cleaning it up).
    new
    silent! put! = l:bad_chat_doc

    " Invoke the ParseChatBufferToBlocks() function and assert that an exception is thrown whose message indicates the
    " fault we're expecting to see.
    try
        call s:util.ParseChatBufferToBlocks()

        " If the logic comes here than fail the test; we should have seen an exception thrown during parse which would
        " make this line unreachable.
        call s:testutil.Fail(expand('<sflnum>') - 9,
                           \ "Expected to see an exception thrown from function ParseChatBufferToBlocks() when it " ..
                           \ "was invoked to parse the content of a chat buffer whose header section contained " ..
                           \ "duplicate message register declarations; however, no exception occurred.")

    catch /\c[error].*duplicate 'message register'.*/
        " The caught exception has a message that matches the expression we were looking for; assume that the test
        " was succesful and take no further action.
    endtry

    " Assert that the 'l:debug_target' is readable to Vim (i.e., exists on disk) and holds non-empty content.
    AssertTxt(filereadable(l:debug_target),
            \ "Expected to find a debug output file at path '" .. l:debug_target .. "' but no such file existed.")

    let l:debug_text_lines = join(readfile(l:debug_target), "\n")
    AssertTxt(!empty(l:debug_text_lines),
            \ "Expected to find content written to the debug file in use at the completion of testing but such file " ..
            \ "was empty.")


    " Cleanup - Take the following actions now that the test execution has completed:
    "
    "   1). Forcefully close out the new buffer that was created to hold the test document.
    "   2). Unset the 'g:llmchat_debug_mode_target' variable to disable debug mode.
    "   3). Remove the 'l:debug_target' from disk now that testing is complete.
    "
    bd!
    unlet g:llmchat_debug_mode_target
    call delete(l:debug_target)

endfunction


" This test asserts that function ParseChatBufferToBlocks() throws an exception with an expected error message when the
" buffer content being processed contains a message register declaration in its header that has an invalid value.
function s:TestParseChatBufferToBlocksWithInvalidMessageRegisterDecl()
    " Define an invalid chat log document that contains a header with an invalid message register declaration.
    let l:bad_chat_doc =
                \   "Server Type: Open WebUI" ..
                \ "\nServer URL: https://somhost/somepath" ..
                \ "\nModel ID: Some Model ID" ..
                \ "\nMessage Register: abc" ..
                \ "\n* ENDSETUP *"

    " Open a new buffer then write the content of variable 'l:bad_chat_doc' to it.  Note that we will use the 'put!'
    " command so that content is inserted BEFORE the first line in the buffer and we'll leave the trailing newline
    " resulting from the downshift of the first buffer line (the parse should ignore this so there should not need to be
    " any special effort exerted here in cleaning it up).
    new
    silent! put! = l:bad_chat_doc

    " Invoke the ParseChatBufferToBlocks() function and assert that an exception is thrown whose message indicates the
    " fault we're expecting to see.
    try
        call s:util.ParseChatBufferToBlocks()

        " If the logic comes here than fail the test; we should have seen an exception thrown during parse which would
        " make this line unreachable.
        call s:testutil.Fail(expand('<sflnum>') - 9,
                           \ "Expected to see an exception thrown from function ParseChatBufferToBlocks() when it " ..
                           \ "was invoked to parse the content of a chat buffer whose header section contained an " ..
                           \ "invalid message register declaration; however, no exception occurred.")

    catch /\c[error].*register name.*invalid.*/
        " The caught exception has a message that matches the expression we were looking for; assume that the test
        " was succesful and take no further action.
    endtry

    " Cleanup - Forcefully close out the new buffer that was created to hold the test document.
    bd!

endfunction


" This test asserts that function ParseChatBufferToBlocks() throws an exception, as well as outputs debug information,
" when the buffer content being processed contains a message register declaration with an invalid value in its header
" AND debug mode is enabled.
function s:TestParseChatBufferToBlocksWithInvalidMessageRegisterDeclAndEnabledDebugMode()
    " Request the name and path to a temporary file from Vim and then set such temporary file as the target for debug
    " mode (this will implicitly enable debug mode).
    let l:debug_target = tempname()
    let g:llmchat_debug_mode_target = l:debug_target

    " Define an invalid chat log document that contains a header with an invalid message register declaration.
    let l:bad_chat_doc =
                \   "Server Type: Open WebUI" ..
                \ "\nServer URL: https://somhost/somepath" ..
                \ "\nModel ID: Some Model ID" ..
                \ "\nMessage Register: abc" ..
                \ "\n* ENDSETUP *"

    " Open a new buffer then write the content of variable 'l:bad_chat_doc' to it.  Note that we will use the 'put!'
    " command so that content is inserted BEFORE the first line in the buffer and we'll leave the trailing newline
    " resulting from the downshift of the first buffer line (the parse should ignore this so there should not need to be
    " any special effort exerted here in cleaning it up).
    new
    silent! put! = l:bad_chat_doc

    " Invoke the ParseChatBufferToBlocks() function and assert that an exception is thrown whose message indicates the
    " fault we're expecting to see.
    try
        call s:util.ParseChatBufferToBlocks()

        " If the logic comes here than fail the test; we should have seen an exception thrown during parse which would
        " make this line unreachable.
        call s:testutil.Fail(expand('<sflnum>') - 9,
                           \ "Expected to see an exception thrown from function ParseChatBufferToBlocks() when it " ..
                           \ "was invoked to parse the content of a chat buffer whose header section contained an " ..
                           \ "invalid message register declaration; however, no exception occurred.")

    catch /\c[error].*register name.*invalid.*/
        " The caught exception has a message that matches the expression we were looking for; assume that the test
        " was succesful and take no further action.
    endtry

    " Assert that the 'l:debug_target' is readable to Vim (i.e., exists on disk) and holds non-empty content.
    AssertTxt(filereadable(l:debug_target),
            \ "Expected to find a debug output file at path '" .. l:debug_target .. "' but no such file existed.")

    let l:debug_text_lines = join(readfile(l:debug_target), "\n")
    AssertTxt(!empty(l:debug_text_lines),
            \ "Expected to find content written to the debug file in use at the completion of testing but such file " ..
            \ "was empty.")

    " Cleanup - Take the following actions now that the test execution has completed:
    "
    "   1). Forcefully close out the new buffer that was created to hold the test document.
    "   2). Unset the 'g:llmchat_debug_mode_target' variable to disable debug mode.
    "   3). Remove the 'l:debug_target' from disk now that testing is complete.
    "
    bd!
    unlet g:llmchat_debug_mode_target
    call delete(l:debug_target)

endfunction


" This test asserts that function ParseChatBufferToBlocks() throws an exception with an expected error message when the
" buffer content being processing contains a user message with an invalid resource reference.
function s:TestParseChatBufferToBlocksWithInvalidResourceReference()
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

    " Invoke the ParseChatBufferToBlocks() function and assert that an exception is thrown whose message indicates the
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


" This test asserts that function ParseChatBufferToBlocks() throws an exception, as well as outputs debug information,
" when the buffer content being processed contains a user message with an invalid resource reference AND debug mode is
" enabled.
function s:TestParseChatBufferToBlocksWithInvalidResourceReferenceAndEnabledDebugMode()
    " Request the name and path to a temporary file from Vim and then set such temporary file as the target for debug
    " mode (this will implicitly enable debug mode).
    let l:debug_target = tempname()
    let g:llmchat_debug_mode_target = l:debug_target

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

    " Invoke the ParseChatBufferToBlocks() function and assert that an exception is thrown whose message indicates the
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

    " Assert that the 'l:debug_target' is readable to Vim (i.e., exists on disk) and holds non-empty content.
    AssertTxt(filereadable(l:debug_target),
            \ "Expected to find a debug output file at path '" .. l:debug_target .. "' but no such file existed.")

    let l:debug_text_lines = join(readfile(l:debug_target), "\n")
    AssertTxt(!empty(l:debug_text_lines),
            \ "Expected to find content written to the debug file in use at the completion of testing but such file " ..
            \ "was empty.")

    " Cleanup - Take the following actions now that the test has completed:
    "
    "   1). Forcefully close out the new buffer that was created to hold the test document.
    "   2). Unset the 'g:llmchat_debug_mode_target' variable to disable debug mode.
    "   3). Remove the 'l:debug_target' from disk now that testing is complete.
    "
    bd!
    unlet g:llmchat_debug_mode_target
    call delete(l:debug_target)

endfunction


" This test asserts that function ParseChatBufferToBlocks() throws an exception with an expected error message when the
" buffer content being processed contains a user message that starts with an improperly formatted resource reference.
function s:TestParseChatBufferToBlocksWithStartingInvalidResourceReference()
    " Define a chat document whose content holds a user message that starts with an improperly formatted resource
    " reference.
    let l:bad_chat_doc =
      \   "Server Type: Ollama" ..
      \ "\nServer URL: http://localhost/"  ..
      \ "\nModel ID: Some model" ..
      \ "\n* ENDSETUP *" ..
      \ "\n>>>[Bad Resource Ref]"


    " Open a new buffer then write the content of variable 'l:bad_chat_doc' to it.  Note that we will use the 'put!'
    " command so that content is inserted BEFORE the first line in the buffer and we'll leave the trailing newline
    " resulting from the downshift of the first buffer line (the parse should ignore this so there should not need to be
    " any special effort exerted here in cleaning it up).
    new
    silent! put! = l:bad_chat_doc

    " Invoke the ParseChatBufferToBlocks() function and assert that an exception is thrown whose message indicates the
    " fault we're expecting to see.
    try
        call s:util.ParseChatBufferToBlocks()

        " If the logic comes here than fail the test; we should have seen an exception thrown during parse which would
        " make this line unreachable.
        call s:testutil.Fail(expand('<sflnum>') - 9,
                           \ "Expected to see an exception thrown from function ParseChatBufferToBlocks() when it " ..
                           \ "was invoked to parse the content of a chat buffer that contained a user message " ..
                           \ "starting with an improperly defined resource reference; however, no exception occurred.")

    catch /\c[error].*resource reference.*format was invalid.*/
        " The caught exception has a message that matches the expression we were looking for; assume that the test
        " was successful and take no further action.
    endtry

    " Cleanup - Forcefully close out the new buffer that was created to hold the test document.
    bd!

endfunction


" This test asserts that function ParseChatBufferToBlocks() throws an exception, as well as outputs debug information,
" when the buffer content being processed contains a user message that starts with an invalid resource reference AND
" debug mode is enabled.
function s:TestParseChatBufferToBlocksWithStartingInvalidResourceReferenceAndEnabledDebugMode()
    " Request the name and path to a temporary file from Vim and then set such temporary file as the target for debug
    " mode (this will implicitly enable debug mode).
    let l:debug_target = tempname()
    let g:llmchat_debug_mode_target = l:debug_target


    " Define a chat document whose content holds a user message that starts with an improperly formatted resource
    " reference.
    let l:bad_chat_doc =
      \   "Server Type: Ollama" ..
      \ "\nServer URL: http://localhost/"  ..
      \ "\nModel ID: Some model" ..
      \ "\n* ENDSETUP *" ..
      \ "\n>>>[Bad Resource Ref]"


    " Open a new buffer then write the content of variable 'l:bad_chat_doc' to it.  Note that we will use the 'put!'
    " command so that content is inserted BEFORE the first line in the buffer and we'll leave the trailing newline
    " resulting from the downshift of the first buffer line (the parse should ignore this so there should not need to be
    " any special effort exerted here in cleaning it up).
    new
    silent! put! = l:bad_chat_doc

    " Invoke the ParseChatBufferToBlocks() function and assert that an exception is thrown whose message indicates the
    " fault we're expecting to see.
    try
        call s:util.ParseChatBufferToBlocks()

        " If the logic comes here than fail the test; we should have seen an exception thrown during parse which would
        " make this line unreachable.
        call s:testutil.Fail(expand('<sflnum>') - 9,
                           \ "Expected to see an exception thrown from function ParseChatBufferToBlocks() when it " ..
                           \ "was invoked to parse the content of a chat buffer that contained a user message " ..
                           \ "starting with an improperly defined resource reference; however, no exception occurred.")

    catch /\c[error].*resource reference.*format was invalid.*/
        " The caught exception has a message that matches the expression we were looking for; assume that the test
        " was successful and take no further action.
    endtry

    " Assert that the 'l:debug_target' is readable to Vim (i.e., exists on disk) and holds non-empty content.
    AssertTxt(filereadable(l:debug_target),
            \ "Expected to find a debug output file at path '" .. l:debug_target .. "' but no such file existed.")

    let l:debug_text_lines = join(readfile(l:debug_target), "\n")
    AssertTxt(!empty(l:debug_text_lines),
            \ "Expected to find content written to the debug file in use at the completion of testing but such file " ..
            \ "was empty.")

    " Cleanup - Take the following actions now that the test has completed:
    "
    "   1). Forcefully close out the new buffer that was created to hold the test document.
    "   2). Unset the 'g:llmchat_debug_mode_target' variable to disable debug mode.
    "   3). Remove the 'l:debug_target' from disk now that testing is complete.
    "
    bd!
    unlet g:llmchat_debug_mode_target
    call delete(l:debug_target)

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

    " Invoke the ParseChatBufferToBlocks() function and assert that an exception is thrown whose message indicates the
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


" This test asserts that function ParseChatBufferToBlocks throws an exception, as well as outputs debug information,
" when the buffer content being processed contains "unexpected text" in its header (i.e.., text that is not associated
" with any supported grammatical header structure such as a declaration, comment, etc) AND debug mode is enabled.
function s:TestParseChatBufferToBlocksWithUnexpectedHeaderContentAndEnabledDebugMode()
    " Request the name and path to a temporary file from Vim and then set such temporary file as the target for debug
    " mode (this will implicitly enable debug mode).
    let l:debug_target = tempname()
    let g:llmchat_debug_mode_target = l:debug_target

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

    " Invoke the ParseChatBufferToBlocks() function and assert that an exception is thrown whose message indicates the
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

    " Assert that the 'l:debug_target' is readable to Vim (i.e., exists on disk) and holds non-empty content.
    AssertTxt(filereadable(l:debug_target),
            \ "Expected to find a debug output file at path '" .. l:debug_target .. "' but no such file existed.")

    let l:debug_text_lines = join(readfile(l:debug_target), "\n")
    AssertTxt(!empty(l:debug_text_lines),
            \ "Expected to find content written to the debug file in use at the completion of testing but such file " ..
            \ "was empty.")

    " Cleanup - Take the following actions now that the test has completed:
    "
    "   1). Forcefully close out the new buffer that was created to hold the test document.
    "   2). Unset the 'g:llmchat_debug_mode_target' variable to disable debug mode.
    "   3). Remove the 'l:debug_target' from disk now that testing is complete.
    "
    bd!
    unlet g:llmchat_debug_mode_target
    call delete(l:debug_target)

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

    " Invoke the ParseChatBufferToBlocks() function and assert that an exception is thrown whose message indicates the
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


" This test asserts that function ParseChatBufferToBlocks() throws an exception, as well as outputs debug information,
" when the buffer content being processed contains an empty assistant message AND debug mode is enabled.
function s:TestParseChatBufferToBlocksWithEmptyAssistantMessageFaultAndEnabledDebugMode()
    " Request the name and path to a temporary file from Vim and then set such temporary file as the target for debug
    " mode (this will implicitly enable debug mode).
    let l:debug_target = tempname()
    let g:llmchat_debug_mode_target = l:debug_target

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

    " Invoke the ParseChatBufferToBlocks() function and assert that an exception is thrown whose message indicates the
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

    " Assert that the 'l:debug_target' is readable to Vim (i.e., exists on disk) and holds non-empty content.
    AssertTxt(filereadable(l:debug_target),
            \ "Expected to find a debug output file at path '" .. l:debug_target .. "' but no such file existed.")

    let l:debug_text_lines = join(readfile(l:debug_target), "\n")
    AssertTxt(!empty(l:debug_text_lines),
            \ "Expected to find content written to the debug file in use at the completion of testing but such file " ..
            \ "was empty.")

    " Cleanup - Take the following actions now that the test has completed:
    "
    "   1). Forcefully close out the new buffer that was created to hold the test document.
    "   2). Unset the 'g:llmchat_debug_mode_target' variable to disable debug mode.
    "   3). Remove the 'l:debug_target' from disk now that testing is complete.
    "
    bd!
    unlet g:llmchat_debug_mode_target
    call delete(l:debug_target)

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

    " Invoke the ParseChatBufferToBlocks() function and assert that an exception is thrown whose message indicates the
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


" This test asserts that an exception is thrown from function ParseChatBufferToBlocks(), as well as an output of debug
" information, when the buffer content being processed contains two back-to-back user messages (i.e., the expected
" assistant message between such chat messages does not exist) AND debug mode is enabled.
function s:TestParseChatBufferToBlocksWithMissingAssistantMessageFaultAndEnabledDebugMode()
    " Request the name and path to a temporary file from Vim and then set such temporary file as the target for debug
    " mode (this will implicitly enable debug mode).
    let l:debug_target = tempname()
    let g:llmchat_debug_mode_target = l:debug_target

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

    " Invoke the ParseChatBufferToBlocks() function and assert that an exception is thrown whose message indicates the
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

    " Assert that the 'l:debug_target' is readable to Vim (i.e., exists on disk) and holds non-empty content.
    AssertTxt(filereadable(l:debug_target),
            \ "Expected to find a debug output file at path '" .. l:debug_target .. "' but no such file existed.")

    let l:debug_text_lines = join(readfile(l:debug_target), "\n")
    AssertTxt(!empty(l:debug_text_lines),
            \ "Expected to find content written to the debug file in use at the completion of testing but such file " ..
            \ "was empty.")

    " Cleanup - Take the following actions now that the test has completed:
    "
    "   1). Forcefully close out the new buffer that was created to hold the test document.
    "   2). Unset the 'g:llmchat_debug_mode_target' variable to disable debug mode.
    "   3). Remove the 'l:debug_target' from disk now that testing is complete.
    "
    bd!
    unlet g:llmchat_debug_mode_target
    call delete(l:debug_target)

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

    " Invoke the ParseChatBufferToBlocks() function and assert that an exception is thrown whose message indicates the
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

    " Invoke the ParseChatBufferToBlocks() function and assert that an exception is thrown whose message indicates the
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


" This test asserts that an exception is thrown from function ParseChatBufferToBlocks(), as well as an output of debug
" information, when the buffer content being processed contains an interaction block that is missing a user message AND
" debug mode is enabled.  Note that the following two cases will be handled during the execution of the test:
"
"   1). The first interaction in the file is missing the user message.
"   2). An interaction beyond the first is missing the user message.
"
function s:TestParseChatBufferToBlocksWithMissingUserMessageFaultAndEnabledDebugMode()
    " Request the name and path to a temporary file from Vim and then set such temporary file as the target for debug
    " mode (this will implicitly enable debug mode).
    let l:debug_target = tempname()
    let g:llmchat_debug_mode_target = l:debug_target

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

    " Invoke the ParseChatBufferToBlocks() function and assert that an exception is thrown whose message indicates the
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

    " Assert that the 'l:debug_target' is readable to Vim (i.e., exists on disk) and holds non-empty content.
    AssertTxt(filereadable(l:debug_target),
            \ "Expected to find a debug output file at path '" .. l:debug_target .. "' but no such file existed.")

    let l:debug_text_lines = join(readfile(l:debug_target), "\n")
    AssertTxt(!empty(l:debug_text_lines),
            \ "Expected to find content written to the debug file in use at the completion of testing but such file " ..
            \ "was empty.")

    " Cleanup - Take the following actions now that the test has completed:
    "
    "   1). Forcefully close out the new buffer that was created to hold the test document.
    "   2). Remove the 'l:debug_target' from disk to clear debug data that was output during the first part of testing.
    "
    " NOTE: We do NOT unset the 'g:llmchat_debug_mode_target' variable at this time because the test is not yet complete
    "       and we still need debug mode enabled for the next part of testing.
    bd!
    call delete(l:debug_target)


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

    " Invoke the ParseChatBufferToBlocks() function and assert that an exception is thrown whose message indicates the
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

    " Assert that the 'l:debug_target' is readable to Vim (i.e., exists on disk) and holds non-empty content.
    AssertTxt(filereadable(l:debug_target),
            \ "Expected to find a debug output file at path '" .. l:debug_target .. "' but no such file existed.")

    let l:debug_text_lines = join(readfile(l:debug_target), "\n")
    AssertTxt(!empty(l:debug_text_lines),
            \ "Expected to find content written to the debug file in use at the completion of testing but such file " ..
            \ "was empty.")

    " Cleanup - Take the following actions now that the test has completed:
    "
    "   1). Forcefully close out the new buffer that was created to hold the test document.
    "   2). Unset the 'g:llmchat_debug_mode_target' variable to disable debug mode.
    "   3). Remove the 'l:debug_target' from disk now that testing is complete.
    "
    bd!
    unlet g:llmchat_debug_mode_target
    call delete(l:debug_target)

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

    " Invoke the ParseChatBufferToBlocks() function and assert that an exception is thrown whose message indicates the
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


" This test asserts that an expected exception is thrown from function ParseChatBufferToBlocks, and debug information is
" output, when the buffer content being processed contains unexpected text within the body section of the chat log
" document (for example arbitrary text that is outside the context of a user or assistant message and which is NOT a
" separator) and debug mode is enabled.
function s:TestParseChatBufferToBlocksWithUnexpectedTextContentAndEnabledDebugMode()
    " Request the name and path to a temporary file from Vim and then set such temporary file as the target for debug
    " mode (this will implicitly enable debug mode).
    let l:debug_target = tempname()
    let g:llmchat_debug_mode_target = l:debug_target

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

    " Invoke the ParseChatBufferToBlocks() function and assert that an exception is thrown whose message indicates the
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

    " Assert that the 'l:debug_target' is readable to Vim (i.e., exists on disk) and holds non-empty content.
    AssertTxt(filereadable(l:debug_target),
            \ "Expected to find a debug output file at path '" .. l:debug_target .. "' but no such file existed.")

    let l:debug_text_lines = join(readfile(l:debug_target), "\n")
    AssertTxt(!empty(l:debug_text_lines),
            \ "Expected to find content written to the debug file in use at the completion of testing but such file " ..
            \ "was empty.")

    " Cleanup - Take the following actions now that the test has completed:
    "
    "   1). Forcefully close out the new buffer that was created to hold the test document.
    "   2). Unset the 'g:llmchat_debug_mode_target' variable to disable debug mode.
    "   3). Remove the 'l:debug_target' from disk now that testing is complete.
    "
    bd!
    unlet g:llmchat_debug_mode_target
    call delete(l:debug_target)

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

    " Invoke the ParseChatBufferToBlocks() function and assert that an exception is thrown whose message indicates the
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


" This test asserts that an expected exception is thrown from function ParseChatBufferToBlocks(), and debug information
" is output, when the buffer content being processed lacks the ending separator for the header (this means that the
" parse will never exit the header section during execution) AND debug mode is enabled.
function s:TestParseChatBufferToBlocksWithMissingHeaderSepAndEnabledDebugMode()
    " Request the name and path to a temporary file from Vim and then set such temporary file as the target for debug
    " mode (this will implicitly enable debug mode).
    let l:debug_target = tempname()
    let g:llmchat_debug_mode_target = l:debug_target

    " Request the name and path to a temporary file from Vim and then set such temporary file as the target for debug
    " mode (this will implicitly enable debug mode).
    let l:debug_target = tempname()
    let g:llmchat_debug_mode_target = l:debug_target

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

    " Invoke the ParseChatBufferToBlocks() function and assert that an exception is thrown whose message indicates the
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

    " Assert that the 'l:debug_target' is readable to Vim (i.e., exists on disk) and holds non-empty content.
    AssertTxt(filereadable(l:debug_target),
            \ "Expected to find a debug output file at path '" .. l:debug_target .. "' but no such file existed.")

    let l:debug_text_lines = join(readfile(l:debug_target), "\n")
    AssertTxt(!empty(l:debug_text_lines),
            \ "Expected to find content written to the debug file in use at the completion of testing but such file " ..
            \ "was empty.")

    " Cleanup - Take the following actions now that the test has completed:
    "
    "   1). Forcefully close out the new buffer that was created to hold the test document.
    "   2). Unset the 'g:llmchat_debug_mode_target' variable to disable debug mode.
    "   3). Remove the 'l:debug_target' from disk now that testing is complete.
    "
    bd!
    unlet g:llmchat_debug_mode_target
    call delete(l:debug_target)

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

    " Invoke the ParseChatBufferToBlocks() function and assert that an exception is thrown whose message indicates the
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


" This test asserts that an expected exception is thrown from function ParseChatBufferToBlocks(), as well as an output
" of debug information, when the last message in the buffer being processed is an assistant message, such message is
" missing its closing delimiter, AND debug mode is enabled.
function s:TestParseChatBufferToBlocksWithMissingAssistantMessageClosingDelimiterAndEnabledDebugMode()
    " Request the name and path to a temporary file from Vim and then set such temporary file as the target for debug
    " mode (this will implicitly enable debug mode).
    let l:debug_target = tempname()
    let g:llmchat_debug_mode_target = l:debug_target

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

    " Invoke the ParseChatBufferToBlocks() function and assert that an exception is thrown whose message indicates the
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

    " Assert that the 'l:debug_target' is readable to Vim (i.e., exists on disk) and holds non-empty content.
    AssertTxt(filereadable(l:debug_target),
            \ "Expected to find a debug output file at path '" .. l:debug_target .. "' but no such file existed.")

    let l:debug_text_lines = join(readfile(l:debug_target), "\n")
    AssertTxt(!empty(l:debug_text_lines),
            \ "Expected to find content written to the debug file in use at the completion of testing but such file " ..
            \ "was empty.")

    " Cleanup - Take the following actions now that the test has completed:
    "
    "   1). Forcefully close out the new buffer that was created to hold the test document.
    "   2). Unset the 'g:llmchat_debug_mode_target' variable to disable debug mode.
    "   3). Remove the 'l:debug_target' from disk now that testing is complete.
    "
    bd!
    unlet g:llmchat_debug_mode_target
    call delete(l:debug_target)

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



" ***************************************************
" ****  FormatDictionaryToText() Function Tests  ****
" ***************************************************

" This test asserts the proper operation of function FormatDictionaryToText() when it is invoked to format a dictionary
" of known content.
function s:TestFormatDictionaryToTextWithKnownDict()
    " Unset the 'g:llmchat_h_disp_elem_aug_value' variable to clear the thousands separator (outputs using this
    " separator will be handled under another test).
    unlet g:llmchat_thousands_sep_char

    " Define a known dictionary that holds a variety of different values within it.
    let l:test_dict = {
                    \   "string_key": "string value",
                    \   "numeric_key": 12345,
                    \   "boolean_true": v:true,
                    \   "boolean_false": v:false,
                    \   "child_list":
                    \   [
                    \     "string element",
                    \     98745,
                    \     [ ],
                    \     [
                    \       564
                    \     ],
                    \     [
                    \       v:true,
                    \       v:false
                    \     ],
                    \     {
                    \        "nested key": "nested value"
                    \     }
                    \   ],
                    \   "child_dict":
                    \   {
                    \     "abc": "def",
                    \     "nested_list":
                    \     [
                    \       "list value",
                    \       33333,
                    \       "another list value"
                    \     ]
                    \   }
                    \ }

    " Invoke the FormatDictionaryToText() function to format the test dictionary.
    let l:actual_text_lines = s:util.FormatDictionaryToText(l:test_dict, 2)

    " Define a list of "expected" text lines and then assert that the actual text lines returned from the function call
    " matches to it.
    let l:expected_text_lines = [
                              \   "\"boolean_false\": false",
                              \   "\"boolean_true\": true",
                              \   "\"child_dict\":",
                              \   "{",
                              \   "  \"abc\": \"def\"",
                              \   "  \"nested_list\":",
                              \   "  [",
                              \   "    \"list value\"",
                              \   "    33333",
                              \   "    \"another list value\"",
                              \   "  ]",
                              \   "}",
                              \   "\"child_list\":",
                              \   "[",
                              \   "  \"string element\"",
                              \   "  98745",
                              \   "  [ ]",
                              \   "  [ 564 ]",
                              \   "  [",
                              \   "    true",
                              \   "    false",
                              \   "  ]",
                              \   "  {",
                              \   "    \"nested key\": \"nested value\"",
                              \   "  }",
                              \   "]",
                              \   "\"numeric_key\": 12345",
                              \   "\"string_key\": \"string value\""
                              \ ]

    call s:testutil.AssertEqualLists(expand('<sflnum>') - 9, '', l:expected_text_lines, l:actual_text_lines)

    " Cleanup - Restore the testing default value to variable 'g:llmchat_thousands_sep_char' now that the test has
    "           finished.
    let l:defaults_dict = s:testutil.GetGlobalVariableDefaults()
    let g:llmchat_thousands_sep_char = l:defaults_dict["g:llmchat_thousands_sep_char"]

endfunction


" This test asserts the proper operation of function FormatDictionaryToText() when it is invoked to format an empty
" dictionary.
function s:TestFormatDictionaryToTextWithEmptyDictionary()

    " Invoke the FormatDictionaryToText() function with an empty dictionary and assert that and empty list is returned
    " back.
    let l:text_list = s:util.FormatDictionaryToText({ }, 2, '')
    let l:return_type = type(l:text_list)
    AssertTxt(l:return_type == v:t_list,
            \ "Expected to see a list object returned from function FormatDictionaryToText() when an empty " ..
            \ "dictionary was provided as input; however, the returned value was of type " .. l:return_type .. ".")

    AssertTxt(empty(l:text_list),
            \ "Expected to see an empty list returned from function FormatDictionaryToText() when an empty " ..
            \ "dictionary was provided as input but the list returned had length " ..  len(l:text_list) .. " instead.")

endfunction


" This test asserts the proper operation of function FormatDictionaryToText() when it is invoked to format a dictionary
" holding integer values AND the 'g:llmchat_thousands_sep_char' variable has been set to a known value.
function s:TestFormatDictionaryToTextWithThousandsSeparatedNumbers()
    " Set variable 'g:llmchat_thousands_sep_char' to a known value for testing.
    let g:llmchat_thousands_sep_char = '|'

    " Define a test dictionary of known content which contains various numbers.
    let l:test_dict = {
                    \   "a": 0,
                    \   "b": 123,
                    \   "c": 1234,
                    \   "d": 123456789,
                    \   "e": 1.0,
                    \   "f": 1234.0,
                    \   "g":
                    \   {
                    \     "h":
                    \     {
                    \       "i": 123456,
                    \       "j": 123456.0
                    \     },
                    \     "k":
                    \     [
                    \       123456,
                    \       123456.0
                    \     ]
                    \   }
                    \ }

    " Invoke the FormatDictionaryToText() function to format the test dictionary.
    let l:actual_text_lines = s:util.FormatDictionaryToText(l:test_dict, 2)

    " Define a list of "expected" text lines and then assert that the actual text lines returned from the function call
    " matches to it.
    let l:expected_text_lines = [
                              \   "\"a\": 0",
                              \   "\"b\": 123",
                              \   "\"c\": 1|234",
                              \   "\"d\": 123|456|789",
                              \   "\"e\": 1.0",
                              \   "\"f\": 1234.0",
                              \   "\"g\":",
                              \   "{",
                              \   "  \"h\":",
                              \   "  {",
                              \   "    \"i\": 123|456",
                              \   "    \"j\": 123456.0",
                              \   "  }",
                              \   "  \"k\":",
                              \   "  [",
                              \   "    123|456",
                              \   "    123456.0",
                              \   "  ]",
                              \   "}"
                              \ ]

    call s:testutil.AssertEqualLists(expand('<sflnum>') - 9, '', l:expected_text_lines, l:actual_text_lines)

    " Cleanup - Restore the testing default value to variable 'g:llmchat_thousands_sep_char' now that the test has
    "           finished.
    let l:defaults_dict = s:testutil.GetGlobalVariableDefaults()
    let g:llmchat_thousands_sep_char = l:defaults_dict["g:llmchat_thousands_sep_char"]

endfunction



" *********************************************
" ****  FormatListToText() Function Tests  ****
" *********************************************

" This test asserts the proper operation of function FormatListToText() when it is invoked to format a list of known
" content.
function s:TestFormatDictionaryToTextWithKnownList()
    " Unset the 'g:llmchat_h_disp_elem_aug_value' variable to clear the thousands separator (outputs using this
    " separator will be handled under another test).
    unlet g:llmchat_thousands_sep_char

    " Define a known list that holds a variety of different values within it.
    let l:test_list = [
                    \   v:true,
                    \   45689,
                    \   234.56,
                    \   'a',
                    \   "abc",
                    \   {
                    \     "child_dict":
                    \     {
                    \       "foo": "bar",
                    \       "empty_list": [ ],
                    \       "xyz": "XYZ",
                    \       "descendant_dict":
                    \       {
                    \         "child_list":
                    \         [
                    \           [ "single value list" ],
                    \           [
                    \             "one",
                    \             "two",
                    \             "three"
                    \           ]
                    \         ],
                    \         "descendant_prop": "desc"
                    \       }
                    \     }
                    \   },
                    \   [
                    \     "abc"
                    \   ],
                    \   [
                    \     123,
                    \     "xyz"
                    \   ],
                    \   v:false,
                    \ ]

    " Invoke the FormatListToText() function to format the test list.
    let l:actual_text_lines = s:util.FormatListToText(l:test_list, 2)

    "Define a list of "expected" test lines and then assert that the actual text lines returned from the function call
    "matches to it.
    let l:expected_text_lines = [
                              \   "true",
                              \   "45689",
                              \   "234.56",
                              \   "\"a\"",
                              \   "\"abc\"",
                              \   "{",
                              \   "  \"child_dict\":",
                              \   "  {",
                              \   "    \"descendant_dict\":",
                              \   "    {",
                              \   "      \"child_list\":",
                              \   "      [",
                              \   "        [ \"single value list\" ]",
                              \   "        [",
                              \   "          \"one\"",
                              \   "          \"two\"",
                              \   "          \"three\"",
                              \   "        ]",
                              \   "      ]",
                              \   "      \"descendant_prop\": \"desc\"",
                              \   "    }",
                              \   "    \"empty_list\": [ ]",
                              \   "    \"foo\": \"bar\"",
                              \   "    \"xyz\": \"XYZ\"",
                              \   "  }",
                              \   "}",
                              \   "[ \"abc\" ]",
                              \   "[",
                              \   "  123",
                              \   "  \"xyz\"",
                              \   "]",
                              \   "false"
                              \ ]

    call s:testutil.AssertEqualLists(expand('<sflnum>') - 9, '', l:expected_text_lines, l:actual_text_lines)

    " Cleanup - Restore the testing default value to variable 'g:llmchat_thousands_sep_char' now that the test has
    "           finished.
    let l:defaults_dict = s:testutil.GetGlobalVariableDefaults()
    let g:llmchat_thousands_sep_char = l:defaults_dict["g:llmchat_thousands_sep_char"]

endfunction


" This test asserts the proper operation of function FormatListToText() when it is invoked ot format an empty list.
function s:TestformatListToTextWithEmptyList()

    " Invoke the FormatListToText() function with an empty list and assert that an empty is list is returned back.
    let l:text_list = s:util.FormatListToText([ ], 2, '')
    let l:return_type = type(l:text_list)
    AssertTxt(l:return_type == v:t_list,
            \ "Expected to see a list object returned from function FormatListToText() when an empty list was " ..
            \ "provided as input; however, the returned value was of type " .. l:return_type .. ".")

    AssertTxt(empty(l:text_list),
            \ "Expected to see an empty list returned from function FormatListToText() when an empty list was " ..
            \ "provided as input but the list returned had length " .. len(l:text_list) .. " instead.")

endfunction


" This test asserts the proper operation of function FormatListToText() when it is invoked to format a list holding
" integer values aND the 'g:llmchat_thousands_sep_char' variable has been set to a known value.
function s:TestFormatListToTextWithThousandsSeparatedNumbers()
    " Set variable 'g:llmchat_thousands_sep_char' to a known value for testing.
    let g:llmchat_thousands_sep_char = ','

    " Define a test list of known content which contains various numbers.
    let l:test_list = [
                    \   0,
                    \   123,
                    \   1234,
                    \   1234567890,
                    \   1.0,
                    \   1234.0,
                    \   {
                    \     "a": 1234
                    \   },
                    \   [
                    \     {
                    \       "b": 1234567,
                    \       "c": 1234.0
                    \     }
                    \   ],
                    \ ]

    " Invoke the FormatListToText() function to format the test list.
    let l:actual_text_lines = s:util.FormatListToText(l:test_list, 2)

    " Define a list of "expected" text lines and then assert that the actual text lines returned from the function call
    " matches to it.
    let l:expected_text_lines = [
                              \   "0",
                              \   "123",
                              \   "1,234",
                              \   "1,234,567,890",
                              \   "1.0",
                              \   "1234.0",
                              \   "{",
                              \   "  \"a\": 1,234",
                              \   "}",
                              \   "[",
                              \   "  {",
                              \   "    \"b\": 1,234,567",
                              \   "    \"c\": 1234.0",
                              \   "  }",
                              \   "]"
                              \ ]

    call s:testutil.AssertEqualLists(expand('<sflnum>') - 9, '', l:expected_text_lines, l:actual_text_lines)


    " Cleanup - Restore the testing default value to variable 'g:llmchat_thousands_sep_char' now that the test has
    "           finished.
    let l:defaults_dict = s:testutil.GetGlobalVariableDefaults()
    let g:llmchat_thousands_sep_char = l:defaults_dict["g:llmchat_thousands_sep_char"]

endfunction



" ****************************************************
" ****  CalculateTotalWinHeight() Function Tests  ****
" ****************************************************

" This test asserts the proper operation of function CalculateTotalWinHeight() when invoked in a tab that contains
" a single window.
function s:TestCalculateTotalWinHeightWithSingleWindow()
    " Open a new tab for testing.  Note that we expect focus to immediately shift to this tab so there are no
    " explicit commands provided to manually change to it.
    execute "tabnew"


    " Compute the height of the current tab window and store this into a local variable.
    let l:window_height = winheight(winnr())


    " Call function DetectVerticalSpaceLossOnSplit() to detect any space loss during a horizontal split due to
    " the use of additional display elements between windows (for example a configured status bar) and then set
    " global variable 'g:llmchat_h_disp_elem_aug_value' to the value returned.
    let g:llmchat_h_disp_elem_aug_value = s:DetectVerticalSpaceLossOnSplit()


   " Invoke the CalculateTotalWinHeight() function and assert that it returns a value that is the same as the height
   " of the window computed earlier.
   AssertIs(l:window_height, s:util.CalculateTotalWinHeight())


    " Perform the following cleanup actions now that the test has completed:
    "
    "   1). Close out the tab used for testing.
    "   2). Restore the default value used for global varible 'g:llmchat_h_disp_elem_aug_value' by the tests.
    "
    execute "tabclose"

    let l:defaults_dict = s:testutil.GetGlobalVariableDefaults()
    let g:llmchat_h_disp_elem_aug_value = l:defaults_dict["g:llmchat_h_disp_elem_aug_value"]

endfunction


" This test asserts the proper operation of function CalculateTotalWinHeight() when invoked in a tab that contains
" two horizontally split windows.
function s:TestCalculateTotalWinHeightWithHorizontalSplit()
    " Open a new tab for testing.  Note that we expect focus to immediately shift to this tab so there are no
    " explicit commands provided to manually change to it.
    execute "tabnew"


    " Compute the height of the current tab window and store this into a local variable.
    let l:window_height = winheight(winnr())


    " Call function DetectVerticalSpaceLossOnSplit() to detect any space loss during a horizontal split due to
    " the use of additional display elements between windows (for example a configured status bar) and then set
    " global variable 'g:llmchat_h_disp_elem_aug_value' to the value returned.
    let g:llmchat_h_disp_elem_aug_value = s:DetectVerticalSpaceLossOnSplit()


    " Horizontally split the current tab into 2 separate windows.
    execute "split"


   " Invoke the CalculateTotalWinHeight() function and assert that it returns a value that is the same as the height
   " of the window computed earlier.
   AssertIs(l:window_height, s:util.CalculateTotalWinHeight())


    " Perform the following cleanup actions now that the test has completed:
    "
    "   1). Close out the tab used for testing.
    "   2). Restore the default value used for global varible 'g:llmchat_h_disp_elem_aug_value' by the tests.
    "
    execute "tabclose"

    let l:defaults_dict = s:testutil.GetGlobalVariableDefaults()
    let g:llmchat_h_disp_elem_aug_value = l:defaults_dict["g:llmchat_h_disp_elem_aug_value"]

endfunction


" This test asserts the proper operation of function CalculateTotalWinHeight() when invoked in a tab that contains
" two vertically split windows.
function s:TestCalculateTotalWinHeightWithVerticalSplit()
    " Open a new tab for testing.  Note that we expect focus to immediately shift to this tab so there are no
    " explicit commands provided to manually change to it.
    execute "tabnew"


    " Compute the height of the current tab window and store this into a local variable.
    let l:window_height = winheight(winnr())


    " Call function DetectVerticalSpaceLossOnSplit() to detect any space loss during a horizontal split due to
    " the use of additional display elements between windows (for example a configured status bar) and then set
    " global variable 'g:llmchat_h_disp_elem_aug_value' to the value returned.
    let g:llmchat_h_disp_elem_aug_value = s:DetectVerticalSpaceLossOnSplit()


    " Vertically split the current tab into 2 separate windows.
    execute "vsplit"


   " Invoke the CalculateTotalWinHeight() function and assert that it returns a value that is the same as the height
   " of the window computed earlier.
   AssertIs(l:window_height, s:util.CalculateTotalWinHeight())


    " Perform the following cleanup actions now that the test has completed:
    "
    "   1). Close out the tab used for testing.
    "   2). Restore the default value used for global varible 'g:llmchat_h_disp_elem_aug_value' by the tests.
    "
    execute "tabclose"

    let l:defaults_dict = s:testutil.GetGlobalVariableDefaults()
    let g:llmchat_h_disp_elem_aug_value = l:defaults_dict["g:llmchat_h_disp_elem_aug_value"]

endfunction


" This test asserts the proper operation of function CalculateTotalWinHeight() when invoked in a tab that contains
" multiple horizontal splits.
function s:TestCalculateTotalWinHeightWithMultipleHorizontalSplits()
    " Open a new tab for testing.  Note that we expect focus to immediately shift to this tab so there are no
    " explicit commands provided to manually change to it.
    execute "tabnew"


    " Compute the height of the current tab window and store this into a local variable.
    let l:window_height = winheight(winnr())


    " Call function DetectVerticalSpaceLossOnSplit() to detect any space loss during a horizontal split due to
    " the use of additional display elements between windows (for example a configured status bar) and then set
    " global variable 'g:llmchat_h_disp_elem_aug_value' to the value returned.
    let g:llmchat_h_disp_elem_aug_value = s:DetectVerticalSpaceLossOnSplit()


    " Horizontally split the current tab into 3 separate windows.
    execute "split"
    execute "split"


   " Invoke the CalculateTotalWinHeight() function and assert that it returns a value that is the same as the height
   " of the window computed earlier.
   AssertIs(l:window_height, s:util.CalculateTotalWinHeight())


    " Perform the following cleanup actions now that the test has completed:
    "
    "   1). Close out the tab used for testing.
    "   2). Restore the default value used for global varible 'g:llmchat_h_disp_elem_aug_value' by the tests.
    "
    execute "tabclose"

    let l:defaults_dict = s:testutil.GetGlobalVariableDefaults()
    let g:llmchat_h_disp_elem_aug_value = l:defaults_dict["g:llmchat_h_disp_elem_aug_value"]

endfunction


" This test asserts the proper operation of function CalculateTotalWinHeight() when invoked in a tab that contains
" multiple vertical splits.
function s:TestCalculateTotalWinHeightWithMultipleVerticalSplits()
    " Open a new tab for testing.  Note that we expect focus to immediately shift to this tab so there are no
    " explicit commands provided to manually change to it.
    execute "tabnew"


    " Compute the height of the current tab window and store this into a local variable.
    let l:window_height = winheight(winnr())


    " Call function DetectVerticalSpaceLossOnSplit() to detect any space loss during a horizontal split due to
    " the use of additional display elements between windows (for example a configured status bar) and then set
    " global variable 'g:llmchat_h_disp_elem_aug_value' to the value returned.
    let g:llmchat_h_disp_elem_aug_value = s:DetectVerticalSpaceLossOnSplit()


    " Vertically split the current tab into 3 separate windows
    execute "vsplit"
    execute "vsplit"


   " Invoke the CalculateTotalWinHeight() function and assert that it returns a value that is the same as the height
   " of the window computed earlier.
   AssertIs(l:window_height, s:util.CalculateTotalWinHeight())


    " Perform the following cleanup actions now that the test has completed:
    "
    "   1). Close out the tab used for testing.
    "   2). Restore the default value used for global varible 'g:llmchat_h_disp_elem_aug_value' by the tests.
    "
    execute "tabclose"

    let l:defaults_dict = s:testutil.GetGlobalVariableDefaults()
    let g:llmchat_h_disp_elem_aug_value = l:defaults_dict["g:llmchat_h_disp_elem_aug_value"]

endfunction


" This test asserts the proper operation of function CalculateTotatWinHeight() when invoked in a tab that contains
" nested splits inside an initial horizontal split.
function s:TestCalculateTotalWinHeightWithInitialHorizontalAndNestedSplits()
    " Open a new tab for testing.  Note that we expect focus to immediately shift to this tab so there are no
    " explicit commands provided to manually change to it.
    execute "tabnew"


    " Compute the height of the current tab window and store this into a local variable.
    let l:window_height = winheight(winnr())


    " Call function DetectVerticalSpaceLossOnSplit() to detect any space loss during a horizontal split due to
    " the use of additional display elements between windows (for example a configured status bar) and then set
    " global variable 'g:llmchat_h_disp_elem_aug_value' to the value returned.
    let g:llmchat_h_disp_elem_aug_value = s:DetectVerticalSpaceLossOnSplit()


    " Now split the window horizontally, then vertically, and horizontally again.  This should leave one window from
    " the initial split alone while nesting splits within the other window.
    execute "split"
    execute "vsplit"
    execute "split"


    " Invoke the CalculateTotalWinHeight() function and assert that it returns a value that is the same as the height
    " of the window computed earlier.
    AssertIs(l:window_height, s:util.CalculateTotalWinHeight())


    " Perform the following cleanup actions now that the test has completed:
    "
    "   1). Close out the tab used for testing.
    "   2). Restore the default value used for global varible 'g:llmchat_h_disp_elem_aug_value' by the tests.
    "
    execute "tabclose"

    let l:defaults_dict = s:testutil.GetGlobalVariableDefaults()
    let g:llmchat_h_disp_elem_aug_value = l:defaults_dict["g:llmchat_h_disp_elem_aug_value"]

endfunction


" This test asserts the proper operation of function CalculateTotalWinHeight() when invoked in a tab that contains
" nested splits inside an initial vertical split.
function s:TestCalculateTotalWinHeightWithInitialVerticalAndNestedSplits()
    " Open a new tab for testing.  Note that we expect focus to immediately shift to this tab so there are no
    " explicit commands provided to manually change to it.
    execute "tabnew"


    " Compute the height of the current tab window and store this into a local variable.
    let l:window_height = winheight(winnr())


    " Call function DetectVerticalSpaceLossOnSplit() to detect any space loss during a horizontal split due to
    " the use of additional display elements between windows (for example a configured status bar) and then set
    " global variable 'g:llmchat_h_disp_elem_aug_value' to the value returned.
    let g:llmchat_h_disp_elem_aug_value = s:DetectVerticalSpaceLossOnSplit()


    " Now vertically split the window, then horizontally split it, and vertically split it again.  This should leave
    " one window from the initial split alone while nesting splits within the other window.
    execute "vsplit"
    execute "split"
    execute "vsplit"


    " Invoke the CalculateTotalWinHeight() function and assert that it returns a value that is the same as the height
    " of the window computed earlier.
    AssertIs(l:window_height, s:util.CalculateTotalWinHeight())


    " Perform the following cleanup actions now that the test has completed:
    "
    "   1). Close out the tab used for testing.
    "   2). Restore the default value used for global varible 'g:llmchat_h_disp_elem_aug_value' by the tests.
    "
    execute "tabclose"

    let l:defaults_dict = s:testutil.GetGlobalVariableDefaults()
    let g:llmchat_h_disp_elem_aug_value = l:defaults_dict["g:llmchat_h_disp_elem_aug_value"]

endfunction



" *********************************************************
" ****  FormatNumberWithThousandsSep() Function Tests  ****
" *********************************************************

" This test asserts the proper operation of function FormatNumberWithThousandsSep() when global variable
" 'g:llmchat_thousands_sep_char' has been unset.
function s:TestFormatNumberWithThousandsSepAndNoSepChar()
    " Unset the 'g:llmchat_thousands_sep_char' to clear any separator that might be found by the function logic.
    unlet g:llmchat_thousands_sep_char


    " Invoke the FormatNumberWithThousandsSep() using a number that is less than 1,000 and verify the result.
    AssertIs("680", s:util.FormatNumberWithThousandsSep(680))


    " Invoke the FormatNumberWithThousandsSep() using a number that is over 1,000 and verify the result.
    AssertIs("5680", s:util.FormatNumberWithThousandsSep(5680))


    " Invoke the FormatNumberWithThousandsSep() using a number that would require multiple thousands separators to be
    " inserted and verify the result.
    AssertIs("1234567890", s:util.FormatNumberWithThousandsSep(1234567890))


    " Cleanup - Perform the following tasks to cleanup after testing:
    "
    "   1). Restore the test default value to the 'g:llmchat_thousands_sep_char' variable.
    "
    let l:defaults_dict = s:testutil.GetGlobalVariableDefaults()
    let g:llmchat_thousands_sep_char = l:defaults_dict["g:llmchat_thousands_sep_char"]

endfunction


" This test asserts the proper operation of function FormatNumberWithThousandsSep() when global variable
" 'g:llmchat_thousands_sep_char' has been set to the empty string.
function s:TestFormatNumberWithThousandsSepAndEmptySepChar()
    " Set the 'g:llmchat_thousands_sep_char' variable to hold the empty string.
    let g:llmchat_thousands_sep_char = ''


    " Invoke the FormatNumberWithThousandsSep() using a number that is less than 1,000 and verify the result.
    AssertIs("680", s:util.FormatNumberWithThousandsSep(680))


    " Invoke the FormatNumberWithThousandsSep() using a number that is over 1,000 and verify the result.
    AssertIs("5680", s:util.FormatNumberWithThousandsSep(5680))


    " Invoke the FormatNumberWithThousandsSep() using a number that would require multiple thousands separators to be
    " inserted and verify the result.
    AssertIs("1234567890", s:util.FormatNumberWithThousandsSep(1234567890))


    " Cleanup - Perform the following tasks to cleanup after testing:
    "
    "   1). Restore the test default value to the 'g:llmchat_thousands_sep_char' variable.
    "
    let l:defaults_dict = s:testutil.GetGlobalVariableDefaults()
    let g:llmchat_thousands_sep_char = l:defaults_dict["g:llmchat_thousands_sep_char"]

endfunction


" This test asserts the proper operation of function FormatNumberWithThousandsSep() when global variable
" 'g:llmchat_thousands_sep_char' has been set to a known character.
function s:TestFormatNumberWithThousandsSepAndNonEmptySep()
    " Set the 'g:llmchat_thousands_sep_char' to a known character value for testing.
    let g:llmchat_thousands_sep_char = ','


    " Invoke the FormatNumberWithThousandsSep() using a number that is less than 1,000 and verify the result.
    AssertIs("680", s:util.FormatNumberWithThousandsSep(680))


    " Invoke the FormatNumberWithThousandsSep() using a number that is over 1,000 and verify the result.
    AssertIs("5,680", s:util.FormatNumberWithThousandsSep(5680))


    " Invoke the FormatNumberWithThousandsSep() using a number that would require multiple thousands separators to be
    " inserted and verify the result.
    AssertIs("1,234,567,890", s:util.FormatNumberWithThousandsSep(1234567890))


    " Cleanup - Perform the following tasks to cleanup after testing:
    "
    "   1). Restore the test default value to the 'g:llmchat_thousands_sep_char' variable.
    "
    let l:defaults_dict = s:testutil.GetGlobalVariableDefaults()
    let g:llmchat_thousands_sep_char = l:defaults_dict["g:llmchat_thousands_sep_char"]

endfunction


" ****************************************************
" ****  ProcessDynamicEmbedding() Function Tests  ****
" ****************************************************

" This test asserts the proper operation of function ProcessDynamicEmbedding() when the 'tag_value' argument given to
" it references an available buffer.
function s:TestProcessDynamicEmbeddingWithBufferRef()
    " Create a new buffer then write a set of known lines to it.
    "
    " NOTE: When a new buffer is created it will come with an initial line already and adding content ot the buffer via
    "       the 'put' command will shift this line down.  For our purposes here we don't really care that such line is
    "       present but we do need to make sure we account for its presence when we validate the result returned by
    "       the ProcessDynamicEmbedding() function later.
    "
    let l:buffer_content = "Some content written out\nto a disposable buffer for\nuse in testing."

    new
    silent! put! = l:buffer_content


    " Capture the numerical identifier for the newly created buffer into a local variable for later use in constructing
    " the "ID" we will send to the ProcessDynamicEmbedding() function.
    let l:embedding_buffer = bufnr('')


    " Create a dynamic embedding identifier which refers to the embedding content buffer and then invoke the
    " ProcessDynamicEmbedding() function with such identifier.  Verify that the result returned matches to what was
    " expected (including the extra newline that will be found at the bottom of the embedding content buffer).
    let l:embedding_id = "@" .. l:embedding_buffer
    let l:actual_result = s:util.ProcessDynamicEmbedding(l:embedding_id)

    let l:expected_result = split(buffer_content, "\n")
    call add(l:expected_result, "")   " Add empty line that *should* be at the bottom of the buffer

    call s:testutil.AssertEqualLists(expand('<sflnum>') - 9, '', l:expected_result, l:actual_result)


    " Cleanup after testing by performing the following tasks:
    "
    "   1). Forcefully delete the embedding content buffer created earlier in the test.
    "
    bd!

endfunction


" This test asserts the proper operation of function ProcessDynamicEmbedding() when the 'tag_value' argument given to
" it references an existing file on disk.
function s:TestProcessDynamicEmbeddingWithValidFileRef()
    " Request the path to a temporary file from Vim and then output some testing content to it.
    let l:temp_file = tempname()

    let l:file_data = [
                    \   "Some content written out to file",
                    \   "for testing dynamic embedding",
                    \   "file fetches."
                    \ ]
    call writefile(l:file_data, l:temp_file)


    " Create a dynamic embedding identifier which refers to the temporary file and then invoke the
    " ProcessDynamicEmbedding() function with such identifier.  Verify that the result returned matches exactly to the
    " content that was written to file.
    let l:embedding_id = l:temp_file
    let l:actual_result = s:util.ProcessDynamicEmbedding(l:embedding_id)

    call s:testutil.AssertEqualLists(expand('<sflnum>') - 9, '', l:file_data, l:actual_result)


    " Cleanup after testing by performing the following tasks:
    "
    "   1). Delete the temporary file created by the test execution.
    "
    call delete(l:temp_file)

endfunction


" This test asserts that an expected exception is thrown from function ProcessDynamicEmbedding() when the 'tag_value'
" argument given to it references a non-existant file.
function s:TestProcessDynamicEmbeddingWithInvalidFileRef()
    " Request a temporary file name from Vim but do NOT write anything to the file.  This should leave us with a unique
    " filename that does not yet exist on the system.
    let l:nonexistant_file = tempname()

    " Sanity Check - Verify that Vim cannot read from the 'l:nonexistant_file' before moving forward.
    AssertTxt(!filereadable(l:nonexistant_file),
            \ "Did not expect to find any file allocated at path '" .. l:nonexistant_file .. "' but such file " ..
            \ "already existed on the local system.")

    try
        " Attempt to invoke the ProcessDynamicEmbedding() function using the 'l:nonexistant_file' as the provided
        " ID; this should throw an exception if the logic is working properly as no such file exists.
        call s:util.ProcessDynamicEmbedding(l:nonexistant_file)


        " If the logic comes here than fail the test; we should have seen an exception thrown prior to this point in the
        " logic making this statement unreachable.
        call s:testutil.Fail(expand('<sflnum>') - 9,
                           \ "Expected to see an exception thrown from function ProcessDynamicEmbedding() when the " ..
                           \ "ID given to it corresponded to a non-existant filepath; however, no exception was " ..
                           \ "thrown.")

    catch /\c[error].*does not exist.*/
        " The caught exception has a message that matches the expression we were looking for; assume that the test
        " was successful as this was the behavior we expected to see happen.
    endtry

endfunction


"
" =========================================  End Standalone Tests  =========================================
"

" This function will take the following actions after the execution of each test function in this script:
"
"   1). Reset all global variables to their testing defaults; this helps to minimize the impact of test failures
"       that may prevent proper cleanup of global variable settings.
"
function s:Teardown()
    " Reset all global variables to their testing defaults.  This is done in case of a test failure that prevents
    " cleanup logic within the test from properly restoring the global variable value.  For such a case leakage of
    " the variable value into the execution of other tests may cause unexpected failures and make it difficult to
    " diagnose where the original fault occurred.
    call s:testutil.RestoreGlobalVars(s:testutil.GetGlobalVariableDefaults())

endfunction


" This function is responsible for restoring the editor state following the execution of the unit tests in this file.
" Primarily this will consist of taking the following actions:
"
"   1). Call a test utility function that will restore any global variables whose value was backed up in dictionary
"       's:restore_values_dict' at the start of testing.
"
function s:AfterAll()
    " Call a test utility function to handle the value restoration to any global variable that was reset when this test
    " began execution.
    call s:testutil.RestoreGlobalVars(s:restore_values_dict)

endfunction

