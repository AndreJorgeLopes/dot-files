# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

plugins=(
  git
  git-auto-fetch
  zsh-completions
  zsh-autosuggestions
  zsh-interactive-cd
  fast-syntax-highlighting
  command-not-found
  dirhistory
  dotbare
  sudo
  fzf
  zoxide
)
fpath+=${ZSH_CUSTOM:-${ZSH:-~/.oh-my-zsh}/custom}/plugins/zsh-completions/src

# Fix slowness of pastes with zsh-syntax-highlighting.zsh
zstyle ':bracketed-paste-magic' active-widgets '.self-*'

# Zsh theme
# ----------------------------------------------------------------------------------------------------------------------------------
ZSH_THEME="powerlevel10k/powerlevel10k"
# ZSH_THEME="spaceship"
# ZSH_THEME="steeef"

COMPLETION_WAITING_DOTS="%F{yellow}waiting...%f"

SPACESHIP_PROMPT_ORDER=(
  user          # Username section
  dir           # Current directory section
  host          # Hostname section
  git           # Git section (git_branch + git_status)
  hg            # Mercurial section (hg_branch  + hg_status)
  exec_time     # Execution time
  line_sep      # Line break
  vi_mode       # Vi-mode indicator
  jobs          # Background jobs indicator
  exit_code     # Exit code section
  char          # Prompt character
)
SPACESHIP_USER_SHOW=always
SPACESHIP_PROMPT_ADD_NEWLINE=false
SPACESHIP_CHAR_SYMBOL="❯"
SPACESHIP_CHAR_SUFFIX=" "

POWERLEVEL10K_BATTERY_SHOW_ON_COMMAND=echo

# Remove aliases
# ----------------------------------------------------------------------------------------------------------------------------------
unalias z 2> /dev/null

unset gl

#Sources
# ----------------------------------------------------------------------------------------------------------------------------------
source $HOME/.oh-my-zsh/oh-my-zsh.sh

source $HOME/antigen.zsh

source $HOME/.functions

source $HOME/.binds

source $HOME/.aliases

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

# qfc config
[[ -s "$HOME/.qfc/bin/qfc.sh" ]] && source "$HOME/.qfc/bin/qfc.sh"

# User configuration
# ----------------------------------------------------------------------------------------------------------------------------------
# Mcfly init (^ + R)
eval "$(mcfly init zsh)"

# Zoxide init
eval "$(zoxide init zsh)"

# Antigen
antigen apply

# Exports
# ----------------------------------------------------------------------------------------------------------------------------------
# Path to your oh-my-zsh installation.
export ZSH="$HOME/.oh-my-zsh"

# Export prefered editor
export EDITOR='nano'

# Get the colors in the opened man/bro page itself
export MANPAGER="sh -c 'col -bx | bat -l man -p --paging always'"

#combine fzf with ripgrep
export FZF_CTRL_T_COMMAND='rg --files --no-ignore --hidden --follow --glob "!**/.git/*" --glob "!**/node_modules/*" --glob "!**/vendor/*" --glob "!**/.vscode-server/*" 2> /dev/null'

# Secretive Config
export SSH_AUTH_SOCK=/Users/andrejorgelopes/Library/Containers/com.maxgoedjen.Secretive.SecretAgent/Data/socket.ssh

# Node Version Manager config (nvm)
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

# All path folders for env varaibles
export PATH="$HOME/.config/composer/vendor/bin:$HOME/.cargo/bin:$HOME/.yarn/bin:$HOME/.config/yarn/global/node_modules/.bin:$PATH"

