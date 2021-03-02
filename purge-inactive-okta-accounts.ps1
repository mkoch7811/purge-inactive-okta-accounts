<#
.SYNOPSIS
    Okta_Purge_Inactive_Former_Associates.ps1 - Deletes suspended Okta accounts for former associates
    Created by Mike Koch on December 16, 2020
.DESCRIPTION
    Queries Okta for all SUSPENDED accounts, then deletes them
    Send email with all logged events/actions
.NOTES
    TO DO
    1. 
#>
[CmdletBinding()]
Param()

$api_token = "put_your_org_token_here"
$uri = "https://yourcompany.okta.com/api/v1/users?filter=status%20eq%20%22SUSPENDED%22"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$allusers = @()
$logfile = "c:\temp\Okta-Purge.log"
if (Test-Path -Path $logfile) {
    Remove-Item -Path $logfile -Force
}

function LogWrite {
    param ([string]$logstring)
    Add-Content $logfile -Value $logstring
}

# Query Okta using the URI specified above, page through the results to get all matching accounts
Do {
    $webrequest = Invoke-WebRequest -Headers @{"Authorization" = "SSWS $api_token"} -Method GET -Uri $uri
    $link = $webrequest.Headers.Link.Split("<").Split(">")
    $uri = $link[3]
    $json = $webrequest | ConvertFrom-Json
    $allusers += $json
} while ($webrequest.Headers.Link.EndsWith('rel="next"'))

if ($allusers.count -gt 0) {
    foreach ($usr in $allusers) {
        LogWrite "Deleting suspended user: $($usr.profile.login), $($usr.profile.displayname)"
        Write-Output "Deleting suspended user: $($usr.profile.login), $($usr.profile.displayname)"
# the first DELETE only DEACTIVATEs the account
        Invoke-WebRequest -Headers @{"Authorization" = "SSWS $api_token"} -Method Delete -Uri "https://yourcompany.okta.com/api/v1/users/$($usr.id)"
# the second DELETE actually DELETEs the account
        Invoke-WebRequest -Headers @{"Authorization" = "SSWS $api_token"} -Method Delete -Uri "https://yourcompany.okta.com/api/v1/users/$($usr.id)"
    }
    $MailMessage = @{
        To         = "SomeoneWhoCares@youremaildomain.com"
        From       = "OktaMaintenanceBot@youremaildomain.com"
        Subject    = "Report: Okta Former Employee Account Deletions"
        Body       = Get-Content $logfile -Raw
        BodyAsHtml = $false
        SmtpServer = "your.smtp.server"
    }
    Send-MailMessage @MailMessage
}