# LLMChat.vim
A Vim plugin for chatting with LLMs hosted by Ollama and Open-WebUI servers.

<img width="1031" height="735" alt="LLMChat_Example" src="https://github.com/user-attachments/assets/691387c7-5a60-4044-8173-1e5d7ac8f0e6" />

## Description
This is a Vim plugin for supporting chats with LLMs (Large Language Models) that are being hosted on either Ollama
( https://ollama.com/ ) or through Open WebUI ( https://docs.openwebui.com/ ) servers.  Its goal is to provide an
interface directly in Vim through which one or more ongoing dialogs can be used for discussion or collaboration.

## Features
Currently the plugin supports all of the following features:
  - Management of multiple separate chats
  - Chat metadata and history is stored and worked with as a regular document in Vim so can be managed just as any
    other text file.
  - Supports chat interactions with LLMs hosted via Ollama or through Open WebUI.
  - Has syntax highlighting for chat logs
  - Makes use of the asynchronous job framework in Vim for chat submissions so that the editor is usable while waiting
    on a response.
  - Supports the use of authentication for interacting with LLMs on secured servers.
  - Only depends on the availability of `curl` locally (see the "Requirements" section below) and is otherwise written
    in pure vimscript (no additional requirements on language bindings, no need for specially compiled Vim binaries,
    etc)

## Requirements
This plugin requires that [cURL](https://github.com/curl/curl) be installed to, and can be located via the PATH on,
the system where the plugin will be used.  If not already available, this utility can be added to Linux systems via
the package manager (for example `apt-get install curl` on Debian/Ubuntu) or via standalone executable for Windows.

## Installation
* Note that this plugin requires the use of Vim 9.x or later as it makes use of vim9script for plugin modularity.
  Unfortunately, also because it uses vim9script, this plugin is currently incompatible with neovim.

If you use [Vundle](https://github.com/gmarik/vundle) for your plugin management you can add the following line to your
`~/.vimrc` file to install this plugin:
```
Plugin 'N0m8n/LLMChat.vim'
```
For [Pathogen](https://github.com/tpope/vim-pathogen) users the following lines of code will handle installation:
```
cd ~/.vim/bundle
git clone https://github.com/N0m8n/LLMChat.vim.git
```

## Usage
To use this plugin after installation simply type the command `:NewChat` in order to initialize a new chat log document.
Inside this document you will see that there is a "header" section at the top and a "body" section at the bottom;
these two document segments are separated from each other by an `* ENDSETUP *` delimiter line.  The header section
holds a series of "Name: Value" style options that define behaviors for the chat execution; you *MUST* at minimum
provide values for the 'Server Type', 'Server URL', and 'Model ID' options seen here.  A short description of each
of these is provided below:

  - **Server Type** - The type of LLM server the plugin will be contacting; this must be set to either "Ollama" or
                      "Open WebUI".
  - **Server URL** - The "base" URL to reach the server at.  In general this will just contain the server host or IP and
                     any necessary port number (for example "http://localhost:11434" for a locally running Ollama
                     server).  For more advanced use cases just be aware that this URL should be sufficient for the
                     plugin logic to invoke the API methods provided by the server type given by simply appending the
                     path to the API onto the supplied URL.
 - **Model ID** - This is the fully qualified name of the LLM model you would like to use.  Note that the name given
                  must be recognizable to the remote server and must belong to an LLM model that is available for use.

Once the header section of the chat document has been properly setup than you can type the message you would like to
send to the LLM after the '>>>' sequence found at the bottom of the document.  The message can either immediately follow
this opening sequence on the same line or it may begin on the line after the sequence; both are considered valid and
any leading whitespace will be trimmed off when the message is processed for sending.  Once your message is complete
you may, optionally, add the closing '<<<' sequence for user messages or allow the document end to close the message
(note that if you don't add this sequence it will be added automatically when a response is posted; only the last
message in the document is permitted to use the end of document to denote the message close).

After a message has been added it can be sent to the remote LLM by executing the `:SendChat` command.  This will cause
an asynchronous job to run that behind the scenes executes a curl call and eventually updates the chat log document with
the LLM response.  Note that the plugin is designed to leave the chat log document at the top of the LLM response so you
don't need to backup to read it but this also means that you won't see a dramatic shift in the document when the
response is posted.

Further messages may be sent by opening up a new user message with '>>>' and typing a message just as before.  Note that
the plugin requires user messages and LLM responses to be interleaved so it is invalid to place two user messages
back-to-back or to have two LLM messages back-to-back; each user message should have a received response before the
next message is added and sent.

Chat logs should be saved with the file extension ".chtlg" so that Vim features like syntax highlighting, custom
folding, etc, are enabled when the file is loaded.  More than one chat log can be created as well by simply using the
`:NewChat` command and saving each log off as a separate file.  This makes it easy to manage multiple concurrently
running chats that have different histories on different topics.  Just be aware that when submitting chats with the
`:SendChat` command ***only one pending chat at a time is permitted***.  This means that after you send a chat to the
LLM you need to wait for a response before sending another.

For full help information on this plugin beyond this simple quick start discussion see `:help LLMChat` inside of Vim
itself.


## License
This plugin is provided for general use under the terms of the GNU Public License v3.


## RoadMap
There are plans for supporting the following features as this plugin evolves:
  - Support for limiting the chat history submitted to the remote LLM (currently all chat history is used).
  - Command for retrieving a list of available models on the remote LLM server.
  - Support for managing and using files with LLM interactions through Open WebUI.
  - Support for managing and using knowledge collections with LLM interactions in Open WebUI.

## Known Issues
The following issues are known to exist in the plugin and have yet to be resolved:
  - If you begin typing messages immediately after the opening '>>>' sequence, and allow Vim to line wrap your text,
    than the next line will incorrectly be started with a '>>>'.  You must then remove this opening sequence to continue
    typing your message (note that starting messages on the line after the '>>>' works around this problem).  It is
    unclear exactly what causes this and the issue remains under investigation.

