vim9script

#
# This script contains utility functions that are reused across various tests and so have been encapsulated into a
# separate file for portability.  Note that including these functions can be done in Vimscript with an 'import'
# statement; see ':help import' for additional details.
#
# NOTES:
#   (1) The 'vim-UT' plugin does NOT handle sourced, imported, or otherwise invoked utility scripts during test
#       execution.  Instead it seems the 'UTRun' command literally walks the test suite file you give it line-by-line
#       performing keyword replacements and focusing only on that one file; it therefore doesn't see or amend other
#       Vimscript files that might be in use by the testing.  The consequence is that nice *functions* you would define
#       in your test suite script (for example 'AssertEquals') won't be found by scripts that are included from outside
#       the test suite.  To perform assertions in such testing utilities you therefore need to directly reference the
#       *real* functions (for example lh#UT#assert_equals(..)).
#
#   (2) Because a test suite file is not being run directly by Vim, but is instead being interpreted and run after
#       replacements, be careful with things like relative file paths in 'import' or 'source' statements.  You'll also
#       find that some expansions result in unexpected paths as well since they may happen outside the context of the
#       test suite file itself.  Based on experience with this, the recommendation is to use import paths that are
#       neither absolute nor relative so that such paths are looked up in reference to Vims runtime path (this seems
#       to reliably locate scripts regardless of the final context under which a the import is run); for more details
#       on defining such paths see ':help import'.
#

# =====================================
# ===                              ====
# ===  Test Constant Declarations  ====
# ===                              ====
# =====================================
# The following declarations represent constants that are needed by the utilities within this script as well as
# potentially tests using this script.

# This constant holds the plugin default value this test expects for variable 'g:llmchat_default_server_type'.
const default_llm_default_server_type_value = "Ollama"

# This constant holds the plugin default value this test expects for variable 'g:llmchat_default_server_url'.
const default_llmchat_default_server_url_value = "http://localhost:11434"

# This constant holds the plugin default value this test expects for variable 'g:llmchat_default_model_id'.
const default_llmchat_default_model_id_value = ''

# This constant holds the plugin default value this test expects for variable 'g:llmchat_default_system_prompt'.
const default_llmchat_default_system_prompt_value = ''

# This constant holds the plugin default value this test expects for variable 'g:llmchat_apikey_file'.
const default_llmchat_apikey_file_value = ''

# This constant holds the plugin default value this test expects for variable 'g:llmchat_open_splits_in_insert_mode'.
const default_llmchat_open_new_chats_in_insert_mode_value = 1

# This constant holds the plugin default value this test expects for variable 'g:llmchat_chat_split_type'.
const default_llmchat_chat_split_type_value = "horizontal"

# This constant holds the plugin default value this test expects for variable 'g:llmchat_header_sep_size'.
const default_llmchat_header_sep_size_value = 28

# This constant holds the plugin default value this test expects for variable 'g:llmchat_separator_bar_size'.
const default_llmchat_separator_bar_size_value = 28

# This constant holds the plugin default value this text expects for variable
# 'g:llmchat_assistant_message_follow_style'.
const default_llmchat_assistant_message_follow_style = 0

# This constant holds the plugin default value this test expects for variable 'g:llmchat_use_streaming_mode'.
const default_llmchat_use_streaming_mode = 0

# This constant holds the plugin default value this test expects for variable 'g:llmchat_curl_extra_args'.
const default_llmchat_curl_extra_args = ''


# =================================
# ====                         ====
# ====  Function Declarations  ====
# ====                         ====
# =================================


# This function asserts that the content of the buffer whose 'buffer_id' is provided matches exactly to the string
# value 'expected_content'.  If the match between the expected content and the actual buffer content is successful
# than this function will quietly exit; if the match is unsuccessful than the invoking test will be failed.  Note that
# internally the function uses the various assertion functions made available from the vim-UT plugin to handle content
# verifications.
#
# Arguments:
#   line_num - The line number within the invoking script or test suite; this is used for error reporting during the
#              final test execution.  Note that this should almost always be set to "expand('<sflnum>')" or
#              "expand('<sflnum>') - bias" where "bias" is a numerical value that corrects the offset (the actual
#              script run by UTRun does NOT always track exactly by line number to the test suite file).
#   buffer_id - The numeric ID assigned to the buffer (see the help information for function bufnr() for details on
#               how to obtain the ID of a buffer).
#  expected_content - A String value representing all content that should be found within the specified buffer.  Note
#                      that newline sequences should be used to separate the content of individual lines within the
#                      provided value.
#
# Returns: None.
#
export def AssertBufferContents(line_num: number, buffer_id: number, expected_content: any)
    # Start processing by obtaining a list containing all lines held by the buffer with the given ID.
    var actual_buf_lines = getbufline(buffer_id, 0, '$')

    # Now split the given 'expected_content' string on all newline sequences that it contains to obtain a list of
    # *expected* lines.
    var expected_buf_lines = split(expected_content, '\n')

    # Iterate over all lines that both lists have in common and compare each one in turn.  Later we will assert that
    # the lists are the same size but doing this upfront tends to provide less information than showing the differences
    # first.
    var actual_buf_lines_len = len(actual_buf_lines)
    var expected_buf_lines_len = len(expected_buf_lines)

    var common_end = actual_buf_lines_len < expected_buf_lines_len ? actual_buf_lines_len : expected_buf_lines_len

    var line_cntr = 0
    while line_cntr < common_end
        # Why use the 'assert_txt()' function here instead of assert_equals()?  The issue is that we want to pass a
        # custom message that tells us which line the mismatch was on and what was found.  Unfortuntely the
        # assert_equals() function hard codes the message and won't let us pass one in so we will use assert_txt()
        # because it will let us pass such a message.
        var mismatch_message = "Mismatch found on line " .. line_cntr .. "; expected '" ..
                                 expected_buf_lines[line_cntr] .. "' but instead found '" ..
                                 actual_buf_lines[line_cntr] .. "'"

        lh#UT#assert_txt('',
                         line_num,
                         actual_buf_lines[line_cntr] == expected_buf_lines[line_cntr],
                         mismatch_message)

        # Increment the line counter by 1 before the next loop iteration.
        line_cntr = line_cntr + 1

    endwhile

    # Same note as previous regarding the choice of assertion function; we use assert_txt() because we can craft the
    # message we want to show if the assertion fails.
    var buffer_size_diff_msg = "Actual buffer size differed from expected content size; actual size = " ..
                               actual_buf_lines_len .. ", expected size = " .. expected_buf_lines_len
    lh#UT#assert_txt('',
                     line_num,
                     actual_buf_lines_len == expected_buf_lines_len,
                     buffer_size_diff_msg)
enddef


# This is a convenience function for immediately failing any test that invokes it.  Additionally the function allows
# a custom message to be provided to it that describes the reason why the test was failed.  Tests may use this function
# in conjunction with more complex validation processes that are difficult to match to one of the available assert
# functions provided by the testing framework.
#
# Arguments:
#   line_num - The line number within the invoking script or test suite; this is used for error reporting during the
#              final test execution.  Note that this should almost always be set to "expand('<sflnum>')" or
#              "expand('<sflnum>') - bias" where "bias" is a numerical value that corrects the offset (the actual
#              script run by UTRun does NOT always track exactly by line number to the test suite file).
#   msg - A custom message describing the reason why the test was failed.
#
# Returns: None
#
export def Fail(line_num: number, msg: string)
    # In order to "fail" a test through the vim-UT testing framework we will simply call the assert_txt() function with
    # an "expression" that is set to 0 (i.e., 'false').  Note that we will also pass the "bang" argument as '!' which
    # should cause the test execution to immediately halt for the current test case (this would be the behavior in other
    # testing frameworks like JUnit when the test is asked to fail).
    call lh#UT#assert_txt('!', line_num, 0, msg)

enddef


# This is a utility function for comparing two values, optionally as part of the examination of a larger data
# structure.  If the values compare as equivalent than no action will be taken by the function but if the values
# compare as different the function will (1) add a failure to the test that invoked it then (2) return with a value of
# 'false' (failed).
#
# Note that the primary reason for creating this function (as opposed to simply calling AssertEquals(..)
# as provided by the 'vim-UT' plugin) was to assist in describing where differences were found in large, aggregate
# data structures.  The stock comparison performed by 'AssertEquals(...)' would simply attempt to dump the string
# representation of both structures to the quickfix window and if that resulted in a line that was too long than
# information was simply.. truncated.  This function can be used for such comparisons and will attempt to provide
# a path to the located difference thereby shrinking the reported information to a smaller amount (hopefully what will
# fit within the line length constraint of the quickfix window).
#
# Arguments:
#   line_num - The line number within the invoking script or test suite; this is used for error reporting during the
#              final test execution.  Note that this should almost always be set to "expand('<sflnum>')" or
#              "expand('<sflnum>') - bias" where "bias" is a numerical value that corrects the offset (the actual
#              script run by UTRun does NOT always track exactly by line number to the test suite file).
#   prior_path - A string value used to track where within a larger data structure the comparison is taking place; when
#                calling to this function from a test this argument should simply be given as the empty string ("").
#   expected_value - The value that was expected by the invoking test.  Note that this value can be of any type
#                    (including lists and dictionaries) and special handling based on the type will be taken care of
#                    where necessary inside the function.
#   actual_value - The actual value that was found during the test execution.  Like the 'expected_value' argument this
#                  can be of any type including a list or a dictionary.
#
# Returns: A value of 'true' if the assertion was successful (i.e., the values compared as equivalent) and returns
#          'false' (failed) otherwise.
#
export def AssertEqualValues(line_num: number, prior_path: string, expected_value: any, actual_value: any): bool
    # Check to see if the 'expected_value' is the same type as the 'actual_value'.
    var expected_value_type = type(expected_value)
    var actual_value_type = type(actual_value)
    if expected_value_type != actual_value_type
        # In this case the values given were NOT the same type; invoke the 'assert_txt(..)' function in such a way that
        # it will add a failure for the current test and then immediately return with a value of 'false' (i.e.,
        # "failed").
        var assert_fail_msg = "The expected and actual values given "

        if prior_path != ''
            assert_fail_msg = assert_fail_msg .. "(found at data structure path '" .. prior_path .. "')"

        endif

        assert_fail_msg = assert_fail_msg .. " were of different types; expected type = " ..  expected_value_type ..
                          ", actual type = " .. actual_value_type ..  "; see ':help type()' for details."

        lh#UT#assert_txt('', line_num, 0, assert_fail_msg)
        return false

    endif

    # If the logic makes it here than we assume that both the 'expected_value' and the 'actual_value' arguments provided
    # are the same type of data; use this type to decide if we can handle the assertion here or if we should call to
    # a helper function.
    if expected_value_type == v:t_dict
        # In this case the values are dictionaries so we will call to function 'AssertEqualDictionaries(...)' (in this
        # file) to compare the values.
        return AssertEqualDictionaries(line_num, prior_path, expected_value, actual_value)

    elseif expected_value_type == v:t_list
        # In this case the values are lists so we will call to function 'AssertEqualLists(...)' (in this file) to
        # compare the values.
        return AssertEqualLists(line_num, prior_path, expected_value, actual_value)

    elseif expected_value_type == v:t_string && (len(expected_value) > 30 || len(actual_value) > 30)
        # In this case the expected and actual values we want to compare are strings BUT the values are fairly large.
        # We will assume that such variables may actualy represent a "text block" and if we tried to create a message
        # detailing a comparison fault for such a block it would end up truncated in the quickfix window.  Our
        # workaround will be to call a special utility function that will parse up such a block into lines and then
        # validate such lines one at a time.  This allows us to not only get meaninful information about the
        # comparison should it fail but it will also help to pinpoint where the comparison difference occured.
        return AssertEqualTextBlocks(line_num, prior_path, expected_value, actual_value)

    else
       # In this case we assume that we can just directly compare the values for equality.  If the expected and actual
       # values given are equal than we will take no action but if they are not we will invoke the 'assert_txt(...)'
       # function in such a way that it adds a failure to the current test and then we will immediately return with a
       # value of 'false' (i.e., "failed").
       #
       # NOTE: We will always enforce case sensitive comparisons here so that string values are matched exactly.  We
       #       assume that for other data types the use of case sensitivity won't matter.
       #
       if expected_value !=# actual_value
           # If the logic comes here than the values were NOT actually equal.  We now need to take the following
           # steps:
           #
           #   1). Construct a brief but descriptive message detailing the fault then invoke function 'assert_txt(...)'
           #       with the message in such a way that it will add a failure to the invoking test.
           #
           #   2). Immediately return with a value of 'false' indicating to the caller that the equality assertion has
           #       failed.
           #
           var assert_fail_msg = "The expected value of '" .. expected_value .. "'"

           if prior_path != ''
               assert_fail_msg = assert_fail_msg .. ' (found at data structure path "' .. prior_path ..  '")'

           endif

           assert_fail_msg = assert_fail_msg .. " was not equal to the actual value '" .. actual_value .. "'"

           lh#UT#assert_txt('', line_num, 0, assert_fail_msg)
           return false

       else
           # If the logic comes here than the values given are identical; simply return back a value of 'true' since the
           # comparison was successful.
           return true

       endif

    endif

enddef


# This is a utility function for comparing two dictionaries, optionally as part of the introspection on a larger data
# structure.  If the dictionaries given are equivalent (i.e., both dictionaries contain the same set of keys and for
# each key an equivalent value is held in each dictionary) than no action will be taken by the function but if the
# dictionaries compare as different the function will (1) add a failure to the test that invoked it then (2) return
# with a value of 'false' (failed).
#
# Note that the primary reason for creating this function (as opposed to simply calling AssertEquals(...)) as provided
# by the 'vim-UT' plugin) was to assist in describing where differences were found in large, aggregate data structures.
# The stock comparison performed by 'AssertEquals(...)' would simply attempt to dump the string representation of both
# structures to the quickfix window and if that resulted in a line that was too long than information was simply..
# truncated.  This function can be used for such comparisons and will attempt to provide a path to the located
# difference then only the value difference found; the smaller and more targeted output yields a message more likely to
# fit within the line constaints of the quickfix window (as opposed to dumping the entire data structure for both the
# expected and acutal values).
#
# Arguments:
#   line_num - The line number within the invoking script or test suite; this is used for error reporting during the
#              final test execution.  Note that this should almost always be set to "expand('<sflnum>')" or
#              "expand('<sflnum>') - bias" where "bias" is a numerical value that corrects the offset (the actual
#              script run by UTRun does NOT always track exactly by line number to the test suite file).
#   prior_path - A string value used to track where within a larger data structure the comparison is taking place; when
#                calling to this function from a test this argument should simply be given as the empty string ("").
#   expected_dict - The dictionary that was expected by the invoking test.
#   actual_dict - The actual dictionary that was found during test execution.
#
# Returns: A value of 'true' if the assertion was successful (i.e., if both dictionaries compare as equivalent) and
#          returns 'false' (failed) otherwise.
#
export def AssertEqualDictionaries(line_num: number,
                                   prior_path: string,
                                   expected_dict: dict<any>,
                                   actual_dict: dict<any>): bool
    # Begin the dictionary comparison by getting a list of the keys in each dictionary then assert that such lists are
    # the same.  Note that since we already have a utililty function for asserting lists we will simply invoke this here
    # and ensure that the keys lists we pass are ordered such that a general list comparison is applicable.
    #
    # NOTE: The documentation for Vim says that function keys() will return a list of keys in arbitrary order so we will
    #       need to sort such lists before we try to compare them.
    #
    # NOTE 2: We will append the special prior path "{<KEYS>}" to indicate during a list comparison that we're comparing
    #         the keys returned from a dictionary.  Additionally we will always append any prior path to the start of
    #         this special path for context (i.e., this may not be a top-level dictionary that we're doing a key
    #         comparison for; in such a case we don't want to loose where in the larger data structure this comparison
    #         is happening).
    #
    var sorted_expected_dict_keys = sort(keys(expected_dict))
    var sorted_actual_dict_keys = sort(keys(actual_dict))

    var key_compare_result = AssertEqualLists(line_num,
                                              prior_path .. "{<KEYS>}",
                                              sorted_expected_dict_keys,
                                              sorted_actual_dict_keys)
    if key_compare_result
        # In this case the key comparison between dictionaries was succssful so we now need to iterate through each
        # key and compare the values held by each dictionary for the key.  Note that the "prior path" in this case
        # will be updated to include a suffix with the notation " => '<KEYNAME>'" (where "KEYNAME" is replaced with the
        # actual name of the key we're checking the values for) so that we can see where the comparison is within the
        # larger data structure.
        for curr_dict_key in sorted_expected_dict_keys
            var new_prior_path = prior_path .. " => '" .. curr_dict_key .. "'"

            # Call to a utility function to handle the value comparison.  This allows us to compare any type of value
            # here by doing so recursively as we traverse the dictionary structure.  Additionally, if the comparison
            # is NOT successful, we will terminate our traversal and immediately return with a value of 'false'
            # (failed).
            if ! AssertEqualValues(line_num,
                                   new_prior_path,
                                   expected_dict[curr_dict_key],
                                   actual_dict[curr_dict_key])
                return false

            endif

        endfor

    else
        # If the logic comes here it means that the key comparison failed and therefore the expected dictionary has
        # different content than the actual dictionary.  Simply return back the value 'false' to the caller indicating
        # that the comparison has completed unsuccessfully.  Note that we don't provide any message here as we expect
        # the list comparison has already done so when it detected the difference.
        return false

    endif

    # If the logic made it all the way here than it seems that both dictionaries provided had the same keys and same
    # values for each key; return 'true' since the comparison was successful.
    return true

enddef


# This is a utility function for comparing two lists, optionally as part of the introspection on a larger data
# structure.  If the lists given are equivalent (i.e., both lists are the same size and hold an equivalent value at
# each common index position) than no action will be taken by the function but if the lists compare as different the
# function will (1) add a failure to the test that invoked it then (2) return with a value of 'false' (failed).
#
# Note that the primary reason for creating this function (as opposed to simply calling AssertEquals(...) as provided
# by the 'vim-UT' plugin) was to assist in describing where differences were found within large, aggregate data
# structures.  The stock comparison performed by 'AssertEquals(...)' would simply attempt to dump the string
# representation of both structures to the quickfix window and if that resulted in a line that was too long than
# information was simply.. truncated.  This function can be used for such comparisons as it will attempt to provide a
# an abbreviated difference message that includes only (1) path to the located difference and (2) the actual value
# difference found (this will be within the context of something like a specific element found inside the list).
#
# Arguments:
#   line_num - The line number within the invoking script or test suite; this is used for error reporting during the
#              final test execution.  Note that this should almost always be set to "expand('<sflnum>')" or
#              "expand('<sflnum>') - bias" where "bias" is a numerical value that corrects the offset (the actual
#              script run by UTRun does NOT always track exactly by line number to the test suite file).
#   prior_path - A string value used to track where within a larger data structure the comparison is taking place; when
#                calling to this function from a test this argument should simply be given as the empty string ("").
#   expected_list - The list that was expected by the invoking test.
#   actual_list - The actual list that was found during the test execution.
#
# Returns: A value of 'true' if the assertion was successful (i.e., if both lists compare as equivalent) and returns
#          'false' (failed) otherwise.
#
export def AssertEqualLists(line_num: number,
                            prior_path: string,
                            expected_list: list<any>,
                            actual_list: list<any>): bool
    # Retrieve the size of both lists and determine what "common" set of elements we can traverse.  In general
    # attempting comparison of the common list elements up front is more insightful than checking their sizes initially
    # and then failing.  For this reason we will compare as much of both lists as we can FIRST then we will check to see
    # if the lists sizes happen to also be the same.
    var expected_list_size = len(expected_list)
    var actual_list_size = len(actual_list)

    var common_list_size = expected_list_size <= actual_list_size ? expected_list_size : actual_list_size
    var list_index = 0

    while list_index < common_list_size
        # Update the 'prior_path' value received by this function with a suffix of the following form: " => [<IDX>]".
        # Note that <IDX> will be replaced by the current 'list_index' being used during the loop iteration.
        var new_prior_path = prior_path .. " => [" .. list_index .. "]"

        # Now call out to a utility function to handle the comparison of values found in both lists at the current index
        # position.  If the comparison is successful than we will continue looping but if the comparison fails (i.e., a
        # value of 'false' was returned) than we will immediately exit this function also with a return of 'false'
        # (comparison failed).
        if ! AssertEqualValues(line_num, new_prior_path, expected_list[list_index], actual_list[list_index])
            return false

        endif

        # Always increment the 'list_index' variable by 1 before the next loop iteration.
        list_index = list_index + 1

    endwhile

    # At this point we've iterated through the "common" portions of both given lists so we now need to see if the lists
    # provided were the same size.  If the size is identical than we have already compared the full content of both
    # lists and there is no further action to take.  If the size is NOT identical we will construct a message detailing
    # the difference then pass it to the 'assert_txt(...)' function as part of a call intended to make the 'vim-UT'
    # plugin increment the tallied test failures; we will also then exit this function execution with a return of
    # 'false' (failed).
    if expected_list_size != actual_list_size
        var assert_fail_msg = "The size of the expected list "

        if prior_path != ''
            assert_fail_msg = assert_fail_msg .. '(found at data structure path "' .. prior_path .. '")'

        endif

        assert_fail_msg = assert_fail_msg .. " had a size of '" .. expected_list_size ..
                          "' but the actual list found has a size of '" .. actual_list_size .. "'.  The content of " ..
                          "the actual list provided at the time of this fault was: " .. string(actual_list)
        lh#UT#assert_txt('', line_num, 0, assert_fail_msg)
        return false

    endif

    # If the comparison logic reaches this point than the lists appear to be equal; go ahead and return back a value of
    # 'true' indicating success.
    return true

enddef


# This is a utility function for comparing two text blocks, optionally as part of the introspection on a larger data
# structure.  If the text strings given are equivalent (i.e., both values are the same size and hold an equivalent
# value on each logical line) than no action will be taken by the function but if the text strings compare as different
# the function will (1) add a failure to the test that invoked it then (2) return with a value of 'false' (failed).
#
# Note that the primary reason for creating this function (as opposed to simply comparing the given string values with
# AssertEquals(...)) was to assist in describing where differences were found within large blocks of text that may
# contain one or more newline sequences.  The reporting peformed by the various "assert" functions in the vim-UT plugin
# does not seem to surface multi-line expected and actual values resulting in truncated error messages when an
# unexpected difference is encountered.  This function attempts to combat that by breaking down the 'expected_text'
# and 'actual_text' arguments given into a series of lines that are then compared; the first line difference found
# between the blocks is then reported and can be shown in the quickfix window results.
#
# Arguments:
#   line_num - The line number within the invoking script or test suite; this is used for error reporting during the
#              final test execution.  Note that this should almost always be set to "expand('<sflnum>')" or
#              "expand('<sflnum>') - bias" where "bias" is a numerical value that corrects the offset (the actual
#              script run by UTRun does NOT always track exactly by line number to the test suite file).
#   prior_path - A string value used to track where within a larger data structure the comparison is taking place; when
#                calling to this function from a test this argument should simply be given as the empty string ("").
#   expected_text - A string argument that holds the expected text the test expects to find.
#   actual_text - A string argument that holds the actual text found by the test execution.
#   line_sep - (Optional) The separator string that should be used for breaking down both the 'expected_text' and
#              'actual_text' arguments given into a series of "lines" that can be compared one at a time to perform
#              the equivalence checking.
#
# Returns: A value of 'true' if the assertion was successful (i.e., if both text values given compared as equivalent)
#          and returns 'false' (failed) otherwise.
#
export def AssertEqualTextBlocks(line_num: number,
                                 prior_path: string,
                                 expected_text: string,
                                 actual_text: string,
                                 line_sep = "\n"): bool
    # Break the 'expected_text' and 'actual_text' strings into lists using the 'line_sep' argument as the separation
    # delimiter.
    var expected_line_list = split(expected_text, line_sep)
    var actual_line_list = split(actual_text, line_sep)


    # Now retrieve the size of both line lists and determine what "common" set of elements we can traverse.  In general
    # attempting comparison of the values in common is more insightful than checking the line sizes up front then
    # failing if they are different.  For this reason we will compare as many lines in both lists as possible FIRST then
    # we will check to see if the line lists are actually the same size.
    var expected_line_list_size = len(expected_line_list)
    var actual_line_list_size = len(actual_line_list)

    var common_line_list_size = expected_line_list_size <= actual_line_list_size
                                ? expected_line_list_size
                                : actual_line_list_size
    var line_list_index = 0

    while line_list_index < common_line_list_size
        # Update the 'prior_path' value received by this function with a suffix of the following form:
        # " => LINE[<IDX>]".  Note that <IDX> will be replaced by the current 'line_list_index' value being used during
        # the loop iteration.
        var new_prior_path = prior_path .. " => LINE[" .. line_list_index .. "]"

        # Compare the lines in both lists that are at 'line_list_index' and if they are different then take actions that
        # (1) will fail the test and (2) which will produce a test failure message that *hopefully* allows the details
        # of the difference to be seen in the quickfix window.
        if expected_line_list[line_list_index] !=# actual_line_list[line_list_index]
            # If the logic comes here than the lines are different.  Create a detail message that explains where the
            # difference was found, and which lines were being compared, then invoke function 'assert_txt' in such a way
            # that it will add a failure for the current test.
            var assert_fail_msg = "The expected and actual lines found at "

            if prior_path == ''
                assert_fail_msg = assert_fail_msg .. "text index position '" ..  line_list_index .. "'"
            else
                assert_fail_msg = assert_fail_msg .. 'data structure path "' ..  new_prior_path .. '"'
            endif

            assert_fail_msg = assert_fail_msg ..  " were different.  Expected line = '" ..
                              expected_line_list[line_list_index] .. "', actual line = '" ..
                              actual_line_list[line_list_index] .. "'"
            lh#UT#assert_txt('', line_num, 0, assert_fail_msg)

            # Now immediately return 'false' as this function is designed to halt comparisons on the first found
            # difference.
            return 0

        endif

        # Always increment the 'line_list_index' variable by 1 before the next loop iteration.
        line_list_index = line_list_index + 1

    endwhile

    # At this point we've iterated through the "common" portions of both line lists so we now need to see if the line
    # lists were the same size.  If the size is identical than we have already compared the full content of both lists
    # (so the full content of the provided text values) and there is no futher action to take.  If the size is NOT
    # identical we will construct a message detailing the difference and pass it to the 'assert_txt(...)' function as
    # part of a call indented to make the 'vim-UT' plugin increment the failure count for the current test; we will also
    # then exit this function execution with a return of 'false' (failed).
    if expected_line_list_size != actual_line_list_size
        var assert_fail_msg = "The number of lines found in the expected text "

        if prior_path != ''
            assert_fail_msg = assert_fail_msg .. '(found at data structure path "' .. prior_path .. '") '
        endif

        assert_fail_msg = assert_fail_msg .. "did not match to the actual text lines found; expected lines " ..
                          "= " .. expected_line_list_size .. ", actual lines = " ..  actual_line_list_size
        lh#UT#assert_txt('', line_num, 0, assert_fail_msg)
        return false

    endif

    # If the comparison logic reaches this point than the text values appear to be equal; go ahead and return back a
    # value of 'true' indicating success.
    return true

enddef


# This function will examine all global variables recognized by this plugin and will reset any such variable having a
# custom value back to the "default" assigned by this plugin.  Such functioning allows tests to "reset" the editor
# back to a known and expected state before running code assertions.  Upon completion this function will return back
# a dictionary holding a mapping between (1) any global variable that was reset and (2) the value such variable had
# before being set back to its plugin default.  At the end of testing the returned dictionary can be passed to function
# RestoreGlobalVars() to perform a bulk restore of all global variable values that were changed.
#
# Returns: A dictionary containing a mapping between (1) the name of any global variable that was reset by this
#          function and (2) the value such variable had prior to the reset.
#
export def ResetGlobalVars(): dict<any>
    # Declare a dictionary that we will use to hold all "orginal" global variable values that are overwritten when
    # such variables are "reset" to their plugin defaults.  Ultimately this dictionary will be returned back to the
    # caller and may be given to function RestoreGlobalVars() later on to restore back the values.
    var orig_values_dict = {}

    # Check to see if the 'g:llmchat_default_server_type' variable has been set to a non-default value and if so backup
    # its current value within the 'orig_values_dict' before resetting it to the plugin default.
    if g:llmchat_default_server_type != default_llm_default_server_type_value
        orig_values_dict["g:llmchat_default_server_type"] = g:llmchat_default_server_type
        g:llmchat_default_server_type = default_llm_default_server_type_value
    endif


    # Check to see if the 'g:llmchat_default_server_url' variable has been set to a non-default value and if so backup
    # its value within the 'orig_values_dict' before resetting it to the plugin default.
    if g:llmchat_default_server_url != default_llmchat_default_server_url_value
        orig_values_dict["g:llmchat_default_server_url"] = g:llmchat_default_server_url
        g:llmchat_default_server_url = default_llmchat_default_server_url_value
    endif


    # Check to see if the 'g:llmchat_default_model_id' variable has been set to a non-default value and if so backup
    # its value within the 'orig_values_dict' before resetting it to the plugin default.
    if g:llmchat_default_model_id != default_llmchat_default_model_id_value
        orig_values_dict["g:llmchat_default_model_id"] = g:llmchat_default_model_id
        g:llmchat_default_model_id = default_llmchat_default_model_id_value
    endif


    # Check to see if the 'g:llmchat_default_system_prompt' variable has been set to a non-default value and if so
    # backup its value within the 'orig_values_dict' before resetting it to the plugin default.
    if g:llmchat_default_system_prompt != default_llmchat_default_system_prompt_value
        orig_values_dict["g:llmchat_default_system_prompt"] = g:llmchat_default_system_prompt
        g:llmchat_default_system_prompt = default_llmchat_default_system_prompt_value
    endif


    # Check to see if the 'g:llmchat_apikey_file' variable has been set to a non-default value and if so backup its
    # value within the 'orig_values_dict' before resetting it to the plugin default.
    if g:llmchat_apikey_file != default_llmchat_apikey_file_value
        orig_values_dict["g:llmchat_apikey_file"] = g:llmchat_apikey_file
        g:llmchat_apikey_file = default_llmchat_apikey_file_value
    endif


    # Check to see if the 'g:llmchat_open_splits_in_insert_mode' variable has been set to a non-default value and if so
    # backup its value within the 'orig_values_dict' before resetting it to the plugin default.
    if g:llmchat_open_new_chats_in_insert_mode != default_llmchat_open_new_chats_in_insert_mode_value
        orig_values_dict["g:llmchat_open_new_chats_in_insert_mode"] = g:llmchat_open_new_chats_in_insert_mode
        g:llmchat_open_new_chats_in_insert_mode = default_llmchat_open_new_chats_in_insert_mode_value
    endif


    # Check to see if the 'g:llmchat_chat_split_type' variable has been set a non-default value and if so backup its
    # value within the 'orig_values_dict' before resetting it to the plugin default.
    if g:llmchat_chat_split_type != default_llmchat_chat_split_type_value
        orig_values_dict["g:llmchat_chat_split_type"] = g:llmchat_chat_split_type
        g:llmchat_chat_split_type = default_llmchat_chat_split_type_value
    endif


    # Check to see if the 'g:llmchat_header_sep_size' variable has been set to a non-default value and if so backup its
    # value within the 'orig_values_dict' before resetting it to the plugin default.
    if g:llmchat_header_sep_size != default_llmchat_header_sep_size_value
        orig_values_dict["g:llmchat_header_sep_size"] = g:llmchat_header_sep_size
        g:llmchat_header_sep_size = default_llmchat_header_sep_size_value
    endif


    # Check to see if the 'g:llmchat_separator_bar_size' variable has been set to a non-default value and if so backup
    # its value within the 'orig_values_dict' before resetting it to the plugin default
    if g:llmchat_separator_bar_size != default_llmchat_separator_bar_size_value
        orig_values_dict["g:llmchat_separator_bar_size"] = g:llmchat_separator_bar_size
        g:llmchat_separator_bar_size = default_llmchat_separator_bar_size_value
    endif


    # Check to see if the 'g:llmchat_assistant_message_follow_style' variable has been set to a non-default value and if
    # so backup its value within the 'orig_values_dict' before resetting it to the plugin default.
    if g:llmchat_assistant_message_follow_style != default_llmchat_assistant_message_follow_style
        orig_values_dict["g:llmchat_assistant_message_follow_style"] = g:llmchat_assistant_message_follow_style
        g:llmchat_assistant_message_follow_style = default_llmchat_assistant_message_follow_style
    endif


    # Check to see if the 'g:llmchat_use_streaming_mode' variable has been set to a non-default value and if so backup
    # its value within the 'orig_values_dict' before resetting it to the plugin default.
    if g:llmchat_use_streaming_mode != default_llmchat_use_streaming_mode
        orig_values_dict["g:llmchat_use_streaming_mode"] = g:llmchat_use_streaming_mode
        g:llmchat_use_streaming_mode = default_llmchat_use_streaming_mode
    endif


    # Check to see if the 'g:llmchat_curl_extra_args' variable has been set to a non-default value and if so backup its
    # value within the 'orig_values_dict' before resetting it to the plugin default.
    if g:llmchat_curl_extra_args != default_llmchat_curl_extra_args
        orig_values_dict["g:llmchat_curl_extra_args"] = g:llmchat_curl_extra_args
        g:llmchat_curl_extra_args = default_llmchat_curl_extra_args
    endif


    # Return the 'orig_values_dict' back to the caller.
    return orig_values_dict

enddef


# This function will handle restoration of the value for any global variable recognized by this plugin whose value may
# have been "defaulted" by function ResetGlobalVars().  The dictionary provided to this function should be the same
# dictionary that was returned by function ResetGlobalVars() when the global variables were reset to their defaults and
# it is expected to contain a mapping of the original values that are to be restored.
#
# Arguments:
#   restore_dict - A dictionary that maps the name of each global variable that was changed to the original value it
#                  held (i.e., the value that this function should restore).
#
export def RestoreGlobalVars(restore_dict: dict<any>)
    # Check for the existence of a dictionary entry whose name matches to a global variable that "might" have been
    # reset to a plugin default value.  If such an entry is found than we will restore the value it holds to the
    # corresponding global variable.
    if has_key(restore_dict, "g:llmchat_default_server_type")
        g:llmchat_default_server_type = restore_dict["g:llmchat_default_server_type"]
    endif

    if has_key(restore_dict, "g:llmchat_default_server_url")
        g:llmchat_default_server_url = restore_dict["g:llmchat_default_server_url"]
    endif

    if has_key(restore_dict, "g:llmchat_default_model_id")
        g:llmchat_default_model_id = restore_dict["g:llmchat_default_model_id"]
    endif

    if has_key(restore_dict, "g:llmchat_default_system_prompt")
        g:llmchat_default_system_prompt = restore_dict["g:llmchat_default_system_prompt"]
    endif

    if has_key(restore_dict, "g:llmchat_apikey_file")
        g:llmchat_apikey_file = restore_dict["g:llmchat_apikey_file"]
    endif

    if has_key(restore_dict, "g:llmchat_open_new_chats_in_insert_mode")
        g:llmchat_open_new_chats_in_insert_mode = restore_dict["g:llmchat_open_new_chats_in_insert_mode"]
    endif

    if has_key(restore_dict, "g:llmchat_chat_split_type")
        g:llmchat_chat_split_type = restore_dict["g:llmchat_chat_split_type"]
    endif

    if has_key(restore_dict, "g:llmchat_header_sep_size")
        g:llmchat_header_sep_size = restore_dict["g:llmchat_header_sep_size"]
    endif

    if has_key(restore_dict, "g:llmchat_separator_bar_size")
        g:llmchat_separator_bar_size = restore_dict["g:llmchat_separator_bar_size"]
    endif

    if has_key(restore_dict, "g:llmchat_assistant_message_follow_style")
        g:llmchat_assistant_message_follow_style = restore_dict["g:llmchat_assistant_message_follow_style"]
    endif

    if has_key(restore_dict, "g:llmchat_use_streaming_mode")
        g:llmchat_use_streaming_mode = restore_dict["g:llmchat_use_streaming_mode"]
    endif

    if has_key(restore_dict, "g:llmchat_curl_extra_args")
        g:llmchat_curl_extra_args = restore_dict["g:llmchat_curl_extra_args"]
    endif

enddef


# This function will return a dictionary that links the name of each global variable recognized by this plugin to its
# expected default value (not that the defaults found within this dictionary are the same values that are specified by
# the constants at the top of this script file).
#
# Returns: A dictionary whose keys are the names of all global variables recognized by this plugin and whose values are
#          the expected defaults for each of those global variables.
#
export def GetGlobalVariableDefaults(): dict<any>
    # Create a dictionary that will hold a mapping between the name of each global variable recognized by this plugin
    # and its expected "default" value then return such dictionary back to the caller.
    return {
             "g:llmchat_default_server_type": default_llm_default_server_type_value,
             "g:llmchat_default_server_url": default_llmchat_default_server_url_value,
             "g:llmchat_default_model_id": default_llmchat_default_model_id_value,
             "g:llmchat_default_system_prompt": default_llmchat_default_system_prompt_value,
             "g:llmchat_apikey_file": default_llmchat_apikey_file_value,
             "g:llmchat_open_splits_in_insert_mode": default_llmchat_open_new_chats_in_insert_mode_value,
             "g:llmchat_chat_split_type": default_llmchat_chat_split_type_value,
             "g:llmchat_header_sep_size": default_llmchat_header_sep_size_value,
             "g:llmchat_separator_bar_size": default_llmchat_separator_bar_size_value,
             "g:llmchat_assistant_message_follow_style": default_llmchat_assistant_message_follow_style,
             "g:llmchat_use_streaming_mode": default_llmchat_use_streaming_mode,
             "g:llmchat_curl_extra_args": default_llmchat_curl_extra_args
           }

enddef


# This function will return the path to the test "data" directory on the current system appropriate for use by the test
# having the given name.  In general it is assumed that such directory contains additional asset files required by the
# invoking test which hold content such as input data, expected outputs, etc.
#
# Note that the functionality used to resolve this disk location resides within a convenience function for the following
# reasons:
#
#   1). To abstract away the details concerning the construction of a system path to reach the test's data directory
#       (this is not straightforward in Vim due to unclear means for resolving os-specific constructs such as the file
#       separation sequence to use within paths).
#
#   2). To centralize logic that is aware of the test data directory's filesystem layout and to abstract this away
#       from the tests themselves.
#
# Arguments:
#   test_name - The name of the test that is invoking this function (this should simply be the name of the test function
#               itself minus any scoping prefix).
#   append_trailing_sep - Whether or not to leave a trailing file separator at the end of the path.  This can be useful
#                         for the invoking test in order to avoid having to resolve what the file separation sequence
#                         is on the current system especially when using the return from this function to construct
#                         file paths.  A value of 'true' will cause the returned path to end with the file separation
#                         sequence and a a value of 'false' will omit such sequence (in this latter case the path
#                         will end with the directory name instead).
#
# Returns: The path to the data directory for the specified test within the local filesystem.
#
export def GetTestDataDir(test_name: string, append_trailing_sep: bool): string
    # Retrieve the path to the plugin home directory by assuming it is 3 levels up from the path of this script file on
    # the current system (i.e., if we remove the filename and then two additional directories from the path to this
    # script file than we will have the home directory where this plugin has been installed).  Since this logic is NOT
    # the test file being run by UT the execution of function expand() is not effected as it would be from within the
    # test file itself (e.g., the fact that the "test file" seems to be read and then written to a temporary script by
    # UT results in expand("<script>") returning the path to THAT temporary file instead of the real test script).
    var script_path = expand("<script>:h:h:h")


    # Determine what type of file separator that the current operating system uses so that we can build out the rest of
    # the path to the data directory.  Based on a lot of searching around (and the information in 'help feature-list')
    # it seems that (1) there is NOT a straightforward way to get this (for instance no File.separator equivalent if
    # comparing against Java) and (2) maybe the best way to determine which separator to use is the existance of the
    # '+shellslash' feature.  For now we will assume that if '+shellslash' exists than Vim is allowing '\' characters in
    # file paths and therefore it is likely we are on some flavor of Windows; otherwise we assume that we're on a *nix
    # system or Mac.
    var path_sep = '/'   # Assume a forward slash by default.
    if exists('+shellslash')
        path_sep = "\\"
    endif


    # Now assume that the "data" directory for the specified test will be found at the following relative path BELOW
    # the plugin root folder:  test/data/<TEST_NAME> (where <TEST_NAME> is assumed to have been provided as argument
    # 'test_name' to this function).  Construct the path, making sure to leave a trailing file separator at its end if
    # requested, and return this back to the user.
    return script_path .. path_sep .. "test" .. path_sep .. "data" .. path_sep .. test_name ..
           (append_trailing_sep ? path_sep : '')
enddef

