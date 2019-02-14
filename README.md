Autovault
=========

This is a relatively simple utility script that can be used for the `VAULTED_ASKPASS` environment variable accepted by [Vaulted](https://github.com/miquella/vaulted). The script is written as a ZSH script so you will need to at a minimum have ZSH installed on your system to use it (though the shell it's called from shouldn't matter much).

_NOTE:_ Currently this only works with 1password accounts (though I have some ideas for making it more backend-agnostic).

## Dependencies

There are a few things needed for this to work:
  * ZSH installed (on most systems this is already the case)
  * A 1password account (obviously)
  * [1password-cli](https://support.1password.com/command-line-getting-started/)
  * [1pass](https://github.com/dcreemer/1pass) (make sure you follow the instructions to set this up correctly)
  * [vaulted](https://github.com/miquella/vaulted)

## Usage

To use this script, just clone the repository and then (optionally) alias the script to somewhere in your path:

```sh
[[ ! -d ${HOME}/.local/bin ]] && mkdir -p ${HOME}/.local/bin
ln -s ~/src/autovault/autovault.zsh ~/.local/bin/autovault
```

In your shell rc file (`~/.zshrc`, `~/.bashrc`, etc.) you'll want to make sure you invoke it with the `env` command to get the `VAULTED_ASKPASS` var loaded into your environment:

```sh
eval "$(autovault env)"
```
