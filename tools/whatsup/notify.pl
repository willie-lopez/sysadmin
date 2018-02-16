
sub notify
  {
    my	%down	= @_;
    my	$node	= "";
    my	($user_nodes,$mtl_nodes,$fml_nodes,$etl_nodes,$other_nodes) = "";
    my  ($gv_nodes) = "";

    foreach $node (sort(keys %down))
      {
	next if ( $ignoreList{$node} );
	next if ( $down{$node} % 10 != 0 );	# Notify only every 3rd time

	if ( $node =~ /^hpes/ )
	  {
	    $user_nodes = "!$node," . $user_nodes;
	  }
	elsif ( $node =~ /^mtl/ ) 
	  {
	    $mtl_nodes = "!$node," . $mtl_nodes;
	  }
	elsif ( $node =~ /^fml/ )
	  {
	    $fml_nodes = "!$node," . $fml_nodes;
	  }
	elsif ( $node =~ /^etl/ )
	  {
	    $etl_nodes = "!$node," . $etl_nodes;
	  }
	elsif ( $node =~ /^mtlg[cv]/ )
  	  {
	    $gv_nodes = "!$node," . $gv_nodes;
	  }
	else
	  {
	    $other_nodes = "!$node," . $other_nodes;
	  }
      }

    # Remove trailing comma (,)
    chop($user_nodes);
    chop($mtl_nodes);
    chop($fml_nodes);
    chop($etl_nodes);
    chop($other_nodes);

    # Do paging only during business hours and weeddays
    if ( localtime(time)->hour > 7 && localtime(time)->hour < 19 &&
	 localtime(time)->wday != 0 && localtime(time)->wday != 6 )
      {
	# Do paging only during business hours
    	if ( $user_nodes ne "" )
      	  {
	    `/usr/contrib/bin/fcpager stork,yvonne "$user_nodes"`;
	    `/usr/contrib/bin/fcpager erwin,todd "$user_nodes"`;
	    `/usr/contrib/bin/fcpager betters,bill "$user_nodes"`;
	    `/usr/contrib/bin/fcpager jenkins,matt "$user_nodes"`;
	    `/usr/contrib/bin/fcpager stone,corey "$user_nodes"`;
	    `/usr/contrib/bin/fcpager lopez,willie "$user_nodes"`;
      	  }

    	if ( $mtl_nodes ne "" )
      	  {
	    `/usr/contrib/bin/fcpager lopez,willie "$mtl_nodes"`;
	    `/usr/contrib/bin/fcpager burbank,robin "$mtl_nodes"`;
	    print "\nfcpager lopez,willie \"$mtl_nodes\"";
      	  }

    	if ( $fml_nodes ne "" )
      	  {
	    `/usr/contrib/bin/fcpager lopez,willie "$fml_nodes"`; 
	    `/usr/contrib/bin/fcpager anderson,larry "$fml_nodes"`; 
	    `/usr/contrib/bin/fcpager ross,maggi "$fml_nodes"`; 
	    print "\nfcpager lopez,willie \"$fml_nodes\"";
      	  }

    	if ( $etl_nodes ne "" )
      	  {
	    `/usr/contrib/bin/fcpager lopez,willie "$etl_nodes"`; 
	    `/usr/contrib/bin/fcpager doner,dan "$etl_nodes"`; 
	    print "\nfcpager lopez,willie \"$etl_nodes\"";
      	  }

    	if ( $other_nodes ne "" )
      	  {
    	    `/usr/contrib/bin/fcpager lopez,willie "$other_nodes"`; 
	    print "\nfcpager lopez,willie \"$other_nodes\"";
      	  }

    	if ( $gv_nodes ne "" )
      	  {
    	    `/usr/contrib/bin/fcpager stone,corey "$gv_nodes"`;
	    print "\nfcpager stone,corey \"$gv_nodes\"";
	    print "\nfcpager lopez,willie \"$gv_nodes\"";
	  }
      }


    print "\n";
    return;
  }

# Do not change or remove the next line (1;).
1;

