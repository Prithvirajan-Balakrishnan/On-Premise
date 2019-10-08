#!/bin/bash

##############################  Having SSH-key from one server and pushing it to manyservers and making passwordless ##############################
##############################  authentication is ansecurity risk - this script search the ssh-key and delete then modify ##############################
##############################  the .ssh dir to root:root and permissib to 640, this will stop users being to create new key ##############################


> /tmp/ssh_dir_found
> /tmp/ssh_dir_not_found
> /tmp/ssh_users
> /tmp/no_ssh_dir
red=`tput setaf 1`
reset=`tput sgr0`

#### list out the users in the system ####
ls -ld /home/[a-x][a-x][a-x][0-9][0-9][0-9]| awk '{ print $NF }' > /tmp/ind_users
Total=`wc -l /tmp/ind_users|awk '{ print $1  }'`

for i in `cat /tmp/ind_users`
do
ls -ld $i/.ssh/ >> /tmp/ssh_dir_found 2>> /tmp/ssh_dir_not_found
done

SSH=`wc -l /tmp/ssh_dir_found|awk '{ print $1  }'`
NSSH=`wc -l /tmp/ssh_dir_not_found|awk '{ print $1  }'`
printf "\n"
echo "Total users are found in system is $Total that saved in file /tmp/ind_users"
printf "\n"
echo "SSH directory found for $SSH users and that saved in file /tmp/ssh_dir_found"
printf "\n"
echo "SSH directory not found for $NSSH users and that saved in file /tmp/ssh_dir_not_found"
printf "\n"


echo "${red}Removing SSH-keys if found on $SSH users where the .ssh dir found and setting up permission to 600 and root:root for the .SSH dir$reset"
cat /tmp/ssh_dir_found|awk '{ print $NF }' >> /tmp/ssh_users
for i in `cat /tmp/ssh_users`
do
chmod 600 $i ; chown root:root $i
rm -rf $iid*; ls -ld $i; ls -l $i
done


echo "Creating a .ssh dir and setting up permission to 600 and root:root for the users which doesn't have .SSH dir"
cat /tmp/ssh_dir_not_found |awk '{ print $4  }'|awk -F'[: ]' '{print $1}' >> /tmp/no_ssh_dir
for i in `cat /tmp/no_ssh_dir`
do mkdir $i; chown root:root $i; chmod 600 $i; ls -ld $i
done
[root@ngmplx-rqtto ~]# vi ssh_key_fix.sh
#!/bin/bash

> /tmp/ssh_dir_found
> /tmp/ssh_dir_not_found
> /tmp/ssh_users
> /tmp/no_ssh_dir
red=`tput setaf 1`
reset=`tput sgr0`

#### list out the users in the system ####
ls -ld /home/[a-x][a-x][a-x][0-9][0-9][0-9]| awk '{ print $NF }' > /tmp/ind_users
Total=`wc -l /tmp/ind_users|awk '{ print $1  }'`

for i in `cat /tmp/ind_users`
do
ls -ld $i/.ssh/ >> /tmp/ssh_dir_found 2>> /tmp/ssh_dir_not_found
done

SSH=`wc -l /tmp/ssh_dir_found|awk '{ print $1  }'`
NSSH=`wc -l /tmp/ssh_dir_not_found|awk '{ print $1  }'`
printf "\n"
echo "Total users are found in system is $Total that saved in file /tmp/ind_users"
printf "\n"
echo "SSH directory found for $SSH users and that saved in file /tmp/ssh_dir_found"
printf "\n"
echo "SSH directory not found for $NSSH users and that saved in file /tmp/ssh_dir_not_found"
printf "\n"


echo "${red}Removing SSH-keys if found on $SSH users where the .ssh dir found and setting up permission to 600 and root:root for the .SSH dir$reset"
cat /tmp/ssh_dir_found|awk '{ print $NF }' >> /tmp/ssh_users
for i in `cat /tmp/ssh_users`
do
chmod 600 $i ; chown root:root $i
rm -rf $iid*; ls -ld $i; ls -l $i
done


echo "Creating a .ssh dir and setting up permission to 600 and root:root for the users which doesn't have .SSH dir"
cat /tmp/ssh_dir_not_found |awk '{ print $4  }'|awk -F'[: ]' '{print $1}' >> /tmp/no_ssh_dir
for i in `cat /tmp/no_ssh_dir`
do mkdir $i; chown root:root $i; chmod 600 $i; ls -ld $i
done
