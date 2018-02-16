#!/usr/bin/perl5

use strict;
use File::Copy;
use File::Basename;
use Getopt::Long;


##########################################################################
#  Let's start off with handling all signals.  In this case, since we are
#  modifying the password file, we want to abort the change upon any
#  signal being raised.  

# Insert code here to handle signals


##########################################################################
#  Okay, let's make sure we have proper user permission

my $prog_nm = basename($0);


##########################################################################
#  Now, let's make sure we have valid arguments.  These arguments must
#  be either a parameter actions such as list or change, or a new 
#  parameter value.  In any case, a parameter name is always required.

my ($login,$passwd,$age,$uid,$gid,$gecos,$home,$shell,$user);
my ($listparm,$changeparm,$addparm,$disableparm,$help_flag);

my $result = GetOptions (   "login=s"	=>  \$login,
			    "pw=s"	=>  \$passwd,
			    "age=s"	=>  \$age,
			    "uid=i"	=>  \$uid,
			    "gid=i"	=>  \$gid,
			    "gecos=s"	=>  \$gecos,
			    "home=s"	=>  \$home,
			    "shell=s"	=>  \$shell,
			    "user=s"	=>  \$user,
			    "l"		=>  \$listparm,
			    "c"		=>  \$changeparm,
			    "d"		=>  \$disableparm,
			    "help"	=>  \$help_flag
			);

print_usage() if ($result == 0 or $help_flag == 1);

# Make sure we have proper permissions if we are going to change a parm
die "Must be root to make a change to the passwd file!\n"
    if ($< ne 0 && ($changeparm == 1 or $disableparm == 1));

print "Okay, I have proper permissions ... \n";

# Make sure we have a password parm for which to perform some action upon
die "Must give password parm to change!\n"
    if (length($login.$passwd.$age.$uid.$gid.$gecos.$home.$shell) == 0 &&
	$changeparm == 1);

# Make sure that we have a user key to match to the new value
die "Must specify a key value to search for!\n"
    if ($user eq "");

# Make sure we have a default action to use
$listparm = 1 if ($listparm + $changeparm + $disableparm == 0);

# Make a table by which to reference the parameters
my @parmtab;
$parmtab[0] = $login;
$parmtab[1] = $passwd;
$parmtab[2] = $age;
$parmtab[3] = $uid;
$parmtab[4] = $gid;
$parmtab[5] = $gecos;
$parmtab[6] = $home;
$parmtab[7] = $shell;


##########################################################################
#   Okay, let's make a copy of the existing password file so that we can
#   undo changes if necessary.  But this copy only needs to be done if   
#   the action will change the password file.  

copy ("/etc/passwd","/tmp/passwd.$$")
    if ($listparm == 0);



##########################################################################
#   Now, let's read the password file and perform the action.  If the
#   action is to List the parm, then the work file will not be created.

my ($pwstr,$oldpwstr,$newpwstr);
my $changed = 0;		    # Flag whether or not a change occurred

# Create a temp passwd file that will hold the changes, if any,
# if the parameter action is other than to list the parameter value.
if ($listparm == 0)
  {
    if (open (NEWPWFILE,">/tmp/passwd.tmp"))
      {
	;
      }
    else
      { 
	unlink ("/tmp/passwd.$$"); 
	die "Can't create tmp passwd file!\n"; 
      }
  }

if (open(PWFILE,"</etc/passwd"))
  {
    while ($pwstr = <PWFILE>)
      {
	chop $pwstr;
	if ($listparm == 1)
	  {
	    list_parm ($user,$pwstr) if ($listparm == 1);
	  }
	else
	  {
	    $oldpwstr = $pwstr;
	    $newpwstr = change_parm ($user,$pwstr,@parmtab) 
		if ($changeparm == 1);
	    $newpwstr = disable_parm ($user,$pwstr,@parmtab) 
		if ($disableparm == 1);
	    printf NEWPWFILE "%s\n",$newpwstr;
	    $changed = 1 if ($changed == 0 && $oldpwstr ne $newpwstr); 
	    ###printf "%s\n",$newpwstr;
	  }
      }
    close (PWFILE);		    # Close /etc/passwd file
    close (NEWPWFILE);		    # Close new temp passwd file
  }
else
  {
    close (NEWPWFILE);
    unlink ("/tmp/passwd.$$");
    die "Unable to open and read /etc/passwd file!\n";
  }


# If changes occurred, then copy the new passwd file in place
copy ("/tmp/passwd.tmp","/etc/passwd") if ($changed == 1);
unlink ("/tmp/passwd.tmp");

# Always make sure we remove work files
unlink ("/tmp/passwd.$$");

exit(0);


##########################################################################
##########################################################################

sub print_usage
  {
    print "Usage: $prog_nm -user usernm [args ...]\n";
    print "\n";
    print "Must define an action and a parameter.  See the following for\n";
    print "a list of actions and parameters. \n";
    print "\n";
    print "-login=usernm ................ set the usernm to this value\n";
    print "-pw=password ................. set the password to this value\n";
    print "-age=pwage ................... set the age to this value\n";
    print "-uid=uid ..................... set the UID to this value\n";
    print "-gid=gid ..................... set the group ID to this value\n";
    print "-home=homedir ................ set the /home dir to this value\n";
    print "-shell=shell ................. set the shell to this value\n";
    print "-user=usernm ................. (required) key to change/list\n";
    print "-l ........................... list the password parm\n";
    print "-c ........................... change the password parm\n";
    print "-d ........................... disable the password record\n";
    print "\n\n";
    print "The -user=usernm is Required.  This user is the one that all \n";
    print "actions will work on, whether it be list, change, or delete.\n";
    print "You must also specify what parameter and what action.  See \n";
    print "the following example.\n\n";
    print "Example:\n";
    print "ch_pw -c -user=wjl -login=xyz\n";
    print "Will change the user id wjl to xyz.\n";
    print "\n\n";
    print "ch_pw -l -user=wjl -shell\n";
    print "Will print the value of the user's shell\n";
    print "\n\n";

    exit(0);
  }

sub change_parm  
  {
    my $key	    = shift;
    my $pwstr	    = shift;
    my @ptab	    = @_;
    my ($user,$pw,$uid,$gid,$gecos,$home,$shell) = split(/:/,$pwstr);
    my ($passwd,$pwage) = split(/,/,$pw);

    ###print "sub change_parm ($key,$pwstr,@ptab)\n";

    # Return the same string when the keyvalue doesn't match
    return ($pwstr) if ($key ne $user);

    # Set the new PW field values
    $user = ($user ne $ptab[0] && $ptab[0] ne "") ? $ptab[0] : $user;
    $pw   = ($passwd ne $ptab[1] && $ptab[1] ne "") ? $ptab[1] : $passwd;
    $age  = ($pwage ne $ptab[2] && $ptab[2] ne "") ? $ptab[2] : $pwage;
    $uid  = ($uid ne $ptab[3] && $ptab[3] ne "") ? $ptab[3] : $uid;
    $gid  = ($gid ne $ptab[4] && $ptab[4] ne "") ? $ptab[4] : $gid;
    $gecos = ($gecos ne $ptab[5] && $ptab[5] ne "") ? $ptab[5] : $gecos;
    $home = ($home ne $ptab[6] && $ptab[6] ne "") ? $ptab[6] : $home;
    $shell = ($shell ne $ptab[7] && $ptab[7] ne "") ? $ptab[7] : $shell;

    ###print "$user:$pw,$age:$uid:$gid:$gecos:$home:$shell\n";

    return ("$user:$pw,$age:$uid:$gid:$gecos:$home:$shell");
  }

sub disable_parm  
  {
    my $key	    = shift;
    my $pwstr	    = shift;
    my @ptab	    = @_;
    my ($user,$pw,$uid,$gid,$gecos,$home,$shell) = split(/:/,$pwstr);
    my ($passwd,$pwage) = split(/,/,$pw);

    # Return the same string when the keyvalue doesn't match
    return ($pwstr) if ($key ne $user);

    return ("$user:*:$uid:$gid:$gecos:$home:$shell");
  }

sub list_parm  
  {
    my $key	    = shift;
    my $pwstr	    = shift;
    my ($user,$pw,$uid,$gid,$gecos,$home,$shell) = split(/:/,$pwstr);
    my ($passwd,$pwage) = split(/,/,$pw);

    # Return the same string when the keyvalue doesn't match
    return if ($key ne $user);

    # Set the new PW field values
    printf "user => %s\n",$user;
    printf "passwd => %s\n",$passwd;
    printf "pw age => %s\n",$pwage;
    printf "user ID => %s\n",$uid;
    printf "group ID => %s\n",$gid;
    printf "gecos => %s\n",$gecos;
    printf "home => %s\n",$home;
    printf "shell => %s\n",$shell;

    return;
  }

