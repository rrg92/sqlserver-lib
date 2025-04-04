<#
	Prepara para o ambiente para os embeddings do git!
#>

if(!(Get-Module powershai)){
	install-module powershai;
}


import-module powershai;

# Checa se tem acesso ao repo do hugging face!
Set-AiProvider huggingface;

& "$PSScriptRoot/embed.ps1"