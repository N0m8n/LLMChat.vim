# LLMChat.vim
A Vim plugin for chatting with LLMs hosted by Ollama and Open-WebUI servers.

<img width="1031" height="735" alt="LLMChat_Example" src="https://github.com/user-attachments/assets/691387c7-5a60-4044-8173-1e5d7ac8f0e6" />

## Description
This is a Vim plugin for supporting chats with LLMs (Large Language Models) that are being hosted on either Ollama ( https://ollama.com/ ) or
through Open WebUI ( https://docs.openwebui.com/ ) servers.  Its goal is to provide an interface directly in Vim through which one or more
ongoing dialogs can be used for discussion or collaboration.

## Features
Currently the plugin supports all of the following features:
  - Management of multiple separate chats
  - Chat metadata and history is stored and worked with as a regular document in Vim so can be managed just as any other text file.
  - Supports chat interactions with LLMs hosted via Ollama or through Open WebUI.
  - Has syntax highlighting for chat logs
  - Makes use of the asynchronous job framework in Vim for chat submissions so that the editor is usable while waiting on a response.
  - Supports the use of authentication for interacting with LLMs on secured servers.
  - Only depends on the availability of `curl` locally (see the "Requirements" section below) and is otherwise written in pure vimscript (no additional requirements on language bindings, no need for specially compiled Vim binaries, etc)

## Requirements
This plugin requires that [cURL](https://github.com/curl/curl) be installed to, and can be located via the PATH on,
the system where the plugin will be used.  If not already available, this utility can be added to Linux systems via
the package manager (for example `apt-get install curl` on Debian/Ubuntu) or via standalone executable for Windows.

## Installation
* Note that this plugin requires the use of Vim 9.x or later as it makes use of vim9script for plugin modularity.  Unfortunately, also because it uses vim9script, this plugin is currently incompatible with neovim.

If you use [Vundle](https://github.com/gmarik/vundle) for your plugin management you can add the following line to your `~/.vimrc` file
to install this plugin:
```
Plugin 'N0m8n/LLMChat.vim'
```
For [Pathogen](https://github.com/tpope/vim-pathogen) users the following lines of code will handle installation:
```
cd ~/.vim/bundle
git clone https://github.com/N0m8n/LLMChat.vim.git
```

## License
This plugin is provided for general use under the terms of the GNU Public License v3.


## RoadMap
There are plans for supporting the following features as this plugin evolves:
  - Command for retrieving a list of available models on the remote LLM server.
  - Support for managing and using files with LLM interactions through Open WebUI.
  - Support for managing and using knowledge collections with LLM interactions in Open WebUI.

## Known Issues
The following issues are known to exist in the plugin and have yet to be resolved:
