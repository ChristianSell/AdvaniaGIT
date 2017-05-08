﻿function Remove-NAVDatabaseLicense
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory=$True, ValueFromPipelineByPropertyname=$true)]
        [PSObject]$BranchSettings
    )
    $command = "select name from sys.tables where name = '`$ndo`$dbproperty'"
    $tableName = Get-SQLCommandResult -Server (Get-DatabaseServer -BranchSettings $BranchSettings) -Database $BranchSettings.databaseName -Command $command -ForceDataset
    if ($tableName) {
        $command = "update [$($tablename.name)] set [license] = null"
        Get-SQLCommandResult -Server (Get-DatabaseServer -BranchSettings $BranchSettings) -Database $BranchSettings.databaseName -Command $command | Out-Null
    }

    $command = "select name from sys.tables where name = '`$ndo`$tenantproperty'"
    $tableName = Get-SQLCommandResult -Server (Get-DatabaseServer -BranchSettings $BranchSettings) -Database $BranchSettings.databaseName -Command $command -ForceDataset
    if ($tableName) {
        $command = "update [$($tablename.name)] set [license] = null"
        Get-SQLCommandResult -Server (Get-DatabaseServer -BranchSettings $BranchSettings) -Database $BranchSettings.databaseName -Command $command | Out-Null
    }

}