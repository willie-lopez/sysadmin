#!/bin/ksh

#  Get fibre channel device file status.  wjl

#   Get the possible fibre cards
fccards=`ls /dev/fcms*`
if [ "$fccards" = "" ]; then
    echo "$0: No /dev/fcms* cards found on this node"
    exit 1
fi


#   Check that ioscan can see the cards (time consuming)
/usr/sbin/ioscan -fnCfc | grep -q CLAIMED 
