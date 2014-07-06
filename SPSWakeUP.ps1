﻿# ====================================================================================# Description:	WarmUP script for SharePoint 2007, 2010 & 2013# FileName:		SPSWarmUP.ps1# Author:		Jean-Cyril DROUHIN# Date:			May 15, 2014
# Version:		1.5
# URL:			http://spswarmup.codeplex.com
# Licence:		MS-PL# ====================================================================================param (    [string]$inputFile = $(throw '- Need parameter input file'))# Get the content of the SPSWarmUP-INPUT.xml file[xml]$xmlinput = (Get-Content $inputFile)# ====================================================================================# INTERNAL FUNCTIONS# ====================================================================================# Region Load SharePoint Powershell Snapin for SharePoint 2010 & 2013# ===================================================================================# Name: 		Load SharePoint Powershell Snapin# Description:	Load SharePoint Powershell Snapin# ===================================================================================Function Load-SharePoint-Powershell{    If ((Get-PsSnapin |?{$_.Name -eq "Microsoft.SharePoint.PowerShell"})-eq $null)    {        Write-Host -ForegroundColor White "--------------------------------------------------------------"        Write-Host -ForegroundColor White " - Loading SharePoint Powershell Snapin..."        Add-PsSnapin Microsoft.SharePoint.PowerShell -ErrorAction Stop | Out-Null        Write-Host -ForegroundColor White "--------------------------------------------------------------"    }}# Region End# Region Load-SharePoint-Assembly# ===================================================================================# Name: 		Load SharePoint Assembly# Description:	Load SharePoint Assembly for SharePoint 2007, 2010 & 2013# ===================================================================================Function Load-SharePoint-Assembly{	Write-Host -ForegroundColor White "--------------------------------------------------------------"	Write-Host -ForegroundColor White " - Loading Microsoft.SharePoint Assembly..."	[System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SharePoint") | Out-Null	Write-Host -ForegroundColor White "--------------------------------------------------------------"}# Region End# Region Load-System-Web# ===================================================================================# Name: 		Load System Web# Description:	Load System.Web# ===================================================================================Function Load-System-Web{	Write-Host -ForegroundColor White "--------------------------------------------------------------"	Write-Host -ForegroundColor White " - Loading System.Web ..."	[System.Reflection.Assembly]::LoadWithPartialName("system.web") | Out-Null	Write-Host -ForegroundColor White "--------------------------------------------------------------"}# Region End# Region Get All Site Collections Url# ===================================================================================# Name: 		Get All Site Collections Url# Description:	Get All Site Collections Url# ===================================================================================Function Get-AllSitesURL([xml]$xmlinput){	Write-Host -ForegroundColor White "--------------------------------------------------------------"	Write-Host -ForegroundColor White " - Get URLs of All Site Collection..."	$SitesURL = new-Object System.Collections.ArrayList	$ExcludeUrls = $xmlinput.Configuration.ExcludeUrls.ExcludeUrl		If ($xmlinput.Configuration.Settings.IncludeCentralAdmin -eq $true)	{	$WebAppADM = [microsoft.sharepoint.administration.SPAdministrationWebApplication]::Local	$SitesADM = $WebAppADM.sites			foreach ($sites in $SitesADM)		{ 			[void]$SitesURL.Add($sites.Url)			$sites.Dispose() 		}	}	Else	{		Write-Host -ForegroundColor White " - Central Administration Excluded from WarmUp Urls"	}	$WebSrv = [microsoft.sharepoint.administration.spwebservice]::ContentService	$webApps = $WebSrv.WebApplications	foreach ($webApp in $WebApps)	{     		$sites=$WebApp.sites		foreach ($site in $sites)		{			[void]$SitesURL.Add($site.Url)			$site.Dispose() 		}	}	If ($ExcludeUrls.Length -ne 0)	{		Write-Host -ForegroundColor White " - Site Collection Urls Excluded from WarmUp :"		ForEach($ExcludeUrl in $ExcludeUrls)		{			Write-Host -ForegroundColor White "   * $ExcludeUrl"			[void]$SitesURL.Remove($ExcludeUrl)		}	}		return $SitesURL	Write-Host -ForegroundColor White " "}# Region End# Region Get All Web Applications Url# ===================================================================================# Name: 		Get All Web Applications Url# Description:	Get All Web Applications Url# ===================================================================================Function Get-AllWebAppURL{	Write-Host -ForegroundColor White "--------------------------------------------------------------"	Write-Host -ForegroundColor White " - Get URLs of All Web Applications..."	$WebAppURL = new-Object System.Collections.ArrayList	$farm = [Microsoft.SharePoint.Administration.SPFarm]::Local	# get web services from local farm	$websvcs = $farm.Services | where -FilterScript {$_.GetType() -eq [Microsoft.SharePoint.Administration.SPWebService]}	foreach ($websvc in $websvcs) 	{		foreach ($webapp in $websvc.WebApplications)		{			foreach ($AltUrl in $webapp.AlternateUrls)			{				[void]$WebAppURL.Add($AltUrl.uri)			}		}	}    return $WebAppURL	Write-Host -ForegroundColor White " "	}# Region Web-RequestUrl# ===================================================================================# Name: 		Web-RequestUrl# Description:	Request Url with System.Net.WebClient Object# ===================================================================================Function Web-RequestUrl([string] $Url){	$WebRequestObject = [System.Net.HttpWebRequest] [System.Net.WebRequest]::Create($Url)
	$WebRequestObject.UseDefaultCredentials = $true
	$WebRequestObject.Method = "GET"
	$WebRequestObject.Accept = "text/html"
	$WebRequestObject.Timeout = 60000

	Write-Host -ForegroundColor White " - Web Request for url: $url"

	try
	{
		# Get the response of $WebRequestObject
    	$ResponseObject = [System.Net.HttpWebResponse] $WebRequestObject.GetResponse()
	}
	catch [Net.WebException]
	{
    	write-Host -ForegroundColor Yellow $_.Exception.Message
		# Exit the function
		return
	}
 
	try
	{
		# Read the resonse stream
        $ResponseStream = $ResponseObject.getResponseStream()
        $streamReader = new-object IO.StreamReader($ResponseStream)
        # The result will hold the actually returned html
        $result = $streamReader.ReadToEnd()
		$streamReader.Close()
	}
	Catch
	{
		write-Host -ForegroundColor Yellow $_.Exception.Message
	}}# Region End# Region IE-BrowseUrl# ===================================================================================# Name: 		IE-BrowseUrl# Description:	Open Url in Internet Explorer Window# ===================================================================================Function IE-BrowseUrl([string] $url){	Write-Host -ForegroundColor White " Internet Explorer - Browsing $url"	$TimeOut = 90	$Wait = 0	try	{		$global:ie.Navigate($url)		While ($ie.busy -like "True" -Or $Wait -gt $TimeOut)		{			Start-Sleep -s 1			$Wait++		}		Write-Host -ForegroundColor Green "  WebSite successfully loaded in $Wait s"	}	catch	{		$pid = $global:ieproc.id		Write-Host -ForegroundColor Red"  IE not responding.  Closing process ID $pid"		$global:ie.Quit()		$global:ieproc | Stop-Process -Force		$global:ie = New-Object -com "InternetExplorer.Application"		$global:ie.Navigate("about:blank")		$global:ie.visible = $true		$global:ieproc = (Get-Process -Name iexplore)| Where-Object {$_.MainWindowHandle -eq $global:ie.HWND}	}	}# Region End# Region IE-AddTrustIntranetUrl# ===================================================================================# Name: 		IE-AddTrustIntranetUrl# Description:	Add Url in Security Option - Intranet Zone# ===================================================================================Function IE-AddTrustIntranetUrl([string] $url){	# Remove http or https information to keep only HostName or FQDN	$url = $url -replace "https://",""	$url = $url -replace "http://",""	$urlDomain = $url -replace "/",""	if (-not (Test-Path -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings\ZoneMap\Domains\$urlDomain"))	{		Write-Host -ForegroundColor White " - Adding *.$urlDomain to local Intranet security zone..."		New-Item -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings\ZoneMap\Domains" -Name $urlDomain -ItemType Leaf -Force | Out-Null		New-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings\ZoneMap\Domains\$urlDomain" -Name '*' -value "1" -PropertyType dword -Force | Out-Null	}	Else	{		Write-Host -ForegroundColor White " - $urlDomain already added to local Intranet security zone - skipping."	}	if (-not (Test-Path -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings\ZoneMap\EscDomains\$urlDomain"))	{		Write-Host -ForegroundColor White " - Adding *.$urlDomain to local Intranet security zone (IE ESC) ..."		New-Item -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings\ZoneMap\EscDomains" -Name $urlDomain -ItemType Leaf -Force | Out-Null		New-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings\ZoneMap\EscDomains\$urlDomain" -Name '*' -value "1" -PropertyType dword -Force | Out-Null	}	Else	{		Write-Host -ForegroundColor White " - $urlDomain already added to local Intranet security zone (IE ESC) - skipping."	}}# Region End# Region IE-ClearCache# ===================================================================================# Name: 		IE-ClearCache# Description:	Clear Internet Explorer's cache# ===================================================================================Function IE-ClearCache {	$RunDll32 = "$env:windir\System32\rundll32.exe"	If (Test-Path -Path $RunDll32)	{		try		{			Write-Host -ForegroundColor White " - Clearing Cache IE with runDll32.exe ..."			Start-Process -FilePath $RunDll32 -ArgumentList "InetCpl.cpl,ClearMyTracksByProcess 8" -NoNewWindow -Wait -ErrorAction SilentlyContinue		}		Catch		{			Write-Warning "An error occurred attempting to clear internet explorer temporary files."		}	}	Else	{		Write-Host -ForegroundColor White " - Clear Cache IE - The rundll32 is not present in $env:windir\System32 folder"	}}# Region End# Region Disable Loopback Check and Services# ===================================================================================# Func: DisableLoopbackCheck# Desc: Disable Loopback Check# ===================================================================================Function DisableLoopbackCheck([xml]$xmlinput){    # Disable the Loopback Check on stand alone demo servers.    # This setting usually kicks out a 401 error when you try to navigate to sites that resolve to a loopback address e.g.  127.0.0.1    If ($xmlinput.Configuration.Settings.DisableLoopbackCheck -eq $true)    {        Write-Host -ForegroundColor White "--------------------------------------------------------------"		$lsaPath = "HKLM:\System\CurrentControlSet\Control\Lsa"        $lsaPathValue = Get-ItemProperty -path $lsaPath        If (-not ($lsaPathValue.DisableLoopbackCheck -eq "1"))        {			Write-Host -ForegroundColor White " - Disabling Loopback Check..."            New-ItemProperty HKLM:\System\CurrentControlSet\Control\Lsa -Name "DisableLoopbackCheck" -value "1" -PropertyType dword -Force | Out-Null        }		Else		{			Write-Host -ForegroundColor White " - Loopback Check already Disabled - skipping."		}    }}# End Region# Region AddToHOSTS# ====================================================================================# Func: AddToHOSTS# Desc: This writes URLs to the server's local hosts file and points them to the server itself# From: Check http://toddklindt.com/loopback for more information# Copyright Todd Klindt 2011# Originally published to http://www.toddklindt.com/blog# ====================================================================================Function AddToHOSTS ([string] $url){	# Remove http or https information to keep only HostName or FQDN	$url = $url -replace "https://",""	$url = $url -replace "http://",""	$hostname = $url -replace "/",""		If ($hostname.Contains(":"))	{		Write-Host -ForegroundColor White " - $hostname cannot be added in HOSTS File, only web applications with 80 or 443 port are added ."	}	Else	{			# Make backup copy of the Hosts file with today's date		$hostsfile = "$env:windir\System32\drivers\etc\HOSTS"		$date = Get-Date -UFormat "%y%m%d%H%M%S"		$filecopy = $hostsfile + '.' + $date + '.copy'		# Get the contents of the Hosts file		$file = Get-Content $hostsfile		$file = $file | Out-String		# Write the AAMs to the hosts file, unless they already exist.		If ($file.Contains($hostname))		{Write-Host -ForegroundColor White " - HOSTS file entry for `"$hostname`" already exists - skipping."}		Else		{			Write-Host -ForegroundColor White " - Backing up HOSTS file to:"			Write-Host -ForegroundColor White " - $filecopy"			Copy-Item $hostsfile -Destination $filecopy					Write-Host -ForegroundColor White " - Adding HOSTS file entry for `"$hostname`"..."			Add-Content -Path $hostsfile -Value "`r"			Add-Content -Path $hostsfile -value "127.0.0.1 `t $hostname"		}	}}# Region End# Region Add-UserPolicy# ===================================================================================# Func: Add-UserPolicy# Desc: Applies Read Access to the specified accounts for a web application# ===================================================================================Function Add-UserPolicy([String]$url){    Try    {		$webapp = [Microsoft.SharePoint.Administration.SPWebApplication]::Lookup("$url")		$user = ([Security.Principal.WindowsIdentity]::GetCurrent()).Name		$displayName = "WarmUp Account"		$perm = "Full Read"				# If the web app is not Central Administration 		If ($webapp.IsAdministrationWebApplication -eq $false)		{			# If the web app is using Claims auth, change the user accounts to the proper syntax			If ($webapp.UseClaimsAuthentication -eq $true)			{				$user = 'i:0#.w|'+$user			}			Write-Host -ForegroundColor White " - Applying Read access for $user account to $url..."			[Microsoft.SharePoint.Administration.SPPolicyCollection]$policies = $webapp.Policies			[Microsoft.SharePoint.Administration.SPPolicy]$policy = $policies.Add($user, $displayName)			[Microsoft.SharePoint.Administration.SPPolicyRole]$policyRole = $webapp.PolicyRoles | where {$_.Name -eq $perm}			If ($policyRole -ne $null)			{				$policy.PolicyRoleBindings.Add($policyRole)			}			$webapp.Update()			Write-Host -ForegroundColor White " - Done Applying Read access for `"$user`" account to `"$url`""		}    }    Catch    {        $_        Write-Warning "An error occurred applying Read access for `"$user`" account to `"$url`""    }}# Region End# Region Disable-InternetExplorer-ESC# ===================================================================================# Func: Disable-InternetExplorer-ESC# Desc: Disable Internet Explorer Enhanced Security Configuration for administrators# ===================================================================================Function Disable-InternetExplorer-ESC([xml]$xmlinput){	If($xmlinput.Configuration.Settings.DisableIEESC -eq $true)
	{
		Write-Host -ForegroundColor White "--------------------------------------------------------------"
		Try
		{			
			$AdminKey = "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A7-37EF-4b3f-8CFC-4F3A74704073}"
			$AdminKeyValue = Get-ItemProperty -Path $AdminKey
			If (-not ($AdminKeyValue.IsInstalled -eq "0"))
			{
				Write-Host -ForegroundColor White " - Disabling Internet Explorer Enhanced Security Configuration ..."
				Set-ItemProperty -Path $AdminKey -Name "IsInstalled" -Value 0
			}
			Else
			{
				Write-Host -ForegroundColor White " - Internet Explorer ESC already Disabled - skipping."
			}
		}
		Catch 
		{
			Write-Host "Failed to Disable Internet Explorer Enhanced Security Configuration"
		}
	}
}
# Region End# Region DisableIEFirstRun# ===================================================================================# Func: DisableIEFirstRun# Desc: Disable First Run for Internet Explorer# ===================================================================================Function DisableIEFirstRun(){    Write-Host -ForegroundColor White "--------------------------------------------------------------"	$lsaPath = "HKCU:\Software\Microsoft\Internet Explorer\Main"    $lsaPathValue = Get-ItemProperty -path $lsaPath    If (-not ($lsaPathValue.DisableFirstRunCustomize -eq "1"))    {		Write-Host -ForegroundColor White " - Disabling Internet Explorer First Run ..."        New-ItemProperty "HKCU:\Software\Microsoft\Internet Explorer\Main" -Name "DisableFirstRunCustomize" -value "1" -PropertyType dword -Force | Out-Null    }	Else	{		Write-Host -ForegroundColor White " - Internet Explorer First Run already Disabled - skipping."	}}# End Region# Region SendEmailNotification# ===================================================================================# Func: SendEmailNotification# Desc: Send Email with log file in attachment# ===================================================================================Function SendEmailNotification([xml]$xmlinput, $MailAttachment){	If($xmlinput.Configuration.EmailNotification.Enable -eq $true)	{		Try{			$MailAddress = $xmlinput.Configuration.EmailNotification.EmailAddress			$SMTPServer = $xmlinput.Configuration.EmailNotification.SMTPServer			$MailSubject = "Automated Script - WarmUp Urls - $env:COMPUTERNAME"			Write-Host -ForegroundColor White "--------------------------------------------------------------"			Write-Host -ForegroundColor White " - Sending Email to $MailAddress with $logFile in attachments ..."			Send-MailMessage -To $MailAddress -From $MailAddress -Subject $MailSubject  -SmtpServer $SMTPServer -Attachments $MailAttachment			Write-Host -ForegroundColor Green " - Email sent successfully to $MailAddress"		}
		Catch 
		{
			Write-Host "Failed to Send Email to $MailAddress with SMTP : $SMTPServer"
		}	}}# End Region# ===================================================================================## WarmUp Script - MAIN Region## ===================================================================================cls$Host.UI.RawUI.WindowTitle = " -- WarmUP script -- $env:COMPUTERNAME --"# Logging PowerShell script in rtf file $logfolder = Split-Path -parent $MyInvocation.MyCommand.Definition$logTime = Get-Date -Format yyyy-MM-dd_h-mm$logFile = "$logfolder\WarmUP_script_$logTime.rtf"$currentuser = ([Security.Principal.WindowsIdentity]::GetCurrent()).NameStart-Transcript -Path $logFile -Append -Force | out-Null# Define Variables with Global scopeNew-Variable -Name Sites -Scope GlobalNew-Variable -Name WebApps -Scope Global$DateStarted = Get-dateWrite-Host -ForegroundColor Green "-----------------------------------"Write-Host -ForegroundColor Green "| Automated Script - WarmUp Urls |"Write-Host -ForegroundColor Green "| Started on: $DateStarted |"Write-Host -ForegroundColor Green "-----------------------------------"# Check Permission LevelIf (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")){	Write-Warning "You do not have Administrator rights to run this script!`nPlease re-run this script as an Administrator!"	Break} else {	# Load SharePoint Powershell Assembly and System.Web	Load-SharePoint-Assembly	Load-System-Web	# Get All Web Applications Urls	$WebApps = Get-AllWebAppURL		# Disable LoopBack Check	DisableLoopbackCheck $xmlinput	# Disable Internet Explorer Enhanced Security Configuration and First Run	Disable-InternetExplorer-ESC $xmlinput	DisableIEFirstRun		# Add Web Application Url in Intranet Security Options for Internet Explorer and in HOSTS system File	Write-Host -ForegroundColor White "--------------------------------------------------------------"	Write-Host -ForegroundColor White " - Add URLs of All Web Applications in Internet Settings/Security ..."	ForEach ($WebApp in $WebApps)	{		IE-AddTrustIntranetUrl $WebApp	}	# Add Web Application Url in HOSTS system File	Write-Host -ForegroundColor White "--------------------------------------------------------------"	Write-Host -ForegroundColor White " - Add URLs of All Web Applications in HOSTS File ..."	ForEach ($WebApp in $WebApps)	{		AddToHOSTS $WebApp	}		# Add Web Application Url in Intranet Security Options for Internet Explorer and in HOSTS system File	Write-Host -ForegroundColor White "--------------------------------------------------------------"	Write-Host -ForegroundColor White " - Add Read Access to $currentuser for All Web Applications ..."	ForEach ($WebApp in $WebApps)	{		Add-UserPolicy $WebApp	}		# Get All Site Collections Urls	$Sites = Get-AllSitesURL($xmlinput)	# Request Url with System.Net.WebClient Object for All Site Collections Urls	Write-Host -ForegroundColor White "--------------------------------------------------------------"	Write-Host -ForegroundColor White " - Opening All sites URl with Web Request Object ..."	ForEach ($Site in $Sites)	{		Web-RequestUrl $Site	}	$CustomUrls = $xmlinput.Configuration.CustomUrls.CustomUrl	If ($CustomUrls.Length -ne 0)	{	Write-Host -ForegroundColor White "--------------------------------------------------------------"	Write-Host -ForegroundColor White " - Opening All custom URl with Web Request Object ..."			ForEach($CustomUrl in $CustomUrls)		{			Web-RequestUrl $CustomUrl		}	}	If($xmlinput.Configuration.Settings.UseIEforWarmUp -eq $true)	{		# Run Internet Explorer		Write-Host -ForegroundColor White "--------------------------------------------------------------"		Write-Host -ForegroundColor White " - Opening All sites URl with Internet Explorer ..."		# Remove Internet Explorer Temporary Files with RunDll32.exe		IE-ClearCache		$global:ie = New-Object -com "InternetExplorer.Application"		$global:ie.Navigate("about:blank")		$global:ie.visible = $true		$global:ieproc = (Get-Process -Name iexplore)| Where-Object {$_.MainWindowHandle -eq $global:ie.HWND}			ForEach ($Site in $Sites)		{			IE-BrowseUrl $Site		}			$CustomUrls = $xmlinput.Configuration.CustomUrls.CustomUrl		If ($CustomUrls.Length -ne 0)		{		Write-Host -ForegroundColor White "--------------------------------------------------------------"		Write-Host -ForegroundColor White " - Opening All custom URl with Internet Explorer ..."				ForEach($CustomUrl in $CustomUrls)			{				IE-BrowseUrl $CustomUrl			}		}				# Quit Internet Explorer		if ($global:ie)		{			Write-Host -ForegroundColor White "--------------------------------------------------------------"			Write-Host -ForegroundColor White " - Closing Internet Explorer ..."			$global:ie.Quit()		}	}		$DateEnded = Get-date	Write-Host -ForegroundColor Green "-----------------------------------"	Write-Host -ForegroundColor Green "| Automated Script - WarmUp Urls |"	Write-Host -ForegroundColor Green "| Started on: $DateStarted |"	Write-Host -ForegroundColor Green "| Completed on: $DateEnded |"	Write-Host -ForegroundColor Green "-----------------------------------"		Stop-Transcript | out-Null	# Send Email with log file in attachment - For settings see XML input file	SendEmailNotification $xmlinput $logFile 	Exit}