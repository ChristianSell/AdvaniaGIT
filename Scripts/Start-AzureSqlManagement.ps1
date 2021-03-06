﻿# Import all needed modules
Get-Module RemoteManagement | Remove-Module
Get-Module AdvaniaGIT | Remove-Module
Import-Module RemoteManagement -DisableNameChecking | Out-Null
Import-Module AdvaniaGIT -DisableNameChecking | Out-Null
Import-Module AzureRM

# Get Environment Settings
$SetupParameters = Get-GITSettings
$RemoteConfig = Get-NAVRemoteConfig

$DBAdmin = Get-NAVPasswordStateUser -PasswordId $RemoteConfig.DBUserPasswordID
if ($DBAdmin.UserName -gt "" -and $DBAdmin.Password -gt "") {
    $Credential = New-Object System.Management.Automation.PSCredential($DBAdmin.UserName, (ConvertTo-SecureString $DBAdmin.Password -AsPlainText -Force))
} else {
    $Credential = Get-Credential -Message "Remote Login to Azure SQL" -ErrorAction Stop
    $DBAdmin.UserName = $Credential.UserName
    $DBAdmin.Password = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($Credential.Password))
}    

if (!$Credential.UserName -or !$Credential.Password) {
    Write-Host -ForegroundColor Red "Credentials required!"
    break
}

$VMAdmin = Get-NAVPasswordStateUser -PasswordId $RemoteConfig.VMUserPasswordID
if ($VMAdmin.UserName -gt "" -and $VMAdmin.Password -gt "") {
    $VMCredential = New-Object System.Management.Automation.PSCredential($VMAdmin.UserName, (ConvertTo-SecureString $VMAdmin.Password -AsPlainText -Force))
} else {
    $VMCredential = Get-Credential -Message "Admin Access to Azure SQL" -ErrorAction Stop    
}

if (!$VMCredential.UserName -or !$VMCredential.Password) {
    Write-Host -ForegroundColor Red "Credentials required!"
    break
}

$AzureRMAdmin = Get-NAVPasswordStateUser -PasswordId $RemoteConfig.AzureRMUserPasswordID
if ($AzureRMAdmin.UserName -gt "" -and $AzureRMAdmin.Password -gt "") {
    $AzureCredential = New-Object System.Management.Automation.PSCredential($AzureRMAdmin.UserName, (ConvertTo-SecureString $AzureRMAdmin.Password -AsPlainText -Force))
} else {
    $AzureCredential = Get-Credential -Message "Remote Login to Azure Dns" -ErrorAction Stop    
}

if (!$AzureCredential.UserName -or !$AzureCredential.Password) {
    Write-Host -ForegroundColor Red "Azure Credentials required!"
    break
}

$Login = Login-AzureRmAccount -Credential $AzureCredential
$Subscription = Select-AzureRmSubscription -SubscriptionName $RemoteConfig.AzureRMSubscriptionName -ErrorAction Stop

if ($DBAdmin.GenericField1 -gt "") {
    $databaseServer = Get-AzureRmResourceGroup | Get-AzureRmSqlServer | Where-Object -Property ServerName -ieq $DBAdmin.GenericField1.Split(".").GetValue(0)
    $resourceGroup = Get-AzureRmResourceGroup -Name $databaseServer.ResourceGroupName
} else {
    Remove-Variable resourceGroup -ErrorAction SilentlyContinue
    Remove-Variable databaseServer -ErrorAction SilentlyContinue
}

#Select Azure Resource Group
if (!$resourceGroup) { $resourceGroup = Get-NAVAzureResourceGroup }
if (!$resourceGroup) {
    Write-Host -ForegroundColor Red "Azure Resource Group required!"
    break
}

# Select Azure Sql Database Server
if (!$databaseServer) { $databaseServer = Get-NAVAzureSqlServer -AzureResourceGroup $resourceGroup }
if (!$databaseServer) {
    Write-Host -ForegroundColor Red "Azure Sql Database Server required!"
    break
}


do {
    # Start Menu
    $menuItems = Load-NAVAzureSqlDatabaseMenu -AzureResourceGroup $resourceGroup -SqlServer $databaseServer 
    Clear-Host
    For ($i=0; $i -le 10; $i++) { Write-Host "" }
    $menuItems | Format-Table -Property No, DatabaseName, Location, ServerName, ResourceGroupName, ElasticPoolName -AutoSize 
    $input = Read-Host "Please select Database number (0 = exit, + = new database from bacpac, t = new tenant database)"
    switch ($input) {
        '0' { break }
        '+' { New-NAVAzureSqlDatabase -Credential $VMCredential -AzureResourceGroup $resourceGroup -SqlServer $databaseServer -dbOwner $Credential.UserName }
        't' { New-NAVAzureTenantSqlDatabase -Credential $VMCredential -DBCredential $Credential -AzureResourceGroup $resourceGroup -SqlServer $databaseServer }
        default {
            $selectedDatabase = $menuItems | Where-Object -Property No -EQ $input
            if ($selectedDatabase) { 
                Clear-Host
                For ($i=0; $i -le 10; $i++) { Write-Host "" }
                $selectedDatabase | Format-Table -Property No, DatabaseName, Location, ServerName, ResourceGroupName, ElasticPoolName -AutoSize 
                $input = Read-Host "Please select action (0 = exit, 1 = export, 2 = upload new license, 3 = delete)"
                switch ($input) {
                    '0' { $input = "" }
                    '1' { New-NAVAzureSqlDatabaseBacpac -Credential $VMCredential -AzureResourceGroup  $resourceGroup -SqlServer $databaseServer -DatabaseName $selectedDatabase.DatabaseName }
                    '2' { New-NAVAzureSqlDatabaseLicense -Credential $VMCredential -AzureResourceGroup  $resourceGroup -SqlServer $databaseServer -DatabaseName $selectedDatabase.DatabaseName }
                    '3' { Remove-NAVAzureSqlDatabase -Credential $Credential -AzureResourceGroup  $resourceGroup -SqlServer $databaseServer -DatabaseName $selectedDatabase.DatabaseName }
                }
            }
        }
    }
}
until ($input -ieq '0')
