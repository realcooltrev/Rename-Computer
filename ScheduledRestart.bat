@echo off
setlocal enabledelayedexpansion

REM This batch file will schedule a computer restart at 11:59:59 PM
REM for the computer specified in ChangeComputerName.ps1
SET computerName=''
SET restartTime=''
SET /a counter=0


for /f %%c in ('type "\\bl-dfs1\BL-CTS\Scripting\ScheduleRestart.txt"') do (
	
	if !counter! == 0 (
		SET computerName=%%c 
	) 
	
	if !counter! == 1 (
		SET restartTime=%%c 
	)
	
	set /a counter += 1
)

shutdown.exe -r -f -m \\!computerName!  -t !restartTime!

