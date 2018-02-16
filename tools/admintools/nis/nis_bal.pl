#!/usr/bin/perl5

#
#   Name:
#	nis_bal.pl - get and calculate the load on NIS servers
#
#   Syntax:
#	nis_bal.pl [ hTv ]
#
#	where
#	    -h       print usage/help screen
#	    -T	     run the load/binding test
#	    -v       print load percentage verification
#
#   Description:
#	nis_bal.pl is a crude way of seeing what the load balance is
#	across the NIS servers in an NIS domain.  The term "load
#	balance" refers to how many clients are bound to each server
#	and what percentage of the total number of NIS clients that 
#	quantity represents.
#
#   Returns:
#	0 - always
#   
#   See Also:
#	/usr/bin/ypcat
#	/usr/bin/ypwhich
#
#   Notes:
#	The load balance, although not explicity checked, is within
#	a single domain.  But given the weird nature of NIS, it is
#	possible that a client will really be part of another NIS
#	domain but reported as part of the current domain.
#
#   History:
#	05-21-2001	Willie Lopez		Initial creation.
#
#

use strict;
use Time::localtime;
use Getopt::Std;


##########################################################################

my($rev) = '$Id$';


##########################################################################


my(%opts);

getopt('hTV',\%opts);
my(@args) = keys %opts;
my($verify_load) = 0;

foreach (@args)
  {
    if ( $_ =~ /^T/ )
      {
    	print "\nTesting NIS load balance, please wait ... \n";
    	unlink("/tmp/ypwhich.out");
    	`rpush -l admin -f /opt/whatsup/up "ypwhich" >/tmp/ypwhich.out`;
      }
    elsif ( $_ =~ /^h/ )
      {
    	print "nis_bal.pl [ -hT ] \n";
	print "   -T  run an NIS load balance test\n";
	print "   -h  print this page\n";
	print "   -v  verify load percentage\n";
    	exit(0);
      }
    elsif ( $_ =~ /^V/ )
      {
	$verify_load = 1;
      }
    elsif ( $_ =~ /^v/ )
      {
	print "Version $rev\n";
	exit(0);
      }
  }




##########################################################################

printf "NIS Load Balance as of:  %02d/%02d/%d %02d:%02d:%02d\n",
	    localtime->mon+1,
	    localtime->mday,
	    localtime->year+1900,
	    localtime->hour,
	    localtime->min,
	    localtime->sec;



##########################################################################



my($ypline,$ypserver_count);
my(%ypservers);

open (YPCAT,"ypcat -k ypservers|") or
    die "$!: can't ypcat -k ypservers\n";

while ($ypline = <YPCAT>)
  {
    chop($ypline);
    $ypline = (split(/./,$ypline))[0];
    $ypservers{$ypline} = 0;
    $ypserver_count++;
  }

close(YPCAT);


##########################################################################


my($ypclient,$ypserver_name) = "";
my($total_ypclients) = 0;

open (YPWHICH,"</tmp/ypwhich.out") or 
    die "$!: can't open /tmp/ypwhich.out\n";

while ($ypline = <YPWHICH>)
  {
    next if ($ypline =~ /rcmd/ || $ypline =~ /ypwhich/ || $ypline =~ /remsh/);
    chop($ypline);
    $ypline =~ s/.fc.hp.com//g;
    ($ypclient,$ypserver_name) = split(/:/,$ypline);
    $ypserver_name =~ s/^\s+//g;
    $ypservers{$ypserver_name} += 1;
    $total_ypclients++;
  }

close(YPWHICH);


#########################################################################

my($ypload);
my($total) = 0;

foreach $ypserver_name (sort(keys(%ypservers)))
  {
    next if ($ypserver_name eq "");
    next if (!defined($ypservers{$ypserver_name}));
    next if ($ypserver_name =~ /lib/ );
    $ypload = ($ypservers{$ypserver_name}/$total_ypclients)*100;
    $total += $ypload;
    printf "%-8s:   %4d   %3.0f% \n", 
	$ypserver_name, $ypservers{$ypserver_name},$ypload;
  }

print "There are $total_ypclients clients bound to $ypserver_count servers\n";
printf "Total: %3.1f\n",$total if ( $verify_load == 1 );

#########################################################################

exit(0);

