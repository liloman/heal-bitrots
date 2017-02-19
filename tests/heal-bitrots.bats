#!/usr/bin/env bats

#WARNING!
#Be careful don't use ((, cause (( $status == pp )) && echo Really WRONG!
#the issue is that (( 0 == letters )) is always true ... :(

load test_helper

#Set destination temporal destination for backups
export BITROT_BACKUPS="/tmp/.bitrot_backups"

r=$BATS_TEST_DIRNAME/../heal-bitrots.sh
test_dir=/tmp/heal_bitrots_dir-$USER
mkdir -p  $test_dir
cd $test_dir

###########
#  BASIC  #
###########


@test "heal-bitrots without arguments. warning about target paths" {
run $r
(( $status == 1 ))
[[ ${lines[0]} = "You must pass the target paths or"* ]]
}

@test "heal-bitrots dirnotfound shows dir not found" {
run $r dirnotfound
(( $status == 1 ))
[[ ${lines[2]} = "$test_dir/dirnotfound not a dir or not found" ]]
}

@test "heal-bitrots with multiple notfounddirs shows dir not found" {
run $r dirnotfound1 dirnotfound2
(( $status == 1 ))
[[ ${lines[2]} = "$test_dir/dirnotfound1 not a dir or not found" ]]
}

@test "heal-bitrots in a file shows not a dir" {
touch notadir
run $r notadir
\rm notadir
(( $status == 1 ))
[[ ${lines[2]} = "$test_dir/notadir not a dir or not found" ]]
}

@test "heal-bitrots in a empty dir doesn't fail" {
mkdir emptydir
run $r emptydir
(( $status == 0 ))
[[ ${lines[1]} = "Checking $test_dir/emptydir for bitrot" ]]
[[ ${lines[2]} = "Launching bitrot -v" ]]
[[ ${lines[3]} = "Moving bitrot db files to $BITROT_BACKUPS/${test_dir:1}/emptydir" ]]
[[ ${lines[4]} = "Done!" ]]
[[ -e emptydir/ ]]
[[ -e $BITROT_BACKUPS/${test_dir:1}/emptydir/.bitrot.db ]]
}


@test "heal-bitrots in a empty dir doesn't fail with relative path" {
run $r ../${test_dir##*/}/emptydir
(( $status == 0 ))
[[ ${lines[1]} = "Checking $test_dir/emptydir for bitrot" ]]
[[ ${lines[2]} = "Copying bitrot db files to ." ]]
[[ ${lines[3]} = "Launching bitrot -v" ]]
[[ ${lines[4]} = "Moving bitrot db files to $BITROT_BACKUPS/${test_dir:1}/emptydir" ]]
[[ ${lines[5]} = "Done!" ]]
[[ -e emptydir/ ]]
[[ -e $BITROT_BACKUPS/${test_dir:1}/emptydir/.bitrot.db ]]
\rm -rf emptydir
}

@test "heal-bitrots in a not empty dir create everything" {
mkdir notemptydir&>/dev/null
echo $RANDOM >> notemptydir/file.txt
run $r notemptydir

#check_fail "${lines[@]}"

(( $status == 0 ))
[[ -n ${lines[1]} ]]
[[ -n ${lines[12]} ]]
[[ ${lines[1]} = "Checking $test_dir/notemptydir for bitrot" ]]
[[ ${lines[2]}  = "Launching bitrot -v" ]]
[[ ${lines[3]}  = "change detected in:./file.txt" ]]
[[ ${lines[4]}  = "launching generate_par2files in:./" ]]
[[ ${lines[6]}  = "Generating par2 files for $test_dir/notemptydir" ]]
[[ ${lines[7]}  = "Change local directory to $test_dir/notemptydir" ]]
[[ ${lines[8]}  = "Launching par2create " ]]
[[ ${lines[9]}  = "Moving par2 files to $BITROT_BACKUPS/${test_dir:1}/notemptydir" ]]
[[ ${lines[10]} = "Done!" ]]
[[ ${lines[11]} = "Moving bitrot db files to $BITROT_BACKUPS/${test_dir:1}/notemptydir" ]]
[[ ${lines[12]} = "Done!" ]]
[[ -d notemptydir/ ]]
[[ -e $BITROT_BACKUPS/${test_dir:1}/notemptydir/files.par2 ]]
[[ -e $BITROT_BACKUPS/${test_dir:1}/notemptydir/.bitrot.db ]]
}

@test "heal-bitrots in a not empty dir without changes" {
run $r notemptydir
[[ -e $BITROT_BACKUPS/${test_dir:1}/notemptydir/.bitrot.db ]]
(( $status == 0 ))
[[ ${lines[1]} = "Checking $test_dir/notemptydir for bitrot" ]]
[[ ${lines[2]} = "Copying bitrot db files to ." ]]
[[ ${lines[3]} = "Launching bitrot -v" ]]
[[ ${lines[4]} = "Moving bitrot db files to $BITROT_BACKUPS/${test_dir:1}/notemptydir" ]]
[[ ${lines[5]} = "Done!" ]]
[[ -e notemptydir/ ]]
}

@test "heal-bitrots in a not empty tree dir create the recovery tree in backups" {
mkdir -p notemptydirs/{dir1,dir2}
echo $RANDOM >> notemptydirs/dir1/file1.txt
echo $RANDOM >> notemptydirs/dir2/file2.txt
run $r notemptydirs

(( $status == 0 ))
[[ ${lines[1]}   = "Checking $test_dir/notemptydirs for bitrot" ]]
[[ ${lines[2]}   = "Launching bitrot -v" ]]
[[ ${lines[3]}   = "change detected in:./dir1/file1.txt" ]]
[[ ${lines[4]}   = "change detected in:./dir2/file2.txt" ]]
[[ ${lines[5]}   = "launching generate_par2files in:./dir1/" ]]
[[ ${lines[7]}   = "Generating par2 files for $test_dir/notemptydirs/dir1" ]]
[[ ${lines[8]}   = "Change local directory to $test_dir/notemptydirs/dir1" ]]
[[ ${lines[9]}   = "Launching par2create " ]]
[[ ${lines[10]}   = "Moving par2 files to $BITROT_BACKUPS/${test_dir:1}/notemptydirs/dir1" ]]
[[ ${lines[11]}  = "Done!" ]]
[[ ${lines[12]}  = "launching generate_par2files in:./dir2/" ]]
[[ ${lines[14]}  = "Generating par2 files for $test_dir/notemptydirs/dir2" ]]
[[ ${lines[15]}  = "Change local directory to $test_dir/notemptydirs/dir2" ]]
[[ ${lines[16]}  = "Launching par2create " ]]
[[ ${lines[17]}  = "Moving par2 files to $BITROT_BACKUPS/${test_dir:1}/notemptydirs/dir2" ]]
[[ ${lines[18]}  = "Done!" ]]
[[ -e notemptydirs/ ]]
[[ -e $BITROT_BACKUPS/${test_dir:1}/notemptydirs/dir1/files.par2 ]]
[[ -e $BITROT_BACKUPS/${test_dir:1}/notemptydirs/dir2/files.par2 ]]
[[ ! -e .bitrot* ]]
[[ ! -e notemptydirs/dir1/files.par2 ]]
[[ ! -e notemptydirs/dir2/files.par2 ]]
}

@test "heal-bitrots in two not empties trees dir create the recovery trees in backups" {
mkdir -p notemptydirs2/{dir1,dir2}
echo $RANDOM >> notemptydirs2/dir1/file1.txt
echo $RANDOM >> notemptydirs2/dir2/file2.txt
run $r notemptydirs2/dir1 notemptydirs2/dir2


(( $status == 0 ))
[[ ${lines[1]}   = "Checking $test_dir/notemptydirs2/dir1 for bitrot" ]]
[[ ${lines[2]}   = "Launching bitrot -v" ]]
[[ ${lines[3]}   = "change detected in:./file1.txt" ]]
[[ ${lines[4]}   = "launching generate_par2files in:./" ]]
[[ ${lines[6]}   = "Generating par2 files for $test_dir/notemptydirs2/dir1" ]]
[[ ${lines[7]}   = "Change local directory to $test_dir/notemptydirs2/dir1" ]]
[[ ${lines[8]}   = "Launching par2create " ]]
[[ ${lines[9]}   = "Moving par2 files to $BITROT_BACKUPS/${test_dir:1}/notemptydirs2/dir1" ]]
[[ ${lines[10]}  = "Done!" ]]
[[ ${lines[11]}  = "Moving bitrot db files to $BITROT_BACKUPS/${test_dir:1}/notemptydirs2/dir1" ]]
[[ ${lines[12]}  = "Done!" ]]
[[ ${lines[14]}  = "Checking $test_dir/notemptydirs2/dir2 for bitrot" ]]
[[ ${lines[15]}  = "Launching bitrot -v" ]]
[[ ${lines[16]}  = "change detected in:./file2.txt" ]]
[[ ${lines[17]}  = "launching generate_par2files in:./" ]]
[[ ${lines[19]}  = "Generating par2 files for $test_dir/notemptydirs2/dir2" ]]
[[ ${lines[20]}  = "Change local directory to $test_dir/notemptydirs2/dir2" ]]
[[ ${lines[21]}  = "Launching par2create " ]]
[[ ${lines[22]}  = "Moving par2 files to $BITROT_BACKUPS/${test_dir:1}/notemptydirs2/dir2" ]]
[[ ${lines[23]}  = "Done!" ]]
[[ ${lines[24]}  = "Moving bitrot db files to $BITROT_BACKUPS/${test_dir:1}/notemptydirs2/dir2" ]]
[[ ${lines[25]}  = "Done!" ]]

[[ -e notemptydirs/ ]]
[[ -e $BITROT_BACKUPS/${test_dir:1}/notemptydirs/dir1/files.par2 ]]
[[ -e $BITROT_BACKUPS/${test_dir:1}/notemptydirs/dir2/files.par2 ]]
[[ ! -e .bitrot* ]]
[[ ! -e notemptydirs/dir1/files.par2 ]]
[[ ! -e notemptydirs/dir2/files.par2 ]]
}


@test "heal-bitrots detects new files in a tree dir" {
touch notemptydirs/dir2/new-file-{a,b}.txt
echo $RANDOM >> notemptydirs/dir2/new-file-b.txt

run $r notemptydirs
(( $status == 0 ))
[[ ${lines[1]}   = "Checking $test_dir/notemptydirs for bitrot" ]]
[[ ${lines[2]}   = "Copying bitrot db files to ." ]]
[[ ${lines[3]}   = "Launching bitrot -v" ]]
[[ ${lines[4]}   = "change detected in:./dir2/new-file-a.txt" ]]
[[ ${lines[5]}   = "change detected in:./dir2/new-file-b.txt" ]]
[[ ${lines[6]}   = "launching generate_par2files in:./dir2/" ]]
[[ ${lines[8]}   = "Generating par2 files for $test_dir/notemptydirs/dir2" ]]
[[ ${lines[9]}   = "Change local directory to $test_dir/notemptydirs/dir2" ]]
[[ ${lines[10]}  = "Launching par2create " ]]
[[ ${lines[11]}  = "Moving par2 files to $BITROT_BACKUPS/${test_dir:1}/notemptydirs/dir2" ]]
[[ ${lines[12]}  = "Done!" ]]
[[ ${lines[13]}  = "Moving bitrot db files to $BITROT_BACKUPS/${test_dir:1}/notemptydirs" ]]
[[ ${lines[14]}  = "Done!" ]]
[[ -e notemptydirs/ ]]
[[ -e $BITROT_BACKUPS/${test_dir:1}/notemptydirs/dir2/files.par2 ]]
[[ -e $BITROT_BACKUPS/${test_dir:1}/notemptydirs/.bitrot.db ]]
[[ ! -e .bitrot* ]]
[[ ! -e notemptydirs/dir2/files.par2 ]]
[[ ! -e notemptydirs/.bitrot.db ]]
}

@test "heal-bitrots detects a modified file in a tree dir" {
#to let sometime to not detect bitrot due same timestamp
sleep 1
date >> notemptydirs/dir2/file2.txt
run $r notemptydirs
# check_fail "${lines[@]}"

(( $status == 0 ))
[[ ${lines[1]}   = "Checking $test_dir/notemptydirs for bitrot" ]]
[[ ${lines[2]}   = "Copying bitrot db files to ." ]]
[[ ${lines[3]}   = "Launching bitrot -v" ]]
[[ ${lines[4]}   = "change detected in:./dir2/file2.txt" ]]
[[ ${lines[5]}   = "launching generate_par2files in:./dir2/" ]]
[[ ${lines[7]}   = "Generating par2 files for $test_dir/notemptydirs/dir2" ]]
[[ ${lines[8]}   = "Change local directory to $test_dir/notemptydirs/dir2" ]]
[[ ${lines[9]}   = "Launching par2create " ]]
[[ ${lines[10]}  = "Moving par2 files to $BITROT_BACKUPS/${test_dir:1}/notemptydirs/dir2" ]]
[[ ${lines[11]}  = "Done!" ]]
[[ ${lines[12]}  = "Moving bitrot db files to $BITROT_BACKUPS/${test_dir:1}/notemptydirs" ]]
[[ ${lines[13]}  = "Done!" ]]
[[ -e notemptydirs/ ]]
[[ -e $BITROT_BACKUPS/${test_dir:1}/notemptydirs/dir2/files.par2 ]]
[[ -e $BITROT_BACKUPS/${test_dir:1}/notemptydirs/.bitrot.db ]]
[[ ! -e .bitrot* ]]
[[ ! -e notemptydirs/files.par2 ]]
[[ ! -e notemptydirs/.bitrot.db ]]

}

@test "heal-bitrots detects a deleted file in a tree dir" {
\rm -f notemptydirs/dir2/file2.txt

run $r notemptydirs
(( $status == 0 ))
[[ ${lines[1]}   = "Checking $test_dir/notemptydirs for bitrot" ]]
[[ ${lines[2]}   = "Copying bitrot db files to ." ]]
[[ ${lines[3]}   = "Launching bitrot -v" ]]
[[ ${lines[4]}   = "change detected in:./dir2/file2.txt" ]]
[[ ${lines[5]}   = "launching generate_par2files in:./dir2/" ]]
[[ ${lines[7]}   = "Generating par2 files for $test_dir/notemptydirs/dir2" ]]
[[ ${lines[8]}   = "Change local directory to $test_dir/notemptydirs/dir2" ]]
[[ ${lines[9]}   = "Launching par2create " ]]
[[ ${lines[10]}   = "Moving par2 files to $BITROT_BACKUPS/${test_dir:1}/notemptydirs/dir2" ]]
[[ ${lines[11]}  = "Done!" ]]
[[ ${lines[12]}  = "Moving bitrot db files to $BITROT_BACKUPS/${test_dir:1}/notemptydirs" ]]
[[ ${lines[13]}  = "Done!" ]]
[[ -e notemptydirs/ ]]
[[ -e $BITROT_BACKUPS/${test_dir:1}/notemptydirs/dir2/files.par2 ]]
[[ -e $BITROT_BACKUPS/${test_dir:1}/notemptydirs/.bitrot.db ]]
[[ ! -e .bitrot* ]]
[[ ! -e notemptydirs/files.par2 ]]
}


@test "heal-bitrots detects a bitrot and repair it in a tree dir" {
generate_bitrot bitrotdir/dir2/bitrot.file 10 2
# check_fail "${lines[@]}"

(( $status == 0 ))
[[ ${lines[1]}   = "Checking $test_dir/bitrotdir for bitrot" ]]
[[ ${lines[2]}   = "Copying bitrot db files to ." ]]
[[ ${lines[3]}   = "Launching bitrot -v" ]]
[[ ${lines[4]}   = "bitrot detected in file:$test_dir/bitrotdir/dir2/bitrot.file" ]]
[[ ${lines[5]}   = "Recovering from bitrot with par2 files in $test_dir/bitrotdir/dir2/" ]]
[[ ${lines[6]}   = "Copying $BITROT_BACKUPS/${test_dir:1}/bitrotdir/dir2//files.par2 to ." ]]
[[ ${lines[7]}   = "Repairing bitrot files with par2repair" ]]
[[ ${lines[8]}   = "Launching bitrot -v after bitrot" ]]
[[ ${lines[9]}   = "Moving bitrot db files to $BITROT_BACKUPS/${test_dir:1}/bitrotdir" ]]
[[ ${lines[10]}  = "Done!" ]]
[[ -e bitrotdir/ ]]
[[ -e $BITROT_BACKUPS/${test_dir:1}/bitrotdir/dir2/files.par2 ]]
[[ -e $BITROT_BACKUPS/${test_dir:1}/bitrotdir/.bitrot.db ]]
[[ ! -e .bitrot* ]]
[[ ! -e bitrot/dir2/files.par2 ]]

}

@test "heal-bitrots detects a bitrot in bigger file and repair it in a tree dir" {
generate_bitrot bitrotdir/dir2/bitrot.file2 100 5


(( $status == 0 ))
[[ ${lines[1]}   = "Checking $test_dir/bitrotdir for bitrot" ]]
[[ ${lines[2]}   = "Copying bitrot db files to ." ]]
[[ ${lines[3]}   = "Launching bitrot -v" ]]
[[ ${lines[4]}   = "bitrot detected in file:$test_dir/bitrotdir/dir2/bitrot.file2" ]]
[[ ${lines[5]}   = "Recovering from bitrot with par2 files in $test_dir/bitrotdir/dir2/" ]]
[[ ${lines[6]}   = "Copying $BITROT_BACKUPS/${test_dir:1}/bitrotdir/dir2//files.par2 to ." ]]
[[ ${lines[7]}   = "Repairing bitrot files with par2repair" ]]
[[ ${lines[8]}   = "Launching bitrot -v after bitrot" ]]
[[ ${lines[9]}   = "Moving bitrot db files to $BITROT_BACKUPS/${test_dir:1}/bitrotdir" ]]
[[ ${lines[10]}  = "Done!" ]]
[[ -e bitrotdir/ ]]
[[ -e $BITROT_BACKUPS/${test_dir:1}/bitrotdir/dir2/files.par2 ]]
[[ -e $BITROT_BACKUPS/${test_dir:1}/bitrotdir/.bitrot.db ]]
[[ ! -e .bitrot* ]]
[[ ! -e bitrot/dir2/files.par2 ]]
}


@test "heal-bitrots detects two bitrots and repair them in a tree dir" {
generate_bitrots "bitrotdir/dir2b/bitrotb.file" "bitrotdir/dir2c/bitrotc.file" 10 2


(( $status == 0 ))
[[ ${lines[1]}   = "Checking $test_dir/bitrotdir/dir2b for bitrot" ]]
[[ ${lines[2]}   = "Copying bitrot db files to ." ]]
[[ ${lines[3]}   = "Launching bitrot -v" ]]
[[ ${lines[4]}   = "bitrot detected in file:$test_dir/bitrotdir/dir2b/bitrotb.file" ]]
[[ ${lines[5]}   = "Recovering from bitrot with par2 files in $test_dir/bitrotdir/dir2b/" ]]
[[ ${lines[6]}   = "Copying $BITROT_BACKUPS/${test_dir:1}/bitrotdir/dir2b//files.par2 to ." ]]
[[ ${lines[7]}   = "Repairing bitrot files with par2repair" ]]
[[ ${lines[8]}   = "Launching bitrot -v after bitrot" ]]
[[ ${lines[9]}   = "Moving bitrot db files to $BITROT_BACKUPS/${test_dir:1}/bitrotdir/dir2b" ]]
[[ ${lines[10]}  = "Done!" ]]
[[ ${lines[12]}  = "Checking $test_dir/bitrotdir/dir2c for bitrot" ]]
[[ ${lines[13]}  = "Copying bitrot db files to ." ]]
[[ ${lines[14]}  = "Launching bitrot -v" ]]
[[ ${lines[15]}  = "bitrot detected in file:$test_dir/bitrotdir/dir2c/bitrotc.file" ]]
[[ ${lines[16]}  = "Recovering from bitrot with par2 files in $test_dir/bitrotdir/dir2c/" ]]
[[ ${lines[17]}  = "Copying $BITROT_BACKUPS/${test_dir:1}/bitrotdir/dir2c//files.par2 to ." ]]
[[ ${lines[18]}  = "Repairing bitrot files with par2repair" ]]
[[ ${lines[19]}  = "Launching bitrot -v after bitrot" ]]
[[ ${lines[20]}  = "Moving bitrot db files to $BITROT_BACKUPS/${test_dir:1}/bitrotdir/dir2c" ]]
[[ ${lines[21]}  = "Done!" ]]
[[ -e bitrotdir/ ]]
[[ -e $BITROT_BACKUPS/${test_dir:1}/bitrotdir/dir2b/files.par2 ]]
[[ -e $BITROT_BACKUPS/${test_dir:1}/bitrotdir/dir2c/files.par2 ]]
[[ -e $BITROT_BACKUPS/${test_dir:1}/bitrotdir/dir2b/.bitrot.db ]]
[[ -e $BITROT_BACKUPS/${test_dir:1}/bitrotdir/dir2c/.bitrot.db ]]
[[ -e bitrotdir/dir2b ]]
[[ ! -e bitrotdir/dir2b/files.par2 ]]
[[ ! -e bitrotdir/dir2b/.bitrot.db ]]
[[ -e bitrotdir/dir2c ]]
[[ ! -e bitrotdir/dir2c/files.par2 ]]
[[ ! -e bitrotdir/dir2c/.bitrot.db ]]
}


@test "heal-bitrots detects several modifications in a tree dir" {
#create
date >> notemptydirs/dir2/new-file-a.txt
date >> notemptydirs/dir2/new-file-b.txt
run $r notemptydirs

(( $status == 0 ))
[[ ${lines[1]}   = "Checking $test_dir/notemptydirs for bitrot" ]]
[[ ${lines[2]}   = "Copying bitrot db files to ." ]]
[[ ${lines[3]}   = "Launching bitrot -v" ]]
[[ ${lines[4]}   = "change detected in:./dir2/new-file-a.txt" ]]
[[ ${lines[5]}   = "change detected in:./dir2/new-file-b.txt" ]]
[[ ${lines[6]}   = "launching generate_par2files in:./dir2/" ]]
[[ ${lines[8]}   = "Generating par2 files for $test_dir/notemptydirs/dir2" ]]
[[ ${lines[9]}   = "Change local directory to $test_dir/notemptydirs/dir2" ]]
[[ ${lines[10]}  = "Launching par2create " ]]
[[ ${lines[11]}  = "Moving par2 files to $BITROT_BACKUPS/${test_dir:1}/notemptydirs/dir2" ]]
[[ ${lines[12]}  = "Done!" ]]
[[ ${lines[13]}  = "Moving bitrot db files to $BITROT_BACKUPS/${test_dir:1}/notemptydirs" ]]
[[ ${lines[14]}  = "Done!" ]]
[[ -e notemptydirs/ ]]
[[ -e $BITROT_BACKUPS/${test_dir:1}/notemptydirs/dir2/files.par2 ]]
[[ -e $BITROT_BACKUPS/${test_dir:1}/notemptydirs/.bitrot.db ]]
[[ ! -e .bitrot* ]]
[[ ! -e notemptydirs/files.par2 ]]
[[ ! -e notemptydirs/.bitrot.db ]]

}

@test "heal-bitrots detects several different changes in a tree dir" {
#to not detect bitrot due same timestamp
sleep 1
#updated 
date >> notemptydirs/dir2/new-file-a.txt
#new
cp notemptydirs/dir2/new-file-b.txt notemptydirs/dir2/new-file-c.txt
#renamed
mv notemptydirs/dir2/new-file-b.txt notemptydirs/dir2/new-file-b2.txt
#missing
\rm -rf notemptydirs/dir1
run $r notemptydirs

# check_fail "${lines[@]}"

(( $status == 0 ))
[[ ${lines[1]}   = "Checking $test_dir/notemptydirs for bitrot" ]]
[[ ${lines[2]}   = "Copying bitrot db files to ." ]]
[[ ${lines[3]}   = "Launching bitrot -v" ]]
[[ ${lines[4]}   = "change detected in:./dir2/new-file-c.txt" ]]
[[ ${lines[5]}   = "change detected in:./dir2/new-file-a.txt" ]]
[[ ${lines[6]}   = "Move detected from:./dir2/new-file-b.txt to:./dir2/new-file-b2.txt" ]]
[[ ${lines[7]}   = "change detected in:./dir1/file1.txt" ]]
[[ ${lines[8]}   = "launching generate_par2files in:./dir1/" ]]
[[ ${lines[10]}  = "Generating par2 files for $test_dir/notemptydirs/dir1" ]]
[[ ${lines[11]}  = "$test_dir/notemptydirs/dir1 not a dir or not found" ]]
[[ ${lines[12]}  = "launching generate_par2files in:./dir2/" ]]
[[ ${lines[14]}  = "Generating par2 files for $test_dir/notemptydirs/dir2" ]]
[[ ${lines[15]}  = "Change local directory to $test_dir/notemptydirs/dir2" ]]
[[ ${lines[16]}  = "Launching par2create " ]]
[[ ${lines[17]}  = "Moving par2 files to $BITROT_BACKUPS/${test_dir:1}/notemptydirs/dir2" ]]
[[ ${lines[18]}  = "Done!" ]]
[[ ${lines[19]}  = "Moving bitrot db files to $BITROT_BACKUPS/${test_dir:1}/notemptydirs" ]]
[[ ${lines[20]}  = "Done!" ]]

}


@test "heal-bitrots detect 1 bitrot and cannot repair it cause redundancy >5% " {
#due to rounded numbers in bash must use >100 to work with >5%
generate_bitrot  "bitrotdir/moreredundancy/bigger.file" 100 6 

# check_fail "${lines[@]}"

(( $status == 1 ))
[[ ${lines[1]}   = "Checking $test_dir/bitrotdir for bitrot" ]]
[[ ${lines[2]}   = "Copying bitrot db files to ." ]]
[[ ${lines[3]}   = "Launching bitrot -v" ]]
[[ ${lines[4]}   = "bitrot detected in file:$test_dir/bitrotdir/moreredundancy/bigger.file" ]]
[[ ${lines[5]}   = "Recovering from bitrot with par2 files in $test_dir/bitrotdir/moreredundancy/" ]]
[[ ${lines[6]}   = "Copying $BITROT_BACKUPS/${test_dir:1}/bitrotdir/moreredundancy//files.par2 to ." ]]
[[ ${lines[7]}   = "Repairing bitrot files with par2repair" ]]
[[ ${lines[8]}   = "Moving bitrot db files to $BITROT_BACKUPS/${test_dir:1}/bitrotdir" ]]
[[ ${lines[9]}   = "Couldn't repair $test_dir/bitrotdir/moreredundancy/ with par2 files" ]]
[[ ${lines[10]}  = "See /tmp/.generate_bitrot_db.log, /tmp/.generate_par2_create.log or /tmp/.generate_par2_repair.log for errors." ]]

[[ -d bitrotdir/moreredundancy ]]
[[ -e $BITROT_BACKUPS/${test_dir:1}/bitrotdir/moreredundancy/files.par2 ]]
[[ -e $BITROT_BACKUPS/${test_dir:1}/bitrotdir/.bitrot.db ]]
[[ ! -e bitrotdir/moreredundancy/files.par2 ]]
[[ ! -e bitrotdir/.bitrot.db ]]

}

@test "heal-bitrots cannot work in BITROT_BACKUPS dir" {
run $r $BITROT_BACKUPS

(( $status == 0 ))
[[ ${lines[1]} = "Checking $BITROT_BACKUPS for bitrot" ]]
[[ ${lines[2]} = "$BITROT_BACKUPS is a subdir of $BITROT_BACKUPS. Next!." ]]
}

@test "heal-bitrots cannot work in BITROT_BACKUPS dir 2" {
run $r ${BITROT_BACKUPS}2

(( $status == 1 ))
[[ ${lines[1]} = "Checking ${BITROT_BACKUPS}2 for bitrot" ]]
[[ ${lines[2]} = "${BITROT_BACKUPS}2 not a dir or not found" ]]
}

@test "heal-bitrots cannot work in BITROT_BACKUPS subdir" {
mkdir -p ${BITROT_BACKUPS}/other
run $r ${BITROT_BACKUPS}/other

(( $status == 0 ))
[[ ${lines[1]} = "Checking $BITROT_BACKUPS/other for bitrot" ]]
[[ ${lines[2]} = "$BITROT_BACKUPS/other is a subdir of $BITROT_BACKUPS. Next!." ]]

}

@test "heal-bitrots cannot work in BITROT_BACKUPS subdir 2" {
mkdir -p ${BITROT_BACKUPS}/other/more/more 
run $r ${BITROT_BACKUPS}/other/more/more ${BITROT_BACKUPS}2

# check_fail "${lines[@]}"

(( $status == 1 ))
[[ ${lines[1]} = "Checking $BITROT_BACKUPS/other/more/more for bitrot" ]]
[[ ${lines[2]} = "$BITROT_BACKUPS/other/more/more is a subdir of $BITROT_BACKUPS. Next!." ]]
[[ ${lines[4]} = "Checking ${BITROT_BACKUPS}2 for bitrot" ]]
[[ ${lines[5]} = "${BITROT_BACKUPS}2 not a dir or not found" ]]

}

@test "heal-bitrots cannot operate cause more than 32768 files in a dir " {
skip
mkdir -p alotfiles/here; cd alotfiles/here
#create a 320KB file
dd if=/dev/zero of=masterfile bs=1 count=327680
#split it in 32768 files (instantly) + masterfile = 32769
split -b 10 -a 10 masterfile
cd $test_dir
run $r alotfiles/
# check_fail "${lines[@]}"

(( $status == 1 ))
}


@test "Clean everything" {
run chmod -f a+w *
\rm -rf * $test_dir $BITROT_BACKUPS
}

