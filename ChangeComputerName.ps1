Import-module ActiveDirectory # This allows for you to use Active Directory commands

Function checkSPN($machinename)
{
    $results = setspn -l $machinename | Select-String "SQLEXPRESS"
    ForEach($line in $results)
    {
        $spn = $line.ToString().Trim()
        setspn -d $spn $machinename
        # This can take a while, so let's pause a tic...
        echo ""
        echo "Please wait, had to update SPN...."
        Start-Sleep -Seconds 30
    }
}

# This compares the current time to 11:59:59 PM and returns the difference in seconds
Function getTimeToMidnight () {
    $midnight = "23:59:59"
    $timeNow = Get-Date -Format HH:mm:ss
    $timeToMidnight = New-TimeSpan $timeNow $midnight 
    $timeToMidnight = $timeToMidnight.TotalSeconds

    return $timeToMidnight
}

[cmdletbinding()]

$continue = "Y"


# Begins loop to rename multiple computers/CSV lists.

While ($continue -like "Y") {

    # Prompts user to select single input or csv renaming.

    $oneorcsv = read-host "Would you like to rename single machines or a CSV list? (S=Single C=CSV E=Exit)"

    # Begins loop for CSV renaming if C was selected.
    # CSV file you intend to use needs to have the headings OldName and NewName

    If ($oneorcsv -like "C")
        {
            $csvfilepath = read-host "Type the path to your csv file"
            $domcred = Get-Credential
            
            try {get-item $csvfilepath}
            Catch {Write-host "Incorrect File Path"}
                
            import-csv $csvfilepath | foreach-object -process {
                $computername = $_.OldName;
                $newname = $_.NewName;
            
                            
            # Attempts to rename each computer in the CSV and returns a success or failure message.
                           
            Write-host "Renaming computer from $computername to $newname"
            checkSPN $computername
                
            Try {
                Rename-Computer -ComputerName $computername -NewName $newname -DomainCredential $domcred -Restart -ErrorAction Stop;
                Write-Host "SUCCESS! $computername is now named $newname" -ForegroundColor "Green"
            }
            Catch {
                write-host "FAILURE! Could not rename $computername to $newname" -ForegroundColor "Red"
            }
                            
         }
         
         $continue = read-host "Would you like to continue using a csv list or switch to renaming single computers? (S=Single C=CSV E=Exit)"     
    }

    # Begins loop for single computer renaming

    if ($oneorcsv -like "S")
        {
            $computername = read-host "What computer would you like to rename?"

            # Accepts computer name from user and checks to see if it is a valid domain computer

            try {
                Get-ADComputer $computername
            }
            catch { 
                Write-host "$computername is not a valid computer on this domain." -ForegroundColor "Red"
                write-host "Ending rename operation..." -ForegroundColor "Red"
                Pause
                break
            }

            $newname = read-host "What would you like to name $computername ?"

            # Prompts user for new computer name and attempts to rename it

            try {
                checkSPN $computername
                ping $computername;
                Rename-Computer -ComputerName $computername -NewName $newname -DomainCredential (get-credential) -Force -ErrorAction Stop
           
                # Returns success or failure message depending on outcome

                Write-host "Success! $computername is now named $newname" -ForegroundColor "Green"

            }
            Catch { 
                write-host "FAILED! Could not rename $computername to $newname" -ForegroundColor "Red"
                Pause
                break
            }

            # Prompts user to restart now or overnight
            # New Addition 7/16/18 -Trevor Pierce
            $restartChoice = read-host "For the name change to take, the computer will need to be restarted. Restart (N=Now O=Overnight)"
            $valid = "false"

            do {
                if ($restartChoice -like "N") {
                    try {
                        Restart-Computer -ComputerName $computername

                        Write-host "Success! $computername has been restarted" -ForegroundColor "Green"
                        $valid = "true"
                        }
                    Catch { 
                        Write-host "FAILED! $computername was unable to be restarted" -ForegroundColor "Red"
                        Pause
                        break
                    }
                 }
                elseif ($restartChoice -like "O") {
                    try {
                        $restartTime = getTimeToMidnight # This calls the function to get the difference from now to midnight in seconds
                        
                        # This section writes the computer name and time until restart to a text file for the batch file to read
                        $computername | Out-File -FilePath "\\bl-dfs1\BL-CTS\Scripting\ScheduleRestart.txt"
                        $restartTime | Out-File -FilePath "\\bl-dfs1\BL-CTS\Scripting\ScheduleRestart.txt" -Append

                        # This calls a batch file, which gets the inforation from the file above to restart the computer at 11:59:59 PM 
                        Start-Process -FilePath "\\bl-dfs1\BL-CTS\Fun With Scripting\ScheduledRestart.bat" -Verb runAs

                        Write-Host "This computer has been scheduled to restart tonight at 11:59:59 PM" -ForegroundColor "Green"
                        Write-Host "and will take the name change after this" -ForegroundColor "Green"
                        $valid = "true"
                     } Catch { 
                        Write-host "FAILED! $computername was unable to be scheduled to restart overnight" -ForegroundColor "Red"
                     }
                } else {
                    Write-Host "Invalid entry!" -ForegroundColor "Red"
                    $restartChoice = Read-Host "For the name change to take, the computer will need to be restarted. Restart (N=Now O=Overnight)"
                }
            } until ($valid -like "true")
                
            # Prompts user to continue or exit
            $continue = Read-Host "Would you like to rename another computer? (Y\N)"    
    }

    If ($oneorcsv -like "E") {break}
}