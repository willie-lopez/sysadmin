#!/usr/bin/perl5

use strict;
use Net::Ping;
use Time::localtime;

my($data_dir) = "/opt/whatsup";
my($host_file) = "$data_dir/node_list";
my($up_file) = "$data_dir/up";
my($down_file) = "$data_dir/down";


print STDOUT "\nLoading node test list, please wait ... \n";
open (NODELIST,"<$host_file") or die "$!";

my($host,$state,%hoststate);
my($down_count,$host_count) = 0;

while ($host = <NODELIST>)
  {
    chop($host);
    $hoststate{$host} = 0;		# 0=UP, 1=DOWN
    $host_count++;
  }

close(NODELIST);

open (UP,">$up_file") or die "$!\n";
open (DOWN,">>$down_file") or die "$!\n";

printf DOWN "%02d/%02d/%d %02d:%02d:%02d\n",
    localtime->mon+1,
    localtime->mday,
    localtime->year+1900,
    localtime->hour,
    localtime->min,
    localtime->sec;


print STDOUT "Testing nodes, standby ... \n";

foreach $host (keys %hoststate)
  {
    print "$host ... ?  ";
    my($p) = Net::Ping->new();
    if ( $p->ping($host) )
      {
	print "YES\n";
	print UP $host,"\n";
      }
    else
      {
	print "NO\n";
	print DOWN $host,"\n";
	$down_count++;
      }

    $p->close();
  }

print STDOUT "\nAll done. $down_count were down out of $host_count tested.\n";
print DOWN "\n\n";

close(UP);
close(DOWN);

exit(0);

