/*#info 

	# Autor 
		Rodrigo Ribeiro Gomes 
		
	# Detalhes 
		Uma das primeiras queries que fiz para coletar todos os índices da instância.
		Usava quando precisava de reports rápidos (e sem muitos detalhes).
		
		
*/


IF object_id( 'tempdb..#IndiceDados' ) IS NOT NULL
	DROP TABLE #IndiceDados;
;

CREATE TABLE
	#IndiceDados( 
		 database_id	int
		,object_id		int
		,index_id		int
		,TemLOB			bit
		,TemAPLOFF		bit
		,ColunaCluster	sysname
	);


--EXEC sp_MSforeachdb 
DECLARE @CMD VARCHAR(MAX)
SET @cmd = '
USE ?;

INSERT INTO
	#IndiceDados
SELECT
	 db_id()
	,i.object_id
	,i.index_id
	,CASE WHEN EXISTS --> Checa se o índice tem colunas do tipo LOB
			(
				SELECT
					*
				FROM
							sys.index_columns	ic
				INNER JOIN	sys.columns			c	ON	c.object_id		= ic.object_id
													AND	c.column_id		= ic.column_id
				INNER JOIN	sys.types			t	ON	t.user_type_id	= c.user_type_id
				WHERE
						ic.object_id	= i.object_id
					AND	ic.index_id		= i.index_id
					AND (
						t.name in ( ''image'',''text'',''ntext'',''xml'' )
						OR
						(
								t.name in ( ''varchar'',''nvarchar'',''varbinary'' )
							AND	c.max_length = -1
						)
					)
			)
			THEN 1 
			ELSE 0
	  END as TemLob
	,i.allow_page_locks^1
	,Tabela.nomeColuna
FROM
				sys.indexes			i 
	CROSS APPLY	(
					SELECT TOP 1
						c.name		as NomeColuna
					FROM
									sys.tables	t 
						INNER JOIN	sys.columns	c on c.object_id = t.object_id
					WHERE
						t.object_id = i.object_id
					ORDER BY
						 c.max_length ASC,c.column_id ASC
				) Tabela
WHERE
	objectproperty( i.object_id , ''IsMsShipped'' ) = 0
'

EXEC sp_MSforeachdb @cmd;
GO

CREATE INDEX ixCobreConsulta01 ON #IndiceDados( database_id,object_id,index_id )
include( TemLOB,TemAPLOFF );


--EXEC( @cmd )





