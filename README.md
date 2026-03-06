# claude-in-container

Runs Claude Code in a container, persisting your credentials, preferences, and session information in a volume, separate from your home directory on the host system.

## System requirements

- Docker
- A valid Claude subscription

## Installation

1. Clone this repository in your home directory
2. Choose a directory you have in your `PATH`, such as `~/bin`
3. Run `ln -s $HOME/claude-in-container/claude-in-container ~/bin` or whichever directory you chose

## Run

Just run the command `claude-in-container` the way you would usually run `claude`, with the usual flags.
