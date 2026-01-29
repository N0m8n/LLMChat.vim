
UTSuite LLMPlugin SendChat Tests

" Tests for logic found in the 'autoload/LLMChat/send_chat.vim' script.

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
    " NOTE: Since we need to restore values at the end of testing (and this will be done by a completely different
    "       function execution) we need to store the "restore_values_dict" returned to us in a script-scope variable.
    let s:restore_values_dict = s:testutil.ResetGlobalVars()

endfunction


"
" =========================================  Start Standalone Tests  =========================================
"

" ****************************************************
" ****  InitiateChatInteraction() Function Tests  ****
" ****************************************************

" This test asserts that an expected exception is thrown from the InitiateChatInteraction() function when it is invoked
" from a non-chat buffer
function s:TestInitiateChatInteractionFromNonChatBuffer()
    " Set the 'g:llmchat_test_bypass_mode' to '1' to enable bypass mode (during testing this will silence 'echom'
    " commands that would otherwise run from the InitiateChatInteraction() function on exception).
    let g:llmchat_test_bypass_mode = 1

    " Setup a new, empty buffer and move the execution context to this new buffer.
    new

    try
        " Attempt to execute the InitiateChatInteraction() function from the context of this new buffer.
        call LLMChat#send_chat#InitiateChatInteraction()


        " If the logic reaches this point than fail the test; we expected to see an exception thrown when the
        " InitiateChatInteraction() function was called so this code should be unreachable when the logic is working as
        " intended.
        call s:.testUtil.Fail(expand('<sflnum>') - 9,
                            \ "Expected to see an exception thrown from the InitiateChatInteraction() function when " ..
                            \ "it was invoked from the context of a non-chat buffer; however, no exception occurred.")

    catch /\c[error].*non-chat buffer.*/
        " This appears to be the exception we expected to see thrown; let the test proceed on as the logic seems to be
        " working as intended.
    endtry


    " Cleanup - Take the following actions to cleanup after this test execution:
    "
    "  1). Forcibly close out the new, empty buffer with 'bd!'.
    "  2). Unset the 'g:llmchat_test_bypass_mode' variable so that bypass mode is disabled.
    "
    bd!
    unlet g:llmchat_test_bypass_mode

endfunction


" This test asserts the proper operation of function InitiateChatInteraction() when it is invoked on a chat buffer that
" contains valid content for interacting with an Ollama LLM server.
function s:TestInitiateChatInteractionWithChatDocForOllama()
    " Set the 'g:llmchat_test_bypass_mode' variable to a value of 1 so that execution of the function does NOT submit an
    " actual job for running.  Instead, when bypass mode is set, the command and supporting job information will be
    " captured into the chat execution dictionary where we can validate it later.
    let g:llmchat_test_bypass_mode = 1


    " Open a new empty split that will serve as our test chat log document.  Note that we will also capture the number
    " for the new chat buffer, as well as its text width, then store these into some local variables for later user.
    new
    let l:chat_buf_num = bufnr('%')
    let l:chat_text_width = &textwidth


    " Now load the empty buffer with a test chat document appropriate for interactions with Ollama.
    let l:chat_doc_lines = [
                         \   "Server Type: Ollama",
                         \   "Server URL: http://example.com",
                         \   "Model ID: Foo",
                         \   "* ENDSETUP *",
                         \   ">>>My test message.",
                         \   "<<<"
                         \ ]

    call appendbufline('%', '$', l:chat_doc_lines)


    " Set the 'filetype' for the new chat document to 'chtlg'.  Why did we wait until now for this?  For this test
    " we want to avoid having the buffer initialized with the boilerplate chat document so we need to make sure that
    " we have added content to the buffer BEFORE setting the filetype.
    set filetype=chtlg


    " Invoke the InitiateChatInteraction() function to process the test buffer content and create a job that *would*
    " initiate an interaction with the remote LLM server.
    call LLMChat#send_chat#InitiateChatInteraction()


    " Retrieve the chat execution dictionary so that we can validate its content.
    let l:actual_chat_exec_dict = LLMChat#send_chat#GetCurrChatExecDict()


    " Validate the 'request payload filename' and 'response payload filename' fields found within the retrieved
    " chat execution dictionary.  We expect both fields to be defined and to hold non-empty values.
    if has_key(l:actual_chat_exec_dict, "request payload filename")
        " Retrieve the 'request payload filename' into a local variable then assert that it is NOT empty.  Note that
        " validation of the file's contents will happen later on.
        let l:request_payload_file = l:actual_chat_exec_dict["request payload filename"]

        AssertIsNot!('', l:request_payload_file)
    else
        " In this case the field was missing so we will fail the test; this is required and would hold the payload
        " data for the request to be made to the Ollama server.
        call s:testutil.Fail(expand('<sflnum>') - 9,
                           \ "Expected to find a field named 'request payload filename' within the content of the " ..
                           \ "chat execution dictionary setup by function InitiateChatInteraction() but no such " ..
                           \ "field existed.")
    endif

    if has_key(l:actual_chat_exec_dict, "response payload filename")
        " Retrieve the 'response payload filename' into a local variable then assert that it is NOT empty.  Note that
        " validation of the file's contents will happen later on.
        let l:response_payload_file = l:actual_chat_exec_dict["response payload filename"]

        AssertIsNot!('', l:response_payload_file)
    else
        " In this case the field was missing so we will fail the test; this is required and would hold the response
        " payload returned from the LLM.
        call s:testutil.Fail(expand('<sflnum>') - 9,
                           \ "Expected to find a field named 'response payload filename' within the content of the " ..
                           \ "chat execution dictionary setup by function InitiateChatInteraction() but no such " ..
                           \ "field existed.")
    endif


    " Validate that the request payload file contains the expected JSON content for the initiated chat interaction.
    let l:actual_payload_text = join(readfile(l:request_payload_file), "\n")

    let l:expected_payload_text = "{" ..
                              \ "\n  \"model\": \"Foo\"," ..
                              \ "\n  \"think\": false," ..
                              \ "\n  \"stream\": false," ..
                              \ "\n  \"messages\":" ..
                              \ "\n    [" ..
                              \ "\n      {" ..
                              \ "\n        \"role\": \"user\"," ..
                              \ "\n        \"content\": \"My test message.\"" ..
                              \ "\n      }" ..
                              \ "\n    ]" ..
                              \ "\n}"

    call s:testutil.AssertEqualTextBlocks(expand('<sflnum>') - 9, '', l:expected_payload_text, l:actual_payload_text)


    " Verify that the response payload file is empty (IF such file exists); the request has not been sent so we should
    " not see any data being stored yet.  Note that if the file does not exist we will consider the check passed as the
    " primary concern for testing is to ensure that a chat interaction is not starting off with a dirty state (i.e.,
    " lingering response data from something is already present and cluttering things up).
    if filereadable(l:response_payload_file)
        AssertEquals("", join(readfile(l:response_payload_file), "\n"))
    endif


    " Define the full content of the chat execution dictionary we *expect* to see and then assert that l:chat_exec_dict
    " is equal to such dictionary.
    "
    " NOTE: To compute the "buffer line count" we will use the length of list 'l:chat_doc_lines' and add 1 to it.  We
    "       must add one because the append operation used to inject content into the test buffer leaves a leading
    "       empty line at the top (hence the document content is one line longer than the content we insert).
    "
    let l:expected_chat_exec_dict =
      \ {
      \   "captured command": 'curl -X POST ' ..
      \                       '--header "Content-Type: application/json; charset=' .. &encoding .. '" ' ..
      \                       '--data "@' .. l:request_payload_file .. '" ' ..
      \                       '--output "' .. l:response_payload_file .. '" ' ..
      \                       '--write-out "%{http_code}" ' ..
      \                       '--silent ' ..
      \                       '--show-error ' ..
      \                       '--location ' ..
      \                       'http://example.com/api/chat',
      \   "captured options":
      \   {
      \     "out_cb": function("LLMChat#send_chat#SpoolChatExecStdOut"),
      \     "exit_cb": function("LLMChat#send_chat#HandleChatResponse"),
      \     "out_mode": "nl"
      \   },
      \   "parse dict":
      \   {
      \     "header":
      \     {
      \       "server type": "Ollama",
      \       "server url": "http://example.com",
      \       "model id": "Foo",
      \     },
      \     "messages":
      \     [
      \       {
      \         "user": "My test message."
      \       }
      \     ]
      \   },
      \   "stdout": '',
      \   "buffer number": l:chat_buf_num,
      \   "buffer textwidth": l:chat_text_width,
      \   "buffer line count": (len(l:chat_doc_lines) + 1),
      \   "request payload filename": l:request_payload_file,
      \   "response payload filename": l:response_payload_file
      \ }

    " NOTE: There is currently not a good way to validate the attached timestamp as the means to do this are system
    "       dependent (at least according to the documentation).  For now we will just fudge the comparison for this
    "       by retrieving the value, if it exists, from the actual dictionary then adding it to the expected dictionary.
    "       This will allow the dictionary content comparison to move forward without hanging up on the fact that we
    "       don't know the exact timestamp captured.
    "
    "       If a system independent way to validate timestamp ranges can be found than this test should be augmented to
    "       use it; at least then we could show that the captured timestamp came within the interval of (1) right before
    "       the InitiateChatInteraction() function was called to (2) the time right after such function returned.
    "
    if has_key(l:actual_chat_exec_dict, "timestamp")
        let l:expected_chat_exec_dict["timestamp"] = l:actual_chat_exec_dict["timestamp"]
    endif

    call s:testutil.AssertEqualDictionaries(expand('<sflnum>') - 9,
                                          \ '',
                                          \ l:expected_chat_exec_dict,
                                          \ l:actual_chat_exec_dict)

    " Now cleanup after the test by taking the following actions:
    "
    "   1). Forcibly remove the test chat buffer along with its content (bd! command)
    "   2). Invoke function AbortRunningChatExec() to cleanup the chat execution dictionary and return things to a
    "       consistent state.
    "   3). Unset the 'g:llmchat_test_bypass_mode' variable to restore the editor state.
    "   4). Remove the request and response payload files created by the test execution.
    "
    bd!
    call LLMChat#send_chat#AbortRunningChatExec()
    unlet g:llmchat_test_bypass_mode
    call delete(l:request_payload_file)
    call delete(l:response_payload_file)

endfunction


" This test asserts the proper operation of function InitiateChatInteraction() when it is invoked on a chat buffer that
" contains valid content for interacting with an Open-WebUI server.
function s:TestInitiateChatInteractionWithChatDocForOpenWebUI()
    " Since we have two identifiers that we're using for Open-WebUI (the official "Open WebUI" identifier discussed in
    " the plugin documentation as well as the "Open-WebUI" identifier that we're also allowing) we will run the body
    " of this test more than once; each pass trying a different server type identifier string.
    for l:server_id in [ "Open WebUI", "Open-WebUI" ]
        " Set the 'g:llmchat_test_bypass_mode' variable to a value of 1 so that execution of the function does NOT
        " submit an actual job for running.  Instead, when bypass mode is set, the command and supporting job
        " information will be captured into the chat execution dictionary where we can validate it later.
        let g:llmchat_test_bypass_mode = 1


        " Open a new empty split that will serve as our test chat log document.  Note that we will also capture the
        " number for the new chat buffer, as well as its text width, then store these into some local variables for
        " later user.
        new
        let l:chat_buf_num = bufnr('%')
        let l:chat_text_width = &textwidth


        " Now load the empty buffer with a test chat document appropriate for interactions with Open-WebUI.
        let l:chat_doc_lines = [
                             \   "Server Type: " .. l:server_id,
                             \   "Server URL: http://example.com",
                             \   "Model ID: Foo",
                             \   "* ENDSETUP *",
                             \   ">>>My test message.",
                             \   "<<<"
                             \ ]

        call appendbufline('%', '$', l:chat_doc_lines)


        " Set the 'filetype' for the new chat document to 'chtlg'.  Why did we wait until now for this?  For this test
        " we want to avoid having the buffer initialized with the boilerplate chat document so we need to make sure that
        " we have added content to the buffer BEFORE setting the filetype.
        set filetype=chtlg


        " Invoke the InitiateChatInteraction() function to process the test buffer content and create a job that *would*
        " initiate an interaction with the remote LLM server.
        call LLMChat#send_chat#InitiateChatInteraction()


        " Retrieve the chat execution dictionary so that we can validate its content.
        let l:actual_chat_exec_dict = LLMChat#send_chat#GetCurrChatExecDict()


        " Validate the 'request payload filename' and 'response payload filename' fields found within the retrieved
        " chat execution dictionary.  We expect both fields to be defined and to hold non-empty values.
        if has_key(l:actual_chat_exec_dict, "request payload filename")
            " Retrieve the 'request payload filename' into a local variable then assert that it is NOT empty.  Note that
            " validation of the file's contents will happen later on.
            let l:request_payload_file = l:actual_chat_exec_dict["request payload filename"]

            AssertIsNot!('', l:request_payload_file)
        else
            " In this case the field was missing so we will fail the test; this is required and would hold the payload
            " data for the request to be made to the Ollama server.
            call s:testutil.Fail(expand('<sflnum>') - 9,
                               \ "Expected to find a field named 'request payload filename' within the content of " ..
                               \ "the chat execution dictionary setup by function InitiateChatInteraction() but no " ..
                               \ "such field existed.")
        endif

        if has_key(l:actual_chat_exec_dict, "response payload filename")
            " Retrieve the 'response payload filename' into a local variable then assert that it is NOT empty.  Note
            " that validation of the file's contents will happen later on.
            let l:response_payload_file = l:actual_chat_exec_dict["response payload filename"]

            AssertIsNot!('', l:response_payload_file)
        else
            " In this case the field was missing so we will fail the test; this is required and would hold the response
            " payload returned from the LLM.
            call s:testutil.Fail(expand('<sflnum>') - 9,
                               \ "Expected to find a field named 'response payload filename' within the content of " ..
                               \ "the chat execution dictionary setup by function InitiateChatInteraction() but no " ..
                               \ "such field existed.")
        endif


        " Validate that the request payload file contains the expected JSON content for the initiated chat interaction.
        let l:actual_payload_text = join(readfile(l:request_payload_file), "\n")

        let l:expected_payload_text = "{" ..
                                  \ "\n  \"model\": \"Foo\"," ..
                                  \ "\n  \"stream\": false," ..
                                  \ "\n  \"messages\":" ..
                                  \ "\n    [" ..
                                  \ "\n      {" ..
                                  \ "\n        \"role\": \"user\"," ..
                                  \ "\n        \"content\": \"My test message.\"" ..
                                  \ "\n      }" ..
                                  \ "\n    ]" ..
                                  \ "\n}"

        call s:testutil.AssertEqualTextBlocks(expand('<sflnum>') - 9,
                                            \ '',
                                            \ l:expected_payload_text,
                                            \ l:actual_payload_text)


        " Verify that the response payload file is empty (IF such file exists); the request has not been sent so we
        " should not see any data being stored yet.  Note that if the file does not exist we will consider the check
        " passed as the primary concern for testing is to ensure that a chat interaction is not starting off with a
        " dirty state (i.e., lingering response data from something is already present and cluttering things up).
        if filereadable(l:response_payload_file)
            AssertEquals("", join(readfile(l:response_payload_file), "\n"))
        endif


        " Define the full content of the chat execution dictionary we *expect* to see and then assert that
        " l:chat_exec_dict is equal to such dictionary.
        "
        " NOTE: To compute the "buffer line count" we will use the length of list 'l:chat_doc_lines' and add 1 to it.
        "       We must add one because the append operation used to inject content into the test buffer leaves a
        "       leading empty line at the top (hence the document content is one line longer than the content we
        "       insert).
        "
        let l:expected_chat_exec_dict =
          \ {
          \   "captured command": 'curl -X POST ' ..
          \                       '--header "Content-Type: application/json; charset=' .. &encoding .. '" ' ..
          \                       '--data "@' .. l:request_payload_file .. '" ' ..
          \                       '--output "' .. l:response_payload_file .. '" ' ..
          \                       '--write-out "%{http_code}" ' ..
          \                       '--silent ' ..
          \                       '--show-error ' ..
          \                       '--location ' ..
          \                       'http://example.com/api/chat/completions',
          \   "captured options":
          \   {
          \     "out_cb": function("LLMChat#send_chat#SpoolChatExecStdOut"),
          \     "exit_cb": function("LLMChat#send_chat#HandleChatResponse"),
          \     "out_mode": "nl"
          \   },
          \   "parse dict":
          \   {
          \     "header":
          \     {
          \       "server type": l:server_id,
          \       "server url": "http://example.com",
          \       "model id": "Foo",
          \     },
          \     "messages":
          \     [
          \       {
          \         "user": "My test message."
          \       }
          \     ]
          \   },
          \   "stdout": '',
          \   "buffer number": l:chat_buf_num,
          \   "buffer textwidth": l:chat_text_width,
          \   "buffer line count": (len(l:chat_doc_lines) + 1),
          \   "request payload filename": l:request_payload_file,
          \   "response payload filename": l:response_payload_file
          \ }

        " NOTE: There is currently not a good way to validate the attached timestamp as the means to do this are system
        "       dependent (at least according to the documentation).  For now we will just fudge the comparison for this
        "       by retrieving the value, if it exists, from the actual dictionary then adding it to the expected
        "       dictionary.  This will allow the dictionary content comparison to move forward without hanging up on the
        "       fact that we don't know the exact timestamp captured.
        "
        "       If a system independent way to validate timestamp ranges can be found than this test should be augmented
        "       to use it; at least then we could show that the captured timestamp came within the interval of (1) right
        "       before the InitiateChatInteraction() function was called to (2) the time right after such function
        "       returned.
        "
        if has_key(l:actual_chat_exec_dict, "timestamp")
            let l:expected_chat_exec_dict["timestamp"] = l:actual_chat_exec_dict["timestamp"]
        endif

        call s:testutil.AssertEqualDictionaries(expand('<sflnum>') - 9,
                                              \ '',
                                              \ l:expected_chat_exec_dict,
                                              \ l:actual_chat_exec_dict)

        " Now cleanup after the test by taking the following actions:
        "
        "   1). Forcibly remove the test chat buffer along with its content (bd! command)
        "   2). Invoke function AbortRunningChatExec() to cleanup the chat execution dictionary and return things to a
        "       consistent state.
        "   3). Unset the 'g:llmchat_test_bypass_mode' variable to restore the editor state.
        "   4). Remove the request and response payload files created by the test execution.
        "
        bd!
        call LLMChat#send_chat#AbortRunningChatExec()
        unlet g:llmchat_test_bypass_mode
        call delete(l:request_payload_file)
        call delete(l:response_payload_file)

    endfor

endfunction


" This test asserts the proper operation of function InitiateChatInteraction() when it is invoked while debug mode
" is enabled.
function s:TestInitiateChatInteractionWithEnabledDebugMode()
    " Request a temporary file from Vim and then set the debug target to point to such file.  This will enable debug
    " mode during the test execution and will spool the output to the allocated temporary file.
    let l:debug_out_file = tempname()
    let g:llmchat_debug_mode_target = l:debug_out_file


    " Set the 'g:llmchat_test_bypass_mode' variable to a value of 1 so that execution of the function does NOT submit an
    " actual job for running.  Instead, when bypass mode is set, the command and supporting job information will be
    " captured into the chat execution dictionary where we can validate it later.
    let g:llmchat_test_bypass_mode = 1


    " Open a new empty split that will serve as our test chat log document.  Note that we will also capture the number
    " for the new chat buffer, as well as its text width, then store these into some local variables for later user.
    new
    let l:chat_buf_num = bufnr('%')
    let l:chat_text_width = &textwidth


    " Now load the empty buffer with a test chat document appropriate for interactions with a supported LLM server.
    let l:chat_doc_lines = [
                         \   "Server Type: Ollama",
                         \   "Server URL: http://example.com",
                         \   "Model ID: Foo",
                         \   "* ENDSETUP *",
                         \   ">>>My test message.",
                         \   "<<<"
                         \ ]

    call appendbufline('%', '$', l:chat_doc_lines)


    " Set the 'filetype' for the new chat document to 'chtlg'.  Why did we wait until now for this?  For this test
    " we want to avoid having the buffer initialized with the boilerplate chat document so we need to make sure that
    " we have added content to the buffer BEFORE setting the filetype.
    set filetype=chtlg


    " Invoke the InitiateChatInteraction() function to process the test buffer content and create a job that *would*
    " initiate an interaction with the remote LLM server.
    call LLMChat#send_chat#InitiateChatInteraction()


    " Retrieve the chat execution dictionary so that we can validate its content.
    let l:actual_chat_exec_dict = LLMChat#send_chat#GetCurrChatExecDict()


    " Validate the 'request payload filename', 'response payload filename', and 'response header filename' fields found
    " within the retrieved chat execution dictionary.  We expect all fields to be defined and to hold non-empty values.
    if has_key(l:actual_chat_exec_dict, "request payload filename")
        " Retrieve the 'request payload filename' into a local variable then assert that it is NOT empty.  Note that
        " validation of the file's contents will happen later on.
        let l:request_payload_file = l:actual_chat_exec_dict["request payload filename"]

        AssertIsNot!('', l:request_payload_file)
    else
        " In this case the field was missing so we will fail the test; this is required and would hold the payload
        " data for the request to be made to the Ollama server.
        call s:testutil.Fail(expand('<sflnum>') - 9,
                           \ "Expected to find a field named 'request payload filename' within the content of the " ..
                           \ "chat execution dictionary setup by function InitiateChatInteraction() but no such " ..
                           \ "field existed.")
    endif

    if has_key(l:actual_chat_exec_dict, "response payload filename")
        " Retrieve the 'response payload filename' into a local variable then assert that it is NOT empty.  Note that
        " validation of the file's contents will happen later on.
        let l:response_payload_file = l:actual_chat_exec_dict["response payload filename"]

        AssertIsNot!('', l:response_payload_file)
    else
        " In this case the field was missing so we will fail the test; this is required and would hold the response
        " payload returned from the LLM.
        call s:testutil.Fail(expand('<sflnum>') - 9,
                           \ "Expected to find a field named 'response payload filename' within the content of the " ..
                           \ "chat execution dictionary setup by function InitiateChatInteraction() but no such " ..
                           \ "field existed.")
    endif

    if has_key(l:actual_chat_exec_dict, "response header filename")
        " Retrieve the 'response header filename' into a local variable then assert that it is NOT empty.  Note that
        " validation of the file's contents will happen later on.
        let l:response_header_file = l:actual_chat_exec_dict["response header filename"]

        AssertIsNot!('', l:response_header_file)
    else
        " In this case the field was missing so we will fail the test; this is required and would hold the header data
        " from the response returned from the LLM.
        call s:testutil.Fail(expand('<sflnum>') - 9,
                           \ "Expected to find a field named 'response header filename' within the content of the " ..
                           \ "chat execution dictionary setup by function InitiateChateInteraction() but no such " ..
                           \ "field existed.")
    endif


    " Validate that the request payload file contains the expected JSON content for the initiated chat interaction.
    let l:actual_payload_text = join(readfile(l:request_payload_file), "\n")

    let l:expected_payload_text = "{" ..
                              \ "\n  \"model\": \"Foo\"," ..
                              \ "\n  \"think\": false," ..
                              \ "\n  \"stream\": false," ..
                              \ "\n  \"messages\":" ..
                              \ "\n    [" ..
                              \ "\n      {" ..
                              \ "\n        \"role\": \"user\"," ..
                              \ "\n        \"content\": \"My test message.\"" ..
                              \ "\n      }" ..
                              \ "\n    ]" ..
                              \ "\n}"

    call s:testutil.AssertEqualTextBlocks(expand('<sflnum>') - 9, '', l:expected_payload_text, l:actual_payload_text)


    " Verify that the response payload file is empty (IF such file exists); the request has not been sent so we should
    " not see any data being stored yet.  Note that if the file does not exist we will consider the check passed as the
    " primary concern for testing is to ensure that a chat interaction is not starting off with a dirty state (i.e.,
    " lingering response data from something is already present and cluttering things up).
    if filereadable(l:response_payload_file)
        AssertEquals("", join(readfile(l:response_payload_file), "\n"))
    endif


    " Verify that the response header file is empty (IF such file exists); the request has not been sent so we should
    " not see any data being stored yet.  Note that if the file does not exist we will consider the check passed as the
    " primary concern for testing is to ensure that a chat interaction is not starting off with a dirty state (i.e.,
    " lingering response header data from somthing that was previously run).
    if filereadable(l:response_header_file)
        AssertEquals("", join(readfile(l:response_header_file), "\n"))
    endif


    " Define the full content of the chat execution dictionary we *expect* to see and then assert that l:chat_exec_dict
    " is equal to such dictionary.
    "
    " NOTE: To compute the "buffer line count" we will use the length of list 'l:chat_doc_lines' and add 1 to it.  We
    "       must add one because the append operation used to inject content into the test buffer leaves a leading
    "       empty line at the top (hence the document content is one line longer than the content we insert).
    "
    let l:expected_chat_exec_dict =
      \ {
      \   "captured command": 'curl -X POST ' ..
      \                       '--header "Content-Type: application/json; charset=' .. &encoding .. '" ' ..
      \                       '--data "@' .. l:request_payload_file .. '" ' ..
      \                       '--output "' .. l:response_payload_file .. '" ' ..
      \                       '--write-out "%{http_code}" ' ..
      \                       '--silent ' ..
      \                       '--show-error ' ..
      \                       '--location ' ..
      \                       '--dump-header "' .. l:response_header_file .. '" ' ..
      \                       'http://example.com/api/chat',
      \   "captured options":
      \   {
      \     "out_cb": function("LLMChat#send_chat#SpoolChatExecStdOut"),
      \     "exit_cb": function("LLMChat#send_chat#HandleChatResponse"),
      \     "out_mode": "nl"
      \   },
      \   "parse dict":
      \   {
      \     "header":
      \     {
      \       "server type": "Ollama",
      \       "server url": "http://example.com",
      \       "model id": "Foo",
      \     },
      \     "messages":
      \     [
      \       {
      \         "user": "My test message."
      \       }
      \     ]
      \   },
      \   "stdout": '',
      \   "buffer number": l:chat_buf_num,
      \   "buffer textwidth": l:chat_text_width,
      \   "buffer line count": (len(l:chat_doc_lines) + 1),
      \   "request payload filename": l:request_payload_file,
      \   "response payload filename": l:response_payload_file,
      \   "response header filename": l:response_header_file
      \ }

    " NOTE: There is currently not a good way to validate the attached timestamp as the means to do this are system
    "       dependent (at least according to the documentation).  For now we will just fudge the comparison for this
    "       by retrieving the value, if it exists, from the actual dictionary then adding it to the expected dictionary.
    "       This will allow the dictionary content comparison to move forward without hanging up on the fact that we
    "       don't know the exact timestamp captured.
    "
    "       If a system independent way to validate timestamp ranges can be found than this test should be augmented to
    "       use it; at least then we could show that the captured timestamp came within the interval of (1) right before
    "       the InitiateChatInteraction() function was called to (2) the time right after such function returned.
    "
    if has_key(l:actual_chat_exec_dict, "timestamp")
        let l:expected_chat_exec_dict["timestamp"] = l:actual_chat_exec_dict["timestamp"]
    endif

    call s:testutil.AssertEqualDictionaries(expand('<sflnum>') - 9,
                                          \ '',
                                          \ l:expected_chat_exec_dict,
                                          \ l:actual_chat_exec_dict)

    " Verify that the "debug target" file exists and has non-empty content.  This simply shows that debug mode was in
    " effect during execution of the test AND that debug data was actually collected.
    "
    " NOTE: We don't use an '!' on the AssertTxt() call because we want the test to try to cleanup after itself even
    "       if there are assertion faults; the cleanup is also a little too specific to move down into the Teardown()
    "       function.  This is also why we do a safety check for file readability BEFORE trying to verify that the
    "       debug target file holds content.
    "
    AssertTxt(filereadable(l:debug_out_file), "No debug output file found for the test execution!")
    if(filereadable(l:debug_out_file))
        let l:debug_file_lines = readfile(l:debug_out_file)
        AssertTxt(len(l:debug_file_lines) > 0,
                \ "The debug output file was found to be empty when this was expected to contain information.")
    endif


    " Now cleanup after the test by taking the following actions:
    "
    "   1). Forcibly remove the test chat buffer along with its content (bd! command)
    "   2). Invoke function AbortRunningChatExec() to cleanup the chat execution dictionary and return things to a
    "       consistent state.
    "   3). Unset the 'g:llmchat_test_bypass_mode' variable to restore the editor state.
    "   4). Remove the request payload file as well as any response payload/header files that may have been created by
    "       the test execution.
    "   5). Unset the 'g:llmchat_debug_mode_target' variable to disable debug mode.
    "   6). Remove the debug output target file now that we're done with the test.
    "
    bd!
    call LLMChat#send_chat#AbortRunningChatExec()
    unlet g:llmchat_test_bypass_mode
    call delete(l:request_payload_file)
    call delete(l:response_payload_file)
    call delete(l:response_header_file)
    unlet g:llmchat_debug_mode_target
    call delete(l:debug_out_file)

endfunction


" This test asserts the proper operation of function InitiateChatInteraction() when it is invoked within the context
" of a chat document that requires authentication be provided.
function s:TestInitiateChatInteractionWithRequiredAuth()
    " Set the 'g:llmchat_test_bypass_mode' variable to a value of 1 so that execution of the function does NOT submit an
    " actual job for running.  Instead, when bypass mode is set, the command and supporting job information will be
    " captured into the chat execution dictionary where we can validate it later.
    let g:llmchat_test_bypass_mode = 1


    " Open a new empty split that will serve as our test chat log document.  Note that we will also capture the number
    " for the new chat buffer, as well as its text width, then store these into some local variables for later user.
    new
    let l:chat_buf_num = bufnr('%')
    let l:chat_text_width = &textwidth


    " Load the empty buffer with a test chat document which indicates not only that authentication is required but
    " which also supplies the credentials to use (note that for this test the resolution of credentials is out of scope
    " so loading credentials into the document is simply an easy way to set them up).
    let l:chat_doc_lines = [
                         \   "Server Type: Ollama",
                         \   "Server URL: http://example.com",
                         \   "Model ID: Foo",
                         \   "Use Auth Token: true",
                         \   "Auth Token: abc123",
                         \   "* ENDSETUP *",
                         \   ">>>My test message.",
                         \   "<<<"
                         \ ]

    call appendbufline('%', '$', l:chat_doc_lines)


    " Set the 'filetype' for the new chat document to 'chtlg'.  Why did we wait until now for this?  For this test
    " we want to avoid having the buffer initialized with the boilerplate chat document so we need to make sure that
    " we have added content to the buffer BEFORE setting the filetype.
    set filetype=chtlg


    " Invoke the InitiateChatInteraction() function to process the test buffer content and create a job that *would*
    " initiate an interaction with the remote LLM server.
    call LLMChat#send_chat#InitiateChatInteraction()


    " Retrieve the chat execution dictionary so that we can validate its content.
    let l:actual_chat_exec_dict = LLMChat#send_chat#GetCurrChatExecDict()


    " Validate the 'request payload filename' and 'response payload filename' fields found within the retrieved
    " chat execution dictionary.  We expect both fields to be defined and to hold non-empty values.
    if has_key(l:actual_chat_exec_dict, "request payload filename")
        " Retrieve the 'request payload filename' into a local variable then assert that it is NOT empty.  Note that
        " validation of the file's contents will happen later on.
        let l:request_payload_file = l:actual_chat_exec_dict["request payload filename"]

        AssertIsNot!('', l:request_payload_file)
    else
        " In this case the field was missing so we will fail the test; this is required and would hold the payload
        " data for the request to be made to the Ollama server.
        call s:testutil.Fail(expand('<sflnum>') - 9,
                           \ "Expected to find a field named 'request payload filename' within the content of the " ..
                           \ "chat execution dictionary setup by function InitiateChatInteraction() but no such " ..
                           \ "field existed.")
    endif

    if has_key(l:actual_chat_exec_dict, "response payload filename")
        " Retrieve the 'response payload filename' into a local variable then assert that it is NOT empty.  Note that
        " validation of the file's contents will happen later on.
        let l:response_payload_file = l:actual_chat_exec_dict["response payload filename"]

        AssertIsNot!('', l:response_payload_file)
    else
        " In this case the field was missing so we will fail the test; this is required and would hold the response
        " payload returned from the LLM.
        call s:testutil.Fail(expand('<sflnum>') - 9,
                           \ "Expected to find a field named 'response payload filename' within the content of the " ..
                           \ "chat execution dictionary setup by function InitiateChatInteraction() but no such " ..
                           \ "field existed.")
    endif


    " Validate that the request payload file contains the expected JSON content for the initiated chat interaction.
    let l:actual_payload_text = join(readfile(l:request_payload_file), "\n")

    let l:expected_payload_text = "{" ..
                              \ "\n  \"model\": \"Foo\"," ..
                              \ "\n  \"think\": false," ..
                              \ "\n  \"stream\": false," ..
                              \ "\n  \"messages\":" ..
                              \ "\n    [" ..
                              \ "\n      {" ..
                              \ "\n        \"role\": \"user\"," ..
                              \ "\n        \"content\": \"My test message.\"" ..
                              \ "\n      }" ..
                              \ "\n    ]" ..
                              \ "\n}"

    call s:testutil.AssertEqualTextBlocks(expand('<sflnum>') - 9, '', l:expected_payload_text, l:actual_payload_text)


    " Verify that the response payload file is empty (IF such file exists); the request has not been sent so we should
    " not see any data being stored yet.  Note that if the file does not exist we will consider the check passed as the
    " primary concern for testing is to ensure that a chat interaction is not starting off with a dirty state (i.e.,
    " lingering response data from something is already present and cluttering things up).
    if filereadable(l:response_payload_file)
        AssertEquals("", join(readfile(l:response_payload_file), "\n"))
    endif


    " Define the full content of the chat execution dictionary we *expect* to see and then assert that l:chat_exec_dict
    " is equal to such dictionary.
    "
    " NOTE: To compute the "buffer line count" we will use the length of list 'l:chat_doc_lines' and add 1 to it.  We
    "       must add one because the append operation used to inject content into the test buffer leaves a leading
    "       empty line at the top (hence the document content is one line longer than the content we insert).
    "
    let l:expected_chat_exec_dict =
      \ {
      \   "captured command": 'curl -X POST ' ..
      \                       '--header "Content-Type: application/json; charset=' .. &encoding .. '" ' ..
      \                       '--data "@' .. l:request_payload_file .. '" ' ..
      \                       '--output "' .. l:response_payload_file .. '" ' ..
      \                       '--write-out "%{http_code}" ' ..
      \                       '--silent ' ..
      \                       '--show-error ' ..
      \                       '--location ' ..
      \                       '--header "Authorization: Bearer abc123" ' ..
      \                       'http://example.com/api/chat',
      \   "captured options":
      \   {
      \     "out_cb": function("LLMChat#send_chat#SpoolChatExecStdOut"),
      \     "exit_cb": function("LLMChat#send_chat#HandleChatResponse"),
      \     "out_mode": "nl"
      \   },
      \   "parse dict":
      \   {
      \     "header":
      \     {
      \       "server type": "Ollama",
      \       "server url": "http://example.com",
      \       "model id": "Foo",
      \       "use auth": "true",
      \       "auth key": "abc123"
      \     },
      \     "messages":
      \     [
      \       {
      \         "user": "My test message."
      \       }
      \     ]
      \   },
      \   "stdout": '',
      \   "buffer number": l:chat_buf_num,
      \   "buffer textwidth": l:chat_text_width,
      \   "buffer line count": (len(l:chat_doc_lines) + 1),
      \   "request payload filename": l:request_payload_file,
      \   "response payload filename": l:response_payload_file
      \ }

    " NOTE: There is currently not a good way to validate the attached timestamp as the means to do this are system
    "       dependent (at least according to the documentation).  For now we will just fudge the comparison for this
    "       by retrieving the value, if it exists, from the actual dictionary then adding it to the expected dictionary.
    "       This will allow the dictionary content comparison to move forward without hanging up on the fact that we
    "       don't know the exact timestamp captured.
    "
    "       If a system independent way to validate timestamp ranges can be found than this test should be augmented to
    "       use it; at least then we could show that the captured timestamp came within the interval of (1) right before
    "       the InitiateChatInteraction() function was called to (2) the time right after such function returned.
    "
    if has_key(l:actual_chat_exec_dict, "timestamp")
        let l:expected_chat_exec_dict["timestamp"] = l:actual_chat_exec_dict["timestamp"]
    endif

    call s:testutil.AssertEqualDictionaries(expand('<sflnum>') - 9,
                                          \ '',
                                          \ l:expected_chat_exec_dict,
                                          \ l:actual_chat_exec_dict)

    " Now cleanup after the test by taking the following actions:
    "
    "   1). Forcibly remove the test chat buffer along with its content (bd! command)
    "   2). Invoke function AbortRunningChatExec() to cleanup the chat execution dictionary and return things to a
    "       consistent state.
    "   3). Unset the 'g:llmchat_test_bypass_mode' variable to restore the editor state.
    "   4). Remove the request and response payload files created by the test execution.
    "
    bd!
    call LLMChat#send_chat#AbortRunningChatExec()
    unlet g:llmchat_test_bypass_mode
    call delete(l:request_payload_file)
    call delete(l:response_payload_file)

endfunction


" This test asserts that an expected exception is thrown from the InitiateChatInteraction() function when it is invoked
" in the context of a chat that contains NO messages (only header data).
function s:TestInitiateChatInteractionWithNoMessages()
    " Set the 'g:llmchat_test_bypass_mode' variable to a value of 1 so that execution of the function is aware that it
    " is being called from a test; currently this is how we get the logic to throw the exception outside of the function
    " rather than catch it and display the exception message to the user.
    let g:llmchat_test_bypass_mode = 1


    " Open a new empty split that will serve as our test chat log document.  Note that we will also capture the number
    " for the new chat buffer, as well as its text width, then store these into some local variables for later user.
    new
    let l:chat_buf_num = bufnr('%')
    let l:chat_text_width = &textwidth


    " Load the buffer with a chat document that only contains header data.
    let l:chat_doc_lines = [
                         \   "Server Type: Ollama",
                         \   "Server URL: http://example.com",
                         \   "Model ID: Foo",
                         \   "* ENDSETUP *"
                         \ ]

    call appendbufline('%', '$', l:chat_doc_lines)


    " Set the 'filetype' for the new chat document to 'chtlg'.  Why did we wait until now for this?  For this test
    " we want to avoid having the buffer initialized with the boilerplate chat document so we need to make sure that
    " we have added content to the buffer BEFORE setting the filetype.
    set filetype=chtlg


    try
        " Now attempt to invoke the InitiateChatInteraction() function to process the test chat document; if things are
        " working as expected the function execution should detect that the document contains no messages and should
        " throw an exception.
        call LLMChat#send_chat#InitiateChatInteraction()


        " If test execution makes it here than automatically fail it; an exception should have been thrown earlier if
        " the logic was working as intended which would make this code unreachable.
        call s:testutil.Fail(expand('<sflnum>') - 9,
                           \ "Expected to see an exception thrown from function InitiateChatInteraction() when it " ..
                           \ "was invoked to process a chat document that contained NO messages; however, no " ..
                           \ "exception occurred.")

    catch /\c[warn].*no messages.*/
        " In this case we just caught an exception whose message seems to match the message we expected to see; allow
        " the test to proceed as this is what should have happened if the code was working as intended.

    endtry


    " Now cleanup after the test by taking the following actions:
    "
    "   1). Forcibly remove the test chat buffer along with its content (bd! command)
    "   2). Invoke function AbortRunningChatExec() to cleanup the chat execution dictionary and return things to a
    "       consistent state.
    "   3). Unset the 'g:llmchat_test_bypass_mode' variable to restore the editor state.
    "
    bd!
    call LLMChat#send_chat#AbortRunningChatExec()
    unlet g:llmchat_test_bypass_mode

endfunction


" This test asserts that an expected exception is thrown from the InitiateChatInteraction() function when it is invoked
" in the context of a chat whose last message is from the assistant (e.g., there is no trailing user message to expect
" an LLM response to).
function s:TestInitiateChatInteractionWithMissingEndUserMessage()
    " Set the 'g:llmchat_test_bypass_mode' variable to a value of 1 so that execution of the function is aware that it
    " is being called from a test; currently this is how we get the logic to throw the exception outside of the function
    " rather than catch it and display the exception message to the user.
    let g:llmchat_test_bypass_mode = 1


    " Open a new empty split that will serve as our test chat log document.  Note that we will also capture the number
    " for the new chat buffer, as well as its text width, then store these into some local variables for later user.
    new
    let l:chat_buf_num = bufnr('%')
    let l:chat_text_width = &textwidth


    " Load the buffer with a chat document that contains a completed interaction (i.e., the user message already has an
    " assistant response).
    let l:chat_doc_lines = [
                         \   "Server Type: Ollama",
                         \   "Server URL: http://example.com",
                         \   "Model ID: Foo",
                         \   "* ENDSETUP *",
                         \   ">>>How are you today?",
                         \   "<<<",
                         \   "=>>I am just a program so I don't have feelings; I am ready to assist you though.",
                         \   "<<="]

    call appendbufline('%', '$', l:chat_doc_lines)


    " Set the 'filetype' for the new chat document to 'chtlg'.  Why did we wait until now for this?  For this test we
    " want to avoid having the buffer initialized with the boilerplate chat document so we need to make sure that we
    " have added content to the buffer BEFORE setting the filetype.
    set filetype=chtlg

    try
        " Attempt to invoke the InitiateChatInteraction() function to process the test chat document; if things are
        " working as expected the function execution should detect that no new user message exists to submit and it
        " should throw an exception.
        call LLMChat#send_chat#InitiateChatInteraction()


        " If the test execution makes it here than automatically fail it; an exception should have been thrown earlier
        " if the logic was working as intended and that would make this statement unreachable.
        call s:testutil.Fail(expand('<sflnum>') - 9,
                           \ "Expected to see an exception thrown from function InitateChatInteraction() when the " ..
                           \ "document it was invoked to process ended with an assistant message; however, no " ..
                           \ "exception occurred.")

    catch /\c[warn].*already has an assistant response.*/
        " If the logic comes here than we caught an exception whose message appears to match the exception message we
        " expected to see; allow the test to proceed as the logic appears to be working as intended.

    endtry


    " Now cleanup after the test by taking the following actions:
    "
    "   1). Forcibly remove the test chat buffer along with its content (bd! command)
    "   2). Invoke function AbortRunningChatExec() to cleanup the chat execution dictionary and return things to a
    "       consistent state.
    "   3). Unset the 'g:llmchat_test_bypass_mode' variable to restore the editor state.
    "
    bd!
    call LLMChat#send_chat#AbortRunningChatExec()
    unlet g:llmchat_test_bypass_mode

endfunction


" This test asserts that an expected exception is thrown from the InitiateChatInteraction() function when it is invoked
" in the context of a chat that uses an unknown server type.
function s:TestInitiateChatInteractionWithUnknownServerType()
    " Set the 'g:llmchat_test_bypass_mode' variable to a value of 1 so that execution of the function is aware that it
    " is being called from a test; currently this is how we get the logic to throw the exception outside of the function
    " rather than catch it and display the exception message to the user.
    let g:llmchat_test_bypass_mode = 1


    " Open a new empty split that will serve as our test chat log document.  Note that we will also capture the number
    " for the new chat buffer, as well as its text width, then store these into some local variables for later user.
    new
    let l:chat_buf_num = bufnr('%')
    let l:chat_text_width = &textwidth


    " Load the test buffer with an invalid chat document that references an unknown server type.
    let l:chat_doc_lines = [
                         \   "Server Type: Awesome Server",
                         \   "Server URL: http://example.com",
                         \   "Model ID: Foo",
                         \   "* ENDSETUP *",
                         \   ">>>How are you today?"
                         \ ]

    call appendbufline('%', '$', l:chat_doc_lines)


    " Set the 'filetype' for the new chat document to 'chtlg'.  Why did we wait until now for this?  For this test
    " we want to avoid having the buffer initialized with the boilerplate chat document so we need to make sure that
    " we have added content to the buffer BEFORE setting the filetype.
    set filetype=chtlg


    try
        " Now attempt to invoke the InitateChatInteraction() function to process the test chat document; if things are
        " working as expected the function execution should detect that we have provided an unrecognized server type
        " then throw an exception.
        call LLMChat#send_chat#InitiateChatInteraction()


        " If the test execution makes it here than automatically fail it; an exception should have been thrown earlier
        " if the logic was working as intended which would make this code unreachable.
        call s:testutil.Fail(expand('<sflnum>') - 9,
                           \ "Expected to see an exception thrown from function InitateChatInteraction() when it " ..
                           \ "was invoked to process a chat document that contained an unknown server type; " ..
                           \ "however, no exception occurred.")

    catch /\c[error].*'server type'.*/
        " If the logic comes here than we caught an exception whose message appears to match the content of the message
        " we expected to see; let the test proceed as this is what should have happened if the logic was working
        " correctly.
    endtry


    " Now cleanup after the test by taking the following actions:
    "
    "   1). Forcibly remove the test chat buffer along with its content (bd! command)
    "   2). Invoke function AbortRunningChatExec() to cleanup the chat execution dictionary and return things to a
    "       consistent state.
    "   3). Unset the 'g:llmchat_test_bypass_mode' variable to restore the editor state.
    "
    bd!
    call LLMChat#send_chat#AbortRunningChatExec()
    unlet g:llmchat_test_bypass_mode

endfunction


" This test asserts that function InitiateChatInteraction() will include any content defined by plugin variable
" 'g:llmchat_curl_extra_args' into the cURL command it creates when such variable is given a non-empty value.
function s:TestInitiateChatInteractionWithExtraCurlArgs()
    " Set the 'g:llmchat_test_bypass_mode' variable to a value of 1 so that execution of the function does NOT submit an
    " actual job for running.  Instead, when bypass mode is set, the command and supporting job information will be
    " captured into the chat execution dictionary where we can validate it later.
    let g:llmchat_test_bypass_mode = 1


    " Set the 'g:llmchat_curl_extra_args' variable to a known testing value; later we should see the content we set it
    " to be injected, verbatim, into the cURL command for chat submission.
    let g:llmchat_curl_extra_args = "-abc 123 -def 789"


    " Open a new empty split that will serve as our test chat log document.  Note that we will also capture the number
    " for the new chat buffer, as well as its text width, then store these into some local variables for later user.
    new
    let l:chat_buf_num = bufnr('%')
    let l:chat_text_width = &textwidth


    " Load the empty buffer with a valid test document of known content.
    let l:chat_doc_lines = [
                         \   "Server Type: Ollama",
                         \   "Server URL: http://example.com",
                         \   "Model ID: Foo",
                         \   "* ENDSETUP *",
                         \   ">>>My test message.",
                         \   "<<<"
                         \ ]

    call appendbufline('%', '$', l:chat_doc_lines)


    " Set the 'filetype' for the new chat document to 'chtlg'.  Why did we wait until now for this?  For this test
    " we want to avoid having the buffer initialized with the boilerplate chat document so we need to make sure that
    " we have added content to the buffer BEFORE setting the filetype.
    set filetype=chtlg


    " Invoke the InitiateChatInteraction() function to process the test buffer content and create a job that *would*
    " initiate an interaction with the remote LLM server.
    call LLMChat#send_chat#InitiateChatInteraction()


    " Retrieve the chat execution dictionary so that we can validate its content.
    let l:actual_chat_exec_dict = LLMChat#send_chat#GetCurrChatExecDict()


    " Validate the 'request payload filename' and 'response payload filename' fields found within the retrieved
    " chat execution dictionary.  We expect both fields to be defined and to hold non-empty values.
    if has_key(l:actual_chat_exec_dict, "request payload filename")
        " Retrieve the 'request payload filename' into a local variable then assert that it is NOT empty.  Note that
        " validation of the file's contents will happen later on.
        let l:request_payload_file = l:actual_chat_exec_dict["request payload filename"]

        AssertIsNot!('', l:request_payload_file)
    else
        " In this case the field was missing so we will fail the test; this is required and would hold the payload
        " data for the request to be made to the Ollama server.
        call s:testutil.Fail(expand('<sflnum>') - 9,
                           \ "Expected to find a field named 'request payload filename' within the content of the " ..
                           \ "chat execution dictionary setup by function InitiateChatInteraction() but no such " ..
                           \ "field existed.")
    endif

    if has_key(l:actual_chat_exec_dict, "response payload filename")
        " Retrieve the 'response payload filename' into a local variable then assert that it is NOT empty.  Note that
        " validation of the file's contents will happen later on.
        let l:response_payload_file = l:actual_chat_exec_dict["response payload filename"]

        AssertIsNot!('', l:response_payload_file)
    else
        " In this case the field was missing so we will fail the test; this is required and would hold the response
        " payload returned from the LLM.
        call s:testutil.Fail(expand('<sflnum>') - 9,
                           \ "Expected to find a field named 'response payload filename' within the content of the " ..
                           \ "chat execution dictionary setup by function InitiateChatInteraction() but no such " ..
                           \ "field existed.")
    endif


    " Validate that the request payload file contains the expected JSON content for the initiated chat interaction.
    let l:actual_payload_text = join(readfile(l:request_payload_file), "\n")

    let l:expected_payload_text = "{" ..
                              \ "\n  \"model\": \"Foo\"," ..
                              \ "\n  \"think\": false," ..
                              \ "\n  \"stream\": false," ..
                              \ "\n  \"messages\":" ..
                              \ "\n    [" ..
                              \ "\n      {" ..
                              \ "\n        \"role\": \"user\"," ..
                              \ "\n        \"content\": \"My test message.\"" ..
                              \ "\n      }" ..
                              \ "\n    ]" ..
                              \ "\n}"

    call s:testutil.AssertEqualTextBlocks(expand('<sflnum>') - 9, '', l:expected_payload_text, l:actual_payload_text)


    " Verify that the response payload file is empty (IF such file exists); the request has not been sent so we should
    " not see any data being stored yet.  Note that if the file does not exist we will consider the check passed as the
    " primary concern for testing is to ensure that a chat interaction is not starting off with a dirty state (i.e.,
    " lingering response data from something is already present and cluttering things up).
    if filereadable(l:response_payload_file)
        AssertEquals("", join(readfile(l:response_payload_file), "\n"))
    endif


    " Define the full content of the chat execution dictionary we *expect* to see and then assert that l:chat_exec_dict
    " is equal to such dictionary.
    "
    " NOTE: To compute the "buffer line count" we will use the length of list 'l:chat_doc_lines' and add 1 to it.  We
    "       must add one because the append operation used to inject content into the test buffer leaves a leading
    "       empty line at the top (hence the document content is one line longer than the content we insert).
    "
    let l:expected_chat_exec_dict =
      \ {
      \   "captured command": 'curl -X POST ' ..
      \                       '--header "Content-Type: application/json; charset=' .. &encoding .. '" ' ..
      \                       '--data "@' .. l:request_payload_file .. '" ' ..
      \                       '--output "' .. l:response_payload_file .. '" ' ..
      \                       '--write-out "%{http_code}" ' ..
      \                       '--silent ' ..
      \                       '--show-error ' ..
      \                       '--location ' ..
      \                       g:llmchat_curl_extra_args .. ' ' ..
      \                       'http://example.com/api/chat',
      \   "captured options":
      \   {
      \     "out_cb": function("LLMChat#send_chat#SpoolChatExecStdOut"),
      \     "exit_cb": function("LLMChat#send_chat#HandleChatResponse"),
      \     "out_mode": "nl"
      \   },
      \   "parse dict":
      \   {
      \     "header":
      \     {
      \       "server type": "Ollama",
      \       "server url": "http://example.com",
      \       "model id": "Foo"
      \     },
      \     "messages":
      \     [
      \       {
      \         "user": "My test message."
      \       }
      \     ]
      \   },
      \   "stdout": '',
      \   "buffer number": l:chat_buf_num,
      \   "buffer textwidth": l:chat_text_width,
      \   "buffer line count": (len(l:chat_doc_lines) + 1),
      \   "request payload filename": l:request_payload_file,
      \   "response payload filename": l:response_payload_file
      \ }

    " NOTE: There is currently not a good way to validate the attached timestamp as the means to do this are system
    "       dependent (at least according to the documentation).  For now we will just fudge the comparison for this
    "       by retrieving the value, if it exists, from the actual dictionary then adding it to the expected dictionary.
    "       This will allow the dictionary content comparison to move forward without hanging up on the fact that we
    "       don't know the exact timestamp captured.
    "
    "       If a system independent way to validate timestamp ranges can be found than this test should be augmented to
    "       use it; at least then we could show that the captured timestamp came within the interval of (1) right before
    "       the InitiateChatInteraction() function was called to (2) the time right after such function returned.
    "
    if has_key(l:actual_chat_exec_dict, "timestamp")
        let l:expected_chat_exec_dict["timestamp"] = l:actual_chat_exec_dict["timestamp"]
    endif

    call s:testutil.AssertEqualDictionaries(expand('<sflnum>') - 9,
                                          \ '',
                                          \ l:expected_chat_exec_dict,
                                          \ l:actual_chat_exec_dict)

    " Now cleanup after the test by taking the following actions:
    "
    "   1). Forcibly remove the test chat buffer along with its content (bd! command)
    "   2). Invoke function AbortRunningChatExec() to cleanup the chat execution dictionary and return things to a
    "       consistent state.
    "   3). Unset the 'g:llmchat_test_bypass_mode' variable to restore the editor state.
    "   4). Restore the default plugin value to variable 'g:llmchat_curl_extra_args'.
    "   5). Remove the request and response payload files created by the test execution.
    "
    bd!
    call LLMChat#send_chat#AbortRunningChatExec()
    unlet g:llmchat_test_bypass_mode

    let l:defaults_dict = s:testutil.GetGlobalVariableDefaults()
    let g:llmchat_curl_extra_args = l:defaults_dict["g:llmchat_curl_extra_args"]

    call delete(l:request_payload_file)
    call delete(l:response_payload_file)

endfunction



" **********************************************
" ****  SubmitChatExecJob() Function Tests  ****
" **********************************************

" This test asserts that a known exception is thrown from function SubmitChatExecJob() if it is invoked at a time when
" no chat job is active (i.e., the 's:curr_chat_exec_dict' is empty).
function s:TestSubmitChatExecJobWithNoActiveJob()
    " Retrieve the current chat dictionary and assert that it is empty.
    let l:curr_chat_dict = LLMChat#send_chat#GetCurrChatExecDict()
    call s:testutil.AssertEqualDictionaries(expand('<sflnum>') - 9, '', {}, l:curr_chat_dict)

    try
        " Invoke function SubmitChatExecJob() and assert that an expected exception is thrown.
        call LLMChat#send_chat#SubmitChatExecJob("", {})

        " If the test execution reaches this point than fail it; we expected to see an exception thrown before now
        " which should make this logic unreachable if things are working as expected.
        call s:testutil.Fail("Expected to see an exception thrown from function SubmitChatExecJob() when it was " ..
                           \ "invoked at a time that the current chat execution dictionary was empty; however, " ..
                           \ "no exception occurred.")

    catch /\c[error].*held no content.*/
        " This appears to be the exception we were expecting to see thrown so take no action and allow the test to
        " complete normally
    endtry

endfunction


" ************************************************
" ****  SpoolChatExecStdOut() Function Tests  ****
" ************************************************

" This test asserts the proper operation of function SpoolExecStdOut() by asserting that such function will append
" any message it receives to the 's:curr_chat_exec_dict' dictionary under an expected key.  Additionally the test will
" assert that if any content is already held by the current chat dictionary under the key to be used than the new
" message content is appended to the end of the existing data.
function s:TestSpoolChatExecStdOut()
    " Invoke function GetCurrChatExecDict() and confirm that the returned dictionary is empty.
    let l:curr_chat_dict = LLMChat#send_chat#GetCurrChatExecDict()
    call s:testutil.AssertEqualDictionaries(expand('<sflnum>') - 9, '', {}, l:curr_chat_dict)

    " Invoke function SpoolExecStdOut() using a known series of arguments.
    "
    " NOTE: We will use the empty string as the 'channel' argument for now since standard Vimscript does not perform
    "       strict type enforcement of arguments and ultimately this argument is not used by the function execution.
    "       Why do this?  We're side stepping the task of finding out what type of argument would *really* be passed
    "       by the job framework in Vim and then the work of setting up a "dummy" argument to look the same.  This
    "       WON'T work if we convert the script to vim9script syntax which is primarily why this is being called out.
    "
    call LLMChat#send_chat#SpoolChatExecStdOut('', "First message ")

    " Now call function GetCurrChatExecDict() again and assert that the message previously passed to SpoolExecStdOut()
    " is now present within the returned dictionary under an expected key.
    let l:expected_dict = { "stdout": "First message " }
    let l:curr_chat_dict = LLMChat#send_chat#GetCurrChatExecDict()

    call s:testutil.AssertEqualDictionaries(expand('<sflnum>') - 9, '', l:expected_dict, l:curr_chat_dict)

    " Invoke function SpoolExecStdOut() several more times and pass a series of known messages to each invocation.
    call LLMChat#send_chat#SpoolChatExecStdOut('', "\nSecond message\nThird line")
    call LLMChat#send_chat#SpoolChatExecStdOut('', "ThirdMessage")
    call LLMChat#send_chat#SpoolChatExecStdOut('', " Fourth Message")

    " Invoke function GetCurrChatExecDict() and assert that ALL messages which have been sent to SpoolExecStdOut()
    " during the course of testing have been accumulated under the same, known dictionary entry.
    let l:expected_dict = {
                        \    "stdout" : "First message " ..
                        \               "\nSecond message" ..
                        \               "\nThird lineThirdMessage Fourth Message"
                        \ }
    let l:curr_chat_dict = LLMChat#send_chat#GetCurrChatExecDict()

    call s:testutil.AssertEqualDictionaries(expand('<sflnum>') - 9, '', l:expected_dict, l:curr_chat_dict)

    " Invoke function AbortRunningChatExec() to clear the changes made to the current chat execution dictionary.
    "
    " NOTE: To avoid having the function output an echom statement that we have to acknowledge we will set the
    "       'g:llmchat_test_bypass_mode' to 1 right before we call it then we will unset the variable immediately after.
    let g:llmchat_test_bypass_mode = 1
    call LLMChat#send_chat#AbortRunningChatExec()
    unlet g:llmchat_test_bypass_mode

endfunction



" ***********************************************
" ****  HandleChatResponse() Function Tests  ****
" ***********************************************

" This test asserts that function HandleChatResponse() behaves as expected when processing the content of an LLM
" response returned from an Ollama server.
function s:TestHandleChatResponseWithOllamaInteraction()
    " Set the 'g:llmchat_test_bypass_mode' variable to a value of 1 so that any exceptions that might come out of the
    " HandleChatResponse() function will be properly surfaced.
    let g:llmchat_test_bypass_mode = 1


    " Set the 'g:llmchat_separator_bar_size' to a known size that way the test is insensitive to any changes that might
    " be made to the default value of this variable.
    let g:llmchat_separator_bar_size = 10


    " Request Vim to provide us with the name and path to a temporary file then write some content to the file.  Note
    " that we don't actually care what the file contains as nothing will use it; our main concern is simply that the
    " file gets created.  We will then use this file to simulate the "request payload" file during testing to verify
    " that it is removed as part of the cleanup performed by function HandleChatResponse().
    let l:request_tempfile = tempname()
    call writefile(["Some testing content"], l:request_tempfile)
    AssertTxt(filereadable(l:request_tempfile),
            \ "Unable to create a simulated request payload file on disk for testing.")


    " Create a new buffer that will be used by the testing then write a line of text to it.  Note that the
    " HandleChatResponse() function will only look at the current chat execution dictionary for its data so the content
    " we write to the buffer doesn't need to be in proper chat document format; we only do this so we can confirm that
    " content written to the buffer by the HandleChatResponse() function will appear in the correct place.
    "
    " NOTE: After running the 'new' command we assume the newly opened buffer to become the active buffer.
    new
    let l:test_lines_list = [ "Some test content", "written to the new buffer." ]
    call appendbufline('%', '$', l:test_lines_list)


    " Call a utility function to locate the "data" directory for this test then copy the content of the "response.json"
    " file found at that location to a temporary file whose path is provided by Vim.  We do this because the response
    " payload file we use will be removed by the execution of function HandleChatResponse() and we don't want to
    " delete the original test data file from the system.
    let l:response_tempfile = tempname()
    call filecopy(s:testutil.GetTestDataDir("TestHandleChatResponseWithOllamaInteraction", 1) .. "response.json",
                \ l:response_tempfile)


    " Define a test "chat execution dictionary" that will simulate the information associated with a completed chat
    " execution job and then invoke the necessary function to set it for use.
    "
    " NOTE: For this test "thinking" will be disabled and the output associated with such feature will be verified by
    "       a separate test.
    let l:test_chat_exec_dict = {
                              \   "stdout": "200",
                              \   "parse dict":
                              \   {
                              \     "header":
                              \     {
                              \       "server type": "Ollama",
                              \       "show thinking": "false"
                              \     }
                              \   },
                              \   "buffer number": bufnr(),
                              \   "buffer textwidth": "100",
                              \   "buffer line count": line("$"),
                              \   "response payload filename": l:response_tempfile,
                              \   "request payload filename": l:request_tempfile
                              \ }

    call LLMChat#send_chat#SetCurrChatExecDict(l:test_chat_exec_dict)


    " Invoke the HandleChatResponse() function such that it appears a successful response was received from an LLM.
    "
    " NOTE: The 'job_id' argument is not currently used by anything in the function so we will simply default this to
    "       the empty string for now.
    "
    call LLMChat#send_chat#HandleChatResponse('', 0)


    " Retrieve all content from the test buffer and validate that it contains (1) the original test text written to the
    " buffer as well as (2) the content we expected to see the HandleChatResponse() function update the buffer with.
    "
    " NOTE: The lines appended to the buffer by function HandleChatResponse() should follow the line length restrictions
    "       imposed by the information we put into the test chat execution dictionary.
    "
    let l:actual_list = getline(0, '$')
    let l:expected_list =
      \ [
      \   '',
      \   l:test_lines_list[0],
      \   l:test_lines_list[1],
      \   "=>>",
      \   "Hello! I'm just a virtual assistant, so I don't have feelings, but I'm here and ready to help! How",
      \   "can I assist you today?",
      \   "<<=",
      \   "----------",
      \   ">>> "
      \ ]

    call s:testutil.AssertEqualLists(expand('<sflnum>') - 9, '', l:expected_list, l:actual_list)


    " Assert that both the "response payload" and "request payload" files used for testing were removed from the system.
    AssertIs(0, filereadable(l:request_tempfile))
    AssertIs(0, filereadable(l:response_tempfile))


    " Now perform the following cleanup actions to tidy up after testing:
    "
    "   1). Invoke function AbortRunningChatExec() to cleanup the test chat execution dictionary we set earlier.
    "   2). Forcibly close out the testing buffer (force is needed because the buffer contains unsaved content and we
    "       have no need to save this).
    "   3). Unset the 'g:llmchat_test_bypass_mode' variable to disable test behaviors from the code execution.
    "   4). Reset the 'g:llmchat_separator_bar_size' variable to its default value.
    "
    call LLMChat#send_chat#AbortRunningChatExec()
    bd!
    unlet g:llmchat_test_bypass_mode

    let l:defaults_dict = s:testutil.GetGlobalVariableDefaults()
    let g:llmchat_separator_bar_size = l:defaults_dict["g:llmchat_separator_bar_size"]

endfunction


" This test asserts that function HandleChatResponse() behaves as expected when processing the content of an LLM
" response returned from an Open-WebUI server.
function s:TestHandleChatResponseWithOpenWebUIInteraction()
    " Set the 'g:llmchat_test_bypass_mode' variable to a value of 1 so that any exceptions that might come out of the
    " HandleChatResponse() function will be properly surfaced.
    let g:llmchat_test_bypass_mode = 1


    " Set the 'g:llmchat_separator_bar_size' to a known size that way the test is insensitive to any changes that might
    " be made to the default value of this variable.
    let g:llmchat_separator_bar_size = 10


    " Request Vim to provide us with the name and path to a temporary file then write some content to the file.  Note
    " that we don't actually care what the file contains as nothing will use it; our main concern is simply that the
    " file gets created.  We will then use this file to simulate the "request payload" file during testing to verify
    " that it is removed as part of the cleanup performed by function HandleChatResponse().
    let l:request_tempfile = tempname()
    call writefile(["Some testing content"], l:request_tempfile)
    AssertTxt(filereadable(l:request_tempfile),
            \ "Unable to create a simulated request payload file on disk for testing.")


    " Create a new buffer that will be used by the testing then write a line of text to it.  Note that the
    " HandleChatResponse() function will only look at the current chat execution dictionary for its data so the content
    " we write to the buffer doesn't need to be in proper chat document format; we only do this so we can confirm that
    " content written to the buffer by the HandleChatResponse() function will appear in the correct place.
    "
    " NOTE: After running the 'new' command we assume the newly opened buffer to become the active buffer.
    new
    let l:test_lines_list = [ "Some test content", "written to the new buffer." ]
    call appendbufline('%', '$', l:test_lines_list)


    " Call a utility function to locate the "data" directory for this test then copy the content of the "response.json"
    " file found at that location to a temporary file whose path is provided by Vim.  We do this because the response
    " payload file we use will be removed by the execution of function HandleChatResponse() and we don't want to
    " delete the original test data file from the system.
    let l:response_tempfile = tempname()
    call filecopy(s:testutil.GetTestDataDir("TestHandleChatResponseWithOpenWebUIInteraction", 1) .. "response.json",
                \ l:response_tempfile)


    " Define a test "chat execution dictionary" that will simulate the information associated with a completed chat
    " execution job and then invoke the necessary function to set it for use.
    "
    " NOTE: For this test "thinking" will be disabled and the output associated with such feature will be verified by
    "       a separate test.
    let l:test_chat_exec_dict = {
                              \   "stdout": "200",
                              \   "parse dict":
                              \   {
                              \     "header":
                              \     {
                              \       "server type": "Open WebUI",
                              \       "show thinking": "false"
                              \     }
                              \   },
                              \   "buffer number": bufnr(),
                              \   "buffer textwidth": "100",
                              \   "buffer line count": line("$"),
                              \   "response payload filename": l:response_tempfile,
                              \   "request payload filename": l:request_tempfile
                              \ }

    call LLMChat#send_chat#SetCurrChatExecDict(l:test_chat_exec_dict)


    " Invoke the HandleChatResponse() function such that it appears a successful response was received from an LLM.
    "
    " NOTE: The 'job_id' argument is not currently used by anything in the function so we will simply default this to
    "       the empty string for now.
    "
    call LLMChat#send_chat#HandleChatResponse('', 0)


    " Retrieve all content from the test buffer and validate that it contains (1) the original test text written to the
    " buffer as well as (2) the content we expected to see the HandleChatResponse() function update the buffer with.
    "
    " NOTE: The lines appended to the buffer by function HandleChatResponse() should follow the line length restrictions
    "       imposed by the information we put into the test chat execution dictionary.
    "
    let l:actual_list = getline(0, '$')
    let l:expected_list =
      \ [
      \   '',
      \   l:test_lines_list[0],
      \   l:test_lines_list[1],
      \   "=>>",
      \   "Hello! I'm here to help. How can I assist you today?",
      \   "<<=",
      \   "----------",
      \   ">>> "
      \ ]

    call s:testutil.AssertEqualLists(expand('<sflnum>') - 9, '', l:expected_list, l:actual_list)


    " Assert that both the "response payload" and "request payload" files used for testing were removed from the system.
    AssertIs(0, filereadable(l:request_tempfile))
    AssertIs(0, filereadable(l:response_tempfile))


    " Now perform the following cleanup actions to tidy up after testing:
    "
    "   1). Invoke function AbortRunningChatExec() to cleanup the test chat execution dictionary we set earlier.
    "   2). Forcibly close out the testing buffer (force is needed because the buffer contains unsaved content and we
    "       have no need to save this).
    "   3). Unset the 'g:llmchat_test_bypass_mode' variable to disable test behaviors from the code execution.
    "   4). Reset the 'g:llmchat_separator_bar_size' variable to its default value.
    "
    call LLMChat#send_chat#AbortRunningChatExec()
    bd!
    unlet g:llmchat_test_bypass_mode

    let l:defaults_dict = s:testutil.GetGlobalVariableDefaults()
    let g:llmchat_separator_bar_size = l:defaults_dict["g:llmchat_separator_bar_size"]

endfunction


" This test asserts that function HandleChatResponse() behaves as expected when executed while debug mode has been
" enabled.
function s:TestHandleChatResponseWithDebugModeEnabled()
    " Set the 'g:llmchat_test_bypass_mode' variable to a value of 1 so that any exceptions that might come out of the
    " HandleChatResponse() function will be properly surfaced.
    let g:llmchat_test_bypass_mode = 1


    " Set the 'g:llmchat_separator_bar_size' to a known size that way the test is insensitive to any changes that might
    " be made to the default value of this variable.
    let g:llmchat_separator_bar_size = 10


    " Request a temporary filepath from VIM and then set this path up as the "debug target" to use.  When we execute
    " the HandleChatResponse() function later than this should be the location that receives debug logging writes.
    let l:debug_file = tempname()
    let g:llmchat_debug_mode_target = l:debug_file


    " Request Vim to provide us with the name and path to a temporary file then write some content to the file.  Note
    " that we don't actually care what the file contains as nothing will use it; our main concern is simply that the
    " file gets created.  We will then use this file to simulate the "request payload" file during testing to verify
    " that it is removed as part of the cleanup performed by function HandleChatResponse().
    let l:request_tempfile = tempname()
    call writefile(["Some testing content"], l:request_tempfile)
    AssertTxt(filereadable(l:request_tempfile),
            \ "Unable to create a simulated request payload file on disk for testing.")


    " Request Vim to provide us with the name and path to a temporary file that can serve as the "response header file"
    " for testing then write some arbitrary information to it.  Writing information is primarily done to ensure that
    " the file gets created on disk but could be used later on to verify debug information if desired.
    let l:response_header_tempfile = tempname()
    call writefile(["Response header data."], l:response_header_tempfile)
    AssertTxt(filereadable(l:response_header_tempfile),
            \ "Unable to create a simulated response header file on disk for testing.")


    " Create a new buffer that will be used by the testing then write a line of text to it.  Note that the
    " HandleChatResponse() function will only look at the current chat execution dictionary for its data so the content
    " we write to the buffer doesn't need to be in proper chat document format; we only do this so we can confirm that
    " content written to the buffer by the HandleChatResponse() function will appear in the correct place.
    "
    " NOTE: After running the 'new' command we assume the newly opened buffer to become the active buffer.
    new
    let l:test_lines_list = [ "Some test content", "written to the new buffer." ]
    call appendbufline('%', '$', l:test_lines_list)


    " Call a utility function to locate the "data" directory for this test then copy the content of the "response.json"
    " file found at that location to a temporary file whose path is provided by Vim.  We do this because the response
    " payload file we use will be removed by the execution of function HandleChatResponse() and we don't want to delete
    " the original test data file from the system.
    let l:response_tempfile = tempname()
    call filecopy(s:testutil.GetTestDataDir("TestHandleChatResponseWithDebugModeEnabled", 1) .. "response.json",
                \ l:response_tempfile)


    " Define a test "chat execution dictionary" that will simulate the information associated with a completed chat
    " execution job and then invoke the necessary function to set it for use.
    "
    " NOTE: For this test "thinking" will be disabled and the output associated with such feature will be verified by
    "       a separate test.
    let l:test_chat_exec_dict = {
                              \   "stdout": "200",
                              \   "parse dict":
                              \   {
                              \     "header":
                              \     {
                              \       "server type": "Ollama",
                              \       "show thinking": "false"
                              \     }
                              \   },
                              \   "buffer number": bufnr(),
                              \   "buffer textwidth": "100",
                              \   "buffer line count": line("$"),
                              \   "response payload filename": l:response_tempfile,
                              \   "response header filename": l:response_header_tempfile,
                              \   "request payload filename": l:request_tempfile
                              \ }

    call LLMChat#send_chat#SetCurrChatExecDict(l:test_chat_exec_dict)


    " Invoke the HandleChatResponse() function such that it appears a successful response was received from an LLM.
    "
    " NOTE: The 'job_id' argument is not currently used by anything in the function so we will simply default this to
    "       the empty string for now.
    "
    call LLMChat#send_chat#HandleChatResponse('', 0)


    " Retrieve all content from the test buffer and validate that it contains (1) the original test text written to the
    " buffer as well as (2) the content we expected to see the HandleChatResponse() function update the buffer with.
    "
    " NOTE: The lines appended to the buffer by function HandleChatResponse() should follow the line length restrictions
    "       imposed by the information we put into the test chat execution dictionary.
    "
    let l:actual_list = getline(0, '$')
    let l:expected_list =
      \ [
      \   '',
      \   l:test_lines_list[0],
      \   l:test_lines_list[1],
      \   "=>>",
      \   "Hello! I'm just a virtual assistant, so I don't have feelings, but I'm here and ready to help! How",
      \   "can I assist you today?",
      \   "<<=",
      \   "----------",
      \   ">>> "
      \ ]

    call s:testutil.AssertEqualLists(expand('<sflnum>') - 9, '', l:expected_list, l:actual_list)


    " Assert that both the "response payload" and "request payload" files used for testing were removed from the system.
    AssertIs(0, filereadable(l:request_tempfile))
    AssertIs(0, filereadable(l:response_tempfile))


    " Assert that the debug file is readable and is NOT empty (currently we're not concerned with validating exactly
    " what all was written to the file; only that the file DID receive data showing that debug logging was in effect).
    AssertTxt(filereadable(l:debug_file),
            \ "Expected to find a generated debug log during testing but no such log was readable to the test.")
    if(filereadable( l:debug_file))
        " NOTE: We protect this verification since we will be letting the test proceed even if the debug log wasn't
        "       found earlier.  This is done primarily so that specialized cleanup at the end of the test can still
        "       run.
        let l:debug_file_lines = readfile(l:debug_file)
        AssertTxt(len(l:debug_file_lines) > 0,
                \ "Expected to find debug statements within the debug log created during testing but such log " ..
                \ "appears to be empty.")

    endif

    " Now perform the following cleanup actions to tidy up after testing:
    "
    "   1). Invoke function AbortRunningChatExec() to cleanup the test chat execution dictionary we set earlier.
    "   2). Forcibly close out the testing buffer (force is needed because the buffer contains unsaved content and we
    "       have no need to save this).
    "   3). Unset the 'g:llmchat_test_bypass_mode' variable to disable test behaviors from the code execution.
    "   4). Reset the 'g:llmchat_separator_bar_size' variable to its default value.
    "   5). Remove the debug log file from the system.
    "   6). Unset the 'g:llmchat_debug_mode_target' to disable debug mode.
    "
    call LLMChat#send_chat#AbortRunningChatExec()
    bd!
    unlet g:llmchat_test_bypass_mode

    let l:defaults_dict = s:testutil.GetGlobalVariableDefaults()
    let g:llmchat_separator_bar_size = l:defaults_dict["g:llmchat_separator_bar_size"]

    call delete(l:debug_file)

    unlet g:llmchat_debug_mode_target

endfunction


" This test asserts that function HandleChatResponse() appropriately closes out user messages that weren't explicitly
" terminated when a chat interaction was initiated.
function s:TestHandleChatResponseWithUnclosedUserMessage()
    " Set the 'g:llmchat_test_bypass_mode' variable to a value of 1 so that any exceptions that might come out of the
    " HandleChatResponse() function will be properly surfaced.
    let g:llmchat_test_bypass_mode = 1


    " Set the 'g:llmchat_separator_bar_size' to a known size that way the test is insensitive to any changes that might
    " be made to the default value of this variable.
    let g:llmchat_separator_bar_size = 10


    " Request Vim to provide us with the name and path to a temporary file then write some content to the file.  Note
    " that we don't actually care what the file contains as nothing will use it; our main concern is simply that the
    " file gets created.  We will then use this file to simulate the "request payload" file during testing to verify
    " that it is removed as part of the cleanup performed by function HandleChatResponse().
    let l:request_tempfile = tempname()
    call writefile(["Some testing content"], l:request_tempfile)
    AssertTxt(filereadable(l:request_tempfile),
            \ "Unable to create a simulated request payload file on disk for testing.")


    " Create a new buffer that will be used by the testing then write a line of text to it.  Note that the
    " HandleChatResponse() function will only look at the current chat execution dictionary for its data so the content
    " we write to the buffer doesn't need to be in proper chat document format; we only do this so we can confirm that
    " content written to the buffer by the HandleChatResponse() function will appear in the correct place.
    "
    " NOTE: After running the 'new' command we assume the newly opened buffer to become the active buffer.
    new
    let l:test_lines_list = [ "Some test content", "written to the new buffer." ]
    call appendbufline('%', '$', l:test_lines_list)


    " Call a utility function to locate the "data" directory for this test then copy the content of the "response.json"
    " file found at that location to a temporary file whose path is provided by Vim.  We do this because the response
    " payload file we use will be removed by the execution of function HandleChatResponse() and we don't want to
    " delete the original test data file from the system.
    let l:response_tempfile = tempname()
    call filecopy(s:testutil.GetTestDataDir("TestHandleChatResponseWithUnclosedUserMessage", 1) .. "response.json",
                \ l:response_tempfile)


    " Define a test "chat execution dictionary" that will simulate the information associated with a completed chat
    " execution job and then invoke the necessary function to set it for use.  Note that, in the case of this test,
    " we will also add the appropriate content to the embedded "parse dictionary" to indicate that the last user message
    " was not fully closed off in the chat document.
    "
    " NOTE: For this test "thinking" will be disabled and the output associated with such feature will be verified by
    "       a separate test.
    let l:test_chat_exec_dict = {
                              \   "stdout": "200",
                              \   "parse dict":
                              \   {
                              \     "header":
                              \     {
                              \       "server type": "Ollama",
                              \       "show thinking": "false"
                              \     },
                              \     "flags":
                              \     {
                              \       "no-user-message-close": "1"
                              \     }
                              \   },
                              \   "buffer number": bufnr(),
                              \   "buffer textwidth": "100",
                              \   "buffer line count": line("$"),
                              \   "response payload filename": l:response_tempfile,
                              \   "request payload filename": l:request_tempfile
                              \ }

    call LLMChat#send_chat#SetCurrChatExecDict(l:test_chat_exec_dict)


    " Invoke the HandleChatResponse() function such that it appears a successful response was received from an LLM.
    "
    " NOTE: The 'job_id' argument is not currently used by anything in the function so we will simply default this to
    "       the empty string for now.
    "
    call LLMChat#send_chat#HandleChatResponse('', 0)


    " Retrieve all content from the test buffer and validate that it contains (1) the original test text written to the
    " buffer as well as (2) the content we expected to see the HandleChatResponse() function update the buffer with.
    "
    " NOTE: The lines appended to the buffer by function HandleChatResponse() should follow the line length restrictions
    "       imposed by the information we put into the test chat execution dictionary.
    "
    let l:actual_list = getline(0, '$')
    let l:expected_list =
      \ [
      \   '',
      \   l:test_lines_list[0],
      \   l:test_lines_list[1],
      \   "<<<",
      \   "",
      \   "=>>",
      \   "Hello! I'm just a virtual assistant, so I don't have feelings, but I'm here and ready to help! How",
      \   "can I assist you today?",
      \   "<<=",
      \   "----------",
      \   ">>> "
      \ ]

    call s:testutil.AssertEqualLists(expand('<sflnum>') - 9, '', l:expected_list, l:actual_list)


    " Assert that both the "response payload" and "request payload" files used for testing were removed from the system.
    AssertIs(0, filereadable(l:request_tempfile))
    AssertIs(0, filereadable(l:response_tempfile))


    " Now perform the following cleanup actions to tidy up after testing:
    "
    "   1). Invoke function AbortRunningChatExec() to cleanup the test chat execution dictionary we set earlier.
    "   2). Forcibly close out the testing buffer (force is needed because the buffer contains unsaved content and we
    "       have no need to save this).
    "   3). Unset the 'g:llmchat_test_bypass_mode' variable to disable test behaviors from the code execution.
    "   4). Reset the 'g:llmchat_separator_bar_size' variable to its default value.
    "
    call LLMChat#send_chat#AbortRunningChatExec()
    bd!
    unlet g:llmchat_test_bypass_mode

    let l:defaults_dict = s:testutil.GetGlobalVariableDefaults()
    let g:llmchat_separator_bar_size = l:defaults_dict["g:llmchat_separator_bar_size"]

endfunction


" This test asserts that function HandleChatResponse() will shift the display of assistant messages to begin on the same
" line as the opening '<<=' sequence when global variable 'g:llmchat_assistant_message_follow_style' has been set to 1.
function s:TestHandleChatResponseWithEnabledAssistantMessageFollowStyle()
    " Set the 'g:llmchat_test_bypass_mode' variable to a value of 1 so that any exceptions that might come out of the
    " HandleChatResponse() function will be properly surfaced.
    let g:llmchat_test_bypass_mode = 1


    " Set the 'g:llmchat_assistant_message_follow_style' to a value of 1 so that assistant messages are appended
    " immediately after the message start token.
    let g:llmchat_assistant_message_follow_style = 1


    " Set the 'g:llmchat_separator_bar_size' to a known size that way the test is insensitive to any changes that might
    " be made to the default value of this variable.
    let g:llmchat_separator_bar_size = 10


    " Request Vim to provide us with the name and path to a temporary file then write some content to the file.  Note
    " that we don't actually care what the file contains as nothing will use it; our main concern is simply that the
    " file gets created.  We will then use this file to simulate the "request payload" file during testing to verify
    " that it is removed as part of the cleanup performed by function HandleChatResponse().
    let l:request_tempfile = tempname()
    call writefile(["Some testing content"], l:request_tempfile)
    AssertTxt(filereadable(l:request_tempfile),
            \ "Unable to create a simulated request payload file on disk for testing.")


    " Create a new buffer that will be used by the testing then write a line of text to it.  Note that the
    " HandleChatResponse() function will only look at the current chat execution dictionary for its data so the content
    " we write to the buffer doesn't need to be in proper chat document format; we only do this so we can confirm that
    " content written to the buffer by the HandleChatResponse() function will appear in the correct place.
    "
    " NOTE: After running the 'new' command we assume the newly opened buffer to become the active buffer.
    new
    let l:test_lines_list = [ "Some test content", "written to the new buffer." ]
    call appendbufline('%', '$', l:test_lines_list)


    " Call a utility function to locate the "data" directory for this test then copy the content of the "response.json"
    " file found at that location to a temporary file whose path is provided by Vim.  We do this because the response
    " payload file we use will be removed by the execution of function HandleChatResponse() and we don't want to
    " delete the original test data file from the system.
    let l:response_tempfile = tempname()
    call filecopy(s:testutil.GetTestDataDir("TestHandleChatResponseWithEnabledAssistantMessageFollowStyle", 1) ..
                \ "response.json",
                \ l:response_tempfile)


    " Define a test "chat execution dictionary" that will simulate the information associated with a completed chat
    " execution job and then invoke the necessary function to set it for use.
    "
    " NOTE: For this test "thinking" will be disabled and the output associated with such feature will be verified by
    "       a separate test.
    let l:test_chat_exec_dict = {
                              \   "stdout": "200",
                              \   "parse dict":
                              \   {
                              \     "header":
                              \     {
                              \       "server type": "Ollama",
                              \       "show thinking": "false"
                              \     }
                              \   },
                              \   "buffer number": bufnr(),
                              \   "buffer textwidth": "100",
                              \   "buffer line count": line("$"),
                              \   "response payload filename": l:response_tempfile,
                              \   "request payload filename": l:request_tempfile
                              \ }

    call LLMChat#send_chat#SetCurrChatExecDict(l:test_chat_exec_dict)


    " Invoke the HandleChatResponse() function such that it appears a successful response was received from an LLM.
    "
    " NOTE: The 'job_id' argument is not currently used by anything in the function so we will simply default this to
    "       the empty string for now.
    "
    call LLMChat#send_chat#HandleChatResponse('', 0)


    " Retrieve all content from the test buffer and validate that it contains (1) the original test text written to the
    " buffer as well as (2) the content we expected to see the HandleChatResponse() function update the buffer with.
    "
    " NOTE: The lines appended to the buffer by function HandleChatResponse() should follow the line length restrictions
    "       imposed by the information we put into the test chat execution dictionary.
    "
    let l:actual_list = getline(0, '$')
    let l:expected_list =
      \ [
      \   '',
      \   l:test_lines_list[0],
      \   l:test_lines_list[1],
      \   "=>> Hello! I'm just a virtual assistant, so I don't have feelings, but I'm here and ready to help!",
      \   "How can I assist you today?",
      \   "<<=",
      \   "----------",
      \   ">>> "
      \ ]

    call s:testutil.AssertEqualLists(expand('<sflnum>') - 9, '', l:expected_list, l:actual_list)


    " Assert that both the "response payload" and "request payload" files used for testing were removed from the system.
    AssertIs(0, filereadable(l:request_tempfile))
    AssertIs(0, filereadable(l:response_tempfile))


    " Now perform the following cleanup actions to tidy up after testing:
    "
    "   1). Invoke function AbortRunningChatExec() to cleanup the test chat execution dictionary we set earlier.
    "   2). Forcibly close out the testing buffer (force is needed because the buffer contains unsaved content and we
    "       have no need to save this).
    "   3). Unset the 'g:llmchat_test_bypass_mode' variable to disable test behaviors from the code execution.
    "   4). Reset the 'g:llmchat_separator_bar_size' variable to its default value.
    "   5). Reset the 'g:llmchat_assistant_message_follow_style' variable to its default value.
    "
    call LLMChat#send_chat#AbortRunningChatExec()
    bd!
    unlet g:llmchat_test_bypass_mode

    let l:defaults_dict = s:testutil.GetGlobalVariableDefaults()
    let g:llmchat_separator_bar_size = l:defaults_dict["g:llmchat_separator_bar_size"]
    let g:llmchat_assistant_message_follow_style = l:defaults_dict["g:llmchat_assistant_message_follow_style"]

endfunction


" This test asserts that function HandleChatResponse() includes thinking outputs returned from the LLM server when the
" option to show reasoning has been enabled for the chat.
function s:TestHandleChatResponseWithEnabledReasoning()
    " Set the 'g:llmchat_test_bypass_mode' variable to a value of 1 so that any exceptions that might come out of the
    " HandleChatResponse() function will be properly surfaced.
    let g:llmchat_test_bypass_mode = 1


    " Set the 'g:llmchat_separator_bar_size' to a known size that way the test is insensitive to any changes that might
    " be made to the default value of this variable.
    let g:llmchat_separator_bar_size = 10


    " Request Vim to provide us with the name and path to a temporary file then write some content to the file.  Note
    " that we don't actually care what the file contains as nothing will use it; our main concern is simply that the
    " file gets created.  We will then use this file to simulate the "request payload" file during testing to verify
    " that it is removed as part of the cleanup performed by function HandleChatResponse().
    let l:request_tempfile = tempname()
    call writefile(["Some testing content"], l:request_tempfile)
    AssertTxt(filereadable(l:request_tempfile),
            \ "Unable to create a simulated request payload file on disk for testing.")


    " Create a new buffer that will be used by the testing then write a line of text to it.  Note that the
    " HandleChatResponse() function will only look at the current chat execution dictionary for its data so the content
    " we write to the buffer doesn't need to be in proper chat document format; we only do this so we can confirm that
    " content written to the buffer by the HandleChatResponse() function will appear in the correct place.
    "
    " NOTE: After running the 'new' command we assume the newly opened buffer to become the active buffer.
    new
    let l:test_lines_list = [ "Some test content", "written to the new buffer." ]
    call appendbufline('%', '$', l:test_lines_list)


    " Call a utility function to locate the "data" directory for this test then copy the content of the "response.json"
    " file found at that location to a temporary file whose path is provided by Vim.  We do this because the response
    " payload file we use will be removed by the execution of function HandleChatResponse() and we don't want to
    " delete the original test data file from the system.
    let l:response_tempfile = tempname()
    call filecopy(s:testutil.GetTestDataDir("TestHandleChatResponseWithEnabledReasoning", 1) .. "response.json",
                \ l:response_tempfile)


    " Define a test "chat execution dictionary" that will simulate the information associated with a completed chat
    " execution job and then invoke the necessary function to set it for use.  Note that in this instance we will
    " indicate within the embedded "parse dictionary" that thinking output should be included in any response.
    let l:test_chat_exec_dict = {
                              \   "stdout": "200",
                              \   "parse dict":
                              \   {
                              \     "header":
                              \     {
                              \       "server type": "Ollama",
                              \       "show thinking": "true"
                              \     }
                              \   },
                              \   "buffer number": bufnr(),
                              \   "buffer textwidth": "100",
                              \   "buffer line count": line("$"),
                              \   "response payload filename": l:response_tempfile,
                              \   "request payload filename": l:request_tempfile
                              \ }

    call LLMChat#send_chat#SetCurrChatExecDict(l:test_chat_exec_dict)


    " Invoke the HandleChatResponse() function such that it appears a successful response was received from an LLM.
    "
    " NOTE: The 'job_id' argument is not currently used by anything in the function so we will simply default this to
    "       the empty string for now.
    "
    call LLMChat#send_chat#HandleChatResponse('', 0)


    " Retrieve all content from the test buffer and validate that it contains (1) the original test text written to the
    " buffer as well as (2) the content we expected to see the HandleChatResponse() function update the buffer with.
    "
    " NOTE: The lines appended to the buffer by function HandleChatResponse() should follow the line length restrictions
    "       imposed by the information we put into the test chat execution dictionary.
    "
    let l:actual_list = getline(0, '$')
    let l:expected_list =
      \ [
      \   '',
      \   l:test_lines_list[0],
      \   l:test_lines_list[1],
      \   "#=>> REASONING",
      \   "# Okay, the user greeted me with \"Hello, how are you today?\" I need to respond in a friendly manner.",
      \   "# Since they mentioned feeling enabled to provide complete information without concerns about",
      \   "# offensiveness, I should keep the response straightforward and positive.",
      \   "# I should start by acknowledging their greeting. Maybe say \"Hello!\" to be polite. Then, since they",
      \   "# asked how I am, I can mention that I'm just a chatbot and don't have feelings, but I'm here to",
      \   "# help. That's honest and sets the right expectations.",
      \   "# That works. Also, using only ASCII, no special characters. Looks good. No markdown, just plain",
      \   "# text. Alright, that should cover it.",
      \   "#<<= REASONING",
      \   "=>>",
      \   "Hello! I'm just a virtual assistant, so I don't have feelings, but I'm here and ready to help! How",
      \   "can I assist you today?",
      \   "<<=",
      \   "----------",
      \   ">>> "
      \ ]

    call s:testutil.AssertEqualLists(expand('<sflnum>') - 9, '', l:expected_list, l:actual_list)


    " Assert that both the "response payload" and "request payload" files used for testing were removed from the system.
    AssertIs(0, filereadable(l:request_tempfile))
    AssertIs(0, filereadable(l:response_tempfile))


    " Now perform the following cleanup actions to tidy up after testing:
    "
    "   1). Invoke function AbortRunningChatExec() to cleanup the test chat execution dictionary we set earlier.
    "   2). Forcibly close out the testing buffer (force is needed because the buffer contains unsaved content and we
    "       have no need to save this).
    "   3). Unset the 'g:llmchat_test_bypass_mode' variable to disable test behaviors from the code execution.
    "   4). Reset the 'g:llmchat_separator_bar_size' variable to its default value.
    "
    call LLMChat#send_chat#AbortRunningChatExec()
    bd!
    unlet g:llmchat_test_bypass_mode

    let l:defaults_dict = s:testutil.GetGlobalVariableDefaults()
    let g:llmchat_separator_bar_size = l:defaults_dict["g:llmchat_separator_bar_size"]

endfunction


" This test asserts that function HandleChatResponse() throws a expected exception when it detects that the cURL call,
" whose response data it is supposed to process, exited abonormally.
function s:TestHandleChatResponseWithAbnormalCurlExit()
    " Set the 'g:llmchat_test_bypass_mode' variable to a value of 1 so that any exceptions that might come out of the
    " HandleChatResponse() function will be properly surfaced.
    let g:llmchat_test_bypass_mode = 1


    " Define a test "chat execution dictionary" that will be used by the HandleChatResponse() function to obtain
    " information about the chat request result.  Note that because we don't expect the main part of the processing
    " within function HandleChatResponse() to be engaged we will dummy out many of the values given in the dictionary.
    let l:test_chat_exec_dict = {
                              \   "stdout": "",
                              \   "parse dict":
                              \   {
                              \     "header":
                              \     {
                              \       "server type": "Ollama",
                              \       "show thinking": "false"
                              \     }
                              \   },
                              \   "buffer number": "1",
                              \   "buffer textwidth": "100",
                              \   "buffer line count": "1",
                              \   "response payload filename": "dummy_path",
                              \   "request payload filename": "dummy_path"
                              \ }
    call LLMChat#send_chat#SetCurrChatExecDict(l:test_chat_exec_dict)

    try
        " Now invoke the HandleChatResponse() function process the LLM response; we expect this invocation to see that a
        " non-zero exit status was provided for the chat execution job and then throw an exception.
        call LLMChat#send_chat#HandleChatResponse('', 1)


        " If the logic makes it to this point than fail the test; we expected to see an exception thrown before this
        " point which would make this code unreachable if things were working as intended.
        call s:testutil.Fail(expand('<sflnum>') - 9,
                           \ "Expected to see an exception thrown from function HandleChatResponse() when the " ..
                           \ "job exit status passed to it indicated that the cURL command used to submit the " ..
                           \ "chat request exited abnormally; however, no exception occurred.")

    catch /\c[error].*non-zero exit status.*/
        " If the logic comes here than we appear to have caught an exception containing the message we expected to see;
        " allow the test to complete normally as this is what should happen if the logic is working correctly.
    endtry


    " Perform the following cleanup tasks now that test has completed:
    "
    "   1). Unset the 'g:llmchat_test_bypass_mode' variable to disable test behaviors from the code execution.
    "
    unlet g:llmchat_test_bypass_mode

endfunction


" This test asserts that function HandleChatResponse() throws an expected exception when it detects that the cURL call,
" whose response data it is supposed to process, returned with an unexpected HTTP response status.
function s:TestHandleChatResponseWithAbnormalResponseStatus()
    " Set the 'g:llmchat_test_bypass_mode' variable to a value of 1 so that any exceptions that might come out of the
    " HandleChatResponse() function will be properly surfaced.
    let g:llmchat_test_bypass_mode = 1


    " Request a temporary filepath from Vim and then write some content to the path so we can use it as a "dummy"
    " response data file.  Note that the content we output is arbitrary but we need to make sure the file exists and is
    " readable as construction of the exception message we hope to prompt later will require it.
    let l:response_data_file = tempname()
    call writefile(["The response result"], l:response_data_file)
    AssertTxt(filereadable(l:response_data_file),
            \ "Unable to create a simulated response data file for testing.")


    " Define a test "chat execution dictionary" that will emulate the result of a failed LLM response then invoke the
    " appropriate utility function to set this dictionary for use.  Note that because we don't expect the main part of
    " the processing within function HandleChatResponse() to be engaged we will dummy out many of the values given in
    " the dictionary.
    let l:test_chat_exec_dict = {
                              \   "stdout": "500",
                              \   "parse dict":
                              \   {
                              \     "header":
                              \     {
                              \       "server type": "Ollama",
                              \       "show thinking": "false"
                              \     }
                              \   },
                              \   "buffer number": "1",
                              \   "buffer textwidth": "100",
                              \   "buffer line count": "1",
                              \   "response payload filename": l:response_data_file,
                              \   "request payload filename": "dummy_path"
                              \ }
    call LLMChat#send_chat#SetCurrChatExecDict(l:test_chat_exec_dict)

    try
        " Now invoke the HandleChatResponse() function to process the chat request result; we expect this invocation to
        " see that the simulated LLM response was unsuccessful and then throw an exception.
        call LLMChat#send_chat#HandleChatResponse('', 0)


        " If the logic makes it to this point than fail the test; we expected to see an exception thrown before this
        " point which would make this code unreachable if things were working as intended.
        call s:testutil.Fail(expand('<sflnum>') - 9,
                           \ "Expected to see an exception thrown from function HandleChatResponse() when the " ..
                           \ "active chat execution dictionary indicated that the LLM response was unsuccessful; " ..
                           \ "however, no exception occurred.")

    catch /\c[error].*http status code.*/
        " If the logic comes here than we appear to have caught an exception containing the message we expected to see;
        " allow the test to complete normally as this is what should happen if the logic is working correctly.
    endtry


    " Perform the following cleanup tasks now that test has completed:
    "
    "   1). Unset the 'g:llmchat_test_bypass_mode' variable to disable test behaviors from the code execution.
    "   2). Remove the test response data file from the local disk.
    "
    unlet g:llmchat_test_bypass_mode
    call delete(l:response_data_file)

endfunction


" ***********************************************************
" ****  CreateOllamaChatRequestPayload() Function Tests  ****
" ***********************************************************

" This test asserts the proper operation of function CreateOllamaChatRequestPayload() when a minimal parse dictionary
" is provided (i.e., only required options and a single user message).
function s:TestCreateOllamaChatRequestPayloadWithMinimalParseDict()
    " Define a minimal parse dictionary that will be passed to the CreateOllamaChatRequestPayload() function as input.
    let l:test_parse_dict = {
                          \   "header":
                          \   {
                          \     "server type": "Ollama",
                          \     "server url": "http://localhost:11434",
                          \     "model id": "qwen:latest"
                          \   },
                          \   "messages":
                          \   [
                          \     {
                          \       "user": "How are you today?"
                          \     }
                          \   ]
                          \ }

    " Invoke the CreateOllamaChatRequestPayload() function and provide to it (1) the minimal parse dictionary created
    " earlier and (2) the path to a temporary file that it can output its result to.
    let l:temp_file = tempname()

    call LLMChat#send_chat#CreateOllamaChatRequestPayload(l:test_parse_dict, l:temp_file)


    " Read all lines from the temporary file that function CreateOllamaChatRequestPayload() wrote its output to, join
    " the lines back together using newline sequences, then compare the result to an expected text block.
    let l:expected_output = "{" ..
                        \ "\n  \"model\": \"qwen:latest\"," ..
                        \ "\n  \"think\": false," ..
                        \ "\n  \"stream\": false," ..
                        \ "\n  \"messages\":" ..
                        \ "\n    [" ..
                        \ "\n      {" ..
                        \ "\n        \"role\": \"user\"," ..
                        \ "\n        \"content\": \"How are you today?\"" ..
                        \ "\n      }" ..
                        \ "\n    ]" ..
                        \ "\n}"

    let l:actual_output = join(readfile(l:temp_file), "\n")

    call s:testutil.AssertEqualTextBlocks(expand('<sflnum>') - 9, '', l:expected_output, l:actual_output)


    " Remove the temporary file now that testing has completed.
    call delete(l:temp_file)

endfunction


" This test asserts the proper operation of function CreateOllamaChatRequestPayload() when a maximal parse dictionary
" is provided (i.e., values are provided for every available header setting, the message array contains multiple
" interactions, etc).
function s:TestCreateOllamaChatRequestPayloadWithMaximalParseDict()
    " Define a maximal parse dictionary that will be passed to the CreateOllamaChatRequestPayload() function as input.
    let l:test_parse_dict = {
                          \   "header":
                          \   {
                          \     "server type": "Ollama",
                          \     "server url": "http://mylocalllm.net/ollama",
                          \     "model id": "super awesome model",
                          \     "use auth": "true",
                          \     "auth key": "12345",
                          \     "system prompt": "You are a \"super helpful\" and respectful assistant.",
                          \     "show thinking": "high",
                          \     "options":
                          \     {
                          \       "abc": "\"123\"",
                          \       "def": "\"789\"",
                          \       "use foo": "true"
                          \     }
                          \   },
                          \   "messages":
                          \   [
                          \     {
                          \       "user": "How are you today?",
                          \       "assistant": "I am fine; how can I help you today?"
                          \     },
                          \     {
                          \       "user": "Can you tell me what day the summer solstice will be on this year?",
                          \       "assistant": "Sure; the \"summer solstice\" is on June 21.  Is there anything " ..
                          \                    "else I can help with?"
                          \     },
                          \     {
                          \       "user": "Yes, can you tell me what a \"Chinese Cabbage\" is?"
                          \     }
                          \   ],
                          \   "flags":
                          \   {
                          \     "no-user-message-close": "true"
                          \   }
                          \ }

    " Invoke the CreateOllamaChatRequestPayload() function and provide to it (1) the maximal parse dictionary created
    " earlier and (2) the path to a temporary file that it can output its result to.
    let l:temp_file = tempname()

    call LLMChat#send_chat#CreateOllamaChatRequestPayload(l:test_parse_dict, l:temp_file)


    " Read all lines from the temporary file that function CreateOllamaChatRequestPayload() wrote its output to, join
    " the lines back together using newline sequences, then compare the result to an expected text block.
    let l:expected_output = "{" ..
                        \ "\n  \"model\": \"super awesome model\"," ..
                        \ "\n  \"think\": \"high\"," ..
                        \ "\n  \"stream\": false," ..
                        \ "\n  \"messages\":" ..
                        \ "\n    [" ..
                        \ "\n      {" ..
                        \ "\n        \"role\": \"system\"," ..
                        \ "\n        \"content\": \"You are a \\\"super helpful\\\" and respectful assistant.\"" ..
                        \ "\n      }," ..
                        \ "\n      {" ..
                        \ "\n        \"role\": \"user\"," ..
                        \ "\n        \"content\": \"How are you today?\"" ..
                        \ "\n      }," ..
                        \ "\n      {" ..
                        \ "\n        \"role\": \"assistant\"," ..
                        \ "\n        \"content\": \"I am fine; how can I help you today?\"" ..
                        \ "\n      }," ..
                        \ "\n      {" ..
                        \ "\n        \"role\": \"user\"," ..
                        \ "\n        \"content\": \"Can you tell me what day the summer solstice will be on this " ..
                        \                          "year?\"" ..
                        \ "\n      }," ..
                        \ "\n      {" ..
                        \ "\n        \"role\": \"assistant\"," ..
                        \ "\n        \"content\": \"Sure; the \\\"summer solstice\\\" is on June 21.  Is there " ..
                        \                          "anything else I can help with?\"" ..
                        \ "\n      }," ..
                        \ "\n      {" ..
                        \ "\n        \"role\": \"user\"," ..
                        \ "\n        \"content\": \"Yes, can you tell me what a \\\"Chinese Cabbage\\\" is?\"" ..
                        \ "\n      }" ..
                        \ "\n    ]," ..
                        \ "\n  \"options\":" ..
                        \ "\n    {" ..
                        \ "\n      \"abc\": \"123\"," ..
                        \ "\n      \"def\": \"789\"," ..
                        \ "\n      \"use foo\": true" ..
                        \ "\n    }"..
                        \ "\n}"

    let l:actual_output = join(readfile(l:temp_file), "\n")

    call s:testutil.AssertEqualTextBlocks(expand('<sflnum>') - 9, '', l:expected_output, l:actual_output)


    " Remove the temporary file now that testing has completed.
    call delete(l:temp_file)

endfunction


" This test verifies that function CreateOllamaChatRequestPayload() behaves as expected when the
" 'g:llmchat_use_streaming_mode' plugin variable has been set to 1 ('true') for enabling response streaming.
function s:TestCreateOllamaChatRequestPayloadWithEnabledStreaming()
    " Set the 'g:llmchat_use_streaming_mode' variable to 1.
    let g:llmchat_use_streaming_mode = 1

    " Create a minimal parse dictionary for testing as we are not trying to verify behavior specific to the content of
    " such dictionary
    let l:test_parse_dict = {
                          \   "header":
                          \   {
                          \     "server type": "Ollama",
                          \     "server url": "http://localhost:11434",
                          \     "model id": "qwen:latest"
                          \   },
                          \   "messages":
                          \   [
                          \     {
                          \       "user": "How are you today?"
                          \     }
                          \   ]
                          \ }

    " Invoke the CreateOllamaChatRequestPayload() function and provide to it (1) the test parse dictionary created
    " earlier and (2) the path to a temporary file that it can output its result to.
    let l:temp_file = tempname()

    call LLMChat#send_chat#CreateOllamaChatRequestPayload(l:test_parse_dict, l:temp_file)


    " Read all lines from the temporary file that function CreateOllamaChatRequestPayload() wrote its output to, join
    " the lines back together using newline sequences, then compare the result to an expected text block.
    let l:expected_output = "{" ..
                        \ "\n  \"model\": \"qwen:latest\"," ..
                        \ "\n  \"think\": false," ..
                        \ "\n  \"stream\": true," ..
                        \ "\n  \"messages\":" ..
                        \ "\n    [" ..
                        \ "\n      {" ..
                        \ "\n        \"role\": \"user\"," ..
                        \ "\n        \"content\": \"How are you today?\"" ..
                        \ "\n      }" ..
                        \ "\n    ]" ..
                        \ "\n}"

    let l:actual_output = join(readfile(l:temp_file), "\n")

    call s:testutil.AssertEqualTextBlocks(expand('<sflnum>') - 9, '', l:expected_output, l:actual_output)


    " Now that the test has completed reset the 'g:llmchat_use_streaming_mode' variable value back to 0.
    let g:llmchat_use_streaming_mode = 0


    " Remove the temporary file now that testing has completed.
    call delete(l:temp_file)

endfunction


" **************************************************************
" ****  CreateOpenWebUIChatRequestPayload() Function Tests  ****
" **************************************************************

" This test asserts the proper operation of function CreateOpenWebUIChatRequestPayload() when a minimal parse dictionary
" is provided (i.e., only required options and a single user message).
function s:TestCreateOpenWebUIChatRequestPayloadWithMinimalParseDict()
    " Define a minimal parse dictionary that will be passed to the CreateOpenWebUIChatRequestPayload() function as
    " input.
    let l:test_parse_dict = {
                          \   "header":
                          \   {
                          \     "server type": "Open WebUI",
                          \     "server url": "http://localhost:11434",
                          \     "model id": "qwen:latest"
                          \   },
                          \   "messages":
                          \   [
                          \     {
                          \       "user": "How are you today?"
                          \     }
                          \   ]
                          \ }

    " Invoke the CreateOpenWebUIChatRequestPayload() function and provide to it (1) the minimal parse dictionary created
    " earlier and (2) the path to a temporary file that it can output its result to.
    let l:temp_file = tempname()

    call LLMChat#send_chat#CreateOpenWebUIChatRequestPayload(l:test_parse_dict, l:temp_file)


    " Read all lines from the temporary file that function CreateOpenWebUIChatRequestPayload() wrote its output to, join
    " the lines back together using newline sequences, then compare the result to an expected text block.
    let l:expected_output = "{" ..
                        \ "\n  \"model\": \"qwen:latest\"," ..
                        \ "\n  \"stream\": false," ..
                        \ "\n  \"messages\":" ..
                        \ "\n    [" ..
                        \ "\n      {" ..
                        \ "\n        \"role\": \"user\"," ..
                        \ "\n        \"content\": \"How are you today?\"" ..
                        \ "\n      }" ..
                        \ "\n    ]" ..
                        \ "\n}"

    let l:actual_output = join(readfile(l:temp_file), "\n")

    call s:testutil.AssertEqualTextBlocks(expand('<sflnum>') - 9, '', l:expected_output, l:actual_output)


    " Remove the temporary file now that testing has completed.
    call delete(l:temp_file)

endfunction


" This test asserts the proper operation of function CreateOpenWebUIChatRequestPayload() when a maximal parse
" dictionary is provided to it (i.e., values are given for every available header setting, the message array contains
" multiple interactions, etc).
function s:TestCreateOpenWebUIRequestPayloadWithMaximalParseDict()
    " Define a maximal parse dictionary that will be passed to the CreateOpenWebUIChatRequestPayload() function as
    " input.
    let l:test_parse_dict = {
                          \   "header":
                          \   {
                          \     "server type": "Open WebUI",
                          \     "server url": "http://mylocalllm.net/",
                          \     "model id": "super awesome model",
                          \     "use auth": "true",
                          \     "auth key": "12345",
                          \     "system prompt": "You are a \"super helpful\" and respectful assistant.",
                          \     "show thinking": "high",
                          \     "options":
                          \     {
                          \       "abc": "\"123\"",
                          \       "def": "\"789\"",
                          \       "use foo": "true"
                          \     }
                          \   },
                          \   "messages":
                          \   [
                          \     {
                          \       "user": "How are you today?",
                          \       "assistant": "I am fine; how can I help you today?"
                          \     },
                          \     {
                          \       "user": "Can you tell me what day the summer solstice will be on this year?",
                          \       "assistant": "Sure; the \"summer solstice\" is on June 21.  Is there anything " ..
                          \                    "else I can help with?"
                          \     },
                          \     {
                          \       "user": "Yes, can you summarize the \"attached file?\"",
                          \       "user_resources":
                          \       [
                          \         "f:example_script",
                          \         "c:dependency_collection",
                          \         "F:glossary",
                          \         "C:dictionary"
                          \       ]
                          \     }
                          \   ],
                          \   "flags":
                          \   {
                          \     "no-user-message-close": "true"
                          \   }
                          \ }

    " Invoke the CreateOpenWebUIChatRequestPayload() function and provide to it (1) the maxima parse dictionary created
    " earlier and (2) the path to a temporary file that it can output its result to.
    let l:temp_file = tempname()

    call LLMChat#send_chat#CreateOpenWebUIChatRequestPayload(l:test_parse_dict, l:temp_file)


    " Read all lines from the temporary file that function CreateOllamaChatRequestPayload() wrote its output to, join
    " the lines back together using newline sequences, then compare the result to an expected text block.
    let l:expected_output = "{" ..
                        \ "\n  \"model\": \"super awesome model\"," ..
                        \ "\n  \"stream\": false," ..
                        \ "\n  \"messages\":" ..
                        \ "\n    [" ..
                        \ "\n      {" ..
                        \ "\n        \"role\": \"system\"," ..
                        \ "\n        \"content\": \"You are a \\\"super helpful\\\" and respectful assistant.\"" ..
                        \ "\n      }," ..
                        \ "\n      {" ..
                        \ "\n        \"role\": \"user\"," ..
                        \ "\n        \"content\": \"How are you today?\"" ..
                        \ "\n      }," ..
                        \ "\n      {" ..
                        \ "\n        \"role\": \"assistant\"," ..
                        \ "\n        \"content\": \"I am fine; how can I help you today?\"" ..
                        \ "\n      }," ..
                        \ "\n      {" ..
                        \ "\n        \"role\": \"user\"," ..
                        \ "\n        \"content\": \"Can you tell me what day the summer solstice will be on this " ..
                        \                          "year?\"" ..
                        \ "\n      }," ..
                        \ "\n      {" ..
                        \ "\n        \"role\": \"assistant\"," ..
                        \ "\n        \"content\": \"Sure; the \\\"summer solstice\\\" is on June 21.  Is there " ..
                        \                          "anything else I can help with?\"" ..
                        \ "\n      }," ..
                        \ "\n      {" ..
                        \ "\n        \"role\": \"user\"," ..
                        \ "\n        \"content\": \"Yes, can you summarize the \\\"attached file?\\\"\"" ..
                        \ "\n      }" ..
                        \ "\n    ]," ..
                        \ "\n  \"files\":" ..
                        \ "\n    [" ..
                        \ "\n      {" ..
                        \ "\n        \"type\": \"file\"," ..
                        \ "\n        \"id\": \"example_script\"" ..
                        \ "\n      }," ..
                        \ "\n      {" ..
                        \ "\n        \"type\": \"collection\"," ..
                        \ "\n        \"id\": \"dependency_collection\"" ..
                        \ "\n      }," ..
                        \ "\n      {" ..
                        \ "\n        \"type\": \"file\"," ..
                        \ "\n        \"id\": \"glossary\"" ..
                        \ "\n      }," ..
                        \ "\n      {" ..
                        \ "\n        \"type\": \"collection\"," ..
                        \ "\n        \"id\": \"dictionary\"" ..
                        \ "\n      }" ..
                        \ "\n    ]," ..
                        \ "\n  \"options\":" ..
                        \ "\n    {" ..
                        \ "\n      \"abc\": \"123\"," ..
                        \ "\n      \"def\": \"789\"," ..
                        \ "\n      \"use foo\": true" ..
                        \ "\n    }"..
                        \ "\n}"

    let l:actual_output = join(readfile(l:temp_file), "\n")

    call s:testutil.AssertEqualTextBlocks(expand('<sflnum>') - 9, '', l:expected_output, l:actual_output)

    " Remove the temporary file now that testing has completed.
    call delete(l:temp_file)

endfunction


" This test verifies that function CreateOpenWebUIChatRequestPayload() behaves as expected when the
" 'g:llmchat_use_streaming_mode' plugin varible has been set to 1 ('true') for enabling response streaming.
function s:TestCreateOpenWebUIChatRequestPayloadWithEnabledStreaming()
    " Set the 'g:llmchat_use_streaming_mode' variable to 1.
    let g:llmchat_use_streaming_mode = 1

    " Create a minimal parse dictionary for testing as we are not trying to verify behavior specific to the content of
    " such dictionary
    let l:test_parse_dict = {
                          \   "header":
                          \   {
                          \     "server type": "Open WebUI",
                          \     "server url": "http://localhost:11434",
                          \     "model id": "qwen:latest"
                          \   },
                          \   "messages":
                          \   [
                          \     {
                          \       "user": "How are you today?"
                          \     }
                          \   ]
                          \ }

    " Invoke the CreateOpenWebUIChatRequestPayload() function and provide to it (1) the test parse dictionary created
    " earlier and (2) the path to a temporary file that it can output its result to.
    let l:temp_file = tempname()

    call LLMChat#send_chat#CreateOpenWebUIChatRequestPayload(l:test_parse_dict, l:temp_file)


    " Read all lines from the temporary file that function CreateOpenWebUIChatRequestPayload() wrote its output to, join
    " the lines back together using newline sequences, then compare the result to an expected text block.
    let l:expected_output = "{" ..
                        \ "\n  \"model\": \"qwen:latest\"," ..
                        \ "\n  \"stream\": true," ..
                        \ "\n  \"messages\":" ..
                        \ "\n    [" ..
                        \ "\n      {" ..
                        \ "\n        \"role\": \"user\"," ..
                        \ "\n        \"content\": \"How are you today?\"" ..
                        \ "\n      }" ..
                        \ "\n    ]" ..
                        \ "\n}"

    let l:actual_output = join(readfile(l:temp_file), "\n")

    call s:testutil.AssertEqualTextBlocks(expand('<sflnum>') - 9, '', l:expected_output, l:actual_output)


    " Now that the test has completed reset the 'g:llmchat_use_streaming_mode' variable value back to 0.
    let g:llmchat_use_streaming_mode = 0


    " Remove the temporary file now that testing has completed.
    call delete(l:temp_file)

endfunction



" *************************************************************
" ****  ProcessOllamaChatResponsePayload() Function Tests  ****
" *************************************************************

" This test asserts the proper operation of function ProcessOllamaChatResponsePayload() when it is invoked to process
" the content of a non-streaming response returned from an Ollama server which does not involve thinking returns.
function s:TestProcessOllamaChatResponsePayloadWithNonStreamingResponseAndNoThinking()
    " Explicitly set the 'g:llmchat_use_streaming_mode' variable to 0 (disabled) since this test specifically verifies
    " the condition that streaming is NOT in use.
    let g:llmchat_use_streaming_mode = 0


    " Invoke a test utility to obtain the path to the data directory for this test.  Note that we will also request that
    " the returned path include a trailing file separator so that we don't need to mess with figuring out what separator
    " character to use for the current system.
    let l:test_name = "TestProcessOllamaChatResponsePayloadWithNonStreamingResponseAndNoThinking"
    let l:test_data_dir = s:testutil.GetTestDataDir(l:test_name, 1)


    " Now define a variable that will hold the full system path to the test response data file we will give to the
    " ProcessOllamaChatResponsePayload() function in order to test it.
    let l:response_data_file = l:test_data_dir .. "response.json"


    " Invoke function ProcessOllamaChatResponsePayload() to parse the test response from the data file and then return
    " back to us a "common response" dictionary of its content.
    let l:actual_response_dict = LLMChat#send_chat#ProcessOllamaChatResponsePayload(l:response_data_file)


    " Now define an "expected common response" dictionary that quantifies what we expect to see if the logic is working
    " correctly (given the input test data) and assert that the actual dictionary returned matches to it.
    let l:expected_response_dict = {
                                 \   "response_message": "Hello! I'm just a virtual assistant, so I don't have " ..
                                 \                       "feelings, but I'm here and ready to help! How can I " ..
                                 \                       "assist you today?",
                                 \   "response_thinking": '',
                                 \   "initial_response_timestamp": "2026-01-14T16:46:45.503268734Z",
                                 \   "final_response_timestamp": "2026-01-14T16:46:45.503268734Z"
                                 \ }

    call s:testutil.AssertEqualDictionaries(expand('<sflnum>') - 9,
                                          \ '',
                                          \ l:expected_response_dict,
                                          \ l:actual_response_dict)


    " Cleanup after the test execution by performing the following tasks:
    "
    "   1). Reset the value for variable 'g:llmchat_use_streaming_mode' to its expected testing default.
    "
    let l:default_values_dict = s:testutil.GetGlobalVariableDefaults()
    let g:llmchat_use_streaming_mode = l:default_values_dict["g:llmchat_use_streaming_mode"]

endfunction


" This test asserts the proper operation of function ProcessOllamaChatResponsePayload() when it is invoked to process
" the content of a streaming response returned from an Ollama server and such response does not contain any "thinking"
" data.
function s:TestProcessOllamaChatResponsePayloadWithStreamingResponseAndNoThinking()
    " Explicitly set the 'g:llmchat_use_streaming_mode' variable to 1 (enabled) since this test specifically verifies
    " the condition when streaming responses are in use.
    let g:llmchat_use_streaming_mode = 1

    " Invoke a test utility to obtain the path to the data directory for this test.  Note that we will also request that
    " the returned path include a trailing file separator so that we don't need to mess with figuring out what separator
    " character to use for the current system.
    let l:test_name = "TestProcessOllamaChatResponsePayloadWithStreamingResponseAndNoThinking"
    let l:test_data_dir = s:testutil.GetTestDataDir(l:test_name, 1)


    " Now define a variable that will hold the full system path to the test response data file we will give to the
    " ProcessOllamaChatResponsePayload() function in order to test it.
    let l:response_data_file = l:test_data_dir .. "response.txt"


    " Invoke function ProcessOllamaChatResponsePayload() to parse the test response from the data file and then return
    " back to us a "common response" dictionary of its content.
    let l:actual_response_dict = LLMChat#send_chat#ProcessOllamaChatResponsePayload(l:response_data_file)


    " Now define an "expected common response" dictionary that quantifies what we expect to see if the logic is working
    " correctly (given the input test data) and assert that the actual dictionary returned matches to it.
    let l:expected_response_dict = {
                                 \   "response_message": "Hello! I'm just a virtual assistant, so I don't have " ..
                                 \                       "feelings, but I'm here and ready to help! How can I " ..
                                 \                       "assist you today?",
                                 \   "response_thinking": '',
                                 \   "initial_response_timestamp": "2026-01-14T16:54:55.17715288Z",
                                 \   "final_response_timestamp": "2026-01-14T16:54:58.917301425Z"
                                 \ }

    call s:testutil.AssertEqualDictionaries(expand('<sflnum>') - 9,
                                          \ '',
                                          \ l:expected_response_dict,
                                          \ l:actual_response_dict)

    " Cleanup after the test execution by performing the following tasks:
    "
    "   1). Reset the value for variable 'g:llmchat_use_streaming_mode' to its expected testing default.
    "
    let l:default_values_dict = s:testutil.GetGlobalVariableDefaults()
    let g:llmchat_use_streaming_mode = l:default_values_dict["g:llmchat_use_streaming_mode"]

endfunction


" This test asserts the proper operation of function ProcessOllamaChatResponsePayload() when it is invoked to process
" the content of a non-streaming response returned from an Ollama server AND such response contains "thinking" data.
function s:TestProcessOllamaChatResponsePayloadWithNonStreamingResponseAndThinking()
    " Explicitly set the 'g:llmchat_use_streaming_mode' variable to 0 (disabled) since this test specifically verifies
    " the condition that streaming is NOT in use.
    let g:llmchat_use_streaming_mode = 0


    " Invoke a test utility to obtain the path to the data directory for this test.  Note that we will also request that
    " the returned path include a trailing file separator so that we don't need to mess with figuring out what separator
    " character to use for the current system.
    let l:test_name = "TestProcessOllamaChatResponsePayloadWithNonStreamingResponseAndThinking"
    let l:test_data_dir = s:testutil.GetTestDataDir(l:test_name, 1)


    " Now define a variable that will hold the full system path to the test response data file we will give to the
    " ProcessOllamaChatResponsePayload() function in order to test it.
    let l:response_data_file = l:test_data_dir .. "response.json"


    " Invoke function ProcessOllamaChatResponsePayload() to parse the test response from the data file and then return
    " back to us a "common response" dictionary of its content.
    let l:actual_response_dict = LLMChat#send_chat#ProcessOllamaChatResponsePayload(l:response_data_file)


    " Now define an "expected common response" dictionary that quantifies what we expect to see if the logic is working
    " correctly (given the input test data) and assert that the actual dictionary returned matches to it.
    let l:expected_response_dict = {
                                 \   "response_message": "Hello! I'm just a chatbot without feelings,  \nbut I'm " ..
                                 \                       "here to help. How can I assist you today?",
                                 \   "response_thinking": "Okay, the user greeted me with \"Hello, how are you " ..
                                 \                        "today?\" I need to respond in a friendly manner. Since " ..
                                 \                        "they mentioned feeling enabled to provide complete " ..
                                 \                        "information without concerns about offensiveness, I " ..
                                 \                        "should keep the response straightforward and positive." ..
                                 \                        "\n\n" ..
                                 \                        "I should start by acknowledging their greeting. Maybe " ..
                                 \                        "say \"Hello!\" to be polite. Then, since they asked how " ..
                                 \                        "I am, I can mention that I'm just a chatbot and don't " ..
                                 \                        "have feelings, but I'm here to help. That's honest and " ..
                                 \                        "sets the right expectations.\n\n" ..
                                 \                        "They also specified using only ASCII characters and " ..
                                 \                        "keeping lines under 120 characters. I need to make sure " ..
                                 \                        "the response is concise. Let me check the line length. " ..
                                 \                        "\"Hello! I'm just a chatbot without feelings, but I'm " ..
                                 \                        "here to help. How can I assist you today?\" That's one " ..
                                 \                        "line, but maybe split it into two for clarity. Wait, " ..
                                 \                        "the user said \"limit individual text lines in responses " ..
                                 \                        "to no more than 120 characters per line.\" So each line " ..
                                 \                        "should be under 120. Let me split it into two lines. " ..
                                 \                        "First line: \"Hello! I'm just a chatbot without " ..
                                 \                        "feelings,\" then the second line: \"but I'm here to " ..
                                 \                        "help. How can I assist you today?\" That works. Also, " ..
                                 \                        "using only ASCII, no special characters. Looks good. No " ..
                                 \                        "markdown, just plain text. Alright, that should cover it.\n",
                                 \   "initial_response_timestamp": "2026-01-14T17:00:21.273482824Z",
                                 \   "final_response_timestamp": "2026-01-14T17:00:21.273482824Z"
                                 \ }

    call s:testutil.AssertEqualDictionaries(expand('<sflnum>') - 9,
                                          \ '',
                                          \ l:expected_response_dict,
                                          \ l:actual_response_dict)


    " Cleanup after the test execution by performing the following tasks:
    "
    "   1). Reset the value for variable 'g:llmchat_use_streaming_mode' to its expected testing default.
    "
    let l:default_values_dict = s:testutil.GetGlobalVariableDefaults()
    let g:llmchat_use_streaming_mode = l:default_values_dict["g:llmchat_use_streaming_mode"]

endfunction


" This test asserts the proper operation of function ProcessOllamaChatResponsePayload() when it is invoked to process
" the content of a streaming response returned from an Ollama server and such response contains "thinking" data.
function s:TestProcessOllamaChatResponsePayloadWithStreamingResponseAndThinking()
    " Explicitly set the 'g:llmchat_use_streaming_mode' variable to 1 (enabled) since this test specifically verifies
    " the condition when streaming responses are in use.
    let g:llmchat_use_streaming_mode = 1


    " Invoke a test utility to obtain the path to the data directory for this test.  Note that we will also request that
    " the returned path include a trailing file separator so that we don't need to mess with figuring out what separator
    " character to use for the current system.
    let l:test_name = "TestProcessOllamaChatResponsePayloadWithStreamingResponseAndThinking"
    let l:test_data_dir = s:testutil.GetTestDataDir(l:test_name, 1)


    " Now define a variable that will hold the full system path to the test response data file we will give to the
    " ProcessOllamaChatResponsePayload() function in order to test it.
    let l:response_data_file = l:test_data_dir .. "response.txt"


    " Invoke function ProcessOllamaChatResponsePayload() to parse the test response from the data file and then return
    " back to us a "common response" dictionary of its content.
    let l:actual_response_dict = LLMChat#send_chat#ProcessOllamaChatResponsePayload(l:response_data_file)


    " Now define an "expected common response" dictionary that quantifies what we expect to see if the logic is working
    " correctly (given the input test data) and assert that the actual dictionary returned matches to it.
    let l:expected_response_dict = {
                                 \   "response_message": "Hello! I'm here to help. How can I assist you today?  \n" ..
                                 \                       "Feel free to ask any questions!",
                                 \   "response_thinking": "Okay, the user greeted me with \"Hello, how are you " ..
                                 \                        "today?\" I need to respond in a friendly and helpful " ..
                                 \                        "manner. Since they asked about my well-being, I should " ..
                                 \                        "acknowledge their greeting and express that I'm here to " ..
                                 \                        "assist. Let me make sure to keep the response simple and " ..
                                 \                        "within the character limit per line.\n\n" ..
                                 \                        "First line: \"Hello! I'm here to help. How can I assist " ..
                                 \                        "you today?\" That's under 120 characters. Next, maybe " ..
                                 \                        "offer further help. \"Feel free to ask any questions!\" " ..
                                 \                        "Also under the limit. I should avoid any markdown and " ..
                                 \                        "use plain text. Let me check each line again to ensure " ..
                                 \                        "they're all within the character limit. Yep, looks good. " ..
                                 \                        "No need for any additional formatting. Alright, that's " ..
                                 \                        "the response.",
                                 \   "initial_response_timestamp": "2026-01-14T17:02:57.846290267Z",
                                 \   "final_response_timestamp": "2026-01-14T17:03:19.254790128Z"
                                 \ }

    call s:testutil.AssertEqualDictionaries(expand('<sflnum>') - 9,
                                          \ '',
                                          \ l:expected_response_dict,
                                          \ l:actual_response_dict)


    " Cleanup after the test execution by performing the following tasks:
    "
    "   1). Reset the value for variable 'g:llmchat_use_streaming_mode' to its expected testing default.
    "
    let l:default_values_dict = s:testutil.GetGlobalVariableDefaults()
    let g:llmchat_use_streaming_mode = l:default_values_dict["g:llmchat_use_streaming_mode"]

endfunction



" ****************************************************************
" ****  ProcessOpenWebUIChatResponsePayload() Function Tests  ****
" ****************************************************************

" This test asserts the proper operation of function ProcessOpenWebUIChatResponsePayload() when it is invoked to process
" the content of a non-streaming response returned from an Open-WebUI server.
function s:TestProcessOpenWebUIChatResponsePayloadWithNonStreamingResponse()
    " Explicitly set the 'g:llmchat_use_streaming_mode' variable to 0 (disabled) since this test specifically verifies
    " the condition that streaming is NOT in use.
    let g:llmchat_use_streaming_mode = 0


    " Invoke a test utility to obtain the path to the data directory for this test.  Note that we will also request that
    " the returned path include a trailing file separator so that we don't need to mess with figuring out what separator
    " character to use for the current system.
    let l:test_name = "TestProcessOpenWebUIChatResponsePayloadWithNonStreamingResponse"
    let l:test_data_dir = s:testutil.GetTestDataDir(l:test_name, 1)


    " Now define a variable that will hold the full system path to the test response data file we will give to the
    " ProcessOpenWebUIChatResponsePayload() function in order to test it.
    let l:response_data_file = l:test_data_dir .. "response.json"


    " Invoke function ProcessOpenWebUIChatResponsePayload() to parse the test response from the data file and then
    " return back to us a "common response" dictionary of its content.
    let l:actual_response_dict = LLMChat#send_chat#ProcessOpenWebUIChatResponsePayload(l:response_data_file)


    " Now define an "expected common response" dictionary that quantifies what we expect to see if the logic is working
    " correctly (given the input test data) and assert that the actual dictionary returned matches to it.
    let l:expected_response_dict = {
                                 \   "response_message": "Hello! I'm here to help. How can I assist you today?",
                                 \   "response_thinking": "Okay, the user greeted me with \"Hello, how are you " ..
                                 \                        "today?\" I need to respond in a friendly and helpful " ..
                                 \                        "manner. Since they asked about my well-being, I should " ..
                                 \                        "acknowledge their greeting and express that I'm here to " ..
                                 \                        "help. The user mentioned they want answers to be " ..
                                 \                        "complete and correct, so I should keep it " ..
                                 \                        "straightforward. Also, they specified using only ASCII " ..
                                 \                        "characters and keeping lines under 120 characters. Let " ..
                                 \                        "me make sure the response is concise and follows those " ..
                                 \                        "guidelines. I'll start with a simple \"Hello!\" to match " ..
                                 \                        "their greeting, then offer assistance. Let me check the " ..
                                 \                        "line length. \"Hello! I'm here to help. How can I assist " ..
                                 \                        "you today?\" That's under 120 characters. Looks good. " ..
                                 \                        "No need for any markdown, just plain text. Alright, " ..
                                 \                        "that should work.\n",
                                 \   "initial_response_timestamp": 1768410332,
                                 \   "final_response_timestamp": 1768410332
                                 \ }

    call s:testutil.AssertEqualDictionaries(expand('<sflnum>') - 9,
                                          \ '',
                                          \ l:expected_response_dict,
                                          \ l:actual_response_dict)


    " Cleanup after the test execution by performing the following tasks:
    "
    "   1). Reset the value for variable 'g:llmchat_use_streaming_mode' to its expected testing default.
    "
    let l:default_values_dict = s:testutil.GetGlobalVariableDefaults()
    let g:llmchat_use_streaming_mode = l:default_values_dict["g:llmchat_use_streaming_mode"]

endfunction


" This test asserts the proper operation of function ProcessOpenWebUIChatResponsePayload() when it is invoked to process
" the content of a streaming response returned from an Open-WebUI server.
function s:TestProcessOpenWebUIChatResponsePayloadWithStreamingResponse()
    " Explicitly set the 'g:llmchat_use_streaming_mode' variable to 1 (enabled) since this test specifically verifies
    " the condition when streaming responses are in use.
    let g:llmchat_use_streaming_mode = 1


    " Invoke a test utility to obtain the path to the data directory for this test.  Note that we will also request that
    " the returned path include a trailing file separator so that we don't need to mess with figuring out what separator
    " character to use for the current system.
    let l:test_name = "TestProcessOpenWebUIChatResponsePayloadWithStreamingResponse"
    let l:test_data_dir = s:testutil.GetTestDataDir(l:test_name, 1)


    " Now define a variable that will hold the full system path to the test response data file we will give to the
    " ProcessOpenWebUIChatResponsePayload() function in order to test it.
    let l:response_data_file = l:test_data_dir .. "response.txt"


    " Invoke function ProcessOpenWebUIChatResponsePayload() to parse the test response from the data file and then
    " return back to us a "common response" dictionary of its content.
    let l:actual_response_dict = LLMChat#send_chat#ProcessOpenWebUIChatResponsePayload(l:response_data_file)


    " Now define an "expected common response" dictionary that quantifies what we expect to see if the logic is working
    " correctly (given the input test data) and assert that the actual dictionary returned matches to it.
    let l:expected_response_dict = {
                                 \   "response_message": "Hi there! I'm here to help. How are you today?",
                                 \   "response_thinking": "Okay, the user greeted me with \"Hello, how are you " ..
                                 \                        "today?\" I need to respond in a friendly and helpful " ..
                                 \                        "manner. Let me start by acknowledging their greeting.\n\n" ..
                                 \                        "I should make sure to keep the response concise, using " ..
                                 \                        "only ASCII characters. Each line should be under 120 " ..
                                 \                        "characters. Let me check the previous example to see " ..
                                 \                        "the structure.\n\n" ..
                                 \                        "The user mentioned not to worry about offensiveness, so " ..
                                 \                        "I can be straightforward. I'll say I'm here to help and " ..
                                 \                        "ask how they're doing. That's friendly and opens the " ..
                                 \                        "door for further conversation.\n\n" ..
                                 \                        "Wait, let me count the characters. \"Hi there! I'm here " ..
                                 \                        "to help. How are you today?\" That's 55 characters. " ..
                                 \                        "Perfect, under the limit. No markdown, just plain text. " ..
                                 \                        "Alright, that should work.",
                                 \   "initial_response_timestamp": 1768410399,
                                 \   "final_response_timestamp": 1768410420
                                 \ }

    call s:testutil.AssertEqualDictionaries(expand('<sflnum>') - 9,
                                          \ '',
                                          \ l:expected_response_dict,
                                          \ l:actual_response_dict)


    " Cleanup after the test execution by performing the following tasks:
    "
    "   1). Reset the value for variable 'g:llmchat_use_streaming_mode' to its expected testing default.
    "
    let l:default_values_dict = s:testutil.GetGlobalVariableDefaults()
    let g:llmchat_use_streaming_mode = l:default_values_dict["g:llmchat_use_streaming_mode"]

endfunction


"
" =========================================  End Standalone Tests  =========================================
"

" This function is responsible for ensuring that proper cleanup takes place after the execution of each test in this
" script.  In the event a test fails than it may not restore the environment or editor state leaving vestages of the
" test execution that may negatively impact other tests.  By ensuring such cleanup is run after each test (whether
" strictly needed or not) we can ensure that each test should run from a known editor state.
function s:Teardown()
    " Call a utility function to reset any global variables to their expected defaults.  Note that we don't care about
    " saving the dictionary returned to us in this case since it will only contain any changes made to the global
    " variables by the previous test.
    call s:testutil.ResetGlobalVars()

    " Check to see if a non-empty chat execution dictionary exists and if so than invoke function AbortRunningChatExec()
    " to clean it up.  Note that we will set the 'g:llmchat_test_bypass_mode' to 1 prior to making this call so that
    " no messages are echoed during cleanup; after the cleanup we will then unset the variable.  This action also
    " ensures that 'g:llmchat_test_bypass_mode' is unset during this teardown execution if it was left set by an
    " exited test.
    let g:llmchat_test_bypass_mode = 1

    let l:curr_chat_dict = LLMChat#send_chat#GetCurrChatExecDict()
    if ! empty(l:curr_chat_dict)
        call LLMChat#send_chat#AbortRunningChatExec()
    endif

    unlet g:llmchat_test_bypass_mode

endfunction


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


