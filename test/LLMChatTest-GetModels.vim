UTSuite LLMChat GetModels Tests

" Tests for logic found in the 'autoload/LLMChat/get_models.vim' script.

"-------------------------------------------------------------------------------------------------------------------

" =================
" ===           ===
" ===  Imports  ===
" ===           ===
" =================
" This section contains all script imports that are needed for the test execution.

" Import the 'import/utils.vim' script so that we have access to the main plugin utility functions.
import 'utils.vim' as util

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

" ****************************************
" ****  FetchModels() Function Tests  ****
" ****************************************

" This test verifies the proper operation of function FetchModels() when it is invoked from a chat log document that
" is setup for interactions with an Ollama server.
function! s:TestFetchModelsWithOllamaServer()
    " Set the 'g:llmchat_test_bypass_mode' variable to hold an empty dictionary.  Note that setting this variable to
    " any value will cause logic within the FetchModels() function to stop short of executing the cURL system call
    " allowing us to test the function logic without requiring a remote LLM server be available and network reachable.
    let g:llmchat_test_bypass_mode = { }


    " Setup a new, empty buffer and move focus to this buffer after creation.
    execute "new"


    " Now load the empty buffer with a test chat document appropriate for interactions with Ollama and then set the
    " filetype on the buffer to 'chtlg'.
    let l:chat_log_lines = [
                         \   "Server Type: Ollama",
                         \   "Server URL: http://myollama.org",
                         \   "Model ID: TBD",
                         \   "* ENDSETUP *"
                         \ ]

    call appendbufline('%', '$', l:chat_log_lines)
    set filetype=chtlg


    " Invoke the FetchModels() function to process the header information from the test chat log document and to setup
    " a cURL call that would request available model data from the remote LLM server.  Note that because we have set
    " the 'g:llmchat_test_bypass_mode' variable the cURL call won't be executed and instead the logic will bind the
    " following information into the dictionary we attached to 'g:llmchat_test_bypass_mode':
    "
    "  'curl_cmd' - The full curl command that would have been executed on the system.
    "  'model_listing_info_dict' - The model listing information dictionary that was created to hold state data needed
    "                              to complete the model listing workflow.
    "
    call LLMChat#get_models#FetchModels()


    " Retrieve the model listing information dict and assert that this contains the required fields and expected
    " information for the model listing request made.
    let l:model_listing_info_dict = g:llmchat_test_bypass_mode["model_listing_info_dict"]

    AssertTxt(has_key(l:model_listing_info_dict, "register name"),
            \ "Expected to find key 'register name' in the model information dictionary but no such key existed.")
    AssertTxt(has_key(l:model_listing_info_dict, "response payload file"),
            \ "Expected to find key 'response payload file' in the model information dictionary but no such key " ..
            \ "existed.")
    AssertTxt(has_key(l:model_listing_info_dict, "server type"),
            \ "Expected to find key 'server type' in the model information dictionary but no such key existed.")

    AssertEquals("Ollama", model_listing_info_dict['server type'])
    AssertEquals('"', model_listing_info_dict['register name'])


    " Retrieve the curl call that was added to the dictionary attached to variable 'g:llmchat_test_bypass_mode' and
    " assert that it has been created as expected.
    let l:actual_curl_call = g:llmchat_test_bypass_mode["curl_cmd"]

    let l:expected_curl_call = "curl -X GET --output \"" .. model_listing_info_dict['response payload file'] ..
                             \ "\" --write-out \"%{http_code}\" --silent --show-error --location " ..
                             \ "http://myollama.org/api/tags"

    AssertIs(l:expected_curl_call, l:actual_curl_call)


    " Cleanup - Take the following actions to cleanup after the execution of this test:
    "
    "   1). Unset the 'g:llmchat_test_bypass_mode' variable as this was being used exclusively here to bypass further
    "       logical executions from the function being tested.
    "
    "   2). Forcibly remove the buffer that was setup for testing.
    "
    unlet g:llmchat_test_bypass_mode
    bd!

endfunction


" This test verifies the proper operation of function FetchModels() when it is invoked from a chat log document that
" is setup for interactions with an Open WebUI server.
function! s:TestFetchModelsWithOpenWebUIServer()
    " Set the 'g:llmchat_test_bypass_mode' variable to hold an empty dictionary.  Note that setting this variable to
    " any value will cause logic within the FetchModels() function to stop short of executing the cURL system call
    " allowing us to test the function logic without requiring a remote LLM server be available and network reachable.
    let g:llmchat_test_bypass_mode = { }


    " Setup a new, empty buffer and move focus to this buffer after creation.
    execute "new"


    " Now load the empty buffer with a test chat document appropriate for interactions with Open WebUI and then set the
    " filetype on the buffer to 'chtlg'.
    let l:chat_log_lines = [
                         \   "Server Type: Open WebUI",
                         \   "Server URL: http://myopenwebui.org",
                         \   "Model ID: TBD",
                         \   "* ENDSETUP *"
                         \ ]

    call appendbufline('%', '$', l:chat_log_lines)
    set filetype=chtlg


    " Invoke the FetchModels() function to process the header information from the test chat log document and to setup
    " a cURL call that would request available model data from the remote LLM server.  Note that because we have set
    " the 'g:llmchat_test_bypass_mode' variable the cURL call won't be executed and instead the logic will bind the
    " following information into the dictionary we attached to 'g:llmchat_test_bypass_mode':
    "
    "  'curl_cmd' - The full curl command that would have been executed on the system.
    "  'model_listing_info_dict' - The model listing information dictionary that was created to hold state data needed
    "                              to complete the model listing workflow.
    "
    call LLMChat#get_models#FetchModels()


    " Retrieve the model listing information dict and assert that this contains the required fields and expected
    " information for the model listing request made.
    let l:model_listing_info_dict = g:llmchat_test_bypass_mode["model_listing_info_dict"]

    AssertTxt(has_key(l:model_listing_info_dict, "register name"),
            \ "Expected to find key 'register name' in the model information dictionary but no such key existed.")
    AssertTxt(has_key(l:model_listing_info_dict, "response payload file"),
            \ "Expected to find key 'response payload file' in the model information dictionary but no such key " ..
            \ "existed.")
    AssertTxt(has_key(l:model_listing_info_dict, "server type"),
            \ "Expected to find key 'server type' in the model information dictionary but no such key existed.")

    AssertEquals("Open WebUI", model_listing_info_dict['server type'])
    AssertEquals('"', model_listing_info_dict['register name'])


    " Retrieve the curl call that was added to the dictionary attached to variable 'g:llmchat_test_bypass_mode' and
    " assert that it has been created as expected.
    let l:actual_curl_call = g:llmchat_test_bypass_mode["curl_cmd"]

    let l:expected_curl_call = "curl -X GET --output \"" .. model_listing_info_dict['response payload file'] ..
                             \ "\" --write-out \"%{http_code}\" --silent --show-error --location " ..
                             \ "http://myopenwebui.org/api/models"

    AssertIs(l:expected_curl_call, l:actual_curl_call)


    " Cleanup - Take the following actions to cleanup after the execution of this test:
    "
    "   1). Unset the 'g:llmchat_test_bypass_mode' variable as this was being used exclusively here to bypass further
    "       logical executions from the function being tested.
    "
    "   2). Forcibly remove the buffer that was setup for testing.
    "
    unlet g:llmchat_test_bypass_mode
    bd!

endfunction


" This test asserts the proper operation of function FetchModels() when it is invoked from a chat log document that
" requires the use of authentication.
function! s:TestFetchModelswithRequiredAuth()
    " Set the 'g:llmchat_test_bypass_mode' variable to hold an empty dictionary.  Note that setting this variable to
    " any value will cause logic within the FetchModels() function to stop short of executing the cURL system call
    " allowing us to test the function logic without requiring a remote LLM server be available and network reachable.
    let g:llmchat_test_bypass_mode = { }


    " Setup a new, empty buffer and move focus to this buffer after creation.
    execute "new"


    " Now load the empty buffer with a test chat log document whose header information indicates that authentication
    " is required for server interactions.
    let l:chat_log_lines = [
                         \   "Server Type: Ollama",
                         \   "Server URL: http://llm.mydomain.net",
                         \   "Model ID: TBD",
                         \   "Use Auth Token: true",
                         \   "Auth Token: abc123",
                         \   "* ENDSETUP *"
                         \ ]

    call appendbufline('%', '$', l:chat_log_lines)


    " Make sure to set the 'filetype' on the test buffer to 'chtlg' so that its content is accepted for processing as
    " a chat log document
    set filetype=chtlg


    " Invoke the FetchModels() function to process the header information from the test chat log document and to setup
    " a cURL call that would request available model data from the remote LLM server.  Note that because we have set
    " the 'g:llmchat_test_bypass_mode' variable the cURL call won't be executed and instead the logic will bind the
    " following information into the dictionary we attached to 'g:llmchat_test_bypass_mode':
    "
    "  'curl_cmd' - The full curl command that would have been executed on the system.
    "  'model_listing_info_dict' - The model listing information dictionary that was created to hold state data needed
    "                              to complete the model listing workflow.
    "
    call LLMChat#get_models#FetchModels()


    " Retrieve the model listing information dict and assert that this contains the required fields and expected
    " information for the model listing request made.
    let l:model_listing_info_dict = g:llmchat_test_bypass_mode["model_listing_info_dict"]

    AssertTxt(has_key(l:model_listing_info_dict, "register name"),
            \ "Expected to find key 'register name' in the model information dictionary but no such key existed.")
    AssertTxt(has_key(l:model_listing_info_dict, "response payload file"),
            \ "Expected to find key 'response payload file' in the model information dictionary but no such key " ..
            \ "existed.")
    AssertTxt(has_key(l:model_listing_info_dict, "server type"),
            \ "Expected to find key 'server type' in the model information dictionary but no such key existed.")

    AssertEquals("Ollama", model_listing_info_dict['server type'])
    AssertEquals('"', model_listing_info_dict['register name'])


    " Retrieve the curl call that was added to the dictionary attached to variable 'g:llmchat_test_bypass_mode' and
    " assert that it has been created as expected.
    let l:actual_curl_call = g:llmchat_test_bypass_mode["curl_cmd"]

    let l:expected_curl_call = "curl -X GET --output \"" .. model_listing_info_dict['response payload file'] ..
                             \ "\" --write-out \"%{http_code}\" --silent --show-error --location " ..
                             \ "--header \"Authorization: Bearer abc123\" http://llm.mydomain.net/api/tags"

    AssertIs(l:expected_curl_call, l:actual_curl_call)


    " Cleanup - Take the following actions to cleanup after the execution of this test:
    "
    "   1). Unset the 'g:llmchat_test_bypass_mode' variable as this was being used exclusively here to bypass further
    "       logical executions from the function being tested.
    "
    "   2). Forcibly remove the buffer that was setup for testing.
    "
    unlet g:llmchat_test_bypass_mode
    bd!

endfunction


" This test asserts the proper operation of function FetchModels() when a custom register name has been passed to the
" function execution.
function! s:TestFetchModelsWithCustomRegisterArg()
    " Set the 'g:llmchat_test_bypass_mode' variable to hold an empty dictionary.  Note that setting this variable to
    " any value will cause logic within the FetchModels() function to stop short of executing the cURL system call
    " allowing us to test the function logic without requiring a remote LLM server be available and network reachable.
    let g:llmchat_test_bypass_mode = { }


    " Setup a new, empty buffer and move focus to this buffer after creation.
    execute "new"


    " Load the empty buffer with a test chat log document that contains the minimal information required to be used
    " for a model listing operation.
    let l:chat_log_lines = [
                         \   "Server Type: Ollama",
                         \   "Server URL: http://myollama.org",
                         \   "Model ID: TBD",
                         \   "* ENDSETUP *"
                         \ ]

    call appendbufline('%', '$', l:chat_log_lines)


    " Set the 'filetype' on the test buffer to 'chtlg' so that the content being held is recognized as a chat log
    " document.
    set filetype=chtlg


    " Invoke the FetchModels() function using a known register name.  Note that because we have set the
    " 'g:llmchat_test_bypass_mode' variable the cURL call won't be executed and instead the logic will bind the
    " following information into the dictionary we attached to 'g:llmchat_test_bypass_mode':
    "
    "   'curl_cmd' - The full curl command that would have been executed on the system.
    "   'model_listing_info_dict' - The model listing information dictionary that was created to hold state data needed
    "                               to complete the model listing workflow.
    "
    call LLMChat#get_models#FetchModels('a')


    " Retrieve the model listing information dict and assert that this contains the required fields and expected
    " information for the model listing request made.
    let l:model_listing_info_dict = g:llmchat_test_bypass_mode["model_listing_info_dict"]

    AssertTxt(has_key(l:model_listing_info_dict, "register name"),
            \ "Expected to find key 'register name' in the model information dictionary but no such key existed.")
    AssertTxt(has_key(l:model_listing_info_dict, "response payload file"),
            \ "Expected to find key 'response payload file' in the model information dictionary but no such key " ..
            \ "existed.")
    AssertTxt(has_key(l:model_listing_info_dict, "server type"),
            \ "Expected to find key 'server type' in the model information dictionary but no such key existed.")

    AssertEquals("Ollama", model_listing_info_dict['server type'])
    AssertEquals('a', model_listing_info_dict['register name'])


    " Retrieve the curl call that was added to the dictionary attached to variable 'g:llmchat_test_bypass_mode' and
    " assert that it has been created as expected.
    let l:actual_curl_call = g:llmchat_test_bypass_mode["curl_cmd"]

    let l:expected_curl_call = "curl -X GET --output \"" .. model_listing_info_dict['response payload file'] ..
                             \ "\" --write-out \"%{http_code}\" --silent --show-error --location " ..
                             \ "http://myollama.org/api/tags"

    AssertIs(l:expected_curl_call, l:actual_curl_call)


    " Cleanup - Take the following actions to cleanup after the execution of this test:
    "
    "   1). Unset the 'g:llmchat_test_bypass_mode' variable as this was being used exclusively here to bypass further
    "       logical executions from the function being tested.
    "
    "   2). Forcibly remove the buffer that was setup for testing.
    "
    unlet g:llmchat_test_bypass_mode
    bd!

endfunction


" This test asserts the proper operation of function FetchModels() when the 'g:llmchat_curl_extra_args' global varible
" has been defined with a non-empty value (essentially the test shows that the extra arguments are included into the
" curl commands created by the function).
function! s:TestFetchModelsWithExtraCurlArgs()
    " Set the 'g:llmchat_test_bypass_mode' variable to hold an empty dictionary.  Note that setting this variable to
    " any value will cause logic within the FetchModels() function to stop short of executing the cURL system call
    " allowing us to test the function logic without requiring a remote LLM server be available and network reachable.
    let g:llmchat_test_bypass_mode = { }


    " Set the 'g:llmchat_curl_extra_args' variable to some arbitrary value known to the test. Note that we don't care
    " that this uses valid curl arguments; we only care that we know what value was set so we can validate how it was
    " injected into the curl call later.
    let g:llmchat_curl_extra_args = '--extra-arg-1  --extra-arg-2'


    " Setup a new, empty buffer and move focus to this buffer after creation.
    execute "new"


    " Load the empty buffer with a test chat document that holds the minimum information required by the FetchModels()
    " function for processing.
    let l:chat_log_lines = [
                         \   "Server Type: Ollama",
                         \   "Server URL: http://myollama.org",
                         \   "Model ID: TBD",
                         \   "* ENDSETUP *"
                         \ ]

    call appendbufline('%', '$', l:chat_log_lines)


    " Set the 'filetype' on the buffer to 'chtlg' so that its content is recognized as a chat log document.
    set filetype=chtlg


    " Invoke the FetchModels() function to process the header information from the test chat log document and to setup
    " a cURL call that would request available model data from the remote LLM server.  Note that because we have set
    " the 'g:llmchat_test_bypass_mode' variable the cURL call won't be executed and instead the logic will bind the
    " following information into the dictionary we attached to 'g:llmchat_test_bypass_mode':
    "
    "  'curl_cmd' - The full curl command that would have been executed on the system.
    "  'model_listing_info_dict' - The model listing information dictionary that was created to hold state data needed
    "                              to complete the model listing workflow.
    "
    call LLMChat#get_models#FetchModels()


    " Retrieve the model listing information dict and assert that this contains the required fields and expected
    " information for the model listing request made.
    let l:model_listing_info_dict = g:llmchat_test_bypass_mode["model_listing_info_dict"]

    AssertTxt(has_key(l:model_listing_info_dict, "register name"),
            \ "Expected to find key 'register name' in the model information dictionary but no such key existed.")
    AssertTxt(has_key(l:model_listing_info_dict, "response payload file"),
            \ "Expected to find key 'response payload file' in the model information dictionary but no such key " ..
            \ "existed.")
    AssertTxt(has_key(l:model_listing_info_dict, "server type"),
            \ "Expected to find key 'server type' in the model information dictionary but no such key existed.")

    AssertEquals("Ollama", model_listing_info_dict['server type'])
    AssertEquals('"', model_listing_info_dict['register name'])


    " Retrieve the curl call that was added to the dictionary attached to variable 'g:llmchat_test_bypass_mode' and
    " assert that it has been created as expected.
    let l:actual_curl_call = g:llmchat_test_bypass_mode["curl_cmd"]

    let l:expected_curl_call = "curl -X GET --output \"" .. model_listing_info_dict['response payload file'] ..
                             \ "\" --write-out \"%{http_code}\" --silent --show-error --location " ..
                             \ "--extra-arg-1  --extra-arg-2 http://myollama.org/api/tags"

    AssertIs(l:expected_curl_call, l:actual_curl_call)


    " Cleanup - Take the following actions to cleanup after the execution of this test:
    "
    "   1). Unset the 'g:llmchat_test_bypass_mode' variable as this was being used exclusively here to bypass further
    "       logical executions from the function being tested.
    "
    "   2). Forcibly remove the buffer that was setup for testing.
    "
    "   3). Reset the 'g:llmchat_curl_extra_args' variable to its testing default value.
    "
    unlet g:llmchat_test_bypass_mode
    bd!

    let l:defaults_dict = s:testutil.GetGlobalVariableDefaults()
    let g:llmchat_curl_extra_args = l:defaults_dict['g:llmchat_curl_extra_args']

endfunction


" This test asserts the proper operation of function FetchModels() when it is invoked while a non-empty debug target
" is in effect.
function! s:TestFetchModelsWithDebugMode()
    " Set the 'g:llmchat_test_bypass_mode' variable to hold an empty dictionary.  Note that setting this variable to
    " any value will cause logic within the FetchModels() function to stop short of executing the cURL system call
    " allowing us to test the function logic without requiring a remote LLM server be available and network reachable.
    let g:llmchat_test_bypass_mode = { }


    " Request Vim to provide us with the name and path to a temporary file then set this file as the debug target to
    " be used for testing.
    let g:llmchat_debug_mode_target = tempname()


    " Setup a new, empty buffer and move focus to this buffer after creation.
    execute "new"


    " Now load the empty buffer with a test chat log document that holds sufficient content for the FetchModels()
    " function to use it for processing.
    let l:chat_log_lines = [
                         \   "Server Type: Ollama",
                         \   "Server URL: http://myollama.org",
                         \   "Model ID: TBD",
                         \   "* ENDSETUP *"
                         \ ]

    call appendbufline('%', '$', l:chat_log_lines)


    " Set the 'filetype' for the buffer to 'chtlg' so that its contents are recognized as a chat log document.
    set filetype=chtlg


    " Invoke the FetchModels() function to process the header information in our test chat document and to setup
    " the cURL call that *would* have been executed.  Note that because the 'g:llmchat_test_bypass_mode' variable was
    " set the cURL call execution is bypassed and such command will be passed back to us (along with other information)
    " through the dictionary attached to the 'g:llmchat_test_bypass_mode' variable.
    call LLMChat#get_models#FetchModels()


    " Assert that the 'g:llmchat_test_bypass_mode' variable's dictionary contains an entry for 'curl_cmd' but don't
    " go to the extent of validating it as this is already done in other tests.  Here this check is performed only to
    " show that the full function logic did run and so we can expect debug output to have been produced.
    AssertTxt(has_key(g:llmchat_test_bypass_mode, 'curl_cmd'),
            \ "Expected to see the curl command generated by function FetchModels() returned within the dictionary " ..
            \ "attached to global variable 'g:llmchat_test_bypass_mode' but no such entry existed.")


    " Assert that the file allocated for debug use (1) is readable for Vim (which we assume implies file existence) and
    " (2) that such file is NOT empty.  Note that we're not concerned with validating everything that was written; only
    " in showing that debug output was generated which shows that the paths used to create such content were engaged.
    AssertTxt(filereadable(g:llmchat_debug_mode_target),
            \ "Expected to find the file used as a debug target for this test to be readable for Vim but instead " ..
            \ "found that it was not.  The temporary file path in use as such target at this time was '" ..
            \ g:llmchat_debug_mode_target .. "'.")

    let l:debug_file_lines = readfile(g:llmchat_debug_mode_target)

    AssertTxt(len(join(l:debug_file_lines, ' ')) > 0,
            \ "Expected to find the file used as a debug target for this test to contain text information but " ..
            \ "instead found it to be empty.")


    " Cleanup - Take the following actions to cleanup after the execution of this test:
    "
    "   1). Unset the 'g:llmchat_test_bypass_mode' variable as this was being used exclusively here to bypass further
    "       logical executions from the function being tested.
    "
    "   2). Forcibly remove the buffer that was setup for testing.
    "
    "   3). Remove the temporary file whose name and path are currently held by variable 'g:llmchat_debug_mode_target'.
    "
    "   4). Unset the 'g:llmchat_debug_mode_target' variable to remove the debug target in use.
    "
    unlet g:llmchat_test_bypass_mode
    bd!
    call delete(g:llmchat_debug_mode_target)
    unlet g:llmchat_debug_mode_target

endfunction


" This test asserts that a known exception is thrown from function FetchModels() when it is invoked from a buffer that
" is NOT holding a chat log.
function! s:TestFetchModelsWithNonChatLogBuffer()
    " Set the 'g:llmchat_test_bypass_mode' variable so that (1) exceptions are properly surfaced for testing by
    " re-throwing them and (2) echo messages requiring acknowledgment are silenced.  Note that in this case that the
    " value assigned to 'g:llmchat_test_bypass_mode' is arbitrary so we will use 1 (i.e., 'true') by general
    " convention.
    let g:llmchat_test_bypass_mode = 1


    " Setup a new, empty buffer and move focus to this buffer after creation.
    execute "new"


    " Load a chat log document into the new buffer that contains enough information for the FetchModels() function
    " to operation (if it were to actually process the document).
    let l:chat_log_lines = [
                         \   "Server Type: Ollama",
                         \   "Server URL: http://myollama.org",
                         \   "Model ID: TBD",
                         \   "* ENDSETUP *"
                         \ ]

    call appendbufline('%', '$', l:chat_log_lines)


    try
        " Attempt to invoke function FetchModels() on the test buffer; we expect to see an exception thrown in this
        " case because the filetype on the buffer was never set to indicate that the buffer holds a chat log.
        call LLMChat#get_models#FetchModels()


        " If the logic reaches this point than fail the test; if properly working an exception should have been thrown
        " earlier making this statements unreachable.
        call s:testutil.Fail(expand('<sflnum>') - 9,
                           \ "Expected to see an exception thrown from function FetchModels() when it was invoked " ..
                           \ "at a time when the active buffer did not have a filetype setting indicating it to " ..
                           \ "be a chat log; however, no exception occurred.")

    catch /\c[error].*non-chat buffer.*/
        " If the logic comes here than we've caught an exception whose message appears to match to the type of exception
        " we were expecting to see; allow the test to proceed on as this is what should happen if the logic was
        " working correctly.
    endtry


    " Cleanup - Perform the following steps to cleanup after the test execution:
    "
    "   1). Forcibly remove the test buffer and its content.
    "
    "   2). Unset the 'g:llmchat_test_bypass_mode' now that the test is finished.
    bd!
    unlet g:llmchat_test_bypass_mode

endfunction


" This test asserts that a known exception is thrown from function FetchModels() when a bad register name is given to
" it.
function! s:TestFetchModelsWithBadRegisterName()
    " Set the 'g:llmchat_test_bypass_mode' variable so that (1) exceptions are properly surfaced for testing by
    " re-throwing them and (2) echo messages requiring acknowledgment are silenced.  Note that in this case that the
    " value assigned to 'g:llmchat_test_bypass_mode' is arbitrary so we will use 1 (i.e., 'true') by general
    " convention.
    let g:llmchat_test_bypass_mode = 1


    " Setup a new, empty buffer and move focus to this buffer after creation.
    execute "new"


    " Load a chat log document into the new buffer that contains enough information for the FetchModels() function to
    " execute.
    let l:chat_log_lines = [
                         \   "Server Type: Ollama",
                         \   "Server URL: http://myollama.org",
                         \   "Model ID: TBD",
                         \   "* ENDSETUP *"
                         \ ]

    call appendbufline('%', '$', l:chat_log_lines)


    " Set the filetype for the test buffer to 'chtlg' so that it is recognized as holding a chat log document.
    set filetype=chtlg


    try
        " Attempt to pass an invalid register name to the FetchModels() function; if properly working this should cause
        " an exception to be thrown.
        call LLMChat#get_models#FetchModels('*')


        " If the logic reaches this point than fail the test; if properly working an exception should have been thrown
        " earlier making this statement unreachable.
        call s:testutil.Fail(expand('<sflnum>') - 9,
                           \ "Expected to see an exception thrown from function FetchModels() when it was invoked " ..
                           \ "with an invalid register name; however, no exception occurred.")

    catch /\c[error].*register name.*invalid.*/
        " If the logic comes here than we've caught an exception whose message appears to match to the type of exception
        " we were expecting to see; allow the test to proceed on as this is what should happen if the logic was
        " working correctly.
    endtry


    " Cleanup - Perform the following steps to cleanup after the test execution:
    "
    "   1). Forcibly remove the test buffer and its content.
    "
    "   2). Unset varible 'g:llmchat_test_bypass_mode' now that the test is finished.
    "
    bd!
    unlet g:llmchat_test_bypass_mode

endfunction


" This test asserts that a known exception is thrown from function FetchModels() when it is invoked in the context of
" a chat log buffer that declares an unsupported server type.
function! s:TestFetchModelsWithUnknownServerType()
    " Set the 'g:llmchat_test_bypass_mode' variable so that (1) exceptions are properly surfaced for testing by
    " re-throwing them and (2) echo messages requiring acknowledgment are silenced.  Note that in this case that the
    " value assigned to 'g:llmchat_test_bypass_mode' is arbitrary so we will use 1 (i.e., 'true') by general
    " convention.
    let g:llmchat_test_bypass_mode = 1


    " Setup a new, empty buffer and move focus to this buffer after creation.
    execute "new"


    " Load a chat log document into the new buffer that gives an unsupported server type in its header section.
    let l:chat_log_lines = [
                         \   "Server Type: Unsupported",
                         \   "Server URL: http://myllm.myorg.com",
                         \   "Model ID: TBD",
                         \   "* ENDSETUP *"
                         \ ]

    call appendbufline('%', '$', l:chat_log_lines)


    " Set the filetype for the test buffer to 'chtlg' so that it is recognized as holding a chat log document.
    set filetype=chtlg


    try
        " Attempt to invoke the FetchModels() to process the test chat log document; this should result in an
        " exception being thrown when the unsupported server type value is found.
        call LLMChat#get_models#FetchModels()


        " If the logic reaches this point than fail the test; if properly working an exception should have been thrown
        " earlier making this statement unreachable.
        call s:testutil.fail(expand('<sflnum>') - 9,
                           \ "Expected to see an exception thrown from function FetchModels() when it was invoked " ..
                           \ "in the context of a chat log document that declared use of an unsupported server " ..
                           \ "type; however, no exception occurred.")

    catch /\c[error].*server type.*not recognized.*/
        " If the logic comes here than we've caught an exception whose message appears to match to the type of exception
        " we were expecting to see; allow the test to proceed on as this is what should happen if the logic was
        " working correctly.
    endtry


    " Cleanup - Perform the following steps to cleanup after the test execution:
    "
    "   1). Forcibly remove the test buffer and its content.
    "
    "   2). Unset varible 'g:llmchat_test_bypass_mode' now that the test is finished.
    "
    bd!
    unlet g:llmchat_test_bypass_mode

endfunction



" ********************************************************
" ****  ProcessModelListingResponse() Function Tests  ****
" ********************************************************

" This test asserts the proper operation of function ProcessModelListingResponse() when invoked to handle a model
" listing response from an Ollama server.
function! s:TestProcessModelListingResponseWithOllamaResponse()
    " Set the 'g:llmchat_test_bypass_mode' variable to hold an empty dictionary.  This will do a number of things
    " including (1) disengaging code invocations that go beyond the function so we can keep the test more focused, (2)
    " disable any popup dialogs that would otherwise be created, and (3) allow information from the function
    " execution to be returned back to this test later for verification.
    let g:llmchat_test_bypass_mode = { }


    " Build out the path to a test "response" file that will be utilized later to emulate an Ollama server model
    " listing response.  Note that the data directory path for the file will come from a testing utility intended to
    " help test code remain agnostic of details like the file separator in use on the current OS.
    let l:test_data_dir = s:testutil.GetTestDataDir("TestProcessModelListingResponseWithOllamaResponse", 1)
    let l:test_response_file = l:test_data_dir .. "response.json"


    " Request a temporary file from Vim and then copy the full content of the 'l:test_response_file' into the temporary
    " file location.  We do this because in the course of proper operation the response file will be removed by the
    " ProcessModelListingResponse() function and we don't want to delete our test data file.
    let l:temp_response_file = tempname()
    call filecopy(l:test_response_file, l:temp_response_file)


    " Setup a test "model listing dictionary" that contains all information related to the model listing request that
    " would have been passed down from the first part of the model listing workflow.
    "
    " NOTE: For this test we will simulate the following conditions through the dictionary:
    "
    "   1). The cURL call will appear to have exited successfully (i.e., an exit status of 0).
    "   2). The HTTP status code will be listed as 200 indicating a successful response to the request.
    "
    let l:test_listing_dict = {
                            \   "register name": "a",
                            \   "http response code": "200",
                            \   "exit status": 0,
                            \   "server type": "Ollama",
                            \   "response payload file": l:temp_response_file
                            \ }


    " Invoke function ProcessModelListingResponse() and pass to it the test model listing dictionary created earlier.
    " Note that since the 'g:llmchat_test_bypass_mode' variable was set the execution will stop short of showing the
    " model listing popup dialog and will instead add the following entries to the dictionary held by
    " 'g:llmchat_test_bypass_mode':
    "
    "   'popup_options' --> The dictionary containing all options that *would* have been passed to the popup window.
    "   'model_info_dict' --> The revised model information dictionary that was originally given to the function
    "                         invocation.
    "
    " Later we will perform verifications on the information found in both of these entries.
    call LLMChat#get_models#ProcessModelListingResponse(l:test_listing_dict)


    " Verify that the file pointed to by variable 'l:temp_response_file' no longer exists on the system; this shows
    " that the execution of ProcessModelListingResponse() properly removed such file as part of its cleanup.
    AssertTxt(filereadable(l:temp_response_file) != 1,
            \ "Expected to find the response file removed from disk at the completion of function " ..
            \ "ProcessModelListingResponse() but the file still appeared to exist.")


    " Now verify the following concerning the 'popup_options' entry added to the dictionary held by variable
    " 'g:llmchat_test_bypass_mode':
    "
    "   1). A 'filter' entry was defined which has an expected value.
    "   2). A 'callback' entry was defined which has an expected value.
    "   3). A 'maxheight' entry was defined whose value is equal to the value returned by function
    "       CalculateTotalWinHeight() from the 'import/utils.vim' script.
    "
    let l:popup_opts_dict = g:llmchat_test_bypass_mode['popup_options']
    AssertTxt(has_key(l:popup_opts_dict, "filter"),
            \ "Expected to find a 'filter' entry within the popup options dictionary created by function " ..
            \ "ProcessModelListingResponse() but no such entry was located.")
    AssertEquals("LLMChat#get_models#HandleModelSelectionKeyPress", l:popup_opts_dict['filter'])

    AssertTxt(has_key(l:popup_opts_dict, "callback"),
            \ "Expected to find a 'callback' entry within the popup options dictionary created by function " ..
            \ "ProcessModelListingResponse() but no such entry was located.")
    AssertEquals("LLMChat#get_models#HandleModelSelection", l:popup_opts_dict['callback'])

    AssertTxt(has_key(l:popup_opts_dict, "maxheight"),
            \ "Expected to find a 'maxheight' entry within the popup options dictionary created by function " ..
            \ "ProcessModelListingResponse() but no such entry was located.")
    AssertEquals(s:util.CalculateTotalWinHeight(), l:popup_opts_dict['maxheight'])


    " Verify the following concerning the 'model_info_dict' entry returned within the dictionary held by variable
    " 'g:llmchat_test_bypass_mode':
    "
    "   1). An entry exists inside the model information dictionary with name 'model list'.
    "
    "   2). The content of the 'model list' matches to a sorted list of model information dictionaries that hold all
    "       data found within the test response JSON file.
    "
    let l:model_info_dict = g:llmchat_test_bypass_mode["model_info_dict"]
    AssertTxt(has_key(l:model_info_dict, "model list"),
            \ "Expected to find a 'model list' entry within the model information dictionary amended by function " ..
            \ "ProcessModelListingResponse() but no such entry was located.")

    let l:actual_model_list = l:model_info_dict['model list']

    let l:expected_model_list = [
                              \   {
                              \     "model id": "nous-hermes2:34b",
                              \     "model display": "nous-hermes2:34b",
                              \     "details":
                              \     {
                              \       "name":"nous-hermes2:34b",
                              \       "model":"nous-hermes2:34b",
                              \       "modified_at":"2025-11-14T09:21:09.614882696-06:00",
                              \       "size":19466541333,
                              \       "digest":"1fbb49caabbd2d36b7132848ddf7dcd7f2fb9b58df9838850f2c4160b9fe7ba4",
                              \       "details":
                              \       {
                              \         "parent_model":"",
                              \         "format":"gguf",
                              \         "family":"llama",
                              \         "families": [ "llama" ],
                              \         "parameter_size":"34B",
                              \         "quantization_level":"Q4_0"
                              \       }
                              \     }
                              \   },
                              \   {
                              \     "model id": "qwq:32b",
                              \     "model display": "qwq:32b",
                              \     "details":
                              \     {
                              \       "name":"qwq:32b",
                              \       "model":"qwq:32b",
                              \       "modified_at":"2025-11-14T09:17:30.481079257-06:00",
                              \       "size":19851349657,
                              \       "digest":"009cb3f08d74437380f3b84194c1bd34f1cc3d95a2bb87241d89387fc22a9ddf",
                              \       "details":
                              \       {
                              \         "parent_model":"",
                              \         "format":"gguf",
                              \         "family":"qwen2",
                              \         "families": [ "qwen2" ],
                              \         "parameter_size":"32.8B",
                              \         "quantization_level":"Q4_K_M"
                              \       }
                              \     }
                              \   }
                              \ ]

    call s:testutil.AssertEqualLists(expand('<sflnum>') - 9, '', l:expected_model_list, l:actual_model_list)


    " Cleanup - Perform the following actions after the execution of this test:
    "
    "   1). Unset the 'g:llmchat_test_bypass_mode' variable as we no longer need to force testing bypasses.
    "
    unlet g:llmchat_test_bypass_mode

endfunction


" This test asserts the proper operation of function ProcessModelListingResponse() when invoked to handle a model
" listing response from an Open WebUI server.
function! s:TestProcessModelListingResponseWithOpenWebUIResponse()
    " Set the 'g:llmchat_test_bypass_mode' variable to hold an empty dictionary.  This will do a number of things
    " including (1) disengaging code invocations that go beyond the function so we can keep the test more focused, (2)
    " disable any popup dialogs that would otherwise be created, and (3) allow information from the function
    " execution to be returned back to this test later for verification.
    let g:llmchat_test_bypass_mode = { }


    " Build out the path to a test "response" file that will be utilized later to emulate an Open WebUI server model
    " listing response.  Note that the data directory path for the file will come from a testing utility intended to
    " help test code remain agnostic of details like the file separator in use on the current OS.
    let l:test_data_dir = s:testutil.GetTestDataDir("TestProcessModelListingResponseWithOpenWebUIResponse", 1)
    let l:test_response_file = l:test_data_dir .. "response.json"


    " Request a temporary file from Vim and then copy the full content of the 'l:test_response_file' into the temporary
    " file location.  We do this because in the course of proper operation the response file will be removed by the
    " ProcessModelListingResponse() function and we don't want to delete our test data file.
    let l:temp_response_file = tempname()
    call filecopy(l:test_response_file, l:temp_response_file)


    " Setup a test "model listing dictionary" that contains all information related to the model listing request that
    " would have been passed down from the first part of the model listing workflow.
    "
    " NOTE: For this test we will simulate the following conditions through the dictionary:
    "
    "   1). The cURL call will appear to have exited successfully (i.e., an exit status of 0).
    "   2). The HTTP status code will be listed as 200 indicating a successful response to the request.
    "
    let l:test_listing_dict = {
                            \   "register name": "a",
                            \   "http response code": "200",
                            \   "exit status": 0,
                            \   "server type": "Open WebUI",
                            \   "response payload file": l:temp_response_file
                            \ }


    " Invoke function ProcessModelListingResponse() and pass to it the test model listing dictionary created earlier.
    " Note that since the 'g:llmchat_test_bypass_mode' variable was set the execution will stop short of showing the
    " model listing popup dialog and will instead add the following entries to the dictionary held by
    " 'g:llmchat_test_bypass_mode':
    "
    "   'popup_options' --> The dictionary containing all options that *would* have been passed to the popup window.
    "   'model_info_dict' --> The revised model information dictionary that was originally given to the function
    "                         invocation.
    "
    " Later we will perform verifications on the information found in both of these entries.
    call LLMChat#get_models#ProcessModelListingResponse(l:test_listing_dict)


    " Verify that the file pointed to by variable 'l:temp_response_file' no longer exists on the system; this shows
    " that the execution of ProcessModelListingResponse() properly removed such file as part of its cleanup.
    AssertTxt(filereadable(l:temp_response_file) != 1,
            \ "Expected to find the response file removed from disk at the completion of function " ..
            \ "ProcessModelListingResponse() but the file still appeared to exist.")


    " Now verify the following concerning the 'popup_options' entry added to the dictionary held by variable
    " 'g:llmchat_test_bypass_mode':
    "
    "   1). A 'filter' entry was defined which has an expected value.
    "   2). A 'callback' entry was defined which has an expected value.
    "   3). A 'maxheight' entry was defined whose value is equal to the value returned by function
    "       CalculateTotalWinHeight() from the 'import/utils.vim' script.
    "
    let l:popup_opts_dict = g:llmchat_test_bypass_mode['popup_options']
    AssertTxt(has_key(l:popup_opts_dict, "filter"),
            \ "Expected to find a 'filter' entry within the popup options dictionary created by function " ..
            \ "ProcessModelListingResponse() but no such entry was located.")
    AssertEquals("LLMChat#get_models#HandleModelSelectionKeyPress", l:popup_opts_dict['filter'])

    AssertTxt(has_key(l:popup_opts_dict, "callback"),
            \ "Expected to find a 'callback' entry within the popup options dictionary created by function " ..
            \ "ProcessModelListingResponse() but no such entry was located.")
    AssertEquals("LLMChat#get_models#HandleModelSelection", l:popup_opts_dict['callback'])

    AssertTxt(has_key(l:popup_opts_dict, "maxheight"),
            \ "Expected to find a 'maxheight' entry within the popup options dictionary created by function " ..
            \ "ProcessModelListingResponse() but no such entry was located.")
    AssertEquals(s:util.CalculateTotalWinHeight(), l:popup_opts_dict['maxheight'])


    " Verify the following concerning the 'model_info_dict' entry returned within the dictionary held by variable
    " 'g:llmchat_test_bypass_mode':
    "
    "   1). An entry exists inside the model information dictionary with name 'model list'.
    "
    "   2). The content of the 'model list' matches to a sorted list of model information dictionaries that hold all
    "       data found within the test response JSON file.
    "
    let l:model_info_dict = g:llmchat_test_bypass_mode["model_info_dict"]
    AssertTxt(has_key(l:model_info_dict, "model list"),
            \ "Expected to find a 'model list' entry within the model information dictionary amended by function " ..
            \ "ProcessModelListingResponse() but no such entry was located.")

    let l:actual_model_list = l:model_info_dict['model list']

    let l:expected_model_list = [
                              \   {
                              \     "model id": "nous-hermes2:10.7b",
                              \     "model display": "nous-hermes2:10.7b",
                              \     "details":
                              \     {
                              \       "id":"nous-hermes2:10.7b",
                              \       "name":"nous-hermes2:10.7b",
                              \       "object":"model",
                              \       "created":1770927090,
                              \       "owned_by":"ollama",
                              \       "ollama":
                              \       {
                              \         "name":"nous-hermes2:10.7b",
                              \         "model":"nous-hermes2:10.7b",
                              \         "modified_at":"2025-11-14T09:21:09.08187336-06:00",
                              \         "size":6072407285,
                              \         "digest":"d50977d0b36ae5779167f2d376da80b512886a0789e5f7e122cdb6f85fc86f85",
                              \         "details":
                              \         {
                              \           "parent_model":"",
                              \           "format":"gguf",
                              \           "family":"llama",
                              \           "families": [ "llama" ],
                              \           "parameter_size":"11B",
                              \          "quantization_level":"Q4_0"
                              \         },
                              \         "connection_type":"local",
                              \         "urls": [ 0 ]
                              \       },
                              \       "connection_type":"local",
                              \       "tags": [ ],
                              \       "actions": [ ],
                              \       "filters": [ ]
                              \     }
                              \   },
                              \   {
                              \     "model id": "qwen2-math:1.5b",
                              \     "model display": "qwen2-math:1.5b",
                              \     "details":
                              \     {
                              \       "id":"qwen2-math:1.5b",
                              \       "name":"qwen2-math:1.5b",
                              \       "object":"model",
                              \       "created":1770927090,
                              \       "owned_by":"ollama",
                              \       "ollama":
                              \       {
                              \         "name":"qwen2-math:1.5b",
                              \         "model":"qwen2-math:1.5b",
                              \         "modified_at":"2025-11-14T09:16:48.32929219-06:00",
                              \         "size":934964386,
                              \         "digest":"a4fdda0c6cc5d11e7d865ffc124a7dbbe3daa3d8304e6677027da9baf457a032",
                              \         "details":
                              \         {
                              \           "parent_model":"",
                              \           "format":"gguf",
                              \           "family":"qwen2",
                              \           "families": [ "qwen2" ],
                              \           "parameter_size":"1.5B",
                              \           "quantization_level":"Q4_0"
                              \         },
                              \         "connection_type":"local",
                              \         "urls": [ 0 ]
                              \       },
                              \       "connection_type":"local",
                              \       "tags": [ ],
                              \       "actions": [ ],
                              \       "filters": [ ]
                              \     }
                              \   }
                              \ ]

    call s:testutil.AssertEqualLists(expand('<sflnum>') - 9, '', l:expected_model_list, l:actual_model_list)


    " Cleanup - Perform the following actions after the execution of this test:
    "
    "   1). Unset the 'g:llmchat_test_bypass_mode' variable as we no longer need to force testing bypasses.
    "
    unlet g:llmchat_test_bypass_mode

endfunction


" This test asserts the proper operation of function ProcessModelListingResponse() when it is invoked to handle an
" empty model listing response.
function! s:TestProcessModelListingResponseWithEmptyResponse()
    " Set the 'g:llmchat_test_bypass_mode' variable to hold an empty dictionary.  This will do a number of things
    " including (1) disengaging code invocations that go beyond the function so we can keep the test more focused, (2)
    " disable any popup dialogs that would otherwise be created, and (3) allow information from the function
    " execution to be returned back to this test later for verification.
    let g:llmchat_test_bypass_mode = { }


    " Request a temporary file from Vim and then output an empty JSON document to the file; this will serve as our
    " test server model listing response later.
    let l:test_response_file = tempname()
    call writefile([ "{\"models\":[]}" ], l:test_response_file)


    " Setup a test "model listing dictionary" that contains all information related to the model listing request that
    " would have been passed down from the first part of the model listing workflow.
    "
    " NOTE: For this test we will simulate the following conditions through the dictionary:
    "
    "   1). The cURL call will appear to have exited successfully (i.e., an exit status of 0).
    "   2). The HTTP status code will be listed as 200 indicating a successful response to the request.
    "
    let l:test_listing_dict = {
                            \   "register name": "a",
                            \   "http response code": "200",
                            \   "exit status": 0,
                            \   "server type": "Ollama",
                            \   "response payload file": l:test_response_file
                            \ }


    " Invoke function ProcessModelListingResponse() and pass to it the test model listing dictionary created earlier.
    " Note that since the 'g:llmchat_test_bypass_mode' variable was set the execution will stop short of showing the
    " model listing popup dialog and will instead add the following entries to the dictionary held by
    " 'g:llmchat_test_bypass_mode':
    "
    "   'popup_options' --> The dictionary containing all options that *would* have been passed to the popup window.
    "   'model_info_dict' --> The revised model information dictionary that was originally given to the function
    "                         invocation.
    "
    " Later we will perform verifications on the information found in both of these entries.
    call LLMChat#get_models#ProcessModelListingResponse(l:test_listing_dict)


    " Verify that the file pointed to by variable 'l:test_response_file' no longer exists on the system; this shows
    " that the execution of ProcessModelListingResponse() properly removed such file as part of its cleanup.
    AssertTxt(filereadable(l:test_response_file) != 1,
            \ "Expected to find the response file removed from disk at the completion of function " ..
            \ "ProcessModelListingResponse() but the file still appeared to exist.")


    " Now verify the following concerning the 'popup_options' entry added to the dictionary held by variable
    " 'g:llmchat_test_bypass_mode':
    "
    "   1). A 'filter' entry was defined which has an expected value.
    "   2). A 'callback' entry was defined which has an expected value.
    "   3). A 'maxheight' entry was defined whose value is equal to the value returned by function
    "       CalculateTotalWinHeight() from the 'import/utils.vim' script.
    "
    let l:popup_opts_dict = g:llmchat_test_bypass_mode['popup_options']
    AssertTxt(has_key(l:popup_opts_dict, "filter"),
            \ "Expected to find a 'filter' entry within the popup options dictionary created by function " ..
            \ "ProcessModelListingResponse() but no such entry was located.")
    AssertEquals("LLMChat#get_models#HandleModelSelectionKeyPress", l:popup_opts_dict['filter'])

    AssertTxt(has_key(l:popup_opts_dict, "callback"),
            \ "Expected to find a 'callback' entry within the popup options dictionary created by function " ..
            \ "ProcessModelListingResponse() but no such entry was located.")
    AssertEquals("LLMChat#get_models#HandleModelSelection", l:popup_opts_dict['callback'])

    AssertTxt(has_key(l:popup_opts_dict, "maxheight"),
            \ "Expected to find a 'maxheight' entry within the popup options dictionary created by function " ..
            \ "ProcessModelListingResponse() but no such entry was located.")
    AssertEquals(s:util.CalculateTotalWinHeight(), l:popup_opts_dict['maxheight'])


    " Verify the following concerning the 'model_info_dict' entry returned within the dictionary held by variable
    " 'g:llmchat_test_bypass_mode':
    "
    "   1). An entry exists inside the model information dictionary with name 'model list'.
    "
    "   2). The content of the 'model list' matches to a sorted list of model information dictionaries that hold all
    "       data found within the test response JSON file.
    "
    let l:model_info_dict = g:llmchat_test_bypass_mode["model_info_dict"]
    AssertTxt(has_key(l:model_info_dict, "model list"),
            \ "Expected to find a 'model list' entry within the model information dictionary amended by function " ..
            \ "ProcessModelListingResponse() but no such entry was located.")

    let l:actual_model_list = l:model_info_dict['model list']

    AssertTxt(empty(l:actual_model_list),
            \ "Expected to find an empty model list returned back but instead found the following list returned: " ..
            \ string(l:actual_model_list))


    " Cleanup - Perform the following actions after the execution of this test:
    "
    "   1). Unset the 'g:llmchat_test_bypass_mode' variable as we no longer need to force testing bypasses.
    "
    unlet g:llmchat_test_bypass_mode

endfunction


" This test asserts the proper operation of function ProcessModelListingResponse() when invoked after debug mode has
" been enabled.
function! s:TestProcessModelListingResponseWithDebugMode()
    " Set the 'g:llmchat_test_bypass_mode' variable to hold an empty dictionary.  This will do a number of things
    " including (1) disengaging code invocations that go beyond the function so we can keep the test more focused, (2)
    " disable any popup dialogs that would otherwise be created, and (3) allow information from the function
    " execution to be returned back to this test later for verification.
    let g:llmchat_test_bypass_mode = { }


    " Request a temporary file from Vim and then output some testing content to it.  This file will serve as the
    " "headers" file that function ProcessModelListingResponse() will assume that response header data was dumped to
    " by curl.  Note that since this file isn't parsed or processed (only added to the debug output) the content we
    " write to it is immaterial.  We DO, however, need to make sure that the file exists so that it can be read by
    " the debug content generation later on.
    let l:header_data_file = tempname()
    call writefile([ "<Header Data>" ], l:header_data_file)


    " Request another temporary file from Vim and set this as the "debug" target to use during test execution.
    " Essentially this will become the output destination for all debug writes generated later in the test.
    let g:llmchat_debug_mode_target = tempname()


    " Build out the path to a test "response" file that will be utilized later to emulate an Ollama server model
    " listing response.  Note that the data directory path for the file will come from a testing utility intended to
    " help test code remain agnostic of details like the file separator in use on the current OS.
    let l:test_data_dir = s:testutil.GetTestDataDir("TestProcessModelListingResponseWithDebugMode", 1)
    let l:test_response_file = l:test_data_dir .. "response.json"


    " Request a temporary file from Vim and then copy the full content of the 'l:test_response_file' into the temporary
    " file location.  We do this because in the course of proper operation the response file will be removed by the
    " ProcessModelListingResponse() function and we don't want to delete our test data file.
    let l:temp_response_file = tempname()
    call filecopy(l:test_response_file, l:temp_response_file)


    " Setup a test "model listing dictionary" that contains all information related to the model listing request that
    " would have been passed down from the first part of the model listing workflow.
    "
    " NOTE: For this test we will simulate the following conditions through the dictionary:
    "
    "   1). The cURL call will appear to have exited successfully (i.e., an exit status of 0).
    "   2). The HTTP status code will be listed as 200 indicating a successful response to the request.
    "
    let l:test_listing_dict = {
                            \   "register name": "a",
                            \   "http response code": "200",
                            \   "exit status": 0,
                            \   "server type": "Ollama",
                            \   "response payload file": l:temp_response_file,
                            \   "response headers file": l:header_data_file
                            \ }


    " Invoke function ProcessModelListingResponse() and pass to it the test model listing dictionary created earlier.
    " Note that since the 'g:llmchat_test_bypass_mode' variable was set the execution will stop short of showing the
    " model listing popup dialog and will instead add the following entries to the dictionary held by
    " 'g:llmchat_test_bypass_mode':
    "
    "   'popup_options' --> The dictionary containing all options that *would* have been passed to the popup window.
    "   'model_info_dict' --> The revised model information dictionary that was originally given to the function
    "                         invocation.
    "
    " Later we will perform verifications on the information found in both of these entries.
    call LLMChat#get_models#ProcessModelListingResponse(l:test_listing_dict)


    " Verify that the file pointed to by variable 'l:temp_response_file' no longer exists on the system; this shows
    " that the execution of ProcessModelListingResponse() properly removed such file as part of its cleanup.
    AssertTxt(filereadable(l:temp_response_file) != 1,
            \ "Expected to find the response file removed from disk at the completion of function " ..
            \ "ProcessModelListingResponse() but the file still appeared to exist.")


    " Verify that the "header data" file (which would have been created by curl when debug mode is enabled) has also
    " been removed from the system.  The content of this file should have been integrated into the debug writes by the
    " time the ProcessModelListingResponse() function completes execution so there is no reason for the file to remain
    " on disk.
    AssertTxt(filereadable(l:header_data_file) != 1,
            \ "Expected to find the response header data file removed from disk at the completion of function " ..
            \ "ProcessModelListingResponse() but the file still appeared to exist.")


    " Now verify the following concerning the 'popup_options' entry added to the dictionary held by variable
    " 'g:llmchat_test_bypass_mode':
    "
    "   1). A 'filter' entry was defined which has an expected value.
    "   2). A 'callback' entry was defined which has an expected value.
    "   3). A 'maxheight' entry was defined whose value is equal to the value returned by function
    "       CalculateTotalWinHeight() from the 'import/utils.vim' script.
    "
    let l:popup_opts_dict = g:llmchat_test_bypass_mode['popup_options']
    AssertTxt(has_key(l:popup_opts_dict, "filter"),
            \ "Expected to find a 'filter' entry within the popup options dictionary created by function " ..
            \ "ProcessModelListingResponse() but no such entry was located.")
    AssertEquals("LLMChat#get_models#HandleModelSelectionKeyPress", l:popup_opts_dict['filter'])

    AssertTxt(has_key(l:popup_opts_dict, "callback"),
            \ "Expected to find a 'callback' entry within the popup options dictionary created by function " ..
            \ "ProcessModelListingResponse() but no such entry was located.")
    AssertEquals("LLMChat#get_models#HandleModelSelection", l:popup_opts_dict['callback'])

    AssertTxt(has_key(l:popup_opts_dict, "maxheight"),
            \ "Expected to find a 'maxheight' entry within the popup options dictionary created by function " ..
            \ "ProcessModelListingResponse() but no such entry was located.")
    AssertEquals(s:util.CalculateTotalWinHeight(), l:popup_opts_dict['maxheight'])


    " Verify the following concerning the 'model_info_dict' entry returned within the dictionary held by variable
    " 'g:llmchat_test_bypass_mode':
    "
    "   1). An entry exists inside the model information dictionary with name 'model list'.
    "
    "   2). The content of the 'model list' matches to a sorted list of model information dictionaries that hold all
    "       data found within the test response JSON file.
    "
    let l:model_info_dict = g:llmchat_test_bypass_mode["model_info_dict"]
    AssertTxt(has_key(l:model_info_dict, "model list"),
            \ "Expected to find a 'model list' entry within the model information dictionary amended by function " ..
            \ "ProcessModelListingResponse() but no such entry was located.")

    let l:actual_model_list = l:model_info_dict['model list']

    let l:expected_model_list = [
                              \   {
                              \     "model id": "nous-hermes2:34b",
                              \     "model display": "nous-hermes2:34b",
                              \     "details":
                              \     {
                              \       "name":"nous-hermes2:34b",
                              \       "model":"nous-hermes2:34b",
                              \       "modified_at":"2025-11-14T09:21:09.614882696-06:00",
                              \       "size":19466541333,
                              \       "digest":"1fbb49caabbd2d36b7132848ddf7dcd7f2fb9b58df9838850f2c4160b9fe7ba4",
                              \       "details":
                              \       {
                              \         "parent_model":"",
                              \         "format":"gguf",
                              \         "family":"llama",
                              \         "families": [ "llama" ],
                              \         "parameter_size":"34B",
                              \         "quantization_level":"Q4_0"
                              \       }
                              \     }
                              \   },
                              \   {
                              \     "model id": "qwq:32b",
                              \     "model display": "qwq:32b",
                              \     "details":
                              \     {
                              \       "name":"qwq:32b",
                              \       "model":"qwq:32b",
                              \       "modified_at":"2025-11-14T09:17:30.481079257-06:00",
                              \       "size":19851349657,
                              \       "digest":"009cb3f08d74437380f3b84194c1bd34f1cc3d95a2bb87241d89387fc22a9ddf",
                              \       "details":
                              \       {
                              \         "parent_model":"",
                              \         "format":"gguf",
                              \         "family":"qwen2",
                              \         "families": [ "qwen2" ],
                              \         "parameter_size":"32.8B",
                              \         "quantization_level":"Q4_K_M"
                              \       }
                              \     }
                              \   }
                              \ ]

    call s:testutil.AssertEqualLists(expand('<sflnum>') - 9, '', l:expected_model_list, l:actual_model_list)


    " Verify the following concerning the "debug" output we expect to see generated:
    "
    "   1). The debug file whose name and path are held by variable 'g:llmchat_debug_mode_target' exists on disk.
    "   2). The debug file content is NOT empty.
    "   3). We can find the line we wrote to the header file somewhere in the debug output (this shows that the
    "       response header data was properly reported through the debug writes).
    "
    AssertTxt(filereadable(g:llmchat_debug_mode_target),
            \ "Expected to find the file whose path was set as the debug target at the beginning of the test on the " ..
            \ "local filesystem; however, no such file could be found")

    let l:debug_file_lines = readfile(g:llmchat_debug_mode_target)

    AssertTxt(len(l:debug_file_lines) > 0,
                \ "Expected to see content written to the debug target file by the end of testing but found no " ..
                \ "content resided within such file.")

    let l:header_line_found = 0
    for l:curr_debug_line in l:debug_file_lines
        if l:curr_debug_line =~# '\v.*\<Header Data\>.*'
            " In this case we found the header line in the debug output so (1) set variable 'l:header_line_found' to
            " 1 (true) and then (2) break out of the loop.
            let l:header_line_found = 1
            break
        endif
    endfor

    AssertTxt(l:header_line_found == 1,
            \ "Expected to find the information written to the test response header file within the debug content " ..
            \ "read from the debug target file; however, no such data was located.")


    " Cleanup - Perform the following actions after the execution of this test:
    "
    "   1). Unset the 'g:llmchat_test_bypass_mode' variable as we no longer need to force testing bypasses.
    "
    "   2). Remove the debug target file from the system as this is no longer needed.
    "
    "   3). Unset the 'g:llmchat_debug_mode_target' variable so that debug mode is disabled before the test exits.
    "
    unlet g:llmchat_test_bypass_mode
    call delete(g:llmchat_debug_mode_target)
    unlet g:llmchat_debug_mode_target

endfunction


" This test asserts that a known exception is thrown from function ProcessModelListingResponse() when it detects that
" the curl call used to submit the remote request exited abnormally.
function! s:TestProcessModelListingResponseWithFailedCurlExecution()
    " Set the 'g:llmchat_test_bypass_mode' variable so that (1) exceptions are properly surfaced for testing by
    " re-throwing them and (2) echo messages requiring acknowledgment are silenced.  Note that in this case that the
    " value assigned to 'g:llmchat_test_bypass_mode' is arbitrary so we will use 1 (i.e., 'true') by general
    " convention.
    let g:llmchat_test_bypass_mode = 1


    " Request a temporary file name and path from Vim and then write an empty JSON document to it; this will serve
    " as the test analog for the response data file returned from the remote LLM server.
    let l:test_response_file = tempname()
    call writefile([ "{\"models\":[]}" ], l:test_response_file)


    " Setup a "model listing dictionary" that will indicate that the curl execution returned a non-zero exit status.
    let l:test_listing_dict = {
                            \   "register name": "a",
                            \   "http response code": "200",
                            \   "exit status": 1,
                            \   "server type": "Ollama",
                            \   "response payload file": l:test_response_file
                            \ }

    try
        " Attempt to invoke function ProcessModelListingResponse() with the test model listing dictionary; this should
        " prompt an exception to be thrown when the logic finds that the exit status reported is NOT 0.
        call LLMChat#get_models#ProcessModelListingResponse(l:test_listing_dict)


        " If the logic reaches this point than fail the test; an exception should have already been thrown if the logic
        " was working properly that would make this code unreachable.
        call s:testutil.Fail(expand('<sflnum>') - 9,
                           \ "Expected to see an exception thrown from function ProcessModelListingResponse() when " ..
                           \ "the model listing info dictionary given to it held an entry indicating that the " ..
                           \ "previously executed curl call exited abnormally; however, no exception occurred.")

    catch /\c[error].*curl call.*non-zero exit status.*/
        " If the logic comes here than we have caught an exception whose message matches the message we were looking
        " for; allow the test to proceed forward as this is what we expect to see happen if the logic is working
        " correctly.
    endtry


    " Perform the following cleanup actions after the execution of this test:
    "
    "   1). Remove the 'l:test_response_file' from the system as we're now done with it.
    "
    "   2). Unset the 'g:llmchat_test_bypass_mode' as the test is complete and we should not leave by-pass mode in
    "       effect.
    "
    call delete(l:test_response_file)
    unlet g:llmchat_test_bypass_mode

endfunction


" This test asserts that a known exception is thrown from function ProcessModelListingResponse() when it detects that
" an unexpected HTTP response status was returned for the model listing request.
function! s:TestProcessModelListingResponseWithUnsuccessfulHTTPStatus()
    " Set the 'g:llmchat_test_bypass_mode' variable so that (1) exceptions are properly surfaced for testing by
    " re-throwing them and (2) echo messages requiring acknowledgment are silenced.  Note that in this case that the
    " value assigned to 'g:llmchat_test_bypass_mode' is arbitrary so we will use 1 (i.e., 'true') by general
    " convention.
    let g:llmchat_test_bypass_mode = 1


    " Request a temporary file name and path from Vim and then write an empty JSON document to it; this will serve
    " as the test analog for the response data file returned from the remote LLM server.
    let l:test_response_file = tempname()
    call writefile([ "{\"models\":[]}" ], l:test_response_file)


    " Setup a "model listing dictionary" that will indicate that the HTTP request was not successful.
    let l:test_listing_dict = {
                            \   "register name": "a",
                            \   "http response code": 401,
                            \   "exit status": 0,
                            \   "server type": "Ollama",
                            \   "response payload file": l:test_response_file
                            \ }

    try
        " Attempt to invoke function ProcessModelListingResponse() with the test model listing dictionary; this should
        " prompt an exception to be thrown when the logic finds that the HTTP response status reported is not 200.
        call LLMChat#get_models#ProcessModelListingResponse(l:test_listing_dict)


        " If the logic reaches this point than fail the test; an exception should already have been thrown if the logic
        " was working properly making this code unreachable.
        call s:testutil.Fail(expand('<sflnum>') - 9,
                           \ "Expected to see an exception thrown from function ProcessModelListingResponse() when " ..
                           \ "the model listing info dictionary given to it held an entry indicating that the HTTP " ..
                           \ "request was not successful; however, no exception occurred.")

    catch /\c[error].*http status code.*not equal to 200.*/
        " If the logic comes here than we have caught an exception whose message matches the message we were looking
        " for; allow the test to proceed forward as this is what we expect to see happen if the logic is working
        " correctly.
    endtry


    " Perform the following cleanup actions after the execution of this test:
    "
    "   1). Remove the 'l:test_response_file' from the system as we're now done with it.
    "
    "   2). Unset the 'g:llmchat_test_bypass_mode' as the test is complete and we should not leave by-pass mode in
    "       effect.
    "
    call delete(l:test_response_file)
    unlet g:llmchat_test_bypass_mode

endfunction



" ******************************************************
" ****  ProcessOllamaModelListing() Function Tests  ****
" ******************************************************

" This test asserts the proper operation of function ProcessOllamaModelListing() when it is invoked to process an
" Ollama response that contains a single model information listing.
function! s:TestProcessOllamaModelListingWithSingleEntry()
    " Build out the path to a test "response" file that will be utilized later to emulate an Ollama server model
    " listing response.  Note that the data directory path for the file will come from a testing utility intended to
    " help test code remain agnostic of details like the file separator in use on the current OS.
    let l:test_data_dir = s:testutil.GetTestDataDir("TestProcessOllamaModelListingWithSingleEntry", 1)
    let l:test_response_file = l:test_data_dir .. "response.json"


    " Invoke the ProcessOllamaModelListing() function to parse and process the content found in the
    " 'l:test_response_file' and then store the list it returns in a variable for later verification.
    let l:actual_model_list = LLMChat#get_models#ProcessOllamaModelListing(l:test_response_file)


    " Assert that the content of the 'l:actual_model_list' matches exactly to an "expected" list of models known to the
    " test.
    let l:expected_model_list = [
                              \   {
                              \     "model id": "nous-hermes2:10.7b",
                              \     "model display": "nous-hermes2:10.7b",
                              \     "details":
                              \     {
                              \       "name":"nous-hermes2:10.7b",
                              \       "model":"nous-hermes2:10.7b",
                              \       "modified_at":"2025-11-14T09:21:09.08187336-06:00",
                              \       "size":6072407285,
                              \       "digest":"d50977d0b36ae5779167f2d376da80b512886a0789e5f7e122cdb6f85fc86f85",
                              \       "details":
                              \       {
                              \         "parent_model":"",
                              \         "format":"gguf",
                              \         "family":"llama",
                              \         "families": [ "llama" ],
                              \         "parameter_size":"11B",
                              \         "quantization_level":"Q4_0"
                              \       }
                              \     }
                              \   }
                              \ ]

    call s:testutil.AssertEqualLists(expand('<sflnum>') - 9, '', l:expected_model_list, l:actual_model_list)

endfunction


" This test asserts the proper operation of function ProcessOllamaModelListing() when it is invoked to process an
" Ollama response that contains multiple model definitions in the information listing.
function! s:TestProcessOllamaModelListingWithMultipleEntries()
    " Build out the path to a test "response" file that will be utilized later to emulate an Ollama server model
    " listing response.  Note that the data directory path for the file will come from a testing utility intended to
    " help test code remain agnostic of details like the file separator in use on the current OS.
    let l:test_data_dir = s:testutil.GetTestDataDir("TestProcessOllamaModelListingWithMultipleEntries", 1)
    let l:test_response_file = l:test_data_dir .. "response.json"


    " Invoke the ProcessOllamaModelListing() function to parse and process the content found in the
    " 'l:test_response_file' and then store the list it returns in a variable for later verification.
    let l:actual_model_list = LLMChat#get_models#ProcessOllamaModelListing(l:test_response_file)


    " Assert that the content of the 'l:actual_model_list' matches exactly to an "expected" list of models known to the
    " test.
    let l:expected_model_list = [
                              \   {
                              \     "model id": "nous-hermes2:10.7b",
                              \     "model display": "nous-hermes2:10.7b",
                              \     "details":
                              \     {
                              \       "name":"nous-hermes2:10.7b",
                              \       "model":"nous-hermes2:10.7b",
                              \       "modified_at":"2025-11-14T09:21:09.08187336-06:00",
                              \       "size":6072407285,
                              \       "digest":"d50977d0b36ae5779167f2d376da80b512886a0789e5f7e122cdb6f85fc86f85",
                              \       "details":
                              \       {
                              \         "parent_model":"",
                              \         "format":"gguf",
                              \         "family":"llama",
                              \         "families": [ "llama" ],
                              \         "parameter_size":"11B",
                              \         "quantization_level":"Q4_0"
                              \       }
                              \     }
                              \   },
                              \   {
                              \     "model id": "starcoder2:3b",
                              \     "model display": "starcoder2:3b",
                              \     "details":
                              \     {
                              \       "name":"starcoder2:3b",
                              \       "model":"starcoder2:3b",
                              \       "modified_at":"2025-11-14T09:19:41.401342643-06:00",
                              \       "size":1709901728,
                              \       "digest":"9f4ae0aff61ee24fe4b7d9714c9382b5172551fa8e95aa064452ec2e62610835",
                              \       "details":
                              \       {
                              \         "parent_model":"",
                              \         "format":"gguf",
                              \         "family":"starcoder2",
                              \         "families": [ "starcoder2" ],
                              \         "parameter_size":"3B",
                              \         "quantization_level":"Q4_0"
                              \       }
                              \     }
                              \   },
                              \   {
                              \     "model id": "qwen3-coder:30b",
                              \     "model display": "qwen3-coder:30b",
                              \     "details":
                              \     {
                              \       "name":"qwen3-coder:30b",
                              \       "model":"qwen3-coder:30b",
                              \       "modified_at":"2025-11-14T09:16:17.073824237-06:00",
                              \       "size":18556701140,
                              \       "digest":"ad67f85ca2502e92936ef793bf29a312e1912ecd1e2c09c9c2963adf1debde78",
                              \       "details":
                              \       {
                              \         "parent_model":"",
                              \         "format":"gguf",
                              \         "family":"qwen3moe",
                              \         "families": [ "qwen3moe" ],
                              \         "parameter_size":"30.5B",
                              \         "quantization_level":"Q4_K_M"
                              \       }
                              \     }
                              \   }
                              \ ]

    call s:testutil.AssertEqualLists(expand('<sflnum>') - 9, '', l:expected_model_list, l:actual_model_list)

endfunction


" This test asserts the proper operation of function ProcessOllamaModelListing() when it is invoked to process an
" Ollama response that contains NO model definitions in the information listing.
function! s:TestProcessOllamaModelListingWithNoEntries()
    " Request a temporary file from Vim and then write an empty model listing JSON to the file.
    let l:test_response_file = tempname()
    call writefile([ "{\"models\":[ ]}" ], l:test_response_file)


    " Invoke the ProcessOllamaModelListing() function to parse and process the content found in the
    " 'l:test_response_file' and then store the list it returns in a variable for later verification.
    let l:actual_model_list = LLMChat#get_models#ProcessOllamaModelListing(l:test_response_file)


    " Assert that the 'l:actual_model_list' is empty.
    AssertTxt(empty(l:actual_model_list),
            \ "Expected to see an empty model list returned from function ProcessOllamaModelListing() but insread " ..
            \ "was returned the list: " .. string(l:actual_model_list))

endfunction



" *********************************************************
" ****  ProcessOpenWebUIModelListing() Function Tests  ****
" *********************************************************

" This test asserts the proper operation of function ProcessOpenWebUIModelListing() when is is invoked to process a
" model listing response containing a single model entry.
function! s:TestProcessOpenWebUIModelListingWithSingleEntry()
    " Build out the path to a test "response" file that will be utilized later to emulate an Open WebUI server model
    " listing response.  Note that the data directory path for the file will come from a testing utility intended to
    " help test code remain agnostic of details like the file separator in use on the current OS.
    let l:test_data_dir = s:testutil.GetTestDataDir("TestProcessOpenWebUIModelListingWithSingleEntry", 1)
    let l:test_response_file = l:test_data_dir .. "response.json"


    " Invoke the ProcessOpenWebUIModelListing() function to parse and process the content found in the
    " 'l:test_response_file' and then store the list it returns in a variable for later verification.
    let l:actual_model_list = LLMChat#get_models#ProcessOpenWebUIModelListing(l:test_response_file)


    " Assert that the content of the 'l:actual_model_list' matches exactly to an "expected" list of models known to the
    " test.
    let l:expected_model_list = [
                              \   {
                              \     "model id": "starcoder2:15b",
                              \     "model display": "starcoder2:15b",
                              \     "details":
                              \     {
                              \       "id":"starcoder2:15b",
                              \       "name":"starcoder2:15b",
                              \       "object":"model",
                              \       "created":1770927090,
                              \       "owned_by":"ollama",
                              \       "ollama":
                              \       {
                              \         "name":"starcoder2:15b",
                              \         "model":"starcoder2:15b",
                              \         "modified_at":"2025-11-14T09:19:41.134337998-06:00",
                              \         "size":9065413313,
                              \         "digest":"21ae152d49e026b721a52cda94b32f95b3c9719d5eb71ea670e4fa60efde276b",
                              \         "details":
                              \         {
                              \           "parent_model":"",
                              \           "format":"gguf",
                              \           "family":"starcoder2",
                              \           "families": [ "starcoder2" ],
                              \           "parameter_size":"16B",
                              \           "quantization_level":"Q4_0"
                              \         },
                              \         "connection_type":"local",
                              \         "urls": [ 0 ]
                              \       },
                              \       "connection_type":"local",
                              \       "tags": [ ],
                              \       "actions": [ ],
                              \       "filters": [ ]
                              \     }
                              \   }
                              \ ]

    call s:testutil.AssertEqualLists(expand('<sflnum>') - 9, '', l:expected_model_list, l:actual_model_list)

endfunction


" This test asserts the proper operation of function ProcessOpenWebUIModelListing() when it is invoked to process a
" model listing response containing multiple entries.
function! s:TestProcessOpenWebUIModelListingWithMultileEntries()
    " Build out the path to a test "response" file that will be utilized later to emulate an Open WebUI server model
    " listing response.  Note that the data directory path for the file will come from a testing utility intended to
    " help test code remain agnostic of details like the file separator in use on the current OS.
    let l:test_data_dir = s:testutil.GetTestDataDir("TestProcessOpenWebUIModelListingWithMultileEntries", 1)
    let l:test_response_file = l:test_data_dir .. "response.json"


    " Invoke the ProcessOpenWebUIModelListing() function to parse and process the content found in the
    " 'l:test_response_file' and then store the list it returns in a variable for later verification.
    let l:actual_model_list = LLMChat#get_models#ProcessOpenWebUIModelListing(l:test_response_file)


    " Assert that the content of the 'l:actual_model_list' matches exactly to an "expected" list of models known to the
    " test.
    let l:expected_model_list = [
                              \   {
                              \     "model id": "nous-hermes2:34b",
                              \     "model display": "nous-hermes2:34b",
                              \     "details":
                              \     {
                              \       "id":"nous-hermes2:34b",
                              \       "name":"nous-hermes2:34b",
                              \       "object":"model",
                              \       "created":1770927090,
                              \       "owned_by":"ollama",
                              \       "ollama":
                              \       {
                              \         "name":"nous-hermes2:34b",
                              \         "model":"nous-hermes2:34b",
                              \         "modified_at":"2025-11-14T09:21:09.614882696-06:00",
                              \         "size":19466541333,
                              \         "digest":"1fbb49caabbd2d36b7132848ddf7dcd7f2fb9b58df9838850f2c4160b9fe7ba4",
                              \         "details":
                              \         {
                              \           "parent_model":"",
                              \           "format":"gguf",
                              \           "family":"llama",
                              \           "families": [ "llama" ],
                              \           "parameter_size":"34B",
                              \           "quantization_level":"Q4_0"
                              \         },
                              \         "connection_type":"local",
                              \         "urls": [ 0 ]
                              \       },
                              \       "connection_type":"local",
                              \       "tags":[ ],
                              \       "actions": [ ],
                              \       "filters":[ ]
                              \     }
                              \   },
                              \   {
                              \     "model id": "starcoder2:15b",
                              \     "model display": "starcoder2:15b",
                              \     "details":
                              \     {
                              \       "id":"starcoder2:15b",
                              \       "name":"starcoder2:15b",
                              \       "object":"model",
                              \       "created":1770927090,
                              \       "owned_by":"ollama",
                              \       "ollama":
                              \       {
                              \         "name":"starcoder2:15b",
                              \         "model":"starcoder2:15b",
                              \         "modified_at":"2025-11-14T09:19:41.134337998-06:00",
                              \         "size":9065413313,
                              \         "digest":"21ae152d49e026b721a52cda94b32f95b3c9719d5eb71ea670e4fa60efde276b",
                              \         "details":
                              \         {
                              \           "parent_model":"",
                              \           "format":"gguf",
                              \           "family":"starcoder2",
                              \           "families": [ "starcoder2" ],
                              \           "parameter_size":"16B",
                              \           "quantization_level":"Q4_0"
                              \         },
                              \         "connection_type":"local",
                              \         "urls": [ 0 ]
                              \       },
                              \       "connection_type":"local",
                              \       "tags": [ ],
                              \       "actions": [ ],
                              \       "filters": [ ]
                              \     }
                              \   },
                              \   {
                              \     "model id": "qwen3-coder:30b",
                              \     "model display": "qwen3-coder:30b",
                              \     "details":
                              \     {
                              \       "id":"qwen3-coder:30b",
                              \       "name":"qwen3-coder:30b",
                              \       "object":"model",
                              \       "created":1770927090,
                              \       "owned_by":"ollama",
                              \       "ollama":
                              \       {
                              \         "name":"qwen3-coder:30b",
                              \         "model":"qwen3-coder:30b",
                              \         "modified_at":"2025-11-14T09:16:17.073824237-06:00",
                              \         "size":18556701140,
                              \         "digest":"ad67f85ca2502e92936ef793bf29a312e1912ecd1e2c09c9c2963adf1debde78",
                              \         "details":
                              \         {
                              \           "parent_model":"",
                              \           "format":"gguf",
                              \           "family":"qwen3moe",
                              \           "families": [ "qwen3moe" ],
                              \           "parameter_size":"30.5B",
                              \           "quantization_level":"Q4_K_M"
                              \         },
                              \         "connection_type":"local",
                              \         "urls": [ 0 ]
                              \       },
                              \       "connection_type":"local",
                              \       "tags": [ ],
                              \       "actions": [ ],
                              \       "filters": [ ]
                              \     }
                              \   }
                              \ ]

    call s:testutil.AssertEqualLists(expand('<sflnum>') - 9, '', l:expected_model_list, l:actual_model_list)

endfunction


" This test asserts the proper operation of function ProcessOpenWebUIModelListing() when it is invoked to process a
" model listing response that is empty.
function! s:TestProcessOpenWebUIModelListingWithNoEntries()
    " Request a temporary file from Vim and then write an empty model listing JSON to the file.
    let l:test_response_file = tempname()
    call writefile([ "{\"data\":[ ]}" ], l:test_response_file)


    " Invoke the ProcessOpenWebUIModelListing() function to parse and process the content found in the
    " 'l:test_response_file' and then store the list it returns in a variable for later verification.
    let l:actual_model_list = LLMChat#get_models#ProcessOpenWebUIModelListing(l:test_response_file)


    " Assert that the 'l:actual_model_list' is empty.
    AssertTxt(empty(l:actual_model_list),
            \ "Expected to see an empty model list returned from function ProcessOpenWebUIModelListing() but " ..
            \ "instead was returned the list: " .. string(l:actual_model_list))

endfunction



" *************************************************
" ****  HandleModelSelection() Function Tests  ****
" *************************************************

" This test asserts the proper operation of function HandleModelSelection() when a 'result' argument whose value is
" 1 or greater was provided to it.
function! s:TestHandleModelSelectionWithActualSelectionID()
    " Backup the value held by register 'a' so we can restore it at the end of testing.
    let l:orig_reg_value = @a


    " Craft a model list dictionary that we can use for testing and then set this into the appropriate script member
    " via function SetModelListInfoDict().
    "
    " NOTE: Currently this test will create an "abbreviated" dictionary that only contains the fields we know we
    "       absolutely need.  This wastes less code setting up definitions we won't use but it also means that if the
    "       code changes to require more than we will need to update this dictionary accordingly.
    "
    let l:test_model_list_dict = {
                               \   "register name": "a",
                               \   "model list":
                               \   [
                               \     {
                               \       "model id": "Model A"
                               \     },
                               \     {
                               \       "model id": "Model B"
                               \     },
                               \     {
                               \       "model id": "Model C"
                               \     }
                               \   ]
                               \ }
    call LLMChat#get_models#SetModelListInfoDict(l:test_model_list_dict)


    " Invoke the HandleModelSelection() function using a 'result' ID that matches to the list position (i.e., the
    " 1-based way of counting the list models and NOT the 0-based index) for one of the "models" we created within the
    " l:test_model_list_dict dictionary earliery.  Note that the function only cares about the 'model id' field so this
    " is all we provided in our model definitions.
    "
    " NOTE: The 'id' argument is currently not used by the function for anything so we will simply pass this as the
    "       empty string.
    "
    call LLMChat#get_models#HandleModelSelection('', 2)


    " Validate that the value for register 'a' was changed to hold the ID of the selected model.
    AssertEquals('Model B', @a)


    " Cleanup - Take the following actions now that testing has completed to cleanup:
    "
    "   1). Set an empty model list dictionary via function SetModelListInfoDict().
    "
    "   2). Restore the original value back to register 'a'.
    "
    call LLMChat#get_models#SetModelListInfoDict({ })

    let @a = l:orig_reg_value

endfunction


" This test assets the proper operation of function HanldeModelSelection() when a 'result' argument whose value is
" less than 1 is provided to it.
function! s:TestHandleModelSelectionWithCancelledID()
    " Retrieve the value currently stored in the " register and cache this into a local variable; later in the test
    " we will simply assert that such value has not changed.
    let l:orig_register_value = @"


    " Invoke the HandleModelSelection() function with a value less than 1 and validate the following:
    "
    "   1). No adverse reaction occurs (i.e., no exception is thrown).
    "   2). No modification was made to the " register.
    "
    " NOTE: The 'id' argument to the function is not used so we will simply pass this as the empty string for now.
    "
    call LLMChat#get_models#HandleModelSelection('', -1)

    AssertEquals(l:orig_register_value, @")

endfunction



" *********************************************************
" ****  HandleModelSelectionKeyPress() Function Tests  ****
" *********************************************************

" This test asserts the proper operation of function HandleModelSelectionKeyPress() when the key press made was equal
" to '?' (i.e., display model details).
function! s:TestHandleModelSelectionKeyPressWithDetailsSelection()
    " Set variable 'g:llmchat_test_bypass_mode' to hold an empty dictionary.  This action will allow us to (1) bypass
    " the actual creation of a popup dialog when we invoke function HandleModelSelectionKeyPress() and (2) will provide
    " a means for us to retrieve back information about what the function *would* have used to create the popup so
    " we can verify it.
    let g:llmchat_test_bypass_mode = { }


    " Create a new, empty split for testing.  Note that when this command executes we will assume that focus is
    " shifted to the buffer automatically.
    "
    " NOTE: We are using a buffer to *emulate* a popup window; at least so far as to provide an analog that can give
    "       the cursor position when requested.  We do this because buffers are easier to work with from the script
    "       but in doing so we run some small risk of passing the test with an operation that works with buffers but
    "       which fails in popup windows.  In the future some more time should be invested here to see if we can get
    "       the test to properly work with a real popup that way testing is aligned to the actual usage of the
    "       function we're verifying.
    "
    " NOTE 2: For testing we expect the cursor position within this new buffer to be used as the "selection" index for
    "         the model that the HandleModelSelectionKeyPress() function will display a details dialog on.  Currently
    "         the expectation is that, with no content added, the cursor position will be reported on line 1 and will
    "         therefore be mapped to model index 0.
    "
    execute "new"


    " Obtain the window ID associated with the current buffer and store this into a local variable.  Later we will pass
    " this information to our invocation of function HandleModelSelectionKeyPress() so that it interacts with the
    " window showing the test buffer.
    let l:win_id = winnr()


    " Setup a test model information dict and then call function SetModelListInfoDict() to set this into the script
    " for use.  Note that the model dict we create will not be accurate for a real return since such accuracy is not
    " needed for this case; instead we will populate only those values we need to and we will try to use values that
    " will make testing verifications easier later.  The primary reason for taking these short cuts is to reduce the
    " amount of test code we need to maintain and to not indulge in detailed setup that isn't strictly needed (given
    " the concerns of the function being tested).
    let l:test_model_info_dict = {
                               \   "model list":
                               \   [
                               \     {
                               \       "model id": "model_a",
                               \       "model display": "Model A",
                               \       "details":
                               \       {
                               \         "name": "model_a",
                               \         "display": "Model A",
                               \         "tag": "a123",
                               \         "hosts": [ "localhost" ]
                               \       }
                               \     },
                               \     {
                               \       "model id": "model_b",
                               \       "model display": "Model B",
                               \       "details":
                               \       {
                               \         "name": "model_b",
                               \         "display": "Model B",
                               \         "tag": "b789",
                               \         "hosts": [ "foobar.com", "additionals.com" ]
                               \       }
                               \     }
                               \   ]
                               \ }

    call LLMChat#get_models#SetModelListInfoDict(l:test_model_info_dict)


    " Invoke the HandleModelSelectionKeyPress() function and pass it a 'key' argument of '?'; we expect this to trigger
    " the logical path within the function that would create and display a details dialog.  Note that since we have
    " set variable 'g:llmchat_test_bypass_mode' to hold an empty dictionary earlier in the test, the function execution
    " should be altered to (1) NOT show the details popup and (2) instead attach the following information to the
    " dictionary held by 'g:llmchat_test_bypass_mode':
    "
    "   "popup_options" - A dictionary of the options that would have been passed to the popup creation.
    "   "model_detail_desc" - The model detail information that would have been displayed inside the popup
    "
    " This behavior will allow us to validate the information that *would* have been used to create the popup window
    " rather than actually creating it.  Note that since we expect the key press we send to be handled by the function
    " call we will also assert that a value of 1 (true) gets returned.
    AssertEquals(1, LLMChat#get_models#HandleModelSelectionKeyPress(l:win_id, '?'))


    " Assert that the 'model_detail_desc' list, which should now be attached to the dictionary held by variable
    " 'g:llmchat_test_bypass_mode', matches to an expected list.
    let l:expected_detail_list = [
                               \   "\"display\": \"Model A\"",
                               \   "\"hosts\":",
                               \   "[",
                               \   "  \"localhost\"",
                               \   "]",
                               \   "\"name\": \"model_a\"",
                               \   "\"tag\": \"a123\""
                               \ ]

    call s:testutil.AssertEqualLists(expand('<sflnum>') - 9,
                                   \ '',
                                   \ l:expected_detail_list,
                                   \ g:llmchat_test_bypass_mode['model_detail_desc'])


    " Assert the following about the 'popup_options' dictionary that should now be added into the dictionary held
    " by variable 'g:llmchat_test_bypass_mode':
    "
    "   1). An entry exists for 'title' and the value of that entry matches to an expected value.
    "
    "   2). An entry exists for 'maxheight' and the value for that entry matches to the value returned by function
    "       CalculateTotalWinHeight().
    "
    "   3). An entry exists for 'minwidth' and the value for that entry matches to the length of the longest line
    "       found in the formatted model "detail" dictionary.
    "
    "   4). An entry exists for 'maxwidth' and the value for that entry matches to the length of the longest line
    "       found in the formated model "detail" dictionary.
    "
    let l:popup_opts_dict = g:llmchat_test_bypass_mode["popup_options"]

    AssertTxt(has_key(l:popup_opts_dict, 'title'),
            \ "Expected to find an entry with key 'title' within the popup options dictionary returned from the " ..
            \ "HandleModelSelectionKeyPress() function but no such entry was located.")
    AssertEquals(" Model 'Model A' Details ", l:popup_opts_dict['title'])

    AssertTxt(has_key(l:popup_opts_dict, 'maxheight'),
            \ "Expected to find an entry with key 'maxheight' within the popup options dictionary returned from the " ..
            \ "HandleModelSelectionKeyPress() function but no such entry was located.")
    AssertEquals(s:util.CalculateTotalWinHeight(), l:popup_opts_dict['maxheight'])

    AssertTxt(has_key(l:popup_opts_dict, 'minwidth'),
            \ "Expected to find an entry with key 'minwidth' within the popup options dictionary returned from the " ..
            \ "HandleModelSelectionKeyPress() function but no such entry was located.")
    AssertEquals(20, l:popup_opts_dict["minwidth"])

    AssertTxt(has_key(l:popup_opts_dict, 'maxwidth'),
            \ "Expected to find an entry with key 'maxwidth' within the popup options dictionary returned from the " ..
            \ "HandleModelSelectionKeyPress() function but no such entry was located.")
    AssertEquals(20, l:popup_opts_dict['maxwidth'])


    " Cleanup - Perform the following actions now that testing has completed:
    "
    "   1). Use function SetModelListInfoDict() to set an empty dictionary into the get_models.vim script and thereby
    "       clear out our test dictionary.
    "
    "   2). Forcibly remove the test buffer (this shouldn't have any contents but we'll use force just in case).
    "
    "   3) Unset the 'g:llmchat_test_bypass_mode' to turn off test bypass mode.
    "
    call LLMChat#get_models#SetModelListInfoDict({ })
    bd!
    unlet g:llmchat_test_bypass_mode

endfunction



" *****************************************************
" ****  CompareModelDictionaries() Function Tests  ****
" *****************************************************

" This test asserts the proper operation of function CompareModelDictionaries().  In order to do this the test will
" verify the behavior and return of the function when invoked under each of the following conditions:
"
"   1). The first argument given should logically sort BEFORE the second argument provided.
"   2). The first argument given should logically sort AFTER the second argument provided.
"   3). The first argument given should be considered equal to the second argument provided.
"
function! s:TestCompareModelDictionaries()
    " Create some test model dictionaries that can be used by the testing assertions that follow.  Note that these
    " "dictionaries" will only contain the model display name since that is currently the only field used by function
    " CompareModeDictionaries() for comparisons.
    let l:model_dict_1 = { "model display": "ABC" }
    let l:model_dict_2 = { "model display": "DEF" }
    let l:model_dict_3 = { "model display": "ABC" }  " Same as 'l:model_dict_1' in content but is different dict.

    " Assert that function CompareModelDictionaries() returns an expected value when the first dictionary given should
    " logically sort BEFORE the second dictionary provided.
    AssertEquals(-1, LLMChat#get_models#CompareModelDictionaries(l:model_dict_1, l:model_dict_2))

    " Assert that function CompareModelDictionaries() returns an expected value when the first dictionary given should
    " logically sort AFTER the second dictionary provided.
    AssertEquals(1, LLMChat#get_models#CompareModelDictionaries(l:model_dict_2, l:model_dict_3))

    " Assert that function CompareModelDictionaries() returns an expected value when the first dictionary given should
    " sort equivalently to the second dictionary provided.
    AssertEquals(0, LLMChat#get_models#CompareModelDictionaries(l:model_dict_1, l:model_dict_3))

endfunction


"
" =========================================  End Standalone Tests  =========================================
"

" This function is responsible for ensuring that proper cleanup takes place after the execution of each test in this
" script.  In the event a test fails than it may not restore the environment or editor state leaving vestages of the
" test execution that may negatively impact other tests.  By ensuring such cleanup is run after each test (whether
" strictly needed or not) we can help to ensure that each test should run from a known editor state.
function s:Teardown()
    " Call a utility function to reset any global variables to their expected defaults.  Note that we don't care about
    " saving the dictionary returned to us in this case since it will only contain any changes made to the global
    " variables by the previous test.
    call s:testutil.ResetGlobalVars()

    " Check to see if global variable 'g:llmchat_test_bypass_mode' is set and if so than remove it.
    if exists("g:llmchat_test_bypass_mode")
        unlet g:llmchat_test_bypass_mode
    endif

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


