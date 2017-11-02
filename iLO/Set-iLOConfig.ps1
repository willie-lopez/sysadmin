
<#
.NAME
Set-ILOConfig.ps1 

.SYNOPSIS
	Set-iLOConfig -Domain <string> [arguments,...] 

	Call Set-iLOConfig.ps1 with at least the required parameter -Domain <string> where
	<string> is the name of the DNS domain (ie mydomain.com). You must run with either
	-Server <string> OR -ServerList <path> where -Servere <string> is the name of a single
	iLO name or IP address and -ServerList <string> is the name and path to a file 
	containing at least one iLO name or IP address. 

	Optionally, you can exclude one or more iLO names or IPs by putting the name or IP in
	an exclude file and calling the script with -Exclude <string> where <string> is the 
	path/name of the file containing iLOs to exclude.

	You can also choose to execute a verification of the iLO(s) by using the -Verify
	argument.

	Logging of changes or verification will be logged to a default logging location if
	you use the -Logging argument. The default location of the log file is in the user's 
	Downloads folder with the name Set-iLOConfig_<PID>.txt where PID is the value of
	the current session $PID. o

.DESCRIPTION
	This script allows you to update the configuration of iLOs. Those changes
	include only the DNS domain as defined by the -Domain <string> argument or
	DNS name as defined by the -DNS_Name <string> argument.

.PARAMETER Server
.PARAMETER ServerList

	Use only one of the parameters with the name of a single iLO or a file path
	containing a list of iLO devices to configure. 
	
.PARAMETER DNS_Name

	New name of the iLO to configure on the iLO defined by -Server <string>. 
	This is the short name of the iLO, not the FQDN of the iLO, though it should
	not harm operation of the iLO.

.PARAMETER Domain

	Name of the DNS domain to configure the iLO with (ie mydomain.com)

.PARAMETER Quiet 

	Quiet is a switch and when used will allow the configuration to take place
	without prompting the user to press ENTER.

.PARAMETER Verify

	Verify connects to the iLO(s) and gets the DNS_NAME and Domain already configured.
	No changes are made when this argument is used.

.PARAMETER Logging

	When -Logging is used, output that the user sees on the screen is also written to
	a default logging file at the user's Downloads folder with the name 
	Set-iLOConfig_<pid>.txt where pid is the PID number of the PowerShell session that
	ran.

.PARAMETER DisableDHCP

	When executed with this option, IPv4 DHCP will be disable when changing
	the domain name.

.NOTES
	This script does not support all versions of iLO. Changes are limited
	to iLO3 and newer.
	
	Created by Willie Lopez, willie.lopez@yahoo.com 
#>


param(	[Parameter(Mandatory=$False)][string]$Server, 	   # iLO to change (name or IP) 
		[Parameter(Mandatory=$False)][string]$ServerList,  # List of iLOs to change
		[Parameter(Mandatory=$False)][string]$DNS_Name,	   # Short name 
		[Parameter(Mandatory=$True)][string]$Domain,	   # Domain name 
		[Parameter(Mandatory=$False)][string]$Exclude,	   # Exclude from change
	 	[switch]$Quiet,                                    # No prompting
	 	[switch]$Verify,                                   # No prompting
		[switch]$Logging,                                  # Enable logging
		[switch]$DisableDHCP,							   # Disable IPv4 DHCP
	 	[switch]$Continue								   # Continue last session
     ) 



# To-do:
#	* Add a call to Get-Credential to ask the user for credentials 
#	  if the -Password switch is used on the command line or if the
#	  environment variable iLOPassword is empty or non-existent.
#	* Add functionality to convert the password into a secure string
#	  (should already be that when Get-Credential is used), encrypt
#	  the password, and store/read to/from environment variable. 
#	  Will have to decrypt the password for use with iLO. 
#	
# Change the credentials for your use. 
$ilo_user = "Admin"
$ilo_pw = ""


# Catch errors but continue and don't print them. Errors are
# handled privately within the code.
$Prev_ErrorActionPreference=$ErrorActionPreference 
$ErrorActionPreference=".silentlyContinue"




#################################################################################


# By default, the script will prompt to continue before applying changes.
$RUN_QUIET = $False


# Default logging 
$basename = ($MyInvocation.MyCommand.Name).split('.')[0] 
$SessionLogPath = $env:homepath + "\Downloads\${basename}_${pid}.txt"
$SessionStatus = $env:homepath + "\Downloads\.${basename}_session_status"   
$SessionList 


function UpdateSessionStatus
  {
  	param(	[Parameter(Mandatory=$True)][string]$Node )


	if (-not(test-path $SessionStatus)) 
	  {
	  	$tmpstat = new-item -path $SessionStatus -ItemType File 
	  }

	add-content -path $SessionStatus -value $Node
  }

function get-iloconfig 
  {
	param( [Parameter(Mandatory=$True)][string]$Server )
	
	$err=@()
	$warn=@()

	# Next, let's get the current iLO configuration 
	$x = Get-HPiLONetworkSetting -Username "$ilo_user" -Password "$ilo_pw" -Server $Server -EA SilentlyContinue -WA SilentlyContinue -ErrorVariable err -WarningVariable warn 

	
	return $x 
  }



# Ping iLO device. Return $True if UP and $False if not responding.
function pingilo 
  {
	param( [Parameter(Mandatory=$True)][string]$Server )

   
	# Try converting the Hostname to a IP 32 bit number. If successful,
	# the Hostname is an IP address and is a valid one. If conversion
	# fails, the value is a string hostname. 

	$lookup_byname = $True 
	try { $converted_ip_string = [IPAddress]$Server }
	catch { $NULL }


	$ipaddr = ""
	$dns_object = $null 

	# Now, Lookup the IP or Hostname in DNS
	try  { $dns_object = [System.Net.Dns]::GetHostEntry($Server) }
	catch  
	{
		$ipaddr = "No such host" 
		write-host -foreground Yellow "No such host $Server" 
	}
  
	# Next, let's make sure the host is responding.
	if ((test-connection -computername $Server -Quiet -count 1) -eq $False)
	  {
	  	return $False
	  }
  
	return $True
  } 



function update_dnsdomain 
  {
	param( 	[Parameter(Mandatory=$True)]$Server,
			[Parameter(Mandatory=$True)]$Domain,
			[switch]$Quiet
		 ) 

	$cur_config = get-iloconfig -Server $Server 
	if ( $cur_config -eq $null )
	  {
		write-host "Unable to get iLO config for $Server"
	    $str_formatted = "iLO: {0,-18} :: {1,-33} `t{2,-23}" -f $Server,"Failed","Failed"
		if ($Logging) { add-content -Path $SessionLoggingPath -Value $str_formatted } 
		return 
	  }

  
	# Update DNS domain configuration 
	$cur_ilo_name = $cur_config.DNS_NAME
	$cur_ilo_domain_name = $cur_config.DOMAIN_NAME 
	
	write-host -foreground Gray  "`nCurrent iLO Configuration for Servr ${Server}: "
	write-host -foreground Gray  "     DNS_NAME      = $cur_ilo_name "
	write-host -foreground Gray  "     DOMAIN_NAME   = $cur_ilo_domain_name "
	$str_formatted = "Current iLO: {0,-18} :: {1,-33} `t{2,-23}" -f $Server,$cur_ilo_name,$cur_ilo_domain_name
	if ($Logging) { add-content -Path $SessionLogPath -Value $str_formatted }
	
	write-host -foreground Green " New iLO DNS Configuration for Server ${Server}: "
	write-host -foreground Green "      DNS_NAME     = $cur_ilo_name "
	write-host -foreground Green "      DOMAIN_NAME  = $Domain "
	$str_formatted = "New iLO: {0,-18} :: {1,-33} `t{2,-23}" -f $Server,$cur_ilo_name,$Domain
	if ($Logging) { add-content -Path $SessionLogPath -Value $str_formatted } 

	if (-not($RUN_QUIET))
	  {
		read-host -prompt "Press ENTER to continue configuring iLO $Server (or ctl-c to exit)"
	  }

	write-host -foreground Yellow "`n`nSetting iLO network configuration. This could take a few minutes ... "

	# Set the new Domain and wait for it to complete 
	if ($DisableDHCP)
	  {
		Set-HPiLONetworkSetting -Username "$ilo_user" -Password "$ilo_pw" -Server $Server -Domain $Domain -DHCPEnable "off"
	  }
	else
	  {
	    # Default
	    Set-HPiLONetworkSetting -Username "$ilo_user" -Password "$ilo_pw" -Server $Server -Domain $Domain
	  }

	sleep 60

	# Now reset the iLO to commit change and then wait for it to complete
	Reset-HPILORIB -Server $Server -Username "$ilo_user" -Password "$ilo_pw" 
	sleep 60
	

	# Finally, verify the changes were applied 
	$new_config = get-iloconfig -Server $Server 
	if ( $new_config -eq $null )
	  {
		$str_formatted = "Verified iLO: {0,-18} :: {1,-33} `t{2,-23}" -f $Server,"Failed_Connection","Failed_Connection"
		write-host "Unable to get iLO config for $Server, exiting!"
		if ($Logging) { add-content -Path $SessionLogPath -Value $str_formatted }
	  	return
	  }
	
	$new_ilo_name = $new_config.DNS_NAME
	$new_ilo_domain_name = $new_config.DOMAIN_NAME 
	$str_formatted = "Verified iLO: {0,-18} :: {1,-33} `t{2,-23}" -f $Server,$new_ilo_name,$new_ilo_domain_name
	
	if ($Domain -ne $new_ilo_domain_name)
	  {
		$str_formatted = "Failed iLO: {0,-18} :: {1,-33} `t{2,-23}" -f $Server,$cur_ilo_name,"Failed_Domain_Config"
		write-host -foreground Red $str_formatted 
		if ($Logging) { add-content -Path $SessionLogPath -Value $str_formatted }
	  }
	
	return
  }
  
  


########################################################################################
########################################################################################


# If -Continue session is not defined, remove the previous session file
# and start over; otherwise, continue from where we left off before. This
# saves not having to start from the beginning if the script crashes 
# because of a connection problem to an iLO. When processing list, any
# node in the $SessionList will be ignored.

if ($Continue)
  {
  	# Read previous contents from session file
  	if (test-path $SessionStatus)
	  {
	  	$SessionList = get-content $SessionStatus
	  }
	else
	  {
	  	$tmpstat = new-item -path $SessionStatus -ItemType File 
	  }
  }
else
  {
  	# Reset session file
  	remove-item -path $SessionStatus
	$tmpstat = new-item -path $SessionStatus -ItemType File 
  }
  	


# Set Quiet so no prompting required
if ($Quiet) { $RUN_QUIET = $True } 

# Notify session logging 
if ($Logging) 
  { 
    $RunTime = date -UFormat "%D-%T"
  	write-host -foreground Gray "Session being logged to $SessionLogPath"
	add-content -Path $SessionLogPath -Value "`nRuntime: $RunTime "
  }



# -Server or -ServerList are mutually exclusive
if ($Server) 
  {
  	$NodeList = $Server
  }
elseif ($ServerList) 
  {
  	$NodeList = (get-content -path $ServerList) | %{ $n = $_.split(' ')[0]; $n } 
  }
else
  {
  	write-host -foreground Red "You must specify one: -Server <string> OR -ServerList <path>"
	exit 1
  }


# Look for exclusions
if (($Exclude) -and (test-path -path $Exclude)) 
  {
    $ExcludeList = get-content -path $Exclude
  }


foreach ($ServerName in $NodeList)
  {
  	# Skip excluded iLOs but show they are excluded in the output, just don't check them
	if ($ExcludeList -contains "$ServerName") 
	  {
	  	$tmp_name = "Excluded"
		$tmp_domain = "Excluded"
		$str_formatted = "iLO: {0,-18} :: {1,-33} `t{2,-23}" -f $ServerName,$tmp_name,$tmp_domain
		write-host $str_formatted
		
		if ($Logging) { add-content -path $SessionLogPath -Value $str_formatted } 
		continue
	  }


	# First, let's make sure the iLO device is responding 
	if ((pingilo -Server $ServerName) -eq $False)
  	  {
		write-host "iLO $ServerName is not responding, exiting!"
		exit 1
  	  }

	if ($Verify)
  	  {
		$tmp_ilo = get-iloconfig -Server $ServerName 
		
		if ($tmp_ilo -eq $Null)
		  {
			$str_formatted = "iLO: {0,-18} :: {1,-33} `t{2,-23}" -f $ServerName,"Failed","Connect_Failure" 
		  	write-host -foreground Yellow "`n"$str_formatted"`n"
			if ($Logging) { add-content -path $SessionLogPath -Value $str_formatted } 
			continue
		  }

		if ($tmp_ilo -and $tmp_ilo.STATUS_TYPE -ne "ERROR")
  	  	  {
			$tmp_name = $tmp_ilo.DNS_NAME
			$tmp_domain = $tmp_ilo.DOMAIN_NAME

			if ($tmp_name.Length -eq 0) { $tmp_name = "DNS_Name_Not_Set" }
			if ($tmp_domain.Length -eq 0) { $tmp_domain = "Domain_Not_Set" }
			$str_formatted = "iLO: {0,-18} :: {1,-33} `t{2,-23}" -f $ServerName,$tmp_name,$tmp_domain
			write-host -foreground Yellow "`n"$str_formatted"`n"
			if ($Logging) { add-content -path $SessionLogPath -Value $str_formatted } 
  	  	  }
		else
		  {
			$tmp_name = $tmp_ilo.HOSTNAME 
			if ($tmp_ilo.STATUS_MESSAGE -ne "") 
			  { 
			    $tmp_domain = ($tmp_ilo.STATUS_MESSAGE).replace(' ','_')
			  }
			else
			  {
			  	$tmp_domain = "Unknown_Failure"
			  }

			$str_formatted = "iLO: {0,-18} :: {1,-33} `t{2,-23}" -f $ServerName,$tmp_name,$tmp_domain
			write-host -foreground Yellow "`n"$str_formatted"`n"
			if ($Logging) { add-content -path $SessionLogPath -Value $str_formatted } 
  	  	  }
		  	
  	  }
	else
  	  {
		# Skip any ServerName in SessionList 
		if ($SessionList -contains $ServerName) { continue }
  	    update_dnsdomain -Server $ServerName -Domain $Domain 
		UpdateSessionStatus -Node $ServerName
  	  }
  }



#######################################################################################
  
exit 0
