#parameters
[CmdletBinding()]
param(
[Parameter(Mandatory=$true)]
[ValidateNotNullOrEmpty()]
$datasetname,



[Parameter(Mandatory=$true)]
[ValidateNotNullOrEmpty()]
$targetWorkSpaceName,


[Parameter(Mandatory=$true)]
[ValidateNotNullOrEmpty()]
$reportName,



[Parameter(Mandatory=$true)]
[ValidateNotNullOrEmpty()]
$ParameterURL,



[Parameter(Mandatory=$true)]
[ValidateNotNullOrEmpty()]
$artifactPath,



[Parameter(Mandatory=$false)]
[ValidateNotNullOrEmpty()]
$ServiceRootURL,

[Parameter(Mandatory=$true)]
[ValidateNotNullOrEmpty()]
$PowerBICRMAppID,

[Parameter(Mandatory=$true)]
[ValidateNotNullOrEmpty()]
$PowerBICRMTenantID,

[Parameter(Mandatory=$true)]
[ValidateNotNullOrEmpty()]
$PowerBICRMAppSecret,

[Parameter(Mandatory=$true)]
[ValidateNotNullOrEmpty()]
$UserName,

[Parameter(Mandatory=$true)]
[ValidateNotNullOrEmpty()]
$Password,

[Parameter(Mandatory=$false)]
[ValidateNotNullOrEmpty()]
$Canbeanyvalue,

[Parameter(Mandatory=$false)]
[ValidateNotNullOrEmpty()]
$Table

)

Write-Host("Verifying if Appid, TenantID and App Secret are NULL")
if (!$PowerBICRMAppID ){    Write-Host "Appid is NULL" break }
if (!$PowerBICRMTenantID ){    Write-Host "TenantId is NULL" break }
if (!$PowerBICRMAppSecret ){    Write-Host "AppSecret is NULL" break }

$AppId = $PowerBICRMAppID

$TenantId = $PowerBICRMTenantID

$AppSecret = $PowerBICRMAppSecret

Write-Host("Appid, TenantID and App Secret are available.")

Write-Host("Verifying if Service Account Details are NULL")

if (!$UserName ){    Write-Host "Service Account UserName is NULL" break }
if (!$Password ){    Write-Host "Service Account Password is NULL" break }

Write-Host("Service Account Details are available. Proceeding with deployment..!!")
#Write-Host("Receiving AppIdentifier")
#$AppIdentifier = $PowerBICRMIdentifier#Get-AzKeyVaultSecret -VaultName 'PBICRMSecrets' -Name 'PowerBICRMIdentifier' -AsPlainText


#Power BI Import Process - Insert/Update




try{
#Connecting Power BI with Master User
#$password = $Password | ConvertTo-SecureString -asPlainText -Force
#$username = $Username
#$credential = New-Object System.Management.Automation.PSCredential($username, $password)
#Connect-PowerBIServiceAccount -Credential $credential


$PWord = ConvertTo-SecureString -String $AppSecret -AsPlainText -Force

$Credential = New-Object -TypeName "System.Management.Automation.PSCredential" -ArgumentList $AppId, $PWord

Write-Host "Connecting to PowerBI Service"

$Connectionresponse = Connect-PowerBIServiceAccount -ServicePrincipal -Credential $Credential -TenantId $TenantID
if ($Connectionresponse )
{
    Write-Host "Connected to PowerBI Service"
}

Write-Host("Receiving  Workspace Details")

$targetWorkSpace = Get-PowerBIWorkspace -Name $targetWorkSpaceName



if (!$targetWorkSpace) { Write-Host "targetWorkSpace is null" break }
Write-Host "Publishing Reports into Target WorkSpace: " $targetWorkSpaceName

$ReportNames = $reportName
$ReportNamesSplit = $ReportNames.split(",");

foreach($Report in $ReportNamesSplit)
    { 

        $DeployedResponse = ''
        Write-Host "Deploying Report: " $Report
        #Importing(Upsert) PowerBI Report from Artifact path to Target Workspace  $artifactPath/$reportName.pbix
        $DeployedResponse = New-PowerBIReport -Path $artifactPath/$Report.pbix  -Name $Report -Workspace ( Get-PowerBIWorkspace -Name $targetWorkSpaceName ) -ConflictAction "CreateOrOverwrite"
        if ($DeployedResponse )
        {
            Write-Host "Deployed Report: " $Report
        }
    


        #Receiving Target DatasetId
        Write-Host "Receiving Dataset ID"
        #$targetdatasetId = getDataSetId -workSpaceId $targetWorkSpace.id -datasetName $Report#$datasetname.$Report

        $targetdatasetId = Get-PowerBIDataset -WorkspaceId $targetWorkSpace.Id.Guid |  Where-Object {$_.name -eq $Report } |SELECT Id

        if (!$targetdatasetId) { Write-Host "targetdatasetId is null" break }
        Write-Host "targetWorkSpace Id: " $targetWorkSpace.Id.Guid
        Write-Host "targetdatasetId: " $targetdatasetId

        #Performing Takeover
        #Invoke-PowerBIRestMethod -Url "groups/$($targetWorkSpace.id)/datasets/$($targetdatasetId)/Default.TakeOver" –Headers $head -Method Post -Body ""
        Write-Host "Performing Takeover using Service Account"
        
        $PSWord = ConvertTo-SecureString -String $Password -AsPlainText -Force

        $Credential = New-Object -TypeName "System.Management.Automation.PSCredential" -ArgumentList $UserName, $PSWord

        Write-Host "Connecting to PowerBI Service Using Service Account"

        $ConnectionresponseSA = Connect-PowerBIServiceAccount -Credential $Credential

        if ($ConnectionresponseSA )
        {
            Write-Host "Connected to PowerBI Service Using Service Account"
        }

        #Write-Host "Script is on hold for 60 Secs"
        #Start-Sleep -Seconds 60
        $TakeOverURL = "https://api.powerbi.com/v1.0/myorg/groups/" + $targetWorkSpace.Id.Guid + "/datasets/" + $targetdatasetId.Id + "/Default.TakeOver"
        $TakeOverResponse = ''
        #Write-Host "Takeover URL: " $TakeOverURL
        #Invoke-PowerBIRestMethod -Url 'https://api.powerbi.com/v1.0/myorg/groups/728d2a72-3b14-4dd5-beb5-c237a3a64147/datasets/e39e3826-0bf1-46ef-972c-7e0fdc48cc6b/Default.TakeOver' -Method Post -Verbose
        #Invoke-PowerBIRestMethod -Url "groups/$($targetWorkSpace.Id.Guid)/datasets/$($targetdatasetId)/Default.TakeOver" -Method Post -Body ""
        $TakeOverResponse = Invoke-PowerBIRestMethod -Url $TakeOverURL -Method Post -Body "" -Verbose
        if ($TakeOverResponse) 
        {
             Write-Host $Report "has been takevover using: " $UserName "Service Account"        
        }

        switch ( $Report )
            {
                "Demo" { Write-Host "No Parameters for Demo Report"   }
                "Pipeline_Paramter" {
$json = @"
{
"updateDetails": [
{
"name": "Can be any value",
"newValue": "$Canbeanyvalue"
},
{
"name": "Table",
"newValue": "$Table"
},
{
"name": "URL",
"newValue": "$ServiceRootURL"
}
]
}
"@
                Write-Host "Update Dataset Parameters"
                $ParametersResponse = ""
                $ParametersResponse = Invoke-PowerBIRestMethod -Url "groups/$($targetWorkSpace.Id.Guid)/datasets/$($targetdatasetId.Id)/UpdateParameters" -Method Post -Body $json -Verbose
                if ($ParametersResponse) {
                    Write-Host "Updated Dataset Parameters for Pipeline_Paramter Report"
                }
            }
            }

        #Refreshing Dataset
        Write-Host "Performing Dataset refresh"
        $DatasetRefreshResponse = ""
        $DatasetRefreshResponse = Invoke-PowerBIRestMethod -Headers $head -Url "groups/$($targetWorkSpace.Id.Guid)/datasets/$($targetdatasetId.Id)/refreshes" -Method Post -Body ""
        if ($DatasetRefreshResponse) {
            Write-Host "Dataset refresh completed"
        }
    }



}catch{
Write-Host "Exception in Post Deployment Steps " $_.Exception.Message
Resolve-PowerBIError
exit
}