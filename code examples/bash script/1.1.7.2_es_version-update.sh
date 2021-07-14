#!/bin/bash

. /home/earlysense/ENV.sh

PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/opt/bin

NUM_EVENT_FILES=10                                         # max most recent event files to backup
SCRIPT_VERSION=1.1
VERSION=1.1.7.2

prefs_xml=$ESHOMEPATH/.java/.userPrefs/BedSide/prefs.xml
cds_repository=/home/earlysense/pkg

if [ "$ISEZ" = "true" ]; then                              # INSIGHT

BACKUP_DIR=$ESHOMEPATH/sdcard/$VERSION/backup              # folders
repository=$ESHOMEPATH/sdcard/var/pkg/IS
upgrade_dir=$ESHOMEPATH/sdcard/upgrade                     # needed as var folder is not mounted by new zImage
var_dir=$ESHOMEPATH/sdcard/var

upgrade_ready_pkg=is-upgrade-ready.deb                     # files
backup_file=$BACKUP_DIR/backup.tar
zimage=zImage

uboot_cmds=update_uboot_cmds.txt                           # files : uboot
uboot_update=update_uboot.sh
new_uboot_img=new_u-boot.img                               # install updated uboot before an upgrade
uboot_setenv=fw_setenv

nand_zImage_var_som_am33_dtb=zImage-var-som-am33.dtb       # files : nand
nand_tar=is-img-thin.tar.gz
nand_u_boot_img=u-boot.img
nand_ubi_img=nand-ubi.img
nand_zImage=nand_zImage
nand_MLO=MLO

else                                                       # BEDSIDE

USB=$ESHOMEPATH/usb
BACKUP_DIR=$USB/$VERSION/backup                            # folders
repository=$ESHOMEPATH/pkg/BS
var_dir=$ESHOMEPATH/var

upgrade_ready_pkg=bs-upgrade-ready.deb                     # files
backup_file=$ESHOMEPATH/var/backup.tar
initrd=initrd.img-4.9.0
bs_img=bs.img.zip

mounted_usb=false                                          # defines log location
password=1104                                              # to encrypt backup file on external USB

fi

###########################################################
#                     C O M M O N
###########################################################

clear_repository() {
    rm -rf $repository
}

set_log_file() {
    if [ "$ISEZ" = "false" ]; then
        [ "$mounted_usb" = "true" ] && logfile=$USB/$VERSION/upgrade.log || logfile=$ESHOMEPATH/var/upgrade.log
    else
        logfile=$ESHOMEPATH/sdcard/$VERSION/upgrade.log
    fi
}

LOG_OK() {
    #echo -e $1
    set_log_file
    echo -e "$(date) [  OK  ] $1" >> $logfile ; sync
}

LOG_FAIL() {
    #echo -e $1
    set_log_file
    echo -e "$(date) [ FAIL ] $1" >> $logfile
    umount $USB &> /dev/null
    clear_repository
    exit 1
}

###########################################################
#                     I N S I G H T
###########################################################

#
# upgrade types
#
# tt   : files in local repo
# cds  : files on cds
#
check_integrity_is() {
    [ ! -f $repository/$zimage ] && {
        LOG_OK "get files from CDS"
        mkdir $repository && LOG_OK "$repository folder created" || LOG_FAIL "failed to create $repository"
        CDSIP=$(awk -F'"' '($2=="ESCDS_IP") {print $4; exit}' $ESHOMEPATH/.java/.userPrefs/BedSide/prefs.xml)
        [ ! -z $CDSIP ] && LOG_OK "CDS IP [$CDSIP]" || LOG_FAIL "failed to get CDSIP"
        scp earlysense@$CDSIP:"$cds_repository/IS/$zimage                              \
                                $cds_repository/IS/$upgrade_ready_pkg                  \
                                $cds_repository/IS/uboot/$uboot_setenv                 \
                                $cds_repository/IS/uboot/$new_uboot_img                \
                                $cds_repository/IS/uboot/$uboot_update                 \
                                $cds_repository/IS/uboot/$uboot_cmds                   \
                                $cds_repository/IS/nand/$nand_tar"                     \
                                $repository

        # uboot
        mkdir $repository/uboot && LOG_OK "$repository/uboot folder created" || LOG_FAIL "failed to create $repository/uboot"
        mv $repository/$uboot_setenv $repository/$uboot_update $repository/$uboot_cmds $repository/$new_uboot_img $repository/uboot/.
        # nand
        mkdir $repository/nand && LOG_OK "$repository/nand folder created" || LOG_FAIL "failed to create $repository/nand"
        chown root:root $repository/$nand_tar
        mv $repository/$nand_tar $repository/nand/. 
    }

    #
    #  /home/earlysense/sdcard/var is not mounted under new zImage, thus copy to permanent location
    #
    mkdir -p $upgrade_dir/nand && LOG_OK "$upgrade_dir/nand folder created" || LOG_FAIL "failed to create $upgrade_dir/nand"
    #
    #  put zImage (Trego) into SD card root and not into folder
    #+ for some reason kernel might fail to read newly created folder
    #
    chown root:root $repository/$zimage
    mv $repository/$zimage $ESHOMEPATH/sdcard/.
    mv $repository/nand/$nand_tar $upgrade_dir/nand/.
    tar xvf $upgrade_dir/nand/$nand_tar -C $upgrade_dir/nand || LOG_OK "$nand_tar extacted to $upgrade_dir/nand" || LOG_FAIL "failed to extract $nand_tar to $upgrade_dir/nand"
    rm -f $upgrade_dir/$nand_tar

    # uboot
    [ ! -f $repository/uboot/$new_uboot_img ] && LOG_FAIL "$repository/uboot/$new_uboot_img not found"
    [ ! -f $repository/uboot/$uboot_setenv ] && LOG_FAIL "$repository/uboot/$uboot_setenv not found"
    [ ! -f $repository/uboot/$uboot_update ] && LOG_FAIL "$repository/uboot/$uboot_update not found"
    [ ! -f $repository/uboot/$uboot_cmds ] && LOG_FAIL "$repository/uboot/$uboot_cmds not found"

    # nand
    [ ! -f $upgrade_dir/nand/$nand_zImage_var_som_am33_dtb ] && LOG_FAIL "$upgrade_dir/nand/$nand_zImage_var_som_am33_dtb not found"
    [ ! -f $upgrade_dir/nand/$nand_u_boot_img ] && LOG_FAIL "$upgrade_dir/nand/$nand_u_boot_img not found"
    [ ! -f $upgrade_dir/nand/$nand_ubi_img ] && LOG_FAIL "$upgrade_dir/nand/$nand_ubi_img not found"
    [ ! -f $upgrade_dir/nand/$nand_MLO ] && LOG_FAIL "$upgrade_dir/nand/$nand_MLO not found"
    [ ! -f $upgrade_dir/nand/$zimage ] && LOG_FAIL "$upgrade_dir/nand/$zimage not found"
    
    # 1.1.7.2
    [ ! -f $repository/$upgrade_ready_pkg ] && LOG_FAIL "$repository/$upgrade_ready_pkg not found"
    [ ! -f $ESHOMEPATH/sdcard/$zimage ] && LOG_FAIL "$ESHOMEPATH/sdcard/$zimage not found"
    LOG_OK "integrity check ok"
}

#
# in case of error run twice (by Trego)
#
run_uboot() {
    #
    # install updated uboot
    #
    flash_erase /dev/mtd5 0 0 > /dev/null
    flash_erase /dev/mtd6 0 0 > /dev/null
    flash_erase /dev/mtd7 0 0 > /dev/null
    nandwrite -p /dev/mtd5 $repository/uboot/$new_uboot_img > /dev/null
    #
    # set configuration after installing
    #
    chmod +x $repository/uboot/$uboot_update || true
    $repository/uboot/$uboot_update || true
    $repository/uboot/$uboot_update || true
    LOG_OK "uboot configuration updated"
}

###########################################################
#                     B E D S I D E
###########################################################

power_usb() {
    local USBENB="\xAA\x07\x57\x01\x10\x01\x01\x1A\xCC"
    local USBDIS="\xAA\x07\x57\x01\x10\x00\x01\x19\xCC"
    [ "$1" = "OFF" ] && USBENB="$USBDIS"

    local stty=/bin/stty
    $stty -F /dev/ttyS2 ospeed 57600 ispeed 57600 cs8 -parenb cstopb
    echo -ne "${USBENB}" > /dev/ttyS2
    sleep 5
}

#
# upgrade types
#
# local: files in local repo
# cds  : files on cds
#
check_integrity_bs() {
    [ ! -f $repository/$initrd ] && {
        LOG_OK "get files from CDS"
        mkdir $repository && LOG_OK "$repository folder created" || LOG_FAIL "failed to create $repository"
        CDSIP=$(awk -F'"' '($2=="ESCDS_IP") {print $4; exit}' $ESHOMEPATH/.java/.userPrefs/BedSide/prefs.xml)
        [ ! -z $CDSIP ] && LOG_OK "CDS IP [$CDSIP]" || LOG_FAIL "failed to get CDSIP"
        scp earlysense@$CDSIP:"$cds_repository/BS/$upgrade_ready_pkg  \
                                $cds_repository/BS/$initrd"           \
                                $repository
    }

    [ ! -f $repository/$upgrade_ready_pkg ] && LOG_FAIL "$repository/$upgrade_ready_pkg not found"
    [ ! -f $USB/$bs_img ] && LOG_FAIL "$USB/$bs_img not found"
    [ ! -f $repository/$initrd ] && LOG_FAIL "$repository/$initrd not found"
    LOG_OK "integrity check ok"
}

replace_initrd() {
    cp $repository/$initrd /boot/. && LOG_OK "$initrd replaced" || LOG_FAIL "failed to replace $initrd"
}

#
# FIPS configuration in /home/earlysense/BedSide/prefs.xml cannot be trusted
# check /proc/cmdline and update FIPS parameter accordingly before backup
# Note: FIPS=0 means enabled in 1.1.7
#
handle_fips_configuration() {
    fips_enabled=$(cat /proc/cmdline | grep fips=1 | wc -l)
    if [ "$fips_enabled" = "1" ]; then
        sed -i '/key="FIPS"/c\  <entry key="FIPS" value="0"/>' $prefs_xml
        LOG_OK "fips enabled. update $prefs_xml"
    fi
}

###########################################################
#                     M A I N
###########################################################

#
# prepare log file
#
if [ "$ISEZ" = "false" ]; then                             # BEDSIDE
    rm -f $ESHOMEPATH/var/upgrade.log
    power_usb ON && LOG_OK "usb powered on"
    umount $USB &> /dev/null
    mount /dev/disk/by-id/usb*part1 $USB && LOG_OK "usb mounted" || LOG_FAIL "usb mount failed"
    sleep 5
else                                                       # INSIGHT
    rm -f $ESHOMEPATH/sdcard/var/$VERSION/upgrade.log
fi

#
# prepare backup folder
#
[ -d $BACKUP_DIR ] || {
    mkdir -p $BACKUP_DIR && LOG_OK "$BACKUP_DIR created" || LOG_FAIL "failed to create $BACKUP_DIR"
}
LOG_OK "$BACKUP_DIR ready"
mounted_usb=true                                           # now logs may go to backup folder

[ "$ISEZ" = "true" ] && name=IS || name=BS
LOG_OK "=== [$VERSION] Prepare $name for upgrade to 1.1.9-1 (v$SCRIPT_VERSION)"

LOG_OK "user [$(id)]"
#
# check integrity
#
[ "$ISEZ" = "true" ] && check_integrity_is || check_integrity_bs

#
# check version
#
major_version=${ESVERSION:0:5}
[ "$major_version" = "03.17" ] && LOG_OK "version $ESVERSION" || LOG_FAIL "upgrade from version $ESVERSION is not supported"

#
# rotate backup file if already exists
#
if [ -f $backup_file ]; then
    ip=$(ip addr | grep 'state UP' -A2 | tail -n1 | awk '{print $2}' | cut -f1  -d'/')
    timestamp=$(date "+%Y.%m.%d-%H.%M.%S")
    mv $backup_file{,-$ip-$timestamp} && LOG_OK "moved $backup_file to $backup_file-$ip-$timestamp" || LOG_FAIL "failed to move $backup_file to $backup_file-$ip-$timestamp"
fi

#
# prepare list of files to backup
#
backup_list=(
    /home/earlysense/.java/.userPrefs/BedSide/prefs.xml
    /home/earlysense/NetworkSetup.txt
    /home/earlysense/.ModifiedWpa
    /home/earlysense/calib_tmp
    /home/earlysense/certs.zip
    /etc/wpa_supplicant.conf
    /etc/network/interfaces
    /home/earlysense/cert
    $var_dir/Syslog.log
    /etc/timezone
)

#
# prepare list of recent event files
#
recent_dir_by_time=$(ls $var_dir | grep "^20" | awk -F '_' '{print $1 "_" $2}' | sort | tail -n 1)
event_files=$(find / | grep ${recent_dir_by_time} | grep "event_log_" | sort | tail -n ${NUM_EVENT_FILES})
LOG_OK "event files to backup:"
for file in $event_files; do
    LOG_OK $file
done

#
# handle fips configuration on BEDSIDE
#
[ "$ISEZ" = "false" ] && handle_fips_configuration

#
#  create backup file
#+ tar may fail if event log file is being written at the moment
#+ try 10 times or until success. Syslog.log keeps updating so stop rsyslog
#+ just before backup
#
service rsyslog stop
LOG_OK 'rsyslog has been stopped'

tar_flags="--ignore-failed-read -cf"

i=0 ; exit_status=1
while [ $i -lt 10 -a $exit_status -ne 0 ]; do
    tar $tar_flags $backup_file ${backup_list[*]} $event_files
    exit_status=$? ; sleep 1 ; ((i++))
done
[ $exit_status -eq 0 ] && LOG_OK "backup done to $backup_file [attempt#$i]" || {
    service rsyslog start
    LOG_OK 'rsyslog has been started'
    LOG_FAIL "failed to archive files [attempts#$i]"
}

service rsyslog start
LOG_OK 'rsyslog has been started'

#
# encrypt backup before copy to usb
# Note: same PASSWORD should be used for decryption
#
if [ "$ISEZ" = "false" ]; then
    gpg --yes --batch --passphrase=$password -c $backup_file && LOG_OK "$backup_file ecrypted to $backup_file.gpg" || LOG_FAIL "failed to encrypt $backup_file"
    rm -f $backup_file
    mv $backup_file.gpg $BACKUP_DIR && LOG_OK "$backup_file.gpg moved to $BACKUP_DIR" || LOG_FAIL "failed to move $backup_file.gpg file to $BACKUP_DIR"
fi

#
# make changes to the system
#
[ "$ISEZ" = "true" ] && run_uboot || replace_initrd

#
# install 1.1.7.2 package to mark success
#
dpkg -i $repository/$upgrade_ready_pkg && LOG_OK "$repository/$upgrade_ready_pkg installed" || LOG_OK "failed to install $repository/$upgrade_ready_pkg"

LOG_OK "=== [$VERSION] Prepare completed"

umount $USB &> /dev/null                                   # make sure logs saved

[ "$ISEZ" = "false" ] && power_usb OFF

clear_repository
reboot

