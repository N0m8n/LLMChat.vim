
##########################
####                  ####
####  Testing README  ####
####                  ####
##########################

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

