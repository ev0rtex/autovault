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

# Advanced Usage

In my own shell I have added a few things to make thing work more smoothly. Notably I try to do a simple sanity check and make sure that the `gpg-agent` is loaded because `1pass` will need to work with your encrypted `1password` data:

```sh
#
# Check to ensure the 'op' session that 1pass saves can be decrypted by the GPG agent
#    - This ensures that the GPG agent loads the key _before_ 'vaulted' gets called and usurps STDIO
check_session() {
    local op_dir="${HOME}/.1pass"
    if [[ ! -d "${op_dir}" ]]; then
        echo "ERROR: 1pass doesn't appear to be installed"
        return 1
    fi
    if [[ -f "${op_dir}/config" ]] && [[ -f "${op_dir}/cache/_session.gpg" ]]; then
        gpg -qdr ${$(grep self_key ${op_dir}/config)##*=} ${op_dir}/cache/_session.gpg > /dev/null
    else
        echo "ERROR: 1pass doesn't appear to be configured/initialized yet"
        return 1
    fi
}

#
# Wrap the vaulted binary
vaulted() {
    if which vaulted > /dev/null; then
        check_session
        command vaulted ${@}
    else
        echo "ERROR: Vaulted doesn't appear to be installed"
        return 1
    fi
}
```

...and if you use [Rapture](https://github.com/daveadams/go-rapture) you can wrap that as well:

```sh
#
# Wrap the rapture binary
rapture() {
    if [[ -n "${GOPATH}" ]] && [[ -x "${GOPATH}/bin/rapture" ]]; then
        export _rapture_session_id \
            _rapture_session_key \
            _rapture_session_salt \
            _rapture_wrap=true

        check_session
        eval "$(${GOPATH}/bin/rapture ${@})"
    else
        echo "ERROR: Rapture doesn't appear to be installed"
        return 1
    fi
}
```
