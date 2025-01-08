/*#info 

	# Autor 
		Rodrigo Ribeiro Gomes 
		
	# Detalhes 
	
		Executa um DBCC CHECKTABLE para cada tabela de um banco.
		Especifique o nome do banco na variável @DatabaseName.
		
		Isso já me foi muito útil quando encontrei casos de corrupção e queria saber quais tabelas estavam intactas. 
		Rodando para cada tabela, eu poderia saber onde falharia, e depois analisaria com calma.  
		
		Me ajudou muito em casos extremos, onde o cliente não tinha backup, e queria salvar o máximo de coisas possíveis.  
		Sabendo quais tabelas estão boas, isso me guia para decidir quais dados eu vou perder e qual estratégia vou usar!
*/

DECLARE
	@PhysicalOnly bit = 0
	,@DatabaseName sysname = 'NomeBanco'


IF @DatabaseName IS NULL
BEGIN
	RAISERROR('Null db',16,1);
	RETURN;
END

if object_id('tempdb..#Tables') IS NOT NULL
	DROP TABLE #Tables;

CREATE TABLE #Tables( Id int identity primary key, DatabaseName sysname, TableName sysname, TotalSize bigint, FullName nvarchar(1000) );

DECLARE @Sql nvarchar(max);


SET @Sql = @DatabaseName+'..sp_executesql';

INSERT INTO #Tables
exec @Sql N'
	SELECT
		 DB_NAME()
		,T.name
		,S.TotalSize
		,FullName = QUOTENAME(C.name)+''.''+QUOTENAME(T.name)
	FROM
		sys.tables T
		JOIN
		sys.schemas C
			ON C.schema_id = T.schema_id
		CROSS APPLY
		(
			SELECT	
				TotalRows = SUM(P.rows)
				,TotalSize = SUM(au.total_pages)
			FROM
				sys.partitions P
				JOIN
				sys.allocation_units AU
					ON AU.container_id = P.partition_id
			WHERE
				P.object_id = T.object_id
				AND
				P.index_id <= 1
		) S
'



DECLARE
	@Id int = 0
	,@FullName sysname
	,@colDbname sysname


WHILE 1 = 1
BEGIN
	SELECT top 1
		@Id = Id
		,@FullName = FullName
		,@colDbname = DatabaseName
	FROM
		#Tables
	WHERE
		Id > @Id
	ORDER BY
		Id

	IF @@ROWCOUNT = 0
		BREAK;

	SET @sql = 'USE '+@colDbname+'; DBCC CHECKTABLE('''+@FullName+''') WITH NO_INFOMSGS';

	IF @PhysicalOnly = 1
		SET @sql += ',PHYSICAL_ONLY'

	RAISERROR('Running on table %s, sql: %s',0,1,@FullName,@sql) WITH NOWAIT;
	exec(@sql);

	IF @@ERROR != 0
		RAISERROR('	Table corrupted: %s',0,1,@FullName) WITH NOWAIT;

END


	