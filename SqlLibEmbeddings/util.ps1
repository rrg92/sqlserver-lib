. "$PSScriptRoot/SqlOperations.ps1"

import-module powershai;

if(-not(Get-Command SqlLibEmbed -EA SilentlyContinue)){
	Enter-AiProvider HuggingFace {
		Get-GradioSession | ? {$_.name -eq 'space:rrg92/sqlserver-lib-assistant'} | Remove-GradioSession
		$space = Get-HfSpace rrg92/sqlserver-lib-assistant
		New-GradioSessionApiProxyFunction -force -Prefix "SqlLib"
	}
}

function GetEmbeddings {
	param($text, $provider = "huggingface", $model = $null)
	
	
	$res = SqlLibEmbed $text
	$embeddings = $res.data | ConvertFrom-Json
	$embeddings
}

function sql {
	param($sql, $server = $Env:SQL_SERVER, $DB = $ENV:SQL_DB, $User = $ENV:SQL_USER, $Pass = $Env:SQL_PASS)
	
	
	SqlClient -SQL $SQL -Server $Server -Database $Db -User $User -Pass $Pass
}

function dbulk {
	[CmdletBinding()]
	param(
		$o
		,$sqltab
		,$pre		= $null
		,$post		= $null
		,$Database 	= $ENV:SQL_DB
		,$Server 	= $Env:SQL_SERVER
		,$User = $ENV:SQL_USER
		,$Pass = $Env:SQL_PASS
	)
	
	$DataTab = Object2Table $o;
	
	SqlBulkInsert $DataTab $SqlTab -Server $Server -Database $Database -PreSql $pre -PostSQL $post -User $User -Password $Pass;
}