#!/bin/sh

set -eu

host_ssh_dir=/run/copilot-host-ssh
host_gnupg_dir=/run/copilot-host-gnupg
host_ssh_agent_sock="${COPILOT_HOST_SSH_AUTH_SOCK:-}"
target_home=/home/agent
target_ssh_dir="$target_home/.ssh"
target_gnupg_dir="$target_home/.gnupg"
target_ssh_agent_sock="$target_ssh_dir/agent.sock"
git_ssh_command=
ssh_auth_sock=

copy_ssh_file() {
  src_name="$1"
  mode="$2"
  src_path="$host_ssh_dir/$src_name"
  dest_path="$target_ssh_dir/$src_name"

  if [ -f "$src_path" ]; then
    install -D -o agent -g agent -m "$mode" "$src_path" "$dest_path"
  fi
}

copy_gnupg_home() {
  if [ ! -d "$host_gnupg_dir" ]; then
    return
  fi

  rm -rf "$target_gnupg_dir"
  install -d -o agent -g agent -m 700 "$target_gnupg_dir"
  tar -C "$host_gnupg_dir" --exclude='./S.*' -cf - . 2>/dev/null \
    | tar -C "$target_gnupg_dir" -xf -
  find "$target_gnupg_dir" -type d -exec chown agent:agent {} \; -exec chmod 700 {} \;
  find "$target_gnupg_dir" -type f -exec chown agent:agent {} \; -exec chmod 600 {} \;
}

start_ssh_agent_relay() {
  if [ ! -S "$host_ssh_agent_sock" ]; then
    return
  fi

  install -d -o agent -g agent -m 700 "$target_ssh_dir"
  rm -f "$target_ssh_agent_sock"
  socat "UNIX-LISTEN:$target_ssh_agent_sock,fork,user=agent,group=agent,mode=600" \
    "UNIX-CONNECT:$host_ssh_agent_sock" &

  i=0
  while [ "$i" -lt 20 ]; do
    if [ -S "$target_ssh_agent_sock" ]; then
      ssh_auth_sock="$target_ssh_agent_sock"
      return
    fi

    i=$((i + 1))
    sleep 0.1
  done
}

if [ -d "$host_ssh_dir" ]; then
  install -d -o agent -g agent -m 700 "$target_ssh_dir"
  copy_ssh_file id_rsa 600
  copy_ssh_file id_rsa.pub 644
  copy_ssh_file known_hosts 644
  copy_ssh_file config 600
fi

start_ssh_agent_relay

if [ -n "$ssh_auth_sock" ]; then
  git_ssh_command="ssh -o IdentityAgent=$ssh_auth_sock"
fi

if [ -f "$target_ssh_dir/id_rsa" ]; then
  if [ -n "$ssh_auth_sock" ]; then
    git_ssh_command="ssh -o IdentityAgent=$ssh_auth_sock -i $target_ssh_dir/id_rsa -o IdentitiesOnly=yes"
  else
    git_ssh_command="ssh -i $target_ssh_dir/id_rsa -o IdentitiesOnly=yes"
  fi
fi

copy_gnupg_home

if [ -n "$git_ssh_command" ]; then
  exec setpriv --reuid=agent --regid=agent --init-groups \
    env HOME="$target_home" USER=agent LOGNAME=agent GNUPGHOME="$target_gnupg_dir" \
    SSH_AUTH_SOCK="$ssh_auth_sock" GIT_SSH_COMMAND="$git_ssh_command" "$@"
fi

exec setpriv --reuid=agent --regid=agent --init-groups \
  env HOME="$target_home" USER=agent LOGNAME=agent GNUPGHOME="$target_gnupg_dir" \
  SSH_AUTH_SOCK="$ssh_auth_sock" "$@"
