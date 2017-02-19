# heal-bitrots

Autodetect and self repair damaged files from bitrot in any FS without using btrfs or zfs. :)

WARNING: It's still beta until I can trust it to my $HOME folders for sure and good I reckon it'll be soon. ;)


#Install

```bash
git clone https://github.com/liloman/heal-bitrots
cd heal-bitrots/
./heal-bitrots.sh /yourdir /anothedir
```

Requires:

```bash
pip install --user bitrot
dnf/apt/pacman/x install par2cmdline
```

Systemd daemon coming soon with notify of bitrot detection.

#Use

Specify a list of dir to check for backup or configure or set the file BITROT_BACKUPS_DEST (~/.bitrot_backups/bitrot_dirs by default) with a line for each dir you want to check for bitrots:


```bash
./heal-bitrots.sh /yourdir /anothedir
#or (set BITROT_BACKUPS_DEST with a line for each dir you want to check for bitrots)
./heal-bitrots.sh 
```

If you want to change the default destination for your recovery files (5% percent of size) set it after launch:

```bash
export BITROT_BACKUPS=~/mycloudprovider/bitrot_backups
export BITROT_BACKUPS_DEST=~/bitrot_dirs.conf
./heal-bitrots.sh  ...
```

Paranoids should keep the BITROT_BACKUPS dir synced/cloned for bitrot damage. ;)

You should launch it each week with a low priority.


#Spec

It's based on:

- [bitrot](https://github.com/ambv/bitrot/)
- [par2cmdline](https://github.com/Parchive/par2cmdline)

For each dir you configure/pass along it will use bitrot to create a root db to detect any bitrot in that dir and its subdirs.After it will create the necessary par2 files to recovery from any bitrot with par2cmdline with the files of each subdir. Everything will be saved into the $BITROT_BACKUPS dir.

There are tests written with [bats](https://github.com/sstephenson/bats), so just:

```bash
#bats tests/
 ✓ heal-bitrots without arguments. warning about target paths
 ✓ heal-bitrots dirnotfound shows dir not found
 ✓ heal-bitrots with multiple notfounddirs shows dir not found
 ✓ heal-bitrots in a file shows not a dir
 ✓ heal-bitrots in a empty dir doesn't fail
 ✓ heal-bitrots in a empty dir doesn't fail with relative path
 ✓ heal-bitrots in a not empty dir create everything
 ✓ heal-bitrots in a not empty dir without changes
 ✓ heal-bitrots in a not empty tree dir create the recovery tree in backups
 ✓ heal-bitrots in two not empties trees dir create the recovery trees in backups
 ✓ heal-bitrots detects new files in a tree dir
 ✓ heal-bitrots detects a modified file in a tree dir
 ✓ heal-bitrots detects a deleted file in a tree dir
 ✓ heal-bitrots detects a bitrot and repair it in a tree dir
 ✓ heal-bitrots detects a bitrot in bigger file and repair it in a tree dir
 ✓ heal-bitrots detects two bitrots and repair them in a tree dir
 ✓ heal-bitrots detects several modifications in a tree dir
 ✓ heal-bitrots detects several different changes in a tree dir
 ✓ heal-bitrots detect 1 bitrot and cannot repair it cause redundancy >5%
 ✓ heal-bitrots cannot work in BITROT_BACKUPS dir
 ✓ heal-bitrots cannot work in BITROT_BACKUPS dir 2
 ✓ heal-bitrots cannot work in BITROT_BACKUPS subdir
 ✓ heal-bitrots cannot work in BITROT_BACKUPS subdir 2
 - heal-bitrots cannot operate cause more than 32768 files in a dir  (skipped)
 ✓ Clean everything
25 tests, 0 failures, 1 skipped
#
```


#TODO

- [ ] Integrate par2recovery -B option to recovery when include in Fedora mainstream
- [ ] Database of false positive files like sqlite-shm ...
- [ ] Systemd daemon with bitrot notification
- [ ] Fedora/Debian/... packages
- [ ] S.M.A.R.T checks ...

