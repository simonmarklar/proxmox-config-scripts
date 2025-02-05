#!/usr/bin/env bash

function exit-script() {
 # clear
  echo -e "⚠  User exited script \n"
  exit 0
}

function checkExitStatus() {
    if [[ ! $1 = 0 ]]; then
        exit 1
    fi
}


function ensureNotEmpty() {
    if [[ -z $1 ]]; then
        echo "${!1@} is empty - exiting script" 
        exit 1
    fi
}

function selectOption() {
    local title=$1
    shift
    local question=$1
    shift
    local options=("$@")
	local SCREEN_ARGS=(
        --title "$title"
        --noitem
        --radiolist "$question:"
        10 80 "${#options[@]}"
    )

    local i=0
    for MOUNT in "${options[@]}"; do
        SCREEN_ARGS+=("$MOUNT")
        SCREEN_ARGS+=( "OFF" )
    done

    whiptail_out=$(whiptail "${SCREEN_ARGS[@]}" 3>&1 1>&2 2>&3);
    checkExitStatus $?
    echo "$whiptail_out"
}

function getAnswer() {
    local title=$1
    local question=$2
    local defaultValue=""

    # if set, $3 is the default answer for the question
    if [[ ! -z $3 ]]; then
        defaultValue=$3
    fi
    local SCREEN_ARGS=(
        --title "$title"
        --inputbox "$question:" 
        10 80 $defaultValue
    )

    whiptail_out=$(whiptail "${SCREEN_ARGS[@]}" 3>&1 1>&2 2>&3)
    checkExitStatus $?
    echo "$whiptail_out"
}

function questions() {
    # get a list of nfs shares on the server
    local oldIfs=IFS
    IFS=,
    
    local NFS_MOUNTS=""
    local NFS_SHARE_ID=""
    NFS_SHARE=""

    if NFS_MOUNTS=$(showmount -e 10.0.0.14 --no-headers  | awk '{print $1}' | tr '\n ' ','); then
        if NFS_SHARE=$(selectOption "Select NFS Share" "Select NFS Share" $NFS_MOUNTS); then
            echo "oooh yeah!"
        else 
            echo "Couldn't select NFS Share :("
            exit 1
        fi
    else 
        exit 1
    fi

    # get the name of the last subfolder in the nfs share for the local mount point
    local origIFS=$IFS
    IFS=/

    read -ra split <<< "$NFS_SHARE"
    local len="${#split[@]}"
    (( len = len - 1 ))
    local defaultMountPoint=( "${split[$len]}" )
    IFS=$origIFS

    LOCAL_MOUNT_POINT=""
    LOCAL_MOUNT_POINT=$(getAnswer "Create new folder under /mnt/" "What is the mount point name?" $defaultMountPoint)

    IFS=$oldIfs
}

# make sure we have the required nfs tools
# TODO: support non debian os?
apt install nfs-common -y

# get nfs info
questions
ensureNotEmpty $NFS_SHARE
ensureNotEmpty $LOCAL_MOUNT_POINT

MOUNT_PATH="/mnt/$LOCAL_MOUNT_POINT"
NFS_PATH="10.0.0.14:$NFS_SHARE"


if [[ ! -d $MOUNT_PATH ]]; then
    echo "Creating mount path $MOUNT_PATH" && mkdir $MOUNT_PATH
    echo "Mounting NFS share $NFS_PATH" && mount $NFS_PATH $MOUNT_PATH
    echo "Adding NFS Mounts to /etc/fstab"
    echo "$NFS_PATH $MOUNT_PATH nfs defaults 0 0" >> /etc/fstab
else 
    echo "Mount path $MOUNT_PATH already exists..."
    echo "Attempting to mount anyways..."
    mount $NFS_PATH $MOUNT_PATH

    echo "Did NOT add NFS Mounts to /etc/fstab"
fi

