Autovault
=========

This is a simple utility script that can be used for the `VAULTED_ASKPASS` environment variable accepted by [Vaulted](https://github.com/miquella/vaulted).

## Dependencies

There are a few things needed for this to work:
  * A 1password account (obviously)
  * [1password-cli](https://support.1password.com/command-line-getting-started/)
  * [1pass](https://github.com/dcreemer/1pass)
  * [vaulted](https://github.com/miquella/vaulted)

## Usage

To use this script, just clone the repository and then alias the script to somewhere in your path:

```sh
[[ ! -d ${HOME}/.local/bin ]] && mkdir -p ${HOME}/.local/bin
ln -sfn ~/src/autovault/autovault.zsh ~/.local/bin/autovault
```
