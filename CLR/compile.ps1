$ErrorActionPreference = "Stop";

push-location 

cd $PsScriptRoot;

try {

	.\LoadCSC.ps1

	write-host "Compilando Lab.cs..."
	csc -nologo -out:SqlLabClr.dll  -target:library Lab.cs

	$FilePath = @(Get-Item "$PsScriptRoot\SqlLabClr.dll").FullName
	
	$CreateAssembly = Get-Content .\SqlLabClr.create.sql -Raw 
	
	write-host "==== RODE O CÓDIGO ABAIXO NO SEU SQL ===="
	
	$CreateAssembly = $CreateAssembly.replace('SqlLabClr.dll',$FilePath )
	
	write-host $CreateAssembly
} finally {
	pop-location
}