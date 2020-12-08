:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
:: Author:		David Geeraerts
:: Location:	Olympia, Washington USA
:: E-Mail:		dgeeraerts.evergreen@gmail.com
:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
:: Copyleft License(s)
:: GNU GPL (General Public License)
:: https://www.gnu.org/licenses/gpl-3.0.en.html
:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

::::::::::::::::::::::::::::::::::
:: VERSIONING INFORMATION		::
::  Semantic Versioning used	::
::   http://semver.org/			::
::	Major.Minor.Revision		::
::::::::::::::::::::::::::::::::::

::#############################################################################
::							#DESCRIPTION#
::
::	SCRIPT STYLE: Interactive
::	Program is a wrapper for ADDS (Active Directory Domain Services)
::	Active Directory search's
::#############################################################################

@Echo Off
@SETLOCAL enableextensions
::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

SET $PROGRAM_NAME=Active_Directory_Domain_Services_Tool
SET $Version=0.0.0
SET $BUILD=2020-12-08 08:30
Title %$PROGRAM_NAME% Version: %$Version%
Prompt ADT$G
color 8F
mode con:cols=80
mode con:lines=45

::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
:: Declare Global variables
:: All User variables are set within here.
::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
:: Defaults
::	uses user profile location for logs
SET "$LOGPATH=%APPDATA%\ADDS"
SET $SESSION_LOG=ADDS_Tool_Active_Session.log
SET $SEARCH_SESSION_LOG=ADDS_Tool_Session_Search_.log
SET $LAST_SEARCH_LOG=ADDS_Tool_Last_Search.log
SET $ARCHIVE_LOG=ADDS_Tool_Session_Archive.log
SET $ARCHIVE_SEARCH_LOG=ADDS_Tool_Search_Archive.log

::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
:: Advanced Settings
::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

::	Suppress_Console_Threshold
::	too many results isn't useful to display
SET $SUPPRESS_CONSOLE_THRESHOLD=3

:: Sort --the search results
:: {0 [No] , 1 [Yes]}
SET $SORTED=1

::	Keep all logs
::	{Yes, No}
SET $KPLOG=Yes

::	Keep Session Settings
::	{Yes, No}
SET $SAVE_SETTINGS=Yes

::	Load Settings --from file
:: {0 [Off/No] , 1 [On/Yes]}
SET $LOAD_SETTINGS=Yes

:: DEBUG
:: {0 [Off/No] , 1 [On/Yes]}
SET $DEGUB_MODE=1
::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
::##### Everything below here is 'hard-coded' [DO NOT MODIFY] #####
::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

:: Program Variables
::	Defaults
SET $Counter=0
SET $sLimit=0
::	Domain User status
::	0 - Local User , 1 - Domain User
SET $DU=1
SET $DC=%USERDOMAIN%
SET $SESSION_USER=%USERNAME%
SET $DOMAIN_USER=NA
SET $cUSERNAME=
SET $adgroup.n=NA
SET $LAST_SEARCH_TYPE=NA
SET $LAST_SEARCH_KEY=NA
SET $LAST_SEARCH_COUNT=NA
SET $DOMAIN=%USERDNSDOMAIN%
SET $DSITE=Default
IF NOT DEFINED $DOMAIN SET $DOMAIN=NA
REM Doesn't like On Off words
IF %$SORTED% EQU 1 (SET $SORTED_N=Yes) ELSE (SET $SORTED_N=No)
SET $SUPPRESS_CONSOLE_THRESHOLD=3
SET $SEARCH_SETTINGS_CHECK=0
:: Defaults
SET $AD_BASE=domainroot
SET $AD_SCOPE=subtree
:: Dependency Checks
::	assumes ready to go
SET $PREREQUISITE_STATUS=1

::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

:CD
	:: Launched from directory
	SET "$PROGRAM_PATH=%~dp0"
	::	Setup logging
	IF NOT EXIST "%$LOGPATH%\var" MD "%$LOGPATH%\var"
	cd /D "%$LOGPATH%"
::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

:wLog
	:: Start session and write to log
	Echo Start Session %DATE% %TIME% > "%$LogPath%\%$SESSION_LOG%"
	Echo Program Name: %$PROGRAM_NAME% >> "%$LogPath%\%$SESSION_LOG%"
	Echo Program Version: %$Version% >> "%$LogPath%\%$SESSION_LOG%"
	Echo Program Build: %$BUILD% >> "%$LogPath%\%$SESSION_LOG%"
	Echo PC: %COMPUTERNAME% >> "%$LogPath%\%$SESSION_LOG%"
	Echo Session User: %USERNAME% >> "%$LogPath%\%$SESSION_LOG%"
::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

:DUC
	::	Check for Domain computer
	::	If value is 1 domain, is 0 workgroup
	SET $DOMAIN_PC=1
	wmic computersystem get DomainRole /value | (FIND "0") && (SET $DOMAIN_PC=0)
	echo Domain_PC: %$DOMAIN_PC% >> "%$LogPath%\%$SESSION_LOG%"
	if %$DOMAIN_PC% EQU 0 SET $DOMAIN=%COMPUTERNAME%
	if %$DOMAIN_PC% EQU 1 SET $DOMAIN=%USERDNSDOMAIN%
	:: Can be local or domain
	IF %$DOMAIN_PC% EQU 0 SET $SESSION_USER_STATUS=local
	IF %$DOMAIN_PC% EQU 0 GoTo skipDUC

	:: Is domain user or local user?
	whoami /UPN 2>nul || FOR /F "tokens=1-2 delims=\" %%P IN ('whoami') Do SET $DOMAIN=%%P && SET $DU=0
	IF %$DU% EQU 0 SET $SESSION_USER_STATUS=local
	IF %$DU% EQU 0 GoTo skipDUC

	:: If domain user use UPN to set domain instead of USERDNSDOMAIN
	FOR /F "tokens=2 delims=^@" %%P IN ('whoami /UPN') Do SET $DOMAIN=%%P
	::	Default credentials for Active Directory is current logged on user.
	::	can be changed in console program
	SET $DC=%LOGONSERVER:~2%
	SET $DOMAIN_USER=%USERNAME%
	SET $SESSION_USER_STATUS=domain
:skipDUC

	:: Friendly name
	if %$DOMAIN_PC% EQU 0 SET $DOMAIN_PC_N=workgroup
	if %$DOMAIN_PC% EQU 1 SET $DOMAIN_PC_N=domain
	echo workgroup else echo domain)

::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

::	Administrator Privilege Check
:subA
	openfiles.exe 1> "%$LOGPATH%\var\var_$Admin_Status_M.txt" 2> "%$LOGPATH%\var\var_$Admin_Status_E.txt"
	SET $ADMIN_STATUS=0
	FIND "ERROR:" "%$LOGPATH%\var\var_$Admin_Status_E.txt" && (SET $ADMIN_STATUS=1)
	IF %$ADMIN_STATUS% EQU 0 (SET "$ADMIN_STATUS_N=Yes") ELSE (SET "$ADMIN_STATUS_N=No")
	echo %$ADMIN_STATUS_N%> "%$LOGPATH%\var\var_$Admin_Status_N.txt" 
::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

:CheckRSAT
	::	Check RSAT-Remote Server Administration Tools
	dsquery /? 1> nul 2> nul
	SET $RSAT_STATUS=%ERRORLEVEL%
	IF %$RSAT_STATUS% EQU 0 GoTo Menu
	:: Admin privileges required
	IF %$ADMIN_STATUS% NEQ 0 GoTo err10
	::	Remote Server Administrator Tools Message
	::	Requires RSAT-Remote Server Administration Tools
	mode con:cols=80 lines=40
	cls
	color 8B
	SET PREREQUISITE_STATUS=0
	Echo.
	Echo It appears this computer [%COMPUTERNAME%] doesn't have:
	Echo [RSAT] Remote Server Administration Tools installed!
	Echo.
	Echo Try installing "Remote Server Admin Tool --> AD DS and AD LDS Tools".
	Echo Reference for doing this:
	Echo https://support.microsoft.com/en-us/help/2693643/remote-server-administration-tools-rsat-for-windows-operating-systems
	Echo.
	echo Install RSAT?
	set /p $INSTALL_DEPENDENCY=[Y]es or [N]o:
	echo.
	echo Selected: %$INSTALL_DEPENDENCY%
	IF NOT DEFINED $INSTALL_DEPENDENCY GoTo skipRSAT
	IF /I "%$INSTALL_DEPENDENCY%"=="N" GoTo skipRSAT
	GoTo RSAT
	Echo.
:skipRSAT
Timeout /t 10
GoTo end
::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

:RSAT
	:: Requires RSAT-Remote Server Administration Tools
	::	Active Directory Domain Services (AD DS) tools and Active Directory Lightweight Directory Services (AD LDS) tools
	::	Requires administrative privileges!
	::	Rsat.ActiveDirectory.DS-LDS.Tools
	FOR /F "tokens=2 delims=:" %%P IN ('DISM /Online /Get-Capabilities ^| find /I "Rsat.ActiveDirectory.DS-LDS.Tools"') DO SET $RSAT_ADDS_FULL=%%P
	::	remove leading space
	FOR /F "tokens=1 delims= " %%P IN ("%$RSAT_ADDS_FULL%") DO SET $RSAT_ADDS_FULL=%%P
	echo %$RSAT_ADDS_FULL%
	::	RSAT Installation
	ECHO Going to try to install RSAT (Remote Server Administration Tools)...
	echo.
	DISM /Online /add-capability /CapabilityName:%$RSAT_ADDS_FULL%
	SET $DISM_ERR=%ERRORLEVEL%
	echo $DISM_ERR:%DISM_STATUS%
	::after install check
	DISM /Online /Get-CapabilityInfo /CapabilityName:%$RSAT_ADDS_FULL% > "%$LOGPATH%\var\var_DISM_ADDS.txt"
	FIND /I "State : Installed" "%$LOGPATH%\var\var_DISM_ADDS.txt"
	type "%$LOGPATH%\var\var_DISM_ADDS.txt" >> "%$LogPath%\%$SESSION_LOG%"
	SET $RSAT_STATUS=%ERRORLEVEL%
	IF %$RSAT_STATUS% NEQ 0 SET $PREREQUISITE_STATUS=%$RSAT_STATUS%
	IF %$RSAT_STATUS% NEQ 0 GoTo err20
	IF %$PREREQUISITE_STATUS% EQU 0 GoTo Menu
::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

:Menu
	Color 0F
	mode con:cols=58 lines=40
	Cls
	ECHO *********************************************************
	ECHO		%$PROGRAM_NAME% %$VERSION%
	IF %$DEGUB_MODE% EQU 1 Echo			Build: %$BUILD%
	echo.
	echo		 	%DATE% %TIME%
	ECHO.
	Echo		Location: Main Menu   
	ECHO *********************************************************
	Echo.
	ECHO Session Information:
	Echo ------------------------
	echo  Session User: %USERNAME%
	echo  Session Admin Privilege: %$ADMIN_STATUS_N%
	echo  Session User Status: %$SESSION_USER_STATUS%
	echo  Session PC: %COMPUTERNAME%
	echo  Session PC Role: %$DOMAIN_PC_N%
	echo.
	echo Log Settings:
	Echo ------------------------
	Echo  Log File Path: %$LogPath%
	Echo  Log File Name: %$SESSION_LOG%
	Echo  Keep Log at End: %$kpLog%
	Echo.
	Echo Current Domain settings:
	Echo ------------------------
	Echo  Domain Account: %$DOMAIN_USER%
	Echo  Domain: %$DOMAIN%
	Echo  Domain Controller: %$DC%
	echo  Domain Site: %$DSITE%
	ECHO *********************************************************
	Echo.
	Echo Choose an action to perform from the list:
	Echo.
	Echo [1] Search
	Echo [2] Settings
	Echo [3] Logs
	Echo [4] Exit
	Echo.
	Choice /c 1234
	Echo.
	::
	If ERRORLevel 4 GoTo End
	If ERRORLevel 3 GoTo Logs
	If ERRORLevel 2 GoTo Uset
	If ERRORLevel 1 GoTo Search
	Echo.
::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

:SMB
	::	Search Menu Banner
	Color 0A
	mode con:cols=55 lines=40
	Cls
	ECHO ******************************************************
	ECHO		%$PROGRAM_NAME% %$VERSION%
	echo.
	echo		 	%DATE% %TIME%
	ECHO.
	Echo		Location: Search Menu     
	echo.
	Echo ******************************************************
	Echo.
	Echo Search Settings
	Echo ------------------------
	Echo  AD Base: %$AD_BASE%
	Echo  AD Scope: %$AD_SCOPE%
	Echo  Query limit: %$sLimit%
	echo  Sorted: %$SORTED_N%
	Echo  Last Search Type: %$LAST_SEARCH_TYPE%
	Echo  Search count: %$COUNTER%
	Echo ******************************************************
	Echo.
	GoTo:EOF
::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

:Search
	:: Trap: Domain User check
	echo %COMPUTERNAME% | (FIND /I "%$DOMAIN%") && (GoTo :subDomain)
	IF %$DU% EQU 0 call :subDA
	IF /I "%$DC%"=="%COMPUTERNAME%" call :subDC
	call :SMB
	Echo Choose search type from the list:
	Echo.
	Echo [1] Universal
	Echo [2] User
	Echo [3] Group
	ECho [4] Computer
	echo [5] Server ^(DC's^)
	echo [6] OU
	echo [7] Settings Menu
	echo [8] Main Menu
	Echo [9] Exit
	Echo.
	Choice /c 123456789
	Echo.
	If ERRORLevel 9 GoTo end
	If ERRORLevel 8 GoTo Menu
	If ERRORLevel 7 GoTo Uset
	If ERRORLevel 6 GoTo sOU
	If ERRORLevel 5 GoTo sServer
	If ERRORLevel 4 GoTo sComputer
	If ERRORLevel 3 GoTo sGroup
	If ERRORLevel 2 GoTo sUser
	If ERRORLevel 1 GoTo sUniversal
::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

:SM
	:: Search Menu banner
	cls
	ECHO ******************************************************
	ECHO		%$PROGRAM_NAME% %$VERSION%
	echo.
	echo		 	%DATE% %TIME%
	ECHO.
	Echo		Location: %$LAST_SEARCH_TYPE% Search
	echo.
	Echo ******************************************************
	echo.
	Echo Domain Settings
	Echo ------------------------
	Echo  Domain Running Account: %$DOMAIN_USER%
	Echo  Domain Controller: %$DC%
	echo  Domain Site: %$DSITE%
	Echo  Domain: %$domain%
	echo.
	Echo Search Settings
	Echo ------------------------
	Echo  AD Base: %$AD_BASE%
	Echo  AD Scope: %$AD_SCOPE%
	Echo  Query limit: %$sLimit%
	echo  Sorted: %$SORTED_N%
	echo.
	echo Search HUD
	Echo ------------------------
	Echo  Last Search Type: %$LAST_SEARCH_TYPE%
	echo  Last Search Key: %$LAST_SEARCH_KEY%
	echo  Last Search Results: %$LAST_SEARCH_COUNT%
	Echo  Search count: %$COUNTER%
	echo.
	Echo ******************************************************
	echo.
	GoTo:EOF
::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

:subSK
:: Sub-routin for Search Key







::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
:sUniversal
	:: Search Universal
	SET $LAST_SEARCH_TYPE=Universal
	call :SM
	SET $SEARCH_KEY=
	::	Close previous Windows
	taskkill /F /FI "WINDOWTITLE eq %$LAST_SEARCH_LOG% - Notepad" 2>nul 1>nul

:SUC
	echo ^(Don't use "*", wildcard will be used automatically.^)
	echo If left blank, will abort.
	IF NOT DEFINED $SEARCH_KEY (SET $SEARCH_KEY_LAST=NA) ELSE (SET $SEARCH_KEY_LAST=%$SEARCH_KEY%)
	SET $SEARCH_KEY=
	SET /P $SEARCH_KEY=Choose a search key ^(word^):
	IF NOT DEFINED $SEARCH_KEY (SET $SEARCH_KEY=%$SEARCH_KEY_LAST%)
	IF /I "%$SEARCH_KEY%"=="NA" GoTo jumpSUC
	echo Selected {%$SEARCH_KEY%} as search key.
	echo %$SEARCH_KEY% | FIND /I "*" 
	IF %ERRORLEVEL% EQU 0 GoTo SUC
	SET $LAST_SEARCH_KEY=%$SEARCH_KEY%
	echo Searching...
	IF EXIST "%$LogPath%\%$LAST_SEARCH_LOG%" DEL /Q "%$LogPath%\%$LAST_SEARCH_LOG%"
	Echo Start search %DATE% %Time% >> "%$LogPath%\%$LAST_SEARCH_LOG%"
	Echo Search Type: %$LAST_SEARCH_TYPE% >> "%$LogPath%\%$LAST_SEARCH_LOG%"
	Echo Search Term: %$SEARCH_KEY% >> "%$LogPath%\%$LAST_SEARCH_LOG%"
	echo Search AD Root: %$AD_BASE% >> "%$LogPath%\%$LAST_SEARCH_LOG%"
	echo Search AD Scope: %$AD_SCOPE% >> "%$LogPath%\%$LAST_SEARCH_LOG%"
	echo Domain Controller: %$DC% >> "%$LogPath%\%$LAST_SEARCH_LOG%"
	Echo Domain: %$DOMAIN% >> "%$LogPath%\%$LAST_SEARCH_LOG%"
	echo. >> "%$LogPath%\%$LAST_SEARCH_LOG%"
	:: No point in sorting since it won't match the details from attr *
	if "%$SESSION_USER%"=="%$DOMAIN_USER%" (
		DSQUERY * %$AD_BASE% -scope %$AD_SCOPE% -limit %$sLimit% -filter "(&(objectClass=*)(name=*%$SEARCH_KEY%*))" -s %$DC% -attr name distinguishedName > "%$LogPath%\var\var_Last_Search_N_DN.txt") ELSE (
		DSQUERY * %$AD_BASE% -scope %$AD_SCOPE% -limit %$sLimit% -filter "(&(objectClass=*)(name=*%$SEARCH_KEY%*))" -attr name distinguishedName -domain %$DOMAIN% -s %$DC% -u %$DOMAIN_USER% -p %$cUSERPASSWORD% > "%$LogPath%\var\var_Last_Search_N_DN.txt"
		)
	if "%$SESSION_USER%"=="%$DOMAIN_USER%" (
		DSQUERY * %$AD_BASE% -scope %$AD_SCOPE% -limit %$sLimit% -filter "(&(objectClass=*)(name=*%$SEARCH_KEY%*))" -s %$DC% -attr distinguishedName > "%$LogPath%\var\var_Last_Search_DN.txt") ELSE (
		DSQUERY * %$AD_BASE% -scope %$AD_SCOPE% -limit %$sLimit% -filter "(&(objectClass=*)(name=*%$SEARCH_KEY%*))" -attr distinguishedName -domain %$DOMAIN% -s %$DC% -u %$DOMAIN_USER% -p %$cUSERPASSWORD% > "%$LogPath%\var\var_Last_Search_DN.txt"
		)		
	FOR /F "tokens=3 delims=:" %%K IN ('FIND /I /C "=" "%$LogPath%\var\var_Last_Search_N_DN.txt"') DO echo %%K > "%$LogPath%\var\var_Last_Search_Count.txt"
	SET /P $LAST_SEARCH_COUNT= < "%$LogPath%\var\var_Last_Search_Count.txt"	
	echo Number of search results: %$LAST_SEARCH_COUNT% >> "%$LogPath%\%$LAST_SEARCH_LOG%"
	echo. >> "%$LogPath%\%$LAST_SEARCH_LOG%"
	type "%$LogPath%\var\var_Last_Search_N_DN.txt" >> "%$LogPath%\%$LAST_SEARCH_LOG%"	
	echo. >> "%$LogPath%\%$LAST_SEARCH_LOG%"
	if "%$SESSION_USER%"=="%$DOMAIN_USER%" (
		DSQUERY * %$AD_BASE% -scope %$AD_SCOPE% -limit %$sLimit% -filter "(&(objectClass=*)(name=*%$SEARCH_KEY%*))" -s %$DC% -attr *  >> "%$LogPath%\%$LAST_SEARCH_LOG%") ELSE (
		DSQUERY * %$AD_BASE% -scope %$AD_SCOPE% -limit %$sLimit% -filter "(&(objectClass=*)(name=*%$SEARCH_KEY%*))" -attr * -domain %$DOMAIN% -s %$DC% -u %$DOMAIN_USER% -p %$cUSERPASSWORD%  >> "%$LogPath%\%$LAST_SEARCH_LOG%"
		)
	echo. >> "%$LogPath%\%$LAST_SEARCH_LOG%"
	type "%$LogPath%\%$LAST_SEARCH_LOG%" >> "%$LogPath%\%$SEARCH_SESSION_LOG%"
	Echo Number of search results: %$LAST_SEARCH_COUNT%
	:: Search counter increment
	Call :fSC
	:: Open log files
	@explorer "%$LogPath%\%$LAST_SEARCH_LOG%"
	echo Search Again?
:jumpSUC
	Choice /c YN /m "[Y]es or [N]o":
	IF %ERRORLEVEL% EQU 2 GoTo Menu
	IF %ERRORLEVEL% EQU 1 GoTo sUniversal
:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

:sUser
	:: Search User
	SET $LAST_SEARCH_TYPE=User
	call :SM
	SET $SEARCH_KEY=
	::	Close previous Windows
	taskkill /F /FI "WINDOWTITLE eq %$LAST_SEARCH_LOG% - Notepad" 2>nul 1>nul
	REM UNDER DEVELOPMENT
	GoTo err40
:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

:sGroup
	:: Search Group
	SET $LAST_SEARCH_TYPE=Group
	call :SM
	SET $SEARCH_KEY=
	::	Close previous Windows
	taskkill /F /FI "WINDOWTITLE eq %$LAST_SEARCH_LOG% - Notepad" 2>nul 1>nul
	REM UNDER DEVELOPMENT
	GoTo err40
:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

:sComputer
	:: Search Computer
	SET $LAST_SEARCH_TYPE=Computer
	call :SM
	SET $SEARCH_KEY=
	::	Close previous Windows
	taskkill /F /FI "WINDOWTITLE eq %$LAST_SEARCH_LOG% - Notepad" 2>nul 1>nul
	REM UNDER DEVELOPMENT
	GoTo err40
:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

:sServer
	:: Search Server
	SET $LAST_SEARCH_TYPE=Server
	call :SM
	SET $SEARCH_KEY=
	::	Close previous Windows
	taskkill /F /FI "WINDOWTITLE eq %$LAST_SEARCH_LOG% - Notepad" 2>nul 1>nul
	REM UNDER DEVELOPMENT
	GoTo err40
:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

:sOU
	:: Search OU
	SET "$LAST_SEARCH_TYPE=OrganizationalUnit^(OU^)"
	call :SM
	IF NOT DEFINED $SEARCH_KEY (SET $SEARCH_KEY_LAST=NA) ELSE (SET $SEARCH_KEY_LAST=%$SEARCH_KEY%)
	SET $SEARCH_KEY=
	::	Close previous Windows
	taskkill /F /FI "WINDOWTITLE eq %$LAST_SEARCH_LOG% - Notepad" 2>nul 1>nul
	Echo Use wildcard "*"
	echo If left blank, will abort.
	SET /P $SEARCH_KEY=Choose a search key ^(word^):
	IF NOT DEFINED $SEARCH_KEY GoTo Menu
	IF /I "%$SEARCH_KEY%"=="NA" GoTo jumpsOU
	IF "%$SEARCH_KEY%"=="""" GoTo jumpsOU
	echo Selected {%$SEARCH_KEY%} as search key.
	SET $LAST_SEARCH_KEY=%$SEARCH_KEY%
	echo Searching...
	IF EXIST "%$LogPath%\%$LAST_SEARCH_LOG%" DEL /Q "%$LogPath%\%$LAST_SEARCH_LOG%"
	Echo Start search %DATE% %Time% >> "%$LogPath%\%$LAST_SEARCH_LOG%"
	Echo Search Type: %$LAST_SEARCH_TYPE% >> "%$LogPath%\%$LAST_SEARCH_LOG%"
	Echo Search Term: %$SEARCH_KEY% >> "%$LogPath%\%$LAST_SEARCH_LOG%"
	echo Search AD Root: %$AD_BASE% >> "%$LogPath%\%$LAST_SEARCH_LOG%"
	echo Search AD Scope: %$AD_SCOPE% >> "%$LogPath%\%$LAST_SEARCH_LOG%"
	echo Domain Controller: %$DC% >> "%$LogPath%\%$LAST_SEARCH_LOG%"
	Echo Domain: %$DOMAIN% >> "%$LogPath%\%$LAST_SEARCH_LOG%"
	echo. >> "%$LogPath%\%$LAST_SEARCH_LOG%"
	set "$AD_SERVER_SEARCH=-s %$DC%" 
	if %$AD_BASE%==forestroot SET "$AD_SERVER_SEARCH=-gc"
	
	if %$SORTED% EQU 1 GoTo jumpSOU 
	if "%$SESSION_USER%"=="%$DOMAIN_USER%" (
		DSQUERY OU %$AD_BASE% -scope %$AD_SCOPE% -o rdn -name "%$SEARCH_KEY%" -limit %$sLimit% %$AD_SERVER_SEARCH%  > "%$LogPath%\var\var_Last_Search_N.txt") ELSE (
		DSQUERY OU %$AD_BASE% -scope %$AD_SCOPE% -o rdn -name "%$SEARCH_KEY%" -limit %$sLimit%   -domain %$DOMAIN% %$AD_SERVER_SEARCH% -u %$DOMAIN_USER% -p %$cUSERPASSWORD% > "%$LogPath%\var\var_Last_Search_N.txt"
		)
	if "%$SESSION_USER%"=="%$DOMAIN_USER%" (
		DSQUERY OU %$AD_BASE% -scope %$AD_SCOPE% -o dn -name "%$SEARCH_KEY%" -limit %$sLimit%  %$AD_SERVER_SEARCH% -attr distinguishedName > "%$LogPath%\var\var_Last_Search_DN.txt") ELSE (
		DSQUERY OU %$AD_BASE% -scope %$AD_SCOPE% -o dn -name "%$SEARCH_KEY%" -limit %$sLimit%   -domain %$DOMAIN% %$AD_SERVER_SEARCH% -u %$DOMAIN_USER% -p %$cUSERPASSWORD% > "%$LogPath%\var\var_Last_Search_DN.txt"
		)	
	if %$SORTED% NEQ 1 GoTo skipSOU
:jumpSOU
	if "%$SESSION_USER%"=="%$DOMAIN_USER%" (
		DSQUERY OU %$AD_BASE% -scope %$AD_SCOPE% -o rdn -name "%$SEARCH_KEY%" -limit %$sLimit% %$AD_SERVER_SEARCH% | sort  > "%$LogPath%\var\var_Last_Search_N.txt") ELSE (
		DSQUERY OU %$AD_BASE% -scope %$AD_SCOPE% -o rdn -name "%$SEARCH_KEY%" -limit %$sLimit%   -domain %$DOMAIN% %$AD_SERVER_SEARCH% -u %$DOMAIN_USER% -p %$cUSERPASSWORD% | sort > "%$LogPath%\var\var_Last_Search_N.txt"
		)
	if "%$SESSION_USER%"=="%$DOMAIN_USER%" (
		DSQUERY OU %$AD_BASE% -scope %$AD_SCOPE% -o dn -name "%$SEARCH_KEY%" -limit %$sLimit%  %$AD_SERVER_SEARCH% | sort > "%$LogPath%\var\var_Last_Search_DN.txt") ELSE (
		DSQUERY OU %$AD_BASE% -scope %$AD_SCOPE% -o dn -name "%$SEARCH_KEY%" -limit %$sLimit%   -domain %$DOMAIN% %$AD_SERVER_SEARCH% -u %$DOMAIN_USER% -p %$cUSERPASSWORD% | sort > "%$LogPath%\var\var_Last_Search_DN.txt"
		)	
:skipSOU
	FOR /F "tokens=3 delims=:" %%K IN ('FIND /I /C "=" "%$LogPath%\var\var_Last_Search_DN.txt"') DO echo %%K> "%$LogPath%\var\var_Last_Search_Count.txt"
	SET /P $LAST_SEARCH_COUNT= < "%$LogPath%\var\var_Last_Search_Count.txt"	
	echo Number of search results: %$LAST_SEARCH_COUNT% >> "%$LogPath%\%$LAST_SEARCH_LOG%"
	echo. >> "%$LogPath%\%$LAST_SEARCH_LOG%"
	type "%$LogPath%\var\var_Last_Search_N.txt" >> "%$LogPath%\%$LAST_SEARCH_LOG%"
	echo. >> "%$LogPath%\%$LAST_SEARCH_LOG%" 
	type "%$LogPath%\var\var_Last_Search_DN.txt" >> "%$LogPath%\%$LAST_SEARCH_LOG%"	
	echo. >> "%$LogPath%\%$LAST_SEARCH_LOG%"
	IF %$LAST_SEARCH_COUNT% EQU 0 (Echo Nothing found! Try again with broader wildcard.) & (echo.) & (timeout /t 10)
	IF %$LAST_SEARCH_COUNT% EQU 0 GoTo sOU
	:: Search counter increment
	Call :fSC
	:: Open log files
	@explorer "%$LogPath%\%$LAST_SEARCH_LOG%"
	IF %$LAST_SEARCH_COUNT% EQU 1 (SET $OU_USE_OPT=Y) ELSE (SET $OU_USE_OPT=N)
	IF /I "%$OU_USE_OPT%"=="Y" (Echo Single OU found!) ELSE (GoTo skipOUO)
	echo Set the OU as search base?
	Choice /c yn /m "[y]es or [n]o":
	IF %ERRORLEVEL% EQU 2 GoTo skipOUO
	IF %ERRORLEVEL% EQU 1 for /F "skip=1 delims=" %%S IN ('FIND /I "=" "%$LogPath%\%$LAST_SEARCH_LOG%"') DO ECHO %%S> "%$LogPath%\var\var_OU_Base.txt"
	SET /P $AD_BASE= < "%$LogPath%\var\var_OU_Base.txt"
	echo AD Base: %$AD_BASE%
:skipOUO	
	echo Search Again?
	Choice /c yn /m "[y]es or [n]o":
	IF %ERRORLEVEL% EQU 2 GoTo Menu
	IF %ERRORLEVEL% EQU 1 GoTo sOU
:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::































:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
:Uset
	::	User Settings
	Color 8E
	mode con:cols=60 lines=40
	cls
	ECHO ************************************************************
	ECHO		%$PROGRAM_NAME% %$VERSION%
	echo.
	echo		 	%DATE% %TIME%
	echo.
	Echo		Location: Settings    
	ECHO ************************************************************
	Echo.
	Echo Current Log Settings
	Echo ------------------------
	Echo  Log File Path: %$LogPath%
	Echo  Log File Name: %$SESSION_LOG%
	Echo  Keep Log at End: %$kpLog%
	Echo.
	Echo Current Domain Settings
	Echo ------------------------
	Echo  Domain Running Account: %$DOMAIN_USER%
	Echo  Domain Controller: %$DC%
	echo  Domain Site: %$DSITE%
	Echo  Domain: %$domain%
	Echo.
	Echo Current Search Settings
	Echo ------------------------
	Echo  AD Base: %$AD_BASE%
	Echo  AD Scope: %$AD_SCOPE%
	Echo  Query limit: %$sLimit%
	ECHO  Sorted: %$SORTED%
	ECHO  Suppress Console Threshold: %$SUPPRESS_CONSOLE_THRESHOLD%
	ECHO ************************************************************
	Echo.
	Echo Choose an action from the list:
	Echo.
	Echo [1] Change Log Settings
	Echo [2] Change Domain Settings
	Echo [3] Change Search Settings
	echo [4] Search Menu
	Echo [5] Main menu
	Echo.
	Choice /c 12345
	Echo.
	If ERRORLevel 5 GoTo Menu
	If ERRORLevel 4 GoTo Search
	If ERRORLevel 3 GoTo uSetS
	If ERRORLevel 2 GoTo uSetDC
	If ERRORLevel 1 GoTo uSetL
::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

:UsetL
	::	Log Settings
	mode con:cols=60 lines=40
	cls
	ECHO ************************************************************
	ECHO		%$PROGRAM_NAME% %$VERSION%
	echo.
	echo		 	%DATE% %TIME%
	echo.
	Echo		Location: Log Settings
	echo.
	ECHO ************************************************************
	Echo.
	Echo Current Log Settings
	Echo ------------------------
	Echo  Log File Path: %$LogPath%
	Echo  Log File Name: %$SESSION_LOG%
	Echo  Keep Log at End: %$kpLog%
	Echo.
	Echo  Instructions
	Echo ------------------------
	Echo.
	Echo If no change is desired,
	Echo just hit enter and leave blank.
	Echo.
	echo %$LOGPATH%> "%$LOGPATH%\var\var_$LOGPATH.txt"
	echo %$SESSION_LOG%> "%$LOGPATH%\var\var_$SESSION_LOG.txt"
	echo %$kpLog%> "%$LOGPATH%\var\var_$kpLog.txt"
	SET /p $LOGPATH=Log Path:
	echo.
	Echo ^("Yes" or "No"^)
	SET /P $kpLog=Keep Logs:
	echo %$kpLog% | FIND /I "Y" && SET $kpLog=Yes
	echo %$kpLog% | FIND /I "N" && SET $kpLog=No
	IF /I NOT "%$kpLog%"=="Yes" SET /A $CHECK_KPLOG+=1
	IF /I NOT "%$kpLog%"=="No" SET /A $CHECK_KPLOG+=1
	IF %$CHECK_KPLOG% EQU 2 SET /P $kpLog= < "%$LOGPATH%\var\var_$kpLog.txt"
	:: ERROR CHECKING
	IF NOT EXIST %$LogPath% mkdir %$LogPath% || Echo Log path not valid and/or file name not valid. Back to default!
	IF NOT EXIST %$LogPath% SET /P $LogPath= < "%$LOGPATH%\var\var_$LOGPATH.txt"
	Echo Close ALL open logs?
	choice /c YN /m "[y]es, [n]o?"
	If ERRORLevel 2 GoTo skipCL	
	If ERRORLevel 1 taskkill /F /IM notepad.exe 2>nul 1>nul
:skipCL	
	GoTo uSet
::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

SET "$DC_TAG=DS Settings"
:bannerDS
	mode con:cols=60 lines=40
	cls
	ECHO ************************************************************
	ECHO		%$PROGRAM_NAME% %$VERSION%
	echo.
	echo		 	%DATE% %TIME%
	echo.
	Echo		Location: Domain Settings [%$DC_TAG%]
	ECHO ************************************************************
	echo.
	Echo Current Domain Settings
	Echo ------------------------
	Echo  Domain Running Account: %$DOMAIN_USER%
	Echo  Domain Controller: %$DC%
	echo  Domain Site: %$DSITE%
	Echo  Domain: %$domain%
	ECHO ************************************************************
	echo.
	GoTo:EOF
::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

:uSetDC
	SET "$DC_TAG=Domain Settings"
	CALL :bannerDS
	Echo Choose an action from the list:
	Echo.
	Echo [1] Change Domain Running Account
	Echo [2] Change Domain Controller
	Echo [3] Change Domain
	echo [4] Chanage Domain Site
	echo [5] Back Settings
	Echo [6] Main menu
	Echo.
	Choice /c 123456
	Echo.
	If ERRORLevel 6 GoTo Menu
	If ERRORLevel 5 GoTo Uset
	If ERRORLevel 4 GoTo subDS
	If ERRORLevel 3 GoTo subDomain
	If ERRORLevel 2 GoTo subDC
	If ERRORLevel 1 GoTo subDA
::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

:subDA
	::trap Domain must be set first
	IF /I "%$DOMAIN%"=="%COMPUTERNAME%" GoTo subDomain
	IF /I "%$DOMAIN_USER%"=="NA" GoTo jumpDA
	IF %$DU% EQU 0 GoTo jumpDA
	IF /I "%$DC%"=="%COMPUTERNAME%" GoTo subDC
:jumpDA
	::	sub-routin Domain Account
	SET "$DC_TAG=Domain Account"
	CALL :bannerDS
	Echo  Instructions
	Echo ------------------------
	Echo If no change is desired,
	Echo just hit enter and leave blank.
	echo.
	echo %$DOMAIN_USER%> "%$LOGPATH%\var\var_$DOMAIN_USER.txt"
	echo Provide Credentials ^(searches Name ^& UPN^)
	SET /P $DOMAIN_USER=UserName:
	SET /P $cUSERPASSWORD=Password:
	:: Using name search
	dsquery user forestroot -o rdn -scope subtree -domain %$domain% -name "%$DOMAIN_USER%" -u %$DOMAIN_USER% -p %$cUSERPASSWORD% -limit %$sLimit% -uc 2> nul 1> "%$LOGPATH%\var\var_Custom_User_Domain_Authentication.txt"
	::	mainly to capture authentication faliure
	SET $DA_QUERY_RESULT=%ERRORLEVEL%
	IF NOT DEFINED $DA_QUERY_RESULT SET $DA_QUERY_RESULT=0
	echo %$DA_QUERY_RESULT% > "%$LOGPATH%\var\var_$DA_QUERY_RESULT.txt"
	::	Athentication error -2147023570
	IF %$DA_QUERY_RESULT% EQU -2147023570 (
		SET /P $DOMAIN_USER= < "%$LOGPATH%\var\var_$DOMAIN_USER.txt") & (
		ECHO Authentication failed!) & (
		echo.) & (
		Timeout /t 10) & (
		GoTo subDA
		)
	echo.
	SET /P $CHECK_CUSTOM_USER_DOMAIN_ATHENTICATION= < "%$LOGPATH%\var\var_Custom_User_Domain_Authentication.txt"
	::Will contain double quotes to remove
	FOR /F "usebackq delims=" %%P IN ('%$CHECK_CUSTOM_USER_DOMAIN_ATHENTICATION%') DO SET $CHECK_CUSTOM_USER_DOMAIN_ATHENTICATION=%%~P
	:: Using UPN search
	IF NOT DEFINED $CHECK_CUSTOM_USER_DOMAIN_ATHENTICATION dsquery user forestroot -o rdn -scope subtree -domain %$domain% -UPN "%$DOMAIN_USER%*" -u %$DOMAIN_USER% -p %$cUSERPASSWORD% -limit %$sLimit% -uc 2> nul 1> "%$LOGPATH%\var\var_Custom_User_Domain_Authentication.txt"
	SET /P $CHECK_CUSTOM_USER_DOMAIN_ATHENTICATION= < "%$LOGPATH%\var\var_Custom_User_Domain_Authentication.txt"
	::Will contain double quotes to remove
	FOR /F "usebackq delims=" %%P IN ('%$CHECK_CUSTOM_USER_DOMAIN_ATHENTICATION%') DO SET $CHECK_CUSTOM_USER_DOMAIN_ATHENTICATION=%%~P
	SET $DA_VALID=0
	IF NOT DEFINED $CHECK_CUSTOM_USER_DOMAIN_ATHENTICATION SET $DA_VALID=1
	IF %$DA_VALID% EQU 0 SET $DU=1
	IF %$DA_VALID% EQU 1 GoTo subDA
	echo Success!
	timeout /t 10
	GoTo:EOF
	GoTo uSetDC

::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
:subDC
	::traps
	IF /I "%$DOMAIN_USER%"=="NA" call :subDA
	::	sub-routine Domain Controller
	SET "$DC_TAG=Domain Controller"
	CALL :bannerDS
	Echo  Instructions
	Echo ------------------------
	Echo If no change is desired,
	Echo just hit enter and leave blank.
	echo %$DC%> "%$LOGPATH%\var\var_$DC.txt"
	echo.
	IF /I "%$SESSION_USER_STATUS%"=="local" IF NOT DEFINED $cUSERPASSWORD GoTo err30
	echo Pick a Domain Controller to connect to
	IF "%$SESSION_USER_STATUS%"=="domain" (dsquery server -o rdn -forest -domain %$domain% -name "*" -limit %$sLimit% -uc 2> nul) ELSE (
		dsquery server -o rdn -forest -domain %$domain% -name "*" -u %$DOMAIN_USER% -p %$cUSERPASSWORD% -limit %$sLimit% -uc 2> nul
		) > "%$LOGPATH%\var\var_Domain_Controller_List.txt"
	type "%$LOGPATH%\var\var_Domain_Controller_List.txt"
	SET /P $DC=Domain Controller:
	SET $DC_CHECK=0
	CALL :bannerDS
	@ping %$DC% || SET $DC_CHECK=1
	IF %$DC_CHECK% EQU 1 (
		SET /P $DC= < "%$LOGPATH%\var\var_$DC.txt") & (
		echo DC not responding! Choose another DC) & (
		timeout /t 10) & (
		GoTo subDC)
	echo.
	echo Perform PATHPING?
	Choice /c YN /m "[Y]es or [N]o":
	IF %ERRORLEVEL% EQU 2 GoTo uSetDC
	IF %ERRORLEVEL% EQU 1 GoTo checkDC
	:checkDC
	CALL :bannerDS
	pathping %$DC%.%$domain%
	echo Change Domain Controller?
	Choice /c yn /m "[y]es or [n]o":
	:: mark may not work
	IF %ERRORLEVEL% EQU 2 GoTo uSetDC
	IF %ERRORLEVEL% EQU 1 GoTo subDC

::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

:subDomain
	::	sub-routine Domain
	SET "$DC_TAG=Domain"
	CALL :bannerDS
	Echo  Instructions
	Echo ------------------------
	Echo If no change is desired,
	Echo just hit enter and leave blank.
	echo %$DOMAIN%> "%$LOGPATH%\var\var_$DOMAIN.txt"
	echo.
	SET /P $DOMAIN=Domain:
	(nslookup %$DOMAIN% 2> nul) | (FIND /I "NAME:")
	SET $CHECK_DOMAIN=%ERRORLEVEL%
	IF %$CHECK_DOMAIN% EQU 1 (SET /P $DOMAIN= < "%$LOGPATH%\var\var_$DOMAIN.txt")
	IF %$CHECK_DOMAIN% EQU 1 (Echo Domain not found!) & (timeout /t 10) & (GoTo subDomain)
	Echo Domain configured: %$DOMAIN% 
	timeout /t 10
	REM Having GoTo:EOF if not called
	GoTo uSetDC
::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

:subDS
	::traps
	echo %COMPUTERNAME% | (FIND /I "%$DOMAIN%") && (GoTo subDomain)
	IF %$DU% EQU 0 call :subDA
	IF /I "%$DC%"=="%COMPUTERNAME%" call :subDC
	:: sub-routine Domain Site
	SET "$DC_TAG=Domain Site"
	CALL :bannerDS
	Echo  Instructions
	Echo ------------------------
	Echo If no change is desired,
	Echo just hit enter and leave blank.
	Echo Can use "*" at end of string.
	echo %$DSITE%> "%$LOGPATH%\var\var_$DSITE.txt"
	echo.
	IF %$DU% EQU 0 IF NOT DEFINED $cUSERPASSWORD GoTo err30
	echo Choose a site
	Echo --------------
	IF "%$SESSION_USER_STATUS%"=="domain" (dsquery site -o rdn -domain %$domain% -limit %$sLimit% -uc) ELSE (
		dsquery site -o rdn -domain %$domain% -u %$DOMAIN_USER% -p %$cUSERPASSWORD% -limit %$sLimit% -uc 2> nul
		)
	SET /P $DSITE=Domain Site:
	SET $DS_CHECK=0
	IF "%$SESSION_USER_STATUS%"=="domain" (
		dsquery site -o rdn -domain %$domain% -name "%$DSITE%" -limit %$sLimit% -uc | FIND /I """") ELSE (
		dsquery site -o rdn -domain %$domain% -name "%$DSITE%" -u %$DOMAIN_USER% -p %$cUSERPASSWORD% -limit %$sLimit% -uc | FIND /I """"
		)
	SET $DS_CHECK=%ERRORLEVEL%
	IF %$DS_CHECK% NEQ 0 SET /P $DSITE= < "%$LOGPATH%\var\var_$DSITE.txt"
	IF %$DS_CHECK% NEQ 0 Echo Not a valid site, reverted back to previous setting.
	IF %$DS_CHECK% EQU 0 GoTo jumpDSS
	echo Try to change Domain Site again?
	Choice /c yn /m "[y]es or [n]o":
	IF %ERRORLEVEL% EQU 2 GoTo uSetDC
	IF %ERRORLEVEL% EQU 1 GoTo subDS
	:jumpDSS
	IF "%$SESSION_USER_STATUS%"=="domain" (
		dsquery site -o rdn -domain %$domain% -name "%$DSITE%" -limit %$sLimit% -uc > "%$LOGPATH%\var\var_$DSITE_List.txt") ELSE (
		dsquery site -o rdn -domain %$domain% -name "%$DSITE%" -u %$DOMAIN_USER% -p %$cUSERPASSWORD% -limit %$sLimit% -uc > "%$LOGPATH%\var\var_$DSITE_List.txt"
		)
	SET /P $DSITE_N= < "%$LOGPATH%\var\var_$DSITE_List.txt"
	::Will contain double quotes to remove
	echo %$DSITE% | (FIND /I "*" 1> nul 2> nul) && ( 
		FOR /F "usebackq delims=" %%P IN ('%$DSITE_N%') DO SET $DSITE_N=%%~P)
	SET $DSITE=%$DSITE_N%
	echo %$DSITE%> "%$LOGPATH%\var\var_$DSITE.txt"
	Echo Success!
	timeout /t 10 
	GoTo uSetDC
::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

:uSetS
:: Search Settings
	mode con:cols=60 lines=40
	cls
	ECHO ************************************************************
	ECHO		%$PROGRAM_NAME% %$VERSION%
	echo.
	echo		 	%DATE% %TIME%
	echo.
	Echo		Location: Search Settings
	echo.
	ECHO ************************************************************
	Echo.
	IF %$SEARCH_SETTINGS_CHECK% EQU 1 GoTo jumpSSC
	Echo Current Search Settings
	Echo ------------------------
	Echo  AD Base: %$AD_BASE%
	Echo  AD Scope: %$AD_SCOPE%
	Echo  Suppress Console Threshold: %$SUPPRESS_CONSOLE_THRESHOLD%
	Echo  Sort: %$SORTED_N%
	Echo.
	Echo  Instructions
	Echo ------------------------
	Echo Select
	echo.
	Echo %$AD_BASE%> "%$LOGPATH%\var\var_AD_Base.txt"
	Echo %$AD_SCOPE%> "%$LOGPATH%\var\var_AD_Scope.txt"
	Echo Select AD Base:
	echo [1] domainroot
	echo [2] forestroot
	echo [3] custom OU
	Echo.
	Choice /c 123
	Echo.
	If ERRORLevel 3 GoTo subADRoot
	If ERRORLevel 2 SET $AD_BASE=forestroot
	If ERRORLevel 1 SET $AD_BASE=domainroot
	if /I "%$AD_BASE%"=="forestroot" (SET $AD_SCOPE=subtree) & (GoTo skipASS)
	Echo Select AD Scope:
	echo [1] subtree
	echo [2] onelevel
	echo [3] base
	Echo.
	Choice /c 123
	Echo.	
	If ERRORLevel 3 SET $AD_SCOPE=base
	If ERRORLevel 2 SET $AD_SCOPE=onelevel
	If ERRORLevel 1 SET $AD_SCOPE=subtree
:skipASS


	
	echo %$SUPPRESS_CONSOLE_THRESHOLD% > "%$LOGPATH%\var\var_Suppress_Console_Threshold.txt"
:jumpSCT	
	echo Provide a number
	SET /P $SUPPRESS_CONSOLE_THRESHOLD=Suppress Console Threshold:
	echo %$SORTED% > "%$LOGPATH%\var\var_$SORTED.txt"
	echo Provide {0 [No] , 1 [Yes]}
	SET /P $SORTED=Sorted:
	IF %$SORTED% LEQ 1 GoTo skipSC
	echo %$SORTED% | (find /I "Y")
	IF %ERRORLEVEL% EQU 0 (SET $SORTED=1) ELSE (SET $SORTED=0)
:skipSC
	IF %$SORTED% EQU 1 (SET $SORTED_N=Yes) ELSE (SET $SORTED_N=No)
	SET $SEARCH_SETTINGS_CHECK=1
	GoTo uSetS
:jumpSSC
	echo New Search Settings
	Echo ------------------------
	Echo  AD Base: %$AD_BASE%
	Echo  AD Scope: %$AD_SCOPE%
	Echo  Suppress Console Threshold: %$SUPPRESS_CONSOLE_THRESHOLD%
	Echo  Sort: %$SORTED_N%
	echo.
	echo Change Search settings?
	SET $SEARCH_SETTINGS_CHECK=0
	Choice /c yn /m "[y]es or [n]o":
	IF %ERRORLEVEL% EQU 2 GoTo Uset
	IF %ERRORLEVEL% EQU 1 GoTo uSetS
::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::





::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::






:Logs
	IF EXIST "%$LOGPATH%\ADDS_Tool_Active_Session.log" @explorer "%$LOGPATH%\ADDS_Tool_Active_Session.log"
	IF EXIST "%$LOGPATH%\ADDS_Search_Session.log" @explorer "%$LOGPATH%\ADDS_Search_Session.log"
	IF EXIST "%$LOGPATH%\ADDS_Tool_Last_Search.log" @explorer "%$LOGPATH%\ADDS_Tool_Last_Search.log"
	IF EXIST "%$LOGPATH%\var\var_Last_Search_N_DN.txt" @explorer "%$LOGPATH%\var\var_Last_Search_N_DN.txt"
	GoTo menu
:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

:::: FUNCTIONS ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

:fSC
	::	Search Counter
	SET /A $Counter+=1
	GoTo:EOF
:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::


::	jump error section 
GoTo end

::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
::
:: ERROR SECTION
::
::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

:ErrBann
:: Banner
	cls
	color 4E
	mode con:cols=80
	mode con:lines=40
	ECHO   ***************************************************************************
	ECHO. 
	ECHO		%$PROGRAM_NAME% %$VERSION%
	echo.
	echo		 %DATE% %TIME%
	ECHO.
	ECHO   ***************************************************************************
	ECHO   ***************************************************************************
	echo.
	Echo		!!ERROR!! !!ERROR!! !!ERROR!! !!ERROR!! !!ERROR!! !!ERROR!!
	echo.
	ECHO   ***************************************************************************
	echo.
	echo.
	GoTo:EOF
:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

:err10
	:: error Administrative Privilege
	call :ErrBann
	echo Administrative Privilege Error
	Echo.
	echo Current user doesn't have administrative privilege!
	Echo.
	echo This is likely a fatal error!
	echo Try running the program as an administrator.
	echo ^(An action is required (likely installing dependencies),
	echo  which requires administrative privilege.^)
	echo.
	echo Aborting!
	echo.
	Timeout/t 120
	GoTo end
:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

:err20
	::error RSAT
	call :ErrBann
	echo RSAT-Remote Server Administration Tools ERROR
	echo.
	echo Something went wrong trying to install RSAT!
	echo RSAT is a core dependency for this program.
	echo This is a fatal error!
	echo.
	echo Aborting!
	echo.
	Timeout/t 120
	GoTo end
:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

:err30
	:: Error PW Cache
	:: 
	call :ErrBann
	echo Logged in User is not a domain user, and no PW cached!
	echo Custom domain user requires that the password be cached.
	echo (Password is cached in memory)
	Echo Jumping to allow setting custom user and password...
	echo.
	timeout /t 60
	GoTo subDA
:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

:err40
	:: Error Under Development
	call :ErrBann
	echo	UNDER CONSTRUCTION
	echo.
	echo	Feature: %$LAST_SEARCH_TYPE% search
	echo.
	timeout /t 60
GoTo Search
:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

:end
	:: End session
	IF EXIST "%$LOGPATH%\%$SESSION_LOG%" Echo End Session %DATE% %TIME%. >> "%$LOGPATH%\%$SESSION_LOG%"
	IF EXIST "%$LOGPATH%\%$SESSION_LOG%" Echo. >> "%$LOGPATH%\%$SESSION_LOG%"
	
	:: [FUTURE FEATURE]
	::	Save Session Settings
	:: IF /I NOT "%$SAVE_SETTINGS%"=="Yes" GoTo skipSSS
	:: IF NOT EXIST "%$LOGPATH%\Settings" mkdir "%$LOGPATH%\Settings"
	:: :skipSSS	
	
	::	Check for debug mode
	IF %$DEGUB_MODE% EQU 1 GoTo skipCL
	:: Last Search files
	IF EXIST "%$LOGPATH%\%$LAST_SEARCH_LOG%" Del /q "%$LOGPATH%\%$LAST_SEARCH_LOG%"
	IF EXIST "%$LOGPATH%\var\var_Last_Search_N_DN.txt" Del /q "%$LOGPATH%\var\var_Last_Search_N_DN.txt"
	IF EXIST "%$LOGPATH%\var" RD /S /Q "%$LOGPATH%\var"
:skipCL
	:: Archive session
	Type "%$LOGPATH%\%$SESSION_LOG%" >> "%$LOGPATH%\%$ARCHIVE_LOG%"
	Del /q "%$LOGPATH%\%$SESSION_LOG%"
	Type "%$LOGPATH%\%$SEARCH_SESSION_LOG%" >> "%$LOGPATH%\%$ARCHIVE_SEARCH_LOG%"
	Del /q "%$LOGPATH%\%$SEARCH_SESSION_LOG%"
	IF %$DEGUB_MODE% EQU 1 GoTo skipLC
	:: Keep logs check
	IF /I %$KPLOG%==Yes IF EXIST "%$LOGPATH%\ReadMe.txt" Del /q "%$LOGPATH%\ReadMe.txt"
	IF /I %$KPLOG%==Yes GoTo skipLC
	::	Delete all logs
		:: Close any open files
	taskkill /F /FI "WINDOWTITLE eq ADDS*"
	IF EXIST "%$LOGPATH%" RD /S /Q "%$LOGPATH%"
	echo %DATE% %TIME% > "%$LOGPATH%\ReadMe.txt"
	echo Directory was nuked! >> "%$LOGPATH%\ReadMe.txt"
:skipLC
:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

:credits
	::	Credits
	cls
	mode con:cols=55 lines=25
	COLOR 0B
	Echo.
	ECHO Developed by:
	ECHO David Geeraerts {dgeeraerts.evergreen@gmail.com}
	ECHO GitHub: https://github.com/DavidGeeraerts/ADDS_Tool
	ECHO.
	Echo.
	ECHO Contributors:
	ECHO.
	Echo.
	Echo.
	ECHO.
	ECHO.
	ECHO Copyleft License
	ECHO GNU GPL (General Public License)
	ECHO https://www.gnu.org/licenses/gpl-3.0.en.html
	Echo.
	Timeout /T 30
	ENDLOCAL
Exit
:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::