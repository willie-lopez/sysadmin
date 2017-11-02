
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
