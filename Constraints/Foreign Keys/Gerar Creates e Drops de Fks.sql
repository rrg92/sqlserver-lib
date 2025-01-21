/*#info 

	# Autor 
		Rodrigo Ribeiro Gomes 

	# Detalhes 
		Gerar o drop e create de fks.
		Você deve antes criar a função: .\fnGeraCreateFK.sql no banco atual onde deseja rodar!
	
*/

DECLARE
	@Tabelas nvarchar(max);
SET @Tabelas = 'a.A,b.B,C,D'; -- posso colocar todas as tabelas separadas por virgula (pose especificar o schema)

--> Tranform em A,B,C em OBJECT_ID('A'),OBJECT_ID('B'),OBJECT_ID('C')
DECLARE @TabFilter nvarchar(max) = 'OBJECT_ID('''+REPLACE(@Tabelas,',','''),OBJECT_ID(''')+''')'

--> Montando uma lista com os object_ids das tabelas!
IF OBJECT_ID('tempdb..#Objetos') IS NOT NULL
	DROP TABLE #Objetos;
CREATE TABLE #Objetos( object_id INT )

DECLARE
	@SQL nvarchar(MAX)
SET @SQL = N'SELECT t.object_id FROM sys.all_objects t WHERE t.object_id in('+@TabFilter+')'

INSERT INTO
	#Objetos
EXEC(@SQL);
	

DECLARE
	 @Create	varchar(max)
	,@Drop		varchar(max)	
;
SET @Create = '';
SET @Drop	= '';

SELECT
	 Creates = dbo.fnGeraCreateFK( OBJECT_SCHEMA_NAME(fk.object_id)+'.'+name ,1) + ';'+char(13)+char(10)
	,Drops   = 'ALTER TABLE '+object_name(parent_object_id)+' DROP CONSTRAINT '+name+';'+char(13)+char(10)
FROM
	sys.foreign_keys fk
WHERE
	fk.is_disabled	= 0
and fk.referenced_object_id in
(
SELECT * FROM #Objetos
) 