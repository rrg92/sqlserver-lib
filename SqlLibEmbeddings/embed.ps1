param(
	 $ReuseEmbeddings = $null
	 ,[switch]$AllFiles
)

$ErrorActionPreference = "Stop"


. "$PSScriptRoot/util.ps1"

if($ReuseEmbeddings){
	write-warning "reusing...";
	$TableContent = $ReuseEmbeddings
} else {
	[string]$CurrentDir = Get-Location;

	$Files = git ls-files --full-name  | %{
		@{
			item 		= Get-Item "$CurrentDir/$_"
			RelPath 	= $_
		}
	} | ? { $_.item.name -like "*.sql" }

	$ScriptData = @()

	# Index os scripts!
	foreach($file in $Files){
		
		write-host "File: $($file.item)";
		$FileContent = Get-Content -Raw $file.item;
		
		
		$EmbeddingContent = @(
			"Nome do Script: $($file.RelPath)"
			"Conteudo do script:"
			"$FileContent"
		) -Join "`n"
		
		
		$Embeddings = GetEmbeddings $EmbeddingContent
		write-host "Embeddings: $($Embeddings.length)";
		
		$ScriptData += [PsCustomObject]@{
			RelPath 		= $file.RelPath 
			ChunkNum 		= 0
			ChunkContent 	= $FileContent 
			embeddings 		= ($Embeddings | ConvertTo-Json -Compress)
		}
		
	}
	
	$TableContent = $ScriptData;
	
}

if(!$TableContent){
	write-warning "Nothing to index!";
	return;
}


dbulk $TableContent "Scripts" -pre "TRUNCATE TABLE Scripts";