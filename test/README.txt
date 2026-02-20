
##########################
####                  ####
####  Testing README  ####
####                  ####
##########################


  -[ General ]-

Tests created for this plugin depend on the "vim-UT" plugin from https://github.com/LucHermitte/vim-UT.  In order to run
a test after such dependency plugin has been installed in Vim you can do:

:UTRun <TEST_FILE>

Main test files for this plugin all begin with "LLMChat_" and are found in the same directory as this readme file.

Notes:
  (1) It is generally beneficial to manipulate the 'runtimepath' setting for Vim yourself so that you load a working
      copy of this plugin from a development location rather than from Vim's settings directory.  To do this you
      need to add a '--cmd' option to your VIM location like the following:

        vim --cmd "set runtimepath^=<PLUGIN_DEV_PATH>" <FILES>

      Note that the '^=' operation appends the plugin path to the existing runtimepath value rather than overwriting it.
      For the case that your shell path is within the development directory for this plugin you can do the following:

        vim --cmd "set runtimepath^=$(pwd)"

  (2) Remember that Vim only loads source files once so if you fix a bug in the code you MUST RESTART VIM before
      trying to test the code again.  Without doing this Vim won't see the change and the test logic that is failing
      will continue to fail.



  -[ The 'g:llmchat_test_bypass_mode' Variable ]-

Breaking up logical code paths for proper testing in Vim has been a challenge and to help address this a special
variable called 'g:llmchat_test_bypass_mode' was created.  This variable will cause execution path changes to take
place inside the main plugin code when set that will work toward the following objectives:

  1). Bypass the execution of system commands or logic that would submit jobs into the asynchronous execution framework
      in Vim.

  2). Break execution paths so that function calls return rather than proceeding down the call stack.

Conventions around the use of this variable are as follows:

  1). Logic making decisions about the execution path to run should simply base such decisions on the existence of this
      variable and NOT the value that it has been set to.

  2). Any value given for the 'g:llmchat_test_bypass_mode' variable by a test is reserved for the code path to be
      verified.  This means that values may be ignored or may be expected to be different things for separate logical
      paths in the plugin.  Isn't this messy?  In practice it really isn't as we can document within the code path what
      the expectations are as well as in the test that sets the variable.  Leaving the value largely undefined in this
      way gives us the flexibility to use this single variable not only for forcing breaks in execution but also for
      returning information to a test for verification while not constraining what that return can be.  It also lets us
      avoid the need to declare multiple global variables just for testing as including this into the main logic already
      feels dirty.

  3). When a test simply wants to introduce indirection, and the code path contains no logic intended to read or
      manipulate the value of varible 'g:llmchat_test_bypass_mode', than it should simply be set to the value 1 as a
      convention (this is read as a logical 'true' in Vim).


