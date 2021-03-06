<#
.SYNOPSIS
	Get-WMIEventFilters.ps1 outputs all WMI Event Filters on local machine and enables remediation.
    
    Name: WMIEventFilters.ps1
    Version: 1.1
    Author: Matt Green (@mgreen27)
    
.DESCRIPTION
    Get-WMIEventFilters.ps1 outputs all WMI Event Filters on local machine after parsing all availible Namespaces.
    Option to output in formatted or raw versions.
    Option to target specific Namespace to increase speed.
    Option to remove specific WMI Event Consumers and also using wildcards.
    Tested PS2+
    
.PARAMETER Raw
    Optional switch to output raw WMIEventFilter values instead of default parsed lists.
    
.PARAMETER Remove
    Optional parameter for specifying the WMI Event Filter to remove. Note: typo will result in no fields.

.PARAMETER Namespace
    Optional parameter for specifying targetted namespace. Required to remove. Note: typo will result in no results.

.PARAMETER Like
    Optional switch for specifying name paramater is a contains.
    e.g -Name EvilName -like  :  CONTAINS *EvilName*
    
.EXAMPLE
	Get-WMIEventFilters.ps1
    
    Namespace      : ROOT\subscription
    FilterName     : BVTFilter
    EventNamespace : root\cimv2
    FilterQuery    : SELECT * FROM __InstanceModificationEvent WITHIN 60 WHERE TargetInstance ISA "Win32_Processor" AND TargetInstance.LoadPercentage > 99
    
.EXAMPLE
	Get-WMIEventFilters.ps1 -raw
   
    __GENUS          : 2
    __CLASS          : __EventFilter
    __SUPERCLASS     : __IndicationRelated
    __DYNASTY        : __SystemClass
    __RELPATH        : __EventFilter.Name="BVTFilter"
    __PROPERTY_COUNT : 6
    __DERIVATION     : {__IndicationRelated, __SystemClass}
    __SERVER         : WIN7X64
    __NAMESPACE      : ROOT\subscription
    __PATH           : \\WIN7X64\ROOT\subscription:__EventFilter.Name="BVTFilter"
    CreatorSID       : {1, 5, 0, 0...}
    EventAccess      : 
    EventNamespace   : root\cimv2
    Name             : BVTFilter
    Query            : SELECT * FROM __InstanceModificationEvent WITHIN 60 WHERE TargetInstance ISA "Win32_Processor" AND TargetInstance.LoadPercentage > 99
    QueryLanguage    : WQL

.EXAMPLE
	Get-WMIEventFilters.ps1 -namespace ROOT\Subscription -remove EvilFilter
    <LOGIC TO CONFIRM REMOVAL>
    <OUTPUT REMAINING Event Filters>   
#>

[CmdletBinding()]
    Param (
        [Parameter(Mandatory = $False)][String]$Namespace = $Null,
        [Parameter(Mandatory = $False)][String]$Remove = $Null,
        [Parameter(Mandatory = $False)][Switch]$Like = $False,
        [Parameter(Mandatory = $False)][Switch]$Raw = $False  
)


function Get-WmiNamespace {
<#
.SYNOPSIS
    Returns a list of WMI namespaces present within the specified namespace.
.PARAMETER Namespace
    Specifies the WMI repository namespace in which to list sub-namespaces. Get-WmiNamespace defaults to the ROOT namespace.
.PARAMETER Recurse
    Specifies that namespaces should be recursed upon starting from the specified root namespace.
.EXAMPLE
    Get-WmiNamespace
.EXAMPLE
    Get-WmiNamespace -Recurce
.EXAMPLE
    Get-WmiNamespace -Namespace ROOT\CIMV2
.EXAMPLE
    Get-WmiNamespace -Namespace ROOT\CIMV2 -Recurse
.OUTPUTS
    System.String
    Get-WmiNamespace returns fully-qualified names.
.NOTES    
    This version is modified from: @Matifestation
    https://gist.githubusercontent.com/mattifestation/69c50a87044ba1b22eaebcb79e352144/raw/f4a41dff4eb8cf0db30a34e17ac15327cdb797e8/WmiNamespace.ps1
    
    Initially inspired from: Boe Prox
    https://github.com/KurtDeGreeff/PlayPowershell/blob/master/Get-WMINamespace.ps1
#>

    [OutputType([String])]
    Param (
        [String][ValidateNotNullOrEmpty()]$Namespace = "ROOT",
        [Switch]$Recurse
    )

    $BoundParamsCopy = $PSBoundParameters
    $null = $BoundParamsCopy.Remove("Namespace")

    # To Exclude locale specific namespaces replace line below with Get-WmiObject -Class __NAMESPACE -Namespace $Namespace -Filter 'NOT Name LIKE "ms_4%"' |
    Get-WmiObject -Class __NAMESPACE -Namespace $Namespace |
    ForEach-Object {
        $FullyQualifiedNamespace = "{0}\{1}" -f $_.__NAMESPACE, $_.Name
        $FullyQualifiedNamespace

        if ($Recurse) {
            Get-WmiNamespace -Namespace $FullyQualifiedNamespace @BoundParamsCopy
        }
    }
}



function Remove-WMIEventFilters {
<#
.SYNOPSIS
    Removes specified WMIEventFilter
.PARAMETER Namespace
    Specifies the WMI repository namespace in which to list sub-namespaces. Get-WmiNamespace defaults to the ROOT\Subscription namespace.
.PARAMETER Name
    Specifies that namespaces should be recursed upon starting from the specified root namespace.
.PARAMETER Like
    Switch to remove Like %Name%
.EXAMPLE
    Remove-WMIEventFilters -Namespace ROOT\CIMV2 -name EvilFilter
.OUTPUTS

.NOTES    
#>

[OutputType([String])]
    Param (
        [Parameter(Mandatory = $False)][String]$Namespace = $Null,
        [Parameter(Mandatory = $False)][String]$Remove = $Null,
        [Parameter(Mandatory = $False)][Switch]$Like = $False
)
    
    $ToRemove = $False    
    If ($Like){
        $Output = @()
        Get-WmiObject -Namespace $Namespace -Class "__EventFilter" -ErrorAction silentlycontinue | where-object {$_.Name -Like "*" + $Remove + "*"} | Foreach {
            $Line = "" | Select Namespace, FilterName, EventNamespace, FilterQuery
            $Line.Namespace = $_.__Namespace
            $Line.FilterName = $_.Name
            $Line.EventNamespace = $_.EventNamespace
            $Line.FilterQuery = $_.Query
            $Output += $Line
            $ToRemove = $True
        }
        If ($ToRemove){
            Write-Host -ForegroundColor Red "`nItems to remove:"
            $Output | Format-List
            
            write-host -ForegroundColor Red -nonewline "Are you sure you want to remove? (Y/N) "
            $Response = read-host
            if ($Response -ne "Y") {exit}
                
            Get-WmiObject -Namespace $Namespace -Class "__EventFilter" -ErrorAction silentlycontinue | where-object {$_.Name -Like "*" + $Remove + "*"}  | Remove-WmiObject
        }   
    }
    Else{
        $Output = @()
        Get-WmiObject -Namespace $Namespace -Class "__EventFilter" -ErrorAction silentlycontinue | where-object {$_.Name -eq $Remove} | Foreach {
            $Line = "" | Select Namespace, FilterName, EventNamespace, FilterQuery
            $Line.Namespace = $_.__Namespace
            $Line.FilterName = $_.Name
            $Line.EventNamespace = $_.EventNamespace
            $Line.FilterQuery = $_.Query
            $Output += $Line
            $ToRemove = $True
        }                
        If ($ToRemove){
            Write-Host -ForegroundColor Red "Item to remove:"
            $Output | Format-List
            
            write-host -ForegroundColor Red -nonewline "Are you sure you want to remove? (Y/N) "
            $Response = read-host
            if ($Response -ne "Y") {exit}
                
            Get-WmiObject -Namespace $Namespace -Class "__EventFilter" -ErrorAction silentlycontinue | where-object {$_.Name -eq $Remove}  | Remove-WmiObject
        }
    }
    If(!($ToRemove)){Write-Host -ForegroundColor Yellow "No WMIEventFilter found to remove. Printing availible Filters - Please check spelling."}
    Else{Write-Host -ForegroundColor Yellow "Printing remaining Filters."}
}

# Main

If($Remove){
    If (!$Namespace){$Namespace = Read-Host -Prompt "Enter WMI Namespace you would like to remove filter"}   
    
    If($Like){Remove-WMIEventFilters -Namespace $Namespace -Remove $Remove -Like}
    Else{Remove-WMIEventFilters -Namespace $Namespace -Remove $Remove}
}

 
If($Namespace){
    $Namespaces = @()
    $Namespaces += $Namespace
    $Namespaces += $(Get-WmiNamespace -Namespace $Namespace -recurse)
}
Else {$Namespaces = Get-WmiNamespace -recurse}


# Running WMIEventFilter Enumeration at the end.
ForEach ($NameSpace in $Namespaces){
    If ($Raw){
        Get-WmiObject -Namespace $Namespace -Class "__EventFilter" -ErrorAction SilentlyContinue
    }
    Else{
        $Output = @()
        Get-WmiObject -Namespace $Namespace -Class "__EventFilter" -ErrorAction SilentlyContinue | Foreach {            
            $Line = "" | Select Namespace, FilterName, EventNamespace, FilterQuery
            $Line.Namespace = $_.__Namespace
            $Line.FilterName = $_.Name
            $Line.EventNamespace = $_.EventNamespace
            $Line.FilterQuery = $_.Query
            $Output += $Line
        }
        $Output | Format-List
    }
}
