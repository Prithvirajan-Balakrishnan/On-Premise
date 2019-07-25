#!/bin/sh

#---------------#
# Set Variables #
#---------------#

SERVER_NAME=$(hostname -s)
SCRIPT_DIR="/opt/admin/bin"

# Script and binary locations
RPM_SCRIPT="${SCRIPT_DIR}/get_installed_rpms.sh"
LVM_KS_SCRIPT="${SCRIPT_DIR}/create_lvm_ks.sh"
AIDE="/usr/sbin/aide"
CFG2HTML="/usr/bin/cfg2html"

# If this is a firewalled server OUTPUT_DIR must match the settings in the collect script on admnie03
OUTPUT_DIR="/var/tmp/linux_system_restore"

# Output files
RPM_OUTPUT="${OUTPUT_DIR}/installed_rpms.txt"
LVM_KS_OUTPUT="${OUTPUT_DIR}/lvm_kickstart.txt"
AIDE_OUTPUT="${OUTPUT_DIR}/aide.db.gz"
CFG2HTML_OUTDIR="${OUTPUT_DIR}/cfg2html"

# Firewalled servers do not perform scp into COIN.
# Files are collected from admnie03 instead.
# Set to 1 to scp files or 0 to skip scp.
SCP_FILES=1

# SCP Variables
SSH_USER="swsync"
SCP_SERVER="unixsoftware"
SCP_BASE_LOCATION="/var/opt/linux_system_restore"

# Set CHOWN_FILES to 1 to chown the output files to the CHOWN_USER.
# Used to allow the audit user to collect the files for firewalled servers.
CHOWN_FILES=1
CHOWN_USER="audit"

#------------------------------------------------------------------------------------#

#-----------#
# Functions #
#-----------#

get_installed_rpms()
{
   #-------------------------------#
   # Gets a list of installed RPMs #
   #-------------------------------#

   echo
   echo "INFO: Getting list of installed RPMS."
   echo

   $RPM_SCRIPT $RPM_OUTPUT

   if [[ $? -ne 0 ]];then
      echo
      echo "ERROR: Script to list installed RPMs failed"
      echo
      exit 1
   fi

} # end of get_installed_rpms

#------------------------------------------------------------------------------------#
initial_checks()
{
   #----------------#
   # Initial checks #
   #----------------#

   # Check script is running as root
   if [[ ! `id -u` -eq 0 ]]; then
      echo
      echo "ERROR: Script is not running as root. Running as `id -un`."
      echo "ERROR: Exiting - Please rerun script as user root."
      echo
      exit 1
   else
      echo  "INFO: Script is running as user root."
   fi

   # Create OUTPUT_DIR if not present
   if [[ ! -d ${OUTPUT_DIR} ]];then
      echo
      echo "INFO: $OUTPUT_DIR doesn't exist - creating it."
      mkdir -p ${OUTPUT_DIR}
   else
     # Clear old files out of output dir
     echo
     echo "INFO: Clearing old files from $OUTPUT_DIR"
     rm ${RPM_OUTPUT}
     rm ${LVM_KS_OUTPUT}
     rm ${AIDE_OUTPUT}
     rm ${CFG2HTML_OUTDIR}/*
   fi

} # end of initial_checks

#------------------------------------------------------------------------------------#

generate_lvm_ks()
{
   #--------------------------------#
   # Generate LVM Kickstart entries #
   #--------------------------------#

   echo
   echo "INFO: Generating LVM Kickstart entries."
   echo

   $LVM_KS_SCRIPT $LVM_KS_OUTPUT

   if [[ $? -ne 0 ]];then
      echo
      echo "ERROR: Script to create Kickstart entries failed."
      echo
      exit 2
   fi

} # end of generate_lvm_ks

#------------------------------------------------------------------------------------#

update_aide()
{
   #----------------------#
   # Update aide database #
   #----------------------#

   AIDE_DBFILE="/var/lib/aide/aide.capone.db.gz"
   AIDE_NEW_DBFILE="/var/lib/aide/aide.db.new.gz"

   echo
   echo "INFO: Updating aide database."
   echo

   $AIDE --update

   if [[ $? -gt 7 ]];then
      echo
      echo "ERROR: aide update exited with an error."
      echo
   fi

   # Copy aide database to output location
   cp $AIDE_NEW_DBFILE $AIDE_OUTPUT

   # Update aide database on the server
   cp $AIDE_NEW_DBFILE $AIDE_DBFILE

} # end of update_aide

#------------------------------------------------------------------------------------#

run_cfg2html()
{
   #--------------#
   # Run cfg2html #
   #--------------#

   if [[ ! -d ${OUTPUT_DIR}/cfg2html ]];then
      mkdir ${OUTPUT_DIR}/cfg2html
   fi

   echo
   echo "INFO: Running cfg2html."
   echo

   $CFG2HTML -o $CFG2HTML_OUTDIR

   if [[ $? -ne 0 ]];then
      echo
      echo "WARNING: cfg2html script had errors."
      echo
   fi

} # end of run_cfg2html

#------------------------------------------------------------------------------------#
get_tsm_config()
{
   #-----------------------------#
   # Get TSM Configuration files #
   #-----------------------------#

   TSM_PASSWD_FILE="/etc/adsm/TSM.PWD"
   TSM_CONFIG_FILE="/opt/tivoli/tsm/client/ba/bin/dsm.sys"

   echo
   echo "INFO: Collecting TSM Configuration files."

   if [[ -f ${TSM_PASSWD_FILE} ]];then
      cp ${TSM_PASSWD_FILE} ${OUTPUT_DIR}/
      if [[ $? -ne 0 ]];then
         echo "ERROR: Could not copy TSM password file ${TSM_PASSWD_FILE}."
      else
         echo "INFO: TSM password file ${TSM_PASSWD_FILE} collected."
      fi
   else
      echo "ERROR: TSM password file ${TSM_PASSWD_FILE} is not present."
   fi

   if [[ -f ${TSM_CONFIG_FILE} ]];then
      cp ${TSM_CONFIG_FILE} ${OUTPUT_DIR}/
      if [[ $? -ne 0 ]];then
         echo "ERROR: Could not copy TSM configuration file ${TSM_CONFIG_FILE}."
      else
         echo "INFO: TSM configuration file ${TSM_CONFIG_FILE} collected."
      fi
   else
      echo "ERROR: TSM configuration file ${TSM_CONFIG_FILE} is not present."
   fi

   echo "INFO: Finished Collecting TSM Configuration files."
}
#------------------------------------------------------------------------------------#

scp_files()
{
   #-------------------------------------#
   # Copy output files to central server #
   #-------------------------------------#

   echo
   echo "INFO: Preparing to SCP files to central location."

   # Work out enviroment from ip address of scp server
   NETWORK=$(nslookup $SCP_SERVER |grep Address |tail -1 |awk '{print $2}' |awk -F. '{print $1"."$2}')

   case ${NETWORK} in
            10.160 )
               ENVIRONMENT="PROD"
            ;;
            10.170 )
               ENVIRONMENT="DR"
            ;;
            172.22 )
               ENVIRONMENT="DEV"
            ;;
            * )
              echo
              echo "ERROR: Cannot find Environment (PROD, DR or DEV) from Network octets (${NETWORK})."
              echo "ERROR: Cannot set scp location. Exiting."
              echo
              exit 2
            ;;
   esac

   SCP_LOCATION="${SCP_BASE_LOCATION}/${ENVIRONMENT}/${SERVER_NAME}"

   # Create server directory if it doesn't exist
   echo
   echo "INFO: Checking directory for current files exists"
   ssh ${SSH_USER}@${SCP_SERVER} "test -d ${SCP_LOCATION}/current"
   if [[ $? -ne 0 ]];then
      # create current dir
      echo
      echo "INFO: Directory for storing current files (${SCP_SERVER}:${SCP_LOCATION}/current) does not exist - creating it."
      ssh ${SSH_USER}@${SCP_SERVER} "mkdir -p ${SCP_LOCATION}/current"
   else
      # empty current dir
      echo
      echo "INFO: Clearing old files from destination. (${SCP_SERVER}:${SCP_LOCATION}/current)."
      ssh ${SSH_USER}@${SCP_SERVER} "rm -r ${SCP_LOCATION}/current/*"
   fi

   # Copy output files to current location
   echo
   echo "INFO: Copying output files to ${SCP_SERVER}:${SCP_LOCATION}/current"
   scp -r $OUTPUT_DIR/* ${SSH_USER}@${SCP_SERVER}:${SCP_LOCATION}/current

   # Create an archive of files
   echo
   echo "INFO: Checking directory for archive files exists"
   ssh ${SSH_USER}@${SCP_SERVER} "test -d ${SCP_LOCATION}/archive"
   if [[ $? -ne 0 ]];then
      # create archive dir
      echo
      echo "INFO: Directory for storing archive files (${SCP_SERVER}:${SCP_LOCATION}/archive) does not exist - creating it."
      ssh ${SSH_USER}@${SCP_SERVER} "mkdir -p ${SCP_LOCATION}/archive"
   fi

   echo
   echo "INFO: Creating an archive of the files in (${SCP_SERVER}:${SCP_LOCATION}/archive"
   DATE=$(date +%F)
   ssh ${SSH_USER}@${SCP_SERVER} "cd ${SCP_LOCATION}/current; tar cvf ../archive/${SERVER_NAME}-${DATE}.tar *; /usr/contrib/bin/gzip -f ${SCP_LOCATION}/archive/${SERVER_NAME}-${DATE}.tar"

   echo
   echo "INFO: Changing permissions of scp files to be read only by owner."
   ssh ${SSH_USER}@${SCP_SERVER} "find ${SCP_LOCATION} -type f -exec chmod 400 {} \;"
   ssh ${SSH_USER}@${SCP_SERVER} "find ${SCP_LOCATION} -type d -exec chmod 700 {} \;"
   echo

} # end of scp_files function

#------------------------------------------------------------------------------------#

#-----------#
# Main Code #
#-----------#

# Echo starting message
echo
echo "INFO: $(date)"
echo "INFO: Script $0 Started."

# initial checks
initial_checks

# Get a list of installed rpms
get_installed_rpms

# Generate lvm kickstart entries
generate_lvm_ks

# Update aide database
update_aide

# Get cfg2html output
run_cfg2html

# Get tsm configuration files
get_tsm_config

# Copy files to central server
if [[ $SCP_FILES -eq 1 ]];then
   scp_files
fi

# Chown files so they can be collected
if [[ $CHOWN_FILES -eq 1 ]];then
   chown -R ${CHOWN_USER} ${OUTPUT_DIR}
   find ${OUTPUT_DIR} -type f -exec chmod 400 {} \;
   find ${OUTPUT_DIR} -type d -exec chmod 700 {} \;
fi

# Echo ending message
echo
echo "INFO: $(date)"
echo "INFO: Script $0 Completed."
echo

# End of Script
