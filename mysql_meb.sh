#!/bin/sh

usage()
{
    echo "
Usage: `basename $0` [command] [MEB options]

Commands:
    full                                make full backup
    incremental                         make incremental backup
    incremental-with-redo-log-only      make incremental backup with redo log only
    binlog                              verify backup images, then copy to tape
    remove-old                          remove old backups
    conf                                configuration
    upload                              upload new back to servers
    "
}

# creates defaults values
initialize()
{
    CURDATE=`date +%Y%m%d%H%M%S`
    LOGDATE=`date +'%Y%m'`
    dUSERNAME=mysqlback
    dPASSWORD=mysqlbackup#20171211
    dNUB_ENABLE=0
    dBACKUPHOME=`pwd`/mysql_backup
    dBACKUPDIR=$dBACKUPHOME/full
    dINCREMENTALDIR=$dBACKUPHOME/incremental
    dBINLOGDIR=$dBACKUPHOME/binlog
    dPREPAREDDIR=$dBACKUPHOME/preparedir
    dLOGDIR=$dBACKUPHOME/log
    dCONFDIR=$dBACKUPHOME/conf
    dBACKUPIMAGENAME=backup
    dOUTLOG=backup_output.log
    dERRORLOG=backup_error.log
    dBPLOG=nublist.log
    dREMOVELOG=move.log
    dMYSQLBACKUP=`find / -path "*/meb-*/bin/mysqlbackup"`

    mSOCKET=/var/lib/mysql/mysql.sock
    nproc=`ps -ef|grep "mysqld "|grep -v grep|grep socket |wc -l`
    if [ 0 -eq $nproc ];then
      if test -f $mSOCKET;then
        dSOCKET=$mSOCKET
      else
        echo "$(date +'%Y-%m-%d %H:%M:%S') ERROR: mysqld not have a socket!" >>${dLOGDIR}/${dERRORLOG}.${LOGDATE}
        exit 1;
      fi
    else
      dSOCKET=`ps -ef|grep "mysqld "|grep -v grep|grep socket|awk -F'--socket=' '{print $2}'|awk '{print $1}'`
    fi

    dBINLOGINDEX=`mysql -u${dUSERNAME} -p${dPASSWORD} -S ${dSOCKET} -e "show variables like 'log_bin_index';" -N |awk '{print $2}'`
    dPARALLELNUM=1
    dVERIFYTIME=2
    dREMOVETIME=1
    dCLEANUP=0
}

#parses options
parse_options()
{
    if [ -z "$1" ]
    then
        usage
        exit 1
    fi
    case $1 in
    full)                                  COMMAND=do_full;;
    incremental)                           COMMAND=do_incremental;;
    binlog)                                COMMAND=do_binlog;;
        conf)                                  COMMAND=build_config_file;;
    remove-old)                            COMMAND="do_remove_old $2";;
    upload)                                COMMAND="upload $2";;
    *)                                     usage; exit 1;;
    esac
#    shift
}

Check_environment()
{
        #setting new files
    if test ! -d $dBACKUPHOME;then
       mkdir ${dBACKUPHOME}
    fi
    if test ! -d ${dBACKUPDIR};then
       mkdir ${dBACKUPDIR}
    fi
    if test ! -d ${dINCREMENTALDIR};then
       mkdir ${dINCREMENTALDIR}
    fi
    if test ! -d ${dBINLOGDIR};then
       mkdir ${dBINLOGDIR}
    fi
    if test ! -d ${dPREPAREDDIR};then
       mkdir ${dPREPAREDDIR}
    fi
    if test ! -d ${dLOGDIR};then
       mkdir ${dLOGDIR}
    fi
    if test ! -d ${dCONFDIR};then
       mkdir ${dCONFDIR}
    fi

    #setting environment variables
    if [ -z $USERNAME ]
    then
        USERNAME=${dUSERNAME}
    fi
    if [ -z $PASSWORD ]
    then
        PASSWORD=${dPASSWORD}
    fi
    if [ -z $SOCKET ]
    then
        SOCKET=${dSOCKET}
    fi
        if [ -z $NUB_ENABLE ]
    then
        NUB_ENABLE=${dNUB_ENABLE}
    fi
    if [ -z $MYSQLBACKUP ]
    then
        MYSQLBACKUP=$dMYSQLBACKUP
    fi
    if [ -z $BACKUPDIR ]
    then
        BACKUPDIR=${dBACKUPDIR}
    fi
    if [ -z $INCREMENTALDIR ]
    then
        INCREMENTALDIR=${dINCREMENTALDIR}
    fi
    if [ -z $LOGDIR ]
    then
        LOGDIR=$dLOGDIR
    fi
    if [ -z $BACKUPIMAGENAME ]
    then
        BACKUPIMAGENAME=${dBACKUPIMAGENAME}.${CURDATE}.bki
    fi
    if [ -z $OUTLOG ]
    then
        OUTLOG=${dOUTLOG}.${LOGDATE}
    fi
    if [ -z $ERRORLOG ]
    then
        ERRORLOG=${dERRORLOG}.${LOGDATE}
    fi
    if [ -z $BPLOG ]
    then
        BPLOG=${dBPLOG}.${LOGDATE}
    fi
    if [ -z $REMOVELOG ]
    then
       REMOVELOG=${dREMOVELOG}.${LOGDATE}
    fi
    if [ -z $VERIFYTIME ]
    then
        VERIFYTIME=$dVERIFYTIME
    fi
    if [ -z $PARALLELNUM ]
    then
        PARALLELNUM=$dPARALLELNUM
    fi
    if [ -z $REMOVETIME ]
    then
        REMOVETIME=$dREMOVETIME
    fi
    if [ -z $CLEANUP ]
    then
        CLEANUP=$dCLEANUP
    fi
    if [ -z $BINLOGINDEX ]
    then
        BINLOGINDEX=$dBINLOGINDEX
    fi
    if [ -z $BINLOGDIR ]
    then
        BINLOGDIR=$dBINLOGDIR
    fi
}

build_config_file()
{
    dir=${dBACKUPHOME}/..
    CONFLOG=conf.log.${LOGDATE}
    NUM=`ps -ef |grep mysqld_safe |grep -v grep|grep "defaults-file="|wc -l`
    if [ 1 -eq $NUM ];then
            out_event="copy mysql configuration"
        dMYSQL_CONF=`ps -ef|grep mysqld_safe|grep -v grep|grep "defaults-file"|awk -F'--defaults-file=' '{print $2}'|awk '{print $1}'`
                cp -f ${dMYSQL_CONF} $dCONFDIR/my.cnf
                cleanup ${CONFLOG}
    else
       ${dir}/mysql_conf ${dCONFDIR} >> ${LOGDIR}/${CONFLOG}
        fi
}

#cleans up failed backups
cleanup()
{
    result=$?
    output=$out_event
    if [[ 0 -ne $result ]]
    then
        echo "$(date +'%Y-%m-%d %H:%M:%S') ERROR: ${output} failed!" >> $LOGDIR/$ERRORLOG
        exit 1
    else
        echo "[info] $(date +'%Y-%m-%d %H:%M:%S') ${output} sucessful!"  >> $LOGDIR/$1
    fi
}

#makes full backup
do_full()
{
    out_event="full backup"
    echo "[info] $(date +'%Y-%m-%d %H:%M:%S') A Full backup begin........." >> $LOGDIR/$OUTLOG
    echo "$(date +'%Y-%m-%d %H:%M:%S') $MYSQLBACKUP --user=${USERNAME} --password=${PASSWORD} --socket=${SOCKET} --backup-dir=$BACKUPDIR/${CURDATE}  --backup-image=$BACKUPDIR/$BACKUPIMAGENAME backup-to-image" >>$LOGDIR/$OUTLOG
    $MYSQLBACKUP  --user=${USERNAME} --password=${PASSWORD} --socket=${SOCKET} --backup-dir=$BACKUPDIR/${CURDATE} --skip-binlog  --backup-image=$BACKUPDIR/$BACKUPIMAGENAME backup-to-image
    cleanup ${OUTLOG}
}

#makes incremental backup
do_incremental()
{
    out_event="incremental backup"
    echo "[info] $(date +'%Y-%m-%d %H:%M:%S') incremental backup begin" >> $LOGDIR/$OUTLOG
    echo "$(date +'%Y-%m-%d %H:%M:%S') $MYSQLBACKUP --user=${USERNAME} --password=${PASSWORD} --socket=${SOCKET} --incremental-base=history:last_backup --backup-dir=${INCREMENTALDIR}/${CURDATE} --backup-image=${INCREMENTALDIR}/${BACKUPIMAGENAME} --skip-binlog --skip-relaylog --incremental backup-to-image" >>$LOGDIR/$OUTLOG
    $MYSQLBACKUP --user=$USERNAME --password=$PASSWORD --socket=${SOCKET} --incremental-base=history:last_backup --backup-dir=$INCREMENTALDIR/${CURDATE} --backup-image=$INCREMENTALDIR/$BACKUPIMAGENAME --skip-binlog --skip-relaylog --incremental backup-to-image
    cleanup ${OUTLOG}
}

do_binlog()
{
    echo "[info] ${CURDATE} binary log backup begin" >$LOGDIR/$OUTLOG 2>>$LOGDIR/$ERRORLOG
    binlog_lst=`echo ${BINLOGINDEX} | awk -F. '{print $1}'` >$LOGDIR/$OUTLOG 2>>$LOGDIR/$ERRORLOG
    last_binlog=`cat $BINLOGINDEX |tail -1` >$LOGDIR/$OUTLOG 2>>$LOGDIR/$ERRORLOG
    rm -f $BINLOGDIR/`echo ${last_binlog}|awk -F/ '{print $NF}'` >$LOGDIR/$OUTLOG 2>>$LOGDIR/$ERRORLOG
}

do_remove_old()
{
  REMOVEDIR=${dBACKUPHOME}/$1
  R_movedir=${dBACKUPHOME}/oldback
  DATE=`date +'%Y%m%d'`
  out_event="move new backup to old file"
  echo "$(date +'%Y-%m-%d %H:%M:%S') try to move the newback to oldback..." >> ${LOGDIR}/${REMOVELOG}
  move_files=`find ${REMOVEDIR} -maxdepth 1 -mindepth 1|grep ${DATE}`
  move_files_nub=`find $REMOVEDIR -maxdepth 1 -mindepth 1|grep ${DATE}|wc -l`
  `echo "$(date +'%Y-%m-%d %H:%M:%S') $move_files" >> ${LOGDIR}/${REMOVELOG}`
  if [ 0 -ne ${move_files_nub}0 ]
  then
     mv ${move_files} ${R_movedir}
     cleanup ${REMOVELOG}
  fi
}

upload()
{
 hostname=`hostname`
 BAK_PATH=${dBACKUPHOME}/$1
 bpdir=`find / -name bpbackup`
 if [ -z $2 ];then
     bp_DBname=DB_MYSQL_TEST1
 elif [ 1 -eq $2 ];then
     echo "the back do not to upload!" >>$LOGDIR/${BPLOG}
     return 0
 else
     bp_DBname=$2
 fi
  echo "$(date +'%Y-%m-%d %H:%M:%S') a upload eventtime beginning ....." >> ${LOGDIR}/${BPLOG}
  echo "$(date +'%Y-%m-%d %H:%M:%S') $bpdir -p \"DB_MYSQL_TEST1\" -t 0 -s \"User_teastore\" -S \"backup_server\" -h ${hostname} -w ${BAK_PATH}" >>${LOGDIR}/${BPLOG}
  $bpdir -p "${bp_DBname}" -t 0 -s "User_teastore" -S "backup_server" -h ${hostname} -w ${BAK_PATH}
  if [ 0 -ne $? ]
  then
      echo "$(date +'%Y-%m-%d %H:%M:%S') ERROR: backup upload failed!" >> $LOGDIR/$ERRORLOG
          exit 1
  else
      echo "[info] $(date +'%Y-%m-%d %H:%M:%S') backup upload sucessful!" >> $LOGDIR/${BPLOG}
  fi
}

initialize
Check_environment
parse_options $@
$COMMAND
if [ "full" = "$1" ] || [ "incremental" = "$1" ];then
     upload $@
     do_remove_old $1
fi
exit 0