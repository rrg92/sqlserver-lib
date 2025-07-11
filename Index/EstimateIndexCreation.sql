/*#info 

	# Autor 
		Rodrigo Ribeiro Gomes 
		
	# Detalhes 
		Esse script foi uma tentativa de estimar o tempo necessário para criar um índice.
		Me lembro de ter usado algumas vezes em produção e ter resultados muitos próximos do real.
		A ideia é muito simples: 
			- Dado uma tabela (@TableName) e uma lista de colunas (@TestCols)  que quero indexar
			- Crio uma cópia dessa tabela com uma amostra de linhas (parâmetro @TestSize) 
			- Então, crio o índice na cópia, com as colunas desejada e mensuro o tempo que levou.
			- No final, faço uma regra de três simples para estimar para o total de linhas da tabela.
			
		
		
		
*/

DECLARE
	@TableName sysname
	,@TestSize bigint = 50000
	,@TestCols nvarchar(max) = NULL

SET @TableName = 'Posts'
set @TestCols = 'Id'

----
set nocount on;

IF OBJECT_ID(@TableName) IS NULL
BEGIN
	RAISERROR('Invalid table %s',16,1,@TableName);
	RETURN;
END

if @TestCols is null
BEGIN
	RAISERROR('Invalid cols',16,1);
	RETURN;
END

DECLARE
	@CopyTableName sysname
	,@sql nvarchar(MAX)
	,@TotalSize bigint = 0
	,@StartTime datetime
	,@EndTime datetime
	,@TotalCreateTime bigint
	,@TableSize bigint

SET @CopyTableName = 'zzzIndexCreationEstimate_'+replace(@TableName,'.','_')

SET @sql = 'SELECT '+@TestCols+' INTO '+@CopyTableName+' FROM '+@TableName+' WHERE 1 = 2' +
 'UNION ALL SELECT '+@TestCols+' FROM '+@TableName+' WHERE 1 = 2'
exec(@sql)

IF @@ERROR !=0
	RETURN;


RAISERROR('Test table %s created! To drop run: DROP TABLE %s',0,1,@CopyTableName,@CopyTableName) with nowait;

SET @sql = 'INSERT INTO '+@CopyTableName+' SELECT '+@TestCols+' FROM '+@TableName+' TABLESAMPLE(10000 ROWS)'
exec(@sql)

raiserror('Loading copy Table...',0,1) with nowait;
while @TotalSize < @TestSize
begin

	SELECT @TotalSize = sum(rows) FROM sys.partitions p where p.object_id = object_id(@CopyTableName)
	exec(@sql)
end

set @sql = 'create index ixTest on '+@CopyTableName+'('+@TestCols+')';
raiserror('Creating test index on %s',0,1,@CopyTableName)
set @StartTime = getdate();
exec(@sql);
set @EndTime = getdate();
select @StartTime,@EndTime
set @TotalCreateTime = ISNULL(NULLIF(datediff(ms,@StartTime,@EndTime),0),1)



SELECT @TableSize = sum(rows) FROM sys.partitions p where p.object_id = object_id(@TableName)
	and p.index_id <= 1

select CopyTotalRows = @TotalSize
		,CopyCreationDurationMs = @TotalCreateTime
		,RealTotalRows = @TableSize
		,RealCreationEstimationMs = (@TotalCreateTime*@TableSize)/@TotalSize

		

select DropThisTableToEnd = 'drop table '+@CopyTableName;