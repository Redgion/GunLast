@echo off
cd /d "%~dp0"
rem Colors
set CNormal=[36m
set CWarning=[33m
set CError=[31m
set CSuccess=[32m
set CInfo=[37m
rem Version number
set versionnum=17
title Outlast Level Launcher v%versionnum%

if not exist ./OutlastLauncher.exe (
	echo %CError%script is not installed in the correct directory.
	TIMEOUT /T 3 /nobreak > NUL
	exit /b
)

if not exist ".\backup" (
	echo %CError%Backup folder not detected, creating folder.
	mkdir .\backup\
	Echo %CSuccess%Backup folder created.
	echo.
)

if not exist ".\backup\Config\" mkdir .\backup\Config\
if not exist ".\backup\Localization\" mkdir .\backup\Localization\
if not exist ".\backup\Movies\" mkdir .\backup\Movies\
if not exist ".\backup\SaveData\" mkdir .\backup\SaveData\
if not exist ".\PlayerModels\" mkdir .\PlayerModels\
if not exist ".\PlayerModels\Configs\" (
	mkdir .\PlayerModels\Configs\BaseGame
	robocopy .\OLGame\config\ .\PlayerModels\Configs\BaseGame\ DefaultGame.ini > nul
	mkdir .\PlayerModels\Configs\PlayerModelGame
	robocopy .\OLGame\config\ .\PlayerModels\Configs\PlayerModelGame\ DefaultGame.ini > nul
)

if not exist ".\custom" (
	echo %CError%Custom Campaign folder not detected, creating folder.
	mkdir .\custom\
	Echo %CSuccess%Custom Campaign folder created.
	echo.
)

if not exist ".\OLGame\CookedPCConsole\Custom" (
	echo %CError%Custom map folder not detected, creating folder.
	mkdir .\OLGame\CookedPCConsole\Custom\
	Echo %CSuccess%Custom Campaign folder created.
	echo.
)

rem Check if computer is 32bit
set IsJayPC=false
if %PROCESSOR_ARCHITECTURE% == x86 ( 
	if not defined PROCESSOR_ARCHITEW6432 ( 
		set IsJayPC=true
	)
)

rem Read Settings file

if not exist ".\Settings.ini" (
	Echo %CWarning%Couldn't find settings file
	Echo %CWarning%Attempting to download settings file
	curl -s -L -O -f --show-error https://www.dropbox.com/s/31k0wsltys99svd/Settings.ini
	if %ERRORLEVEL% NEQ 0 (
		Echo %CWarning%Failed to download settings, defaulting to hardcoded variables
		echo >> .\Settings.ini
		echo DisplayChangelog=true >> .\Settings.ini
		echo CheckForUpdates=true >> .\Settings.ini
		echo UpdateAutomatically=false >> .\Settings.ini
	) else (
		Echo %CSuccess%Settings file downloaded successfully
	)
	echo.
)

rem Big brain method of appending variables from an file
for /f "tokens=1,2 delims==" %%a in (.\Settings.ini) do (
	set "%%a=%%b"
)

rem Check for Update
if /I %CheckForUpdates% == true (
	for /F %%D in ('curl -s -L --show-error https://www.dropbox.com/s/k9ape2paz79qjbu/Version.txt') do if %%D gtr %versionnum% (
		Echo %CWarning%An update is available.
		if /I %UpdateAutomatically% == true (goto Com-Update)
		Echo %CWarning%To update, type [Update]
		echo.
	)

	if %ERRORLEVEL% NEQ 0 ( Echo %CWarning%Failed to check version )
)

if not "%1"=="" (
	set Command=Play %1
	Goto Com-Play
)

Echo %CNormal%For a list of commands type [Help]
Echo %CNormal%Please do not close the script while Outlast is running.
Echo %CNormal%If a line that says [Terminate batch job] shows up type [N]

rem Print Changelog
if /I %DisplayChangelog%==true (
	echo.
	echo %CInfo%Changelog: 
	echo.
	curl -s -L --show-error https://www.dropbox.com/s/f7czwdz6s4xldy3/Changelog.txt
	if %ERRORLEVEL% NEQ 0 (
		Echo %CWarning%Failed to recieve Changelog
	)
	echo.
)
goto Input

:Input
	echo %CInfo%
	Echo.
	set /p Command=^> 
	Echo.
	findstr /ri /c:"^ *:Com-%Command% " /c:"^ *:Com-%Command%$" "%~f0" >nul 2>nul && goto Com-%Command%
	for /f "tokens=1" %%i in ("%Command%") do if /I "%%i"=="Open" goto Com-Open 
	for /f "tokens=1" %%i in ("%Command%") do if /I "%%i"=="Play" goto Com-Play
	for /f "tokens=1" %%i in ("%Command%") do if /I "%%i"=="make" goto Com-Make
	for /f "tokens=1" %%i in ("%Command%") do if /I "%%i"=="Mount" goto Com-Mount
	
	REM Below is the set of instructions to run if the command does not work. 
	echo %CError%Command Not Found
	goto Input

:Com-List
	REM for %%f in (".\OLGame\CookedPCConsole\Custom\*.udk") do Echo %CNormal%%%~nf
	for %%f in (".\OLGame\CookedPCConsole\Custom\*") do (
			Echo %CNormal%%%~nf
		)
	goto Input
	
:Com-Open
	REM Get second word from inputted command, and use that as the level name
	for /f "tokens=2" %%i in ("%Command%") do set Level=%%i
	
	if exist .\OLGame\CookedPCConsole\Custom\%level%.udk (
		Echo %CSuccess%Successfully loaded level
		if /I %IsJayPC%==true (
			.\Binaries\Win32\OLGame.exe Custom\%level% -NoSteam -NOHOMEDIR -log
		)

		if /I %IsJayPC%==false (
			.\Binaries\Win64\OLGame.exe Custom\%level% -NoSteam -NOHOMEDIR -log
		)
		goto input
	)
	REM Run if not found
	echo %CError%Level Not found
	goto Input
	
:Com-Help
	Echo %CNormal%Open
	Echo %CInfo%	Used to open maps. 
	Echo %CInfo%	Syntax: Open [Map]
	Echo %CNormal%Play
	Echo %CInfo%	Used to run custom campaigns
	Echo %CInfo%	Syntax: Play [Campaign]
	Echo %CNormal%Make
	Echo %CInfo%	Makes a folder with the correct directorys for a custom campaign.
	Echo %CInfo%	Syntax: Make [Campaign Name] [Config{true/false}] [Localization{True/false}] [Content{True/False}]
	Echo %CNormal%List
	Echo %CInfo%	Prints a list of currently installed custom maps. 
	Echo %CInfo%	Syntax: List
	Echo %CNormal%Update
	Echo %CInfo%	Checks for an update, and updates the batch script if one is available.
	Echo %CInfo%	Syntax: Update
	Echo %CNormal%Exit
	Echo %CInfo%	Stops running this script
	Echo %CInfo%	Syntax: Exit
	Echo %CNormal%Mount
	Echo %CInfo%	Mounts a player model stored in the PlayrModels directory.
	Echo %CInfo%	Syntax: Mount [PlayerModel]
	Echo %CNormal%Unmount
	Echo %CInfo%	Unmounts the currently mounted playermodel, and restores the config files.
	Echo %CInfo%	Syntax: Unmount
	Echo %CNormal%Mounthelp
	Echo %CInfo%	Displays a guide on how to set up the Player Model Mounter.
	Echo %CInfo%	Syntax: Mounthelp
	Echo %CNormal%DownloadSettings
	Echo %CInfo%	Downloads a version of the settings file with comments
	Echo %CInfo%	Syntax: DownloadSettings
	goto Input
	
:Com-Exit
	Exit

:Com-Play

	for /f "tokens=2" %%i in ("%Command%") do set Game=%%i
	
	if not exist .\Custom\%Game%\ (
		echo %CError%Campaign Not found
		echo %CError%Please ensure you havent made a typo.
		if not "%1"=="" (
			exit /b
		)
		goto input
	)
	
	if not exist .\Custom\%Game%\config.ini (
		echo %CError%Campaign is missing config file
		if not "%1"=="" (
			exit /b
		)
		goto input
	)
		
	Rem Reset variables
	set config=False
	set Localization=False
	set Content=False
	set Movies=false
	set SaveData=False
	
	Rem Read from config file
	for /f "tokens=1,2 delims==" %%a in (.\Custom\%Game%\config.ini) do (
		set "%%a=%%b"
	)
			
	Rem Mount Game
	if /I %Content%==true (
		call
		Echo %CNormal%Mounting Game Content
		mklink /J .\OLGame\CookedPCConsole\Custom\Campaign\ .\Custom\%Game%\Content > nul
	)
	Rem Mount Config files
	if /I %Config%==true (
		Echo %CNormal%Mounting Config Files
		robocopy /MIR .\OLGame\Config\ .\Backup\Config\ > nul
		robocopy .\Custom\%Game%\Config\ .\OLGame\Config\ > nul
	)
			
	Rem Mount Localization Files
	if /I %Localization%==true (
		Echo %CNormal%Mounting Localization Files
		robocopy /MIR .\OLGame\Localization\ .\Backup\Localization\ > nul
		robocopy /e .\Custom\%Game%\Localization\ .\OLGame\Localization\ > nul
	)
	
	Rem Mount Movie Files
	if /I %Movies%==true (
		Echo %CNormal%Mounting Movie Files
		robocopy .\OLGame\Movies\ .\Backup\Movies\ > nul
		robocopy .\Custom\%Game%\Movies\ .\OLGame\Movies\ > nul
	)
			
	Rem Mount Save Data
	if /I %SaveData%==true (
		if not exist .\custom\%game%\SaveData\ (
			Echo %CNormal%Savegame folder not found, creating
			mkdir .\custom\%game%\SaveData\
		)
		Echo %CNormal%Mounting Save Data
		robocopy /MIR .\OLGame\SaveData\ .\Backup\SaveData > nul
		robocopy /MIR .\Custom\%Game%\SaveData\ .\OLGame\SaveData\ > nul
	)
			
	Rem Launch the game using the newly mounted file. 
	Echo %CSuccess%Content mounted
	if /I %IsJayPC%==true (
		.\Binaries\Win32\OLGame.exe -NoSteam -NOHOMEDIR -log
	)
	if /I %IsJayPC%==false (
		.\Binaries\Win64\OLGame.exe -NoSteam -NOHOMEDIR -log
	)
		
			
		Rem Restore config files from backup
	if /I %config%==true (
		Echo %CNormal%Restoring Config Files
		robocopy .\Backup\Config .\OLGame\Config > nul
	)
			
	Rem Restore localization from backup
	if /I %Localization%==true (
		Echo %CNormal%Restoring Localization
		robocopy /MIR .\Backup\Localization\ .\OLGame\Localization\ > nul
	)
	
	Rem Restore Movies from backup
	if /I %Movies%==true (
		Echo %CNormal%Restoring Movies
		robocopy .\Backup\Movies\ .\OLGame\Movies\ > nul
	)
		
	if /I %SaveData%==true (
		Rem Copy Savefiles over to the mod folder, then restore the save files from backup.
		Echo %CNormal%Updating Save Data
		robocopy /MIR .\OLGame\SaveData\ .\Custom\%Game%\SaveData\ > nul
		robocopy /MIR .\Backup\SaveData\ .\OLGame\SaveData\ > nul
	)

	Rem Unmount Game Content
	if /I %Content%==true (
		Echo %CNormal%Unmounting Game Content
		rmdir .\OLGame\CookedPCConsole\Custom\Campaign\
	)

	if not "%1"=="" (
		exit /b
	)

	goto Input
	REM Run if not found

:Com-Make
	
	set Config=false
	set Localization=false
	set Content=false
	set Movies=false
	
	for /f "tokens=2" %%i in ("%Command%") do set Name=%%i
	
	for /f "tokens=3" %%i in ("%Command%") do (
		if %%i==true set Config=true
		if %%i==True set Config=true
	)
	
	for /f "tokens=4" %%i in ("%Command%") do (
		if %%i==true set Localization=true
		if %%i==True set Localization=true
	)
	
	for /f "tokens=5" %%i in ("%Command%") do (
		if %%i==true set Content=true
		if %%i==True set Content=true
	)
	
	if exist ".\Custom\%name%" (
		echo %CError%A campaign with the same name already exists.
		goto input
	)
	
	rem Make Folder
	
	Echo %CNormal%Making Campaign Folder
	mkdir .\Custom\%Name%
	
	Echo %CNormal%Making Config File
	echo Configuration> .\Custom\%Name%\Config.ini
	
	if %config%==true (
		Echo %CNormal%Making Config Folder
		mkdir .\Custom\%Name%\config
		echo Config=true >> .\Custom\%Name%\Config.ini
	)
	
	if %Localization%==true (
		Echo %CNormal%Making Localization Folder
		mkdir .\Custom\%Name%\Localization
		echo Localization=true >> .\Custom\%Name%\Config.ini
	)
	
	if %Movies%==true (
		Echo %CNormal%Making Movies Folder
		mkdir .\Custom\%Name%\Movies
		echo Movies=true >> .\Custom\%Name%\Config.ini
	)
	
	if %Content%==true (
		Echo %CNormal%Making Content Folder
		mkdir .\Custom\%Name%\Content
		echo Content=true >> .\Custom\%Name%\Config.ini
	)
	
	goto input
	
:Com-Mount

	for /f "tokens=2" %%i in ("%Command%") do set Game=%%i
	
	if Game==Configs (
	echo %CError%Very Funny
	goto input
	)
	
	if not exist ".\PlayerModels\%Game%\" (
		echo %CError%Player Model Not found
		echo %CError%Please ensure you havent made a typo.
		goto input
	)
	
	if exist ".\OLGame\CookedPCConsole\Custom\PlayerModel\" (
		rmdir .\OLGame\CookedPCConsole\Custom\PlayerModel\
	)
	robocopy .\PlayerModels\Configs\PlayerModelGame\ .\OLGame\config\ DefaultGame.ini > nul
	mklink /J .\OLGame\CookedPCConsole\Custom\PlayerModel\ .\PlayerModels\%Game%\Content > nul
	robocopy .\PlayerModels\%Game%\Config .\OLGame\config\ DefaultPlayerModel.ini > nul
	Echo %CSuccess%Player Model Mounted
	goto input
	
:Com-Unmount

	rmdir .\OLGame\CookedPCConsole\Custom\PlayerModel\
	robocopy .\PlayerModels\Configs\BaseGame\ .\OLGame\config\ DefaultGame.ini > nul
	Echo %CSuccess%Player Model Unmounted
	goto input
	
:Com-MountHelp
	Echo %CNormal%In order to mount Player models you must make a few changes to one file. 
	Echo %CNormal%Navigate into the Playermodels folder that the script created. 
	Echo %CNormal%Then go into the config folder, and inside the PlayerModelGame folder
	Echo %CNormal%should be a file named DefaultGame.ini
	echo.
	Echo %CNormal%Open the file, and replace the lines under [Engine.GameInfo] with the following.
	echo.
	Echo %CWarning%DefaultGame=OLCustomPlayerModelSDK.OLCustomGame
	Echo %CWarning%DefaultServerGame=OLCustomPlayerModelSDK.OLCustomGame
	Echo %CWarning%PlayerControllerClassName=OLGame.OLPlayerController
	Echo %CWarning%DefaultGameType="OLCustomPlayerModelSDK.OLCustomGame"
	echo.
	Echo %CNormal%Now you should be ready to mount the files. 
	
	goto input

:Com-Update
for /F %%D in ('curl -s -L --show-error https://www.dropbox.com/s/k9ape2paz79qjbu/Version.txt') do (
	if "%%D" gtr "%versionnum%" (curl -s -L -O --show-error https://www.dropbox.com/s/jd0q9f3mc74jxmv/Level_Launcher.Bat && cls && %0) else (Echo %CNormal%No Update Required && goto Input)
)

:Com-DownloadSettings
Echo %CNormal%Downloading settings file
curl -s -L -O -f --show-error https://www.dropbox.com/s/31k0wsltys99svd/Settings.ini
if %ERRORLEVEL% NEQ 0 (
	Echo %CWarning%Failed to download settings
)
goto input
