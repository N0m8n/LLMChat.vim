" This file contains the logic needed to retrieve a listing of available models from the remote LLM server and display
" the result in a Vim popup window.  Logic related to the parsing of chat log content (primarily for the extraction of
" header information required to contact the remote LLM server) is imported from the vim9script library file
" 'import/utils.vim'.

" ===================
" ====           ====
" ====  Imports  ====
" ====           ====
" ===================

" Import definitions from the "import/utils.vim" script for use by the logic within this script.  Note that we use
" a path that is neither relative nor absolute to force Vim to load the script via its "runtimepath" value.
import "utils.vim" as util



" ================================
" ====                        ====
" ====  Function Definitions  ====
" ====                        ====
" ================================

" This function serves as the entrypoint for the model listing workflow.  When invoked, it will take the following
" actions as the first steps in the execution of such workflow:
"
"   1). Parse the header information from the active chat log document at the time of its invocation.
"   2). Use the extracted header data to form up a curl request to retrieve available models from the remote server.
"   3). Hand off execution to the first in a series of utility functions that will execute the formed cURL command and
"       present the results to the user in a popup window.
"
" This function may optionally be given the name of a register to use for storing the ID of a selected model later in
" the workflow; if not given than the "unnamed" register represented by " will be used by default.
"
" Arguments:
"   register_name - The name of a register that should be used for storing the ID of any selected model later in the
"                   workflow.  The value given can be any of the general use registers identified by letters A-Z or
"                   a-z.  When not given than this will default to use of the "unnamed" register that is identified by
"                   ".
"
" Throws: This function will throw an exception if any of the following conditions are encountered during its
"         execution:
"
"         1). The function was invoked at a time when the active document was NOT a chat log.
"         2). The chat log document that was active at the time of invocation did not have a properly formed header
"             section.
"         3). The register_name argument provided to the function was NOT the name of a register supported for use.
"         4). The server type given in the chat log document did not correspond to any supported remote server.
"
function LLMChat#get_models#FetchModels(register_name = '"')
    try
        " Make sure that the 'filetype' option in the current buffer is set to 'chtlg'; otherwise we will assume that
        " we're not being called from the context of a chat log document and will therefore be unable to parse the
        " active buffer's content into anything meaningful.
        if &filetype != 'chtlg'
            throw "[ERROR] - A model listing request was invoked from a non-chat buffer; the 'filetype' of the " ..
                \ "current buffer MUST be set to 'chtlg' before this action can be completed successfully.  The " ..
                \ "'filetype' of the buffer this command was invoked from was: '" .. &filetype .. "'"
        endif


        " Validate that the 'register_name' argument provided contains a valid value (which would be any upper or
        " lowercase letter or the double quote); if not than throw an exception.
        if a:register_name !~ '\v^[A-Za-z"]$'
            throw "[ERROR] - The register name provided for the model list operation was invalid.  Any given " ..
                \ "register name MUST be a single character that is (1) a lower case letter [a-z], (2) an upper " ..
                \ "case letter [A-Z], or \" which refers to the unnamed register.  The register name provided at " ..
                \ "the time of this fault was: '" .. a:register_name .. "'."
        endif

        " Now initiate a parse of header information from the current buffer; we will need this to get critical
        " information such as the remote server URL, the type of server we're requesting the model listing from,
        " authentication details, etc.
        let l:parse_dict = s:util.ParseChatBufferToBlocks(1, bufnr(), 0)


        " Output a debug message detailing that we're about to request a model listing from the remote LLM server.
        call s:util.WriteToDebug("Beginning request for remote LLM model listing (buffer = '" .. bufnr() .. "') ...")


        " Obtain a reference to the "header" dictionary that is held within the 'l:parse_dict' and which contains the
        " connection settings we need for the request.  Note that while it is not strictly necessary to store this in
        " a local variable it will shorten the code lines that follow and avoid redundant drill down to reach the same
        " nested dictionary.
        let l:header_dict = l:parse_dict[s:util.PARSE_DICTIONARY_HEADER_KEY]


        " Determine what the API path will be for the call based on the type of server that we are interacting with.
        "
        " NOTE: To be more user friendly we will use case insensitive comparisons to determine the server type and we
        "       will tolerate some variation on how "open webui" is specified (for example by allowing either a space or
        "       a dash in the server type value).
        let l:server_type = l:header_dict[s:util.PARSE_DICTIONARY_HEADER_SERVER_TYPE]

        if l:server_type ==? "ollama"
            " If the logic comes here than it looks like we'll be submitting our model listing request to an Ollama
            " server; simply set the 'l:api_path' variable approprite for this call and move on.
            let l:api_path = "/api/tags"

        elseif l:server_type ==? "open webui" || l:server_type ==? "open-webui"
            " If the logic comes here than it seems we'll be submitting our model listing request to an Open-WebUI
            " server; set the 'l:api_path' variable accordingly then continue on.
            let l:api_path = "/api/models"

        else
            " In this case we've found an unrecognized or unsupported server type so we'll throw an exception.
            throw "[ERROR] - The current chat log contained a 'Server Type' declaration in its header information " ..
                \ "whose value was not recognized as a supported type.  Currently this plugin can only support LLM " ..
                \ "interactions with the types 'Ollama' and 'Open WebUI'.  In order to fix this error please " ..
                \ "correct this declaration within your chat log document to use one of the supported values " ..
                \ "mentioned.  At the time of this fault the server type value found was: '" .. l:server_type .. "'."
        endif


        " Retrieve any authentication token that may be required by the remote LLM server and, if a value other than '-'
        " is returned, go head and build out the authorization header we'll need to pass to our cURL call later.
        let l:auth_token = s:util.GetAuthToken(l:parse_dict)
        if l:auth_token != '-'
            let l:auth_header = "Authorization: Bearer " .. l:auth_token
        endif


        " Request Vim to provide us with the name and path to a temporary file that we can use for holding the response
        " payload data.
        let l:response_payload_filename  = tempname()


        " Begin building up the cURL call needed to request a model listing from the remote system.
        "
        " NOTES:
        "   (1) The '--location' option will cause cURL to automatically handle redirects it encounters rather than
        "       return back with a 302.
        "   (2) The '--write-out' option tells cURL that we want it to return the HTTP response status to us on the
        "       standard output stream (ultimately this is what we will capture into variable 'l:http_status_code')
        "   (3) The '--silent' mode suppresses messages that would otherwise obfuscate the HTTP response code we're
        "       trying to receive back on the standard output stream for the cURL command.
        "   (4) The '--show-error' option prevents cURL from going completely mute with '--silent' so that if the
        "       command execution fails we might still get some information back as to why.
        "
        let l:curl_command = "curl -X GET " ..
                           \ "--output \"" .. l:response_payload_filename .. "\" " ..
                           \ "--write-out \"%{http_code}\" " ..
                           \ "--silent " ..
                           \ "--show-error " ..
                           \ "--location "

        if exists("l:auth_header")
            " In this case we assume authentication is required for the request so go ahead and add the header created
            " earlier.
            let l:curl_command = l:curl_command .. "--header \"" .. l:auth_header .. "\" "

        endif

        if exists("g:llmchat_curl_extra_args") && g:llmchat_curl_extra_args != ''
            " If the logic comes here than the global "extra arguments" property for cURL was set; make sure to append
            " the information held by this variable to our cURL command before proceeding.
            let l:curl_command = l:curl_command ..  g:llmchat_curl_extra_args .. ' '

        endif

        if s:util.IsDebugEnabled()
            " Since debug mode is enabled we will go ahead and add the cURL option to dump headers this way we can add
            " them to the debug output collected.  Note that to do this we will need to allocate a new temporary
            " file then add the path to that file into the command.
            let l:response_header_filename = tempname()
            let l:curl_command = l:curl_command .. "--dump-header \"" .. l:response_header_filename .. "\" "

        endif

        let l:curl_command = l:curl_command .. l:header_dict[s:util.PARSE_DICTIONARY_HEADER_SERVER_URL] .. l:api_path


        " If debug mode is enabled then create a debug message that details the curl call we're about to run.
        if s:util.IsDebugEnabled()
            let l:debug_message = "Curl call to be used for requesting a model listing from the remote LLM " ..
                                \ "server:\n\n" .. l:curl_command .. "\n\n"

            call s:util.WriteToDebug(l:debug_message)
        endif


        " Create a "model listing information" dictionary that we can use to pass additional data to downstream
        " processing.  This is done primarily to avoid the adjustment of parameter lists each time a new tweak is
        " made to the functionality for fetching model names.
        let l:model_listing_info_dict = {
                                      \   s:MODEL_LIST_INFO_DICT_REGISTER_NAME: a:register_name,
                                      \   s:MODEL_LIST_INFO_DICT_RESPONSE_FILE: l:response_payload_filename,
                                      \   s:MODEL_LIST_INFO_DICT_SERVER_TYPE: l:server_type
                                      \ }

        if s:util.IsDebugEnabled()
            " In this case debug mode was enabled so the curl command to be executed was also setup to dump headers
            " from any returned response to a temporary file.  Add the name and path of the allocated temporary file
            " to the model information dictionary so that downstream processing logic can reference it.
            let l:model_listing_info_dict[s:MODEL_LIST_INFO_DICT_RESPONSE_HEADERS_FILE] = l:response_header_filename
        endif


        " Call out to a utility function to handle the actual execution of the request and to perform the handoff of any
        " received response to downstream logic for processing.  This is done primarily to introduce some indirection
        " into the execution so that testing can break up the logic flow for verification.  Obviously we don't want to
        " couple up testing to the presence of an actual server so execution of the cURL call we created can be bypassed
        " inside the utility function when the appropriate testing state is set.
        "
        " NOTE: The utility function invoked does not currently use the asynchronous job framework from Vim so this
        "       means that the editor will freeze until the response is received.  In general we don't expect this call
        "       to take very long so, for now, this is probably fine.  In the future if this call turns out to be
        "       expensive than this may need to be refactored to accomodate excessive response lag.
        "
        call LLMChat#get_models#RequestModelList(l:curl_command, l:model_listing_info_dict)

    catch /\v.*/
        " If the logic comes here than we assume an exception was encountered outside the context of testing while
        " trying to execute an LLM interaction; display the exception message using 'echom' then take no further action.
        if s:util.IsDebugEnabled()
            call s:util.WriteToDebug("Chat interaction failed: " .. v:exception .. "\nException Trace:\n" ..
                                    \ join(v:stacktrace, "\n"))
        endif

        " Check to see if the 'g:llmchat_test_bypass_mode' variable has been set to a non-empty value; if so we will
        " assume that this function is being called by a test and we will re-throw the caught exception in order to
        " properly surface it.  If it looks like we're NOT in the context of a running test than echo the fault message
        " for the user to review.
        if exists("g:llmchat_test_bypass_mode")
            throw v:exception
        else
            echom v:exception
        endif

    endtry

endfunction


" This is a utility function intended to handle the execution of a curl command for retrieving a list of available
" LLM models from a remote server.  In general it serves as a point of indirection that allows the model listing
" workflow to be broken up for proper testing.
"
" Arguments:
"   curl_cmd - The curl command created to request the set of LLM models currently available from the remote server.
"   model_listing_info_dict - A dictionary containing state data needed for the rest of the model listing workflow.
"                             For details on the content of this dictionary please refer to the constants declared at
"                             the bottom of this script file.  Note that this function itself does not depend on
"                             information held by the dictionary given and that such information will simply be added
"                             to by the function execution before it is handed off to downstream processing.
"
function LLMChat#get_models#RequestModelList(curl_cmd, model_listing_info_dict)
    " Create a copy of the 'model_listing_info_dict' we received and store this into a local variable.  We do this
    " because we need to add more information to this dictionary for downstream processing but we can't modify the
    " argument given directly.
    let l:info_dict = copy(a:model_listing_info_dict)


    " Check to see if variable 'g:llmchat_test_bypass_mode' has been set to a non-empty value and if so then skip
    " execution of the provided curl command; instead we will assume that we are in the context of a test execution
    " and will take one of the following actions:
    "
    "   1). If 'g:llmchat_test_bypass_mode' has been set to a value that is a dictionary than we will simply add the
    "       arguments we receive under the following keys:
    "
    "         'curl_cmd' - The value given for argument 'curl_cmd'
    "         'model_listing_info_dict' - The dictionary we received for argument 'model_listing_info_dict'.
    "
    "  2). If the 'g:llmchat_test_bypass_mode' was set to any other value we will create a new empty dictionary,
    "      assign this to the global variable, then add the same entries as described for #1 above.
    "
    " If the 'g:llmchat_test_bypass_mode' varible is not set at all than we will proceed with execution of the curl
    " command given on the local system.
    if exists("g:llmchat_test_bypass_mode")
        if type(g:llmchat_test_bypass_mode) != 4
            let g:llmchat_test_bypass_mode = { }
        endif

        let g:llmchat_test_bypass_mode['curl_cmd'] = a:curl_cmd
        let g:llmchat_test_bypass_mode['model_listing_info_dict'] = a:model_listing_info_dict
    else
        " Execute the curl command then capture any value returned (which we assume to be data from the command's
        " standard output stream) into a local variable.
        let l:std_out_data = system(a:curl_cmd)

        " Set the "standard output stream" content we stored into variable 'l:std_out_data' as the http status code.
        " We do this because we assume that the curl call given to us was setup to return its response status on the
        " standard output stream when run.
        let l:info_dict[s:MODEL_LIST_INFO_DICT_HTTP_CODE] = l:std_out_data

        " Push the exit status for the curl command into the 'l:info_dict' as well so that downstream logic can
        " validate it.
        let l:info_dict[s:MODEL_LIST_INFO_DICT_EXIT_STATUS] = v:shell_error

        " Finally call the downstream function responsible for processing the response.
        call LLMChat#get_models#ProcessModelListingResponse(l:info_dict)

    endif

endfunction


" This is a utility function designed to parse the return of a model listing response from a remote server and then to
" organize that data into a popup window that can be shown to the user.  Note that details concerning the format of
" the response to be parsed are broken out into separate utility function calls so that the logic here can remain
" largely agnostic of the reponse format and semantics.
"
" Arguments:
"   model_listing_info_dict - A dictionary that contains all accumumlated state data for the model listing workflow.
"                             By the time this function is invoked such dictionary MUST information for all the
"                             following fields:
"
"                               - s:MODEL_LIST_INFO_DICT_HTTP_CODE
"                               - s:MODEL_LIST_INFO_DICT_EXIT_STATUS
"                               - s:MODEL_LIST_INFO_DICT_RESPONSE_FILE
"                               - s:MODEL_LIST_INFO_DICT_SERVER_TYPE
"                               - s:MODEL_LIST_INFO_DICT_RESPONSE_HEADERS_FILE (only if debug mode is enabled)
"
" Throws: An exception will be thrown by this function if any of the following conditions are encountered:
"
"         1). The curl exit code found in the given 'model_listing_info_dict' was NOT 0.
"         2). The HTTP response code found in the given 'model_listing_info_dict' was NOT 200.
"         3). A fault is encountered while trying  to parse the returned response payload.
"
function LLMChat#get_models#ProcessModelListingResponse(model_listing_info_dict)
    try
        " Create some local variables that will hold information being bootstrapped into this function through the
        " 'model_listing_info_dict' argument.  Note tht while this step isn't fully necessary it does help to
        " reduce the length of code lines in the logic that follows and avoids redundant drill downs for the same
        " values.
        let l:http_status_code = a:model_listing_info_dict[s:MODEL_LIST_INFO_DICT_HTTP_CODE]
        let l:curl_exit_code = a:model_listing_info_dict[s:MODEL_LIST_INFO_DICT_EXIT_STATUS]
        let l:response_file = a:model_listing_info_dict[s:MODEL_LIST_INFO_DICT_RESPONSE_FILE]
        let l:server_type = a:model_listing_info_dict[s:MODEL_LIST_INFO_DICT_SERVER_TYPE]

        " If debug messaging was enabled then write out the full response received; headers and payload.
        if s:util.IsDebugEnabled()
            let l:response_header_filename = a:model_listing_info_dict[s:MODEL_LIST_INFO_DICT_RESPONSE_HEADERS_FILE]

            let l:debug_message = "Response Data Received:" ..
                              \ "\n  Headers:" ..
                              \ "\n  -----------------"

            if(filereadable(l:response_header_filename))
                let l:debug_message = l:debug_message .. "\n" .. join(readfile(l:response_header_filename), "\n")

                " Remove the response header file now that its content has been added to the debug output; there is no
                " further need for the information such file contains after this is done.
                call delete(l:response_header_filename)
            else
                let l:debug_message = l:debug_message .. "\n  <Unavailable>"
            endif

            let l:debug_message = l:debug_message ..
                             \ "\n" ..
                             \ "\n  Payload Data:" ..
                             \ "\n  -----------------"

            if(filereadable(l:response_file))
                let l:debug_message = l:debug_message .. "\n" .. join(readfile(l:response_file), "\n")
            else
                let l:debug_message = l:debug_message .. "\n  <Unavailable>"
            endif

            let l:debug_message = l:debug_message .. "\n\n"

            call s:util.WriteToDebug(l:debug_message)
        endif


        " Begin verifying the outcome of the request by checking the exit status of the cURL command that should be held
        " by variable 'l:curl_exit_code'.  If this is any value other than 0 we will assume that the request was
        " unsuccesful.
        if l:curl_exit_code != 0
            throw "[ERROR] - The cURL call used to request the available model listing from the remote LLM server " ..
                \  "returned with a non-zero exit status; due to this condiition it is generally assumed that such " ..
                \ "call failed.  Additional details about this issue are provided below:\n" ..
                \ "Exit Status: " .. l:curl_exit_code .. "\n" ..
                \ "Standard Out:\n" .. l:http_status_code
        endif


        " Now check to see if the HTTP status code we received back was 200; if not than we assume that the request
        " was unsuccessful and we will throw an exception.
        if l:http_status_code != 200
            let l:ex_message = "[ERROR] - The HTTP status code returned for the model listing request was not equal " ..
                             \ "to 200 and due to this it is assumed that such request was unsuccessful.  " ..
                             \ "Additional details regarding this fault are provided below:\n" ..
                             \ "HTTP Status: " .. l:http_status_code
            if filereadable(l:response_file)
                let l:ex_message = l:ex_message .. "\n" .. "Response Payload:\n" ..
                                 \ join(readfile(l:response_file), "\n")
            endif

            throw l:ex_message

        endif


        " If the logic reaches this point than we assume that the curl request executed successfully.  Call out to a
        " utility function to process the content of the response payload and to return back a list of available models.
        " Note that this will be a server-specific action so we will need to look at the 'l:server_type' variable to
        " decide which utility to invoke.
        if l:server_type ==? "ollama"
            let l:model_list = LLMChat#get_models#ProcessOllamaModelListing(l:response_file)

        else
            " In this case we assume that the response came from an Open WebUI server so we will invoke a utility
            " function that knows how to parse such a response into a list of model names.  Why is there no validation
            " here?  The server type had to be validated at the start of processing for the model listing fetch so
            " by this point we assume (1) that the server type we found in the information dictionary passed to this
            " function is supported and (2) that every supported server type EXCEPT for Open WebUI was already fielded
            " by the if condition(s) above.
            let l:model_list = LLMChat#get_models#ProcessOpenWebUIModelListing(l:response_file)

        endif


        " Remove the 'l:response_file' from the system as part of cleanup since its content has been processed and the
        " list of available models is now loaded for use.
        call delete(l:response_file)


        " Perform an in-place sort of the 'l:model_list' variable contents so that models are arranged alphabetically
        " by their display name; this makes it much easier to search for and find models within the popup dialog.
        let l:Sort_Util_Funcref = function("LLMChat#get_models#CompareModelDictionaries")
        call sort(l:model_list, l:Sort_Util_Funcref)


        " UGLY - Save the model list information dictionary we received into script local variable
        "        's:model_list_info_dict' so that the popup menu call back function can access it.  As noted this is
        " very ugly and is being used as a work around for the fact that it seems that we have no way to bootstrap
        " arbitrary information through to such function.
        "
        " NOTE: We will make a copy of the 'model_listing_info_dict' during this assignment because we will need to
        "       modify the assigned dictionary later and it is not possible in Vimscript to modify function arguments.
        "
        let s:model_list_info_dict = copy(a:model_listing_info_dict)


        " Append the extracted model list information to the 's:model_list_info_dict' so that this is available later
        " to the callback function used with our popup menu.
        let s:model_list_info_dict[s:MODEL_LIST_INFO_DICT_MODEL_LIST] = l:model_list


        " Now create a VIM popup menu that will display the extracted model information for the user to review and
        " potentially select.
        "
        " NOTE: The 'l:model_list' contains a series of model information objects and the popup menu really needs a
        "       list of text lines to display for the user.  To create these text lines we will generate a new list
        "       that contains ONLY the display text for each model in the 'l:model_list'.
        "
        " NOTE 2: As we build up the 'l:model_display_list' for the dialog display we will keep a running tally of the
        "         longest display name seen.  Later we will use this value to fix the width of the popup window so
        "         that it doesn't resize itself as you're scrolling through it.
        "
        let l:model_display_list = [ ]
        let l:longest_desc_line = 0

        for l:curr_model_dict in l:model_list
            let l:curr_model_desc = l:curr_model_dict[s:MODEL_INFO_LIST_MODEL_DISPLAY]
            let l:curr_desc_len = len(l:curr_model_desc)

            call add(l:model_display_list, l:curr_model_desc)

            if l:curr_desc_len > l:longest_desc_line
                let l:longest_desc_line = l:curr_desc_len
            endif

        endfor

        let l:popup_opts_dict = {
                              \   "title": " Available Models ",
                              \   "callback": "LLMChat#get_models#HandleModelSelection",
                              \   "padding": [ 1, 1, 0, 1 ],
                              \   "filter": "LLMChat#get_models#HandleModelSelectionKeyPress",
                              \   "zindex": 50,
                              \   "maxheight": s:util.CalculateTotalWinHeight(),
                              \   "maxwidth": l:longest_desc_line,
                              \   "minwidth": l:longest_desc_line
                              \ }


        " NOTE: Check to see if variable 'g:llmchat_test_bypass_mode' has been set and if so take the following
        "       actions INSTEAD of opening the popup:
        "
        " 1). Check to see if the 'g:llmchat_test_bypass_mode' variable is holding a dictionary value and if not than
        "     replace its value with an empty dictionary.
        "
        " 2). Populate the dictionary held by the 'g:llmchat_test_bypass_mode' variable with the following fields:
        "
        "       'popup_options' --> The l:popup_opts_dict variable created for the popup menu.
        "       'model_info_dict' --> The current value for script variable 's:model_list_info_dict'.
        "
        " This will allow test executions to (1) bypass the popup menu and (2) to validate the information that this
        " function would send to the popup menu as well as set into the script namespace for downstream logic.
        "
        if exists("g:llmchat_test_bypass_mode")
            if type(g:llmchat_test_bypass_mode) != v:t_dict
                let g:llmchat_test_bypass_mode = { }
            endif

            let g:llmchat_test_bypass_mode["popup_options"] = l:popup_opts_dict
            let g:llmchat_test_bypass_mode["model_info_dict"] = s:model_list_info_dict

        else
            call popup_menu(l:model_display_list, l:popup_opts_dict)
        endif

    catch /\v.*/
        " If the logic comes here than we assume an exception was encountered outside the context of testing while
        " trying to execute an LLM interaction; display the exception message using 'echom' then take no further action.
        if s:util.IsDebugEnabled()
            call s:util.WriteToDebug("Chat interaction failed: " .. v:exception .. "\nException Trace:\n" ..
                                    \ join(v:stacktrace, "\n"))
        endif

        " Check to see if the 'g:llmchat_test_bypass_mode' variable has been set to a non-empty value; if so we will
        " assume that this function is being called by a test and we will re-throw the caught exception in order to
        " properly surface it.  If it looks like we're NOT in the context of a test than simply echo the fault message
        " out for the user to review.
        if exists("g:llmchat_test_bypass_mode")
            throw v:exception
        else
            echom v:exception
        endif


    endtry

endfunction


" This is a utility function designed to parse a model listing response payload from an Ollama server and then return
" the content of that response as a "model information list".  The model information list given back is a list of
" dictionaries that each hold common fields such as the model's display name, ID, and detail information.  This common
" presentation of information allows the invoking logic to remain largely agnostic of the details around the specific
" remote server that was interacted with.
"
" Arguments:
"   response_file - The name and path to a file that holds the response payload that this function should parse.
"
" Returns: A list of dictionaries that describe the models found within the parsed response payload.  For more
"          information on the content of such dictionaries please see the "model information list" constants section
"          at the bottom of this script file.
"
" Throws: Will throw an exception if a fault is encountered while trying to parse the JSON document held by the
"         'response_file' given.
"
function LLMChat#get_models#ProcessOllamaModelListing(response_file)
    " Begin processing of the response by parsing the full content of the 'response_file' provided as a JSON document.
    " This will return back to us a dictionary that we can use to extract individual values from the return.  Note that
    " we expect the general format of the JSON response document we're parsing to look like the following:
    "
    "  {
    "    "models":
    "    [
    "      {
    "        "name":"nous-hermes2:10.7b",
    "        "model":"nous-hermes2:10.7b",
    "        "modified_at":"2025-11-14T09:21:09.08187336-06:00",
    "        "size":6072407285,
    "        "digest":"d50977d0b36ae5779167f2d376da80b512886a0789e5f7e122cdb6f85fc86f85",
    "        "details":
    "        {
    "          "parent_model":"",
    "          "format":"gguf",
    "          "family":"llama",
    "          "families": ["llama"],
    "          "parameter_size":"11B",
    "          "quantization_level":"Q4_0"
    "        }
    "      },
    "      ...
    "    ]
    "  }
    "
    let l:response_dict = json_decode(join(readfile(a:response_file), "\n"))


    " Create a list object that will be returned back to the caller and which will contain the "common" information
    " values expected from the model data we're parsing.
    let l:model_info_list = [ ]


    " Extract the array of model objects held by the 'l:response_dict' then begin iterating over each one for
    " processing.
    for l:curr_model_obj in l:response_dict["models"]
        " Create a model information dictionary that will hold the "common" data fields defined by the constants for the
        " "model information list" found at the bottom of this script file.  This will build out a data structure whose
        " information and presentation looks the same to the invoking logic regardless of the underlying format and
        " content of the received model listing response.
        let l:curr_model_info_dict = {
                                   \   s:MODEL_INFO_LIST_MODEL_ID: l:curr_model_obj["name"],
                                   \   s:MODEL_INFO_LIST_MODEL_DISPLAY: l:curr_model_obj["name"],
                                   \   s:MODEL_INFO_LIST_DETAILS_DICT: l:curr_model_obj
                                   \ }

        " Add the finished model information dictionary to the end of the 'model_info_list'.
        call add(l:model_info_list, l:curr_model_info_dict)

    endfor


    " Return the flushed out 'l:model_info_list' back to the caller of this function.
    return l:model_info_list

endfunction


" This is a utility function designed to parse a model listing response payload from an Open WebUI server then return
" the content of that response as a "model information list".  The model information list given back is a list of
" dictionaries that each hold common fields such as the model's display name, ID, and detail information.  This common
" presentation of information allows the invoking logic to remain largely agnostic of the details around the specific
" remote server that was interacted with.
"
" Arguments:
"   response_file - The name and path to a file that holds the response payload that this function should parse.
"
" Returns: A list of dictionaries that describe the models found within the parsed response payload.  For more
"          information on the content of such dictionaries please see the "model information list" constants section
"          at the bottom of this script file.
"
" Throws: Will throw an exception if a fault is encountered while trying to parse the JSON document held by the
"         'response_file' given.
"
function LLMChat#get_models#ProcessOpenWebUIModelListing(response_file)
    " Begin processing of the response by parsing the full content of the 'response_file' provided as a JSON document.
    " This will return back to us a dictionary that we can use to extract individual values from the return.  Note that
    " we expect the general format of the JSON response document we're parsing to look like the following:
    "
    "  {
    "    "data":
    "    [
    "      {
    "        "id":"nous-hermes2:10.7b",
    "        "name":"nous-hermes2:10.7b",
    "        "object":"model",
    "        "created":1770235563,
    "        "owned_by":"ollama",
    "        "ollama":
    "        {
    "          "name":"nous-hermes2:10.7b",
    "          "model":"nous-hermes2:10.7b",
    "          "modified_at":"2025-11-14T09:21:09.08187336-06:00",
    "          "size":6072407285,
    "          "digest":"d50977d0b36ae5779167f2d376da80b512886a0789e5f7e122cdb6f85fc86f85",
    "          "details":
    "          {
    "            "parent_model":"",
    "            "format":"gguf",
    "            "family":"llama",
    "            "families":["llama"],
    "            "parameter_size":"11B",
    "            "quantization_level":"Q4_0"'
    "          },
    "          "connection_type":"local",
    "          "urls":[0]
    "        },
    "        "connection_type":"local",
    "        "tags":[],
    "        "actions":[],
    "        "filters":[]
    "      },
    "      ...
    "    ]
    "  }
    "
    let l:response_dict = json_decode(join(readfile(a:response_file), "\n"))


    " Create a list object that will be returned back to the caller and which will contain the "common" information
    " values expected from the model data we're parsing.
    let l:model_info_list = [ ]


    " Extract the array of model objects held by the 'l:response_dict' then begin iterating over each one for
    " processing.
    for l:curr_model_obj in l:response_dict["data"]
        " Create a model information dictionary that will hold the "common" data fields defined by the constants for the
        " "model information list" found at the bottom of this script file.  This will build out a data structure whose
        " information and presentation looks the same to the invoking logic regardless of the underlying server that
        " provided back the model listing.
        let l:curr_model_info_dict = {
                                   \   s:MODEL_INFO_LIST_MODEL_ID: l:curr_model_obj["id"],
                                   \   s:MODEL_INFO_LIST_MODEL_DISPLAY: l:curr_model_obj["name"],
                                   \   s:MODEL_INFO_LIST_DETAILS_DICT: l:curr_model_obj
                                   \ }

        " Add the finished model information dictionary to the end of the 'model_info_list'.
        call add(l:model_info_list, l:curr_model_info_dict)

    endfor


    " Return the flushed out 'l:model_info_list' back to the caller of this function.
    return l:model_info_list

endfunction


" This is a utility function intended to handle selection outcomes from the model list popup window; it will be
" invoked directly by Vim when the user presses a key that either selects a model or exits the popup.  Once invoked the
" function will determine whether or not a model was selected and IF a selection was made it will copy the ID of the
" selected model into the register specified for use when the model listing workflow was initiated (see function
" FetchModels() in this script).  If no selection was made than this function will simply exit without taking any
" specific action.
"
" Arguments:
"   id - The ID of the window that the selection was made from; currently unused by the function execution.
"   result - A number indicating the row within the window that was selected by the user.  When no selection was made
"            (for instance when the user simply chose to close the popup window) than this value will be less than 1.
"
function LLMChat#get_models#HandleModelSelection(id, result)
    " Check to see if the 'result' given is less than 1; if so than there is no action to take as we assume the user
    " exited the dialog without making any selection.
    if a:result < 1
        return
    endif


    " If the logic comes here than we assume the user made a selection from the popup menu and that we need to now
    " set the name of the selected model into the specified register.  Retrieve the register name to use from the
    " 's:model_list_info_dict' and then load it with the selected model ID.  Note that 'result' is simply a selection
    " index so to get the associated model ID we will need to fetch the model information list (also stored inside
    " the 's:model_list_info_dict' variable) and use the index to locate the model dictionary whose ID was selected.
    let l:register_name = s:model_list_info_dict[s:MODEL_LIST_INFO_DICT_REGISTER_NAME]
    let l:model_info_list = s:model_list_info_dict[s:MODEL_LIST_INFO_DICT_MODEL_LIST]

    let l:model_id = l:model_info_list[a:result - 1][s:MODEL_INFO_LIST_MODEL_ID]
    call setreg(l:register_name, l:model_id)


    " Clear the content from script variable 's:model_list_info_dict' now that we've reached the end of the workflow
    " for listing available models on the remote server.  We do this primarly to ensure that old information can't be
    " left around and possible obscure script bugs in the future.
    let s:model_list_info_dict = { }


    " Echo some feedback to the user that the model ID was copied into the register.
    echom "Model ID '" .. l:model_id .. "' copied to register '" .. l:register_name .. "'..."

endfunction


" This function handles key press events from within the context of the model list popup window and is responsible
" for implementing specialized logic such as the display of a details dialog when the appropriate key press is made.
" Note that key presses not registered for specialized handling are passed back to the popup_menu_filter() function
" within Vim to provide things like window cursor navigation and popup close actions.  For more details on popup
" filters see ':help popup-filter'.
"
" Arguments:
"   winid - The ID of the popup window that key press events should be associated with.
"   key - The key that was pressed by the user.
"
function LLMChat#get_models#HandleModelSelectionKeyPress(winid, key)
    " Check to see if one of the following keys was pressed and if so take appropriate action:
    "
    "   ?  - In this case we will create a new "information" popup that will show details about the selected model.
    "
    " If none of these cases apply than we will invoke function popup_filter_menu() to handle the key press as per
    " standard popup navigation.
    if a:key == '?'
        " In this case we assume that the user requested to see additional detail information on a particular model.
        " Use function getcurpos() to determine what line item is currently selected so we know which model to display
        " the detail information for.
        "
        " NOTE: The getcurpos() function actually returns a list that contains a number of different values; we are
        "       only concerned with the 2nd item in the list (i.e., index 1) as this is the column position that we
        "       will interpret to correspond to a selection line.  In order to map this column position to a selection
        "       we will have to assume that (1) models in the popup menu are displayed in the order of the model
        "       information list (from top to bottom) and (2) that we can map the column number we find to a model
        "       index by simply subtracting 1 (columns in the popup seem to start at 1 whereas list indices start at 0
        "       so the shift is just to go from 1-based to 0-based indexing).
        "
        let l:position_list = getcurpos(a:winid)
        let l:model_index = l:position_list[1] - 1


        " Lookup the model dictionary at the provided index from within the "model information list" held by script
        " variable 's:model_list_info_dict'.
        let l:model_dict = s:model_list_info_dict[s:MODEL_LIST_INFO_DICT_MODEL_LIST][l:model_index]


        " Retrieve the model detail information dictionary from the 'l:model_dict' then call out to a utility function
        " that will format this information into a series of text lines appropriate for display to a user.
        let l:model_detail_dict = l:model_dict[s:MODEL_INFO_LIST_DETAILS_DICT]
        let l:model_detail_desc = s:util.FormatDictionaryToText(l:model_detail_dict, 2)


        " Find the longest line in the 'l:model_detail_desc' and store this information into a local variable; later
        " we will use this to set a fixed width for the detail popup dialog.  Note that if we don't do this the
        " popup will resize as you scroll it and this can be disruptive to watch.
        let l:longest_detail_line = 0
        for l:curr_detail_line in l:model_detail_desc
            let l:curr_line_length = len(l:curr_detail_line)

            if l:curr_line_length > l:longest_detail_line
                let l:longest_detail_line = l:curr_line_length
            endif

        endfor


        " Create a popup dialog that will display over the current popup and which will show the requested detail
        " information.
        let l:model_dict = s:model_list_info_dict[s:MODEL_LIST_INFO_DICT_MODEL_LIST][l:model_index]
        let l:model_name = model_dict[s:MODEL_INFO_LIST_MODEL_DISPLAY]

        let l:popup_options = {
                            \   "title": " Model '" .. l:model_name .. "' Details ",
                            \   "padding": [1, 1, 0, 1],
                            \   "zindex": 100,
                            \   "filter": "popup_filter_menu",
                            \   "maxheight": s:util.CalculateTotalWinHeight(),
                            \   "minwidth": l:longest_detail_line,
                            \   "maxwidth": l:longest_detail_line
                            \ }

        " NOTE: Check to see if variable 'g:llmchat_test_bypass_mode' has been set and if so take the following
        "       actions INSTEAD of opening the popup:
        "
        "  1). Check to see if the 'g:llmchat_test_bypass_mode' variable is holding a dictionary value and if not than
        "      replace its value with an empty dictionary.
        "
        "  2). Populate the dictionary held by the 'g:llmchat_test_bypass_mode' variable with the following fields:
        "
        "        'popup_options' --> The 'l:popup_options' variable created for the popup menu.
        "        'model_detail_desc' --> The model detail description that would be displayed inside the popup.
        "
        if exists("g:llmchat_test_bypass_mode")
            if type(g:llmchat_test_bypass_mode) != v:t_dict
                let g:llmchat_test_bypass_mode = { }
            endif

            let g:llmchat_test_bypass_mode["popup_options"] = l:popup_options
            let g:llmchat_test_bypass_mode["model_detail_desc"] = l:model_detail_desc

        else
            call popup_menu(l:model_detail_desc, l:popup_options)
        endif


        " Set variable 'l:return_value' to 1 so that we acknowledge on exit of this function that we handled the
        " key press.
        let l:return_value = 1
    else
        let l:return_value = popup_filter_menu(a:winid, a:key)
    endif


    " Return the value held by 'l:return_value' back to the caller indicating whether or not the key press was fielded
    " by this function.
    return l:return_value

endfunction


" This is a comparator function that allows model information lists to be sorted by model display name.  When invoked,
" the function expects to receive two model information dictionaries that it will then compare by the display name
" they hold.  Return values are then determined by the following rules:
"
"   1). If the display name held by the 'first_dict' would logically sort BEFORE the display name held by the
"       'second_dict' than a value of -1 is returned.
"   2). If the display name held by the 'first_dict' would logically sort AFTER the display name held by the
"       'second_dict' than a value of 1 is returned.
"   3). If neither of the cases above apply than 0 is returned (which is generally regarded as meaning that the
"       display names where the same).
"
" For details on how this function will be used for sorting purposes see 'help sort()'.
"
" Arguments:
"   first_dict - The first model information dictionary to be involved in the comparison operation.
"   second_dict - The second dictionary against which the 'first_dict' argument will be compared.
"
" Returns: An integer value describing the sort order for the 'first_dict' and 'second_dict' arguments provided.
"
function LLMChat#get_models#CompareModelDictionaries(first_dict, second_dict)
    " Base the sorting entirely on the display name held by both models.
    let first_model_display = a:first_dict[s:MODEL_INFO_LIST_MODEL_DISPLAY]
    let second_model_display = a:second_dict[s:MODEL_INFO_LIST_MODEL_DISPLAY]

    let sort_code = 0     " Assume the equality case by default.
    if first_model_display < second_model_display
        " In this case the first_dict has a model display name that comes BEFORE the model display name in the second
        " dictionary; change the 'sort_code' we will return to -1.
        let sort_code = -1

    elseif first_model_display > second_model_display
        " In this case the first_dict has a model display name that comes AFTER the model display name in the second
        " dictionary; change the 'sort_code' we will return to 1.
        let sort_code = 1

    endif

    " Return the resolved sort code back to the caller.
    return sort_code

endfunction


" This is a utility function allowing the 's:model_list_info_dict' member of this script to be set explicitly by the
" caller to a provided dictionary.  The primary reason for this function is to allow testing to clear or to explicitly
" set the 's:model_list_info_dict' member as there is no other means by which to do so.  This function is not intended
" for general use and code paths outside of testing should allow the logic within this script to manage the
" 's:model_list_info_dict' member' internally.
"
" Arguments:
"   new_dict - The dictionary that should be set into script variable 's:model_list_info_dict'.
"
function LLMChat#get_models#SetModelListInfoDict(new_dict)
    " Simply set the provided dictionary into script member 's:model_list_info_dict'.
    let s:model_list_info_dict = a:new_dict

endfunction



" ============================
" ====                    ====
" ====  Main Script Logic ====
" ====                    ====
" ============================
"
" The following logic should run any time that this file is sourced by Vim and is typically used for initialization,
" optimization actions, or common values within the script.

" The following script local variable is used to hold the model listing information dictionary during specific segments
" of the model listing workflow since such segments have technical limitations around the information you can pass
" (for example trying to get the dictionary to the callback function used by a popup menu).  Note that by default this
" variable is always empty and will be set when needed by the logic flow.
let s:model_list_info_dict = { }


    " ------------------------------------------------
    " ----  Model Listing Information Dictionary  ----
    " ------------------------------------------------
"
" The model listing functionality contained by this script is setup so that a dictionary of data values can be passed
" around between functions to convey information about how the logical listing process should behave.  This allows
" new features and behavior tweaks to be injected easily into the path for the listing process without the more
" heavy-handed approach of continually modifying function parameter lists for the direct passing of values.  The
" current dictionary used for this information is one level and contains entries whose names correspond to one of
" the constants listed below (constants are used for consistenty and to introduce an immediate execution fault on typo
" which a string literal won't do).
const s:MODEL_LIST_INFO_DICT_REGISTER_NAME = "register name"
const s:MODEL_LIST_INFO_DICT_RESPONSE_FILE = "response payload file"
const s:MODEL_LIST_INFO_DICT_RESPONSE_HEADERS_FILE = "response headers file"
const s:MODEL_LIST_INFO_DICT_HTTP_CODE = "http response code"
const s:MODEL_LIST_INFO_DICT_EXIT_STATUS = "exit status"
const s:MODEL_LIST_INFO_DICT_SERVER_TYPE = "server type"
const s:MODEL_LIST_INFO_DICT_MODEL_LIST = "model list"


    " --------------------------------
    " ---  Model Information List  ---
    " --------------------------------
"
" Once the model information has been returned back from the remote LLM server a server-specific parsing process will
" be invoked that will return back a "common" model information list.  This is done to abstract away the details of
" how the particular remote server exposes its model information and the way it returns this to the caller.  The
" "common" list will have a consistent format and content regardless of which server response it was generated for that
" way the main logic in the model request workflow can remain agnostic to the details of the specific server it is
" working with.
"
" Each entry in the model information list created by parsing a model listing return will consist of a "model"
" dictionary that has a series of pre-defined fields.  Each field that can appear within this dictionary has a
" corresponding constant definition below intended to normalize the string literals in use within the script and to
" provide better fault detection on typo (for instance it is much easier to see an unknown constant flagged than a
" mistyped literal key).
"
" NOTE: The value for the 'details' key is the full description for the model as returned by the remote server.  Since
"       this information is kept fully in its original form it is only suitable for (1) display to users as full
"       detail data or (2) consumption through functions that are aware of the remote server type.
"
const s:MODEL_INFO_LIST_MODEL_ID = "model id"
const s:MODEL_INFO_LIST_MODEL_DISPLAY = "model display"
const s:MODEL_INFO_LIST_DETAILS_DICT = "details"

