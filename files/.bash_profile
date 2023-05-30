# Ansible managed

# include .bashrc if it exists
if [[ -f "${HOME}/.bashrc" ]]
then
  source  "${HOME}/.bashrc"
fi

# set PATH so it includes user's ~/bin if present
if [[ -d "${HOME}/bin" ]]
then
  export PATH="${HOME}/bin:${PATH}"
fi

# set PATH so it includes user's ~/.local/bin if present
if [[ -d "${HOME}/.local/bin" ]]
then
  export PATH="${HOME}/.local/bin:${PATH}"
fi

# set MYSQL_HISTFILE if a directory for MySQL history is present
if [[ -d "${HOME}/.mysql" ]]
then
  export MYSQL_HISTFILE="${HOME}/.mysql/history"
fi

# set TMPDIR, TMP and TEMP if ~/tmp exists
if [[ -d "${HOME}/tmp" ]]
then
  export TMPDIR="${HOME}/tmp"
  export TMP="${HOME}/tmp"
  export TEMP="${HOME}/tmp"
fi

# vim: syntax=bash
