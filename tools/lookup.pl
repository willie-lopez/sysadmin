#!/usr/bin/perl5

use Socket;


# References from /usr/include/netdb.h
my @NETDBERR = qw(NO NOT_FOUND TRY_AGAIN NO_RECOVERY NO_DATA NO_ADDR);


sub lookup
  {
    my $token = shift;
    my $status = 1;
    my @addr;

    if ( $token =~ /[::num::].[::num::].[::num::].[::num::]/ )
      {
	# Do a reverse lookup
	$name = gethostbyaddr(inet_aton($token),AF_INTE);
      }
    else
      {
	# Do a forward lookup
	@addr = (gethostbyname($token))[4];
      }

    $exit_code = $?;
    return $exit_code;
  }

