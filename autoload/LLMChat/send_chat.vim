" This file contains the logic needed to send a chat message to an LLM hosted by a remote server then post the response
" into the chat window the command was run from.  Note that logic related to parsing and validation of the chat window
" content is imported from the vim9script library file 'import/utils.vim'; such logic must be used multiple separate
" features within the plugin so it makes sense to keep this separate.


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


" This function is responsible for reading the content from the currently active buffer, parsing such content as a chat
" log document, then asynchronously submitting a chat request to a remote chat log server.  Note that in order for the
" execution of the function to complete as expected the following assumptions must all be true at the time of
" invocation:
"
"   1). The currently active buffer has a file type of 'chtlg' and such buffer holds a document whose content adheres
"       to the structure requirements for a chat log document.
"
"   2). The last message in the chat comes from the user (in other words a chat interaction exists for which there is
"       not yet an assistant response).
"
"   3). The editor CANNOT be waiting on a response from a previously submitted chat interaction to complete (in other
"       words interactions are serial and and only one chat interaction at a time can be in progress).
"
" On successful execution an asynchronous job will be submitted to contact the remote LLM server and a
" "chat execution dictionary" will be created within the scope of this script (bound to variable
" 's:curr_chat_exec_dict') that will contain all the details of the submission made.  The asynchronous job framework
" in Vim will then take responsibility for invoking functions related to the execution of the job including the function
" that will handle post-response processing and updating of the chat buffer.
"
" Throws: The execution of this function will throw an exception if any of the assumptions documented above are found
"         to be incorrect.
"
function LLMChat#send_chat#InitiateChatInteraction()
    try
        " Make sure that the 'filetype' option in the current buffer is set to 'chtlg'; otherwise we will assume that
        " we're not being called from a buffer that is holding a chat log.  In such a case write out an error to the
        " user/messages then exit the function call.
        if &filetype != "chtlg"
            throw "[ERROR] - A chat interaction was invoked from a non-chat buffer; the 'filetype' of the current " ..
                \ "buffer MUST be set to 'chtlg' before this action can be completed successfully.  The 'filetype' " ..
                \ "of the buffer this command was invoked from was: '" .. &filetype .. "'"
        endif


        " Check to see if the 's:curr_chat_exec_dict' variable is undefined or not; if it is NOT defined than we need
        " to initialize it to hold an empty dictionary.  If this variable IS defined than we will need to do some
        " more checking to see what state things are in.
        if exists("s:curr_chat_exec_dict")
            " In this case the 's:curr_chat_exec_dict' existed so we need to stop and check if maybe there is already
            " a running execution job.  We only allow one chat execution at a time to be run so if the user tried to
            " trigger a chat submission before the previous such submission completed we will throw an exception.  If
            " the job information held shows that such job was completed or if the dictionary just wasn't cleaned up
            " (for example if some fault occurred previously that preempted cleanup) we will perform that cleanup now
            " before proceeding on.
            if has_key(s:curr_chat_exec_dict, s:CURR_CHAT_EXEC_DICT_JOB_ID)
                " In this case the chat execution dictionary was still holding a reference to a job.  Retrieve that
                " job reference and check to see if such job is still running.
                let l:job_ref = s:curr_chat_exec_dict[s:CURR_CHAT_EXEC_DICT_JOB_ID]
                if job_status(l:job_ref) == "run"
                    throw "[ERROR] - A chat submission appears to already be running and only one submission at a " ..
                        \ "time is allowed.  You will either need to wait on such submission to complete or kill " ..
                        \ "it with the 'AbortChatExec' command before you can send a new chat request."
                endif

            endif

            " If the logic comes here than we assume that any job information held by the chat execution dictionary
            " referred to a job that is no longer running OR the dictionary referred to no job and simply wasn't cleaned
            " up.  In either case we will clean out the dictionary so we can proceed with the current chat submission
            " execution.
            let s:curr_chat_exec_dict = {}

        else
            " In this case the variable is NOT defined so we need to initialize this to an empty dictionary for use.
            let s:curr_chat_exec_dict = {}

        endif


        " If the logic reaches this point than it looks like we will be proceeding with a new chat request submission;
        " setup the 's:curr_chat_exec_dict' in prep for this execution by doing the following:
        "
        "  1). Push the current system time (in seconds) into the dictionary.
        "
        "  2). Set the 's:CURR_CHAT_EXEC_DICT_STDOUT' field (which will capture messages written to standard out during
        "      job execution) to the empty string.  This initializes the field appropriately for spooling messages.
        "
        let s:curr_chat_exec_dict[s:CURR_CHAT_EXEC_DICT_TIMESTAMP] = localtime()
        let s:curr_chat_exec_dict[s:CURR_CHAT_EXEC_DICT_STDOUT] = ''


        " Retrieve the number of the buffer that was active when this function was called then (1) store this into a
        " local variable and (2) push a copy into the 's:curr_chat_exec_dict'.
        let l:chat_buff_num = bufnr()
        let s:curr_chat_exec_dict[s:CURR_CHAT_EXEC_DICT_BUFFER_NUM] = l:chat_buff_num


        " Retrieve the text width setting for the current buffer then store this into the 's:curr_chat_exec_dict' for
        " later use while processing the chat response.
        let s:curr_chat_exec_dict[s:CURR_CHAT_EXEC_DICT_BUFFER_TEXTWIDTH] = &textwidth


        " Retrieve the total number of lines currently found in the chat buffer then push this value into the
        " 's:curr_chat_exec_dict'.  We will need to know this later during the processing of any chat response so we can
        " compute where to move the cursor after writing the assistant message.
        let s:curr_chat_exec_dict[s:CURR_CHAT_EXEC_DICT_BUFFER_LINECNT] = line('$')


        " Output a debug message detailing that a chat interaction is beginning.
        call s:util.WriteToDebug("Beginning chat interaction execution (buffer = '" .. l:chat_buff_num .. "') ...")


        " Call out to a utility function to parse the content of the current chat log document and return back to us
        " a "parse dictionary" representing its structured information.  Note that we will also need to push a
        " reference to this parse dictionary into the 's:curr_chat_exec_dict' dictionary for post-response processing.
        let l:parse_dictionary = s:util.ParseChatBufferToBlocks(0, l:chat_buff_num)
        let s:curr_chat_exec_dict[s:CURR_CHAT_EXEC_DICT_PARSE_DICT] = l:parse_dictionary


        " Check to see if one of the following applies to the state of the 'l:parse_dictionary' as each condition
        " indicates a situation where we will immediately abort the chat interaction:
        "
        "  1). The 'l:parse_dictionary' has no messages key - This should only happen when NO messages have been
        "                                                     added to a chat log (for instance if a chat interation
        "          is triggered from the default initialization template WITHOUT adding any user message).  Obviously
        "          there is no chat message for an LLM to respond to so we will abort with a warning message.
        "
        "  2). The most recent message dictionary in 'l:parse_dictionary' - This means that the last message parsed
        "      is complete.                                                 from the chat log document already has an
        "                                                                   associated response.  Since there is no
        "          new chat message for the LLM to respond to we will simply abort the interaction execution with a
        "          warning.
        "
        if ! has_key(l:parse_dictionary, s:util.PARSE_DICTIONARY_MESSAGES_KEY)
            " In this case the parse dictionary holds NO chat messages so there is nothing to submit to an LLM.
            throw "[WARN] - The current chat log appears to contain no messages; please enter a new user message " ..
               \  "that an LLM should respond to."
        else
            " Check to see if the last message in the messages array is complete.
            let l:last_message_idx = len(l:parse_dictionary[s:util.PARSE_DICTIONARY_MESSAGES_KEY]) - 1
            let l:last_message_dict = l:parse_dictionary[s:util.PARSE_DICTIONARY_MESSAGES_KEY][l:last_message_idx]

            if has_key(l:last_message_dict, s:util.PARSE_DICTIONARY_ASSISTANT_MSG_KEY)
                throw "[WARN] - The chat in the current document already has an assistant response; please post " ..
                    \ "a new chat for the LLM to read."
            endif

        endif


        " Ask Vim for the name of some temporary files that we can use for the following:
        "
        "  1). A file for buffering the request payload we will send to the remote server.  This can get large over
        "      time and we don't want to provide this to cURL directly in the command string as we may exceed the
        "      maximum command length allowed on some systems.
        "
        "  2). A file that can be used for buffering the response payload that comes back.
        "
        "  3). [Optional] If debug outputs will be enabled than we will also request a file that we can dump the
        "      response header data to.
        "
        " NOTE: We will need to add the names of each requested file into the 's:curr_chat_exec_dict' as well so that
        "       these can be referenced by the post-response processing.
        "
        let l:request_payload_filename = tempname()
        let s:curr_chat_exec_dict[s:CURR_CHAT_EXEC_DICT_REQUEST_FILENAME] = l:request_payload_filename

        let l:response_payload_filename = tempname()
        let s:curr_chat_exec_dict[s:CURR_CHAT_EXEC_DICT_RESPONSE_FILENAME] = l:response_payload_filename

        if s:util.IsDebugEnabled()
            let l:response_header_filename = tempname()
            let s:curr_chat_exec_dict[s:CURR_CHAT_EXEC_DICT_RESPONSE_HEADER_FILENAME] = l:response_header_filename
        endif


        " Obtain a reference to the "header" dictionary that will be held within the "parse dictionary" obtained
        " earlier.  We will need to access multiple fields from the header information so this just makes code access a
        " little more direct.
        let l:header_dict = l:parse_dictionary[s:util.PARSE_DICTIONARY_HEADER_KEY]


        " Now build out the JSON request payload that we need to send to the remote LLM server.  Note that the
        " structure of this payload will depend on what type of server we intend to interact with so we will need to
        " look at the "server type" information contained by the 'l:header_dict' to decide how to proceed.
        "
        " NOTE: For more user friendliness we will always use case-insensitve comparisons when looking up the server
        "       type found in the chat document against the fixed identifiers found in this script.  We will also
        "       tolerate some variation in how 'open webui' is specified (for instance with or without a '-' character).
        let l:server_type = l:header_dict[s:util.PARSE_DICTIONARY_HEADER_SERVER_TYPE]

        if l:server_type ==? "ollama"
            " If the logic comes here than it looks like we'll be submiting a chat interaction to an Ollama server;
            " call out to a utility function to build the request payload that we will need and write it to the
            " 'l:request_payload_filename' file.
            call LLMChat#send_chat#CreateOllamaChatRequestPayload(l:parse_dictionary, l:request_payload_filename)

            " Set the URL path to '/api/chat' as this will be the API we intend to hit for an Ollama server.
            let l:api_path = "/api/chat"

        elseif l:server_type ==? "open webui" || l:server_type ==? "open-webui"
            " If the logic comes here than it looks like we'll be interacting with an Open-WebUI server; call out to
            " a utility function to build out the request payload that we'll need and then output such payload to the
            " file having name/path 'l:request_payload_filename'.
            call LLMChat#send_chat#CreateOpenWebUIChatRequestPayload(l:parse_dictionary, l:request_payload_filename)

            " Set the URL path to '/api/chat/completions' as this will be the API we intend to hit for an Open-WebUI
            " server.
            let l:api_path = "/api/chat/completions"

        else
            " If the logic comes here than we've encountered a server type that we don't know how to interact with.
            " Throw an exception to abort taking further action and provide a message that will explain to the user
            " what went wrong.
            throw "[ERROR] - The current chat log contained a 'Server Type' declaration in its header information " ..
                \ "whose value was not recognized as a supported type.  Currently this plugin can only support " ..
                \ "LLM interactions with the types 'Ollama' and 'Open WebUI'.  In order to fix this error please " ..
                \ "correct this declaration within your chat log document to use one of the supported values " ..
                \ "mentioned.  At the time of this fault the server type value found was: '" .. l:server_type .. "'."
        endif

        if s:util.IsDebugEnabled()
            " In this case debug messaging is enabled so we will write the full content of the generated request
            " payload to the debug output destination.
            call util.WriteToDebug("Request Payload:\n" .. join(readfile(l:request_payload_filename), "\n") .. "\n\n")
        endif

        " Retrieve any authentication token that may be required by the remote LLM server and, if a value other than '-'
        " is returned, go head and build out the authorization header we'll need to pass to our cURL call later.
        let l:auth_token = s:util.GetAuthToken(l:parse_dictionary)
        if l:auth_token != '-'
            let l:auth_header = "Authorization: Bearer " .. l:auth_token
        endif


        " Now build up the 'cURL' command that we will use to submit the chat request to the remote server.
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
        let l:curl_command = "curl -X POST " ..
                           \ "--header \"Content-Type: application/json; charset=" .. &encoding .. "\" " ..
                           \ "--data \"@" .. l:request_payload_filename .. "\" " ..
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
            " them to the debug output collected.
            let l:curl_command = l:curl_command .. "--dump-header \"" .. l:response_header_filename .. "\" "

        endif

        let l:curl_command = l:curl_command .. l:header_dict[s:util.PARSE_DICTIONARY_HEADER_SERVER_URL] .. l:api_path


        " If debug mode is enabled then create a debug message that details the curl call we're about to run.
        if s:util.IsDebugEnabled()
            let l:debug_message = "Curl call to be used for submitting chat request to the remote LLM server:\n\n" ..
                                \ l:curl_command .. "\n\n"

            call s:util.WriteToDebug(l:debug_message)
        endif


        " Call out to a utility function to handle setting up the cURL command execution as an asynchronous job.  If we
        " attempted to execute such command here using something like the system() function it will cause Vim to become
        " unresponsive until the command has completed.  LLM requests can take some time ESPECIALLY when the request
        " goes to a locally hosted model.  We don't want to block the user during this time, and Vim has no asynchronous
        " support for Vimscript execution, so this is pretty much our only viable option.
        "
        " NOTE: We use a utility function rather than call job_start() directly here because we want an abstracted point
        "       of bypass for test executions.  Running the actual cURL call isn't practical inside any test as it would
        "       require access to an actual LLM server to complete successfully.  Test executions can manipulate the
        "       operation of the utility function used so that it doesn't actually perform a job submission but instead
        "       adds the details of what it *would* have submitted to the chat execution dictionary instead (a test can
        "       then retrieve the chat execution dictionary to access such values for validation).
        "
        let l:job_options_dict = {
                               \   "out_cb": function("LLMChat#send_chat#SpoolChatExecStdOut"),
                               \   "exit_cb": function("LLMChat#send_chat#HandleChatResponse"),
                               \   "out_mode": "nl"
                               \ }

        call LLMChat#send_chat#SubmitChatExecJob(l:curl_command, l:job_options_dict)

        if ! exists("g:llmchat_test_bypass_mode") || g:llmchat_test_bypass_mode == ''
            " If the logic comes here we will assume that this code is NOT being run from the context of a test; output
            " a message to the user letting them know that the chat request is being submitted.
            echo "Submitting chat request to remote server..."

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
        " properly surface it.  If it appears that a test is NOT running than just echo the fault out for the user to
        " review.
        if exists("g:llmchat_test_bypass_mode")
            throw v:exception
        else
            echom v:exception
        endif

    endtry

endfunction


" This function serves as a point of abstraction between the code in this script that submits chat interaction jobs and
" Vim's asynchronous job framework.  In general it only exists so that tests can bypass the asynchronous submission of
" a job and may instead retrieve the information created for the job submission in order to verify behavior.  For a
" test to perform this bypass it MUST set global variable 'g:llmchat_test_bypass_mode' to a value of 1 indicating that
" jobs should NOT be submitted for real execution and instead argument information passed to the function should instead
" be bound to the "chat execution dictionary" currently in use.  When such global variable is NOT set than this
" function will perform some basic state sanity checks and will submit the given job for execution on the system.
"
" For detailed information on the asynchronous job framework see 'help channel.txt'.
"
" Arguments:
"   command - The system command to be executed by the asynchronous job framwork.
"   job_options_dict - A dictionary that provides supporting information to the asynchronous job framework execution
"                      such as the output mode to use, handler functions to call during the execution, etc.
"
" Throws: An exception will be thrown if this function is invoked and the "chat execution dictionary" bound to variable
"         's:curr_chat_exec_dict' is either empty or non-existant.  It is the job of any caller of this function to
"         ensure that such dictionary is properly initialized as part of the setup for submitting a chat request to
"         a remote server.
"
function LLMChat#send_chat#SubmitChatExecJob(command, job_options_dict)
    " Make sure the 's:curr_chat_exec_dict' variable is NOT undefined or empty before proceeding; if this is undefined
    " or empty it means that we don't have the proper context setup for a chat execution submission and we'll throw an
    " exception.
    if ! exists("s:curr_chat_exec_dict") || empty(s:curr_chat_exec_dict)
        throw "[ERROR] - The chat execution dictionary associated with the submission job to be run either did not " ..
            \ "exist or held no content.  Either case indicates a code fault in the plugin that should be reported " ..
            \ "for investigation."
    endif

    " Now check to see if global variable "g:llmchat_test_bypass_mode" has been set to 1; if so we will just write
    " the details about the job we *would* have created to the 's:curr_chat_exec_dict'.  If this variable is NOT set
    " or is set to a value other than 1 we will proceed with creating a job for executing the chat request.
    if exists("g:llmchat_test_bypass_mode") && g:llmchat_test_bypass_mode
        " In this case we will not submit the actual job but will instead append information intended for the job to
        " the 's:curr_chat_exec_dict'.
        let s:curr_chat_exec_dict[s:CURR_CHAT_EXEC_DICT_CAPTURE_COMMAND] = a:command
        let s:curr_chat_exec_dict[s:CURR_CHAT_EXEC_DICT_CAPTURE_JOB_OPTS] = a:job_options_dict

    else
        " If the logic comes here than we will proceed forward with creating a new job to execute the chat request.
        " Once the job is submitted we will attach the returned job reference to the 's:curr_chat_exec_dict' so that
        " the job can be tracked/managed.
        let s:curr_chat_exec_dict[s:CURR_CHAT_EXEC_DICT_JOB_ID] = job_start(a:command, a:job_options_dict)

    endif

endfunction


" This function is used to handle information written to the standard output stream during the asynchronous execution
" of a chat submission job.  Currently such content, assumed to be passed as argument 'message', is collected into the
" current "chat execution dictionary" for later processing by the post-response logic which will be invoked on
" completion of the job.
"
" Arguments:
"   channel - The channel associated with the job execution; currently unused.
"   message - The message content that was written to the standard output stream.
"
function LLMChat#send_chat#SpoolChatExecStdOut(channel, message)
    " Append the 'message' we received to the 's:CURR_CHAT_EXEC_DICT_STDOUT' field on the 's:curr_chat_exe_dict'
    " dictionary.  Note that if such field holds no content we will simply set the message to be the field value and if
    " the field already held content we will append a newline before adding the message to the existing information.
    if has_key(s:curr_chat_exec_dict, s:CURR_CHAT_EXEC_DICT_STDOUT)
        let s:curr_chat_exec_dict[s:CURR_CHAT_EXEC_DICT_STDOUT] = s:curr_chat_exec_dict[s:CURR_CHAT_EXEC_DICT_STDOUT] ..
                                                                \ a:message
    else
        let s:curr_chat_exec_dict[s:CURR_CHAT_EXEC_DICT_STDOUT] = a:message
    endif

endfunction


" This function can be invoked to abort any currently executing chat submission job.  When run, the function will check
" any existing "chat execution dictionary" bound to variable 's:curr_chat_exec_dict' to see if the ID for a running
" job is present and if so it will invoke the appropriate job functions to terminate such job.  If no chat execution
" dictionary exists, if such dictionary contains no job ID, or if the job ID held does not belong to a running job than
" only cleanup actions will be taken by the execution.  Because execution of this function is safe regardless of the
" job state it may also be used to ensure that state associated with a chat submission is cleaned up (in particular
" during testing where job execution flows are intentionally broken up to reduce scope and provide necessary
" inspection).
"
" Note that when this function is executed and variable "g:llmchat_test_bypass_mode" has been set to a value of 1 than
" it will suppress user information messages that would otherwise be output (namely because such messages require
" user acknowledgment and when testing such acknowledgment is unwanted).
"
function LLMChat#send_chat#AbortRunningChatExec()
    " Check to see if variable 's:curr_chat_exec_dict' is defined and non-empty before trying to take any action.  If
    " this is undefined or is simply an empty dictionary we will output a message indicating that no job exists to
    " abort before exiting.
    if exists("s:curr_chat_exec_dict") && ! empty(s:curr_chat_exec_dict)
        " Now check to see if the 's:curr_chat_exec_dict' has a key referencing a job and if so is the job being
        " referenced still running.
        if has_key(s:curr_chat_exec_dict, s:CURR_CHAT_EXEC_DICT_JOB_ID) &&
         \ job_status(s:curr_chat_exec_dict[s:CURR_CHAT_EXEC_DICT_JOB_ID]) == "run"
            " If the logic comes here than we've found a running job; attempt to abort it through the job_stop()
            " function
            call job_stop(s:curr_chat_exec_dict[s:CURR_CHAT_EXEC_DICT_JOB_ID], "int")
            echo "Aborting currently running chat submission job..."

            " We will now assume that the job is dead or that it will be soon; go ahead and clear out all content
            " held by the 's:curr_chat_exec_dict' so that the plugin logic no longer sees a chat submission as running.
            "
            " NOTE: Currently we assume that Vim has issued the process signal before the job_stop() function returns
            "       AND that is has already marked the job as "dead".  If these assumptions are not true and there is
            "       some asynchronous action that does not occur before the function exits than we may need to revisit
            "       this.
            "
            let s:curr_chat_exec_dict = {}

        else
            " In this case there wasn't any running job but we did have a dirty dictionary.  Output a message to the
            " user that any prior job has completed and cleanup the content of the 's:curr_chat_exec_dict' by assigning
            " an empty dictionary to it.
            "
            " Edge Case - During testing this function will be called to cleanup the chat execution dictionary state and
            "             we don't want to echo any user messages in that context.  Look to see if variable
            "             "g:llmchat_test_bypass_mode" has been defined and set to 1 and if so just quietly cleanup the
            "             dictionary.
            "
            if ! exists("g:llmchat_test_bypass_mode") || ! g:llmchat_test_bypass_mode
                echom "[INFO] - Prior job completed before aborting; no further action to take."
            endif

            let s:curr_chat_exec_dict = {}

        endif

    else
        echom "[INFO] - There is no currently running chat submission to abort; no action taken."

    endif

endfunction


" This is a utility function for returning a copy of the current "chat execution dictionary" to the caller.  In general
" this function only exists for testing purposes as accessing the dictionary is not possible from a separate testing
" script without such a function.
"
" Returns: Returns a copy of the current chat execution dictionary; if no such dictionary exists than an empty
"          dictionary will be returned instead.
"
function LLMChat#send_chat#GetCurrChatExecDict()

    if exists("s:curr_chat_exec_dict")
        return s:curr_chat_exec_dict
    else
        return {}
    endif

endfunction


" This function allows a custom "chat execution dictionary" to be set on script variable 's:curr_chat_exec_dict'.  IT
" IS IMPORTANT TO NOTE THAT THIS FUNCTION SHOULD ONLY BE USED BY TESTS AS IT IS NOT DESIGNED FOR USE OUTSIDE THIS
" PUROSE (FOR EXAMPLE IT DOES NOT ADDRESS CANCELLATION OF RUNNING JOBS, CLEANUP OF ANY EXISTING DICTIONARY, ETC).  As
" with the GetCurrChatExecDict() function it is here primarly to address the issue that chat execution dictionaries are
" attached to a script local variable that cannot be accessed from a separate testing script.
"
" Arguments:
"   custom_exec_dict - The custom execution dictionary that should be set by this function as the current chat execution
"                      dictionary.
"
function LLMChat#send_chat#SetCurrChatExecDict(custom_exec_dict)
    " Simply set the 'custom_dict' argument given as the chat execution dictionary that should be bound to this script.
    let s:curr_chat_exec_dict = a:custom_exec_dict

endfunction


" This function should be called by the asynchronous job framework in Vim once a submitted chat request has been
" completed.  During execution the function will process the content returned in the chat response then it will format
" relevant response data and use it to update the chat document that the request was submitted from.
"
" Arguments:
"   job_id - The ID for the completed chat request job; note that currently function does not use the value provided for
"            any purpose.
"   exit_status - The exit status of the cURL command execution used to submit the chat request to the remote LLM
"                 server.  Note that any value provided other than 0 will be assumed to indicate an abnormal command
"                 exit and an exception will be thrown.
"
" Throws: An exception if either (1) the cURL call used to submit the chat request exited abnormally or (2) the
"         received response indicated via HTTP status return that it was not successful.
"
function LLMChat#send_chat#HandleChatResponse(job_id, exit_status)
    " Check if the 's:curr_chat_exec_dict' is empty and if so than quietly exit.  This will happen if a chat submission
    " was requested and then aborted leaving us with nothing to do.
    if empty(s:curr_chat_exec_dict)
        return
    endif

    try
        " Create some local variables that will hold information that was bootstrapped through the
        " 's:curr_chat_exec_dict' dictionary specifically for use by the post-response processing logic here.  Note that
        " this isn't strictly required but it makes referencing these values easier than specifying the dictionary path
        " each time they're needed.
        let l:chat_buff_num = s:curr_chat_exec_dict[s:CURR_CHAT_EXEC_DICT_BUFFER_NUM]
        let l:buff_text_width = str2nr(s:curr_chat_exec_dict[s:CURR_CHAT_EXEC_DICT_BUFFER_TEXTWIDTH])
        let l:curr_chat_buffer_lines = str2nr(s:curr_chat_exec_dict[s:CURR_CHAT_EXEC_DICT_BUFFER_LINECNT])
        let l:parse_dictionary = s:curr_chat_exec_dict[s:CURR_CHAT_EXEC_DICT_PARSE_DICT]
        let l:header_dict = l:parse_dictionary[s:util.PARSE_DICTIONARY_HEADER_KEY]
        let l:server_type = l:header_dict[s:util.PARSE_DICTIONARY_HEADER_SERVER_TYPE]
        let l:request_payload_filename = s:curr_chat_exec_dict[s:CURR_CHAT_EXEC_DICT_REQUEST_FILENAME]
        let l:response_payload_filename = s:curr_chat_exec_dict[s:CURR_CHAT_EXEC_DICT_RESPONSE_FILENAME]

        if has_key(s:curr_chat_exec_dict, s:CURR_CHAT_EXEC_DICT_RESPONSE_HEADER_FILENAME)
            let l:response_header_filename = s:curr_chat_exec_dict[s:CURR_CHAT_EXEC_DICT_RESPONSE_HEADER_FILENAME]
        endif


        " Retrieve the spooled standard output stream information from the chat execution dictionary and use this as
        " the HTTP status code returned by the command.
        let l:http_status_code = ''
        if has_key(s:curr_chat_exec_dict, s:CURR_CHAT_EXEC_DICT_STDOUT)
            let l:http_status_code = s:curr_chat_exec_dict[s:CURR_CHAT_EXEC_DICT_STDOUT]
        endif


        " If debug messaging was enabled then write out the full response received; headers and payload.
        if s:util.IsDebugEnabled()
            let l:response_header_filename = s:curr_chat_exec_dict[s:CURR_CHAT_EXEC_DICT_RESPONSE_HEADER_FILENAME]

            let l:debug_message = "Response Data Received:" ..
                              \ "\n  Headers:" ..
                              \ "\n  -----------------"

            if(filereadable(l:response_header_filename))
                let l:debug_message = l:debug_message .. "\n" .. join(readfile(l:response_header_filename), "\n")
            else
                let l:debug_message = l:debug_message .. "\n  <Unavailable>"
            endif

            let l:debug_message = l:debug_message ..
                             \ "\n" ..
                             \ "\n  Payload Data:" ..
                             \ "\n  -----------------"

            if(filereadable(l:response_payload_filename))
                let l:debug_message = l:debug_message .. "\n" .. join(readfile(l:response_payload_filename), "\n")
            else
                let l:debug_message = l:debug_message .. "\n  <Unavailable>"
            endif

            let l:debug_message = l:debug_message .. "\n\n"

            call s:util.WriteToDebug(l:debug_message)
        endif


        " Begin verifying the outcome of the request by checking the exit status of the cURL command that should be held
        " by argument 'exit_status'.  If this is any value other than 0 we will assume that the request was unsuccesful.
        if a:exit_status != 0
            throw "[ERROR] - The cURL call used to submit the chat request to the remote LLM server returned with " ..
                \ "a non-zero exit status; due to this condiition it is generally assumed that such call failed.  " ..
                \ "Additional details about this issue are provided below:\n" ..
                \ "Exit Status: " .. a:exit_status .. "\n" ..
                \ "Standard Out:\n" .. l:http_status_code
        endif


        " Now check to see if the HTTP status code we received back was 200; if not than we assume that the request
        " was unsuccessful and we will throw an exception.
        if l:http_status_code != 200
            throw "[ERROR] - The HTTP status code returned for the chat request was not equal to 200 and due to " ..
                \ "this it is assumed that such request was unsuccessful.  Additional details regarding this fault " ..
                \ "are provided below:\n" ..
                \ "HTTP Status: " .. l:http_status_code .. "\n" ..
                \ "Response Payload:\n" .. join(readfile(l:response_payload_filename), "\n")
        endif


        " If the logic reaches this point than we assume that the request was successful and that we got back a payload
        " containing the assistant response message.  Call down to an appropriate helper function, depending on the
        " type of server we're interacting with, to parse the response and update the chat buffer.
        "
        if l:server_type ==? "ollama"
            let l:response_dict = LLMChat#send_chat#ProcessOllamaChatResponsePayload(l:response_payload_filename)

        else
            " In this case we assume that the server type must be "open webui".  Why don't we validate this rather
            " than assume it?  Earlier in the processing we should have done exactly that when the request payload
            " was created and any unrecognized server type would have already prompted an exception.  At this point in
            " the code we should therefore only have recognized server type values and any error block for an unknown
            " type would be unreachable.
            let l:response_dict = LLMChat#send_chat#ProcessOpenWebUIChatResponsePayload(l:response_payload_filename)

        endif


        " Define a counter that will track how we need to move the cursor within the chat buffer so that the new
        " assistant message becomes visible for reading.  Note that we will start the new cursor line at the last
        " line known to be in the buffer *before* we output the assistant message then we will update this value
        " with relative line moves as be build out the assistant response.  Once the assistant message has been written
        " (and therefore all changes to be made to this value are complete) we will move the cursor.
        let l:new_cursor_line = l:curr_chat_buffer_lines


        " Check to see if a "message register" has been specified for use; if so (i.e., if a non-empty register name
        " can be found) than we will copy the full LLM response message into the register.
        "
        " NOTE: Unlike the message insertion into the chat later, we will NOT pre-format the message to ensure that
        "       line length is within set limits.  We do not know what the user will do with the register content or
        "       what line limits (if any) exist in a buffer they may paste this content to so it doesn't make sense
        "       to enforce limits from the chat log arbitrarily here.
        "
        let l:message_register = GetMessageRegister(l:parse_dictionary)
        if !empty(l:message_register)
            call setreg(l:message_register, l:response_dict[s:COMMON_RESP_DICT_MESSAGE])
        endif


        " Create a list that will hold the full response we want to write back to the chat buffer as sequence of text
        " "lines".  The issue here is that the appendbufline() function does not seem to like newlines within the
        " strings you give to it (instead it will escape these which messes up your output) but the function will
        " happily accept a list of lines to insert from a list.  It is therefore easier to gather up the sequence of
        " lines we want to insert rather than one giant string representing multiple lines delimited by newline
        " sequences.
        let l:response_lines_list = []


        " Check to see if a flags dictionary exists within the 'l:parse_dictionary'; if so than we need to retrieve it
        " and look for conditions that need to be addressed before we add the assistant response to the chat.
        if has_key(l:parse_dictionary, s:util.PARSE_DICTIONARY_PARSE_FLAGS)
            " Retrieve the flags dictionary and assign this to a local variable for easier reference in the code that
            " follows.
            let l:flags_dictionary = l:parse_dictionary[s:util.PARSE_DICTIONARY_PARSE_FLAGS]

            " Check to see if the flags dictionary holds a key matching to the value held by constant
            " 's:util.PARSE_FLAG_NO_USER_MSG_CLOSE'; if so than we need to add the closing delimiter to the user message
            " before appending further content in the chat buffer.
            "
            " NOTE: The value for this particular flag has no significance; its existence within the flags dictionary
            "       is what implies that the condition exists.
            "
            if has_key(l:flags_dictionary, s:util.PARSE_FLAG_NO_USER_MSG_CLOSE)
                call add(l:response_lines_list, "<<<")
                call add(l:response_lines_list, '')

                " Make sure to add 2 to the current value of 'l:new_cursor_line' so that we account for these extra
                " output lines.
                let l:new_cursor_line = l:new_cursor_line + 2

            endif

        endif


        " Build up the separator bar that will be used between chats then save the result into a local variable.  The
        " size of this bar is configurable so we will dynamically generate it when needed.
        let l:separator_bar = ''    "No separator bar by default
        for curr_cntr in range(1, g:llmchat_separator_bar_size, 1)
            let l:separator_bar = l:separator_bar .. '-'
        endfor


        " Check to see if the user has enabled the "show reasoning" option for the chat and if so we will see if any
        " 'thinking' message was returned by the remote server.  If such option is set AND a thinking message is present
        " than we will append this as a special comment that immediately preceeds the actual response.
        if has_key(l:header_dict, s:util.PARSE_DICTIONARY_HEADER_SHOW_THINKING) &&
         \ l:header_dict[s:util.PARSE_DICTIONARY_HEADER_SHOW_THINKING] ==? "true" &&
         \ has_key(l:response_dict, s:COMMON_RESP_DICT_THINKING)
            " If the logic comes here than the "show reasoning" option was enabled and our response contains a
            " "thinking" message that we can output.  Take the following steps to process such message so it can
            " be written out to the chat buffer:
            "
            "  1). Call a utility function that will take the full message string and return back to us a series
            "      of width formatted lines appropriate for appending.
            "  2). Add a line having the special token "#=>> REASONING" to the 'l:response_lines' list.
            "  3). Add all width formatted lines making up the "thinking" message to the 'l:response_lines' list.
            "      Note that when we do this we will prefix each line with a '# ' character making the line a comment.
            "  4). Add a line having the special token "#<<= REASONING" to the 'l:response_lines' list as the final
            "      delimiter for the "thinking" message.
            "
            " NOTE: Since we will be adding the prefix '# ' to each line we will need to subtract 2 from the line
            "       formatting width used so that the message fits correctly within the expected width.
            "
            let l:raw_thinking_message = l:response_dict[s:COMMON_RESP_DICT_THINKING]
            let l:thinking_lines =  s:util.FormatTextLines(l:raw_thinking_message, l:buff_text_width - 2)

            call add(l:response_lines_list, "#=>> REASONING")

            for l:curr_thinking_line in l:thinking_lines
                call add(l:response_lines_list, "# " .. l:curr_thinking_line)
            endfor

            call add(l:response_lines_list, "#<<= REASONING")

        endif


        " Now assemble the full assistant response, including the start and end delimiters, for the chat message and
        " split the assembled result into lines appropriately sized for the chat buffer then add the resulting series of
        " text lines to the 'l:response_lines_list'.  Note that in this case it is easiest to assemble first and then
        " split into lines because the assistant message may itself contain newline separators.  By waiting until the
        " message is completely assembled we can handle the split and line cleanup as a single function call.
        let l:response_text = "=>>"
        if g:llmchat_assistant_message_follow_style
            let l:response_text = l:response_text .. ' '
        else
            let l:response_text = l:response_text .. "\n"

            " Since we're adding an extra newline here go ahead and increment the value held by variable
            " 'l:new_cursor_line' by 1 as well.
            let l:new_cursor_line = l:new_cursor_line  + 1
        endif


        " NOTE: Make sure to escape any special character sequences (i.e., things like '<<<', '>>>', etc) found within
        "       the assistant response BEFORE appending it to the 'l:response_text' value.
        let l:escaped_assist_msg = s:util.EscapeSpecialSequences(l:response_dict[s:COMMON_RESP_DICT_MESSAGE])


        " NOTE: Always include the opening delimiter for a new user message immediately after the assistant message.
        "       This ensures that the user is ready to begin typing a new chat right after we've posted a response.
        let l:response_text = l:response_text .. l:escaped_assist_msg ..
                            \ "\n<<="  ..
                            \ "\n" .. l:separator_bar ..
                            \ "\n>>> "

        for l:curr_text_line in s:util.FormatTextLines(l:response_text, str2nr(l:buff_text_width))
            call add(l:response_lines_list, l:curr_text_line)
        endfor


        " Append all text lines collected in the 'l:response_lines_list' to the bottom of the chat buffer.
        call appendbufline(l:chat_buff_num, '$', l:response_lines_list)


        " Add 1 to the value held by variable 'l:new_cursor_line' so that we position the cursor on the first line of
        " the output assistant message.
        let l:new_cursor_line = l:new_cursor_line + 1


        " Move the cursor to the start of the assistant message so the user can see something happened.
        call setpos('.', [l:chat_buff_num, l:new_cursor_line, 0, 0])


        " Cleanup after the interaction by removing the request and response payload files from the system (if a header
        " file was created by debug mode than we should remove that as well).
        call delete(l:request_payload_filename)
        call delete(l:response_payload_filename)
        if has_key(s:curr_chat_exec_dict, s:CURR_CHAT_EXEC_DICT_RESPONSE_HEADER_FILENAME)
            call delete(s:curr_chat_exec_dict[s:CURR_CHAT_EXEC_DICT_RESPONSE_HEADER_FILENAME])
        endif


        " If the logic reaches this point than we assume that the chat interaction was completed successfully; output a
        " debug message indicating this.
        call s:util.WriteToDebug("Chat interaction completed successfully!")

    catch /\v.*/
        " If the logic comes here than we assume an exception was encountered outside the context of testing while
        " trying to execute an LLM interaction; display the exception message using 'echom' then take no further action.
        if s:util.IsDebugEnabled()
            call s:util.WriteToDebug("Chat interaction failed: " .. v:exception)
        endif

        " Check to see if the 'g:llmchat_test_bypass_mode' variable has been set to a non-empty value; if so we will
        " assume that this function is being called by a test and we will re-throw the caught exception in order to
        " properly surface it.  If it appears that we're NOT in the context of a running test than simply echo the
        " fault out for the user to review.
        if exists("g:llmchat_test_bypass_mode")
            throw v:exception
        else
            echom v:exception
        endif

    endtry

endfunction


" This function is responsible for creating a chat request payload appropriate for submission to an Ollama server.  Note
" that both streaming and non-streaming modes are supported and which mode is used will depend on the value set for
" variable "g:llmchat_use_streaming_mode" at the time of invocation.  The generated response will be written to the file
" whose path and name are provided as argument 'output_filename'.
"
" Arguments:
"   parse_dictionary - A parse dictionary that contains the full information for the current chat.  For details on the
"                      content and structure for such dictionary please refer the documentation for function
"                      ParseChatBufferToBlocks() in file 'import/utils.vim'.
"   output_filename - The name and path to the file that this function should write its generated request payload to.
"
function LLMChat#send_chat#CreateOllamaChatRequestPayload(parse_dictionary, output_filename)
    " Retrieve the header dictionary from the 'parse_dictionary' argument provided and store this into a local variable;
    " this will make retrieval of the items it holds more convenient in the code that follows.
    let l:header_dict = a:parse_dictionary[s:util.PARSE_DICTIONARY_HEADER_KEY]


    " Retrieve the list of messages to be included into the request and store this into a local variable.  Note that we
    " will call out to a utility function to retreive this list for us (rather than take it directly from the parse
    " dictionary passed to this function) since it is possible that context limiting configurations are in use and we
    " may not be using all messages from the chat history.
    let l:message_array = LLMChat#send_chat#GetMessageContext(a:parse_dictionary)


    " Resolve the "thinking" value to be used on the request to the Ollama server.
    let l:thinking_value = has_key(l:header_dict, s:util.PARSE_DICTIONARY_HEADER_SHOW_THINKING) ?
                          \ l:header_dict[s:util.PARSE_DICTIONARY_HEADER_SHOW_THINKING] :
                          \ v:false

    " Special Cases - If the "thinking" value is equal to the string literal "true" or "false" than we will need to
    "                 change the value representation to have this properly encoded as a boolean within the JSON
    "                 generated later.  Currently Vim will see both of these as string literals which will wind up as
    "                 a quoted string if we did not take action.
    if l:thinking_value ==? "true"
        let l:thinking_value = v:true
    elseif l:thinking_value ==? "false"
        let l:thinking_value = v:false
    endif


    " Create a dictionary that will define the content and tree form of the JSON to be submitted to the remote LLM
    " server as the chat request payload.
    let l:json_dict = { }


    " Add the top level field values for model, thinking, and request streaming.
    let l:json_dict["model"] = l:header_dict[s:util.PARSE_DICTIONARY_HEADER_MODEL_ID]
    let l:json_dict["think"] = l:thinking_value
    let l:json_dict["stream"] = (g:llmchat_use_streaming_mode ? v:true : v:false)


    " Add all messages held by the parse dictionary into a list that will then be embedded into the 'json_dict'.  Note
    " that each entry within the list will be its own dictionary and will contain fields for the user, assistant, and
    " possibly system messages.
    let l:json_message_list = [ ]

    if has_key(l:header_dict, s:util.PARSE_DICTIONARY_HEADER_SYSTEM_PROMPT)
        call add(l:json_message_list,
               \ {
               \   "role": "system",
               \   "content": l:header_dict[s:util.PARSE_DICTIONARY_HEADER_SYSTEM_PROMPT]
               \ })
    endif

    for l:curr_message_dict in l:message_array
        call add(l:json_message_list,
               \ {
               \   "role": "user",
               \   "content": l:curr_message_dict[s:util.PARSE_DICTIONARY_USER_MSG_KEY]
               \ })

        if has_key(l:curr_message_dict, s:util.PARSE_DICTIONARY_ASSISTANT_MSG_KEY)
            call add(l:json_message_list,
                   \ {
                   \   "role": "assistant",
                   \   "content": l:curr_message_dict[s:util.PARSE_DICTIONARY_ASSISTANT_MSG_KEY]
                   \ })
        endif

    endfor

    let l:json_dict["messages"] = l:json_message_list


    " Create a new "options" dictionary that will hold any options specified in the chat for the remote LLM.  Once all
    " option values are added we will bind the dictionary into the 'json_dict'.
    "
    " Why don't we just bind the options dictionary held by the 'header_dict' straight into the 'json_options_dict'?
    " Afterall we expect the keys in such dictionary to match to the JSON name values and the option values should
    " already be formatted (as per requirement in the plugin documentation)?  The reason why we don't do this has to do
    " with how Vim handles the conversion of Vim types into JSON types and nuances like no boolean type existing in
    " Vimscript.  For a more indepth explanation see the documentation for function GetOptionsDictForJSONOutput() which
    " we will use here to handle the details of this conversion.
    let l:json_options_dict = GetOptionsDictForJSONOutput(l:header_dict)

    if !empty(json_options_dict)
        let l:json_dict["options"] = json_options_dict
    endif


    " Now convert the content held by the 'json_dict' variable into a JSON string and write the result out to the
    " file whose name was given to this function call.
    call writefile([json_encode(l:json_dict)], a:output_filename)

endfunction


" This function is responsible for creating a chat request payload appropriate for submission to an Open-WebUI server.
" Note that both streaming and non-streaming modes are supported and which mode is used will depend on the value set for
" variable "g:llmchat_use_streaming_mode" at the time of invocation.  The generated response will be written to the file
" whose path and name are provided as argument 'output_filename'.
"
" Arguments:
"   parse_dictionary - A parse dictionary that contains the full information for the current chat.  For details on the
"                      content and structure for such dictionary please refer to the documentation for function
"                      ParseChatBufferToBlocks() in file 'import/utils.vim'.
"   output_filename - The name and path to the file that this function should write its generated request payload to.
"
function LLMChat#send_chat#CreateOpenWebUIChatRequestPayload(parse_dictionary, output_filename)
    " Retrieve the header dictionary from the 'parse_dictionary' argument provided and store this into a local
    " variable; this will make retrieval of the items it holds more convenient in the code that follows.
    let l:header_dict = a:parse_dictionary[s:util.PARSE_DICTIONARY_HEADER_KEY]


    " Retrieve the list of messages to be included into the request and store this into a local variable.  Note that we
    " will call out to a utility function to retreive this list for us (rather than take it directly from the parse
    " dictionary passed to this function) since it is possible that context limiting configurations are in use and we
    " may not be using all messages from the chat history.
    let l:message_array = LLMChat#send_chat#GetMessageContext(a:parse_dictionary)


    " Create a dictionary that will define the content and tree form of the JSON to be submitted to the remote LLM
    " server as the chat request payload.
    let l:json_dict = { }


    " Add the top level field values for model  and request streaming.
    "
    " NOTE: The request for Open-WebUI doesn't seem to have a 'thinking' field and such information appears to be
    "       included in the response by default for models that support it.  If this is found to be wrong in the future,
    "       and there is an explicit field we should add to guarantee behavior, than the logic here should be corrected.
    "
    let l:json_dict["model"] = l:header_dict[s:util.PARSE_DICTIONARY_HEADER_MODEL_ID]
    let l:json_dict["stream"] = (g:llmchat_use_streaming_mode ? v:true : v:false)


    " Add all messages held by the parse dictionary into a list that will then be embedded into the 'json_dict'.  Note
    " that each entry within the list will be its own dictionary and will contain fields for the user, assistant, and
    " possibly system messages.
    let l:json_message_list = [ ]

    if has_key(l:header_dict, s:util.PARSE_DICTIONARY_HEADER_SYSTEM_PROMPT)
        call add(l:json_message_list,
               \ {
               \   "role": "system",
               \   "content": l:header_dict[s:util.PARSE_DICTIONARY_HEADER_SYSTEM_PROMPT]
               \ })
    endif

    for l:curr_message_dict in l:message_array
        call add(l:json_message_list,
               \ {
               \   "role": "user",
               \   "content": l:curr_message_dict[s:util.PARSE_DICTIONARY_USER_MSG_KEY]
               \ })

        if has_key(l:curr_message_dict, s:util.PARSE_DICTIONARY_ASSISTANT_MSG_KEY)
            call add(l:json_message_list,
                   \ {
                   \   "role": "assistant",
                   \   "content": l:curr_message_dict[s:util.PARSE_DICTIONARY_ASSISTANT_MSG_KEY]
                   \ })
        endif

    endfor

    let l:json_dict["messages"] = l:json_message_list


    " Create a new "options" dictionary that will hold any options specified in the chat for the remote LLM.  Once all
    " option values are added we will bind the dictionary into the 'json_dict'.
    "
    " Why don't we just bind the options dictionary held by the 'header_dict' straight into the 'json_options_dict'?
    " Afterall we expect the keys in such dictionary to match to the JSON name values and the option values should
    " already be formatted (as per requirement in the plugin documentation)?  The reason why we don't do this has to do
    " with how Vim handles the conversion of Vim types into JSON types and nuances like no boolean type existing in
    " Vimscript.  For a more indepth explanation see the documentation for function GetOptionsDictForJSONOutput() which
    " we will use here to handle the details of this conversion.
    let l:json_options_dict = GetOptionsDictForJSONOutput(l:header_dict)

    if !empty(json_options_dict)
        let l:json_dict["options"] = json_options_dict
    endif


    " Now convert the content held by the 'json_dict' variable into a JSON string and write the result out to the
    " file whose name was given to this function call.
    call writefile([json_encode(l:json_dict)], a:output_filename)


    " ======= OLD CODE STARTS HERE =====
"    let l:encoded_model_id = json_encode(l:header_dict[s:util.PARSE_DICTIONARY_HEADER_MODEL_ID])
"    let l:request_message = "{" ..
"                        \ "\n  \"model\": " .. l:encoded_model_id .. "," ..
"                        \ "\n  \"stream\": " .. (g:llmchat_use_streaming_mode ? "true" : "false") .."," ..
"                        \ "\n  \"messages\":" ..
"                        \ "\n    ["
"
"    let l:is_first_message = 1   " Will be used to control when commas are inserted after array elements.
"    if has_key(l:header_dict, s:util.PARSE_DICTIONARY_HEADER_SYSTEM_PROMPT)
"        " NOTE: Make sure to retrieve the system prompt text and escape any " characters it might contain with \" before
"        "       appending the text to the JSON request payload.
"        let l:escaped_system_prompt = json_encode(l:header_dict[s:util.PARSE_DICTIONARY_HEADER_SYSTEM_PROMPT])
"        let l:request_message = l:request_message ..
"                     \ "\n      {" ..
"                     \ "\n        \"role\": \"system\"," ..
"                     \ "\n        \"content\": " .. l:escaped_system_prompt ..
"                     \ "\n      }"
"
"        " Set the 'l:is_first_message' variable to 0 since our first message was the system prompt.
"        let l:is_first_message = 0
"
"    endif
"
"    for l:curr_message_dict in l:message_array
"        " Use the 'l:is_first_message' flag to determine whether or not we append a trailing comma character to the
"        " message block being created.  When set to 1 we will skip adding the comma and will instead just change the
"        " value to 0; when the value is 0 we will add a comma BEFORE the next message block.
"        if l:is_first_message
"            let l:is_first_message = 0
"        else
"            let l:request_message = l:request_message .. ","
"        endif
"
"        " NOTE: Make sure to retrieve the user message text and escape any " characters it might contain with \" before
"        "       appending the text to the JSON request payload.
"        let l:escaped_user_msg = json_encode(l:curr_message_dict[s:util.PARSE_DICTIONARY_USER_MSG_KEY])
"        let l:request_message = l:request_message ..
"                     \ "\n      {" ..
"                     \ "\n        \"role\": \"user\"," ..
"                     \ "\n        \"content\": " .. l:escaped_user_msg ..
"                     \ "\n      }"
"
"        if has_key(l:curr_message_dict, s:util.PARSE_DICTIONARY_ASSISTANT_MSG_KEY)
"            " NOTE: Make sure to retrieve the assistant message text and escape any " characters it might contain with
"            "       \" before appending the text to the JSON request payload.
"            let l:escaped_assistant_msg = json_encode(l:curr_message_dict[s:util.PARSE_DICTIONARY_ASSISTANT_MSG_KEY])
"            let l:request_message = l:request_message .. "," ..
"                         \ "\n      {" ..
"                         \ "\n        \"role\": \"assistant\"," ..
"                         \ "\n        \"content\": " .. l:escaped_assistant_msg ..
"                         \ "\n      }"
"        endif
"
"    endfor
"
"    let l:request_message = l:request_message .. "\n    ]"
"
"    if has_key(l:header_dict, s:util.PARSE_DICTIONARY_HEADER_OPTIONS_DICT)
"        let l:request_message = l:request_message .. "," ..
"                         \ "\n  \"options\":" ..
"                         \ "\n    {"
"
"        " NOTE: Iterating through a dictionary in Vim does not seem to have a defined ordering and this makes it
"        "       difficult to reliably verify behavior in testing.  To combat this we will always apply options in sorted
"        "       order of the keys held by the option dictionary and that way the addition of options to the output
"        "       document should always be consistent.
"        let l:first_option = 1
"
"        let l:options_dict = l:header_dict[s:util.PARSE_DICTIONARY_HEADER_OPTIONS_DICT]
"        let l:sorted_option_keys = sort(keys(l:options_dict))
"
"        for l:option_key in l:sorted_option_keys
"            let l:option_value = l:options_dict[l:option_key]
"
"            " Use the 'l:first_option' variable to determine when we should insert a comma character.  When this
"            " variable is set to 1 we won't add a comma and will instead just flip its value to 0; when set to 0 we will
"            " add a comma BEFORE the next option field.
"            if l:first_option
"                let l:first_option = 0
"            else
"                let l:request_message = l:request_message .. ','
"            endif
"
"            " NOTE: We do NOT surround the 'l:option_value' with quotes because we don't know what type of option
"            "       we've got.  For instance options whose data type is number or boolean should be written to the
"            "       document verbatim whereas strings should be quoted.  We assume that if the value is supposed to be a
"            "       string type than the option value is already quoted (meaning the user quotes this inside the chat
"            "       document header when they define the option; eg. 'Option: name="value"').
"            let l:request_message = l:request_message ..
"                                  \ "\n      \"" .. l:option_key .. "\": " .. l:option_value
"
"        endfor
"
"        let l:request_message = l:request_message .. "\n    }"
"
"    endif
"
"    let l:request_message = l:request_message .. "\n}"
"
"    " Output the request payload to the specified file and return.
"    call writefile(split(l:request_message, "\n"), a:output_filename)
"
endfunction


" This function will parse the content of an LLM response returned from an Ollama server and will return the result
" as a "common" dictionary (see the documentation for constants at the bottom of this script file for details on the
" content and structure for such dictionary).  Parsing of responses from both streaming and non-streaming interaction
" modes are supported and the logic within the function will use the current value assigned to variable
" 'g:llmchat_use_streaming_mode' to determine which mode to expect the response data to be in.
"
" Arguments:
"   payload_filepath - The path and name of a file that contains the LLM response payload that this function should
"                      parse.
"
" Returns:
"   A "common" dictionary that contains the content of the parsed response.
"
function LLMChat#send_chat#ProcessOllamaChatResponsePayload(payload_filepath)
    " Define some variables that will be used to collect the information we care about from the response.  Later we
    " will take the values held by these variables and incorporate them into a dictionary that can be given back to
    " the caller.
    let l:assistant_message = ''
    let l:assistant_thinking = ''


    " Now determine how we should process the response based on whether or not we are using "streaming" mode.
    if(g:llmchat_use_streaming_mode)
        " If the logic comes here than streaming mode is in effect and we expect to see the file at 'payload_filepath'
        " contain a series of server responses.  Each response in the file will be on its own line and the order of
        " responses within the file (from beginning to end) will match the order of the fragments within the message we
        " need to reconstruct for the user.  Note that if "thinking" mode was enabled on the model than we will see
        " the same kind of fragments (and in the same ordering) as for the final message.  An example JSON showing the
        " general format for received streaming messages is pasted below (note that this message has been formatted
        " across lines for readability; when received back from the Ollama server this response will all appear on a
        " single line):
        "
        "  {
        "   "model":"starcoder2:3b",
        "   "created_at":"2025-12-19T20:33:37.715275887Z",
        "   "message":
        "     {
        "       "role":"assistant",
        "       "content":"I"
        "     },
        "     "done":false
        "   }
        "
        let l:response_payload_list = readfile(a:payload_filepath)  " Read in file as a series of lines

        let l:first_message = 1          " Used for coordinating the collected start/end response timestamps.

        " Iterate over all lines in the 'l:response_payload_list' and treat each one as its own complete JSON response.
        for l:curr_response_json in l:response_payload_list

            " Decode the current response into a Vim dictionary so we can easily access its contents.
            let l:response_dict = json_decode(l:curr_response_json)

            " Now extract the "message" dictionary from the response and append any assistant response fragment it may
            " contain to the end of the 'l:assistant_message' variable.
            let l:message_dict = l:response_dict["message"]

            if has_key(l:message_dict, "content")
                let l:assistant_message = l:assistant_message .. l:message_dict["content"]
            endif

            " Check to see if the "message" dictionary contains a "thinking" fragment as well and if so append it to the
            " end of the 'l:assistant_thinking' variable.
            if has_key(l:message_dict, "thinking")
                let l:assistant_thinking = l:assistant_thinking .. l:message_dict["thinking"]
            endif

            " Now handle collection of the response time information.  If this is the first loop iteration (i.e., if
            " variable 'l:first_message' is 1) than we will save the the 'created_at' value found in the response as the
            " initial response timestamp.  If this is NOT the first loop iteration than we will retrieve the
            " 'created_at' value and use it to overwrite any value held by variable 'l:final_response_time'; this will
            " leave such variable set to the 'created_at' value found in the last response processed once the loop
            " exits.
            if l:first_message
                let l:initial_response_time = l:response_dict["created_at"]
                let l:first_message = 0

                " Edge Case - Go ahead and initialize 'l:final_response_time' to be the same as
                "             'l:initial_response_time' so that we can properly address the edge case (slim as it may
                " be) that a single response was sent back.  Note that in regular processing we will just continue to
                " replace the value of this variable until it holds the last 'created_at' timestamp seen so this
                " initialization is inconsequential for the case that 2 or more responses were received.
                let l:final_response_time = l:initial_response_time

            else
                " Overwrite any value held by 'l:final_response_time' with the 'created_at' timestamp found in the
                " current response.
                let l:final_response_time = l:response_dict["created_at"]

            endif

        endfor

    else
        " In this case we are NOT using streaming mode so we expect the received response to be a single message that
        " contains a complete response message (and possibly a complete "thinking" response as well).  Begin processing
        " such response by reading all lines from the 'payload_filepath' then stitch these together with newlines.
        let l:full_response_text = join(readfile(a:payload_filepath), "\n")


        " Parse the 'l:full_response_text' as a single JSON document and then store ther resulting dictionary in a
        " local variable.
        let l:response_dict = json_decode(l:full_response_text)


        " Extract the "message" dictionary from the response and store this into a local variable for easier data
        " retrieval.
        let l:message_dict = l:response_dict["message"]


        " Retrieve any assistant response that might be found within the 'l:message_dict', as well as any thinking
        " response it might contain, and store these into some local variable for later use.
        if has_key(l:message_dict, "content")
            let l:assistant_message = l:message_dict["content"]
        endif

        if has_key(l:message_dict, "thinking")
            let l:assistant_thinking = l:message_dict["thinking"]
        endif


        " Now handle the timestamp data to be collected.  Since we only get back a single response in non-streaming mode
        " there really isn't a concept of an "initial" and a "final" timestamp; we will instead initialize the variables
        " associated with both of these to the same "created_at" value found in the main response.
        let l:initial_response_time = l:response_dict["created_at"]
        let l:final_response_time = l:initial_response_time

    endif


    " Finally, build up a "common" dictionary that holds the content we want to return and then pass this back to the
    " caller.  Note that the format of this dictionary MUST BE THE SAME for any ProcessXXXChatResponsePayload() function
    " so be careful of any changes.  Why is this?  The goal of this structure was to abstract the actual response format
    " for a particular server type such that only the logic within the function parsing such response needs to be
    " knowledgable.  This means that a common format for passing extracted response data back to generalized logic needs
    " to be made available and such format must be consistent regardless of the underlying response parser returning it.
    let l:common_dictionary = {
                            \   s:COMMON_RESP_DICT_MESSAGE : l:assistant_message,
                            \   s:COMMON_RESP_DICT_THINKING : l:assistant_thinking,
                            \   s:COMMON_RESP_INIT_TIMESTAMP : l:initial_response_time,
                            \   s:COMMON_RESP_FINAL_TIMESTAMP : l:final_response_time
                            \ }

    return l:common_dictionary

endfunction


" This function will parse the content of an LLM response returned from an Open-WebUI server and will return the result
" as a "common" dictionary (see the documentation for constants at the bottom of this script file for details on the
" content and structure for such dictionary).  Parsing of responses from both streaming and non-streaming interaction
" models are supported and the logic within the function will use the current value assigned to variable
" 'g:llmchat_use_streaming_mode' to determine which mode to expect the response data to be in.
"
" Arguments:
"   payload_filepath - The path and name of a file that contaisn the LLM response payload that this function should
"                      parse.
"
" Returns:
"   A "common" dictionary that contains the content of the parsed response.
"
function LLMChat#send_chat#ProcessOpenWebUIChatResponsePayload(payload_filepath)
    " Define some variables that will be used to collect the information we care about from the response.  Later we
    " will take the values held by these variables and incorporate them into a dictionary that can be given back to
    " the caller.
    let l:assistant_message = ''
    let l:assistant_thinking = ''


    " Now determine how we should process the response based on whether or not we are using "streaming" mode.
    if(g:llmchat_use_streaming_mode)
        " If the logic comes here than streaming mode is in use and we therefore expect to see the file at
        " 'payload_filepath' contain a series of server responses.  Each response in the file will be one its own line
        " and the ordering of responses within the file (from beginning to end) should match the order that we need to
        " join their fragments back together.  Note that if "thinking" mode was enabled on the model than we will see
        " the same kind of fragments (and the same ordering) as for the final message.  Some example JSONs showing the
        " different message contents we will need to handle are pasted below (note that each of these messages has been
        " formatted for readability; when actually received from an Open-WebUI server each response will be contained
        " on a single file line):
        "
        "    Example #1 - Return containing "thinking" information (i.e., "reasoning_content"):
        "
        "  data: {
        "          "id": "qwen3:8b-8a7b10da-8f44-4a11-b68e-48ad6177ae4d",
        "          "created": 1766416271,
        "          "model": "qwen3:8b",
        "          "choices":
        "          [
        "            {
        "              "index": 0, "logprobs": null,
        "              "finish_reason": null,
        "              "delta":
        "              {
        "                "reasoning_content": ","
        "              }
        "            }
        "          ],
        "          "object": "chat.completion.chunk"
        "        }
        "
        "
        "    Example 2 - Return containing a fragment of the response message:
        "
        "  data: {
        "          "id": "qwen3:8b-119774e5-8066-47cf-9aa1-e1ed0b6f9670",
        "          "created": 1766416307,
        "          "model": "qwen3:8b",
        "          "choices":
        "          [
        "            {
        "              "index": 0,
        "              "logprobs": null,
        "              "finish_reason": null,
        "              "delta":
        "              {
        "                "content": " I"
        "              }
        "            }
        "          ],
        "          "object": "chat.completion.chunk"
        "        }
        "
        "
        "    Example 3 - Return indicating that all response data has been returned.
        "
        "  data: {
        "          "id": "qwen3:8b-34c1bef4-5c55-417d-a96e-e56b4e60f4a8",
        "          "created": 1766416308,
        "          "model": "qwen3:8b",
        "          "choices":
        "          [
        "            {
        "              "index": 0,
        "              "logprobs": null,
        "              "finish_reason": "stop",
        "              "delta": {}
        "            }
        "          ],
        "          "object": "chat.completion.chunk",
        "          "usage":
        "          {
        "            "response_token/s": 8.21,
        "            "prompt_token/s": 880.33,
        "            "total_duration": 36922045757,
        "            "load_duration": 160576369,
        "            "prompt_eval_count": 104,
        "            "prompt_tokens": 104,
        "            "prompt_eval_duration": 118137228,
        "            "eval_count": 300,
        "            "completion_tokens": 300,
        "            "eval_duration": 36552831904,
        "            "approximate_total": "0h0m36s",
        "            "total_tokens": 404,
        "            "completion_tokens_details":
        "            {
        "              "reasoning_tokens": 0,
        "              "accepted_prediction_tokens": 0,
        "              "rejected_prediction_tokens": 0
        "            }
        "          }
        "        }
        "
        " NOTES:
        "   (1) As can be seen in the examples, the response will start with a leading 'data: ' token that will make the
        "       JSON parse fail if we don't clip it off.
        "
        "   (2) There are 4 recognized message cases that we need to handle; the "thinking", "content" and "ending"
        "       responses shown above as well as a final "data: [DONE]" response that will appear at the very end.
        "
        let l:response_payload_list = readfile(a:payload_filepath)

        let l:first_message = 1

        "Iterate over all lines in the 'l:response_payload_list' and treat each one as its own complete JSON response.
        for l:curr_response_json in l:response_payload_list

            " If any of the following apply then simply skip processing of the line and continue the loop:
            "
            "  1). The current line is empty or consists only of whitespace.
            "  2). The current line matches to the value "data: [DONE]"
            "
            if l:curr_response_json =~ '\v^\s*$' || l:curr_response_json =~? '\v^data:\s*\[DONE\]\s*$'
                continue
            endif

            " Strip any leading "data: " prefix from the current line before attempting to parse it as JSON.
            let l:curr_response_json = substitute(l:curr_response_json, '\v^data\:\s*', '', '')

            " Decode the current response into a Vim dictionary so we can easily access its contents.
            let l:response_dict = json_decode(l:curr_response_json)

            " Now extract the "choices" array from the response and process each item that it contains.
            let l:choices_array = l:response_dict["choices"]
            let l:choices_array_len = len(l:choices_array)

            for l:curr_choice_index in range(0, l:choices_array_len - 1, 1)
                " Retrieve the "delta" dictionary from the current choice element as this will contain the message and
                " thinking fragments that we need to process.
                let l:delta_dict = l:choices_array[l:curr_choice_index]["delta"]

                " Check to see if the "delta" dictionary contains a "content" fragment and if so append it to the end
                " of the 'l:assistant_message' value that we're building up.
               if has_key(l:delta_dict, "content")
                   let l:assistant_message = l:assistant_message .. l:delta_dict["content"]
               endif

               " Check to see if the "delta" dictionary contains a "reasoning_content" fragment as well and if so append
               " it to the end of the 'l:assistant_thinking' variable.
               if has_key(l:delta_dict, "reasoning_content")
                   let l:assistant_thinking = l:assistant_thinking .. l:delta_dict["reasoning_content"]
               endif

            endfor

            " Now handle collection of the response time information.  If this is the first loop iteration (i.e., if
            " variable 'l:first_message' is 1 than we will save the 'created' value found in the response as the initial
            " response timestamp.  If this is NOT the first loop iteration than we will retrieve the 'created' value and
            " use it to overwrite any value held by variable 'l:final_response_time'; this will leave such variable set
            " to the 'created' value found in the last response processed once the loop exits.
            if l:first_message
                let l:initial_response_time = l:response_dict["created"]
                let l:first_message = 0

                " Edge Case - Go ahead and initialize 'l:final_response_time' to be the same as
                "             'l:initial_response_time' so that we can properly address the edge case (slim as it may
                " be) that a single response was sent back.  Note that in regular processing we will just continue to
                " replace the value of this variable until it holds the last 'created_at' timestamp seen so this
                " initialization is inconsequential for the case that 2 or more responses were received.
                let l:final_response_time = l:initial_response_time

            else
                " Overwrite any value held by 'l:final_response_time' with the 'created' timestamp found in the current
                " response.
                let l:final_response_time = l:response_dict["created"]

            endif

        endfor

    else
        " In this case we are NOT using "streaming" mode so we should have received back a single response from the
        " server that contains all the messages and data we need.  An example showing such a response is below:
        "
        " {
        "   "id":"qwen3:8b-b7820f00-1b95-46ee-a013-a4d43b74fbfb",
        "   "created":1766420233,
        "   "model":"qwen3:8b",
        "   "choices":
        "   [
        "     {
        "       "index":0,
        "       "logprobs":null,
        "       "finish_reason":"stop",
        "       "message":
        "       {
        "         "role":"assistant",
        "         "content":"Hello! I'm an AI assistant. I don't have feelings, but I'm here to help. How can I assist
        "                   you today?",
        "         "reasoning_content":"Okay, the user greeted me with \"Hello, how are you today?\" I need to respond
        "                              appropriately. Since they asked about my state, I should mention that I'm an AI
        "                              and don't have feelings, but I'm here to help. Let me keep it friendly and
        "                              concise.\n\nFirst, acknowledge their greeting.n"
        "       }
        "     }
        "   ],
        "   "object":"chat.completion",
        "   "usage":
        "   {
        "     "response_token/s":8.55,
        "     "prompt_token/s":43.74,
        "     "total_duration":59633609036,
        "     "load_duration":27457836514,
        "     "prompt_eval_count":104,
        "     "prompt_tokens":104,"prompt_eval_duration":2377920317,
        "     "eval_count":254,
        "     "completion_tokens":254,
        "     "eval_duration":29697615495,
        "     "approximate_total":"0h0m59s",
        "     "total_tokens":358,
        "     "completion_tokens_details":
        "     {
        "       "reasoning_tokens":0,
        "       "accepted_prediction_tokens":0,
        "       "rejected_prediction_tokens":0
        "     }
        "   }
        " }
        "
        " NOTES:
        "   (1) Unlike in the "streaming" case we don't have any leading text prefixed to our JSON so there is no
        "       additional cleanup to perform before parsing.  Also we don't have any trailing messages or messages
        "       with different content to think about so the processing here is pretty straightforward.
        "
        "   (2) Since we know the response will contain only a single message we will read and join the entire file
        "       content before parsing.  It is not likely that we will have more than one line but just to cover the
        "       bases we will instruct join() to link lines together with newline sequences.
        "
        let l:response_message = join(readfile(a:payload_filepath), "\n")

        " Parse the 'l:respone_message' as a single JSON document then store the resulting dictionary in a local
        " variable.
        let l:response_dict = json_decode(l:response_message)

        " Extract the "choices" array from the response dictionary then loop through each element that it contains so we
        " can process the message data being held.
        let l:choices_array = l:response_dict["choices"]
        let l:choices_array_len = len(l:choices_array)

        for l:curr_choice_index in range(0, l:choices_array_len - 1, 1)
            " Retrieve the message dictionary held by the current "choice" index and store this into a local variable
            " for easier access.
            let l:message_dict = l:choices_array[l:curr_choice_index]["message"]


            " If the 'l:message_dict" contains a "content" field than retrieve its value and join this to any content
            " that might have been retrieved from the message dictionary in a previous element.
            "
            " NOTE: We may need to revisit this as the documentation found for the exact structure of the response did
            "       not detail why there is an array and when it will hold more than one element; it is always possible
            "       that we're doing the wrong thing here...
            "
            if has_key(l:message_dict, "content")
                let l:assistant_message = l:assistant_message .. l:message_dict["content"]
            endif

            " Check to see if the "message" dictionary contains a "reasoning_content" fragment as well and if so append
            " it to the end of the 'l:assistant_thinking' variable.
            "
            " NOTE: Same note as was made about the "content" field; it is unclear when more than one element will
            "       appear in the "choices" array so concatenating data across elements may be the wrong thing to do.
            "
            if has_key(l:message_dict, "reasoning_content")
                let l:assistant_thinking = l:assistant_thinking .. l:message_dict["reasoning_content"]
            endif

        endfor


        " Retrieve the timestamp information from the response and store into some known variables.  Note that unlike
        " the "streaming" case, we don't really have the notion of an "initial" and a "final" response timestamp as only
        " a single response message we received.  We will simply set both variables in this case to the same timestamp
        " value as both variables are currently expected later.
        let l:initial_response_time = l:response_dict["created"]
        let l:final_response_time = l:initial_response_time

    endif

    " Finally, build up a "common" dictionary that holds the content we want to return and then pass this back to the
    " caller.  Note that the format of this dictionary MUST BE THE SAME for any ProcessXXXChatResponsePayload()
    " function so be careful of any changes.  Why is this?  The goal of this structure was to abstract the actual
    " response format for a particular server type such that only the logic within the function parsing such response
    " needs to be knowledgable.  This means that a common format for passing extracted response data back to generalized
    " logic needs to be made available and such format must be consistent regardless of the underlying response parser
    " returning it.
    let l:common_dictionary = {
                            \   s:COMMON_RESP_DICT_MESSAGE : l:assistant_message,
                            \   s:COMMON_RESP_DICT_THINKING : l:assistant_thinking,
                            \   s:COMMON_RESP_INIT_TIMESTAMP : l:initial_response_time,
                            \   s:COMMON_RESP_FINAL_TIMESTAMP : l:final_response_time
                            \ }

    return l:common_dictionary

endfunction


" This function is responsible for determining the message context history to be used for LLM chats and for returning
" that history back to the caller.  Internally the function will use the following process to determine if chat history
" length is to be controlled and if so how many messages to include:
"
"   1). Check to see if a header option exists within the 'parse_dict' dictionary provided that would place a cap on
"       the message context history to use.
"
"   2). Check to see if global variable 'g:llmchat_max_context_messages' has been set and if so does the value it holds
"       impose a limit on the context history.
"
" After determining any message limits the function will return the current sequence of messages held by the
" 'parse_dict' and will then return the appropriate subset that conforms to any history restrictions in place (note that
" if no restrictions exist than all chat messages are simply returned).
"
" Arguments:
"   parse_dict - The parse dictionary containing all current header options and the full history of chat messages from
"                a chat log file.
"
" Returns: A list containing only the subset of messages that should be submitted to a remote LLM as part of a chat
"          request.
"
function LLMChat#send_chat#GetMessageContext(parse_dict)
    " Define a variable that will serve as the "limit" for the number of messages we return back to the caller from the
    " given 'parse_dict'.  By default we will assign the value for this limit as 0 which means that no limit is being
    " imposed and ALL messages should be returned.
    let l:context_limit = 0

    " Check to see if the 'parse_dict' given contains a value for the max context messages header field; if so we will
    " extract such value and use it to update the value being stored by 'l:context_limit'.  If no such header field
    " is found we will look for the presence of global variable 'g:llmchat_max_context_messages', and if found, we
    " will use its value instead to update the content of variable 'l:context_limit'.
    let l:header_dict = a:parse_dict[s:util.PARSE_DICTIONARY_HEADER_KEY]
    if has_key(l:header_dict, s:util.PARSE_DICTIONARY_HEADER_MAX_CONTEXT)
        let l:context_limit = l:header_dict[s:util.PARSE_DICTIONARY_HEADER_MAX_CONTEXT]

    elseif exists("g:llmchat_max_context_messages")
        let l:context_limit = g:llmchat_max_context_messages

    endif


    " Retrieve all messages to be returned back to the caller from the 'parse_dict' argument given.  The process for
    " doing this can take any of the following paths:
    "
    "   1). If the value held by variable 'l:context_limit' is 0 or smaller than simply return back all messages
    "       stored within the parse dictionary.
    "
    "   2). If the value held by variable 'l:context_limit' is 1 or greater but is larger than or equal to the
    "       number of messages stored within the parse dictionary than we will still return back all messages.
    "
    "   3). If the value held by variable 'l:context_limit' is 1 or greater and is SMALLER than the number of messages
    "       stored within the parse dictionary given than we will return ONLY those messages that fall within the
    "       given size from the END (i.e., from the most recent) of the messages list.
    "
    " Note that paths 1 & 2 culminate in the same end behavior and may be grouped together as the 'default' return to
    " assume (we have to retrieve the messages list anyways to get its size so it makes sense to go ahead and stage
    " this as the default).  We can then separate condition #3 out as its own special case and make adjustments to the
    " return list IF that condition is found.
    "
    let l:messages_list = a:parse_dict[s:util.PARSE_DICTIONARY_MESSAGES_KEY]
    let l:messages_size = len(l:messages_list)

    if l:context_limit > 0 && l:context_limit < l:messages_size
        " If the logic comes here than we have a context limit that is 1 or greater AND such size is smaller than the
        " number of messages found.  Take a slice of the 'l:messages_list' that will contain 'l:context_limit' number
        " of messages from the END of the list and set this as the messages list to be returned.  Note that to find
        " the starting index for the slice we will simply take the length of the messages list then subtract from it
        " the number of messages we want to retain for return (i.e., the 'l:context_limit' since the limit can be
        " fully reached).
        let l:messages_list = slice(l:messages_list, l:messages_size - l:context_limit)

    endif


    " Return the final 'l:messages_list' resolved back to the caller.
    return l:messages_list

endfunction


" This function will attempt to resolve and return the name of any register that should be used to hold a copy of a
" response message returned from an LLM during a chat interaction.  To complete this task the function execution will
" perform the following actions:
"
"   1). If the 'parse_dict' argument provided contains a message register field in its header section than the value
"       for that field will be returned.  Note that no additional validation steps are taken in this case as it is
"       always assumed the value was validated during creation of the parse dictionary.
"
"   2). If the 'parse_dict' contains no message register specification than the logic will check to see if
"       global variable 'g:llmchat_default_message_register' is set and if so the value held by such variable will be
"       returned instead.  Note that in this case validation of the variable value IS enforced and such value must be
"       (1) a lower case letter [a-z], (2) an upper case letter [A-Z], or " (which refers to the unnamed register)
"       otherwise an exception will be thrown.
"
"   3). When the 'parse_dict' argument given contains no message register specification AND the
"       'g:llmchat_default_message_register' variable is set to the empty string than this function will simply return
"       the empty string (which means no message register should be used by the caller).
"
" Arguments:
"   parse_dict - The parse dictionary representing the chat log document content at the time this function was invoked.
"                Note that since only header information is needed by the function execution than a parse dictionary
"                produced by a header only parse is still acceptable to provide.
"
" Returns: A value representing a valid message register (i.e., a-z, A-Z or ") or the empty string if no message
"          register should be used.
"
" Throws: An exception if the value of variable 'g:llmchat_default_message_register' is consulted and found to be
"         anything other than (1) a valid register name or (2) the empty string.
"
function GetMessageRegister(parse_dict)
    " Define a variable that will hold the register name to be returned from this function call.  By default this will
    " be set to the empty string which means no register should be used for capturing the latest response message in the
    " chat.
    let l:resolved_register = ''


    " Retrieve the "header dictionary" from the parse dictionary given and store this into a local variable.  The
    " header dictionary will give us access to all chat options defined by the user at the time of chat submission.
    let l:header_dict = a:parse_dict[s:util.PARSE_DICTIONARY_HEADER_KEY]


    " Check to see if the header dictionary contains a key matching to the value held by parse constant
    " 'PARSE_DICTIONARY_HEADER_MSG_REGISTER'; if so than set the value stored under such key as the name of the
    " register to return.  If the header dictionary contains no such entry than we will check to see if a global
    " message register was set that can be returned.
    if has_key(l:header_dict, s:util.PARSE_DICTIONARY_HEADER_MSG_REGISTER)
        let l:resolved_register = l:header_dict[s:util.PARSE_DICTIONARY_HEADER_MSG_REGISTER]

    elseif exists('g:llmchat_default_message_register') && !empty(g:llmchat_default_message_register)
        " NOTE: Since a global variable can be set at any time (and such setting does NOT enforce validation) we need
        "       to ensure that the value found is usable before we try to return it.
        if g:llmchat_default_message_register !~ '\v^[A-Za-z"]$'
            throw "[ERROR] - The register name provided in global variable 'g:llmchat_default_message_register'" ..
                \ "was invalid.  The register supplied as a value to this variable MUST be a single character that " ..
                \ "is (1) a lower case letter [a-z], (2) an upper case letter [A-Z], or \" which refers to the " ..
                \ "unnamed register.  The register name found at the time of this fault was: '" ..
                \ g:llmchat_default_message_register .. "'."
        endif


        " If the logic comes here than the value held by global variable 'g:llmchat_default_message_register' is
        " assumed to be valid; go ahead and change the value held by variable 'l:resolved_register' to be the same.
        let l:resolved_register = g:llmchat_default_message_register

    endif

    " Return the resolved register name back to the caller.
    return l:resolved_register

endfunction


" This is a utility function for converting the "options" dictionary found within the "header dict" of a chat parse
" dictionary into a form that is suitable for serialization to JSON.  The issue is that, even though the user provides
" text formatting that helps the plugin logic to understand the implied type, Vim will not treat this text formatting as
" expected.  We must explicitly convert the text values provided into numbers, floats, and booleans ourselves in order
" for the JSON conversion process to work properly.  Additionally we need to take some cleanup actions such as
" unwrapping the quotes from quoted strings to ensure that these aren't unintentionally included by the conversion
" (remember that quoting tells the plugin if something is supposed to be treated as a string literal but for JSON
" conversion Vim only pays attention to the type being "string" and quotes would be considered part of the value.)
"
" Arguments:
"   header_dict - The header dictionary that may (or may not) contain an options dictionary to be converted.  Note
"                 that the conversion process does not change the original dictionary in any way.
"
" Return: A new dictionary that contains all extracted option name/value pairings but defined with the proper Vim types.
"         Note that if no child options dictionary was found within the 'header_dict' argument supplied than an empty
"         dictionary will be returned.
"
function GetOptionsDictForJSONOutput(header_dict)
    " Create an empty dictionary that we will add processed key value pairs into.  Ultimately this will become the
    " dictionary that is returned back to the caller at the end of the function execution.
    let l:json_options_dict = { }

    if has_key(a:header_dict, s:util.PARSE_DICTIONARY_HEADER_OPTIONS_DICT)
        " If the logic comes here than the 'header_dict' given appears to contain a nested options dictionary; retrieve
        " such dictionary and store its reference into a local variable for easier use.
        let l:options_dict = a:header_dict[s:util.PARSE_DICTIONARY_HEADER_OPTIONS_DICT]

        " Iterate through all keys in the retrieved options dictionary, retrieve the value for the option, then convert
        " the value to the appropriate Vim data type before adding it into the 'json_options_dict'.
        for l:option_key in keys(l:options_dict)
            let l:curr_option_value = l:options_dict[l:option_key]

            if l:curr_option_value ==? "true"
                " In this case we've encountered the unquoted literal value 'true' which we assume means we need to
                " use a boolean.  Note that to do this, and to have Vim properly embed the value as a boolean 'true'
                " we MUST use the constant v:true as the value.
                let l:json_options_dict[l:option_key] = v:true

            elseif l:curr_option_value ==? "false"
                " In this case we've encountered the unquoted literal value 'false' which we assume means we need to
                " use a boolean.  Note htat to do this, and to have Vim properly embed the value as a boolean 'false'
                " we MUST use the contant v:false as the value.
                let l:json_options_dict[l:option_key] = v:false

            elseif l:curr_option_value =~ '\v^[+\-]?[0-9]+$'
                " In this case we assume that the value was an integer value (if this should be treated as a string
                " literal anyways than it should have been quoted).  Convert the string value found into a number and
                " push the result into the 'l:json_options_dict'.
                let l:json_options_dict[l:option_key] = str2nr(l:curr_option_value)

            elseif l:curr_option_value =~ '\v^[+\-]?[0-9]+\.[0-9]*$'
                " In this case we assume that the value was a floating point decimal (again, if this should have been
                " treated as a string than it should have been quoted).  Convert the value into a float and push the
                " result into the 'l:json_options_dict'.
                let l:json_options_dict[l:option_key] = str2float(l:curr_option_value)

            else
                " If the logic came here than we assume that we have a string value for the option.  Check to see
                " if such option is quoted and if so remove the quotes before adding the value into the
                " 'l:json_options_dict'.
                if l:curr_option_value =~ '\v^\".*\"$'
                    let l:json_options_dict[l:option_key] = l:curr_option_value[1: -2]
                else
                    let l:json_options_dict[l:option_key] = l:curr_option_value
                endif

            endif

        endfor

    endif


    " Return the 'l:json_options_dict' containing the converted dictionary information back to the caller.
    return l:json_options_dict

endfunction


" ============================
" ====                    ====
" ====  Main Script Logic ====
" ====                    ====
" ============================
"
" The following logic should run any time that this file is sourced by Vim and is typically used for initialization,
" optimization actions, or common values within the script.


    " ------------------------------------------------
    " ----  Common Response Dictionary Variables  ----
    " ------------------------------------------------
"
" The "common response dictionary" is a data structure returned by function that parse chat interaction responses and
" is intended to insulate the greater logic within this plugin from the specifics of a response from a particular
" server type.  Like with the other shared data structures, we will use some variables to hold the field names in this
" dictionary that way they are centralized and we will get errors if references are incorrect.
const s:COMMON_RESP_DICT_MESSAGE = "response_message"
const s:COMMON_RESP_DICT_THINKING = "response_thinking"
const s:COMMON_RESP_INIT_TIMESTAMP = "initial_response_timestamp"
const s:COMMON_RESP_FINAL_TIMESTAMP = "final_response_timestamp"



    " -----------------------------------------------
    " ----  Chat Execution Dictionary Variables  ----
    " -----------------------------------------------

" This script variable holds the "chat execution" dictionary used to store information about any chat interaction
" that is currently being processed.  Such dictionary is stored at a script level since chat interactions operate
" asynchronously and this information will need to be interacted with from several different functions that will be
" called independently from one another.  Note that currently ONLY ONE chat interaction may be in processing at any
" given time so the emptiness of this dictionary will also be used to determine whether or not a new chat submission
" can proceed.
let s:curr_chat_exec_dict = {}


" Like other dictionaries used between functions within this plugin, the "chat execution" dictionary has its field
" names stored within script constants rather than being hard coded within the functions that interact with it.  The
" constants that currently define all content that may be placed within this dictionary are provided below:
const s:CURR_CHAT_EXEC_DICT_JOB_ID = "job id"
const s:CURR_CHAT_EXEC_DICT_STDOUT = "stdout"
const s:CURR_CHAT_EXEC_DICT_TIMESTAMP = "timestamp"
const s:CURR_CHAT_EXEC_DICT_CAPTURE_COMMAND = "captured command"
const s:CURR_CHAT_EXEC_DICT_CAPTURE_JOB_OPTS = "captured options"
const s:CURR_CHAT_EXEC_DICT_PARSE_DICT = "parse dict"
const s:CURR_CHAT_EXEC_DICT_BUFFER_NUM = "buffer number"
const s:CURR_CHAT_EXEC_DICT_BUFFER_TEXTWIDTH = "buffer textwidth"
const s:CURR_CHAT_EXEC_DICT_BUFFER_LINECNT = "buffer line count"
const s:CURR_CHAT_EXEC_DICT_REQUEST_FILENAME = "request payload filename"
const s:CURR_CHAT_EXEC_DICT_RESPONSE_FILENAME = "response payload filename"
const s:CURR_CHAT_EXEC_DICT_RESPONSE_HEADER_FILENAME = "response header filename"

