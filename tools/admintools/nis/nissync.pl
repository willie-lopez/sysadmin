#!/usr/bin/perl5

use File::Copy;
use Getopt::Long;


$foreign = "/tmp/foreign";
$local   = "/tmp/local";


############################################################################
#  Check for any command line arguments.  These arguments will override
#  any default values.

# Set defaults
($help_flag,$nonis_flag) = 0;

$result = GetOptions (	"user=s"	=> \$getasuser,
			"host=s"	=> \$fromhost,
			"ssh=s"		=> \$whichssh,
			"nonis"		=> \$nonis_flag,
			"target=s"	=> \$make_target,
			"help"		=> \$help_flag
		     );

if ( $help_flag == 1 )
  {
    print "\n\n";
    print "Usage: $prog_nm --host=hostname [args ... ]\n";
    print "\n";
    print "--user=user .............. login as this user to foreign host\n";
    print "--host=hostname .......... this is the foreign host to get from\n";
    print "--ssh=ssh|sssh ........... use this version of ssh\n";
    print "--nonis .................. local host is not an NIS server\n";
    print "--target=name ............ name of target in NIS Makefile to run \n";
    print "                           to build/push NIS maps\n";
    print "--help ................... Print this help screen\n";
    print "\n";
    exit(0);
  }


############################################################################
#  Query the domain's NIS passwd map on the foreign server

$cuser = ($getasuser ne "") ? $getasuser : "root" ;
$chost = ($fromhost  ne "") ? $fromhost  : "localhost" ;
$ctool = ($whichssh ne "") ? $whichssh  : "ssh" ;

$connect = "$ctool $cuser\@$chost ypcat passwd > /tmp/foreign";
print $connect,"\n";
#system ($connect);

#  Query the local NIS map or local password file
if ($nonis == 0)
  {
    # Query local NIS domain's passwd map
    system ("ypcat passwd > /tmp/local");
  }
else
  {
    # Query local password file
    system ("cat /etc/passwd > /tmp/local");
  }



############################################################################
#  Now let's sync the local passwd file or map to the foreign map

open (LOCAL,"</tmp/local") or die "Can't open /tmp/local!!\n";
open (FOREIGN,"</tmp/foreign") or die "Can't open /tmp/foreign!\n";
open (MAP,">/tmp/nispasswd.map") or die "Can't write to /tmp/nispasswd.map!\n";

#  Create a hash table, indexed by the user's name (field0), and having
#  value of all password fields except the user's name

while ($local_rec = <LOCAL>)
  {
    chop $local_rec;
    ($lognm,$pw,$uid,$gid,$gecos,$home,$shell) = split(/:/,$local_rec);
    $local_pwfile{$lognm} = "$pw:$uid:$gid:$gecos:$home:$shell";
  }

close (LOCAL);

#  Now create a hash table of the foreign password table, just like
#  the one we just created for the local password table.  
#  Note: There may not be a 1:1 correpondence between local and foreign
#  keys (the user's name).

while ($foreign_rec = <FOREIGN>)
  {
    chop $foreign_rec;
    ($lognm,$pw,$uid,$gid,$gecos,$home,$shell) = split(/:/,$foreign_rec);
    $foreign_pwfile{$lognm} = "$pw:$uid:$gid:$gecos:$home:$shell";
  }
close (FOREIGN);


#  Now, we are going to sync the tables.  For each of the keys, 
#  the user's name, we will take the password from the foreign table
#  and put it into the local table for the user:
#
#	local{user1}->passwd = foreign{user1}->passwd
#	local{user2}->passwd = foreign{user2}->passwd
#
#  If the password field from either the local or foreign tables
#  is empty or "disable" by the *, the local password field/value will 
#  be set to *.
#
#  If the local user is not in the foreign table, then the values 
#  for the user will not be changed.  Users that are in the foreign
#  table but not the local table will not be added to the local
#  table (as tempting as it may be.)
#

foreach $user (sort(keys(%local_pwfile)))
  {
    #  Reset values so that we don't accidentally plug in the wrong
    #  password to one or more users.
    $passwd1 = $passwd2 = $pw = "";

    #  Let's check that the user in 
    if ( $foreign_pwfile{$user} )
      {
    	#  Get the password field from both local and foreign tables
    	$passwd1 = (split(/:/,$local_pwfile{$user}))[0];
    	$passwd2 = (split(/:/,$foreign_pwfile{$user}))[0];

    	#  Get the age string from the password field, if any
    	#  The age is deliniated by the comma (,)
	$age1 = (split(/,/,$passwd1))[1];
	$age2 = (split(/,/,$passwd2))[1];

	#  If the age string is empty in both local and foreign tables, then
	#  set the age value to 180 days.  Otherwise, we are setting the age
	#  to the age defined in the foreign table.
	$age1 = "O.fO" if ($age1 eq "" && $age2 eq "");
	$age = ($age1 ne "") ? $age1 : $age2;

	#  Next, we need to disable the user's record in the local
	#  table if either password field is empty or already disabled.
	$passwd2 = "*" if ($passwd1 eq "" || $passwd2 eq ""); 
	$passwd2 = "*" if ($passwd1 eq "*" || $passwd2 eq "*"); 

	#  Next, we set the value of the password field to the foreign
	#  value (the one we just built).
	$passwd1 = $passwd2;
      }

    #  Finally, we need to update the local table and write it out to
    #  the build file.  In this procedure, passwords are either valid
    #  with aging set, or they are disabled.  Valid passwords then are
    #  the same now in the local table and foreign table, thus synced.
    ($pw,$uid,$gid,$gecos,$home,$shell) = split(/:/,$local_pwfile{$user});
    $passwd1 = $pw if ( $passwd1 eq "" );
    print MAP "$user:$passwd1,$age:$uid:$gid:$gecos:$home:$shell\n";
  }

close(MAP);


############################################################################
#  We're about done now.  All that's left is for us to update the 
#  password map or file and rebuild the NIS maps and push them out.
#  After we're done building maps and pushing them to slave servers,
#  if we're on an NIS server, then we just need to remove all of 
#  our build files.

#  See if we are an NIS server ...
$pid = `ps -e|grep ypserv`;
$pid = (split(/\s+/,$pid))[0];

if ( $pid > 0 )
  {
    # We are an NIS server
    print "*** Updating NIS passwd map ... \n";
    copy ("/tmp/nispasswd.map","/var/tmp/nispasswd");
    system ("cd /var/yp;make update");
  }
else
  {
    # We are not an NIS server, update local password file only
    print "*** Updating /etc/passwd ... \n";
    copy ("/etc/passwd","/etc/passwd~");
    #copy ("/tmp/nispasswd.map","/etc/passwd");

    #  Before we bail out, let's make sure we have a real passwd 
    #  file in place.  If not, put the old one back and print the
    #  error message on the screen so the message can get logged 
    #  some where.  
    if ( ! -f "/etc/passwd" )
      {
    	warn "/etc/passwd not updated, keeping original copy!\n";
	copy ("/etc/passwd~","/etc/passwd");
      }
  }

# Finally, let's clean up and not leave build files behind
#unlink ("/tmp/local");
#unlink ("/tmp/foreign");
#unlink ("/tmp/nispasswd.map");

#  Whew!  We're done!!  Passwords should now be synced up and everyone
#  is happy.

print "NIS domain sync complete!\n";
exit(0);

