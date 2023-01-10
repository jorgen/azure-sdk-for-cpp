<#
.SYNOPSIS
A script that given as input $TargetPath param, returns the owners
of that path, as determined by CODEOWNERS file passed in $CodeOwnersFileLocation
param.

.PARAMETER TargetPath
Path to file or directory whose owners are to be determined from a 
CODEOWNERS file. e.g. sdk/core/azure-amqp/ or sdk/core/foo.txt.

.PARAMETER TargetDirectory
Obsolete. Replaced by $TargetPath. Kept for backward-compatibility.
If both $TargetPath and $TargetDirectory are provided, $TargetDirectory is
ignored.

.PARAMETER ToolVersion
The NuGet package version of the package containing the "retrieve-codeowners" 
tool, around which this script is a wrapper.

.PARAMETER ToolPath
The place to check the "retrieve-codeowners" tool existence.

.PARAMETER DevOpsFeed
The NuGet package feed from which the "retrieve-codeowners" tool is to be installed.

NuGet feed:
https://dev.azure.com/azure-sdk/public/_artifacts/feed/azure-sdk-for-net/NuGet/Azure.Sdk.Tools.RetrieveCodeOwners

Pipeline publishing the NuGet package to the feed, "tools - code-owners-parser":
https://dev.azure.com/azure-sdk/internal/_build?definitionId=3188

.PARAMETER VsoVariable 
Optional. If provided, the determined CODEOWNERS will be output to Azure DevOps pipeline log
as variable named $VsoVariable.

Reference:
https://learn.microsoft.com/en-us/azure/devops/pipelines/process/variables?view=azure-devops&tabs=yaml%2Cbatch
https://learn.microsoft.com/en-us/azure/devops/pipelines/scripts/logging-commands?view=azure-devops&tabs=bash#logging-command-format

.PARAMETER IncludeNonUserAliases
Optional. Whether to include in the returned owners list aliases that are team aliases, e.g. Azure/azure-sdk-team

.PARAMETER Test
Optional. Whether to run the script against hard-coded tests.

#>
param (
  [string]$TargetPath = "",
  [string]$TargetDirectory = "",
  [string]$CodeOwnerFileLocation = (Resolve-Path $PSScriptRoot/../../../.github/CODEOWNERS), # The absolute path of CODEOWNERS file. 
  [string]$ToolVersion = "1.0.0-dev.20230108.6", 
  [string]$ToolPath = (Join-Path ([System.IO.Path]::GetTempPath()) "codeowners-tool-path"), # The place to check the tool existence. Put temp path as default
  [string]$DevOpsFeed = "https://pkgs.dev.azure.com/azure-sdk/public/_packaging/azure-sdk-for-net/nuget/v3/index.json", # DevOp tool feeds.
  [string]$VsoVariable = "",
  [switch]$IncludeNonUserAliases,
  [switch]$Test
)

function Get-CodeOwnersTool()
{
  $command = Join-Path $ToolPath "retrieve-codeowners"
  # Check if the retrieve-codeowners tool exsits or not.
  if (Get-Command $command -errorAction SilentlyContinue) {
    return $command
  }
  if (!(Test-Path $ToolPath)) {
    New-Item -ItemType Directory -Path $ToolPath | Out-Null
  }
  Write-Host "Installing the retrieve-codeowners tool under $ToolPath... "

  # Run command under tool path to avoid dotnet tool install command checking .csproj files. 
  # This is a bug for dotnet tool command. Issue: https://github.com/dotnet/sdk/issues/9623
  Push-Location $ToolPath
  dotnet tool install --tool-path $ToolPath --add-source $DevOpsFeed --version $ToolVersion "Azure.Sdk.Tools.RetrieveCodeOwners" | Out-Null
  Pop-Location
  # Test to see if the tool properly installed.
  if (!(Get-Command $command -errorAction SilentlyContinue)) {
    Write-Error "The retrieve-codeowners tool is not properly installed. Please check your tool path. $ToolPath"
    return 
  }
  return $command
}

function Get-CodeOwners(
  [string]$targetPath,
  [string]$targetDirectory,
  [string]$codeOwnerFileLocation,
  [bool]$includeNonUserAliases = $false)
{
  if ([string]::IsNullOrWhiteSpace($targetPath)) {
    $targetPath = $targetDirectory
  }
  if ([string]::IsNullOrWhiteSpace($targetPath)) {
    throw "targetPath parameter must be not null or whitespace."
  }

  $command = Get-CodeOwnersTool
  # Filter out the non-user alias from code owner list.
  if ($includeNonUserAliases) {
    $codeOwnersString = & $command --target-path $targetPath --code-owner-file-path $codeOwnerFileLocation 2>&1
  }
  else {
    $codeOwnersString = & $command --target-path $targetPath --code-owner-file-path $codeOwnerFileLocation --filter-out-non-user-aliases 2>&1
  }
  # Failed at the command of fetching code owners.
  if ($LASTEXITCODE -ne 0) {
    Write-Host $codeOwnersString
    return ,@()
  }
  
  $codeOwnersJson = $codeOwnersString | ConvertFrom-Json
  if (!$codeOwnersJson) {
    Write-Host "No code owners returned from the path: $targetPath"
    return ,@()
  }
  
  if ($VsoVariable) {
    $codeOwners = $codeOwnersJson.Owners -join ","
    Write-Host "##vso[task.setvariable variable=$VsoVariable;]$codeOwners"
  }

  return ,@($codeOwnersJson.Owners)
}

function TestGetCodeOwner([string]$targetDirectory, [string]$codeOwnerFileLocation, [bool]$includeNonUserAliases = $false, [string[]]$expectReturn) {
  Write-Host "Testing on $targetDirectory..."
  $actualReturn = Get-CodeOwners -targetDirectory $targetDirectory -codeOwnerFileLocation $codeOwnerFileLocation -includeNonUserAliases $IncludeNonUserAliases

  if ($actualReturn.Count -ne $expectReturn.Count) {
    Write-Error "The length of actual result is not as expected. Expected length: $($expectReturn.Count), Actual length: $($actualReturn.Count)."
    exit 1
  }
  for ($i = 0; $i -lt $expectReturn.Count; $i++) {
    if ($expectReturn[$i] -ne $actualReturn[$i]) {
      Write-Error "Expect result $expectReturn[$i] is different than actual result $actualReturn[$i]."
      exit 1
    }
  }
}

if ($Test) {
  $testFile = (Resolve-Path $PSScriptRoot/../../../tools/code-owners-parser/Azure.Sdk.Tools.RetrieveCodeOwners.Tests/CODEOWNERS)
  TestGetCodeOwner -targetDirectory "sdk" -codeOwnerFileLocation $testFile -includeNonUserAliases $true -expectReturn @("person1", "person2")
  TestGetCodeOwner -targetDirectory "sdk/noPath" -codeOwnerFileLocation $testFile -includeNonUserAliases $true -expectReturn @("person1", "person2")
  TestGetCodeOwner -targetDirectory "/sdk/azconfig" -codeOwnerFileLocation $testFile -includeNonUserAliases $true -expectReturn @("person3", "person4")
  TestGetCodeOwner -targetDirectory "/sdk/azconfig/package" -codeOwnerFileLocation $testFile -includeNonUserAliases $true  $testFile -expectReturn @("person3", "person4")
  TestGetCodeOwner -targetDirectory "/sd" -codeOwnerFileLocation $testFile -includeNonUserAliases $true  -expectReturn @()
  TestGetCodeOwner -targetDirectory "/sdk/testUser/" -codeOwnerFileLocation $testFile -expectReturn @("azure-sdk") 
  exit 0
}
else {
  return Get-CodeOwners -targetPath $TargetPath -targetDirectory $TargetDirectory -codeOwnerFileLocation $CodeOwnerFileLocation -includeNonUserAliases $IncludeNonUserAliases
}
