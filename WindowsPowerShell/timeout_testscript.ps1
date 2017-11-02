
<#
.NAME
	timeout_testscript 

.SYNOPSIS
	Test script showing how to run a background job and use a timeout
	to prevent the job from running indefinitely. 

.PARAMETER Timeout
	By default the timeout is 30 seconds, after which time the background
	job will self terminate or be interrupted. You can define this timeout
	value in seconds to be any number you wish, but not more than what is 
	needed. 

.HISTORY
	11-02-2017	Willie Lopez	Initial code and commit.
#>

param( [int32]$Timeout=30 )

$d1 = get-date

$WorkJob = Start-Job -Name "WorkJob" -ScriptBlock { ping 10.0.2.25 } 
$WorkJob | Wait-Job -Timeout $Timeout 

$d2 = get-date
Stop-Job -Name "WorkJob"
get-job
$runtime = $d2-$d1

$JobResults = if ($WorkJob.State -eq "Completed") 
	{
	  receive-job -Name "WorkJob" 
	}
  else
    {
	  "Timed out"
    }

remove-job -force *

"`nRuntime was $($runtime.Seconds) seconds`n"
"`nResults: $JobResults"
