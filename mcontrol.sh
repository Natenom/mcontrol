#!/bin/bash
# Website: http://wiki.natenom.name/minecraft/mcontrol
# Version 0.0.11 - 2012-02-23
# Natenom natenom@natenom.name
# License: Attribution-NonCommercial-ShareAlike 3.0 Unported
#
# Based on Script taken from http://www.minecraftwiki.net/wiki/Server_startup_script version 0.3.2 2011-01-27 (YYYY-MM-DD)
# Original License: Attribution-NonCommercial-ShareAlike 3.0 Unported
############# Settings #####################
# Default backup system, if not specified in serversettings.
# Can be "tar" or "rdiff"
# Be sure to install rdiff-backup http://www.nongnu.org/rdiff-backup/ in case of rdiff :)
BACKUPSYSTEM="rdiff"
########### End: Settings ##################

############################################
##### DO NOT EDIT BELOW THIS LINE ##########
LC_LANG=C

#Read user settings from /etc/minecraft-server/<username>/<servername>
SETTINGS_FILE=${1}

#Check if settings file is in /etc/minecraft-server
#FIXME

. "${SETTINGS_FILE}"

MCSERVERID="mc-server-${RUNAS}-${SERVERNAME}" #Unique ID to be able to send commands to a screen session.
INVOCATION="java -Xincgc -XX:ParallelGCThreads=$CPU_COUNT -Xmx${MAX_GB} -jar ${JAR_FILE}"

#        #INVOCATION="java -Xmx1024M -Xms1024M -XX:+UseConcMarkSweepGC -XX:+CMSIncrementalPacing -XX:ParallelGCThreads=$CPU_COUNT -XX:+AggressiveOpts -jar craftbukkit.jar nogui"



### FUUUU check_qouta() ... :/
# This will be an easy implementation of quota:
#  - check size of all backups with du -s ...
#  - if size>quota, then start remove-loop and remove so long the oldest backup, until size<quota
#   sooo einfach :)
function trim_to_quota() {
	local quota=$1
	local _backup_dir="${BACKUPDIR}/${SERVERNAME}-rdiff"
	_size_of_all_backups=$(($(du -s ${_backup_dir} | cut -f1)/1024))

	while [ ${_size_of_all_backups} -gt $quota ];
	do
		echo ""
		echo "Total backup size of ${_size_of_all_backups} MiB has reached quota of $quota MiB."
		local _increment_count=$(($(rdiff-backup --list-increments ${_backup_dir}| grep -o increments\. | wc -l)-1))
		echo "  going to --remove-older-than $((${_increment_count}-1))B"
		nice -n19 rdiff-backup --remove-older-than $((${_increment_count}-1))B "${BACKUPDIR}/${SERVERNAME}-rdiff" >/dev/null 2>&1
		echo "  Removed."
		_size_of_all_backups=$(($(du -s ${_backup_dir} | cut -f1)/1024))
	done
	echo "Total backup size (${_size_of_all_backups} MiB) is less or equal quota ($quota MiB)."
}

#function check_quota() {
##uses only lines with xx GB
## very hacky ... neu und schoen machen :)
#        local quota=$1
#
#        RDIFFBACKUP_LIST=$(rdiff-backup --list-increment-sizes ${BACKUPDIR}/${SERVERNAME}-rdiff | sed = - | sed 'N;s/\n/\t/' | sed -nr -e 's/^([0-9]+).*([a-zA-Z]{3} [a-zA-Z]{3} [0-9]{1,2} [0-9]{2}:[0-9]{2}:[0-9]{2} [0-9]{4}).*MB[^0-9]+([0-9]{1,3}\.[0-9]{1,2}) GB$/\1 \3/p') 
#        IFS='
#'
#        for i in $RDIFFBACKUP_LIST
#        do  
#                local BACKUPNUMBER=$(($(echo $i | cut -d' ' -f1)-2))
#                #-2 weil die ersten beiden Zeilen Ueberschrift und Trennlinie sind.
#            
#                local CUMMULSIZE=$(echo $i | cut -d' ' -f2)
#            
#                #umrechnen in MiBytes und die nachkommestellen abschneiden
#                local SIZE_MiB=$(echo "$CUMMULSIZE * 1024" | bc -q | sed -nr -e 's/^(.*)\..*$/\1/p')
#            
#                #printf "BackupNr: %s, SizeMiB: %s\n" "$BACKUPNUMBER" "$SIZE_MiB"
#                if [ $SIZE_MiB -gt $quota ];
#                then
#                        #echo "loeschen ab backupnr $BACKUPNUMBER"
#			#BACKUPNUMBER is now the first backup that breaks quota; return BACKUPNUMBER-1 to remove it.
#                        echo $(($BACKUPNUMBER-1))
#			return 0
#                fi  
#        done
#	return 1 #something went wrong...
#}


function as_user() {
  if [ "$(whoami)" = "${RUNAS}" ] ; then
    /bin/bash -c "export LC_ALL=de_DE.UTF-8 && $1" 
  else
    su - ${RUNAS} -c "export LC_ALL=de_DE.UTF-8 && $1"
  fi
}

function is_running() {
   if ps aux | grep -v grep | grep SCREEN | grep "${MCSERVERID} " >/dev/null 2>&1 #Das Leerzeichen am Ende des letzten grep, damit lalas1 und lalas1-test unterschieden werden.
   then
     return 0 #is running, exit level 0 for everythings fine...
   else
     return 1 #is not running
   fi

}

function mc_start() {
  if is_running 
  then
    echo "Tried to start but ${JAR_FILE} is already running!"
  elif [ -f "${SERVERDIR}/${DONT_START}" ]
  then
    echo "Tried to start but ${DONT_START} exists."
  else
    echo "${JAR_FILE} is not running... starting."
    cd "${SERVERDIR}"
    as_user "cd ${SERVERDIR} && screen -dmS ${MCSERVERID} ${INVOCATION}"
    sleep 3

    if is_running
    then
      echo "${JAR_FILE} is now running."
    else
      echo "Could not start ${JAR_FILE}."
    fi
  fi
}

function mc_saveoff() {
        if is_running
	then
		echo "${JAR_FILE} is running... suspending saves"
		as_user "screen -p 0 -S ${MCSERVERID} -X eval 'stuff \"say Server-Backup wird gestartet.\"\015'"
                as_user "screen -p 0 -S ${MCSERVERID} -X eval 'stuff \"save-off\"\015'"
                as_user "screen -p 0 -S ${MCSERVERID} -X eval 'stuff \"save-all\"\015'"
                sync
		sleep 10
	else
                echo "${JAR_FILE} was not running. Not suspending saves."
	fi
}

function mc_saveon() {
 	if is_running
	then
		echo "${JAR_FILE} is running... re-enabling saves"
                as_user "screen -p 0 -S ${MCSERVERID} -X eval 'stuff \"save-on\"\015'"
                as_user "screen -p 0 -S ${MCSERVERID} -X eval 'stuff \"say Server-Backup ist fertig.\"\015'"
	else
                echo "${JAR_FILE} was not running. Not resuming saves."
	fi
}

function get_server_pid() {
		#get pid of screen
		local pid_server_screen=$(ps -o pid,command ax | grep -v grep | grep SCREEN | grep "${MCSERVERID} "  | awk '{ print $1 }') #Das Leerzeichen am Ende des letzten grep, damit lalas1 und lalas1-test unterschieden werden.


		if [ ! -z "$pid_server_screen" ]
		then
		    #We use one screen per server, get all processes with ppid of pid_server_screen
		    local pid_server=$(ps -o ppid,pid ax | awk '{ print $1,$2 }' | grep "^${pid_server_screen}" | cut -d' ' -f2) 
		    echo ${pid_server}
		fi
}

function mc_stop() { #Nach dieser Funktion muss der Server tot sein, sonst gibt es Probleme...
        if is_running
        then
		#Give the server some time to shutdown itself.
                echo "${JAR_FILE} is running... stopping."
                as_user "screen -p 0 -S ${MCSERVERID} -X eval 'stuff \"say Server wird in 10 Sekunden heruntergefahren. Map wird gesichert...\"\015'"
                as_user "screen -p 0 -S ${MCSERVERID} -X eval 'stuff \"save-all\"\015'"
                sleep 10
                as_user "screen -p 0 -S ${MCSERVERID} -X eval 'stuff \"stop\"\015'"
                sleep 7
        else
                echo "${JAR_FILE} was not running."
        fi

	local _count=0
 	while is_running #If the server is still running, kill it.
	do
                echo "${JAR_FILE} could not be shut down... still running."
		echo "Forcing server to stop ... kill :P ..."
		local pid_server=$(get_server_pid)
		echo "Killing pid $pid_server"
		as_user "kill -9 $pid_server"
		if [ $? ]
		then
			echo "Successfully killed ${JAR_FILE} (pid $pid_server)."
		else
			echo "Check that ... could not kill -9 $pid_server"
		fi

		#noch laufende Screen-Sitzungen beenden
		as_user "screen -wipe"

		_count=$(($count+1))
		if [ $_count -ge 9 ]; then	#maximal 10 Versuche, den Server zu killen
			echo "Server could not be killed... after 10 tries..."
			break
		fi
        done
}

function mc_backup() {
   [ -d "${BACKUPDIR}" ] || mkdir -p "${BACKUPDIR}"
   echo "Backing up ${MCSERVERID}."

   case ${BACKUPSYSTEM} in
        tar)
	   # Wir erstellen pro Tag ein Unterverzeichnis im Backupverzeichnis. Name ist das Datum. Falls dann quota voll ist, werden ja Verzeichnisse in der Hauptebene geloescht, also dann immer ganze Tagesbackups.
	   # Wenn fuer den aktuellen Tag noch kein Verzeichnis existiert, dann legen wir es an und machen ein initiales komplettes Backup.
	   # Existiert der Ordner bereits, dann koennen wir davon ausgehen, dass ein Komplettbackup existiert und auch eine snapshot datei und machen ein inkrementelles Backup.

	   DATE=$(date "+%Y-%m-%d")
	   TIME=$(date "+%H-%M-%S")
	   THISBACKUP="${BACKUPDIR}/${DATE}" #Our current backup destiny.

	   [ -d "${THISBACKUP}" ] || mkdir -p "${THISBACKUP}" # Create daily directory if it does not exist.


	   TAR_SNAP_FILE="${THISBACKUP}/${SERVERNAME}.snap" #Snapshot file for tar, with meta information.
	   [ -f "${TAR_SNAP_FILE}" ] && BACKUP_TYPE="inc" || BACKUP_TYPE="full" #If DIR for today exists, do incremental, else full backup.

	   #Create backup tar.
	   TAR_FILE="${THISBACKUP}/${SERVERNAME}.${TIME}.${BACKUP_TYPE}.tar"
	   as_user "cd && tar -cvf '${TAR_FILE}' --exclude='*.log' -g '${TAR_SNAP_FILE}' '${SERVERDIR}' > /dev/null 2>&1"
	  ;;
	rdiff)
	   rdiff-backup --exclude "${SERVERDIR}/server.log" --exclude "${SERVERDIR}/plugins/dynmap/web/tiles/" "${SERVERDIR}" "${BACKUPDIR}/${SERVERNAME}-rdiff"

	   trim_to_quota ${BACKUP_QUOTA_MiB}	
#	   #now check if within quota; a very simple implementation; works only if running always; will not delete more than one old backup...bla
#	   local REMOVE_STARTING_AT=$(check_quota ${BACKUP_QUOTA_MiB})
#	   echo "$REMOVE_STARTING_AT"
#	   if [ ! -z "${REMOVE_STARTING_AT}" ]
#	   then
#		echo "Backup-Quota (\"${BACKUP_QUOTA_MiB}\") for this server is full. Deleting Increment entries older than entry number \"${REMOVE_STARTING_AT}\"."
#		nice -n19 rdiff-backup --force --remove-older-than ${REMOVE_STARTING_AT}B "${BACKUPDIR}/${SERVERNAME}-rdiff" #If something goes really wrong, rdiff-backup deletes only one backup per call ... if not used with --force
#	   else
# 	 	echo "Quota OK. (If you are sure, that quota bla, check function quota_check.)"
#	   fi

	  ;;
   esac
}

function listbackups() {
	if [ "${BACKUPSYSTEM}" != "rdiff" ]
	then
		echo "Error: listbackups is only available for usage with rdiff-backup; change BACKUPSYSTEM in \"$0\" or in user-settings-file in order to use rdiff-backup."
	else
		echo "Backups for server \"${SERVERNAME}\""
		rdiff-backup -l "${BACKUPDIR}/${SERVERNAME}-rdiff"
		rdiff-backup --list-increment-sizes "${BACKUPDIR}/${SERVERNAME}-rdiff"
	fi
}


# Returns output like "2 9", which means: ID:2, 9 times.
function lottery_rand() {
	local _max_item_count=10
	local id_list=/home/minecraft/id.list

	local anzahl_items=$(wc -l ${id_list} | cut -d' ' -f 1)

	local random_count=$((1+$RANDOM%$(($_max_item_count-1)))) #Anzahl der Items, 1 bis 10
	local random_line=$((1+$RANDOM%${anzahl_items}))
	local id_from_random_line=$(head -n ${random_line} ${id_list} | tail -n1)

	echo $id_from_random_line ${random_count}
}

#Gives a named player the items from lottery_rand().
function lottery() {
    local zeugs=$(lottery_rand)
    local give_id=$(echo $zeugs | cut -d' ' -f1)
    local give_count=$(echo $zeugs | cut -d' ' -f2)

    local name=$1
    
    #get name for our item
    #wir brauchen die ID ohne eventuelles :x
    local _cleared_give_id=$(echo ${give_id} | cut -d':' -f1)
    local name_for_id=$(grep "^${_cleared_give_id}:" /home/minecraft/id.list-names | cut -d':' -f2)
    
    sendcommand "say Gewinn fuer ${name}: ${give_count} ${name_for_id}($give_id)."
    sendcommand "give ${name} ${zeugs}"
    echo -en "Name: ${name}\nAnzahl: ${give_count}\nBezeichnung(ID): ${name_for_id}(${give_id})\nDone.\n"

}

function sendcommand() {
	if is_running
        then
                screen -S "$MCSERVERID" -p 0 -X stuff "$(printf "${1}\r")"
	fi  
}

#Start-Stop here
case "${2}" in
  start)
    mc_start
    ;;
  isrunning)
    is_running
    ;;
  stop)
    mc_stop
    ;;
  restart)
    mc_stop
    mc_start
    ;;
  lottery)
    lottery "${3}"
    ;;
  listbackups)
    listbackups
    ;;
#  update)
#    mc_stop
#    mc_backup
#    mc_update
#    mc_start
#    ;;
  backup)
    mc_saveoff
    mc_backup
    mc_saveon
    ;;
  status)
    if is_running
    then
      echo "${JAR_FILE} is running."
    else
      echo "${JAR_FILE} is not running."
    fi
    ;;
  sendcommand|sc|c)
	sendcommand "${3}"
    ;;
  pid)
	get_server_pid
    ;;
  *)cat << EOHELP
Usage: ${0} SETTINGS_FILE OPTION [ARGUMENT]
For example: ${0} /etc/minecraft-server/userx/serverx-bukkit status

OPTIONS
    start                 Start the server.
    stop                  Stop the server.
    restart               Restart the server.
    backup                Backup the server.
    listbackups           List current inkremental backups (only available for BACKUPSYSTEM="rdiff").
    status                Prints current status of the server (online/offline)
    sendcommand|sc|c      Send command to the server given as [ARGUMENT]
    lottery <playername>  Gives a player a random count of a random item. (Player must have a free inventory slot.)
    pid		          Get pid of a server process.

EXAMPLES
    Send a message to all players on the server:
    ${0} SETTINGS_FILE sendcommand "say We are watching you :P"

EOHELP
    exit 1

  ;;
esac

exit 0
