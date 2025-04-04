<#
	Prepara para o ambiente para os embeddings do git!
#>

"powershai" | %{
	$ModName = $_
	
	if(-not(Get-Module -ListAvailable $ModName)){
		write-host "Instaling $ModName module";
		$m = Install-Module $ModName -force -PassThru
		write-host "	Installed: $($m.name) $($m.Version)"
	}	
	
}


import-module powershai;

# Checa se tem acesso ao repo do hugging face!
Set-AiProvider huggingface;

& "$PSScriptRoot/embed.ps1"