/*#info 

	# Autor 
		Rodrigo Ribeiro Gomes 
		
	# Detalhes 
		Comprime todos os índices do banco atual (usando PAGE).
		
		
*/
DECLARE	
	@Execute bit = 0; --> Troque para 1 para rodar! 0 faz apenas printar os comandos


IF OBJECT_ID('tempdb..#AllIndexes') IS NOT NULL
	DROP TABLE #AllIndexes;

CREATE TABLE #AllIndexes (
	 RowId int not null identity
	,TableName nvarchar(1000)
	,IndexName nvarchar(1000)
	,IndexFillFactor int
	,AllowOnline	bit
	,AlterType AS CASE WHEN IndexName IS NULL THEN 'TABLE' ELSE 'INDEX' END PERSISTED
	,AlterObject AS CASE WHEN IndexName IS NULL THEN TableName ELSE QUOTENAME(IndexName)+' ON '+TableName END PERSISTED
	,AlterOnline AS CASE WHEN AllowOnline = 1 THEN 'ON' ELSE 'OFF' END PERSISTED
	,AlterFF AS CASE WHEN IndexFillFactor BETWEEN 1 AND 90 THEN '90' ELSE NULL END PERSISTED
)

INSERT INTO 
	#AllIndexes(
		TableName
		,IndexName
		,IndexFillFactor
		,AllowOnline
	)
SELECT 
	 QUOTENAME(OBJECT_SCHEMA_NAME(I.object_id))+'.'+QUOTENAME(OBJECT_NAME(I.object_id))
	,I.name
	,I.fill_factor
	,O.CanOnline
FROM	
	sys.indexes I
	INNER JOIN
	sys.tables T
		ON T.object_id = I.object_id
	CROSS APPLY
	(
		SELECT	
			CanOnline = MIN
			(	
				CASE 
					WHEN ISNULL(IC.index_id,1)  = 1 AND T.name IN ('image','ntext','text')	THEN 0
					WHEN IC.index_id > 1 AND T.name IN ('image','ntext','text') AND IC.is_included_column = 0 THEN 0
					WHEN IC.index_id > 1 AND T.name IN ('image','ntext','text') AND IC.is_included_column = 0 THEN 0
					ELSE 1
				END
			)
			--,c.name ColName
			--,T.name IndexName
			--,IC.is_included_column
		FROM
			sys.columns C
			INNER JOIN
			sys.types T
				ON T.user_type_id = C.user_type_id
			LEFT JOIN
			sys.index_columns IC
				ON  C.object_id = IC.object_id
				AND C.column_id = IC.column_id
				AND IC.index_id = I.index_id
		WHERE
			C.object_id = I.object_id
			AND
			( (IC.index_id IS NULL AND I.index_id <= 1)
						OR
				(IC.index_id IS NOT NULL AND I.index_id > 0)
			)
	) O
WHERE
	I.is_disabled = 0
	AND
	I.type <= 2
	AND
	NOT EXISTS (
		SELECT * FROM sys.partitions P 
		WHERE P.object_id = I.object_id AND P.index_id = I.index_id
		AND P.data_compression_desc= 'PAGE'
	)


-- loop
DECLARE  @NextRow int
		,@SQL_Compress nvarchar(max)
		,@TotalRows int		
;
SET @NextRow = 1;
SET @TotalRows = (SELECT MAX(RowId) FROM #AllIndexes)


WHILE 1 = 1
BEGIN

	-- aqui é o comando de alter que será usado!
	SELECT TOP 1
		@SQL_Compress = 'ALTER '+AI.AlterType+' '+AI.AlterObject+' REBUILD WITH (DATA_COMPRESSION = PAGE, ONLINE = '+AlterOnline+ISNULL(', FILLFACTOR = '+AlterFF,'')+')'
	FROM
		#AllIndexes AI
	WHERE
		AI.RowId = @NextRow

	IF @@ROWCOUNT = 0
		BREAK;

	set @NextRow = @NextRow + 1;
	
	RAISERROR('Compressing %d/%d',0,1,@NextRow,@TotalRows) WITH NOWAIT;
	RAISERROR('	SQL: %s',0,1,@SQL_Compress) WITH NOWAIT;
	if @Execute = 1
		exec sp_Executesql @SQL_Compress;



END




















