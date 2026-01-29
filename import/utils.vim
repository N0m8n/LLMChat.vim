vim9script

#
# This script contains utility functions and constants that are meant for use within other Vimscript files.
# Centralizing such definitions within a Vim9script file allows for easier syntactic referencing as the definitions
# don't need to be scoped with the script path as they would for an autoload script.  Additionally these definitions
# will be compiled which helps with execution speed.
#
# NOTE: For the syntax highlighting to work properly the file MUST have the command 'vim9script' located at the very
#       top before any other text (including comments).
#


################################
####                        ####
####  Function Definitions  ####
####                        ####
################################

# This is a convenience function for returning whether or not 'debug' messages can be output (see function
# WriteToDebug() for more details on debug writes).  When debug output is currently available than this function will
# return the value '1' (true) and when such writes are disabled this function will return back 0 (false).
#
# Returns: A value of 1 (true) if debug writes are currently enabled and 0 (false) if such writes are disabled.
#
export def IsDebugEnabled(): bool
    # We consider debug enabled any time that variable 'g:llmchat_debug_mode_target' has been defined and was given a
    # non-empty value; this is because WriteToDebug() will output debug messages given it when these condition are met.
    var is_debug_enabled = false   #Assume that debug mode is disabled by default.
    if exists("g:llmchat_debug_mode_target") && g:llmchat_debug_mode_target != ''
        is_debug_enabled = true
    endif

    return is_debug_enabled

enddef


# This function will handle the possible output of any 'debug' messages that other logic in this plugin would like to
# write out.  Rules regarding when and how debug output will be performed are enumerated below:
#
#  1). If variable 'g:llmchat_debug_mode_target' is NOT defined or has a value that is equal to the empty string than
#      no debug outputs will be performed and this function will ignore messages given to it.  Note that this is the
#      standard function of operation as we generally don't want to see debug output when things are working as
#      expected.
#
#  2). When variable 'g:llmchat_debug_mode_target' has been set to a value of the form '@N' (where 'N' is an integer
#      value) than this function will attempt to write debug output to the buffer having ID 'N'.  Note that in this mode
#      buffer 'N' MUST exist and debug output will always be appended to the end of the buffer leaving any existing
#      content in tact.  Additionally, in this mode of operation, a window will be opened to show the debug buffer (if
#      such buffer is not already being shown in a window) for viewing.
#
#  3). When variable 'g:llmchat_debug_mode_target' has been set to a non-empty value, and such value is NOT in the
#      form '@N', than we will assume the value to be a file name and path.  For such a case the message provided will
#      be appended to the end of the specified file.  Note that in this mode file content is never truncated and it is
#      left to the user to decide when content should be cleaned up.
#
# Arguments:
#   message - The debug message that this function is being requested to output.
#
# Throws: This function will throw an exception if variable 'g:llmchat_debug_mode_target' has been set to a value of
#         the form '@N' but no buffer with ID 'N' exists.
#
export def WriteToDebug(message: string)
    # Check to see if the 'g:llmchat_debug_mode_target' variable is defined and if so output the message to the
    # specified destination.  If no such variable exists, or if its value is empty, we will take no action.
    if exists("g:llmchat_debug_mode_target") && g:llmchat_debug_mode_target != ''
        # In this case the variable existed AND did not have an empty value.  Now check to see if the value is equal to
        # a string like '@N' where N is an integer number greater than or equal to 1; if so than we assume that the
        # target for the debug output is a buffer and the 'N' portion of the value is the number of the buffer to write
        # to.  If the value held by the variable did NOT match to a string of this type than we will assume a file path
        # was given as the target and we will write the message given to such file instead.
        if g:llmchat_debug_mode_target =~# '\v\@[1-9][0-9]*'
            # In this case it looks like we're targeting a buffer; strip off the leading '@' symbol and use the
            # remainder as the number of the buffer that we should write to.
            #
            # NOTE: Unfortunately some of the functions we need to call (for example 'bufexists()') use the type of the
            #       received argument to determine how to interpret it.  In the case of bufexists() it will assume that
            #       numbers mean actual buffer IDs BUT that strings represent names.  Obviously we are getting the
            #       result of a substring here which would normally result in a variable of type String... that will get
            #       interprted as a 'name' and not a buffer number later if we don't do something.  Because of this
            #       pitfall we will use the str2nr() function to switch the type of 'debug_buff_num' to number before
            #       storing the value.
            #
            var debug_buff_num = str2nr(g:llmchat_debug_mode_target[1 :])

            # Sanity Check - Verify that the 'debug_buff_num' we found actually exists; if not than throw an exception.
            if ! bufexists(debug_buff_num)
                throw "[ERROR] - The 'g:llmchat_debug_mode_target' variable was set to the value '" ..
                      g:llmchat_debug_mode_target .. "' indicating that debug mode should be enabled with the " ..
                      "debug output target being the buffer with number '" .. debug_buff_num .. "'; however no " ..
                      "such buffer was found to exist.  Please correct the value held by variable " ..
                      "'g:llmchat_debug_mode_target' so that it references the ID for a buffer available in the " ..
                      "current Vim runtime."
            endif

            # Store the ID of the window that is currently active in the editor; we will use this information later to
            # determine things like transitions when updating the debug buffer.
            var orig_window_id = winnr()


            # Check to see if the 'debug_buff_num' refers to a buffer currently being shown in a window and if so set
            # the value for variable 'debug_buff_shown' to 1 (indicating that the buffer IS being currently shown).
            # Note that we will also capture the number ID of the window showing the buffer if such a window is found.
            var debug_buff_shown = false           #Assume the buffer is NOT shown by default
            var curr_win_count = winnr('$')
            var debug_win_id: number

            for win_cntr in range(1, curr_win_count, 1)
                if debug_buff_num == winbufnr(win_cntr)
                    # If the logic comes here than we found the debug buffer among those that are currently open in a
                    # window; set the 'debug_buff_shown' variable to 1, store the ID of the window into its own
                    # variable, then break out of the loop.
                    debug_buff_shown = true
                    debug_win_id = win_cntr
                    break

                endif

            endfor


            # Now we need to take one of the following actions depending on (1) whether or not the debug buffer is
            # currently being shown and (2) what window is currently active in the editor.
            #
            #  1). If 'debug_buff_shown' is 1 (meaning that the debug buffer is currently being shown in a window by
            #      the editor) than we need to consider the following:
            #
            #      A). If the window showing the debug buffer is already the active window (i.e.,
            #          'debug_win_id == orig_window_id' than there is no action to take; we already have the active
            #          context set to the window where the debug information will be written.
            #
            #      B). If the window showing the debug buffer is NOT already the active window than we need to change
            #          over to it (again we need the debug information to be written to the buffer in this window and
            #          NOT the currently active window).
            #
            #  2). If 'debug_buff_shown' is 0 (meaning the debug buffer is NOT displayed in any open window) than we
            #      will open a new horizontal split with 'sbuffer' and display the debug buffer.  Note that we expect
            #      context will have switched to this new window as part of the actions taken by the split.
            #
            # What are we trying to accomplish here?  Why are we messing with all this window layout stuff and not just
            # switch context to the debug buffer?  The underlying problem we want to avoid is Vim's behavior with not
            # allowing modifications to be hidden.  We are about to modify the debug buffer and if we don't want to run
            # into trouble trying to go back to the original buffer we need to be careful about making sure that the
            # changes remain in a visible window.  To do this we want to ensure that (1) we always show the debug buffer
            # in a window then (2) when we're done we navigate back to the originally active window but leave the debug
            # window up.
            if debug_buff_shown
                # In this case the debug buffer is being shown in a window so we just need to switch to that window IF
                # it is not the currently active window.
                if orig_window_id != debug_win_id
                    win_gotoid(debug_win_id)
                endif

            else
                # In this case the debug buffer does NOT appear to be open in any available window.  Open a new
                # horizontal split using the 'sbuffer' command that will load this buffer and switch out context to the
                # new window.  Note that we will also store the ID for the new window into variable 'debug_win_id'.
                execute "sbuffer " .. debug_buff_num
                debug_win_id = winnr()

            endif

            # At this point we assume that we've transitioned into a window that is actively showing the debug buffer
            # and this will be the focus for changes that we make.  Use the appendbufline() function to add the
            # 'message' lines to the end of the buffer content.
            var message_lines = split(message, "\n")
            for curr_message_line in message_lines
                appendbufline(debug_buff_num, '$', curr_message_line)
            endfor


            # Now that we've written the debug message out to the proper buffer we need to transition back to the
            # originally active window if such window was different than the one showing the debug buffer.
            if orig_window_id != debug_win_id
                win_gotoid(orig_window_id)
            endif

        else
            # In this case we're targeting a file, simply append the message lines to the end of the file's current
            # content and proceed on.
            writefile(split(message, "\n"), g:llmchat_debug_mode_target, "a")

        endif

    endif

enddef


# This function will take a string value representing a sequence of 1 or more text lines (where each line is assumed to
# be separated by a single '\n' sequence) and attempt to format it into a list of strings whose length does not exceed
# the 'max_len' value given.  Rules regarding how this formatting takes place are given below:
#
#   1). First the 'raw_text' given is split on each '\n' sequence that it contains to obtain a series of text "lines"
#       that can be formatted.  The formatting rules will then be applied to each such line independently.
#
#   2). For each text line obtained by splitting the 'raw_text' given use the following formatting rules:
#
#       A). If a text line has a character length that is less than or equal to 'max_len' than simply add the line to
#           the list that will be returned; there is no action to be taken for this case.
#
#       B). If the text line has a length that is LONGER than 'max_len' than attempt to do one of the following:
#
#           1B). Search for the last space character that occurs between the 'max_len' index in the line and the
#                beginning of the line; if such character can be found than split the line at this character.  The
#                portion of the line occurring between the start and the location of the split will be added to the
#                lines list that will be returned and the remainder of the line will be considered for further
#                formatting.
#
#           2B). If no space character can be found between the start of the line and 'max_len' than begin searching
#                for the first space character that occurs between the character at 'max_len' and the end of the line.
#                If such space character can be found than split the line at its index, add the portion of the line
#                that occurs between the start and the split location to the lines list that will returned, and finally
#                consider the remainder of the line (i.e., those characters occurring after the split index and until
#                the end of the line) for further formatting.
#
#           2C). If NO space character exists anywhere within the line than add the line, unbroken, into the list of
#                lines tha will be returned.
#
# Note that because the function will NOT break words it cannot guarantee that it will be able to format a given
# 'raw_text' into lines of no longer than 'max_len'; it will only be able to format what it can split without breaking
# on the content of a word.
#
# Arguments:
#   raw_text - The text string that should be formatted by this function.
#   max_len - An integer value defining the maximum length to be targeted by the formatting operation.  As indicated
#             by the described formatting rules, the logic will do its best to keep lines within this length but cannot
#             make a strong guarantee of this abililty.
#
# Returns: A list containing the "formatted" lines that resulted from the function execution.
#
export def FormatTextLines(raw_text: string, max_len: number): list<string>
    # Start processing by splitting the 'raw_text' received on any newline sequences that it may contain; this should
    # result in a list of 1 or more 'lines' that we will process further.
    var raw_text_lines = split(raw_text, "\n")


    # Define a new list that will collect the "formatted lines" we want to return back to the caller.
    var formatted_list = []


    # Now loop through each line found in the 'raw_text_lines' list and process each one.
    for next_raw_text_line in raw_text_lines

        # Assign the 'curr_raw_text_line' to a variable inside the loop block so that we can modify it (loop variables
        # appear to be constants).
        var curr_raw_text_line = next_raw_text_line

        # While the 'curr_raw_text_line' is longer than the provided 'max_len' than (1) cut the line and append
        # 'max_width' worth of words to the 'formatted_list' then set 'curr_raw_text_line' equal to the remainder of the
        # line.
        var curr_raw_text_line_len = len(curr_raw_text_line)
        while curr_raw_text_line_len > max_len
            # If the logic comes here than the 'curr_raw_text_line' has exceeded the maximum line length given to this
            # function.  We now need to look within that line starting at index 'max_len' and begin searching toward the
            # start of the line for the first space character we can find; this will become our break point.
            var break_index = max_len
            while break_index > 0
                if curr_raw_text_line[break_index] == ' '
                    # We've found a break index to use; now we'll take the following actions:
                    #
                    #  1). Substring everthing from the beginning of the text line up to the break index and add the
                    #      result into the 'formatted_list'.
                    #
                    #  2). Substring everything from 1 past the break index and assign it back to variable
                    #      "curr_raw_text_line".
                    #
                    add(formatted_list, curr_raw_text_line[0 : break_index - 1])
                    curr_raw_text_line = curr_raw_text_line[break_index + 1 :]

                    # Break out of the 'while' loop since we've found our break index and split the line.
                    break
                else
                    # In this case the character at 'break_index' was NOT a space so we will decrement the index and try
                    # again.
                    break_index = break_index - 1
                endif

            endwhile

            # Check to see if the break index has become negative; if so it means that we ran all the way toward the
            # start of the string without ever finding a space.  We will now try exceeding the 'max_len' value to see if
            # we can locate a space going toward the end.  Note that the only options here are to exceed the maximum
            # line length OR to break a word and, for the time being at least, we will let the line length be violated
            # in favor of not breaking words.
            if break_index <= 0

                break_index = max_len

                while break_index < curr_raw_text_line_len
                    if curr_raw_text_line[break_index] == ' '
                        # We've found a break index to use even so now we'll take the following actions:
                        #
                        #  1). Substring everything from the beginning of the text line up to the break index and add
                        #      the result into the 'formatted_list'.
                        #
                        #  2). Substring everything from 1 past the break index and assign it back to variable
                        #      'curr_raw_text_line'.
                        #
                        add(formatted_list, curr_raw_text_line[0 : break_index - 1])
                        curr_raw_text_line = curr_raw_text_line[break_index + 1 :]

                        # Break out of the 'while' loop since we've found our break index and split the line.
                        break

                    else
                        # In this case the character at 'break_index' is NOT a space so we will increment the index and
                        # try again.
                        break_index = break_index + 1
                    endif

                endwhile

                # Final Case - If the 'break_index' is now bigger than the length of the 'curr_raw_line' it means that
                #              the line contained NO space to break on.  Simply append the line to the 'formatted_list'
                #              and set 'curr_raw_text_line' to the empty string.
                if break_index >= curr_raw_text_line_len
                    add(formatted_list, curr_raw_text_line)
                    curr_raw_text_line = ''
                endif

            endif

            # Recompute the 'curr_raw_text_line_len' based on the remaining 'curr_raw_text_line' that we need to
            # process.  Note that we don't do this directly in the loop condition as some code paths within the loop
            # also need access to the length information; it therefore makes sense to compute this once and store the
            # result.
            curr_raw_text_line_len = len(curr_raw_text_line)

        endwhile

        # If any values remain in 'curr_raw_text_line' than append what remains to the 'formatted_list'.
        if curr_raw_text_line !~ '\v^\s*$'
            add(formatted_list, curr_raw_text_line)

        endif

    endfor


    # Return the "formatted lines" list back to the caller.
    return formatted_list

enddef


# This function is responsible for parsing the current content of a chat buffer and returning the result to the
# caller as a data structure called the "parse dictionary".  Note that when no buffer ID is provided to the function
# invocation then execution will assume that the currently active buffer contains the chat content to be parsed.
#
# Upon successful parse of the chat buffer content a dictionary will be returned to the caller that will have the
# structure shown below.  Note that the 'keys' shown in this structure correspond to the names of script local
# variables (declared in the 'Main' portion of this script file) that are intended to normalize the actual names in
# use to simply variable values.  This helps to ensure that we don't have literal keys declared all over some of which
# may contain a typos or become inconsistent over time; by using variables instead we will get an error from Vim should
# the name of the variable holding the key be provided incorrectly.
#
#  * NOTE: '{' and '}' symbols indicate the content between them is held by a dictionary whereas '[' and ']' symbols
#          indicate that the content between them is held by a list.
#
#  Parse Dictionary Root
#  |
#  { + parse_dictionary_header_key :
#    |  {
#    |    parse_dictionary_header_server_type: "server type",
#    |    parse_dictionary_header_server_url: "https://remote.server.url",
#    |    parse_dictionary_header_model_id: "model id",
#    |    parse_dictionary_header_auth_key: "auth key",
#    |    parse_dictionary_header_user_aut: 'true' or 'false'
#    |    parse_dictionary_header_system_prompt: "system message",
#    |    parse_dictionary_header_show_thinking: "thinking value",
#    |    parse_dicitonary_header_options_dict:
#    |      {
#    |        "option_name_1": "option_value_1",
#    |        "option_name_2": "option_value_2",
#    |          ...
#    |      }
#    |  }
#    |
#    + parse_dictionary_messages_key
#    |  [
#    |    { + parse_dictionary_user_msg_key : 'Holds the user message for the chat "interaction"'
#    |      |
#    |      + parse_dictionary_user_resources_key
#    |      |  [
#    |      |    "Resource reference found within the user chat",
#    |      |    "Another resource reference found within the user chat",
#    |      |    ...
#    |      |  ]
#    |      |
#    |      + parse_dictionary_assistant_msg_key : "Holds the assistant response to the user message if such
#    |                                              response exists (for newly submitted questions there will be no
#    |                                              response present)".
#    |    },
#    |    {
#    |       ...Next chat interaction dictionary; same format as above...
#    |    },
#    |   ...
#    |  ]
#    |
#    + parse_dictionary_parse_flags
#       {
#           ...Contains a series of name/value pairings where the name corresponds to a "flag" variable declared in
#              the main part of this script.  Note that some such variables have values while others do not (and in
#              such a case the value is defaulted to the empty string).  See the 'Parse Flag Variables' subsection of
#              this script for details on the support flag variable names, their inferred meaning, and any value that
#              they might accept...
#       }
#
# If a parse error is encountered while processing the current chat buffer content than this function will throw an
# exception whose message details the nature of the fault encountered.
#
#  Arguments:
#    header_only_parse - (Optional) This argument indicates whether the entire chat buffer content
#                        (header_only_parse = false) or just the header from the buffer content
#                        (header_only_parse = true) should be parsed.  Truncating the parsing operation to just header
#                        information can be useful in situations where the message history is not needed but details
#                        about the remote server are (for example when performing a file upload or knowledgebase
#                        management operation where we need details on how to reach and authenticate with the remote LLM
#                        server but we're not engaging in a chat operation).
#
#    chat_buff_num - (Optional) This argument provides the number of the chat buffer that should be parsed by the
#                    function execution.  When this argument is not provided than the function invocation will default
#                    to parsing the content of the currently active buffer.
#
#  Returns: A "parse dictionary" having the general structure documented above if the parse was successful.
#
#  Throws: Will throw an exception on parse failure whose message is a user-understandable description of the fault.
#
export def ParseChatBufferToBlocks(header_only_parse = false, chat_buff_num = bufnr()): dict<any>
    # Retrieve a dictionary of information about the buffer whose ID was provided to us (argument 'chat_buff_num')
    # then store this into a local variable.
    var buff_info_dict_array = getbufinfo(chat_buff_num)
    if len(buff_info_dict_array) != 1
        throw "[ERROR] - Information on the chat buffer having ID '" .. chat_buff_num .. "' could not be properly " ..
              "resolved by the chat document parsing logic.  The given ID must uniquely identify a single buffer " ..
              "containing the chat document to be parsed but instead was found to identify " ..
              len(buff_info_dict_array) .. " buffers."
    endif

    var buff_info_dict = buff_info_dict_array[0]


    # To handle the buffer content parsing we will walk line-by-line through the file and will collect processable
    # content into either a "header" dictionary or into "chat interaction" dictionaries.  Which dictionary content is
    # added to will depend on whether or not the line holding the content comes before or after the header delimiter
    # sequence.  Lines found to be in the header will be broken down further to extract their individual property values
    # which will then be merged directly to the "header" dictionary.
    #
    # Messages encountered in the main body of the chat will be grouped together into user/assistant message pairs which
    # will then be stored inside a "chat interaction" dictionary.  The series of "chat interaction" dictionaries created
    # during the full buffer parse will be placed into a list that will be returned as part of the complete "parse
    # dictionary" (see the main documentation for this function for more details).  Note that the order of interaction
    # dictionaries within this list will always match to the ordering of interactions found within the buffer content
    # moving from the top (start of the list) to the bottom (end of the list).
    #
    # During the parsing process we will look for any line that matches one of the following criteria and if so simply
    # ignore it (these will be either comments, whitespace lines, or separator lines):
    #
    #  1). Any line whose first non-whitespace character is a '#'.
    #  2). Any line found to be made up entirely of '-' characters IF such line is found (1) within the "body" portion
    #      of the chat document and (2) is outside the context of a chat message (in such a case we assume this to be
    #      a separator line).
    #  3). Any line found to be equal to the header separator.  Note that to match the separator line we will use an
    #      expression that ONLY assumes the '* ENDSETUP *' portion of the line is present.  The length of this line
    #      can be extended to any size by adding '*' characters (based on user preference) so we will match the
    #      '*' characters by expression.
    #  4). Any line made up entirely of whitespace characters that is outside the context of a chat message.
    #
    var parse_dictionary = {}

    var body_messages = []

    # Variables for collecting dictionary entries under construction while (1) parsing through a chat interaction or (2)
    # working through a general text block such as the document header or a chat message.
    var header_dict = {}
    var curr_chat_interaction_dict = {}
    var curr_text_block = []

    # State variables for parsing that are used to indicate context.
    var inside_header = true
    var inside_user_msg = false
    var inside_llm_msg = false
    var inside_system_msg = false

    # Variables used for tracking our parse through all lines in the buffer
    var curr_buffer_line_cntr = 1
    var total_buffer_lines = buff_info_dict["linecount"]

    while curr_buffer_line_cntr <= total_buffer_lines
        # Fetch the content of the line whose line number matches to 'curr_buffer_line_cntr'.
        var curr_buff_line = getbufline(chat_buff_num, curr_buffer_line_cntr)[0]

        # Check to see if we are still inside the context of the header section or if we are now in the body; this will
        # determine how we approach the parse.
        if inside_header
            # If the logic comes here than we are still parsing the header portion of the chat log document.  Check to
            # see if we happen to be within the context of processing a multi-line declaration based on the state flags
            # for the parsing process.
            if inside_system_msg
                # If the logic comes here than we are processing within the context of the multi-line "system message"
                # found within the header.  Check to see if the 'curr_buff_line' contains only whitespace as this
                # would indicate the delimiting line used to end such declaration.
                if curr_buff_line =~ '\v^\s*$'
                    # In this case we've found the "empty line" that will terminate the system message declaration; now
                    # take the following actions:
                    #
                    #  1). Join all lines collected into the 'curr_text_block', using spaces between elements, then
                    #      trim leading and trailing whitspace before setting the result into the 'header_dict'
                    #      variable IF the final value was non-empty.  The system prompt is not a required declaration
                    #      so technically there is not a firm reason why we need to flag an empty prompt as invalid.
                    #      Won't this lead to confusion later on since the user provided a live declaration that did
                    #      nothing?  Possibly, but it is also just as possible that the user reviews the system prompt
                    #      (visible right in their chat document) if something isn't behaving as expected and they can
                    #      see that it is empty.  Excessive validation tends to give interactive logic a bad reputation
                    #      since it results in more failures than perhaps it really must.  For now we'll let the empty
                    #      value pass and if it causes trouble we can come back and add validation for it.
                    #
                    #  2). Reset the 'curr_text_block' to an empty list so it is ready for collecting the next text
                    #      block during parsing.
                    #
                    #  3). Set the 'inside_system_msg' flag to false now that we're done processing the system message
                    #      declaration.
                    #
                    var raw_system_prompt = join(curr_text_block, ' ')

                    var trimmed_prompt = substitute(raw_system_prompt, '\v^\s+', '', '')
                    trimmed_prompt = substitute(trimmed_prompt, '\v\s+$', '', '')

                    if trimmed_prompt != ''
                        header_dict[parse_dictionary_header_system_prompt] = trimmed_prompt
                    endif

                    curr_text_block = []
                    inside_system_msg = false

                else
                     # In this case we have encountered a non-empty line which we assume to be part of the system
                     # message.  Trim any leading or trailing whitespace from the line then add the result as a new
                     # entry into variable 'curr_text_block'.
                    var trimmed_message = substitute(curr_buff_line, '\v^\s+', '', '')
                    trimmed_message = substitute(trimmed_message, '\v\s+$', '', '')

                    add(curr_text_block, trimmed_message)

                endif

            else
                # In this case we don't appear to be processing a multi-line header declaration; now check to see if the
                # 'curr_buff_line' matches to the 'ENDSETUP' line that delmits the document header from its body.
                #
                # NOTE: The "\v..." in the expression below is simply an explicit way to tell Vim we want to use
                #       "very magic" mode for the regex evaulation.
                if curr_buff_line =~# '\v\s*\*+ ENDSETUP \*+\s*'
                    # In this case we've found the delimiting line between the header section and the document body; go
                    # ahead and take the following actions:
                    #
                    #  1). Validate that the 'header_dict' contains ALL required declarations; if not than we'll throw
                    #      an exception.
                    #
                    #  2). Add the 'header_dict' into the main parse dictionary now that we're done filling in its
                    #      content.
                    #
                    #  3). Set the 'inside_header' variable to 'false' as we are now transitioning into the body of the
                    #      chat log document.
                    #
                    #  4). Check to see if argument 'header_only_parse' has been set to 'true' and if so it means that
                    #      the parsing process should STOP after processing the header.  In such a case we will set
                    #      variable 'curr_buffer_line_cntr' to be equal to 'total_buffer_lines' in order to gracefully
                    #      halt further parsing and allow the parse dictionary to be returned with only header
                    #      information contained within it.  Remember that 'curr_buffer_line_cntr' is automatically
                    #      incremented at the end of each loop so this will be 1 greater than 'total_buffer_lines' when
                    #      the next loop conditional check is made.
                    #
                    if ! has_key(header_dict, parse_dictionary_header_server_type)
                        throw "[ERROR] - No 'Server Type:' declaration found within the header portion of the " ..
                              "current chat buffer content.  This declaration is required and must be set to the " ..
                              "type of server that the chat will be submitted to (for example 'Server Type: Ollama' " ..
                              "or 'Server Type: Open WebUI'."
                    endif

                    if ! has_key(header_dict, parse_dictionary_header_server_url)
                        throw "[ERROR] - No 'Server URL:' declaration found within the header portion of the " ..
                              "current chat buffer content.  This declaration is required and must be set to the " ..
                              "URL of the LLM service that chats are to be sent to."
                    endif

                    if ! has_key(header_dict, parse_dictionary_header_model_id)
                        throw "[ERROR] - No 'Model ID:' declaration found within the header portion of the current " ..
                              "chat buffer content.  This declaration is required and must be set to the ID of the " ..
                              "LLM model that chats should be submitted to."
                    endif

                    parse_dictionary[parse_dictionary_header_key] = header_dict

                    inside_header = false

                    if header_only_parse
                        # In this case we've been instructed to ONLY parse the header content so set the
                        # 'curr_buffer_line_cntr' to be equal to 'total_buffer_lines'; when 'curr_buffer_line_cntr' is
                        # then incremented by 1 at the end of the loop it will exceed the size held by
                        # 'total_buffer_lines' and the main parsing loop will terminate.
                        curr_buffer_line_cntr = total_buffer_lines
                    endif
                else
                    # In this case we haven't found the delimiter that ends the header section of the document yet so we
                    # assume that we've got a normal line.  Check to see now if such line matches to one of the
                    # following ignorable sequences:
                    #
                    #  1). The line starts with a '#' as its first non-whitespace character; if so we will simply
                    #      assume the line represents a comment.
                    #  2). A line that consists only of whitespace characters
                    #
                    # NOTE: The leading '\v..' in the expressions below simply means to use "very magic" mode for the
                    #       expression evaluation.
                    var process_line = true      #Assume, by default, that we should process the current line.

                    if curr_buff_line =~# '\v^\s*\#.*$'
                        # The first non-whitespace character in the line is a '#' so we assume this is a comment; set
                        # variable 'process_line' to 'false'.
                        process_line = false
                    elseif curr_buff_line =~# '\v^\s*$'
                        # In this case the line is made up only of whitespace characters so set 'process_line' to
                        # 'false' to ignore it.
                        process_line = false
                    endif

                    if process_line
                        # If the logic comes here than the 'curr_buff_line' was NOT an ignorable line so we will go
                        # ahead and begin trying to process it as a header declaration.
                        if curr_buff_line =~# '\v^\s*Server Type\:.*$'
                            # In this case we've found a server type declaration.  Process such declaration by taking
                            # the following steps:
                            #
                            #  1). First verify that the 'header_dict' dictionary does NOT have any value already
                            #      associated with key 'parse_dictionary_header_server_type'; if such a key does
                            #      exist it means we have found multiple server type declarations in the chat header
                            #      and we'll throw an exception.
                            #
                            #  2). Strip the 'Server Type:' keyword from the front of the line along with any leading
                            #      or trailing whitespace around it.
                            #
                            #  3). Remove any trailing whitespace from the end of the remaining value.
                            #
                            #  4). Validate that the trimmed up value is NOT empty as server type is a required
                            #      definition.
                            #
                            #  5). Add the extracted and cleaned up value into the 'header_dict' variable.
                            #
                            if has_key(header_dict, parse_dictionary_header_server_type)
                                throw "[ERROR] - A duplicate 'Server Type' declaration was found within the header " ..
                                      "segment of the current chat buffer on line " .. curr_buffer_line_cntr ..
                                      ".  This declaration may be given only once per chat document; to resolve " ..
                                      "this issue you will need to remove the duplicate definition."
                            endif

                            var trimmed_value = substitute(curr_buff_line, '\v^\s*Server Type\:\s*', '', '')
                            trimmed_value = substitute(trimmed_value, '\v\s+$', '', '')

                            if trimmed_value == ''
                                throw "[ERROR] - The 'Server Type' declaration found within the header segment " ..
                                      "of the current chat buffer (line '" .. curr_buffer_line_cntr .. "') had " ..
                                      "an empty value.  Please supply a valid, non-empty value for this declaration " ..
                                      "in order to resolve this fault."
                            endif

                            header_dict[parse_dictionary_header_server_type] = trimmed_value

                        elseif curr_buff_line =~# '\v^\s*Server URL\:.*$'
                            # In this case we've found a server URL declaration; process it by taking the following
                            # actions:
                            #
                            #  1). Verify that the 'header_dict' dictionary does NOT have any value already associated
                            #      with the key 'parse_dictionary_header_server_url'; if such a key does exist it
                            #      means we have found a duplicate server URL declaration in the chat header and we'll
                            #      throw an exception.
                            #
                            #  2). Strip the 'Server URL:' keyword from the front of the line along with any leading
                            #      or trailing whitespace around it.
                            #
                            #  3). Remove any trailing whitespace from the end of the remaining value.
                            #
                            #  4). Validate that the trimmed up value is NOT empty as the server type is a required
                            #      declaration.
                            #
                            #  5). Add the extracted and cleaned value into the 'header_dict' variable.
                            #
                            if has_key(header_dict, parse_dictionary_header_server_url)
                                throw "[ERROR] - A duplicate 'Server URL' declaration was found within the header " ..
                                      "segment of the current chat buffer on line " .. curr_buffer_line_cntr ..
                                      ".  This declaration may be given only once per chat document; to resolve " ..
                                      "this issue you will need to remove the duplicate definition."
                            endif

                            var trimmed_value = substitute(curr_buff_line, '\v^\s*Server URL\:\s*', '', '')
                            trimmed_value = substitute(trimmed_value, '\v\s+$', '', '')

                            if trimmed_value == ''
                                throw "[ERROR] - The 'Server URL' declaration found within the header segment " ..
                                      "of the current chat buffer (line '" .. curr_buffer_line_cntr .. "') had " ..
                                      "an empty value.  Please supply a valid, non-empty value for this declaration " ..
                                      "in order to resolve this fault."
                            endif

                            header_dict[parse_dictionary_header_server_url] = trimmed_value

                        elseif curr_buff_line =~# '\v^\s*Model ID\:.*$'
                            # In this case we've found a model ID declaration; process it by taking the following
                            # actions:
                            #
                            #  1). Verify that the 'header_dict' dictionary does NOT have any value already associated
                            #      with the key 'parse_dictionary_header_model_id'; if such a key does exist it means
                            #      we have found a duplicate model ID declaration in the chat header and we'll throw an
                            #      exception.
                            #
                            #  2). Strip the 'Model ID:' keyword from the front of the line along with any leading or
                            #      trailing whitespace around it.
                            #
                            #  3). Remove any trailing whitespace from the end of the remaining value.
                            #
                            #  4). Validate that the trimmed up value is not empty as the model ID is a required
                            #      declaration.
                            #
                            #  5). Add the extracted and cleaned value into the 'header_dict' variable.
                            #
                            if has_key(header_dict, parse_dictionary_header_model_id)
                                throw "[ERROR] - A duplicate 'Model ID' declaration was found within the header " ..
                                      "segment of the current chat buffer on line " .. curr_buffer_line_cntr ..
                                      ".  This declaration may be given only once per chat document; to resolve " ..
                                      "this issue you will need to remove the duplicate definition."
                            endif

                            var trimmed_value = substitute(curr_buff_line, '\v\s*Model ID:\s*', '', '')
                            trimmed_value = substitute(trimmed_value, '\v\s+$', '', '')

                            if trimmed_value == ''
                                throw "[ERROR] - The 'Model ID' declaration found within the header segment " ..
                                      "of the current chat buffer (line '" .. curr_buffer_line_cntr .. "') had " ..
                                      "an empty value.  Please supply a valid, non-empty value for this declaration " ..
                                      "in order to resolve this fault."
                            endif

                            header_dict[parse_dictionary_header_model_id] = trimmed_value

                        elseif curr_buff_line =~# '\v^\s*Use Auth Token\:.*$'
                            # In this case we've found a "use auth" declaration; process it by taking the following
                            # actions:
                            #
                            #  1). Verify that the 'header_dict' dictionary does NOT have any value already associated
                            #      with the key 'parse_dictionary_header_use_auth'; if such key does exist it means
                            #      we have found a duplicate "use auth" declaration in the chat header and we'll throw
                            #      an exception.
                            #
                            #  2). Strip off the 'Use Auth Token:' keyword from the front of the line along with any
                            #      leading or trailing whitespace around it.
                            #
                            #  3). Remove any trailing whitespace from the end of the remaining value.
                            #
                            #  4). Verify that the remaining value is equal to one of the following strings: "true" or
                            #      "false".  If the value is not equal to either than we will consider the value
                            #      invalid and will throw an exception.
                            #
                            #  5). Add the extracted and cleaned value into the 'header_dict' variable
                            #
                            if has_key(header_dict, parse_dictionary_header_use_auth)
                                throw "[ERROR] - A duplicate 'Use Auth Token' declaration was found within the " ..
                                      "header segment of the current chat buffer on line " .. curr_buffer_line_cntr ..
                                      ".  This declaration may be given only once per chat document; to resolve " ..
                                      "this issue you will need to remove the duplicate definition."
                            endif

                            var trimmed_value = substitute(curr_buff_line, '\v\s*Use Auth Token\:\s*', '', '')
                            trimmed_value = substitute(trimmed_value, '\v\s+$', '', '')

                            if trimmed_value ==? "true"
                                # NOTE: We will always push the lowercase version of the value into the dictionary
                                #       for ease of processing later on.
                                header_dict[parse_dictionary_header_use_auth] = "true"

                            elseif trimmed_value ==? "false"
                                # NOTE: We will always push the lowercase version of the value into the dictionary for
                                #       ease of processing later on.
                                header_dict[parse_dictionary_header_use_auth] = "false"

                            else
                                throw "[ERROR] - A 'Use Auth Token' declaration was found within the header " ..
                                      "segment of the current chat buffer that had an invalid value.  Such " ..
                                      "declarations must only hold values that are equal to the string 'true' or " ..
                                      "the string 'false' (case insensitive).  At the time of this fault the " ..
                                      "declaration on line " .. curr_buffer_line_cntr .. " was found to have " ..
                                      "the value: '" .. trimmed_value .. "'.  Please correct this declaration to " ..
                                      "use a valid value as listed above to resolve the fault."
                            endif

                        elseif curr_buff_line =~# '\v^\s*Show Reasoning\:.*$'
                            # In this case we've found a "show reasoning" declaration that will (1) set the model
                            # reasoning to use during interations and (2) enable or disable the display of "thinking"
                            # messages during LLM interactions.  Process this header line by taking the following
                            # actions:
                            #
                            #  1). Verify that the 'header_dict' dictionary does NOT have any value already
                            #      associated with the key 'parse_dictionary_header_show_thinking'; if such key does
                            #      exist it means we have found a duplicate "show reasoning" declaration in the chat
                            #      header and we'll throw an exception.
                            #
                            #  2). Strip off the 'Show Reasoning:' keyword from the front of the line along with any
                            #      leading or trailing whitespace from the end of the remaining value.
                            #
                            #  3). Remove any trailing whitespace from the end of the remaining value.
                            #
                            #  4). Validate that the trimmed up value is not empty as there is currently no use case
                            #      where this could be viewed as acceptable.
                            #
                            #  5). Add the extracted and cleaned value into the 'header_dict' variable.  Note that
                            #      we do not try to validate exactly what value was provided as this can be more than
                            #      just a boolean option (depending on the remote server we're sending it to);
                            #      ultimately we will let the remote server decide if the provided value is acceptable
                            #      once a chat request is made.
                            #
                            if has_key(header_dict, parse_dictionary_header_show_thinking)
                                throw "[ERROR] - A duplicate 'Show Reasoning' declaration was found within the " ..
                                      "header segment of the current chat buffer on line " .. curr_buffer_line_cntr ..
                                      ".  This declaration may be given only once per chat document; to resolve " ..
                                      "this issue you will need to remove the dupliate definition."
                            endif

                            var trimmed_value = substitute(curr_buff_line, '\v\s*Show Reasoning\:\s*', '', '')
                            trimmed_value = substitute(trimmed_value, '\v\s+$', '', '')

                            if trimmed_value == ''
                                throw "[ERROR] - The 'Show Reasoning' declaration found within the header segment " ..
                                      "of the current chat buffer (line '" .. curr_buffer_line_cntr .. "') had " ..
                                      "an empty value.  Please supply a valid, non-empty value for this " ..
                                      "declaration when specifying it within your chat document."
                            endif

                            header_dict[parse_dictionary_header_show_thinking] = trimmed_value

                        elseif curr_buff_line =~# '\v^\s*Auth Token\:.*$'
                            # In this case we've found an auth token declaration; processing it by taking the following
                            # actions:
                            #
                            #  1). Verify that the 'header_dict' dictionary does NOT have any value already associated
                            #      with the key 'parse_dictionary_header_auth_key'; if such a key does exist it means
                            #      we have found a duplicate authorization token declaration in the chat header and
                            #      we'll throw an exception
                            #
                            #  2). Strip the 'Auth Token:' keyword from the front of the line along with any leading or
                            #      trailing whitespace around it.
                            #
                            #  3). Remove any trailing whitespace from the end of the remaining value.
                            #
                            #  4). Add the extracted and cleaned value into the 'header_dict' variable IF such value
                            #      is non-empty.  The auth token is not a required declaration so there is technically
                            #      not a firm reason for us to flag a fault if an empty value was given.  Some argument
                            #      could be made here, from a usability standpoint, that any uncommented declaration
                            #      should be meaningful and therefore we *should* flag an empty value as a fault (rather
                            #      than quietly ignore it which may lead to user confusion later if the chat
                            #      misbehaves); afterall it is possible for the user to simply comment out such line if
                            #      they don't want it processed.  The flip side of this is the argument that too much
                            #      validation makes the logic less user friendly by giving it more ways to fail when it
                            #      technically doesn't need to.  Users typically aren't perfect so being lenient with
                            #      interactive processes rather than unnecessarily strict tends to provide a more
                            #      palettable experience.
                            #
                            #      Again, for now at least, we'll let it slide and return back later if needed.
                            #
                            if has_key(header_dict, parse_dictionary_header_auth_key)
                                throw "[ERROR] - A duplicate 'Auth Token' declaration was found within the header " ..
                                      "segment of the current chat buffer on line " .. curr_buffer_line_cntr ..
                                      ".  This declaration may be given only once per chat document; to resolve " ..
                                      "this issue you will need to remove the duplicate definition."
                            endif

                            var trimmed_value = substitute(curr_buff_line, '\v\s*Auth Token\:\s*', '', '')
                            trimmed_value = substitute(trimmed_value, '\v\s+$', '', '')

                            if trimmed_value != ''
                                header_dict[parse_dictionary_header_auth_key] = trimmed_value
                            endif

                        elseif curr_buff_line =~# '\v^\s*System Prompt\:.*$'
                            # In this case we've found a system prompt declaration which we need to process by taking
                            # the following actions:
                            #
                            #  1). Verify that the 'header_dict' dictionary does NOT have any value already associated
                            #      with the key 'parse_dictionary_header_system_prompt'; if such a key does exist it
                            #      means we have found a duplicate system message declaration in the chat header and
                            #      we'll throw an exception.
                            #
                            #  2). Strip the 'System Prompt:' keyword from the front of the line along with any leading
                            #      or trailing whitespace around it.
                            #
                            #  3). Remove any trailing whitespace from the end of the remaining value.
                            #
                            #  4). Add the trimmed value into the list held by variable 'curr_text_block'.  System
                            #      prompts may span multiple lines so we'll need to continue collecting text until we
                            #      find the next empty line that follows this prompt.
                            #
                            #  5). Set variable 'inside_system_msg' to 'true' so that the parsing logic understands we
                            #      are now within the context of processing the system prompt content.
                            #
                            if has_key(header_dict, parse_dictionary_header_system_prompt)
                                throw "[ERROR] - A duplicate 'System Prompt:' declaration was found within the " ..
                                      "header segment of the current chat buffer on line " .. curr_buffer_line_cntr ..
                                      ".  This declaration may be given only once per chat document; to resovle " ..
                                      "this issue you will need to remove the duplicate definition."
                            endif

                            var trimmed_value = substitute(curr_buff_line, '\v\s*System Prompt\:\s*', '', '')
                            trimmed_value = substitute(trimmed_value, '\v\s+$', '', '')

                            add(curr_text_block, trimmed_value)

                            inside_system_msg = true

                        elseif curr_buff_line =~# '\v^\s*Option\:.*$'
                            # In this case we've encountered an option declaration.  Call out to a utility function to
                            # parse the declaration then return back to us a 2-element list containing the option name
                            # (at index 0) and the option value (at index 1).
                            var option_pair_list = ParseChatOption(curr_buff_line, curr_buffer_line_cntr)

                            var option_name = option_pair_list[0]
                            var option_value = option_pair_list[1]

                            # Check to see if any options dictionary is currently held by the 'header_dict' variable.
                            if has_key(header_dict, parse_dictionary_header_options_dict)
                                # In this case the 'header_dict' did contain an option dictionary already so we want
                                # to make sure that such dictionary does NOT contain an entry whose key is equal to
                                # 'option_name'; if such a key already exists we will throw an exception as defining
                                # duplicate options is not supported.
                                if has_key(header_dict[parse_dictionary_header_options_dict], option_name)
                                    throw "[ERROR] - More than one option declaration having name '" .. option_name ..
                                          "' was found within the header section of the current chat buffer; the " ..
                                          "declaration for a particular option may only be defined, at most, once. " ..
                                          "At the the time of this fault the duplicate declaration was found on " ..
                                          "line " .. curr_buffer_line_cntr .. "."
                                else
                                    # In this case the options dictionary held by 'header_dict' did NOT have a key
                                    # that matched to the new option name so we will go ahead and merge the new option
                                    # pairing into the options dictionary.
                                    header_dict[parse_dictionary_header_options_dict][option_name] = option_value
                                endif

                            else
                                # In this case the 'header_dict' didn't even have an options dictionary yet so
                                # we'll go ahead and add one that contains the new option pairing.
                                header_dict[parse_dictionary_header_options_dict] = { [option_name]: option_value }
                            endif

                        else
                            # If the logic comes here than we got something unexpected in the header.  Throw an
                            # exception since it is unclear what text we've encountered.
                            throw "[ERROR] - Unexpected text was encountered at line " .. curr_buffer_line_cntr ..
                                  " within the header portion of the current chat buffer.  Such text does not " ..
                                  "appear to be part of any recognized declaration and is not held by a recognized " ..
                                  "comment sequence.  Please remove this text or refactor it to appear within a " ..
                                  "supported header structure to resolve this fault."
                        endif

                    endif

                endif

            endif

        else
            # If the logic comes here than we are currently parsing the body portion of the chat log document.  Check to
            # see now if we are in the context of any particular block such as a user message or an LLM message as this
            # will effect the actions we choose to take.
            if inside_user_msg
                # If the logic comes here than we are parsing while inside the context of a "user message" (this means
                # that the start token for the user message has been found but we have not located the end token yet).
                # Check to see if the current line is equal to the end token or not to determine what we do next.
                #
                # NOTE: The leading "\v..." at the start of the matching expression lets Vim know that we're providing
                #       a regex that should be evaluated using "very magic" mode.
                if curr_buff_line =~# '\v^\s*\<\<\<\s*$'
                    # In this case we've found the end token for the user chat; now we need to take the following
                    # actions:
                    #
                    #  1). Check to see if the 'curr_text_block' is non-empty and IF SO proceed forward with the
                    #      following:
                    #
                    #      A). Join all elements in the 'curr_text_block' back into a single string value (using
                    #          a single space as the separator) then trim off any leading or training whitespace
                    #          sequences and finally call a utility function to unescape any special sequences found
                    #          within the joined text.
                    #
                    #      B). Add a new mapping between the key held by variable 'parse_dictionary_user_msg_key' and
                    #          the string value obtained during step 'A' into the 'curr_chat_interaction_dict'.  Note
                    #          that we don't check to see if any such key already exists since this check is performed
                    #          when we entered the processing context for the user message (see the portion of the
                    #          logic that handles the opening token for message).
                    #
                    #      C). Reset the 'curr_text_block' variable back to an empty list since the text it was
                    #          buffering has now been added to the current chat interaction dictionary.
                    #
                    #  2). Set the 'inside_user_msg' variable to 'false' as we are no longer processing text while
                    #      inside the context of a user message block.
                    #
                    # NOTE: We assume the flow for a user/assistant interaction ALWAYS begins with a user message and
                    #       ends with an assistant response (if the interaction is fully complete).  Hence we will
                    #       wait to see if any assistant message is found and if so we will add such message to the
                    #       'curr_chat_interaction_dict' before merging that dictionary into the main
                    #       'parse_dictionary' that will be returned by this function.
                    #
                    if !empty(curr_text_block)
                        var joined_user_message_text = join(curr_text_block, " ")

                        joined_user_message_text = substitute(joined_user_message_text, '\v^\s+', '', '')
                        joined_user_message_text = substitute(joined_user_message_text, '\v\s+\n*$', '', '')
                        joined_user_message_text = substitute(joined_user_message_text, '\v\s+\n\n', '\n\n', 'g')
                        joined_user_message_text = substitute(joined_user_message_text, '\v\n\n\s', '\n\n', 'g')

                        var user_message_text = UnescapeSpecialSequences(joined_user_message_text)

                        curr_chat_interaction_dict[parse_dictionary_user_msg_key] = user_message_text

                        curr_text_block = []
                    endif

                    inside_user_msg = false

                else
                    # In this case we haven't found the end of the user message block yet so we assume that we've just
                    # found some line that belongs to the block.  Check to see now if the line matches to a string
                    # having the general form '[f:id]' or '[k:id]'; if so than we assume that we've found a resource
                    # reference associated with the chat message.  If the line does not match to either of these forms
                    # we will assume that we've just got a regular text line that is part of the user message.
                    #
                    # NOTE: The leading '\v...' in the regular expression is there to let Vim know we want it to use
                    #       "very magic" mode when performing interpretation of the regex.
                    if curr_buff_line =~# '\v^\s*\[.+\]\s*$'
                        # If the logic comes here than we've found a "resource" that is embedded within the chat message
                        # content.  Resources refer to things like files that have been uploaded, knowledge bases that
                        # exist on the remote LLM server, etc.  For our purposes here we don't need to worry about what
                        # type of resource is being referenced; only that a resource was found and we need to embed its
                        # information into the content being accumulated by dictionary 'curr_chat_interaction_dict'.
                        # Take the steps below to finish processing this information:
                        #
                        #  1). Remove the wrapping '[' and ']' characters from the resource reference (along with any
                        #      leading or trailing whitespace); these are only used to identify the resource while
                        #      parsing.
                        #
                        #  2). Validate that the resource begins with the prefix "f:" or "c:" (which specifies the
                        #      type of resource; "f:" meaning "file" and "c:" meaning "collection").  If the resource
                        #      does NOT begin with one of the supported prefixes than we will throw an exception.
                        #
                        #  3). Check to see if a key matching to the value held by variable
                        #      'parse_dictionary_user_resources_key' exists within the 'curr_chat_interaction_dict'
                        #      as this will determine how we choose to add the new information.
                        #
                        #  4). If the key aleady existed than append the new resource information to the list that
                        #      exists below that key.
                        #
                        #  5). If the key did NOT already exist than add the resource information into a new list
                        #      and set this list into the 'curr_chat_interaction_dict' under the key.
                        #
                        var front_trimmed_resource_ref = substitute(curr_buff_line, '\v^\s*\[', "", "")
                        var resource_ref = substitute(front_trimmed_resource_ref, '\v\]\s*\n*$', "", "")

                        if resource_ref !~? '\v^[fc]\:.*'
                            throw "[ERROR] - A resource reference was encountered on line " ..
                                  curr_buffer_line_cntr .. " whose format was invalid.  Any provided resource " ..
                                  "reference must be given in the format '[s:ID]' (for a file) or [c:ID] (for " ..
                                  "a knowledge collection) in order to be understood by the parsing.  The resource " ..
                                  "reference that prompted this fault was not found to begin with either an 'f:' or " ..
                                  "a 'c:' prefix so its type could not be understood.  Please update this reference " ..
                                  "to use a supported prefix value in order to resolve the fault."
                        endif

                        if has_key(curr_chat_interaction_dict, parse_dictionary_user_resources_key)
                            add(curr_chat_interaction_dict[parse_dictionary_user_resources_key], resource_ref)
                        else
                            curr_chat_interaction_dict[parse_dictionary_user_resources_key] = [resource_ref]
                        endif

                    else
                        # If the logic comes here than we assume that we've just got a line of text that belongs to the
                        # user message; we now need to see if the special case below applies before adding the line to
                        # the 'curr_text_block' list:
                        #
                        #  1). A Whitespace Only Line - Whitespace lines within chats are typically used as an easy way
                        #                               to delimit information such as a paragraph or off-setting an
                        #          an example from the rest of the text for clarity.  Since such formatting *may* be
                        #          used by an LLM we will go ahead and keep it.  Note that we assume the operative
                        #          portion of this information to just be the empty line so we will insert two newlines
                        #          ("\n\n") into the 'curr_text_block' if the 'curr_buff_line' is in fact (1) empty or
                        #          (2) made up only of whitespace characters.  We don't preserve any original whitespace
                        #          characters from the line because, at present, we have no use case demonstrating that
                        #          whitespace characters beyond the newline contribute meaningful information in a chat
                        #          when found in a whitespace-only line.  Additionally, we want to keep the chat parse
                        #          as lean as possible so we don't bloat any network requests constructed from it with
                        #          unnecessary character data.
                        #
                        #          Why two newlines rather than just one? ... and why does the empty line fall into this
                        #          category?  Remember that we already split on newline characters to process the buffer
                        #          text and this means that newlines are removed to start with.  The empty string "" on
                        #          a line would be produced by having a newline on either end and the same goes for
                        #          whitespace only content (i.e., a whitespace only line needs to have a newline at
                        #          either end to appear by itself in the text).  We want to preserve the idea of
                        #          "an empty line" and this requires two newlines be present to create; one to move away
                        #          from the non-empty chat text then the second to leave behind the empty line.
                        #
                        if curr_buff_line =~# '\v^\s*$'
                            add(curr_text_block, "\n\n")
                        else
                            add(curr_text_block, curr_buff_line)
                        endif

                    endif

                endif

            elseif inside_llm_msg
                # If the logic comes here than we are parsing while inside the context of an "assistant message" (this
                # means that the start token for such message has been found but we have not located the end token yet).
                # Check to see if the current line is equal to the end token or not to determine what we need to do
                # next.
                #
                # NOTE: The leading "\v..." at the start of the matching expression lets Vim know that we're providing
                #       a regex that should be evaluated using "very magic" mode.
                if curr_buff_line =~# '\v^\s*\<\<\=\s*$'
                    # In this case we've found the end token for the assistant chat; now we need to take the following
                    # actions:
                    #
                    #  1). Check to see if the 'curr_text_block' is empty and if so assume that we have a corrupt or
                    #      incomplete chat log as the assistant message is misssing.  In such a case output an error
                    #      message to the user then immediately return an empty dictionary back to the caller as this
                    #      will effectively abort the parse.
                    #
                    #  2). Join all elements in the 'curr_text_block' back into a single string value (using a single
                    #      space as the element separator) then trim off any leading or trailing whitespace before
                    #      calling a utility function to unescape all special sequences found within the joined text.
                    #
                    #  3). Add a new mapping between the key held by variable 'parse_dictionary_assistant_msg_key'
                    #      and the text block obtained during the previous step into the 'curr_chat_interaction_dict';
                    #      this effectively adds the "assistant" portion of the chat into the dictionary completing its
                    #      content.
                    #
                    #  4). Check to see if the 'parse_dictionary' variable already contains a key that is equal to the
                    #      value held by variable 'parse_dictionary_messages_key' as this will determine how we add
                    #      information to it in the coming steps.
                    #
                    #  5). If the 'parse_dictionary' already has a key for messages then append the
                    #      'curr_chat_interaction_dict' to the list that is attached to that key.  If no such key exists
                    #      than add the 'curr_chat_interaction_dict' into a new list and then bind that list into the
                    #      'parse_dictionary' under the key held by variable 'parse_dictionary_messages_key'.
                    #
                    #  6). Now reset the 'curr_text_block' to an empty list as its content has already been added to
                    #      the parse dictionary and we need to empty it out in prep for further processing.
                    #
                    #  7). Reset the 'curr_chat_interaction_dict' to an empty dictionary as, again, the chat interaction
                    #      it was holding has already been completed and merged to the main parse dictionary; we now
                    #      need to reset this so it is ready to begin collecting information about the next chat
                    #      interaction we encounter during parsing.
                    #
                    #  8). Set the 'inside_llm_msg' variable to 'false' indicating that we have completed processing of
                    #      the assistant message and are no longer parsing within the context of such message block.
                    #
                    if len(curr_text_block) == 0
                        # In this case we found the start and end tokens for an assistant message but no actual message
                        # content was present.  Throw an exception indicating that we assume this to mean there may be
                        # missing data within the chat buffer.
                        throw "[ERROR] - The chat interaction ending on line " .. curr_buffer_line_cntr ..
                              " was found to be missing the content of the assistant message (although the start " ..
                              "and end tokens for such message were found by the parsing process).  All chats held " ..
                              "by the chat buffer which contain assistant response markers MUST contain non-empty " ..
                              "information.  Please correct this fault by filling in the missing information, " ..
                              "fixing the delimiting tokens for the chat, or by removing/commenting out the " ..
                              "complete chat interaction where this fault was found. Note that detction of this " ..
                              "issue has caused parsing of the chat buffer to fail and no further actions were " ..
                              "taken beyond this."
                    endif

                    var joined_assist_text = join(curr_text_block, " ")

                    joined_assist_text = substitute(joined_assist_text, '\v^\s+', '', '')
                    joined_assist_text = substitute(joined_assist_text, '\v\s+\n*$', '', '')
                    joined_assist_text = substitute(joined_assist_text, '\v\s+\n\n', '\n\n', 'g')
                    joined_assist_text = substitute(joined_assist_text, '\v\n\n\s', '\n\n', 'g')

                    var assist_msg_text = UnescapeSpecialSequences(joined_assist_text)

                    curr_chat_interaction_dict[parse_dictionary_assistant_msg_key] = assist_msg_text

                    if has_key(parse_dictionary, parse_dictionary_messages_key)
                        add(parse_dictionary[parse_dictionary_messages_key], curr_chat_interaction_dict)
                    else
                        parse_dictionary[parse_dictionary_messages_key] = [curr_chat_interaction_dict]
                    endif

                    curr_text_block = []
                    curr_chat_interaction_dict = {}
                    inside_llm_msg = false

                else
                    # If the logic comes here than we have not yet found the ending token for the assistant message;
                    # assume that the current buffer line is simply part of the assistant reponse.  We now need to see
                    # if the special case below applies before appending the current line to the end of list
                    # 'curr_text_block'.
                    #
                    #  1). A Whitespace Only Line - Whitespace lines within chats are typically used as an easy way to
                    #                               delimit information such as a paragraph or off-setting an an
                    #          example from the rest of the text for clarity.  Since such formatting *may* be used by
                    #          an LLM we will go ahead and keep it.  Note that we assume the operative portion of this
                    #          information to just be the empty line so we will insert two newlines ("\n\n") into the
                    #          'curr_text_block' if the 'curr_buff_line' is in fact (1) empty or (2) made up only of
                    #          whitespace characters.  We don't preserve any original whitespace characters from the
                    #          line because, at present, we have no use case demonstrating that whitespace characters
                    #          beyond the newline contribute meaningful information in a chat when found in a
                    #          whitespace-only line.  Additionally, we want to keep the chat parse as lean as possible
                    #          so we don't bloat any network requests constructed from it with unnecessary character
                    #          data.
                    #
                    #          Why two newlines rather than just one? ... and why does the empty line fall into this
                    #          category?  Remember that we already split on newline characters to process the buffer
                    #          text and this means that newlines are removed to start with.  The empty string "" on a
                    #          line would be produced by having a newline on either end and the same goes for
                    #          whitespace only content (i.e., a whitespace only line needs to have a newline at either
                    #          end to appear by itself in the text).  We want to preserve the idea of "an empty line"
                    #          and this requires two newlines be present to create; one to move away from the non-empty
                    #          chat text then the second to leave behind the empty line.
                    #
                    if curr_buff_line =~# '\v^\s*$'
                        add(curr_text_block, "\n\n")
                    else
                        add(curr_text_block, curr_buff_line)
                    endif

                endif

            else
                # If the logic comes here than we're not currently inside the context of any user or assistant message.
                # Check to see if any of the following conditions apply and if so than just skip over any further
                # processing of the line:
                #
                #  1). The first non-whitespace character in the line is a '#' meaning the line is a comment; in such
                #      a case we'll simply ignore it.
                #
                #  2). The line is made up entirely of whitespace characters.
                #
                #  3). The line is made up entirely of '-' characters with possibly some leading and/or trailing
                #      whitespace.  In such a case we assume the line to be a chat interaction division bar and we'll
                #      ignore it.
                #
                # NOTE: The leading '\v...' in the matching expressions ensures that we explictly use "very magic" mode
                #       for the regular expression evaluation.
                var ignore_line = false
                if curr_buff_line =~# '\v^\s*\#.*$'
                    # In this case we've found a comment line; simply set the 'ignore_line' variable to 'true' so we
                    # skip further processing.
                    ignore_line = true
                elseif curr_buff_line =~# '\v^\s*$'
                    # In this case we've found an empty or whitespace only line; simply set 'ignore_line' to 'true' so
                    # we skip any further processing.
                    ignore_line = true
                elseif curr_buff_line =~# '\v\s*[-]+\s*'
                    # In this case the line was made up of '-' characters with possibly some leading and trailing
                    # whitespace; we assume this to be a division bar between chat interactions so set the 'ignore_line'
                    # variable to 'true' to ignore it.
                    ignore_line = true
                endif


                # If the 'ignore_line' variable is still set to 0 (i.e., "DON'T ignore the line) than proceed with
                # processing it.
                if ! ignore_line
                    # If the logic arrives here than we assume that the line pointed to by 'curr_buff_line' is
                    # relevant to either a user or an assistant message (meaning that this should be the start to
                    # such a message).  If we find that the line is applicable to neither we will assume that we have
                    # a file format problem and will report an error to the user.
                    if curr_buff_line =~# '\v^\>\>\>(.)*'
                        # If the logic comes here than we've found the start to a "user" message and need to take the
                        # following actions:
                        #
                        #  1). Check to see if any key equal to the value held by variable
                        #      'parse_dictionary_user_msg_key' is already present in the dictionary held by variable
                        #      'curr_chat_interaction_dict'; if so than we assume that we have a format problem with
                        #      the file as this means two user chats were found back-to-back WITHOUT any LLM response.
                        #      Throw an exception whose message details this fault to effectively abort the parsing
                        #      process.
                        #
                        #  2). Check to see if any text follows the opening ">>>" sequence and, if so, extract that
                        #      text then add it to the 'curr_text_block' list.
                        #
                        #  3). Update variable 'inside_user_msg' to have a value of 'true' indicating that we are now
                        #      processing text from within the context of a user chat message.
                        #
                        if has_key(curr_chat_interaction_dict, parse_dictionary_user_msg_key)
                            # In this case the key already existed so it seems we have two user messages back-to-back
                            # without any LLM message in-between.  We currently don't support sending messages when an
                            # interaction gap has been found so throw an exception to abort the parse.
                            throw "[ERROR] - A chat interaction was found within the document on line " ..
                                  curr_buffer_line_cntr .. " where two user messages occurred in sequence WITHOUT " ..
                                  "any assistant message being present.  Message interactions must always occur in " ..
                                  "pairs of user/assistant messages (with exception given to the last chat " ..
                                  "interaction in the document) in order to be processed properly.  Please resolve " ..
                                  "this problem by adding the missing assistant response, fixing the delimiting " ..
                                  "tokens for the chat, or remove/comment out one of the user messages occuring in " ..
                                  "this region.  Note that due to this fault parsing of the current buffer content " ..
                                  "was unsuccesful and no further action was taken."
                        endif

                        var trimmed_message_start = substitute(curr_buff_line, '\v^\>\>\>', '', '')
                        if trimmed_message_start != ''
                            add(curr_text_block, trimmed_message_start)
                        endif

                        inside_user_msg = true

                    elseif curr_buff_line =~# '\v^\=\>\>(.)*'
                        # If the logic comes here than we've found the start to an "assistant" message and need to take
                        # the following actions:
                        #
                        #  1). Check to see if a key matching to the value held by varible
                        #      'parse_dictionary_user_msg_key' exists within the 'curr_chat_interaction_dict'.  If NOT
                        #      it means that no user message was found to proceed this assistant response and we will
                        #      assume we've got a corrupt or incomplete file.  In such a case output an error message to
                        #      the user then immediately return an empty dictionary to the caller as this effectively
                        #      aborts the parse.
                        #
                        # 2). Check to see if any text follows the opening "=>>" sequence and, if so, extract that text
                        #     then add it to the 'curr_text_block' list.
                        #
                        # 3). Update variable 'inside_llm_msg' to have a value of 'true' indicating that we are now
                        #     processing text from within the context of a user chat message.
                        #
                        if ! has_key(curr_chat_interaction_dict, parse_dictionary_user_msg_key)
                            # If the logic comes here it means we are wrapping up the parse for the current
                            # user/assisant dialog for a single chat interaction but no user message was found.  The
                            # assistant seems to have responded but we don't know to what.  Throw an exception to abort
                            # the parse and provide a message that indicates the nature of the fault to the user.
                            throw "[ERROR] - The chat interaction on line " .. curr_buffer_line_cntr ..
                                  " was found to be missing a user message; all chat interactions must be complete " ..
                                  "(i.e., contain BOTH user and assistant messages that are non-empty) except for " ..
                                  "the last chat found at the bottom of the buffer which may contain incomplete " ..
                                  "chat data. Please correct by filling in the missing information, fixing the " ..
                                  "delimiting tokens for the chat, or remove/comment out the chat interaction " ..
                                  "entirely from the buffer.  Note that due to this fault parsing of the buffer " ..
                                  "content has failed and no further actions were taken."
                        endif

                        var trimmed_message_start = substitute(curr_buff_line, '\v^\=\>\>', '', '')
                        if trimmed_message_start != ''
                            add(curr_text_block, trimmed_message_start)
                        endif

                        inside_llm_msg = true

                    else
                        # In this case we assume that we've got an error condition as we've encountered an unexpected
                        # text value within the body of the chat document.  Throw an exception to abort the parse and
                        # provide an error message that details the nature of the fault to the user.
                        throw "[ERROR] - Unexpected text was found in the chat buffer at line " ..
                              curr_buffer_line_cntr .. ".  Any text appearing within the body of a chat log " ..
                              "document must be (1) a comment, (2) a separator line, or (3) be part of a chat " ..
                              "message.  The text on the flagged line could not be resolved as any of these and " ..
                              "so cannot be properly understood by the parser.  Please fix this issue by either " ..
                              "removing/commenting out the text or move the text to be within the appropriate set " ..
                              "of chat markers if this should be seen as part of a message.  Due to this fault " ..
                              "parsing of the current buffer information has failed and no further actions were " ..
                              " taken."
                    endif

                endif

            endif

        endif

        # Always increment the 'curr_buffer_line' by one before the next loop iteration so we move forward to the next
        # buffer line.
        curr_buffer_line_cntr = curr_buffer_line_cntr + 1

    endwhile


    # Check to see if any of the parsing states were left unresolved now that we've finished processing the content of
    # the buffer.  Possible conditions to be addressed are the following:
    #
    #   1). The parse ended while still within the context of processing the header data (i.e., variable
    #       'inside_header' was still set to 'true').
    #
    #   2). The parse ended while still within the context of processing a user message (i.e., variable
    #       'inside_user_msg' was still set to 'true').
    #
    #   3). The parse ended while still within the context of processing an assistant message (i.e., variable
    #       'inside_llm_msg' was still set to 'true').
    #
    #   4). The 'curr_chat_interaction_dict' was left set to a non-empty value (but the parse was not in the context
    #       of processing any particular block of text or document segment).  This can happen when a user message was
    #       found but no assistant message existed leaving the chat interaction incomplete.  Note that this is common
    #       as the most recent chat may not have been sent to the LLM yet and therefore has only the user message
    #       present.
    #
    if inside_header
        # In this case we never found the start to the chat body which we will consider to be an error condition.
        # Throw an exception to abort the parse and attach a message to the user explaining the fault and how to
        # correct it.
        throw "[ERROR] - Parsing of the current chat buffer completed without ever finding the body section; this " ..
              "generally means that the division bar required to terminate the header section of the chat content " ..
              "is missing.  Please correct this issue by adding the sequence '* ENDSETUP *' to its own line " ..
              "immediately after the header information in the chat buffer.  Note that the '*' characters on the " ..
              "sequence may also be extended to any number so it is also acceptable to add a line like the " ..
              "following to fix this issue: '******* ENDSETUP ********'.  Due to this fault parsing of the chat " ..
              "buffer content was unsuccessful and no further actions were taken."
    endif

    if inside_user_msg
        # In this case we will assume that no ending token for the user message was found before the content in the
        # buffer was exhausted.  This is actually okay as we don't make any requirement that the user explicitly type
        # out the ending sequence for their chat IF such chat is the last one in the buffer.  Go ahead and finish
        # processing the user message by taking the following steps:
        #
        # 1). Check to see if the 'curr_text_block' is non-empty and IF SO proceed forward with the following:
        #
        #     A). Join all elements in the 'curr_text_block' back into a single string value (using a single space
        #         character between elements) then trim any leading or trailing whitespace in the joined text before
        #         calling a utility function to unescape any special sequences.
        #
        #     B). Add a new mapping between the key held by variable 'parse_dictionary_user_msg_key' and the string
        #         value obtained during step 'A' into the 'curr_chat_interaction_dict'.  Note that we don't check
        #         to see if any such key already exists since this chack was made when the processing entered the
        #         context of the user message (see the logic that handles the start token for the user message).
        #
        #     C). Reset the 'curr_text_block' variable back to an empty list since the text it was holding has now
        #         been integrated into the chat dictionary.  Note that while this is not technically necessary (since
        #         the parse is now complete) we do this just to make sure we don't accidently trip any other 'if'
        #         conditions that might be added later checking for buffered but unprocessed text.
        #
        # 2). Reset the 'inside_user_msg' variable to 'false' since the user message has now been fully processed.
        #     Again, this isn't strictly necessary since the parse is done but, as with the 'curr_text_block' we're
        #     trying to make sure we don't trigger any other checks that might be added later by leaving an inconsistent
        #     flag.
        #
        # 3). Check to see if the 'curr_chat_interaction_dict' is non-empty and IF SO than take the following steps:
        #
        #     A). Check to see if the 'parse_dictionary' variable already contains a key that is equal to the value
        #         held by variable 'parse_dictionary_messages_key' as this will determine how we add information to it
        #         in the next step.
        #
        #     B). If the 'parse_dictionary' already has a key for messages then append the 'curr_chat_interaction_dict'
        #         to the list that is attached to that key.  If no such key exists than add the
        #         'curr_chat_interaction_dict' into a new list then bind that list into the 'parse_dictionary' under the
        #         key held by variable 'parse_dictionary_messages_key'.
        #
        #     C). Reset variable 'curr_chat_interaction_dict' to store an empty dictionary as the chat interaction
        #         data it held has now been merged into the main parse dictionary that will be returned.  Note that, as
        #         with the other data buffering variables, we want to leave this in a consistent state with the actions
        #         we've taken even if doing this might not be strictly required anymore.
        #
        #     D). Check to see if the 'parse_dictionary' already has a key which matches to the value held by variable
        #         'parse_dictionary_parse_flags' as this will determine how we insert flag data in the steps that
        #         follow.
        #
        #     E). We now need to add the flag held by variable 'parse_flag_NO_USER_MSG_CLOSE' into the parse dictionary
        #         flag information so that downstream logic understands the last user message didn't actually have a
        #         proper closing tag (this will need to be added before something like an assistant response is written
        #         to the buffer).  If the 'parse_dictionary' already has a key for flags than we will simply add the new
        #         flag to the existing list that is keyed from the dictionary.  If no such key existed we will create a
        #         new list to hold the flag then will bind this into the 'parse_dictionary' under the
        #         'parse_flag_NO_USER_MSG_CLOSE' key.
        #
        # Some closing items for reference...
        #
        # * Why didn't we check to see if the 'curr_chat_interaction_dict' already contained a user message?  The way
        #   the parser is currently written it is not possible to encounter this condition unless the parser has a
        #   serious bug.  When the opening for a user message is encountered the logic verifies that no user message has
        #   already been seen for the current chat interaction; this means we couldn't have been in the middle of
        #   processing a user message with an existing user message already being held by the
        #   'curr_chat_interaction_dict'; the start for the 2nd user message would've already been flagged when
        #   encountered and the parse aborted.
        #
        #   Why didn't we check for any assistant message?  Seems that we do this earlier but here we're allowing this
        #   to be incomplete?  During a chat session it is expected that the last interaction may only have a user
        #   message since this is how the buffer will look when a new message is being sent to the LLM.  Hence if we
        #   tried to make such validation here we would make it impossible to submit new messages in the chat.
        #
        #   What about the empty message?  Isn't this an error and if so why are we stepping around it?  The buffer
        #   may need to be parsed for more actions than submitting a new chat message and since we will fill in the
        #   start token for the user message automatically (part of the ease of usability) we actually create the case
        #   for an empty user message to be present at the end of the buffer ourselves.  In the case that a chat WAS
        #   being submitted the logic for sending the chat will assume responsibility for ensuring that the last user
        #   message is non-empty before it tries to do anything.
        if !empty(curr_text_block)
            var joined_user_message_text = join(curr_text_block, ' ')

            joined_user_message_text = substitute(joined_user_message_text, '\v^\s+', '', '')
            joined_user_message_text = substitute(joined_user_message_text, '\v\s+\n*$', '', '')
            joined_user_message_text = substitute(joined_user_message_text, '\v\s+\n\n', '\n\n', 'g')
            joined_user_message_text = substitute(joined_user_message_text, '\v\n\n\s', '\n\n', 'g')

            var user_message_text = UnescapeSpecialSequences(joined_user_message_text)

            curr_chat_interaction_dict[parse_dictionary_user_msg_key] = user_message_text

            curr_text_block = []
        endif

        inside_user_msg = false

        if !empty(curr_chat_interaction_dict)
            if has_key(parse_dictionary, parse_dictionary_messages_key)
                add(parse_dictionary[parse_dictionary_messages_key], curr_chat_interaction_dict)
            else
                parse_dictionary[parse_dictionary_messages_key] = [curr_chat_interaction_dict]
            endif

            curr_chat_interaction_dict = {}

            if has_key(parse_dictionary, parse_dictionary_parse_flags)
                parse_dictionary[parse_dictionary_parse_flags][parse_flag_NO_USER_MSG_CLOSE] = ''
            else
                parse_dictionary[parse_dictionary_parse_flags] = {[parse_flag_NO_USER_MSG_CLOSE]: ''}
            endif

        endif

    endif


    if inside_llm_msg
        # For now we're going to consider this an error condition as it is unclear why the end token for the assistant
        # response is missing (we should add this ourselves when we populate responses into the chat buffer during a
        # message send action).  Why not just insert the missing tag and not trouble the user with this?  The issue is
        # that we don't know if the assistant response we were in the middle of is complete or is trunctated and if
        # truncated this could have an unwanted impact on the chat history.  It is better to call this out and have the
        # user review than try to sweep it under the rug unless some other means is found to ensure that such message
        # is in fact fully complete.
        throw "[ERROR] - The last assistant response message found at the bottom of the chat buffer is missing its " ..
              "closing chat marker and it is unclear if such information is in fact complete or truncated.  Please " ..
              "fix this issue by adding the closing '<<=' to the message and verify that the content for the " ..
              "assistant response is still complete/valid.  Due to this fault parsing of the chat buffer content " ..
              "has been aborted and no further actions were taken."
    endif


    if !empty(curr_chat_interaction_dict)
        # In this case it seems that we found some chat interaction content (likely the user message and possibly some
        # resource references based on how the parsing proceeds) but we never encountered the assistant message that
        # would close out the interaction.  Like the case for ending with an open user message, this actually isn't a
        # fault and the condition can be encountered if the user typed in the closing delimiter to their latest chat
        # before invoking an action that needed the buffer content parsed.  To handle this issue we will take the
        # following actions:
        #
        #  1). Check to see if the 'parse_dictionary' variable already contains a key that is equal to the value
        #      held by variable 'parse_dictionary_messages_key' as this will determine how we add information to it in
        #      the next step.
        #
        #  2). If the 'parse_dictionary' already has a key for messages then append the 'curr_chat_interaction_dict'
        #      to the list that is attached to that key.  If no such key exists then add the
        #      'curr_chat_interaction_dict' into a new list then bind that list into the 'parse_dictionary' under the
        #      key held by variable 'parse_dictionary_messages_key'.
        #
        #  3). Reset variable 'curr_chat_interaction_dict' to store an empty dictionary as the chat interaction data
        #      it held has now been merged into the main parse dictionary.  This step isn't fully necessary, from the
        #      context that the parse is over so we won't be using this variable to buffer anymore data, but we don't
        #      want to just leave the variable in a state inconsistent with the processing.  The main concern is that
        #      future condition checks may be added and by not being consistent with our state variables we may trigger
        #      cases that we shouldn't down the road.  Tidying up our state to account for the actions taken is the best
        #      policy to avoid unexpected bahaviors later on.
        #
        # Some additional items here...
        #
        # Why didn't we check what state the 'curr_chat_interaction_dict' was in before we just blindly added it to the
        # parse data?  Seems awfully hand wavy...  The truth here is that the current parsing process for chat
        # interactions is very simple and if we are in a state that (1) no particular message is being processed but (2)
        # the 'curr_chat_interaction_dict' is not empty then we must have processed a user message (fully) but never
        # made it to the assistant response.  How do we know this?  Before processing any user message the
        # 'curr_chat_interaction_dict' is empty; we make sure it starts in this state and that it returns to this state
        # after each chat interaction parse is completed (i.e., once parsing of the assistant message for the chat
        # occurs).  We also currently enforce that a user message appear in the chat BEFORE the assistant message so if
        # the 'curr_chat_interaction_dict' is not empty it must be that the user message just finished processing; this
        # is the only step that populates this variable and then leaves it in a populated state.  NOTE: Obviously if the
        # parser changes such that this deduction is wrong than the code here needs to be updated; part of the value in
        # writing all this down is to ensure that the assumption on which this logic is based can be referenced in the
        # future.
        if has_key(parse_dictionary, parse_dictionary_messages_key)
            add(parse_dictionary[parse_dictionary_messages_key], curr_chat_interaction_dict)
        else
            parse_dictionary[parse_dictionary_messages_key] = [curr_chat_interaction_dict]
        endif

        curr_chat_interaction_dict = {}

    endif


    # Return the 'parse_dictionary' back to the caller as the final parse result.
    return parse_dictionary

enddef


# This function is responsible for resolving any authorization token that should be used for requests sent to the
# LLM server.  If authorization should be used AND an authorization token is available than the function will return
# that token back to the caller.  If authorization should NOT be used for requests than the special value '-' will be
# returned back instead.  Finally, if authorization should be used BUT no authorization token could be resolved
# than the function will throw an exception whose message details the underlying nature of the fault encountered.
#
# Arguments:
#   parse_dict - The parse dictionary obtained by processing the chat log document that is associated with the logical
#                processing that invoked this function (in other words this function assumes that the need for auth
#                comes from the context of interacting with a remote LLM chat server and such interaction must have been
#                prompted from a buffer containing a chat document that gives the details needed for such interactions).
#                Note that parse dictionaries provided are expected to have a content and format that matches to the
#                dictionary returned by function ParseChatBufferToBlocks() in this script.
#
# Returns: A string value that can have any of the following forms:
#          (1) A non-empty String value of arbitrary content when the return is an authorization token that should be
#              attached to any request made to the LLM server.
#          (2) The special string value '-' when authorization is not necessary for requests and should therefore not
#              be included.
#
# Throws: Will throw an exception in the case that (1) authorization IS required but (2) the function could not resolve
#         the authorization token to be used.  The message for the exception in this case will always be a user
#         readable description of the issue encountered.
#
export def GetAuthToken(parse_dict: dict<any>): string
    # Extract the 'header' dictionary from the 'parse_dict' given and store its reference in a local variable for easier
    # access.  Note that if the 'parse_dict' given does NOT have a header dictionary we will consider the argument
    # invalid and we will throw an exception.
    var parse_dict_type = type(parse_dict)
    if parse_dict_type != v:t_dict || ! has_key(parse_dict, parse_dictionary_header_key)
        throw "[ERROR] - The 'parse_dict' argument given to this function either (1) was NOT a dictionary or (2) " ..
              "did not contain an embedded header dictionary for key '" .. parse_dictionary_header_key ..
              ".  In either case the argument cannot be used by this function to locate any auth token that should " ..
              "be used for requests to the LLM server."
    endif

    var header_dict = parse_dict[parse_dictionary_header_key]


    # Check to see if authorization is even necessary before we go through the work of trying to track down an
    # authorization token.  To do this we will check within the 'header_dict' given to see if (1) it contains a key
    # matching to the value held by constant 'parse_dictionary_header_auth_key' and if so (2) is the value associated
    # with such key equal to 'true'.
    #
    # We will also create a variable, 'requires_auth', which we will use to track whether or not an authentication
    # token should be used.  Note that the default setting for this variable will come from whether or not the
    # 'g:llmchat_apikey_file' was defined with a non-empty value.
    var requires_auth = exists("g:llmchat_apikey_file") && g:llmchat_apikey_file != '' ? true : false


    if has_key(header_dict, parse_dictionary_header_use_auth)
        # In this case the 'header_dict' contained an entry which details explicitly whether or not authorization is
        # required.  Retrieve the value from the dictionary and it is equal to 'true' then update variable
        # 'requires_auth' to be 'true'; otherwise set 'requires_auth' to be 'false'.  How do we know the else case is
        # correct?  The value set for key 'parse_dictionary_header_auth_key' may currently only have the values 'true'
        # or 'false' so we can reliably infer what the value must be if it was not equal to 'true'.
        if header_dict[parse_dictionary_header_use_auth] == "true"
            requires_auth = true
        else
            requires_auth = false
        endif

    else
        # If the logic comes here than we did not find any explicit declaration as to whether or not authentication is
        # required for requests.  In general we take this to mean that we should use the default initiailzation for
        # variable 'requires_auth' as the correct value (meaning that IF an auth key file was defined than assume we
        # need to use an authentication token and if no such file was given assume no auth is required).  However, there
        # is a slight usability edge case here which occurs when the user explicitly defines an 'Auth Token:'
        # declaration within the header.  If we were strict we would simply ignore such declaration and fall back to the
        # resolution path already defined forcing the user to correct their chat headers if they wanted us to use the
        # explicit token given.  The more user-friendly approach is to recognize that the user would not be providing
        # an explicit token in the chat if they didn't mean for us to use it and if this seems clear enough then why
        # beat around the bush making the user define the 'Use Auth Token:' declaration just for correctness?  This
        # later viewpoint is what we will be going with so we will check to see if any auth token was defined in the
        # 'header_dict' before assuming we have resolved the value for 'requires_auth' correctly.
        if has_key(header_dict, parse_dictionary_header_auth_key)
            # If the logic comes here than we DID find a token given explicitly in the chat.  Note that the token
            # resolution behavior also says that any token defined directly in the chat header will receive precedence
            # over tokens that might be found elsewhere so we already have what we need to resolve.  Go ahead and
            # return the token value held by the 'header_dict' back to the caller.
            return header_dict[parse_dictionary_header_auth_key]

        endif

    endif


    # By this point we should have resolved whether or not authentication is required and will use this information to
    # detemine the next steps to take.  Setup a variable, 'auth_token', which will be used to hold the authorization
    # token we should return to the caller.  By default this will be set to '-' (which means that auth is not required)
    # and the value can be adjusted by logic that will execute if 'requires_auth' has been set to 'true'.
    var auth_token = '-'

    if requires_auth
        # In this case we've determined that authentication for requests to the LLM server is necessary; now begin
        # trying to resolve what token we should return for such authentication.  The basic resolution priority for this
        # is outlined below:
        #
        #   1). Explicit Token in Chat - If the 'Auth_Token:' declaration was given in the chat header than this always
        #                                takes precidence over any other tokens we might resolve.
        #   2). Local Buffer Token - If variable 'b:llmchat_auth_token' was defined than this will become the token
        #                            we return to the user.
        #   3). Global Token Definition - If the 'g:llmchat_apikey_file' variable was defined than we will load
        #                                 its content into memory and return this as the auth token.
        #
        # Should we fail to resolve a token from any of the options given above than we will throw an exception whose
        # message indicates that no auth token could be resolved.
        # ---------------------------------------------------------------
        #  Resolution Step #1 - Look for an explicit token given in the chat headers (in our case this simply means
        #                       checking to see if the 'header_dict' contains a key matching to the value held by
        #                       constant 'parse_dictionary_header_auth_key').
        if has_key(header_dict, parse_dictionary_header_auth_key)
            # If the logic comes here than we found a token given explicitly in the chat.  Retrieve the provided token
            # from the 'header_dict' and set this as the token to return via variable 'auth_token'.
            auth_token = header_dict[parse_dictionary_header_auth_key]

        elseif exists('b:llmchat_auth_token') && b:llmchat_auth_token != ''
            #
            #  Resolution Step #2 - If the logic comes here than no explicit token was given within the chat document
            #                       BUT a buffer-local auth token variable was available so we will set the value it
            #                       holds as the auth token to use.
            auth_token = b:llmchat_auth_token

        elseif exists('g:llmchat_apikey_file') && g:llmchat_apikey_file != ''
            #
            # Resolution Step #3 - If the logic comes here than the 'g:llmchat_apikey_file' variable was defined with a
            #                      non-empty value and none of the earlier resolution options were available.  Go ahead
            # and read the file that the variable refers to then set the first line that it contains as the auth token
            # to be returned.
            auth_token = join(readfile(g:llmchat_apikey_file, '', 1), '')

         else
             # If the logic lands here than ALL attempts at resolving an auth token to return have failed; throw an
             # exception indicating that we know we need to add authentication to requests but can't find a token to
             # use.
             throw "[ERROR] - Examination of the current chat buffer and editor state indicates that authentication " ..
                   "is REQUIRED for requests to the remote server but no token to use for such authorization could " ..
                   "be resolved.  This situation can be fixed by ensuring that one of the following is true:\n" ..
                   " 1). An 'Auth Token' definition is provided explicitly in the chat with the token to be used.\n" ..
                   " 2). The buffer-local variable 'b:llmchat_auth_token' can be set to the token to use.\n" ..
                   " 3). Global variable 'g:llmchat_apikey_file' can be set to the path of a file containing the " ..
                   "token to use."
        endif

    endif


    # Return the final, resolved auth token back to the caller.
    return auth_token

enddef


# This function will extract the name/value pairing content from a given "Option:" definition then return such
# information within a list.  The element at index '0' in such list will hold the resolved option name and the element
# at index '1' will hold the resolved value.  If a problem is encountered while attempting to parse the given option
# definition than an exception will be thrown by the function.
#
# Arguments:
#   option_text - The option declaration that this function should parse the name/value pairing from.   Note that
#                 the text given should contain the leading "Option:" keyword and should also contain all data that
#                 was found on the same line as this keyword within the header segment of the chat.
#   line_num - The line number that the option declaration was found on within the header segment of the chat; this is
#              used in exception messages to report the location of bad option definitions.
#
# Returns: A 2-element list containing the extracted option data; the element at index 0 in this list will contain the
#          option name and the element at index 0 will contain the option value.
#
# Throws: Will throw an exception if a malformed option declaration is encountered within the 'option_text' value
#         supplied.
#
export def ParseChatOption(option_text: string, line_num: number): list<string>
    # Start processing of the provided option definition by stripping off the leading 'Option:' keyword along with any
    # leading and trailing whitespace it may have.
    var trimmed_option = substitute(option_text, '\v^\s*Option\:\s*', '', '')

    # Now validate that the trimmed option value has the general format 'ANYTHING = ANYTHING' by searching for the first
    # '=' symbol then assert that such symbol occurs within the option value.  Note that validations like proper name,
    # non-empty value, etc, will be handled later once we break the option value into "name" and "value" portions.
    var equals_index = stridx(trimmed_option, '=')
    if equals_index == -1
        # In this case the '=' symbol was not found anywhere within the option value so we assume the option value has
        # an invalid format.  Throw an exception to (1) halt any processing that was taking place and (2) to alert the
        # user to the problem.
        throw "[ERROR] - An 'Option:' declaration with an invalid format was encountered on line " .. line_num ..
              " within the current chat header content. Chat options must always be given values that have the " ..
              "general format 'name=value'; in this case no '=' symbol was found so it was not possible to " ..
              "distinguish the the 'name' portion from the 'value' portion of the option definition."
    endif

    # If the logic makes it here than we've located an '=' symbol within the raw option value; go ahead and break this
    # now into a 'name' value and a 'value' value.  We will then perform some final cleanup and validation on each.
    #
    # NOTE: Because the substring operation in Vim is inclusive of both ends we will actually still have the '=' symbol
    #       stuck at the end of the raw name value and at the beginning of the raw 'value' value; this is okay as we'll
    #       clean it up in a bit.
    var raw_option_name = trimmed_option[0 : equals_index]
    var raw_option_value = trimmed_option[equals_index :]


    # Cleanup the 'name' portion of the value pairing by taking the following actions:
    #
    #  1). Remove the trailing '=' symbol and any whitespace immediately proceeding it.
    #  2). Trim any whitespace from the beginning of the name.
    #
    var trimmed_name = substitute(raw_option_name, '\v\s*\=$', '', '')
    trimmed_name = substitute(trimmed_name, '\v^\s*', '', '')


    # Validate that the cleaned up 'name' portion of the pairing is NOT empty.  If this is empty than we'll throw an
    # exception to (1) halt any further processng and (2) to alert the user to the problem.
    if trimmed_name == ''
        throw "[ERROR] - An 'Option:' declaration with an invalid format was encountered within the content of " ..
              "the chat header at line " .. line_num .. ".  Chat options must always be given values that have " ..
              "the general format 'name=value' but in this case the 'name' portion of this value was absent.  " ..
              "Please correct this fault by amending the option declaration so that the 'name' segment of its " ..
              "definition holds at least one non-whitespace character."
    endif


    # Cleanup the 'value' portion of the value pairing by taking the following actions:
    #
    #  1). Remove the leading '=' symbol and any whitespace immediately following it.
    #  2). Trim any trailing whitespace from the end of the value.
    #
    var trimmed_value = substitute(raw_option_value, '\v^\=\s*', '', '')
    trimmed_value = substitute(trimmed_value, '\s*$', '', '')

    # Validate that the cleaned up 'value' porition of the pairing is NOT empty.  If this is empty than we'll throw
    # an exception to (1) halt any further processing and (2) to alert the user to the problem.
    if trimmed_value == ''
        throw "[ERROR] - An 'Option:' declaration with an invalid format was encountered within the content of " ..
              "the chat header at line " .. line_num .. ".  Chat options must always be given values that have " ..
              "the general format 'name=value' but in this case the 'value' portion of this value was absent.  " ..
              "Please correct this fault by amending the option declaration so that the 'value' segment of its " ..
              "definition holds at least one non-whitespace character."
    endif


    # If the logic makes it here than we assume that we have a valid option pairing; at least syntactically.  Go ahead
    # and put the option name/value pairing into a new list and return such list to the caller.
    return [trimmed_name, trimmed_value]

enddef


# This function is responsible for escaping the "special" sequences listed below within the provided 'text' string then
# returning the escaped text back to the caller:
#
#   * The sequence '>>>' (user message start)
#   * The sequence '=>>' (assistant message start)
#   * The sequence '<<<' (user message end)
#   * The sequence '<<=' (assistant message end)
#   * The sequence '['   (start of a resource reference in a user message)
#
# Arguments:
#   text - The string whose content is to be escaped.
#
# Returns: A string containing the same content as the 'text' argument given except that all "special" sequences have
#          been replaced with the appropriate escape sequence.
#
export def EscapeSpecialSequences(text: string): string
    # Escape the following sequences within the given 'text' if they are present then return the result to the caller:
    #
    #    * The sequence '>>>'; escape to '\>>>'
    #    * The sequence '=>>'; escape to '\=>>'
    #    * The sequence '<<<'; escape to '\<<<'
    #    * The sequence '<<='; escape to '\<<='
    #    * The sequence '['  ; escape to '\['
    #
    # What about the escape character itself (i.e., '\'); don't we need to escape this?  Escaping of the escape
    # character isn't needed because we're not reserving it and escaping the escape sequence itself can be done by
    # convention with just doubling the leading '\'.  How does this work?  Assume that we have the special sequence
    # '>>>' and we want to escape it so we do '\>>>'.  Now that creates a new "escaped" sequence that maybe we also want
    # to use now (and don't want replaced)... assume for example one day an LLM returns back this exact information in a
    # chat and we need to show the escape sequence.  So we double the leading '\', which itself isn't reserved and we
    # allow the logic to proceed as normal.  The unescaping process sees '\\>>>', replaces the '\>>>' with '>>>' and
    # doesn't touch the leading '\'.  This leaves us with '\>>>' which is what we wanted.  If we wanted to show the
    # '\\>>>' sequence we can do so by adding yet another leading '\'.  Note that the escaping/unescaping process
    # doesn't really care though; it still looks for just the original sequence and its escaped counterpart.
    #
    # NOTE: For escaping aren't we going a little further than necessary?  For instance in the parsing we have
    #       qualifications such as "line must start with" or "line must only contain" and yet here we're escaping the
    #       sequence "if it occurs".  This is intentional as we wouldn't be able to properly escape the escape sequences
    #       if we constrained this further.  Consider that we wouldn't, for instance, escape a line starting with
    #       '\>>>' because it DIDN'T start with '>>>'.  Now when we unescape we see only the original escape sequence
    #       (which was actually already escaped in the original text) and we mistakenly unescape it.  We want to avoid
    #       these problems which is why we are escaping at a more granular level than we strictly have to.
    #
    var escaped_text = substitute(text, '\v\>\>\>', '\\>>>', 'g')
    escaped_text = substitute(escaped_text, '\v\=\>\>', '\\=>>', 'g')
    escaped_text = substitute(escaped_text, '\v\<\<\<', '\\<<<', 'g')
    escaped_text = substitute(escaped_text, '\v\<\<\=', '\\<<=', 'g')
    return substitute(escaped_text, '\v\[', '\\[', 'g')

enddef


# This function is responsible for replacing any of the escaped sequences listed below with the original "special" text
# values that were escaped.
#
#   * The escaped sequence '\>>>' (escaped user message start)
#   * The escaped sequence '\=>>' (escaped assistant message start)
#   * The escaped sequence '\<<<' (escaped user message end)
#   * The escaped sequence '\<<=' (escaped assistant message end)
#   * The escaped sequence '\['   (escaped resource reference)
#   * The escaped sequence '\n'   (escaped newline in message)
#
# Arguments:
#   text - The string whose content is to be escaped.
#
# Returns: A string containing the same content as the 'text' argument given except that all escaped sequences have
#          been replaced with the original "special" sequences.
#
export def UnescapeSpecialSequences(text: string): string
    # Unescape the following sequences and return the resulting text to the caller:
    #
    #   * The sequence '\>>>'; unescape to '>>>'
    #   * The sequence '\=>>'; unescape to '=>>'
    #   * The sequence '\<<<'; unescape to '<<<'
    #   * The sequence '\<<='; unescape to '<<='
    #   * The sequence '\['  ; unescape to '['
    #   * The sequence '\n'  ; unescape to a newline character
    #
    # For details on why the leading character for the escape is not itself escaped see the inline comments within
    # function EscapeSpecialSequences(text).
    var escaped_text = substitute(text, '\v\\\>\>\>', '>>>', 'g')
    escaped_text = substitute(escaped_text, '\v\\\=\>\>', '=>>', 'g')
    escaped_text = substitute(escaped_text, '\v\\\<\<\<', '<<<', 'g')
    escaped_text = substitute(escaped_text, '\v\\\<\<\=', '<<=', 'g')
    escaped_text = substitute(escaped_text, '\v\\\[', '[', 'g')
    return substitute(escaped_text, '\v\\n', "\n", 'g')

enddef


# ============================
# ====                    ====
# ====  Main Script Logic ====
# ====                    ====
# ============================
#
# The following logic should run any time that this file is sourced by Vim and is typically used for initialization,
# optimization actions, or common values within the script.


    # --------------------------------------
    # ----  Parse Dictionary Variables  ----
    # --------------------------------------
#
# Declare some variables that will be used to hold the main keys under which parse information is stored within the
# dictionary returned by function ParseChatBufferToBlocks().  We do this because not only does the
# ParseChatBufferToBlocks() function need to refer to these keys but any function processing the returned dictionary
# will also need them.  Additionally we would rather not have the literal keys sprayed all over the code as this would
# make them harder to change in the future (additionally we won't get any kind of error if we typo a literal string key
# somewhere but we WILL get such an error if we typo the variable name holding such key; this makes it easier to avoid
# such bugs).
#
export const parse_dictionary_header_key = "header"
export const parse_dictionary_messages_key = "messages"
export const parse_dictionary_user_msg_key = "user"
export const parse_dictionary_user_resources_key = "user_resources"
export const parse_dictionary_assistant_msg_key = "assistant"
export const parse_dictionary_parse_flags = "flags"

# Header dictionary keys...
export const parse_dictionary_header_server_type = "server type"
export const parse_dictionary_header_server_url = "server url"
export const parse_dictionary_header_model_id = "model id"
export const parse_dictionary_header_use_auth = "use auth"
export const parse_dictionary_header_auth_key = "auth key"
export const parse_dictionary_header_system_prompt = "system prompt"
export const parse_dictionary_header_show_thinking = "show thinking"
export const parse_dictionary_header_options_dict = "options"


    # --------------------------------
    # ----  Parse Flag Variables  ----
    # --------------------------------
#
# Declare some variables that will be used to hold token identifiers for various "flags" created during the parsing
# process.  A "flag" is a simple notice indicating that something was found during parsing of the chat buffer
# that later logic may need to be aware of.  Typically this involves some of the leniency behaviors that we allow to
# make the logic easier for users to interact with (for example leaving off the closing tag for the most recent chat
# they've typed into the buffer).  Flags may have values associated with them or they may be more boolean in nature
# (i.e., what one thinks of with an argument flag... note that the name "flag" in this case comes more from the
# condition of having been "flagged" by the parser rather than indicating an argument whose simple presence means
# a condition).  For flags which don't actually need a value we will use the convention of assigning the empty string
# since these will be kept inside of a dictionary.  For details on the parser that will create these flags or the
# data structure that they will be added to see function ParseChatBufferToBlocks().

# This parser flag indicates that the last user message found in the chat buffer had no closing tag so logic updating
# the buffer with something like an assistant response will need to make sure that such tag is added.
export const parse_flag_NO_USER_MSG_CLOSE = "no-user-message-close"

