# claude-in-container

Runs Claude Code in a container, persisting your credentials, preferences, and session information in a volume, separate from your home directory on the host system.

## System requirements

- Docker
- A valid Claude subscription

## Install

1. Clone this repository in your home directory
2. Choose a directory you have in your `PATH`, such as `~/bin`
3. Run `ln -s $HOME/claude-in-container/claude-in-container ~/bin` or whichever directory you chose

## Adapt to your needs

Edit the [Dockerfile](./Dockerfile) and add the Debian packages or whatever tools you need in your image.

## Run

Just run the command `claude-in-container` the way you would usually run `claude`, with the usual flags.

## License

This repository is released under the [MIT License](LICENSE). You are free to fork, modify, and redistribute it for any purpose.

Note that Claude Code itself is proprietary software owned by Anthropic. Use of Claude Code is governed by the [Anthropic Usage Policy](https://www.anthropic.com/legal/aup) and requires a valid Claude subscription. This license covers only the Dockerfile and shell script in this repository.
