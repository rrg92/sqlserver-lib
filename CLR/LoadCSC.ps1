
<#
	.SYNOPSIS
		Get availble list of csc compilers!
#>
function Get-CSCompiler {
	[CmdLetBinding()]
	param()
	
	$NETVersions = $Env:SystemRoot + '\Microsoft.NET\Framework'
	
	gci $NETVersions | ? {$_.Name -like 'v*' -and (Test-Path ($_.FullName + '\csc.exe'))} | %{
	

		[void]($_ |  Add-Member -Type Noteproperty -name IsCurrent -Value $false -Force);
		
		if( (Get-CSCompilerCurrentPath) -eq $_.FullName){
			$_.IsCurrent = $true;
		}
		
		return $_;
	} | select Name,IsCurrent,FullName
}

<#
	.SYNOPSIS
		Get current CSC path
#>
function Get-CSCompilerCurrentPath {
	[CmdLetBinding()]
	param()
	return $Global:CsCompilerPath;
}

<#
	.SYNOPSIS
		Set current csc compiler!
#>
function Set-CSCompiler {
	[CmdLetBinding()]
	param($version = '*', [switch]$Last = $False)
	
	$Elegible = @(Get-CSCompiler | ?  {  $_.Name -like $version+'*'  });
	
	if(!$Last -and $Elegible.count -gt 1){
		throw "$Version matches more that one version: $($Elegible | %{$_.Name})"
	}
	
	
	
	if($Last){
		$Global:CscompilerPath = $Elegible[-1].FullName;
	} else {
		$Global:CscompilerPath = $Elegible[0].FullName;
	}

}

Set-CSCompiler -Last;
#Get the path to the c# compiler and build path to it...
$csc = Get-CSCompilerCurrentPath
if($csc){
	Set-Alias -Name csc -Value "$csc\csc.exe" -Scope 1;
	write-host "Try invoke csc and start compiling =)"
}



