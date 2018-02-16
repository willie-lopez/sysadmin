#!/bin/ksh

#
#   Name:
#	audit_ssh.sh  -  look for public key files in common areas
#	    and validate users from each key
#
#   Synopsis:
#	Must be run as root
#
#	$ audit_ssh.sh 
#
#   Description:
#	audit_ssh.sh audits the use of ssh, albeit very limited.
#	A predefined list of directories are scanned for a list of
#	possible key filenames.  The user/host pair is then extracted
#	from the key file and verified as a user in the local and 
#	the NIS password files.  Validity is defined as the user ID
#	is in the password file.  A check is also made to see if the
#	user is "active" or "disabled".  Disabled is defined as one
#	or both of the following: the password field is starred out
#	with an asterisk (*) or the shell is defined as /bin/false
#	or /bin/sync.  
#
#	A message for each user/host pair found in the key file is
#	printed to STDOUT.  The message, deliniated by the colon 
#	character (:), gives the name of the client that audit_ssh.sh
#	is running on, the name of the key file, the user/host pair,
#	the user, the verification state, and the verification message.
#
#	The verification state is defined as:
#	    
#	    0 - the user was not found in any password file
#	    1 - the user was found and is active
#	    2 - the user was found but the account is disabled
#
#	The verification message is one of the following:
#
#	    User <user> verified
#	    User <user> unknown
#	    User <user> globally and locally disabled 
#	    User <user> globally active, but locally disabled
#   
#	    The term "global(ly)" refers to NIS
#
#   Returns:
#	Verification state (see notes above)
#	-1 .... Attempt to run script as a non-root user
#
#   Notes:
#	audit_ssh.sh is not a fool proof audit method but does 
#	provide information with the presumption the key files
#	were not manually changed.
#
#	It is recommended that the find be expanded to search for
#	any possible key files.
#
#	The password file may have to be changed to your environment's
#	filename (especially if shadow files are used.)
#
#   History:
#	06-21-2001	Willie Lopez		Initial creation.
#
#


if [ `id -u` -ne 0 ] ; then
    echo "Must be run as root!"
    exit -1
fi


PATH=/bin:/usr/bin:/usr/local/bin:/usr/sbin:.
export PATH


dirlist="/etc /tmp /var/tmp /home"
foundlist=/tmp/files.$$
keylist=/tmp/keys.$$

let exit_flag=


function find_keys
  {
    
    find $dirlist -name "authorized_keys" -print > $foundlist
    return 0
    
  }

function getkeys 
  {
    > $keylist

    for keyfile in `cat $foundlist` ; do
    	awk '{
		filenm = FILENAME
		user_host_pair = $NF
		split(user_host_pair,a,"@")
		user_id = a[1]
		print filenm"|"user_host_pair"|"user_id""
	    }' $keyfile >>$keylist
    done

  }

function verfuser
  {

    host=`hostname`

    IFS=\|

    while read keyfile keyhost keyuser ; do
    
	global_verf $keyuser ; let active_global=$?
	local_verf $keyuser ; let active_local=$?
	
	if [ $active_global -eq 0 -a $active_local -eq 0 ] ; then
	    # User not found globally or locally
	    let verf_state=1 
	    verf_msg="User $keyuser unknown"

	elif [ $active_global -eq 2 -a $active_local -eq 2 ] ; then
	    # User is globally and locally deactivated
	    let verf_state=1 
	    verf_msg="User $keyuser globally and locally deactivated"

	elif [ $active_global -eq 1 -a $active_local -eq 2 ] ; then
	    # User is globally authorized but locally deactivated
	    let verf_state=1 
	    verf_msg="User $keyuser globally active, locally deactivated"

	else
	    # All other conditions are okay
	    let verf_state=0
	    verf_msg="User $keyuser verified"

	fi

	print "$host:$keyfile:$keyhost:$keyuser:$verf_state:$verf_msg"

    done < $keylist

    exit_flag=$verf_state
  }

function global_verf  {

    . /etc/rc.config.d/namesvrs

    user=$1
    let yppwent_active=0		# 0=not found, 1=active, 2=disabled

    if [ $NIS_CLIENT -eq 1 ] ; then

	ypcat passwd | awk -F: -v user=$user '
	    BEGIN { active = 0 }
		  { if ($1 == user) 
		      {
			active = 1
			if ($2 == "*" || $7 == "/bin/false" || 
			    $7 == "/bin/sync") active = 2
		      }
		  }
	    END { exit (active) }'
	
	let yppwent_active=$?
    fi

    return $yppwent_active
  }

function local_verf  {

    user=$1
    let pwent_active=0			# 0=not found, 1=active, 2=disabled

    awk -F: -v user=$user '
	BEGIN { active = 0 }
	      { if ($1 == user)
		  {
		    active = 1
		    if ($2 == "*" || $7 == "/bin/false" ||
			$7 == "/bin/sync") active = 2
		  }
	      }
	END { exit (active) }' /etc/passwd

    let pwent_active=$?
    return $pwent_active
  }



find_keys $dirlist 
getkeys 
verfuser

/bin/rm -f $foundlist $keylist
exit $exit_flag

