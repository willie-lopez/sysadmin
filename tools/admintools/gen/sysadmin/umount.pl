#!/usr/bin/perl5

use strict;
use Time::localtime;
use File::Basename;
use Getopt::Long;


##################################################################################
#   Global definitions.
my $faults_log		= "/tmp/nfs_umount.log";# Error log file
my $client_list_file	= "/tmp/clients";	# List of clients to run on
my $verbose		= 0;			# Run without verbosity
my $worm		= 0;			# Run on just one client


##################################################################################
#   Verify the user ID is root
my $prog_nm = basename ($0);
my $real_id = $<;

die "Must be root to run $prog_nm ...\n"
    if ($real_id != 0);


##################################################################################
#   Get the server list to unmount.  The servers are delimited by the : or , 
#   character.

my (@server_list,@client_list);
getargs();

print "Running in verbose mode\n" if ($verbose == 1);

die "No server(s) defined to unmount from clients\n"
    if ($#server_list+1 == 0);


##################################################################################
#   Perform the unmount of the NFS servers.  This will be done iteravely
#   until either no mounts are mounted, or 3 successive tries have occurred.
#   Any servers that failed to unmount will be logged.  

my $server_nm;

foreach $server_nm (@server_list)
  {
    print "Calling unmount_server($server_nm) ...\n" if ($verbose == 1);
    print "Failed to unmount NFS server $server_nm\n"
    	if (unmount_server($server_nm) != 0)
  }

print "NFS unmount process completed\n";
exit(0);

################################################################################
################################################################################

sub unmount_server 
  {
    my	$server_nm	= shift;
    my	$status		= 0;

    return (0) if (ismounted($server_nm) == 0);
    
    print "In unmount_server: attempting to umount server $server_nm \n"
    	if ($verbose == 1);

    my $mount_pt;

    # Remove the server's mount directory by directory in reverse order
    foreach $mount_pt (getmountsbynm($server_nm))
      {
	print "Calling unmount_nfsdir ($server_nm,$mount_pt)\n" 
	    if ($verbose == 1);
	if (unmount_nfsdir ($server_nm,$mount_pt) != 0)
	  {
	    print "Failed to NFS unmount $server_nm mounted as $mount_pt\n";
	    $status = 1;
	    last;		    # No point in trying to umount what's left
	  }
      }

    # Even though an unmount of an NFS dir failed, it is possible the
    # server unmount function will succeed.  
    print "Calling umount_nfsserver ($server_nm)\n" if ($verbose == 1);
    $status = unmount_nfsserver ($server_nm);

    print "Unable to unmount NFS server $server_nm\n"
    	if ($status == 1);

    print "Leaving unmount_server\n" if ($verbose == 1);

    return ($status);
  }

sub getmountsbynm
  {
    my	$server_nm		= shift;
    my	$mount_tab_status	= "/usr/sbin/mount -p";
    my	@mount_table;
    my	$mntent;
    my	$mntdirnm;

    print "In getmountsbynm: getting mounts for $server_nm\n" 
	if ($verbose == 1);

    if (open (MOUNT,"${mount_tab_status}|"))
      {
	@mount_table = grep(/^$server_nm/,<MOUNT>);
	close (MOUNT);
	for (my $i=0;$i<$#mount_table+1;$i++) 
	  { 
	    $mount_table[$i] = (split(/\s+/,$mount_table[$i]))[1];
	    print "adding nfsdir ",$mount_table[$i]," to unmount\n" 
		if ($verbose == 1);
	  }
      }
    else
      {
	printf "Couldn't get status of /etc/mnttab:$!\n";
      }
    
    print "Leaving getmountsbynm\n" if ($verbose == 1);

    # Return mount table containing only the entries for the named server
    return (@mount_table);
  }

sub ismounted 
  {
    my	$server_nm  = shift;
    my	@mount_table;
    my	$status	    = 0;

    print "In ismounted: checking if $server_nm is mounted\n" 
	if ($verbose == 1);

    if ($server_nm ne "")
      {
    	@mount_table = getmountsbynm($server_nm);
	$status = 1 if ($#mount_table+1 > 0);
	print "Is $server_nm mounted? mount status = <$status>\n" 
	    if ($verbose == 1);
      }
    
    print "Leaving ismounted\n" if ($verbose == 1);

    return ($status);
  }

sub unmount_nfsdir
  {
    my	$server_nm  = shift;
    my	$nfsdir	    = shift;
    my	$status	    = 0;
    my	$verif_cnt  = 0;
    my	(@tmp_mounts,$mnt);

    print "In unmount_nfsdir: server=<$server_nm>, nfsdir=<$nfsdir>\n" 
	if ($verbose == 1);

TRY_UMOUNT:

    # Reset status flag
    $status = 0;

    # Attempt to kill any processes that are binding this NFS dir
    system ("/usr/sbin/fuser -ck $nfsdir");
    print "Ran fuser -ck $nfsdir\n" if ($verbose == 1);

    # Do the unmount of the nfs dir
    system ("/usr/sbin/umount $nfsdir");
    print "Ran umount $nfsdir\n" if ($verbose == 1);

    # Check if the unmount was successful.  If the nfsdir is 
    # found in the mount table, then it was unsuccessful.

    foreach $mnt (getmountsbynm ($server_nm))
      {
	if ( $mnt =~ /$nfsdir$/ )
      	  {
	    print "Found $nfsdir still mounted\n" if ($verbose == 1);
	    $status = 1;
	    last;
      	  }
      }

    $verif_cnt += 1 if ($status == 1);
    goto TRY_UMOUNT if ($verif_cnt < 4 && $status == 1);

    log_umountmsg ("Failed to umount NFS dir $nfsdir") if ($status == 1);
    print "Leaving unmount_nfsdir\n" if ($verbose == 1);

    return ($status);		    # Returns 0 if successful, 1 if unsuccessful
  }

sub unmount_nfsserver
  {
    my	$server_nm	= shift;
    my	$status		= 0;
    my	$verif_cnt	= 0;

    print "In unmount_nfsserver: server_nm=<$server_nm> \n" if ($verbose == 1);

TRY_SERVER:
    system ("/usr/sbin/umount -h $server_nm -a");
    print "Ran umount -h $server_nm -a\n" if ($verbose == 1);

    my @tmp_mnttab = getmountsbynm ($server_nm);
    $status = ($#tmp_mnttab+1 == 0) ? 0 : 1;

    print "Is server $server_nm still mounted?  mount status=<$status>\n" 
	if ($verbose == 1);

    $verif_cnt += 1 if ($status == 1);
    goto TRY_SERVER if ($verif_cnt < 4 && $status == 1);

    log_umountmsg ("Failed to umount NFS server $server_nm") if ($status == 1);
    print "Leaving unmount_nfsserver\n" if ($verbose == 1);

    return ($status);
  }

sub log_umountmsg 
  {
    my	$umount_msg	= shift;
    my	$client_nm;
    my	$logtime	= getdatetime();
    my	$eventtime	= getdatetime();

    print "In log_umountmsg: unmount mesg=<$umount_msg>\n" if ($verbose == 1);

    if (open(LOG,">>$faults_log"))
      {
	printf LOG "FAULT_ERR | LGTIME=%s | EVTIME=%s | %s ($prog_nm)\n",
		$logtime,$eventtime,$umount_msg;
	close (LOG);
	print $umount_msg,"\n";
      }
    else
      {
	print "Could not open $faults_log for writing:$!\n";
      }

    print "Leaving log_umountmsg\n" if ($verbose == 1);

    return;
  }

sub getdatetime
  {
    print "In getdatetime: \n" if ($verbose == 1);

    my $datetime = sprintf "%02d/%02d/%d-%02d:%02d:%02d", 
	    localtime->mon()+1, localtime->mday(), localtime->year() + 1900, 
	    localtime->hour(), localtime->min(), localtime->sec(); 

    print "Leaving getdatetime ($datetime)\n" if ($verbose == 1);

    return ($datetime);
  }

sub getserverlist
  {
    my	$serverlistfile	= shift;
    my	@server_list;
    
    print "In getserverlist: from server list file <$serverlistfile>\n" 
	if ($verbose == 1);

    if (open(LIST,"<$serverlistfile"))
      {
	@server_list = <LIST>; close (LIST); chomp (@server_list);
      }
    else
      {
	print "Could not open server list file $serverlistfile\n";
      }

    print "Leaving getserverlist\n" if ($verbose == 1);

    return (@server_list);
  }

sub getargs 
  {
    my	$verbose_flag	    = 0;
    my	$worm_flag	    = 0;
    my	$server_list_nm     = "";
    my	$server_list_type   = "file";
    my	$client_list_nm	    = "";
    my	$help_flag	    = 0;
    my	$node_nm	    = "";

    my %longopts    = 	(
			"v"	    => 	\$verbose_flag,
			"worm"	    => 	\$worm_flag,
			"servers=s" =>	\$server_list_nm,
			"clients=s" =>	\$client_list_nm,
			"node=s"    =>	\$node_nm,
			"help"	    =>	\$help_flag
			);

    print_help() if (!GetOptions(%longopts) || $help_flag);

    $verbose = 1 if ($verbose_flag);
    $worm = 1 if ($worm_flag);
    $client_list_file = $client_list_nm	if ($client_list_nm);

    if ($server_list_nm)
      {
    	@server_list = getserverlist($server_list_nm);
      }
    elsif ($node_nm)
      {
	@server_list = split(/[:,]/,$node_nm);
      }
    
    return;
  }

sub print_help
  {

    print "\nUsage: $prog_nm [args ...]\n";
    print "\n";
    print "--v                  - run in verbose mode\n";
    print "--worm               - run as a worm across clients\n"; 
    print "--servers file       - list of servers to unmount\n";
    print "--clients file       - list of clients to unmount servers from \n";
    print "--node hostname      - NFS server(s) to unmount from client\n";
    print "                       more than one server can be defined by separating\n";
    print "                       the list by a colon (:) character or comma (,)\n";
    print "--help               - print this help screen\n";
    print "\n";
    print "Most common usage in a lab environment: \n";
    print "\n $ $prog_nm --worm --clients /tmp/client_list --servers /tmp/servers\n";
    print "\n";

    exit(0);
  }

