#!/usr/bin/perl5

use strict;

###########################################################################
my $nodeListFile = "/tmp/up";
my @nodeList;
my $line = "";

open (NODELIST,"<$nodeListFile") or die "$!: can't open $nodeListFile\n";
while ($line = <NODELIST>)
  {
    chop($line);
    push(@nodeList,$line);
  }

close(NODELIST);

###########################################################################


my %hostTable;
my $hostName = "";
my ($ipaddr,$fqdn,$hostname,$comments) = "";

open (HOSTS,"/bin/ypcat hosts|") or 
    die "$!: can't ready NIS hosts table!\n";
while ($line = <HOSTS>)
  {
    chop($line);
    ($ipaddr,$fqdn,$hostname,$comments) = split(/\s+/,$line,4);
    next if ( $line !~ /15.6./ && $line !~ /192.25/ );
    $hostTable{$hostname} = $ipaddr;
  }

close(HOSTS);

##########################################################################

my $node_data;
my $node_type;
my $node_lab;
my $node_model;
my $node_name; 
my $rcmd = "";

foreach $node_name (@nodeList)
  {
    $rcmd = "remsh $node_name /bin/model";

    open (NODE,"${rcmd}|") or die "$!: can't run $rcmd\n";
    $node_data = <NODE>;
    $node_data =~ s/[\s+\n\t]//g; 

    $ipaddr = $hostTable{$node_name};
    $node_type = ($node_name =~ /^mtl/ || $node_name =~ /^fml/ || 
		  $node_name =~ /^etl/ || $node_name =~ /intg/ ) ? 
			"SV" : "WS";

    if ( $ipaddr =~ /15.6.8[012345]./ )
      {
	$node_lab = "MTL";
      }
    elsif ( $ipaddr =~ /192.25.20[79]./ )
      {
	$node_lab = "INTEL";
      }
    elsif ( $ipaddr =~ /15.6.8[89]./ || $ipaddr =~ /15.6.9[012345]/ )
      {
	$node_lab = "FML/ETL";
      }

    printf "%-8s   %-2s   %-7s   %s\n",
	    $node_name,$node_type,$node_lab,$node_data;
  }


exit(0);

