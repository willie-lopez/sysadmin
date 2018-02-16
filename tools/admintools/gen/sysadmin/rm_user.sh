#!/bin/ksh

searchOnly=0
delUser=0

while [ $# -gt 0 ]; do
    arg=$1
    case "$arg" in
    -s)	# Search only
	searchOnly=1
	shift;;
    -r)	# Remove user from .rhosts
	delUser=1
	shift;;
    -u)	# User ID to remove
	userID=$2
	shift 2;;
    esac
done

echo "Search=<$searchOnly>  Delete=<$delUser>  userID=<$userID>"
exit 0

