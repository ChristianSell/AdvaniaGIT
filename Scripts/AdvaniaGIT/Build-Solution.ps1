﻿function Build-Solution
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory=$True, ValueFromPipelineByPropertyname=$true)]
        [PSObject]$SetupParameters,
        [Parameter(Mandatory=$True, ValueFromPipelineByPropertyname=$true)]
        [PSObject]$BranchSettings,
        [Parameter(Mandatory=$True, ValueFromPipelineByPropertyname=$true)]
        [String]$ObjectsPath
    )
    if ($($SetupParameters.storeAllObjects).ToUpper() -eq "FALSE" -or $($SetupParameters.storeAllObjects) -eq $false) {
        $BaseObjectsFile = Get-BaseObjectsPath -SetupParameters $SetupParameters
        $BaseObjects = (Split-Path -Path $BaseObjectsFile -Leaf)
        Write-Host "Building solution objects..."
        $ObjectsPath = (Join-Path $workFolder 'Objects')
        $BaseObjectsPath = (Join-Path $workFolder 'BaseObjects')
        Remove-Item -Path $ObjectsPath -Recurse -ErrorAction SilentlyContinue
        New-Item -Path $ObjectsPath -ItemType Directory -ErrorAction SilentlyContinue | Out-Null
        Remove-Item -Path $BaseObjectsPath -Recurse -ErrorAction SilentlyContinue
        New-Item -Path $BaseObjectsPath -ItemType Directory -ErrorAction SilentlyContinue | Out-Null

        if (Test-Path $DeltasPath) {
            Write-Host Splitting $BaseObjects objects...
            Split-NAVApplicationObjectFile -Source $BaseObjectsFile -Destination $BaseObjectsPath -Force
            Write-Host "Updating new objects..."
            $MergeResult = Update-NAVApplicationObject -Target $BaseObjectsPath -Delta $DeltasPath -Result $ObjectsPath -DateTimeProperty FromModified -ModifiedProperty FromModified -VersionListProperty FromModified -DocumentationConflict ModifiedFirst 
            $MergeResult | Where-Object -Property UpdateResult -EQ 'Conflict' | Out-Host
            Get-ChildItem -Path (Join-Path $DeltasPath '*.delta')| foreach { if (Test-Path (Join-Path $ObjectsPath ($_.BaseName + '.txt'))) {Set-NAVApplicationObjectProperty -Target (Join-Path $ObjectsPath ($_.BaseName + '.txt')) -VersionListProperty (Merge-NAVVersionListString -source (Get-NAVApplicationObjectProperty -Source (Join-Path $ObjectsPath ($_.BaseName + '.txt'))).VersionList -target (Get-NAVApplicationObjectProperty -Source (Join-Path $DeltasPath $_.Name)).VersionList -SourceFirst)}}
        } else {
            Write-Host Splitting $BaseObjects objects...
            Split-NAVApplicationObjectFile -Source $BaseObjectsFile -Destination $ObjectsPath -Force
        }
        Write-Host "Solution build completed."
        Write-Output $ObjectsPath
    } else {
        Write-Output $ObjectsPath
    }
}