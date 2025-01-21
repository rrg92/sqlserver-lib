param(
	 [switch]$Update
)

$ErrorActionPreference = "Stop"

$Committed = @(git ls-files).count 
$TotalFiles = @(gci -rec *.sql).count


[int]$PercentCompleted  = $Committed*100/$TotalFiles
$TitleEscaped = [Uri]::EscapeDataString("$Committed/$TotalFiles scripts");

$Url = "https://progress-bar.xyz/$PercentCompleted/?width=200&title=$TitleEscaped"
$ReadmeImage = "![Progresso]($Url)"


$ReadmeLines = Get-Content .\README.md

for ($i = 0; $i -lt $ReadmeLines.length; $i++)
{
    if($ReadmeLines[$i] -match '^!\[Progresso\].+'){
		$ReadmeLines[$i] = $ReadmeImage
		break;
	}
}

if($i -ge $ReadmeLines.length){
	$ReadmeLines = @($ReadmeImage) + $ReadmeLines
}

$ReadmeLines

write-host "---"
write-host $Committed $TotalFiles $PercentCompleted
write-host $Url 

if($Update){
	$ReadmeLines | Set-Content .\README.md -Encoding UTF8
}