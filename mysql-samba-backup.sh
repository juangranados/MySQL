#!/bin/bash

SERVER_IP="172.28.0.204"		# IP of Samba server
SHARE_NAME="Backups/webmora/mysql"	# Share folder
USR_NAME="user"				# Samba user
USR_PASSWORD="Pa$$w0rd"			# Samba password
DOMAIN="contoso.local"			# Domain
MOUNT_POINT="/mnt/backup"		# Path where mount. Must exist
MYSQL_USER="root"			# Mysql user to backup Databases
MYSQL_PASS="Pa$$w0rd"			# Mysql pass
MAX_AGE="8"				# Days to keep backups
LOGFILE="/var/log/mysql-backup.log"	# Log 
EMAIL="jgranados@mail.com"		# Email to send log
DATE=`date +%d-%m-%y_%H-%M`		# Date format to append to the file backup


GZIP="$(which gzip)"
MYSQL="$(which mysql)"
MYSQLDUMP="$(which mysqldump)"

# Create a new log
rm -rf $LOGFILE
touch $LOGFILE

echo "Backup mysql $HOSTNAME from user $MYSQL_USER on $(date +%d-%m-%y) at $(date +%H:%M)." >> $LOGFILE

# Mount samba share
mount //$SERVER_IP/$SHARE_NAME -o username=$USR_NAME,password=$USR_PASSWORD,dom=$DOMAIN $MOUNT_POINT >> $LOGFILE

# if mount is success continue backup
if grep -qs $MOUNT_POINT /proc/mounts; then

	# Remove backups older than MAX_AGE days
	find $MOUNT_POINT -name "*.gz" -mtime +$MAX_AGE -exec rm -rf {} \;
	
	# get a list of databases
	DATABASES=`$MYSQL --user=$MYSQL_USER --password=$MYSQL_PASS -e "SHOW DATABASES;" | tr -d "| " | grep -v Database`

	# dump each database in turn
	for DB in $DATABASES; do

		FILE=${MOUNT_POINT}/mysql-$DB-$DATE.gz
    		echo Save database $DB as $FILE. >> $LOGFILE
    		$MYSQLDUMP --single-transaction --user=$MYSQL_USER --password=$MYSQL_PASS --databases $DB | $GZIP -9 > $FILE
	
	done
	
	#umount samba share
	umount -f $MOUNT_POINT

# Can not mount samba share. Exiting
else
    	 echo "Can not mount //$SERVER_IP/$SHARE_NAME. Aborting backup." >> $LOGFILE
fi

#Send result email

cat $LOGFILE | mail -s "Backup mysql $HOSTNAME from user $MYSQL_USER" $EMAIL
