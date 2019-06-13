
if [ -n "$ZSH_NAME" ]
then
    # vim keybindings
    bindkey -v

    # The following lines were added by compinstall
    zstyle ':completion:*' completer _expand _complete _ignored _correct
    zstyle :compinstall filename '/home/jcspence/.zshrc'
    
    autoload -Uz compinit
    compinit

    HISTFILE=~/.histfile
    HISTSIZE=10000
    SAVEHIST=10000
    setopt appendhistory autocd
    
    # Suffix aliases ("open with")
    alias -s pdf='evince'
    alias -s {txt,md,markdown,yml,conf,j2}='vim'

    # Enable comments
    setopt interactivecomments

    # Enable reverse-i-search
    bindkey "^R" history-incremental-search-backward

    # set a prompt
    export PS1='[%n@%m]%~%# '
# end zsh-specific entries
elif [ -n "$BASH_VERSION" ]
then
    export PS1='[\u@\h \W]\$ '
fi

