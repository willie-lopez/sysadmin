#!/usr/bin/perl5

use strict;

############################################################################

my($rev) = '$Id: ckpwfile.pl,v 1.3 2001/03/20 18:46:45 wjl Exp $';

if ($ARGV[0] eq "-rev")
  {
    print $rev,"\n";
    exit(0);
  }


############################################################################

my($pwline,@pwdata);
my($cnt) = 0;
my(@nfsusers_dir,%nfsusers);

#  Load the /nfsusers directory listing
chomp(@nfsusers_dir = `ls /net/hpestul/mnt/nfsusers`);
foreach (@nfsusers_dir)
  {
    $nfsusers{$_} = 0;
  }


############################################################################


my $run_time = localtime(time);
printf "\n [ NIS Password Entry Verification on $run_time ] \n";



############################################################################

my ($intel_cnt) = 0;
my (@improper_disabled,@missing_gecos,@missing_passwd,@missing_lognm);
my (%password);

open (PW,"ypcat passwd |") or die "$!";
while ($pwline = <PW>)
  {
    chop($pwline);
    @pwdata = split(/:/,$pwline);
    ++$cnt;

    push(@missing_lognm,$pwdata[2]) if ($pwdata[0] eq "");
    push(@missing_passwd,$pwdata[0]) if ($pwdata[1] eq "");
    push(@missing_gecos,$pwdata[0]) if ($pwdata[4] eq "");

    if ($pwdata[1] eq "*")
      {
	if (($pwdata[5] !~ /null/ && $pwdata[6] =~ /false/) ||
	    ($pwdata[5] =~ /null/ && $pwdata[6] !~ /false/) ||
	    ($pwdata[5] !~ /null/ && $pwdata[6] !~ /false/))
	  {
	    push(@improper_disabled,$pwdata[0]);
	  }
      }

    $password{$pwdata[0]} = $pwdata[2];
    $nfsusers{$pwdata[0]} = 1;
    $intel_cnt++ if ($pwdata[4] =~ /INTEL/);
  }

close(PW);


###########################################################################
#  Check the /nfsusers directory against what is in the NIS password file.

my (@bad_nfsusers);
delete($nfsusers{'lost+found'});

foreach (keys %nfsusers)
  {
    push(@bad_nfsusers,$_);
  }



############################################################################
#  Compare the mail aliases file with the passwd file

my (%aliases,$alias_name,$alias_addr);
my (@bad_aliases);

open (ALIASES,"</etc/mail/aliases") or die "$!: Can't open /etc/mail/aliases\n";
while (<ALIASES>)
  {
    chop($_);
    $_ =~ s/\s+//g;
    next if ( $_ !~ /:/ );
    next if ( $_ =~ /domo/ );
    ($alias_name,$alias_addr) = split(/:/,$_);
    $aliases{$alias_name} = $alias_addr;
  }

close(ALIASES);





############################################################################
#  Print the exceptions report

foreach (@missing_lognm)
  {
    print "User ID is missing the lognm (field[0]): $_ \n";
  }

print "\n";

foreach (@missing_passwd)
  {
    print "Password field (field[1]) is empty for user: $_ \n";
  }

print "\n";

foreach (@missing_gecos)
  {
    print "Gecos field (field[4]) is empty for user: $_ \n";
  }

print "\n";

foreach (@improper_disabled)
  {
    print "Account is improperly disabled (fields[5,6]): $_ \n";
  }

print "\n";

# Get the last modification time of /nfsusers/<user> dir
# for each key's value being equal to 0.  Valid /nfsusers 
# directories will stay valued as 1. 

my ($nfs_path);
foreach (keys %nfsusers)
  {
    $nfs_path = "/net/hpestul/mnt/nfsusers/$_";
    $nfsusers{$_} = (stat($nfs_path))[9] if ($nfsusers{$_} == 0);
  }

# Print the users who have an /nfsusers dir but are not 
# in the password file. Users in this case have a time 
# stamp associated with their key.

my ($time_st);
my (@newkeys) = sort { $nfsusers{$a} <=> $nfsusers{$b} } keys %nfsusers;

foreach (@newkeys)
  {
    $time_st = localtime($nfsusers{$_}) if ($nfsusers{$_} > 1);
    print "User has an /nfsusers dir but is not in passwd file: $_  $time_st\n"
	if ($nfsusers{$_} > 1);
  } 


print "\n";
my (@tmp);
my (@alias_keys) = values(%aliases);

foreach (keys %aliases)
  {
    #next if ( $_ =~ /[_]/ );
    next if ( $_ =~ /#/ );
    if ( $_ =~ /_/ )
      {
	@tmp = grep(/$_/,@alias_keys);
	next if ($#tmp+1 > 0);
      }

    print "User has an alias but is not in the passwd file: $_ \n"
	if (!defined($password{$_}));
  }

exit(0);

