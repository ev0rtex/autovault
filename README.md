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

## Quickstart

For a quickstart (yeah, sorry...not super duper simple currently) get deps installed/configured:

```sh
brew cask install 1password-cli
brew install jq gnupg zsh
gpg --full-gen-key
    # Type of key:   1
    # Keysize:       2048
    # Valid for:     0
    # Real name:     <your name>
    # Email address: <your email>
    # Comment:       <blank>
    # ...(O)kay...?  o
    # Passphrase:    <passphrase>
```

_NOTE:_ Copy the 40-character public key ID from the GPG setup for use with 1pass.

Set up `1pass`:

```sh
mkdir -p ~/.local/bin && echo "export PATH=${HOME}/.local/bin:${PATH}" > ~/.${ZSH_NAME:-bash}rc
curl -sSLo ~/.local/bin/1pass https://raw.githubusercontent.com/dcreemer/1pass/master/1pass
chmod +x ~/.local/bin/1pass
1pass -rv
vim ~/.1pass/config
    # self_key=<4-char GPG key ID from above>
    # email=<your email>
    # subdomain=<your 1Password subdomain>
echo "<1Password master password>" | gpg -er <GPG ID or email> > ~/.1pass/_master.gpg
echo "<1Password secret key>" | gpg -er <GPG ID or email> > ~/.1pass/_secret.gpg
1pass -rv
```

## Usage

To use this script, just clone the repository and/or put the script to somewhere in your path:

```sh
[[ ! -d ${HOME}/.local/bin ]] && mkdir -p ${HOME}/.local/bin
ln -s ~/src/autovault/autovault.zsh ~/.local/bin/autovault
```
**- OR -**

```sh
curl -sSLo ~/.local/bin/autovault https://raw.githubusercontent.com/ev0rtex/autovault/master/autovault.zsh
chmod +x ~/.local/bin/autovault
```

In your shell rc file (`~/.zshrc`, `~/.bashrc`, etc.) you'll want to make sure you invoke it with the `env` command to get the `VAULTED_ASKPASS` var loaded into your environment:

```sh
eval "$(autovault env)"
```

### Creating a new vault

When you create a new vault using `vaulted` this script will be called as long as `VAULTED_ASKPASS` in configured in your environment. When you enter a password for the vault, this script will attempt to create a 1Password entry named `cli:vaulted:{vault_name}` that contains the password you used.

_NOTE:_ If you are using AWS credentials you will need to update the 1Password entry with a TOTP field that contains your MFA secret. You can copy this from an existing 1Password entry for your AWS account.

## Advanced Usage

### GPG agent cache TTL

The default cache TTLs for the GPG agent may be too long or too short for your liking. Decide what you consider a reasonable cache time (I do a default of 2 hours w/an 8 hour max) before you have to enter your GPG password again:

**~/.gnupg/gpg-agent.conf**
```
default-cache-ttl 7200
max-cache-ttl 28800
```

You may have to kill the gpg-agent if it's already running to get the new config:

```sh
killall gpg-agent
```

### Wrapping vaulted and rapture

In my own shell configuration I have added a few things to make it work more smoothly. Notably I try to do a simple sanity check and make sure that the `gpg-agent` is loaded because `1pass` will need to work with your encrypted `1password` data:

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
