<#
	Author: Rodrigo Ribeiro Gomes (github @rrg92)
	Free to use, but MUST keep this header and reference.
#>


function SqlClient {
	param(
		$SQL
		,$ServerInstance = $Server
		,$Database = $Database
		,$AppName = $DefaultSqlAppName
		,$User   	= $DefaultSqlUser
		,$Password	= $DefaultSqlPassword
		,$connection = $null
		,[switch]$AllResults
		,[switch]$KeepConnection
		,[switch]$NoPooling
	)
		
	$ErrorActionPreference = "Stop";
		


	if($connection){
		if($connection -isnot [Data.SqlClient.SqlConnection]){
			throw "value informed in -Connection parameter is not a sqlconnection object"
		}
		
		$NewConex = $connection
	} else {
		$AuthString = "Integrated Security=True";
		
		if($User){
			
			if($User -is [pscredential]){
				$User 		= $User.GetNetworkCredential().UserName
				$Password 	= $User.GetNetworkCredential().Password
			}
			
			$AuthString = @(
				"User Id=$User"
				"Password=$Password"
			)
		}
		
		$ConnectionStringParts = @(
			"Server=$ServerInstance"
			"Database=$database"
			$AuthString
			"APP=$DefaultSqlAppName"
		)
		
		if($NoPooling){
			$ConnectionStringParts += "Pooling=false";
		}
	
		$NewConex = New-Object System.Data.SqlClient.SqlConnection
		$NewConex.ConnectionString = $ConnectionStringParts -Join ";"
		$NewConex.Open();
	}
	
	$DataSet = New-Object System.Data.DataSet;
	
	try {
		$commandTSQL = $NewConex.CreateCommand()
		$commandTSQL.CommandTimeout = 0;
		$ReaderWrapper = @{reader=$null}
		$commandTSQL.CommandText = $SQL;
		$ReaderWrapper.reader = $commandTSQL.ExecuteReader();
		
		while(!$ReaderWrapper.reader.IsClosed){
			$DataSet.Tables.Add().Load($ReaderWrapper.reader);
		}
		
	} finally {
		if(!$KeepConnection){
			$NewConex.Dispose();
		}
	}
	

	
	if($KeepConnection){
		return New-Object PSObject -Prop @{
				connection 	= $NewConex
				results		= $DataSet
			}
	} else {
		if(!$AllResults){
			return @($DataSet.Tables[0].Rows);
		}
	
		return $DataSet;
	}
		
	
}

function SqlBulkInsert {
	[CmdletBinding()]
	param(
		 $DataTable
		,$SqlTable		= $null
		,$ServerInstance = $Server
		,$Database = $Database
		,$AppName = $DefaultSqlAppName
		,$User   	= $DefaultSqlUser
		,$Password	= $DefaultSqlPassword
		,$ColumnMapping = @{}
		,$PreSQL
		,$PostSQL
		,[switch]$CatchErrors
	)
	
	$ErrorActionPreference = "Stop";
	$AuthString = "Integrated Security=True";
	
	if($User){
		
		if($User -is [pscredential]){
			$User 		= $User.GetNetworkCredential().UserName
			$Password 	= $User.GetNetworkCredential().Password
		}
			
		$AuthString = @(
			"User Id=$User"
			"Password=$Password"
		)
	}
	
	$ConnectionStringParts = @(
		"Server=$ServerInstance"
		"Database=$database"
		$AuthString
		"APP=$DefaultSqlAppName"
	)
	
	
	$BulkInserts = @()

	$NewConex = New-Object System.Data.SqlClient.SqlConnection
	$NewConex.ConnectionString = $ConnectionStringParts -Join ";"
	
	
	if($DataTable -isnot [hashtable]){
		$DataTable = @{
			"$SqlTable" = $DataTable
		}
	}
	
	foreach($DestTable in $DataTable.GetEnumerator()){
		$DestTableName 	= $DestTable.key
		$DataTableList = $DestTable.value;
		
		#hack for workaround some shit on powershell ...
		<#
		if($DestTable.value.getType().FullName -eq 'System.Data.DataTable'){
			$DataTableList = $DestTable.value
		} else {
			$DataTableList = $DestTable.value
		}
		#>
		
		
		if($DataTableList.__wasfrom2table__ -ne $true){
			throw "SQLBULKINSERT: Datatable must be generated from Object2Table"
		}

		write-verbose "	Setting up $DestTableName (SrcTablesCount:$($DataTableList.tables.count))";
				
		$BulkCopy = New-Object System.Data.Sqlclient.SqlBulkCopy($NewConex);  
		$BulkCopy.DestinationTableName  = $DestTableName;
		
		$MyColMapping = $ColumnMapping[$DestTableName];
		
		if(!$MyColMapping){
			$MyColMapping = @{};
		}

		$FirstTable = $DataTableList.tables[0].datatable
		
		foreach($DataTableCol in $FirstTable.Columns){
			if(!$MyColMapping.Contains($DataTableCol.ColumnName)){
				$MyColMapping[$DataTableCol.ColumnName] = $DataTableCol.ColumnName
			}
		}
		
		if($MyColMapping.count -eq 0){
			throw "BULKMAPPING_NOTFOUND: $DestTableName"
		}
		
		foreach($ColMap in $MyColMapping.GetEnumerator()){
			
			$TableColName = $ColMap.key
			$DestColName  = $ColMap.value
			
			write-verbose "	Mapping col $TableColName -> $DestTableName.$DestColName";
			$null = $BulkCopy.ColumnMappings.Add($TableColName,$DestColName)
		}
		
		$BulkInserts += New-Object PSObject -Prop @{
					BulkCopy	= $BulkCopy
					DataTables	= $DataTableList 
				}	
		
	}
	

	
	$Results = NEw-Object PsObject -Prop @{
		pre 		= $null
		post 		= $null
		errors		= @{
				pre = $null
				bulk = @()
				post = $null
			}
	}
	
	try {
		$NewConex.Open()
		
		if($PreSQL){
	
			$commandTSQL = $NewConex.CreateCommand()
			$commandTSQL.CommandTimeout = 0;
			$ReaderWrapper = @{reader=$null}
			$commandTSQL.CommandText = $PreSQL;
			
			try {
				$ReaderWrapper.reader = $commandTSQL.ExecuteReader();
				$DataSet = New-Object System.Data.DataSet;
				
				while(!$ReaderWrapper.reader.IsClosed){
					$DataSet.Tables.Add().Load($ReaderWrapper.reader);
				}
					
				$Results.pre = $DataSet.Tables
			} catch {
				if(!$CatchErrors){
					throw;
				}
			
				$Results.errors.pre = $_;
			}
		}
		
		foreach($Bulk in $BulkInserts){
			$BulkCopy 	= $Bulk.BulkCopy;
			#[object[]]$BulkTableList 	= $Bulk.DataTables;
			
			write-verbose "	DestTableCount: $($BulkTableList.count)";
			
			$tabNum = 0;
			foreach($RawDataTable in $Bulk.DataTables.tables){
				$tabNum++;
				$SrcTable = $RawDataTable.datatable;
				write-verbose "	Writing table $tabNum to $($BulkCopy.DestinationTableName)"
				
				try {
					$BulkCopy.WriteToServer($SrcTable);
				} catch {
					if(!$CatchErrors){
						throw;
					}
				
					$Results.errors.bulk += New-Object PSObject -Prop @{
									Bulk = $Bulk
									TabNum = $tabNum
									Error = $_
								}
				}
				
				
				write-verbose "		Done!";
			}
		}
		
		if($PostSQL){
	
			$commandTSQL = $NewConex.CreateCommand()
			$commandTSQL.CommandTimeout = 0;
			$ReaderWrapper = @{reader=$null}
			$commandTSQL.CommandText = $PostSQL;
			
			try {
				$ReaderWrapper.reader = $commandTSQL.ExecuteReader();
				$DataSet = New-Object System.Data.DataSet;
				
				while(!$ReaderWrapper.reader.IsClosed){
					$DataSet.Tables.Add().Load($ReaderWrapper.reader);
				}
					
				$Results.post = $DataSet.Tables
			} catch {
				if(!$CatchErrors){
					throw;
				}


				$Results.errors.post = $_;
			}
		}
	} finally {
		$NewConex.Dispose();
	}
	
	return $Results;
}

function SqlMerge {
	param($TableName,[object[]]$Data, $IdCol, [switch]$UseDelete)
	
	if($Data[0] -is [hashtable]){
		$PropList = $Data[0].keys;
	} else {
		$PropList = $Data[0].psobject.properties | %{ $_.name };
	}
	
	
	$Cols = $PropList | sort
	$ColsList = $Cols -Join ","
	
	$ValuesClause = @();
	$AllDeleteIds = @();
	
	if($IdCol -and $Cols -notContains $IdCol){
		throw "INVALIDCOL: $IdCol";
	}
	
	@($Data) | %{
		$CurrData = $_;
		$ValueList = @();
		
		if($IdCol){
			$AllDeleteIds += Ps2SqlValue $CurrData.$IdCol
		}
		
		$Cols | %{
			$CurrVal = $CurrData.$_
			$ValueList += Ps2SqlValue $CurrVal
		}
		
		$ValuesClause += "(" + ($ValueList -Join ",") + ")"
	}
	
	if($UseDelete){
		$DeleteSQL = "DELETE FROM $TableName WHERE $IdCol IN ("+($AllDeleteIds -Join ",")+")"
		$sql = "INSERT INTO $TableName($ColsList) VALUES " + ($ValuesClause -Join ",");
	} else {
		$SetClauses = @();
		$InsertValuesClause = @()
		
		$Cols | %{
			
			if($_ -ne $IdCol){
				$SetClauses += "$_ = S.$_";
			}
			
			$InsertValuesClause += "S.$_";
		}
		
		$mergeSQL = @(
			"MERGE" 
				"$TableName t"
			"USING"
				"("
					("VALUES "+($ValuesClause -Join ","))
				") S($ColsList)"
			"ON"
				"t.$IdCol = S.$IdCol"
			"WHEN MATCHED THEN"
				"UPDATE SET " + ($SetClauses -join ",")
			"WHEN NOT MATCHED THEN"
				"INSERT ($ColsList) VALUES("+($InsertValuesClause -Join ",")+")"
			"; --> Must end with semicolon"
		) -Join "`r`n"
	}
	
	return New-Object PsObject -Prop @{  delete = $DeleteSQL; insert = $sql; merge = $mergeSQL };
}

function Ps2SqlValue {
	param($val)
	
	$SQLVal = "";
	
	if($val -is [int]){
		$SQLVal = $val
	}
	elseif($val -is [datetime]){
		$SQLVal = "'"+$val.toString("yyyyMMdd HH:mm:ss.fff")+"'"
	}
	elseif($val -eq $null){
		$SQLVal = "NULL"
	}
	elseif($val -is [bool]){
		$SQLVal = [int]$val
	}
	else {
		$SQLVal = "'"+$val.replace("'","''")+"'"
	}
	
	return $SQLVal
}

function SqlBuildUpdate {
	param($TableName,[hashtable[]]$Data, [string]$IdCol)
	
	$Cols = @($Data[0].keys) | sort
	
	$AllUpdate = @();

	if($IdCol){
		if($Cols -notContains $IdCol){
			throw "INVALIDCOL: $IdCol";
		}
		
		$Cols = $Cols | ? { $_ -ne $IdCol }
	}
	
	
	@($Data) | %{
		$CurrData = $_;
		$SetClause = @();
		
		if($IdDeleteCol){
			$AllDeleteIds += $CurrData[$IdDeleteCol]
		}
		
		$Cols | %{
			$CurrVal = $CurrData[$_]
			$SQlVal =  Ps2SqlValue $CurrVal
			$SetClause += "$_ = $SQLVal"
		}
		
		$Where = @();
		
		if($IdCol){
			$IdFilter = $CurrData[$IdCol];
			$Where += "$Idcol = $IdFilter"
		}
		
		$AllUpdate += "UPDATE $TableName SET " + ($SetClause -Join ",");

		if($Where){
			$AllUpdate += " WHERE " + ( $Where -Join " AND " );
		}
	}
	
	
	return $AllUpdate -Join "`r`n";
}

function SqlGenerateBulkUpdate {
	param($TableName,[object[]]$Data, [string]$IdCol)
	
	
	$PropList = $Data[0].psobject.properties | %{$_.Name};
	
	$Cols = $PropList | ? { $_ -ne $IdCol }
	$AllUpdate = @();


	$ColList = @($Cols + $Idcol) -Join ","
	$PreScript = "IF OBJECT_ID('tempdb..#BulkTemp') IS NOT NULL DROP TABLE #BulkTemp; SELECT TOP 0  $ColList INTO #BulkTemp FROM $TableName UNION ALL SELECT TOP 0  $ColList FROM $TableName"

	$SetClause = @($Cols | %{"$_ = T.$_"})
	
	$PostScript = "
		UPDATE
			S
		SET
			"+($SetClause -Join ",")+"
		FROM
			#BulkTemp T 
			Join
			$TableName S
				ON S.$IdCol = T.$IdCol
	"
	
	$DataTable = Object2Table $Data;
	
	return @{
		PreSql 		= $PreScript
		DataTable	= $DataTable
		SqlTable	= '#BulkTemp'
		PostSQL		= $PostScript
	}
}


function SqlGetDic {
	param($TableName, $KeyCol, $ValueCol)
	
	$Sql = "SELECT $KeyCol,$ValueCol  FROM $TableName"
	
	$ResultSQL = SqlClient $sql;
	
	$HashResult = @{};
	
	if($ResultSQL){
		$ResultSQL | %{
			$HashResult[$_.$KeyCol] = $_.$ValueCol
		}
	}
	
	return $HashResult 
}

#Convert a array of objects to an data table.
function Object2Table {
	[object[]]$AllTables = @();
	
	foreach($a in $Args){
		$Object = $a
		$Tab = New-Object System.Data.DataTable
		
		$AllTables += @{datatable = $Tab}
		
		#First...
		$Object[0].psobject.properties | %{
			$PropName 	= $_.name;
			$PropType	= $_.TypeNameOfValue;
			
			$null = $Tab.Columns.Add($PropName,$PropType)
		}
		
		
		$Object | %{
		
			$NewRow = $Tab.NewRow();
			$Obj = $_;
			
			$_.psobject.properties | %{
				$PropName = $_.Name;
				$NewRow[$PropName] = $Obj.$PropName -as $_.TypeNameOfValue
			}
			
			$Tab.Rows.Add($NewRow);
		}
		
		
	
	}
	

	
	#Because DataTable is not enumerable data type, is must return as array.
	return New-Object PSObject -Prop @{
			tables = $AllTables
			__wasfrom2table__ = $true
	}
}
