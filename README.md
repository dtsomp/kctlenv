# kctlenv

[kubectl](https://kubernetes.io/docs/reference/kubectl/kubectl/) version manager ~~copied with pride from~~ heavily inspired by [tfenv](https://github.com/tfutils/tfenv)

## Installation

```
$ git clone https://github.com/dtsomp/kctlenv.git ~/.kctlenv
$ echo 'export PATH="$HOME/.tfenv/bin:$PATH" >> ~/.bash_profile
```

## Usage

So far only the absolute basics work:

```
$ kctlenv install 1.25.0
$ kctlenv list
$ kctlenv use 1.25.0
$ kctlenv uninstall 1.25.0
```

## .kubectl-version

If there is a `.kubectl-version` file in your current directory, `kctlenv install` will install the version written in it.

## Known issues

`kctlenv list-remote` will not work until the URL to a file of available kubectl versions is found.

Assume that anything not specifically mentioned as 'working' is broken as I haven't tested it.

## Development

This is a direct copy of [tfenv](https://github.com/tfutils/tfenv), on which lots of `sed` commands have been run. Any decent code and design has been done by the tfenv contributors, the crap is almost definitely by yours truly.

Feel free to fork this and make improvements, or rewrite completely, I'd be more than happy to use your version than mine. Let's just agree that we standardize `.kubectl-version` as the name for the version number file.

