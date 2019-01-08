#!/bin/bash
#xtrabackup mysql

#mysql info
USER=""
PASSWORD=""

#week info
week=`date -R | awk -F "," '{print $1}'`

#full_backuped datadir
datadir=backup`date +%Y-%m-%d`

case $week in
Mon)
        last_sunday_datadir=backup`date -d"1 day ago" +%Y-%m-%d`
	/usr/bin/innobackupex --defaults-file=/data/mysql3306/etc/my.cnf --parallel=16 --user=$USER --password=$PASSWORD --no-timestamp --compress --compress-threads=4 --incremental /data/backup/$datadir --incremental-basedir=/data/backup/$last_sunday_datadir;;
Tue)
        last_sunday_datadir=backup`date -d"2 day ago" +%Y-%m-%d`
	/usr/bin/innobackupex --defaults-file=/data/mysql3306/etc/my.cnf --parallel=16 --user=$USER --password=$PASSWORD --no-timestamp --compress --compress-threads=4 --incremental /data/backup/$datadir --incremental-basedir=/data/backup/$last_sunday_datadir;;
Wed)
        last_sunday_datadir=backup`date -d"3 day ago" +%Y-%m-%d`
	/usr/bin/innobackupex --defaults-file=/data/mysql3306/etc/my.cnf --parallel=16 --user=$USER --password=$PASSWORD --no-timestamp --compress --compress-threads=4 --incremental /data/backup/$datadir --incremental-basedir=/data/backup/$last_sunday_datadir;;
Thu)
        last_sunday_datadir=backup`date -d"4 day ago" +%Y-%m-%d`
	/usr/bin/innobackupex --defaults-file=/data/mysql3306/etc/my.cnf --parallel=16 --user=$USER --password=$PASSWORD --no-timestamp --compress --compress-threads=4 --incremental /data/backup/$datadir --incremental-basedir=/data/backup/$last_sunday_datadir;;
Fri)
        last_sunday_datadir=backup`date -d"5 day ago" +%Y-%m-%d`
	/usr/bin/innobackupex --defaults-file=/data/mysql3306/etc/my.cnf --parallel=16 --user=$USER --password=$PASSWORD --no-timestamp --compress --compress-threads=4 --incremental /data/backup/$datadir --incremental-basedir=/data/backup/$last_sunday_datadir;;
Sat)
        last_sunday_datadir=backup`date -d"6 day ago" +%Y-%m-%d`
	/usr/bin/innobackupex --defaults-file=/data/mysql3306/etc/my.cnf --parallel=16 --user=$USER --password=$PASSWORD --no-timestamp --compress --compress-threads=4 --incremental /data/backup/$datadir --incremental-basedir=/data/backup/$last_sunday_datadir;;
Sun)
	/usr/bin/innobackupex --defaults-file=/data/mysql3306/etc/my.cnf --parallel=16 --user=$USER --password=$PASSWORD --no-timestamp --compress --compress-threads=4 /data/backup/$datadir;;
esac