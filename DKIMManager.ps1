<#
    .SYNOPSIS
        Makes it easy to setup and enable DKIM for selected domains in a Microsoft 365 tenant.

    .DESCRIPTION
        
        ###################################################################
        #
        # DKIM Manager
        #
        # Author: Ian @ Slash Admin
        #
        # Enables DKIM for domain in 365 tenant and returns 
        # required CNAME records so you dont have to work them out :)
        #
        ###################################################################
        
        This script presents an easy to use menu system allowing you to login to your 365
        tenant and select the domain you wish to enable DKIM on.
        
        Once a domain is selected you can use the menu to create a DKIM policy and retrieve the
        correct DNS records to apply to the domain.
        
        Once the DNS records are in place you can then use the menu system to
        enable or disable DKIM easily for each domain.

    .EXAMPLE
        .\DKIMManager.ps1

    .LINK
        www.slashadmin.co.uk/dkimmanage
#>

#Fix to get around CE software restriction policies which block Powershell from running in the temp folder
#$env:tmp = "C:\files"

# Variables #######################################################
$global:selectedDomain = "< Please select a domain using option 1 >"
$global:domainSelected = $false
$global:exitMenu = $false

# Initiliase module ###############################################
if (!(Get-Module "ExchangeOnlineManagement")) {
    # module is not loaded
    Write-Host "Installing ExchagneOnlineManagement Module"
    Install-Module -Name ExchangeOnlineManagement
}
Import-Module ExchangeOnlineManagement

# Functions #######################################################
function Show-Title() {
    Write-Host "######################################################" -ForegroundColor Green
    Write-Host "      ___           ___                       ___     " -ForegroundColor Green
    Write-Host "     /\  \         /\__\          ___        /\__\    " -ForegroundColor Green
    Write-Host "    /::\  \       /:/  /         /\  \      /::|  |   " -ForegroundColor Green
    Write-Host "   /:/\:\  \     /:/__/          \:\  \    /:|:|  |   " -ForegroundColor Green
    Write-Host "  /:/  \:\__\   /::\__\____      /::\__\  /:/|:|__|__ " -ForegroundColor Green
    Write-Host " /:/__/ \:|__| /:/\:::::\__\  __/:/\/__/ /:/ |::::\__\" -ForegroundColor Green
    Write-Host " \:\  \ /:/  / \/_|:|--|-    /\/:/  /    \/__/--/:/  /" -ForegroundColor Green
    Write-Host "  \:\  /:/  /     |:|  |     \::/__/           /:/  / " -ForegroundColor Green
    Write-Host "   \:\/:/  /      |:|  |      \:\__\          /:/  /  " -ForegroundColor Green
    Write-Host "    \::/__/       |:|  |       \/__/         /:/  /   " -ForegroundColor Green
    Write-Host "     --            \|__|                     \/__/    " -ForegroundColor Green
    Write-Host "                                                      " -ForegroundColor Green
    Write-Host "######################################################" -ForegroundColor Green
    Write-Host ""
    Write-Host "Welcome to M365 DKIM manager" -ForegroundColor Green
    Write-Host ""
    Write-Host "Use at your own risk!" -ForegroundColor Red
    Write-Host ""
}

function Show-SelectDomainMenu() {
    Clear-Host
    Show-Title

    Write-Host "Domains in this tenant"
    Write-Host ""

    $i = 1
    $domains = Get-AcceptedDomain

    foreach ($domain in $domains) {
        Write-Host $i ":" $domain

        $i++
    }

    Write-Host ""
    $userResponse = Read-Host -Prompt "Please select the domain you wish to manage and press enter (Default is option 1)"
    if ($userResponse -notmatch "[1-$($domains.Length)]") {
        $userResponse = 1
    }
    $global:selectedDomain = $domains[$userResponse - 1].DomainName

    Write-host "You selected:" $global:selectedDomain
    $global:domainSelected = $true
}

function Show-ConfigureDKIMMenu() {
    Clear-Host
    Show-Title
    Write-Host "Configure DKIM Menu"
    Write-Host ""
        
    $dkimConfig = Get-DkimSigningConfig

    #Check if domain is listed in DKIM config list
    if ( ($dkimConfig | Where-Object Domain -Match $global:selectedDomain).length -eq 0) {
        #No DKIM policy found for this domain
        Write-Host "No exiting DKIM policy found so i'll create one and set DKIM enabled to false" -ForegroundColor Green
        New-DkimSigningConfig -DomainName $global:selectedDomain -Enabled $false
        Write-Host "Done" -ForegroundColor Green
    }
    else {
        $dkimEnabled = ($dkimConfig | Where-Object Domain -Match $global:selectedDomain).Enabled

        if ($dkimEnabled -eq $true) {
            Write-Host "Existing DKIM policy found and its enabled already." -ForegroundColor Green
        }
        else {
            Write-Host "Existing DKIM policy found and its currently set to disabled." -ForegroundColor Green
        }
    }

    Write-Host ""
    Write-Host "Please set the following CNAME records in your DNS. Wait 24 hours then run the script again to enable DKIM for the selected domain."
    Write-Host ""
    
    $dkimConfig = Get-DkimSigningConfig -Identity $global:selectedDomain
    
    Write-Host "First DNS Record"
    Write-Host "Record Type: CNAME"
    Write-Host "Record Name: selector1._domainkey"
    Write-Host "Record Value:" $dkimConfig.Selector1CNAME
    Write-Host ""
    Write-Host "Second DNS Record"
    Write-Host "Record Type: CNAME"
    Write-Host "Record Name: selector2._domainkey"
    Write-Host "Record Value:" $dkimConfig.Selector2CNAME

    Write-Host ""
    Write-Host "Press enter to return to the main menu"
    $userResponse = Read-Host
}

function Show-EnableDKIMMenu() {
    Clear-Host
    Show-Title
    Write-Host "Enable DKIM Menu"
    Write-Host ""
    $userResponse = Read-Host -Prompt "Please confirm you wish to enable DKIM (y/n)"
    Write-Host ""
    
    if ($userResponse -eq "y") {
        $dkimConfig = Get-DkimSigningConfig

        #Check if domain is listed in DKIM config list
        if ( ($dkimConfig | Where-Object Domain -Match $global:selectedDomain).length -eq 0) {
            #No DKIM policy found for this domain
            Write-Host "No exiting DKIM policy found! Please use option 2 to create one" -ForegroundColor Green
        }
        else {
            $dkimEnabled = ($dkimConfig | Where-Object Domain -Match $global:selectedDomain).Enabled
            $dkimConfig = Get-DkimSigningConfig -Identity $global:selectedDomain
            
            if ($dkimEnabled -eq $true) {
                Write-Host "Existing DKIM policy found and its enabled already." -ForegroundColor Green
            }
            else {
                if ($dkimConfig.Status -eq "CnameMissing") {
                    Write-Host "The required DNS settings are not in place or have not replicated yet, DNS updates can take upto 24 hours." -ForegroundColor Red
                }
                else {
                    Write-Host "Enabling DKIM policy" -ForegroundColor Green
                    Set-DkimSigningConfig -Identity $global:selectedDomain -Enabled $true
                    Write-Host "Done" -ForegroundColor Green
                }
            }
        }
    }

    Write-Host ""
    Write-Host "Press enter to return to the main menu"
    $userResponse = Read-Host
}

function Show-DisableDKIMMenu() {
    Clear-Host
    Show-Title
    Write-Host "Disable DKIM Menu"
    Write-Host ""
    $userResponse = Read-Host -Prompt "Please confirm you wish to disable DKIM (y/n)"
    Write-Host ""
    
    if ($userResponse -eq "y") {
        $dkimConfig = Get-DkimSigningConfig

        #Check if domain is listed in DKIM config list
        if ( ($dkimConfig | Where-Object Domain -Match $global:selectedDomain).length -eq 0) {
            #No DKIM policy found for this domain
            Write-Host "No exiting DKIM policy found! DKIM is effectively disabled" -ForegroundColor Green
        }
        else {
            $dkimEnabled = ($dkimConfig | Where-Object Domain -Match $global:selectedDomain).Enabled
            $dkimConfig = Get-DkimSigningConfig -Identity $global:selectedDomain
            
            if ($dkimEnabled -eq $true) {
                Write-Host "Disabling DKIM policy" -ForegroundColor Green
                Set-DkimSigningConfig -Identity $global:selectedDomain -Enabled $false
                Write-Host "Done" -ForegroundColor Green
            }
            else {
                Write-Host "DKIM policy is already disabled" -ForegroundColor Green
            }
        }
    }

    Write-Host ""
    Write-Host "Press enter to return to the main menu"
    $userResponse = Read-Host
}

function Show-MainMenu() {
    Clear-Host

    Show-Title
    Write-Host "If you want to enable DKIM for one of your domains choose option 1 to select the domain." -ForegroundColor Green
    Write-Host "Then choose option 2 to setup a DKIM policy and return the required CNAME DNS records." -ForegroundColor Green
    Write-Host "Finally update your DNS records and run this script again choosing option 1 then 3 to enable DKIM." -ForegroundColor Green
    Write-Host ""
    Write-Host "Selected Domain: " $global:selectedDomain
    Write-Host ""
    Write-Host "Press 1 to select a domain" -ForegroundColor Green

    if ($global:domainSelected -eq $true) {
        Write-Host "Press 2 to create a new DKIM signing policy and return required CNAME records" -ForegroundColor Green
        Write-Host "Press 3 to enable DIM for the domain" -ForegroundColor Green
        Write-Host "Press 4 to disable DKIM for the domain" -ForegroundColor Green
    }

    Write-Host "Press 5 to to exit" -ForegroundColor Green
    Write-Host ""
    $userResponse = Read-Host -Prompt "please select an option and press enter"

    Switch ($userResponse) {
        1 {
            "Option 1"
            Show-SelectDomainMenu
        }
        2 {
            "Option 2"
            if ($global:domainSelected -eq $true) { Show-ConfigureDKIMMenu }
        }
        3 {
            "Option 3"
            if ($global:domainSelected -eq $true) { Show-EnableDKIMMenu }
        }
        4 {
            "Option 4"
            if ($global:domainSelected -eq $true) { Show-DisableDKIMMenu }
        }
        5 {
            Clear-Host
            $global:exitMenu = $true
        }

        default { "That was not an option!" }
    }
}


# Start Script #######################################################
Clear-Host
Show-Title
$userResponse = Read-Host -Prompt "Press any key and sign into the 365 tenant you wish to manage"
Connect-ExchangeOnline -ShowProgress $false

While ($global:exitMenu -eq $false) {
    Show-MainMenu
}
