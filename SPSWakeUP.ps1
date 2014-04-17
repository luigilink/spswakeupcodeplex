﻿# ====================================================================================# Description:	WarmUP script for SharePoint 2007, 2010 & 2013# FileName:		SPSWarmUP.ps1# Author:		Jean-Cyril DROUHIN# Date:			Avril 16, 2014# Version:		1.4# URL:			http://spswarmup.codeplex.com# Licence:		MS-PL# ====================================================================================param (    [string]$inputFile = $(throw '- Need parameter input file'))# Get the content of the SPSWarmUP-INPUT.xml file[xml]$xmlinput = (Get-Content $inputFile)# ====================================================================================# INTERNAL FUNCTIONS# ====================================================================================# Region Load SharePoint Powershell Snapin for SharePoint 2010 & 2013# ===================================================================================# Name: 		Load SharePoint Powershell Snapin# Description:	Load SharePoint Powershell Snapin# ===================================================================================Function Load-SharePoint-Powershell{    If ((Get-PsSnapin |?{$_.Name -eq "Microsoft.SharePoint.PowerShell"})-eq $null)    {        Write-Host -ForegroundColor White "--------------------------------------------------------------"        Write-Host -ForegroundColor White " - Loading SharePoint Powershell Snapin..."        Add-PsSnapin Microsoft.SharePoint.PowerShell -ErrorAction Stop | Out-Null        Write-Host -ForegroundColor White "--------------------------------------------------------------"    }}# Region End# Region Load SharePoint Assembly for SharePoint 2007# ===================================================================================# Name: 		Load SharePoint Assembly# Description:	Load SharePoint Assembly# ===================================================================================Function Load-SharePoint-Assembly{	Write-Host -ForegroundColor White "--------------------------------------------------------------"	Write-Host -ForegroundColor White " - Loading Microsoft.SharePoint Assembly..."	[System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SharePoint") | Out-Null	Write-Host -ForegroundColor White "--------------------------------------------------------------"}# Region End# Region Get All Site Collections Url# ===================================================================================# Name: 		Get All Site Collections Url# Description:	Get All Site Collections Url# ===================================================================================Function Get-AllSitesURL([xml]$xmlinput){	Write-Host -ForegroundColor White "--------------------------------------------------------------"	Write-Host -ForegroundColor White " - Get URLs of All Site Collection..."	$SitesURL = new-Object System.Collections.ArrayList	$ExcludeUrls = $xmlinput.Configuration.ExcludeUrls.ExcludeUrl		If ($xmlinput.Configuration.Settings.IncludeCentralAdmin -eq $true)	{	$WebAppADM = [microsoft.sharepoint.administration.SPAdministrationWebApplication]::Local	$SitesADM = $WebAppADM.sites			foreach ($sites in $SitesADM)		{ 			[void]$SitesURL.Add($sites.Url)			$sites.Dispose() 		}	}	Else	{		Write-Host -ForegroundColor White " - Central Administration Excluded from WarmUp Urls"	}	$WebSrv = [microsoft.sharepoint.administration.spwebservice]::ContentService	$webApps = $WebSrv.WebApplications	foreach ($webApp in $WebApps)	{     		$sites=$WebApp.sites		foreach ($site in $sites)		{			[void]$SitesURL.Add($site.Url)			$site.Dispose() 		}	}	If ($ExcludeUrls.Length -ne 0)	{		Write-Host -ForegroundColor White " - Site Collection Urls Excluded from WarmUp"		ForEach($ExcludeUrl in $ExcludeUrls)		{			Write-Host -ForegroundColor White " * $ExcludeUrl"			[void]$SitesURL.Remove($ExcludeUrl)		}	}		return $SitesURL	Write-Host -ForegroundColor White " "}# Region End# Region Get All Web Applications Url# ===================================================================================# Name: 		Get All Web Applications Url# Description:	Get All Web Applications Url# ===================================================================================Function Get-AllWebAppURL{	Write-Host -ForegroundColor White "--------------------------------------------------------------"	Write-Host -ForegroundColor White " - Get URLs of All Web Applications..."	$WebAppURL = new-Object System.Collections.ArrayList	$farm = [Microsoft.SharePoint.Administration.SPFarm]::Local	# get web services from local farm	$websvcs = $farm.Services | where -FilterScript {$_.GetType() -eq [Microsoft.SharePoint.Administration.SPWebService]}	foreach ($websvc in $websvcs) 	{		foreach ($webapp in $websvc.WebApplications)		{			foreach ($AltUrl in $webapp.AlternateUrls)			{				[void]$WebAppURL.Add($AltUrl.uri)			}		}	}    return $WebAppURL	Write-Host -ForegroundColor White " "	}# Region IE-BrowseUrl# ===================================================================================# Name: 		IE-BrowseUrl# Description:	Open Url in Internet Explorer Window# ===================================================================================Function IE-BrowseUrl([string] $url){	Write-Host -ForegroundColor White " Internet Explorer - Browsing $url"	$TimeOut = 90	$Wait = 0	try	{		$global:ie.Navigate($url)		While ($ie.busy -like "True" -Or $Wait -gt $TimeOut)		{			Start-Sleep -s 1			$Wait++		}		Write-Host -ForegroundColor Green "  WebSite successfully loaded in $Wait s"	}	catch	{		$pid = $global:ieproc.id		Write-Host -ForegroundColor Red"  IE not responding.  Closing process ID $pid"		$global:ie.Quit()		$global:ieproc | Stop-Process -Force		$global:ie = New-Object -com "InternetExplorer.Application"		$global:ie.Navigate("about:blank")		$global:ie.visible = $true		$global:ieproc = (Get-Process -Name iexplore)| Where-Object {$_.MainWindowHandle -eq $global:ie.HWND}	}	}# Region End# Region IE-AddTrustIntranetUrl# ===================================================================================# Name: 		IE-AddTrustIntranetUrl# Description:	Add Url in Security Option - Intranet Zone# ===================================================================================Function IE-AddTrustIntranetUrl([string] $url){	# Remove http or https information to keep only HostName or FQDN	$url = $url -replace "https://",""	$url = $url -replace "http://",""	$urlDomain = $url -replace "/",""	if (-not (Test-Path -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings\ZoneMap\Domains\$urlDomain"))	{		Write-Host -ForegroundColor White " - Adding *.$urlDomain to local Intranet security zone..."		New-Item -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings\ZoneMap\Domains" -Name $urlDomain -ItemType Leaf -Force | Out-Null		New-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings\ZoneMap\Domains\$urlDomain" -Name '*' -value "1" -PropertyType dword -Force | Out-Null	}	Else	{		Write-Host -ForegroundColor White " - $urlDomain already added to local Intranet security zone - skipping."	}}# Region End# Region IE-ClearCache# ===================================================================================# Name: 		IE-ClearCache# Description:	Clear Internet Explorer's cache# ===================================================================================Function IE-ClearCache {	$RunDll32 = "$env:windir\System32\rundll32.exe"	If (Test-Path -Path $RunDll32)	{		try		{			Write-Host -ForegroundColor White " - Clearing Cache IE with runDll32.exe ..."			Start-Process -FilePath $RunDll32 -ArgumentList "InetCpl.cpl,ClearMyTracksByProcess 8" -NoNewWindow -Wait -ErrorAction SilentlyContinue		}		Catch		{			Write-Warning "An error occurred attempting to clear internet explorer temporary files."		}	}	Else	{		Write-Host -ForegroundColor White " - Clear Cache IE - The rundll32 is not present in $env:windir\System32 folder"	}}# Region End# Region Disable Loopback Check and Services# ===================================================================================# Func: DisableLoopbackCheck# Desc: Disable Loopback Check# ===================================================================================Function DisableLoopbackCheck([xml]$xmlinput){    # Disable the Loopback Check on stand alone demo servers.    # This setting usually kicks out a 401 error when you try to navigate to sites that resolve to a loopback address e.g.  127.0.0.1    If ($xmlinput.Configuration.Settings.DisableLoopbackCheck -eq $true)    {        $lsaPath = "HKLM:\System\CurrentControlSet\Control\Lsa"        $lsaPathValue = Get-ItemProperty -path $lsaPath        If (-not ($lsaPathValue.DisableLoopbackCheck -eq "1"))        {			Write-Host -ForegroundColor White " - Disabling Loopback Check..."            New-ItemProperty HKLM:\System\CurrentControlSet\Control\Lsa -Name "DisableLoopbackCheck" -value "1" -PropertyType dword -Force | Out-Null        }		Else		{			Write-Host -ForegroundColor White " - Loopback Check already Disabled - skipping."		}    }}# End Region# Region AddToHOSTS# ====================================================================================# Func: AddToHOSTS# Desc: This writes URLs to the server's local hosts file and points them to the server itself# From: Check http://toddklindt.com/loopback for more information# Copyright Todd Klindt 2011# Originally published to http://www.toddklindt.com/blog# ====================================================================================Function AddToHOSTS ([string] $url){	# Remove http or https information to keep only HostName or FQDN	$url = $url -replace "https://",""	$url = $url -replace "http://",""	$hostname = $url -replace "/",""		If ($hostname.Contains(":"))	{		Write-Host -ForegroundColor White " - $hostname cannot be added in HOSTS File, only web applications with 80 or 443 port are added ."	}	Else	{			# Make backup copy of the Hosts file with today's date		$hostsfile = "$env:windir\System32\drivers\etc\HOSTS"		$date = Get-Date -UFormat "%y%m%d%H%M%S"		$filecopy = $hostsfile + '.' + $date + '.copy'		# Get the contents of the Hosts file		$file = Get-Content $hostsfile		$file = $file | Out-String		# Write the AAMs to the hosts file, unless they already exist.		If ($file.Contains($hostname))		{Write-Host -ForegroundColor White " - HOSTS file entry for `"$hostname`" already exists - skipping."}		Else		{			Write-Host -ForegroundColor White " - Backing up HOSTS file to:"			Write-Host -ForegroundColor White " - $filecopy"			Copy-Item $hostsfile -Destination $filecopy					Write-Host -ForegroundColor White " - Adding HOSTS file entry for `"$hostname`"..."			Add-Content -Path $hostsfile -Value "`r"			Add-Content -Path $hostsfile -value "127.0.0.1 `t $hostname"		}	}}# Region End# Region Add-UserPolicy# ===================================================================================# Func: Add-UserPolicy# Desc: Applies Read Access to the specified accounts for a web application# ===================================================================================Function Add-UserPolicy([String]$url){    Try    {		$webapp = [Microsoft.SharePoint.Administration.SPWebApplication]::Lookup("$url")		$user = ([Security.Principal.WindowsIdentity]::GetCurrent()).Name		$displayName = "WarmUp Account"		$perm = "Full Read"				# If the web app is not Central Administration 		If ($webapp.IsAdministrationWebApplication -eq $false)		{			# If the web app is using Claims auth, change the user accounts to the proper syntax			If ($webapp.UseClaimsAuthentication -eq $true)			{				$user = 'i:0#.w|'+$user			}			Write-Host -ForegroundColor White " - Applying Read access for $user account to $url..."			[Microsoft.SharePoint.Administration.SPPolicyCollection]$policies = $webapp.Policies			[Microsoft.SharePoint.Administration.SPPolicy]$policy = $policies.Add($user, $displayName)			[Microsoft.SharePoint.Administration.SPPolicyRole]$policyRole = $webapp.PolicyRoles | where {$_.Name -eq $perm}			If ($policyRole -ne $null) {				$policy.PolicyRoleBindings.Add($policyRole)			}			$webapp.Update()			Write-Host -ForegroundColor White " - Done Applying Read access for `"$user`" account to `"$url`""		}    }    Catch    {        $_        Write-Warning "An error occurred applying Read access for `"$user`" account to `"$url`""    }}# Region End# ===================================================================================## WarmUp Script - MAIN Region## ===================================================================================cls$Host.UI.RawUI.WindowTitle = " -- WarmUP script -- $env:COMPUTERNAME --"# Logging PowerShell script in rtf file $logfolder = Split-Path -parent $MyInvocation.MyCommand.Definition$logTime = Get-Date -Format yyyy-MM-dd_h-mm$logFile = "$logfolder\WarmUP_script_$logTime.rtf"$currentuser = ([Security.Principal.WindowsIdentity]::GetCurrent()).NameStart-Transcript -Path $logFile -Append -ForceWrite-Host -ForegroundColor White " - Script Executed by $currentuser - "$DateStarted = Get-dateWrite-Host -ForegroundColor Green "-----------------------------------"Write-Host -ForegroundColor Green "| Automated Script - WarmUp Urls |"Write-Host -ForegroundColor Green "| Started on: $DateStarted |"Write-Host -ForegroundColor Green "-----------------------------------"# Check Permission LevelIf (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")){	Write-Warning "You do not have Administrator rights to run this script!`nPlease re-run this script as an Administrator!"	Break} else {	# Load SharePoint Powershell Assembly	Load-SharePoint-Assembly	# Get All Web Applications Urls	$WebApps = Get-AllWebAppURL		# Disable LoopBack Check	Write-Host -ForegroundColor White "--------------------------------------------------------------"	DisableLoopbackCheck $xmlinput		# Add Web Application Url in Intranet Security Options for Internet Explorer and in HOSTS system File	Write-Host -ForegroundColor White "--------------------------------------------------------------"	Write-Host -ForegroundColor White " - Add URLs of All Web Applications in Internet Settings/Security ..."	ForEach ($WebApp in $WebApps)	{		IE-AddTrustIntranetUrl $WebApp	}	# Add Web Application Url in HOSTS system File	Write-Host -ForegroundColor White "--------------------------------------------------------------"	Write-Host -ForegroundColor White " - Add URLs of All Web Applications in HOSTS File ..."	ForEach ($WebApp in $WebApps)	{		AddToHOSTS $WebApp	}		# Add Web Application Url in Intranet Security Options for Internet Explorer and in HOSTS system File	Write-Host -ForegroundColor White "--------------------------------------------------------------"	Write-Host -ForegroundColor White " - Add Read Access to $currentuser for All Web Applications ..."	ForEach ($WebApp in $WebApps)	{		Add-UserPolicy $WebApp	}		# Get All Site Collections Urls	$Sites = Get-AllSitesURL($xmlinput)	# Run Internet Explorer	Write-Host -ForegroundColor White "--------------------------------------------------------------"	Write-Host -ForegroundColor White " - Opening All sites URl with Internet Explorer ..."	# Remove Internet Explorer Temporary Files with RunDll32.exe	IE-ClearCache	$global:ie = New-Object -com "InternetExplorer.Application"	$global:ie.Navigate("about:blank")	$global:ie.visible = $true	$global:ieproc = (Get-Process -Name iexplore)| Where-Object {$_.MainWindowHandle -eq $global:ie.HWND}		ForEach ($Site in $Sites)	{		IE-BrowseUrl $Site	}		$CustomUrls = $xmlinput.Configuration.CustomUrls.CustomUrl	If ($CustomUrls.Length -ne 0)	{	Write-Host -ForegroundColor White "--------------------------------------------------------------"	Write-Host -ForegroundColor White " - Opening All custom URl with Internet Explorer ..."			ForEach($CustomUrl in $CustomUrls)		{			IE-BrowseUrl $CustomUrl		}	}			# Quit Internet Explorer	if ($global:ie)	{		Write-Host -ForegroundColor White "--------------------------------------------------------------"		Write-Host -ForegroundColor White " - Closing Internet Explorer ..."		$global:ie.Quit()	}		$DateEnded = Get-date	Write-Host -ForegroundColor Green "-----------------------------------"	Write-Host -ForegroundColor Green "| Automated Script - WarmUp Urls |"	Write-Host -ForegroundColor Green "| Started on: $DateStarted |"	Write-Host -ForegroundColor Green "| Completed on: $DateEnded |"	Write-Host -ForegroundColor Green "-----------------------------------"		Stop-Transcript	Exit}