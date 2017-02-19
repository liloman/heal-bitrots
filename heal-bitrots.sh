#!/usr/bin/env bash
#Automatic check and self-healing for bitrot :)

#Requires:
#pip install --user bitrot
#dnf/apt/x install par2cmdline

# dir where will be saved the recovery data (bitrot dbs and par2 files)
# better mirror/backup/sync it also ;)
declare BITROT_BACKUPS=${BITROT_BACKUPS:-~/.bitrot_backups}
declare BITROT_BACKUPS_DEST=${BITROT_BACKUPS_DEST:-$BITROT_BACKUPS/bitrot_dirs}
declare PAR2_NAME=files.par2
declare LOG_CREATE=/tmp/.generate_par2_create.log
declare LOG_REPAIR=/tmp/.generate_par2_repair.log
declare LOG_BITROT=/tmp/.generate_bitrot_db.log
declare DEFAULT_OPTIONS=

[[ -d $BITROT_BACKUPS ]] ||  mkdir -p "$BITROT_BACKUPS"

hash bitrot &>/dev/null || { echo "Needs bitrot. Install it with: pip install --user bitrot" ; exit 1;  } 
hash par2 &>/dev/null || { echo "Needs par2. Install it with: dnf/apt/x install par2cmdline" ; exit 1;  } 

######################
#  GLOBAL VARIABLES  #
######################

declare -i max_files=32768
declare -i max_block_count=2000
declare -i redundancy=5

###################
# MAIN FUNCTIONS  #
###################



set_default_global_options() {

    #let's use half free memory 
    local memgrep=($(grep MemAvailable /proc/meminfo))
    local mBFree=$((${memgrep[1]}/1024/2))
    DEFAULT_OPTIONS+=" -m${mBFree}"

    #set number of threads
    #if more than 2 processors, don't use all due performance fall
    local cpus=$(getconf _NPROCESSORS_ONLN) 
    (($cpus > 2)) && DEFAULT_OPTIONS+=" -t$((cpus-2))"

}

generate_par2files() {
    local -a target_files=()
    local target_dir=$(realpath -P "$1")
    local source_dir=$BITROT_BACKUPS/${target_dir:1}
    local par2_files=$source_dir/$PAR2_NAME
    local local_options=

    err() {
        echo "$@"
        echo "See $LOG_CREATE or $LOG_REPAIR for errors."
        exit 1
    }

    echo "----------------------------------"
    echo "Generating par2 files for $target_dir"

    # It could be that $target_dir has been deleted or renamed.So not fail
    [[ -d $target_dir ]] || { echo "$target_dir not a dir or not found"; return; }


    #Create $source_dir
    mkdir -p $source_dir || err "Couldn't create $source_dir"

    # change local dir
    echo "Change local directory to $target_dir"
    cd "$target_dir" || err "Couldn't cd  into $target_dir "


    #check the dir files
    local total_files=$(find . -maxdepth 1 -type f | wc -l)
    if (( $total_files > $max_files )); then
        err "Number of files in $target_dir: $total_files > $max_files"
    fi

    #check that there aren't more than $max_block_count in $target_dir
    if (( $total_files > $max_block_count )); then
        local size=($(du -bs $target_dir))
        #calculate block size for $redundancy% 
        local target_dir_tam=$((${size[0]}*$redundancy/100))
        #get size in MBs of $target_dir
        local block_bytes=$(( $target_dir_tam / $max_block_count ))
        #final adjust to be multiple of 4!!
        local block_size=$(( $block_bytes * 2**2 ))
        echo "Increasing the default block size for $target_dir to $block_size bytes"
        local_options+=" -s${block_size}"
    fi

    for file in $(find . -maxdepth 1 -type f ! -size 0); do
        target_files+=("$file")
    done

    if (( ${#target_files} > 0 )); then
        #generate new par2 files 
        echo "Launching par2create "
        if ! par2create $DEFAULT_OPTIONS $local_options -v $PAR2_NAME "${target_files[@]}" &>$LOG_CREATE  ; then
            \rm -f *.par2 
            err "Couldn't generate par2 files for $target_dir"
        fi

        #Copy par2 files and bitrot database to $source_dir
        echo "Moving par2 files to $source_dir"
        if ! mv *.par2 $source_dir/ ; then
            \rm -f *.par2 
            err "Couldn't copy par2 files and bitrot database to $source_dir/" 
        fi
    fi

    echo "Done!"
}



split_dir() {
    local line=  temp_file= par2_files=
    local target_dir=$(realpath -P "$1" 2> /dev/null)
    local source_dir=$BITROT_BACKUPS/${target_dir:1}
    local regex_bitrot='error: SHA.* mismatch for (.*): expected .*'
    local regex_changes='([[:digit:]]* entries in the database. )?([[:digit:]]*) entries (updated|new|missing):'
    local regex_moved='([[:digit:]]* entries in the database. )?([[:digit:]]*) entries renamed:'
    local regex_dir_changes='(.*)'
    local regex_dir_moved='from (.*) to (.*)'
    local -a com=(find . -type d)
    local -A dirs_bitrot=()
    local -A dirs_change=()
    local -A dirs_moved=()
    local -i count=0 
    local -i count_moved=0

    err() {
        echo "$@"
        echo "See $LOG_BITROT, $LOG_CREATE or $LOG_REPAIR for errors."
        exit 1
    }


    echo "----------------------------------"
    echo "Checking $target_dir for bitrot"

    #check if exists after backups dir check
    [[ -d $target_dir ]] || err "$target_dir not a dir or not found"

    #check if target is just the backups dir
    local full_target=$target_dir/
    if [[ ${full_target::$((${#BITROT_BACKUPS}+1))} == $BITROT_BACKUPS/ ]]; then
        echo "$target_dir is a subdir of $BITROT_BACKUPS. Next!."
        return
    fi

    cd "$target_dir" || err "couldn't cd to $target_dir"

    if [[ -f $source_dir/.bitrot.db ]]; then
        echo "Copying bitrot db files to ."
        if ! cp $source_dir/.bitrot.* .; then
            err "Couldn't copy $source_dir/.bitrot.* files to ."
        fi
    fi

    echo "Launching bitrot -v"
    bitrot -v &>$LOG_BITROT


    while read -r line; do
        #no change detected
        if (( $count == 0 && $count_moved == 0 )); then
            #check log for bitrot errors
            if [[  $line =~ $regex_bitrot ]]; then
                temp_file="$target_dir/${BASH_REMATCH[1]:2}"
                echo "bitrot detected in file:$temp_file"
                #add to unique index (associative array) 
                # and save file just in case
                dirs_bitrot["${temp_file%/*}/"]="$temp_file"
            fi 

            if [[  $line =~ $regex_changes ]]; then
                count=${BASH_REMATCH[2]}
                # echo "->New/updated/missing files detected"
            fi 

            if [[  $line =~ $regex_moved ]]; then
                count_moved=${BASH_REMATCH[2]}
                # echo "->renamed files detected"
            fi 
        else #change detected
            if (( $count > 0 )); then
                if [[  $line =~ $regex_dir_changes ]]; then
                    file=${BASH_REMATCH[1]}
                    echo "change detected in:$file"
                    dirs_change["${file%/*}/"]="$file"
                    ((count--))
                fi 
            elif (( $count_moved > 0 )); then
                if [[  $line =~ $regex_dir_moved ]]; then
                    orig=${BASH_REMATCH[1]}
                    dest=${BASH_REMATCH[2]}
                    echo "Move detected from:$orig to:$dest"
                    dirs_moved["${orig%/*}"]=1
                    dirs_moved["${dest%/*}"]=1
                    ((count_moved--))
                fi 
            fi
        fi
    done <$LOG_BITROT


    for dir in "${!dirs_bitrot[@]}"; do
        cd "$dir" || err "Couldn't cd  into $dir "
        echo "Recovering from bitrot with par2 files in $dir"
        par2_files=$BITROT_BACKUPS/${dir:1}/$PAR2_NAME
        #if there's a par2 files generated already copy them 
        if [[ -f $par2_files ]]; then
            echo "Copying $par2_files to ."
            if ! cp "${par2_files%/*}/"*.par2 .; then
                \rm -f *.par2  
                err "Couldn't copy par2 files to $target_dir"
            fi
        fi

        #Purge recovery par2 files if successfull
        echo "Repairing bitrot files with par2repair"
        if ! par2repair -p $PAR2_NAME &>$LOG_REPAIR; then
            \rm -f *.par2  
            cd "$target_dir" || err "couldn't cd to $target_dir"
            if [[ -e .bitrot.db ]]; then
                [[ -d $source_dir ]] || mkdir -p "$source_dir"
                echo "Moving bitrot db files to $source_dir"
                if ! mv .bitrot.* $source_dir; then
                    \rm -f .bitrot.*
                    err "Couldn't move bitrot files to $source_dir"
                fi
            fi
            err "Couldn't repair $dir with par2 files"
        else #update the db for the new changes
            cd "$target_dir" || err "couldn't cd to $target_dir"
            echo "Launching bitrot -v after bitrot"
            bitrot -v &>$LOG_BITROT
        fi
        cd - &>/dev/null
    done

    #regenerate dir changes
    for dir in "${!dirs_change[@]}"; do
        cd "$target_dir" || err "couldn't cd to $target_dir"
        echo "launching generate_par2files in:$dir"
        generate_par2files "${dir}"
    done

    #regenerate dir moved
    for dir in "${!dirs_moved[@]}"; do
        #if it doesn't exist it just normal in this case
        [[ -d  $dir ]] || continue
        cd "$target_dir" || err "couldn't cd to $target_dir"
        echo "launching generate_par2files in:$dir"
        generate_par2files "${dir}"
    done

    if (( ${#dirs_bitrot} == 0 && ${#dirs_change[@]} == 0 && ${#dirs_moved[@]} )); then 
        echo "No changes detected."
    fi

    cd "$target_dir" || err "couldn't cd to $target_dir"

    if [[ -e .bitrot.db ]]; then
        [[ -d $source_dir ]] || mkdir -p "$source_dir"
        echo "Moving bitrot db files to $source_dir"
        if ! mv .bitrot.* $source_dir; then
            \rm -f .bitrot.*
            err "Couldn't move bitrot files to $source_dir"
        fi
    fi

    echo "Done!"
}

#set memory and number of threads
set_default_global_options 

cur=$PWD
if [[ -n $1 ]]; then
    #For each path
    for path; do
        cd "$cur"
        split_dir "$path"
    done
elif [[ -f $BITROT_BACKUPS_DEST ]]; then
    while IFS= read -r path
    do
        cd "$cur"
        split_dir "$path"
    done < $BITROT_BACKUPS_DEST
else
    echo "You must pass the target paths or set $BITROT_BACKUPS_DEST with your absolute target paths in each line"
    exit 1
fi
