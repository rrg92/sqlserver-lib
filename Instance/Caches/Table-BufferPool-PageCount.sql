/*#info 

	# Autor 
		Rodrigo Ribeiro Gomes 
		
	# Descrição 
		Dado uma lista de tabelas (nometab,nometab2,schema.tab), o script retorna o quanto de páginas ela possuem no cache, por tipo de página.
		Eu não lembro exatamente quando precisei usar isso, mas pode ser útil caso você esteja investigando o consumo de alguma tabela específica ou lista de tabelas (analsiando uma query por exemplo)

		E aí você quer saber quanto essas tabelas estão ocupando no seu cache.
		Você deve mudar o contexto para o banco atual onde as tabelas. O script não funciona (ainda) com diferentes bancos.
*/

DECLARE
	@Objetos	nvarchar(MAX)
;
SET @Objetos =	'backupset,sysjobs'

-- trasnforma em uma lista separada por spas simples e virgula, pra usar no in(object_id(texto),OBJECT_ID(texto))
SET @Objetos = 'OBJECT_ID(''' + REPLACE(@Objetos,',','''),object_id(''') + ''')'


IF OBJECT_ID('tempdb..#Objetos') IS NOT NULL
	DROP TABLE #Objetos;
CREATE TABLE #Objetos( object_id INT )

DECLARE
	@SQL nvarchar(MAX)
SET @SQL = N'SELECT t.object_id FROM sys.all_objects t WHERE t.object_id in($TABS)'
SET @SQL = REPLACE(@SQL,'$TABS',@Objetos)

INSERT INTO
	#Objetos
EXEC(@SQL);
	

SELECT
     object_name(au.object_id) 
	,bd.page_type
	,count(au.allocation_unit_id)  as TotalPages
FROM 
	sys.dm_os_buffer_descriptors bd
	INNER JOIN
	(
		SELECT
			 au.allocation_unit_id
			,p.object_id
		FROM
			sys.allocation_units	au
			JOIN
			sys.partitions			p	ON p.partition_id = au.container_id
		WHERE
			au.type = 2

		UNION ALL

		SELECT
			 au.allocation_unit_id
			,p.object_id
		FROM
			sys.allocation_units	au
			JOIN
			sys.partitions			p	ON p.hobt_id = au.container_id
		WHERE
			au.type IN (1,3)
	) AU ON au.allocation_unit_id = bd.allocation_unit_id
		AND au.object_id in ( SELECT t.object_id FROM #Objetos t )
WHERE 
	database_id = db_id()
	
GROUP BY
	bd.page_type,au.object_id
ORDER BY
		TotalPages DESC