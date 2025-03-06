#!/bin/bash

# This file parses environmental variables $DL_JUMPHOST_CONN_X and 
# creates a SSH config file that routes SSH traffic to $DL_DEPLOYHOST_CONN
# through these jumphosts. If no $DL_JUMPHOST_CONN_X exists,
# then the connection to $DL_DEPLOYHOST_CONN is direct.
# 
# ###
# Example ENV variables:
#DL_JUMPHOST_CONN_1="dljumphost@jumpserver1:22"
#DL_JUMPHOST_CONN_2="dljumphost@jumpserver2:22"
# 
# DL_JUMPHOST_SSHKEY_1=$(cat << EOF
# -----BEGIN OPENSSH PRIVATE KEY-----
# ...
# -----END OPENSSH PRIVATE KEY-----
# EOF
# )
# 
#DL_DEPLOYHOST_CONN="deploy@targetserver:22"
#DL_DEPLOYHOST_SSHKEY=$(cat <<EOF
# ...
#EOF
#)
dl_jumphost_make_configfile() {
    # Remove current SSH config file

    if [ -f ~/.ssh/config ]; then
        mv ~/.ssh/config ~/.ssh/config.back
    fi

    rm -f ~/.ssh/config && \
        mkdir -p ~/.ssh/ && \
        touch ~/.ssh/config && \
        rm -f ~/dljumphost_identity_*.txt 

    # Loop through any & all jumphosts and configure them
    local i=1
    local varname="DL_JUMPHOST_CONN_$i"

    while [[ "${!varname}" != "" ]]
    do
        # Extract info from connection string
        local user=$(echo "${!varname}" | sed -E 's/(.*)@(.*)\:([0-9]*)/\1/')
        local host=$(echo "${!varname}" | sed -E 's/(.*)@(.*)\:([0-9]*)/\2/')
        local port=$(echo "${!varname}" | sed -E 's/(.*)@(.*)\:([0-9]*)/\3/')

        # Create config file entry for this jumphost
        local CONFIG="Host dljumpproxy$i"$'\n\t'"HostName $host"$'\n\t'"User $user"$'\n\t'"Port $port"$'\n\t'"IdentityFile ~/dljumphost_identity_$i.txt"$'\n\t'"StrictHostKeyChecking no"$'\n\t'"UserKnownHostsFile=/dev/null"$'\n\t'"ForwardAgent yes"

        if [ $i -gt 1 ]; then
            local CONFIG="$CONFIG"$'\n\t'"ProxyJump dljumpproxy$(($i-1))"
        fi

        echo "$CONFIG" >> ~/.ssh/config

        # Write key to file
        local varname_key="DL_JUMPHOST_SSHKEY_$i"
        echo "${!varname_key}" > ~/dljumphost_identity_$i.txt
        chmod 600 ~/dljumphost_identity_$i.txt

        # Prepare for next loop
        local i=$(($i+1))
        local varname="DL_JUMPHOST_CONN_$i"
    done

    # Target host
    local user=$(echo "$DL_DEPLOYHOST_CONN" | sed -E 's/(.*)@(.*)\:([0-9]*)/\1/')
    local host=$(echo "$DL_DEPLOYHOST_CONN" | sed -E 's/(.*)@(.*)\:([0-9]*)/\2/')
    local port=$(echo "$DL_DEPLOYHOST_CONN" | sed -E 's/(.*)@(.*)\:([0-9]*)/\3/')

    local CONFIG="Host dltarget"$'\n\t'"HostName $host"$'\n\t'"User $user"$'\n\t'"Port $port"$'\n\t'"IdentityFile ~/dljumphost_identity_target.txt"$'\n\t'"StrictHostKeyChecking no"$'\n\t'"UserKnownHostsFile=/dev/null"$'\n\t'"ForwardAgent yes"

    if [ $i -gt 1 ]; then
        local CONFIG="$CONFIG"$'\n\t'"ProxyJump dljumpproxy$(($i-1))"
    fi

    # Add target to SSH config, add key
    echo "$CONFIG" >> ~/.ssh/config
    echo -e "$DL_DEPLOYHOST_SSHKEY" > ~/dljumphost_identity_target.txt
    chmod 600 ~/dljumphost_identity_target.txt

    # If you use `ssh dltarget`, then you should be inside the target host without further ado, routed through all jumphosts.
}

dl_jumphost_restore_configfile() {
    if [ -f ~/.ssh/config.back ]; then
        mv ~/.ssh/config.back ~/.ssh/config
    else
        rm -f ~/.ssh/config
    fi

    rm ~/dljumphost_identity_*
}

export -f dl_jumphost_make_configfile
export -f dl_jumphost_restore_configfile
