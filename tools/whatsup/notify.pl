
sub notify
  {
    my	%down	= @_;
    my	$node	= "";
    my	($user_nodes,$build_nodes,$test_nodes,$tools_nodes,$other_nodes) = "";
    my  ($gv_nodes) = "";

    foreach $node (sort(keys %down))
      {
	next if ( $ignoreList{$node} );
	next if ( $down{$node} % 10 != 0 );	# Notify only every 3rd time

	if ( $node =~ /^user/ )  # Workstation nodes. Change name to fit.
	  {
	    $user_nodes = "!$node," . $user_nodes;
	  }
	elsif ( $node =~ /^build/ ) 
	  {
	    $build_nodes = "!$node," . $build_nodes;
	  }
	elsif ( $node =~ /^test/ )
	  {
	    $test_nodes = "!$node," . $test_nodes;
	  }
	elsif ( $node =~ /^tools/ )
	  {
	    $tools_nodes = "!$node," . $tools_nodes;
	  }
	else
	  {
	    $other_nodes = "!$node," . $other_nodes;
	  }
      }

    # Remove trailing comma (,)
    chop($user_nodes);
    chop($build_nodes);
    chop($test_nodes);
    chop($tools_nodes);
    chop($other_nodes);

    # Do paging only during business hours and weeddays
    if ( localtime(time)->hour > 7 && localtime(time)->hour < 19 &&
	 localtime(time)->wday != 0 && localtime(time)->wday != 6 )
      {
	# Do paging only during business hours
    	if ( $user_nodes ne "" )
      	  {
	    `/usr/contrib/bin/fcpager doe,jane "$user_nodes"`;
	    `/usr/contrib/bin/fcpager lopez,willie "$user_nodes"`;
      	  }

    	if ( $build_nodes ne "" )
      	  {
	    `/usr/contrib/bin/fcpager lopez,willie "$build_nodes"`;
	    print "\nfcpager lopez,willie \"$build_nodes\"";
      	  }

    	if ( $test_nodes ne "" )
      	  {
	    `/usr/contrib/bin/fcpager lopez,willie "$test_nodes"`; 
	    print "\nfcpager lopez,willie \"$test_nodes\"";
      	  }

    	if ( $tools_nodes ne "" )
      	  {
	    `/usr/contrib/bin/fcpager lopez,willie "$tools_nodes"`; 
	    print "\nfcpager lopez,willie \"$tools_nodes\"";
      	  }

    	if ( $other_nodes ne "" )
      	  {
    	    `/usr/contrib/bin/fcpager lopez,willie "$other_nodes"`; 
	    print "\nfcpager lopez,willie \"$other_nodes\"";
      	  }

    	if ( $gv_nodes ne "" )
      	  {
    	    `/usr/contrib/bin/fcpager lopez,willie "$gv_nodes"`;
	    print "\nfcpager lopez,willie \"$gv_nodes\"";
	  }
      }


    print "\n";
    return;
  }

# Do not change or remove the next line (1;).
1;

