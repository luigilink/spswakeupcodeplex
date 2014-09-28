﻿<#.SYNOPSIS      WarmUP script for SharePoint 2007, 2010 & 2013.DESCRIPTION  	SPSWakeUp is a PowerShell script tool to warm up all site collection in your SharePoint environment.	It's compatible with all supported versions for SharePoint (2007, 2010 and 2013).	Use Internet Explorer to download JS, CSS and Pictures files, 	Log script results in rtf file, 	Email nofications, 	Configure automatically prerequisites for a best warm-up, 	Possibility to add or remove custom url.PARAMETER inputFile	Need parameter input file, example: 	PS D:\> E:\SCRIPT\SPSWakeUP.ps1 "E:\SCRIPT\SPSWakeUP.xml".EXAMPLE	SPSWakeUP.ps1 "E:\SCRIPT\SPSWakeUP.xml".NOTES  	FileName:	SPSWarmUP.ps1	Author:		Jean-Cyril DROUHIN	Date:		September 19, 2014	Version:	1.7	Licence:	MS-PL.LINK	http://spswarmup.codeplex.com#>	param (    [string]$inputFile = $(throw '- Need parameter input file'))# Get the content of the SPSWarmUP-INPUT.xml file[xml]$xmlinput = (Get-Content $inputFile -ReadCount 0)# ====================================================================================# INTERNAL FUNCTIONS# ====================================================================================# Region Load SharePoint Powershell Snapin for SharePoint 2010 & 2013# ===================================================================================# Name: 		Load SharePoint Powershell Snapin# Description:	Load SharePoint Powershell Snapin# ===================================================================================Function Load-SharePoint-Powershell{    If ((Get-PsSnapin |?{$_.Name -eq "Microsoft.SharePoint.PowerShell"})-eq $null)    {        Write-Host -ForegroundColor White "--------------------------------------------------------------"        Write-Host -ForegroundColor Cyan " - Loading SharePoint Powershell Snapin..."        Add-PsSnapin Microsoft.SharePoint.PowerShell -ErrorAction Stop | Out-Null        Write-Host -ForegroundColor White "--------------------------------------------------------------"    }}# Region End# Region Load-SharePoint-Assembly# ===================================================================================# Name: 		Load SharePoint Assembly# Description:	Load SharePoint Assembly for SharePoint 2007, 2010 & 2013# ===================================================================================Function Load-SharePoint-Assembly{	Write-Host -ForegroundColor White "--------------------------------------------------------------"	Write-Host -ForegroundColor Cyan " - Loading Microsoft.SharePoint Assembly..."	[System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SharePoint") | Out-Null	Write-Host -ForegroundColor White "--------------------------------------------------------------"}# Region End# Region Load-System-Web# ===================================================================================# Name: 		Load System Web# Description:	Load System.Web# ===================================================================================Function Load-System-Web{	If($xmlinput.Configuration.Settings.UseIEforWarmUp -eq $false)	{		Write-Host -ForegroundColor White "--------------------------------------------------------------"		Write-Host -ForegroundColor Cyan " - Loading System.Web ..."		[System.Reflection.Assembly]::LoadWithPartialName("system.web") | Out-Null		Write-Host -ForegroundColor White "--------------------------------------------------------------"	}}# Region End# Region Get All Site Collections Url# ===================================================================================# Name: 		Get All Site Collections Url# Description:	Get All Site Collections Url# ===================================================================================Function Get-AllSitesURL([xml]$xmlinput){	Write-Host -ForegroundColor White "--------------------------------------------------------------"	Write-Host -ForegroundColor White " - Get URLs of All Site Collection ... Please waiting"	# Variable Declaration	$SitesURL = new-Object System.Collections.ArrayList	$ExcludeUrls = $xmlinput.Configuration.ExcludeUrls.ExcludeUrl	$CustomUrls = $xmlinput.Configuration.CustomUrls.CustomUrl	$NumSites = 0		# Get url of CentralAdmin if include in input xml file	If ($xmlinput.Configuration.Settings.IncludeCentralAdmin -eq $true)	{		$WebAppADM = [microsoft.sharepoint.administration.SPAdministrationWebApplication]::Local		$SitesADM = $WebAppADM.sites		foreach ($sites in $SitesADM)		{ 			[void]$SitesURL.Add($sites.Url)			$sites.Dispose() 		}		Write-Host -ForegroundColor White "   * Central Administration included in WarmUp Urls"	}	Else	{		Write-Host -ForegroundColor White "   * Central Administration excluded from WarmUp Urls"	}		# Get Url of all site collection	$WebSrv = [microsoft.sharepoint.administration.spwebservice]::ContentService	$webApps = $WebSrv.WebApplications	$sites = $webApps | ForEach-Object {$_.sites}	ForEach($site in $sites)	{		[void]$SitesURL.Add($site.Url)		$site.Dispose()		$NumSites++	}	Write-Host -ForegroundColor White "   * $NumSites site collection will be waking up ..."		# Remove Site Collection Urls from WarmUp	If ($ExcludeUrls.Length -ne 0)	{		Write-Host -ForegroundColor White " - Site Collection Urls Excluded from WarmUp :"		$global:MailContent += "<br>Site Collection Urls Excluded from WarmUp :<br>"		ForEach($ExcludeUrl in $ExcludeUrls)		{			Write-Host -ForegroundColor White "   * $ExcludeUrl"			$global:MailContent += "$ExcludeUrl<br>"			[void]$SitesURL.Remove($ExcludeUrl)		}	}		# Add Site Collection Urls in WarmUp	If ($CustomUrls.Length -ne 0)	{		Write-Host -ForegroundColor White " - Custom Urls added in WarmUp :"		$global:MailContent += "<br>Custom Urls added in WarmUp :<br>"		ForEach($CustomUrl in $CustomUrls)		{			Write-Host -ForegroundColor White "   * $CustomUrl"			$global:MailContent += "$CustomUrl<br>"			[void]$SitesURL.Add($CustomUrl)		}	}	return $SitesURL	Write-Host -ForegroundColor White " "}# Region End# Region Get All Web Applications Url# ===================================================================================# Name: 		Get All Web Applications Url# Description:	Get All Web Applications Url# ===================================================================================Function Get-AllWebAppURL{	Write-Host -ForegroundColor White "--------------------------------------------------------------"	Write-Host -ForegroundColor White " - Get URLs of All Web Applications..."	$WebAppURL = new-Object System.Collections.ArrayList	$farm = [Microsoft.SharePoint.Administration.SPFarm]::Local	# get web services from local farm	$websvcs = $farm.Services | where -FilterScript {$_.GetType() -eq [Microsoft.SharePoint.Administration.SPWebService]}	foreach ($websvc in $websvcs) 	{		foreach ($webapp in $websvc.WebApplications)		{			foreach ($AltUrl in $webapp.AlternateUrls)			{				[void]$WebAppURL.Add($AltUrl.uri)			}		}	}    return $WebAppURL	Write-Host -ForegroundColor White " "	}# Region Web-RequestUrl# ===================================================================================# Name: 		Web-RequestUrl# Description:	Request Url with System.Net.WebClient Object# ===================================================================================Function Web-RequestUrl($Urls){	ForEach ($Url in $Urls)	{		$TimeStart = Get-Date		$WebRequestObject = [System.Net.HttpWebRequest] [System.Net.WebRequest]::Create($Url)		$WebRequestObject.UseDefaultCredentials = $true		$WebRequestObject.Method = "GET"		$WebRequestObject.Accept = "text/html"		$WebRequestObject.Timeout = 80000		Write-Host -ForegroundColor White " - Web Request for url: $url"		$global:MailContent += " - Web Request for url: $url"		try		{			# Get the response of $WebRequestObject			$ResponseObject = [System.Net.HttpWebResponse] $WebRequestObject.GetResponse()			$TimeStop = Get-Date			$TimeExec = ($TimeStop - $TimeStart).TotalSeconds			'{0,-30} : {1,10:#,##0.00} s' -f '   WebSite successfully loaded in', $TimeExec			#Write-Host -ForegroundColor Green "   * WebSite successfully loaded in $TimeExec s"			$global:MailContent += "<br><font color=green>WebSite successfully loaded in $TimeExec s</font><br>"		}		catch [Net.WebException]		{			$ExceptionText = "   ! " + $_.Exception.Message	    	write-Host -ForegroundColor Yellow $ExceptionText			$global:MailContent += "<br><font color=red>$ExceptionText</font><br>"		}		finally 		{			# Issue 1451 - https://spswakeup.codeplex.com/workitem/1451			# Thanks to Pupasini - Closing the HttpWebResponse object					if ($ResponseObject) 			{				$ResponseObject.Close()				Remove-Variable ResponseObject			}		}	}}# Region End# Region IE-BrowseUrl# ===================================================================================# Name: 		IE-BrowseUrl# Description:	Open Url in Internet Explorer Window# ===================================================================================Function IE-BrowseUrl($urls){	# Run Internet Explorer	$global:ie = New-Object -com "InternetExplorer.Application"	$global:ie.Navigate("about:blank")	$global:ie.visible = $true	$global:ieproc = (Get-Process -Name iexplore)| Where-Object {$_.MainWindowHandle -eq $global:ie.HWND}		ForEach ($url in $urls)	{		Write-Host -ForegroundColor White " - Internet Explorer - Browsing $url"		$global:MailContent += "- Browsing $url"		$TimeOut = 90		$Wait = 0		try		{			$global:ie.Navigate($url)			While ($ie.busy -like "True" -Or $Wait -gt $TimeOut)			{				Start-Sleep -s 1				$Wait++			}			Write-Host -ForegroundColor Green "   * WebSite successfully loaded in $Wait s"			$global:MailContent += "<br><font color=green>WebSite successfully loaded in $Wait s</font><br>"		}		catch		{			$pid = $global:ieproc.id			Write-Host -ForegroundColor Red"  IE not responding.  Closing process ID $pid"			$global:ie.Quit()			$global:ieproc | Stop-Process -Force			$global:ie = New-Object -com "InternetExplorer.Application"			$global:ie.Navigate("about:blank")			$global:ie.visible = $true			$global:ieproc = (Get-Process -Name iexplore)| Where-Object {$_.MainWindowHandle -eq $global:ie.HWND}		}	}	# Quit Internet Explorer	if ($global:ie)	{		Write-Host -ForegroundColor White "--------------------------------------------------------------"		Write-Host -ForegroundColor White " - Closing Internet Explorer ..."		$global:ie.Quit()	}}# Region End# Region IE-AddTrustIntranetUrl# ===================================================================================# Name: 		IE-AddTrustIntranetUrl# Description:	Add Url in Security Option - Intranet Zone# ===================================================================================Function IE-AddTrustIntranetUrl($urls){	Write-Host -ForegroundColor White "--------------------------------------------------------------"	Write-Host -ForegroundColor White " - Add URLs of All Web Applications in Internet Settings/Security ..."	ForEach ($url in $urls)	{		# Remove http or https information to keep only HostName or FQDN		$url = $url -replace "https://",""		$url = $url -replace "http://",""		$urlDomain = $url -replace "/",""		if (-not (Test-Path -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings\ZoneMap\Domains\$urlDomain"))		{			Write-Host -ForegroundColor White " - Adding *.$urlDomain to local Intranet security zone..."			New-Item -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings\ZoneMap\Domains" -Name $urlDomain -ItemType Leaf -Force | Out-Null			New-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings\ZoneMap\Domains\$urlDomain" -Name '*' -value "1" -PropertyType dword -Force | Out-Null		}		Else		{			Write-Host -ForegroundColor White " - $urlDomain already added to local Intranet security zone - skipping."		}		if (-not (Test-Path -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings\ZoneMap\EscDomains\$urlDomain"))		{			Write-Host -ForegroundColor White " - Adding *.$urlDomain to local Intranet security zone (IE ESC) ..."			New-Item -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings\ZoneMap\EscDomains" -Name $urlDomain -ItemType Leaf -Force | Out-Null			New-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings\ZoneMap\EscDomains\$urlDomain" -Name '*' -value "1" -PropertyType dword -Force | Out-Null		}		Else		{			Write-Host -ForegroundColor White " - $urlDomain already added to local Intranet security zone (IE ESC) - skipping."		}	}}# Region End# Region IE-ClearCache# ===================================================================================# Name: 		IE-ClearCache# Description:	Clear Internet Explorer's cache# ===================================================================================Function IE-ClearCache {	$RunDll32 = "$env:windir\System32\rundll32.exe"	If (Test-Path -Path $RunDll32)	{		try		{			Write-Host -ForegroundColor White " - Cleaning Cache IE with runDll32.exe ..."			Start-Process -FilePath $RunDll32 -ArgumentList "InetCpl.cpl,ClearMyTracksByProcess 8" -NoNewWindow -Wait -ErrorAction SilentlyContinue		}		Catch		{			Write-Warning "An error occurred attempting to clear internet explorer temporary files."		}	}	Else	{		Write-Host -ForegroundColor White " - Clear Cache IE - The rundll32 is not present in $env:windir\System32 folder"	}}# Region End# Region Disable Loopback Check and Services# ===================================================================================# Func: DisableLoopbackCheck# Desc: Disable Loopback Check# ===================================================================================Function DisableLoopbackCheck([xml]$xmlinput){    # Disable the Loopback Check on stand alone demo servers.    # This setting usually kicks out a 401 error when you try to navigate to sites that resolve to a loopback address e.g.  127.0.0.1    If ($xmlinput.Configuration.Settings.DisableLoopbackCheck -eq $true)    {        Write-Host -ForegroundColor White "--------------------------------------------------------------"		$lsaPath = "HKLM:\System\CurrentControlSet\Control\Lsa"        $lsaPathValue = Get-ItemProperty -path $lsaPath        If (-not ($lsaPathValue.DisableLoopbackCheck -eq "1"))        {			Write-Host -ForegroundColor White " - Disabling Loopback Check..."            New-ItemProperty HKLM:\System\CurrentControlSet\Control\Lsa -Name "DisableLoopbackCheck" -value "1" -PropertyType dword -Force | Out-Null        }		Else		{			Write-Host -ForegroundColor White " - Loopback Check already Disabled - skipping."		}    }}# End Region# Region AddToHOSTS# ====================================================================================# Func: AddToHOSTS# Desc: This writes URLs to the server's local hosts file and points them to the server itself# From: Check http://toddklindt.com/loopback for more information# Copyright Todd Klindt 2011# Originally published to http://www.toddklindt.com/blog# ====================================================================================Function AddToHOSTS ($urls){	Write-Host -ForegroundColor White "--------------------------------------------------------------"	Write-Host -ForegroundColor White " - Add Urls of All Web Applications in HOSTS File ..."	ForEach ($url in $urls)	{		# Remove http or https information to keep only HostName or FQDN		$url = $url -replace "https://",""		$url = $url -replace "http://",""		$hostname = $url -replace "/",""				If ($hostname.Contains(":"))		{			Write-Host -ForegroundColor White " - $hostname cannot be added in HOSTS File, only web applications with 80 or 443 port are added ."		}		Else		{				# Make backup copy of the Hosts file with today's date			$hostsfile = "$env:windir\System32\drivers\etc\HOSTS"			$date = Get-Date -UFormat "%y%m%d%H%M%S"			$filecopy = $hostsfile + '.' + $date + '.copy'			# Get the contents of the Hosts file			$file = Get-Content $hostsfile -ReadCount 0			$file = $file | Out-String			# Write the AAMs to the hosts file, unless they already exist.			If ($file.Contains($hostname))			{Write-Host -ForegroundColor White " - HOSTS file entry for `"$hostname`" already exists - skipping."}			Else			{				Write-Host -ForegroundColor White " - Backing up HOSTS file to:"				Write-Host -ForegroundColor White " - $filecopy"				Copy-Item $hostsfile -Destination $filecopy							Write-Host -ForegroundColor White " - Adding HOSTS file entry for `"$hostname`"..."				Add-Content -Path $hostsfile -Value "`r"				Add-Content -Path $hostsfile -value "127.0.0.1 `t $hostname"			}		}	}}# Region End# Region Add-UserPolicy# ===================================================================================# Func: Add-UserPolicy# Desc: Applies Read Access to the specified accounts for a web application# ===================================================================================Function Add-UserPolicy($urls){	Write-Host -ForegroundColor White "--------------------------------------------------------------"	Write-Host -ForegroundColor White " - Add Read Access to $currentuser for All Web Applications ..."	ForEach ($url in $urls)	{		Try		{			$webapp = [Microsoft.SharePoint.Administration.SPWebApplication]::Lookup("$url")			$user = ([Security.Principal.WindowsIdentity]::GetCurrent()).Name			$displayName = "WarmUp Account"			$perm = "Full Read"						# If the web app is not Central Administration 			If ($webapp.IsAdministrationWebApplication -eq $false)			{				# If the web app is using Claims auth, change the user accounts to the proper syntax				If ($webapp.UseClaimsAuthentication -eq $true)				{					$user = 'i:0#.w|'+$user				}				Write-Host -ForegroundColor White " - Applying Read access for $user account to $url..."				[Microsoft.SharePoint.Administration.SPPolicyCollection]$policies = $webapp.Policies				[Microsoft.SharePoint.Administration.SPPolicy]$policy = $policies.Add($user, $displayName)				[Microsoft.SharePoint.Administration.SPPolicyRole]$policyRole = $webapp.PolicyRoles | where {$_.Name -eq $perm}				If ($policyRole -ne $null)				{					$policy.PolicyRoleBindings.Add($policyRole)				}				$webapp.Update()				Write-Host -ForegroundColor White " - Done Applying Read access for `"$user`" account to `"$url`""			}		}		Catch		{			$_			Write-Warning "An error occurred applying Read access for `"$user`" account to `"$url`""		}	}}# Region End# Region Disable-InternetExplorer-ESC# ===================================================================================# Func: Disable-InternetExplorer-ESC# Desc: Disable Internet Explorer Enhanced Security Configuration for administrators# ===================================================================================Function Disable-InternetExplorer-ESC([xml]$xmlinput){	If($xmlinput.Configuration.Settings.DisableIEESC -eq $true)	{		Write-Host -ForegroundColor White "--------------------------------------------------------------"		Try		{						$AdminKey = "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A7-37EF-4b3f-8CFC-4F3A74704073}"			$AdminKeyValue = Get-ItemProperty -Path $AdminKey			If (-not ($AdminKeyValue.IsInstalled -eq "0"))			{				Write-Host -ForegroundColor White " - Disabling Internet Explorer Enhanced Security Configuration ..."				Set-ItemProperty -Path $AdminKey -Name "IsInstalled" -Value 0			}			Else			{				Write-Host -ForegroundColor White " - Internet Explorer ESC already Disabled - skipping."			}		}		Catch 		{			Write-Host "Failed to Disable Internet Explorer Enhanced Security Configuration"		}	}}# Region End# Region DisableIEFirstRun# ===================================================================================# Func: DisableIEFirstRun# Desc: Disable First Run for Internet Explorer# ===================================================================================Function DisableIEFirstRun(){    Write-Host -ForegroundColor White "--------------------------------------------------------------"	$lsaPath = "HKCU:\Software\Microsoft\Internet Explorer\Main"    $lsaPathValue = Get-ItemProperty -path $lsaPath    If (-not ($lsaPathValue.DisableFirstRunCustomize -eq "1"))    {		Write-Host -ForegroundColor White " - Disabling Internet Explorer First Run ..."        New-ItemProperty "HKCU:\Software\Microsoft\Internet Explorer\Main" -Name "DisableFirstRunCustomize" -value "1" -PropertyType dword -Force | Out-Null    }	Else	{		Write-Host -ForegroundColor White " - Internet Explorer First Run already Disabled - skipping."	}}# End Region# Region SendEmailNotification# ===================================================================================# Func: SendEmailNotification# Desc: Send Email with log file in attachment# ===================================================================================Function SendEmailNotification([xml]$xmlinput, $MailAttachment, $MailBody){	If($xmlinput.Configuration.EmailNotification.Enable -eq $true)	{		Try{			$MailAddress = $xmlinput.Configuration.EmailNotification.EmailAddress			$SMTPServer = $xmlinput.Configuration.EmailNotification.SMTPServer			$MailSubject = "Automated Script - WarmUp Urls - $env:COMPUTERNAME"			Write-Host -ForegroundColor White "--------------------------------------------------------------"			Write-Host -ForegroundColor White " - Sending Email to $MailAddress with $logFile in attachments ..."			Send-MailMessage -To $MailAddress -From $MailAddress -Subject $MailSubject -Body $MailBody -BodyAsHtml -SmtpServer $SMTPServer -Attachments $MailAttachment			Write-Host -ForegroundColor Green " - Email sent successfully to $MailAddress"		}		Catch 		{			Write-Host "Failed to Send Email to $MailAddress with SMTP : $SMTPServer"		}	}}# End Region# Region CleanLogs# ===================================================================================# Func: CleanLogs# Desc: Clean Log Files# ===================================================================================Function CleanLogs([xml]$xmlinput, $logfolder){	If($xmlinput.Configuration.Settings.CleanLogs.Enable -eq $true)	{		If(Test-Path $logfolder)		{			# Days of logs that will be remaining after log cleanup. 			$days = $xmlinput.Configuration.Settings.CleanLogs.Days						# Get the current date			$Now = Get-Date						# Definie the extension of log files			$Extension = "*.rtf"						# Define LastWriteTime parameter based on $days			$LastWrite = $Now.AddDays(-$days)						# Get files based on lastwrite filter and specified folder			$Files = Get-Childitem $logfolder -Include $Extension | Where {$_.LastWriteTime -le "$LastWrite"}			Write-Host -ForegroundColor White "--------------------------------------------------------------"			Write-Host -ForegroundColor White " - Cleaning log files in $logfolder ..."			foreach ($File in $Files) 			{			if ($File -ne $NULL)				{				write-host -ForegroundColor Yellow " * Deleting File $File ..."				Remove-Item $File.FullName | out-null				}			else				{								Write-Host -ForegroundColor White " - No more log files to delete "				Write-Host -ForegroundColor White "--------------------------------------------------------------"				}			}		}	}	Else	{		Write-Host -ForegroundColor White "--------------------------------------------------------------" 		Write-Host -ForegroundColor Yellow " Clean of logs is disabled in XML input file. "		Write-Host -ForegroundColor White "--------------------------------------------------------------"		}}# End Region# ===================================================================================## WarmUp Script - MAIN Region## ===================================================================================cls$Host.UI.RawUI.WindowTitle = " -- WarmUP script -- $env:COMPUTERNAME --"# Logging PowerShell script in rtf file $logfolder = Split-Path -parent $MyInvocation.MyCommand.Definition$logTime = Get-Date -Format yyyy-MM-dd_h-mm$logFile = "$logfolder\WarmUP_script_$logTime.rtf"$currentuser = ([Security.Principal.WindowsIdentity]::GetCurrent()).NameStart-Transcript -Path $logFile -Append -Force | out-Null$DateStarted = Get-dateWrite-Host -ForegroundColor Green "-----------------------------------"Write-Host -ForegroundColor Green "| Automated Script - WarmUp Urls |"Write-Host -ForegroundColor Green "| Started on: $DateStarted |"Write-Host -ForegroundColor Green "-----------------------------------"$global:MailContent = "Automated Script - WarmUp Urls - Started on: $DateStarted <br>"$global:MailContent += "SharePoint Server : $env:COMPUTERNAME<br>"# Check Permission LevelIf (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")){	Write-Warning "You do not have Administrator rights to run this script!`nPlease re-run this script as an Administrator!"	Break} else {	# Load SharePoint Powershell Assembly and System.Web	Load-SharePoint-Assembly	Load-System-Web	# Get All Web Applications Urls	$WebApps = Get-AllWebAppURL		# Disable LoopBack Check	DisableLoopbackCheck $xmlinput	# Disable Internet Explorer Enhanced Security Configuration and First Run	Disable-InternetExplorer-ESC $xmlinput	DisableIEFirstRun		# Add Web Application Url in Intranet Security Options for Internet Explorer and in HOSTS system File	IE-AddTrustIntranetUrl $WebApps	# Add Web Application Url in HOSTS system File	AddToHOSTS $WebApps		# Add Web Application Url in Intranet Security Options for Internet Explorer and in HOSTS system File	Add-UserPolicy $WebApps		# Get All Site Collections Urls	$Sites = Get-AllSitesURL($xmlinput)	If($xmlinput.Configuration.Settings.UseIEforWarmUp -eq $true)	{		# Request Url with Internet Explorer for All Site Collections Urls		Write-Host -ForegroundColor White "--------------------------------------------------------------"		# Remove Internet Explorer Temporary Files with RunDll32.exe		IE-ClearCache		Write-Host -ForegroundColor White " - Opening All sites Urls with Internet Explorer ..."		$global:MailContent += "<br>Opening All sites Urls with Internet Explorer ... <br>"		IE-BrowseUrl $Sites	}	Else	{		# Request Url with System.Net.WebClient Object for All Site Collections Urls		Write-Host -ForegroundColor White "--------------------------------------------------------------"		Write-Host -ForegroundColor Yellow " - UseIEforWarmUp is set to False - Opening All sites Urls with Web Request ..."		$global:MailContent += "<br>Opening All sites Urls with Web Request Object ...<br>"		Web-RequestUrl $Sites	}		# Clean the folder of log files 	CleanLogs $xmlinput $logfolder		$DateEnded = Get-date	Write-Host -ForegroundColor Green "-----------------------------------"	Write-Host -ForegroundColor Green "| Automated Script - WarmUp Urls |"	Write-Host -ForegroundColor Green "| Started on: $DateStarted |"	Write-Host -ForegroundColor Green "| Completed on: $DateEnded |"	Write-Host -ForegroundColor Green "-----------------------------------"	$global:MailContent += "<br>"	$global:MailContent += "Automated Script - WarmUp Urls - Completed on: $DateEnded"	Stop-Transcript | out-Null		# Send Email with log file in attachment - For settings see XML input file	SendEmailNotification $xmlinput $logFile $global:MailContent		Exit}