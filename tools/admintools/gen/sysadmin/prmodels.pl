#!/usr/bin/perl5

use strict;
use File::Copy;

###########################################################################

my($model_file) = "/tmp/model.out";


###########################################################################

my(%models);		# key=<model> value=<hostname>|<IP addr>
my($hostname,$modelstr);
my($node_addr,$a,$b,$c,$d,$lab);

open (MODEL,"<$model_file") or 
    die "$!: Can't open $model_file\n";

while (<MODEL>)
  {
    chop;
    ($hostname,$modelstr) = split(/:/,$_);
    $node_addr = (gethostbyname($hostname))[4];
    ($a,$b,$c,$d) = unpack('C4',$node_addr);
    $lab = "MTL"	if ( $c >= 80 && $c <= 87 );
    $lab = "FML_ETL"	if ( $c >= 88 && $c <= 95 );
    $lab = "INTEL"	if ( $a  == 192 );
    $models{$hostname} = "$modelstr|$lab";
  }

close(MODEL);

foreach (keys %models)
  {
    ($modelstr,$lab) = split(/\|/,$models{$_});
    print "$_   $modelstr   $lab\n";
  } 

exit(0);

