#!/bin/bash
#####################################################################################
# Script que copia bases de datos MySQL en un servidor NFS con Percona xtrabackup
#####################################################################################
#Variables
#####################################################################################
#Tiempo de inicio de script
start_time=`date +%s`
#Usuario con permiso en las BBDD
dbUser="root"
dbPass="Amparo77"
#Punto de montaje del NFS
mountPoint="/home/wdna/backup/backDB"
#Directorio donde se guardan los archivos de copia de seguridad antes de copiarlos al NFS
appDir="/home/wdna/backup/sqlBack"
#Nombre del servidor, por defecto coge el nombre del sistema
serverName=$HOSTNAME
#Fecha
datetime=`date +"%Y%m%d"`
#Fecha para el log
logDate=`date +%Y-%m-%d`
#IP del servidor NFS
#IPNFS="192.168.2.44"
IPNFS="15.100.11.166"
#Directorio del servidor NFS
pathNFSServerName="/export/RF/WDNA/"
#Los archivos con esta antiguedad se borrarán del NFS. El valor cero desactiva el borrado
retainDays=0
#Archivos de control
controlFiles=("cron_control_ATT_HUAWEI2G.txt" "cron_control_ATT_HUAWEI3G.txt" "cron_control_ATT_HUAWEI4G.txt")
#Ruta archivos de control
controlFilesPath="/home/wdna/preprocess/"
####################################################################
#Funcion para mostrar los segundos en formato legible
####################################################################
function displaytime {
  local T=$1
  local D=$((T/60/60/24))
  local H=$((T/60/60%24))
  local M=$((T/60%60))
  local S=$((T%60))
  (( $D > 0 )) && printf '%d dias ' $D
  (( $H > 0 )) && printf '%d horas ' $H
  (( $M > 0 )) && printf '%d minutos ' $M
  (( $D > 0 || $H > 0 || $M > 0 )) && printf 'y '
  printf '%d segundos\n' $S
}
function deleteControlFiles {
	for i in "${controlFiles[@]}"
	do
		rm -f $controlFilesPath$i
	done
}
####################################################################
#Ejecucion de copia de seguridad
####################################################################
zip="pigz"

hash innobackupex 2>/dev/null || { echo >&2 "$logDate: Error. Se requiere el programa Percona xtrabackup para hacer la copia de seguridad."; exit -1; }

hash pigz 2>/dev/null || { echo >&2 "$logDate: Alerta. Se requiere el programa pigz para hacer la compresion, se usara gzip en su lugar"; zip="gzip"; }

set -o pipefail

echo "$logDate: Montando NFS"
isMounted=`df -h | grep $mountPoint | head -1`
if [ -n "$isMounted"  ]; then
	echo "$logDate: NFS Montado"
else
	mkdir -p $mountPoint
	mount -t nfs $IPNFS:$pathNFSServerName $mountPoint
	isMounted=`df -h | grep $mountPoint | head -1`
	if [ -n "$isMounted"  ]; then
		echo "$logDate: NFS Montado"
	else
		echo "$logDate: Error. No se puede montar NFS"
		exit -1
	fi
fi

mkdir -p $appDir
if [ ! -d $appDir ]
then
	echo "$logDate: Error. No se puede crear el directorio $appDir"
	exit -1
fi

for i in "${controlFiles[@]}"
do
	controlFile=$controlFilesPath$i
	while [ -f $controlFile ]
			do
				echo "$logDate: El archivo $controlFile existe. Esperando 60s a que termine el proceso de recoleccion de datos."
				sleep 60
			done
			echo "$logDate: Creando el archivo de control $controlFile"
			touch $controlFile
done

fileName=$serverName"_"$datetime
echo "$logDate: Haciendo copia de la BD $i en el archivo $appDir/$fileName.gz"
innobackupex --user=$dbUser --password=$dbPass --no-timestamp --stream=tar $appDir | $zip -f > $appDir/$fileName.tar.gz
if [ $? -eq 0 ]
then
	echo "$logDate: Copia de seguridad realizada correctamente"
else
	echo "$logDate: Error. Se ha producido un error: ${PIPESTATUS[0]}"
	deleteControlFiles
	exit -1
fi

if [ "$appDir" != "$mountPoint" ]
then
	echo "$logDate: Copiando $appDir/$fileName.tar.gz a $mountPoint/$fileName.tar.gz"
	cp $appDir/$fileName".tar.gz" $mountPoint/$fileName".tar.gz"
	if [ $? -eq 0 ]
	then
		echo "$logDate: Archivo copiado al NFS"
		rm -f $appDir/$fileName".tar.gz"
	else
		echo "$logDate: Error. Fallo al copiar el archivo al NFS: ${PIPESTATUS[0]}"
		deleteControlFiles
		exit -1
	fi
fi

deleteControlFiles

if [ $retainDays -gt 0 ]
then
	echo "$logDate: Borrando archivos anteriores a $retainDays dias"
	find $mountPoint/* -mtime +$retainDays -exec rm {} \;
fi

echo "$logDate: Desconectando NFS"
umount -f $mountPoint

echo "$logDate: Tiempo de ejecucion: "$(displaytime $(expr $(date +%s) - $start_time))
exit 0