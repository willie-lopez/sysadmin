#!/usr/bin/perl5


my @nodelist;
open (LIST,"</opt/whatsup/node_list") or die "$0: $!";
while (<LIST>)
  {
    chop;
    next if ( /^[\s+#]/ );
    push(@nodelist,$_);
  }

close(LIST);

my %exclude = ();
open (EXCL,"</opt/whatsup/exclude") or die "$0:$!";
while (<EXCL>)
  {
    chop;
    $exclude{$_} = 1;
  }
close(EXCL);


# Global client name
my $client = "";

$SIG{'ALRM'} = sub { print $client,"TIMEOUT/"; die; };

my $nfs_status = "";
my $status = 0;				    # Unavailable

foreach $client (@nodelist)
  {
    next if ( $exclude{$client} == 1 );

    $status = 0;

    eval <<'END_OF_TIMEOUT';
    	print "\nChecking NFS availability on ",$client," ... ";
    	alarm(3);
	$nfs_status = `rpcinfo -u $client mountd`;
	$status = (index($nfs_status,"ready and waiting") > -1) ? 1 : 0;
	alarm(0);
END_OF_TIMEOUT
    $mesg = ($status == 1) ? "OK" : "FAILED";
    print $mesg;
  }

print "\n";
