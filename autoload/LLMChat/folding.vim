" This file contains the logic needed to implement a custom folding method specifically for chat log files.


" ================================
" ====                        ====
" ====  Function Definitions  ====
" ====                        ====
" ================================

" This function provides the basis for a custom folding method appropriate to chat log files.  In its current
" implementation the function will create folds according to the following rules:
"
"   1). The first line of all comment blocks (i.e., sequences of 2 or more consecutive comment lines) can be rolled
"       up into a single fold.
"
"   2). All message exchanges (i.e., pairings of user messages and their assistant responses) can be rolled up into
"       a single fold.
"
"   3). Within any message exchange the assistant message can be rolled up into its own fold as well (so a second
"       level fold within the message exhange fold).
"
" On invocation the operation of this function will attempt to determine what "fold level" to assign the line whose
" number has been provided as argument "line_num".  The function will then return a resolved "fold level" for the line
" that adheres to the level types as specified in help section 'fold-expr'.
"
" In order to use this function for folding the following must be set in Vim for a buffer containing a chat log file:
"
"   setlocal foldmethod=expr
"   setlocal foldexpr=LLMChatFolding(v:lnum)
"
" Additional Notes:
"
"   (1) User and assistant messages (whose content is largely unrestricted) present special syntactic challenges that
"       are best approached with formal parsing logic.  Unfortunately using a formal parser for the folding method
"       implementation in Vim is challenging because the function called will be invoked per line number and this would,
"       by default, cause the document to be re-parsed N times over (where N is the number of lines in the document).
"       Conversely, trying to approach the fold computation from a single line view (and trying to perform as little
"       parsing as possible to keep down the computation overhead) results in a number of ambiguous cases because no
"       parsing state for the line is available.
"
"       To address these challenges this implementation has been setup to (1) perform minimal parsing per invocation
"       and (2) to cache information related to line parsing state into a buffer local variable for reference on
"       future function calls.  This approach allows any invocation of the function to re-use parsing work done on a
"       previous line in order to infer parsing context and to address ambiguous conditions that would otherwise be
"       encountered.
"
"       Unfortunately this approach is not perfect as it is subject to the "stale data" problem.  Essentially once a
"       buffer has been processed for its initial folding information than that data will remain cached within a buffer
"       local list.  This list can then become "stale" with respect to buffer state as editing of the chat document
"       proceeds.  The algorithm in use can account for *some* of this staleness so long as changes to folding levels
"       are requested in document order.  This is possible because ambiguous conditions are currently resolved by
"       looking to the parsing state for earlier lines; as long as the folding level for those lines was requested
"       BEFORE later lines in the document than the state of the buffer local list will be properly upated
"       "just-in-time".  If the folding changes for lines is requested out of document order than this will not happen
"       and stale state will get used resulting in incorrect folding level returns.
"
"       We can't control the line order in which Vim requests folding values, nor has a guaranteed order been been found
"       in the documentation, so we can't 100% ensure that things will happen as we need them too.  All this has been
"       documented for the case that things DON'T go as expected at some point in the future so that revisions to the
"       current algorithm can be considered.
"
" Arguments:
"   line_num - The line number that this function should determine the fold level for.
"
" Returns: A string value representing the "fold level" for the line as per the accepted fold levels documented in
"          help section 'fold-expr'.
"
function LLMChat#folding#GetFoldLevel(line_num)
    " Check to see if a buffer-level variable having name 'fold_level_list' already exists; if not than create the
    " variable and intialize it to hold an empty list.  This variable will be used to track fold level assignments
    " per line so that the levels of earlier lines in the document don't need to be recomputed, they can simply be
    " looked up within the list, when needed later.
    if !exists("b:fold_level_list")
        let b:fold_level_list = [ ]
    endif

    " Make sure that the 'b:fold_level_list' contains at least a number of elements that is equal to 1 less than the
    " 'line_num' argument given; if not than we will call out to a utility function to process and back fill the list
    " before proceeding.  The fold levels of earlier lines must always be known otherwise the logic that follows will
    " not be able to run properly.
    let l:min_list_length = a:line_num - 1
    if len(b:fold_level_list) < l:min_list_length
        call LLMChat#folding#BackfillLevelList(l:min_list_length)
    endif

    " Fetch the text from the 'line_num' given and store this into a local variable for later analysis.
    let l:line_text = getline(a:line_num)

    " Create a variable to hold the fold level that we will return and assign '=' to it by default (this means to
    " use the fold level of the line that came before the current line).
    let l:fold_level = '='

    " Create a variable that will hold any "special" flags that need to be preserved by the processing.  Such flags are
    " typically introduced to notate conditions requiring special handling or to resolve ambiguous cases.  Flags set
    " into this variable can be any of the following values:
    "
    "   '+' - This indicates that the resolved fold level opened a level 1 comment block fold.  Such flag is used
    "         to let the processing distinguish between a "comment fold" and the opening fold for another syntactic
    "         structure such as a message exchange (which is also at level 1).  Without making this distinction later
    "         processing trying to handle comment block folds cannot tell directly whether it is or is not appropriate
    "         to close out a fold as such closing *could* close the wrong fold in certain conditions (consider the case
    "         where the comment block is inside a user message and therefore isn't truly a comment block at all but
    "         rather part of the message content).
    "
    " By default the special flag is empty which indicates no special condition is present.
    let l:special_flag = ''

    " Check to see if the 'line_num' given was 1 and if so handle this specially.  Other line numbers may need to
    " refer back to previous line assignments (as found in the 'b:fold_level_list' variable) but the assignment for
    " the first line can't do this as we assume it will be evaluated before any other line in the document.
    if a:line_num == 1
        " Since this is the first line in the document our main concern is whether or not such line starts with a
        " '#' character.  If so than we assume the document starts with a comment and we'll need to do more work to
        " see if such comment is sufficiently large to create a fold for.  If the line does NOT start with a '#'
        " character than we will assume that the line is not part of any fold and will set the 'l:fold_level' to 0.
        if l:line_text =~# '\v^\s*\#.*$'
            " In this case we assume we've got a comment line.  Check to see if the next line is ALSO a comment line
            " and if so we will start a fold.  If the next line does NOT start with a '#' character than we will
            " assume the line to NOT be a comment and we will return 0 for the current line as a single comment
            " line should not make up a fold.
            let l:next_line_text = getline(a:line_num + 1)
            if l:next_line_text =~# '\v^\s*\#.*$'
                let l:fold_level = ">1"

                " Make sure to set the 'l:special_flag' variable to a '+' symbol in order to note that the fold
                " we will be opening is for a comment block and NOT a level 1 fold for a different syntax structure.
                let l:special_flag = '+'
            else
                let l:fold_level = "0"
            endif

        else
            let l:fold_level = "0"
        endif

    else
        " If the logic comes here than we are assessing the fold level for a line that is NOT the first line in the
        " document.  Begin this process by checking the current line against expressions that would indicate the
        " opening of a new fold.
        "
        " Notes:
        "   (1) When setting up folds we want to meet the following goals:
        "
        "       A). First level folds should roll up comments longer than one line in length as well as chat
        "           exchanges (i.e., pairings of user/assistant messages).
        "
        "       B). Second level folds should roll up assistant messages only.
        "
        "   (2) For chat messages we want to expose the first line of the actual message text in the fold rollup so
        "       that there is some reference as to what the message was.  This can be a bit tricky since users can
        "       format their chats according to their own preference and may even change the chat log content to be
        "       contradictory to some global settings like 'g:llmchat_assistant_message_follow_style'.
        "
        "       To approach this objective we will therefore check for text that follows the opening message delimiter
        "       (for both user and assistant messages) and, if found, we will set the line we found this in as the
        "       start of the fold.  If we don't see any characters (other than whitespace) follow the delimiter than we
        "       will set the next line down as the start of the fold.
        "
        "       Note that this scheme isn't perfect and some users could include multiple lines of whitespace between
        "       the opening delimiter and the start of their actual message.  For now we're not worried about this
        "       case as we expect most users to either start their message immediately after the delimiter or on the
        "       line under it.
        "
        if l:line_text =~ '\v^\>\>\>\s*\S+(.)*'
            " In this case we found the opening delimiter for a user message AND such delimiter was followed by at least
            " one non-whitespace character.  Assume that this should be the start of a fold and update the value held by
            " variable 'l:fold_level' accordingly.
            let l:fold_level = ">1"

        elseif l:line_text =~ '\v^\=\>\>\s*\S+(.)*'
            " In this case we found the opening delimiter for an assistant message AND such delmiter was followed by at
            " least one non-whitespace character.  Assume that this should be the start of a fold and update the value
            " held by variable 'l:fold_level' accordingly.
            let l:fold_level = ">2"

        elseif getline(a:line_num - 1) =~ '\v^\>\>\>\s*$'
            " In this case we found a line that was immediately preceeded by a line containing ONLY the opening
            " delimiter for a user message (and possibly some trailing whitespace); for such a case assume that the
            " current line should open a fold and update variable 'l:fold_level' accordingly.
            let l:fold_level = ">1"

        elseif getline(a:line_num -1) =~ '\v^\=\>\>\s*$'
            " In this case we found a line that was immediately preceeded by a line containing ONLY the opening
            " delimiter for an assistant message (and possibly some trailing whitespace); for such a case assume that
            " the current line should open a fold and update variable 'l:fold_level' accordingly.
            let l:fold_level = ">2"

        elseif getline(a:line_num + 1) =~ '\v^\<\<\=(.)*'
            " In this case we encountered a line whose next line closes out an assistant message; go ahead and close out
            " the second level fold (i.e., the fold containing only the assistant message) as the next line will need
            " to close out the first level fold containing the full message exchange.
            let l:fold_level = "<2"

        elseif l:line_text =~ '\v^\<\<\=\s*'
            " We have found a line that contains the assistant message closing delimiter so close out the first level
            " fold that encompasses the full message exchange.
            let l:fold_level = "<1"

        elseif l:line_text =~ '\v\s*\#(.)*'
            " If the logic comes here than we've found a comment line.  To properly process comments we need to
            " determine a few things like:
            "
            "   * Is this just a single comment line or part of a block?
            "   * If part of a block is this comment line the start?  the end?  somewhere in the middle?
            "
            " Thankfully all of these questions can be asked fairly simply inside some if conditions provided we know
            " the following:
            "
            "   1). Does the current comment line have a previous comment line above it?
            "   2). Does the current comment line have another comment line below it?
            "
            " Create some variables that will store the answers to these questions as Vimscript booleans before
            " proceeding further (where Vimscript uses 0 to mean 'false' and anything else to mean 'true')
            let l:prior_line = a:line_num - 1
            let l:next_line = a:line_num + 1

            let l:has_above_comment = getline(l:prior_line) =~ '\v\s*\#(.)*' ? 1 : 0
            let l:has_below_comment = getline(l:next_line) =~ '\v\s*\#(.)*' ? 1 : 0

            " Check to see if any of the following cases apply:
            "
            "   1). The line preceeding the current line was NOT a comment but the line following it was; in this case
            "       we've found the start of a comment block.
            "
            "   2). The line preceeding the current line was a comment but the line following it was NOT; in this case
            "       we've found the end of a comment block.
            "
            if ! l:has_above_comment && l:has_below_comment
                " If the logic comes here than we've confirmed that the current line is the start of a comment block.
                " We now need to make sure that that the proceeding line was NOT already part of a fold and to do this
                " we will rely on the information held by buffer variable 'b:fold_level_list'.  If the element
                " corresponding to the preceeding line shows a fold level of either "0" or "<1" than we will assume that
                " the current line should open a fold.
                "
                " When would this ever be part of a fold already?  The answer is that just because we recognize comments
                " as lines starting with a '#' does not mean that every line starting with a '#' is a comment; it
                " depends on where the line is in relation to the other syntactic structures in the document.  As an
                " example, an LLM may return markdown formatted responses which will appear within an assistant message
                " and (1) we will NOT recognized this to be a comment but (2) such lines will start with a '#'
                " character.  Note that in these cases the line will *also* be found within fold and this is why we make
                " such check before assuming the line is actually a comment block start that should begin its own fold.
                "
                " NOTE: To get the proper index value for the "prior line" we must subtract 2 from 'line_num'.  To
                "       see this consider that we subtract 1 from 'line_num' to get the number of the prior line and
                "       then since line numbers are 1-based (but list indexes are 0-based) we have to subtract one more
                "       to get the index value for the prior line in 'b:fold_level_list'.
                let l:prior_fold_level = b:fold_level_list[a:line_num - 2]
                if l:prior_fold_level == '0' || l:prior_fold_level == '<1'
                    let l:fold_level = ">1"

                    " Make sure to set the 'l:special_flag' variable to a '+' symbol in order to note that the fold
                    " we will be opening is for a comment block and NOT a level 1 fold for a different syntax structure.
                    let l:special_flag = '+'
                endif

            elseif l:has_above_comment && ! l:has_below_comment
                " If the logic comes here than we've determined that the current line is the ending for a comment block.
                " We now need to make sure that the comment block which is ending was actually part of a comment fold
                " itself.  Consider that it is always possible that the user has put lines into their message which
                " start with a '#' (making them *seem* to be comment lines from the logic here but which are really part
                " of the user message) and we do not want to end the user message fold if we encounter such a case.
                " Since user messages will also be at fold level 1 we, by default, have an ambiguous situation here.
                " Thankfully the logic already resolves this case by using a "special flag" for comment folds that is
                " appended to the fold level when such level is stored into the 'b:fold_level_list'.  The special flag
                " for comment blocks is the '+' character and this will be suffixed to any fold level of "1" or ">1"
                " that correspond to a comment block fold.  Hence, we will lookup the fold level stored by the previous
                " line in the 'b:fold_level_list' and if we see one of these special levels we will close out the
                " comment block fold.
                "
                " NOTE: To get the proper index value for the "prior line" we must subtract 2 from 'line_num'.  To
                "       see this consider that we subtract 1 from 'line_num' to get the number of the prior line and
                "       then since line numbers are 1-based (but list indexes are 0-based) we have to subtract one more
                "       to get the index value for the prior line in 'b:fold_level_list'.
                let l:prior_fold_level = b:fold_level_list[a:line_num - 2]
                if l:prior_fold_level == '1+' || l:prior_fold_level == '>1+'
                    let l:fold_level = '<1'

                    " NOTE: It is NOT necessary to set the special flag in this case as the comment fold is complete
                    "       and further lines below the current line that are processed from the document will not be
                    "       part of such fold.
                endif

            endif

        endif

    endif


    " Optimization - In the documentation for folding (":help fold-expr") it mentions that values like '=', "aX", and
    "                "sX" are non-optimal to return since they require Vim to do more work figuring out what the
    " fold level was for surrounding lines.  Theoretically we already know this information as we are caching resolved
    " fold levels into buffer variable 'b:fold_level_list' so we will try to use this information to find a better
    " value to return to Vim.
    if l:fold_level == '='
        " NOTE: Since we want to retrieve the "prior" line AND indices are already one less than the line number we
        "       need to subtract 2 from the 'line_num' to get the proper index (think if it as subtracting 1 to get the
        "       prior line number then subtracting one more to convert that line number to the proper index value).
        let l:prior_line_level = b:fold_level_list[a:line_num - 2]
        if l:prior_line_level == '1' || l:prior_line_level == '>1' || l:prior_line_level == '<2'
            " If the logic comes here than the previous line was either (1) in a fold at level 1, (2) opening a fold at
            " level 1, or (3) closing out a fold at level 2 (which would mean we should return back to level 1 on the
            " current line).
            let l:fold_level = '1'

        elseif l:prior_line_level == '1+' || l:prior_line_level == '>1+'
            " If the logic comes here than the previous line was either (1) in a *comment* fold at level 1 or (2)
            " opening a *comment* fold at level 1.  The fold level we want to return is still 1 in this case but we
            " need to set the 'l:special_flag' to '+' as well so that the logic notates the line is within a folded
            " comment block.  For more information on the 'l:special_flag' variable see its initial declaration earlier
            " in this function.
            let l:fold_level = '1'
            let l:special_flag = '+'

        elseif l:prior_line_level == '2' || l:prior_line_level == '>2'
            " If the logic comes here than the previous line was either (1) in a fold at level 2 or (2) was opening a
            " fold at level 2.
            let l:fold_level = '2'

        else
            " In this case we don't have the conditions satisifed for a level 1 or level 2 fold so the only option
            " remaining is no fold at all (level 0).
            let l:fold_level = '0'

        endif

    endif


    " Now we need to cache the resolved 'fold_level' value into the 'b:fold_level_list' so it can be looked up and
    " potentially referenced by future calls to this function.  To do this we need to check the current size of
    " 'b:fold_level_list' so we know if the value needs to be (1) inserted (as will be the case for the first time
    " this function is called for a specific line number on the current buffer) or (2) updated (as will be the case
    " if this function has been called previously for the line number and is now being called again due to buffer
    " changes).
    "
    " NOTE: When saving the resolved fold level we also need to store any special flag that was set by the processing
    "       into variable 'l:special_flag'.  To do this we will, by convention, just append the special flag to the
    "       end of the fold level before adding it into the 'b:fold_level_list'.
    "
    let l:actual_list_size = len(b:fold_level_list)
    if l:actual_list_size < a:line_num
        " In this case the list does not have an element assigned that would correspond to the current line number
        " so we need to append a new element that contains the resolved fold level.  Note that at the start of this
        " function we already ensured that 'b:fold_level_list' contained at least (line_num - 1) number of elements
        " so we can safely assume that simply adding one more element to the end of the list is the right action to
        " take.
        call add(b:fold_level_list, l:fold_level .. l:special_flag)
    else
        " In this case the list already has an element which corresponds to the current line number so we will update
        " that element with the resolved fold level.  Remember that since line numbers are 1-based values but list
        " indices are 0-based we must subtract one from the line number to get the list element index.
        let b:fold_level_list[a:line_num - 1] = l:fold_level .. l:special_flag
    endif


    " Return the resolved fold level back to the caller.  Note that this should NEVER contain any special flag data
    " as such information is used only witin this function to resolve ambiguous cases.
    return l:fold_level

endfunction


" This is a utility function for handling iterative invocations of the GetFoldLevel() function.  The issue at hand is
" that GetFoldLevel() requires that for some line number 'N' within a buffer the parse state for all lines from 1 to
" N-1 be known and stored in a list associated with the buffer (storing the folding level and parsing information for
" a particular line within this list is a side effect of the operation for function GetFoldLevel()).  If Vim invokes
" such function out of document line order than we need to pro-actively "backfill" the parsing state information for
" lines that have not yet been processed by calling the function for those lines.  Again, since update of the buffer
" local list that holds parsing state is a side effect of a call to GetFoldLevel() we don't need to proceess or retain
" a returned value; we only need to make sure that the function was call for each previous line that was NOT already
" processed.
"
" One option to approaching this requirement is simply to have function GetFoldLevel() recursively call itself to
" process prior lines.  Unfortunately this has the potential for generating a very large call stack, especially if we
" have very large documents and Vim tries to get the folding state for some line near the end first.  No information
" could be found regarding any guarantees of call ordering so we must generally assume that this condition is possible
" any might overwhelm the stack available to the script.  To avoid creating large call stacks we can instead iteratively
" invoke the function which is ultimately the point of this function.
"
" Arguments:
"   min_list_length - The minimum length of the parsing state list that must be present before the GetFoldLevel()
"                     invocation that invoked this function an proceed.  Note that since the elements in this list
"                     are matched to line numbers this argument infers the set of lines that must be pre-processed for
"                     the appropriate backfilling to take place.
"
function LLMChat#folding#BackfillLevelList(min_list_length)
    " Find the current size of the 'b:fold_level_list' and store this into a local variable.
    let l:curr_level_list_size = len(b:fold_level_list)

    " Now we want to invoke the GetFoldLevel() function for each line corresponding to a missing index in the list
    " up to and including the 'min_list_length' value provided.  Note that since lines are 1-based numbers but indices
    " are 0-based we must add one to each index value in order to get the corresponding line number.
    let l:curr_missing_index = l:curr_level_list_size
    while l:curr_missing_index < a:min_list_length
        " Call the GetFoldLevel() function to implicitly backfill the missing index in the 'b:fold_level_list' variable
        " (note that we have no use for the fold level returned so we will simply ignore it).
        "
        " NOTE: The argument passed to function GetFoldLevel() is the line number (and is 1-based) but we are looping
        "       over missing list indices (which are 0-based).  To provided the correct argument we therefore need to
        "       add one to the value of 'l:curr_missing_index' when invoking the function.
        "
        call LLMChat#folding#GetFoldLevel(l:curr_missing_index + 1)

        " Increment the 'l:curr_missing_index' variable by 1 before the next loop iteration.
        let l:curr_missing_index = l:curr_missing_index + 1
    endwhile

endfunction

