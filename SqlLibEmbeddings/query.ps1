param(
	 $texto 
	 ,$top = 10
)

$ErrorActionPreference = "Stop"

. "$PSScriptRoot/util.ps1"

write-host "Translating text"
$TranslatedText = Get-AiChat "Translate that text to english:$texto" -ResponseFormat @{
		name = "FormatResult"
		schema = @{
			type = "object"
			properties = @{
				text = @{
					type = "string"
					description = "translated text"
				}
			}
		}
	} -ContentOnly

$OriginalText = $texto
$QueryText = @($TranslatedText | ConvertFrom-Json).text;
write-host "text: $QueryText";

write-host "Getting embeddings..."
$embeddings = GetEmbeddings $QueryText

$vector = $embeddings | ConvertTo-Json -Compress;


$sql = "
	declare @search vector(1024) = '$vector'
	
	select top $top
		*
	from (
		select 
			RelPath
			,CosDistance = vector_distance('cosine',embeddings,@search)
			,ScriptContent = ChunkContent
		from
			Scripts 
	) v
	order by
		CosDistance
	
"

write-host "Getting data from sql...";
$results = sql $sql;



$ResultJson = $results | select RelPath,ScriptContent | ConvertTo-Json -compress

$SystemPrompt = "
	You are an assistant that helps users find the best T-SQL scripts for their specific needs.  
	These scripts were created by Rodrigo Ribeiro Gomes and are publicly available for users to query and use.

	The user will provide a short description of what they are looking for, and your task is to present the most relevant scripts.

	To assist you, here is a JSON object with the top matches based on the current user query:  
	$ResultJson
	
	---
	This JSON contains all the scripts that matched the user's input.  
	Analyze each script's name and content, and create a ranked summary of the best recommendations according to the user's need.

	Only use the information available in the provided JSON. Do not reference or mention anything outside of this list.  
	You can include parts of the scripts in your answer to illustrate or give usage examples based on the user's request.

	Re-rank the results if necessary, presenting them from the most to the least relevant.  
	You may filter out scripts that appear unrelated to the user query.

	---
	### Output Rules

	- Review each script and evaluate how well it matches the user’s request.  
	- Summarize each script, ordering from the most relevant to the least relevant.  
	- Write personalized and informative review text for each recommendation.  
	- If applicable, explain how the user should run the script, including parameters or sections (like `WHERE` clauses) they might need to customize.  
	- When referencing a script, include the link provided in the JSON all scripts are hosted on GitHub
"

write-host "Analyzing..."
ait "s: $SystemPrompt",$OriginalText



