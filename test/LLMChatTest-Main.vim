
UTSuite LLMChat Main Tests

" Test for logic found within the main plugin script.

" ------------------------------------------------------------------------------------------------------------------

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
" ****  LLMChatFolding() Function Tests  ****
" *******************************************

" This test performs a general walkthough of the logic in function LLMChatFolding() to show that it returns expected
" fold levels for each line a known chat log document.
function s:TestLLMChatFoldingWalkthrough()
    " Create a new split for testing and write to it a known "test" chat log document.  Be aware that we expect the
    " "new" command to automatically shift focus to the split on creation so no logic is included here for adjusting the
    " active buffer.
    "
    " NOTE: The LLMChatFolding() function does not require any kind of buffer parsing so the chat log document will
    "       be "loose" in the sense that we're not concerned about strict syntax representations.  Instead the test
    "       will focus primarily on including the structures that must be present for proper fold level determinations.
    new

    let l:test_chat_log_lines = [
                              \   "# Starting comment.",
                              \   "Option: Some option",
                              \   "Option: Another option",
                              \   " ",
                              \   "# A two line",
                              \   "# comment block",
                              \   "   *** ENDSETUP **",
                              \   "# Another block",
                              \   "#comment in the document",
                              \   "#body that is longer than just",
                              \   "#two lines.",
                              \   ">>>",
                              \   "First user message",
                              \   "<<<",
                              \   "=>>",
                              \   "First assistant message",
                              \   "<<=",
                              \   " ",
                              \   "----",
                              \   ">>>Second user message.",
                              \   "<<<",
                              \   "=>>Second assistant message.",
                              \   "<<=",
                              \   "-------------------",
                              \   "# Standalone comment line",
                              \   ">>> Third user",
                              \   "message as an extended",
                              \   "block of multiple",
                              \   "text lines.",
                              \   "<<<",
                              \   "",
                              \  "=>>Third assistant message",
                              \  "as an extended block",
                              \  "of multiple",
                              \  "text lines.",
                              \  "<<=",
                              \  "",
                              \  ">>> "
                              \ ]

    " NOTE: The appendbufline() function will end up leaving an empty line at the bottom of the document that we don't
    "       want for testing (the default first line that each new buffer begins with).  To get rid of this we will
    "       need to delete the last line via function deletebufline() after the content has been inserted.
    call appendbufline('%', 0, l:test_chat_log_lines)
    call deletebufline('%', '$')


    " Define a list that holds the expected fold levels for each line found in the 'l:test_chat_log_lines' list.
    let l:expected_levels_list = [ "-1", "-1", "-1", "-1", ">1", "<1",  "0", ">1",  "1",  "1", "<1", "-1", ">1",
                               \   "-1", "-1", ">2", "<1", "-1", "-1", ">1", "-1", ">2", "<1", "-1", "-1", ">1",
                               \   "-1", "-1", "-1", "-1", "-1", ">2", "-1", "-1", "<2", "<1", "-1", "-1" ]

    " Sanity Check - Make sure that the test buffer holds a number of lines that is equal to the length of list
    "                'l:expected_levels_list'.
    let l:buffer_line_cnt = line('$')
    AssertTxt( l:buffer_line_cnt == len(l:expected_levels_list),
           \ "Found the test buffer to contain " .. l:buffer_line_cnt  .. " lines but the test was found to define " ..
           \ "expected fold levels for " .. len(l:expected_levels_list) .. " lines.")


    " Now loop through each line found in the test buffer, invoke function LLMChatFolding() for each one, and assert
    " that the folding level returned matches to the expected level value.
    for l:line_cntr in range(1, l:buffer_line_cnt - 1, 1)
        let l:actual_fold_level = LLMChatFolding(l:line_cntr)
        let l:expected_fold_level = l:expected_levels_list[l:line_cntr - 1]
        AssertTxt(l:expected_fold_level == l:actual_fold_level,
                \ "An unexpected result was returned from function LLMChatFolding for line " .. l:line_cntr ..
                \ " having text '" .. getline(l:line_cntr) .. "'.  Expected to see the fold level '" ..
                \ l:expected_fold_level .. "' returned but instead found '" .. l:actual_fold_level .. "'.")

    endfor


    " Cleanup after testing by taking the following actions:
    "
    "   1). Forcibly close out the test buffer in use.
    "
    bd!

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

