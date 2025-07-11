/*#info 

	# Autor 
		Rodrigo Ribeiro Gomes 
		
	# Detalhes 
		Não lembro exatamente onde usei, mas basicamente gera um script que move uma tabela HEAP para outro filegroup e o mesmo script para mover de volta.
		O filegroup para onde vai mover pode ser uma partition scheme.
		Depende da função fnGeraCreateIndice2005, mas futuras atualizações eu posso remover essa dependencia.
		
		Foi um dos primeiros scripts de DBa que eu criei. Melhorariam uita coisa nele.
		
		
*/

DECLARE
	@NomeIndiceCluster varchar(200), @DataSpace varchar(100);
	
SET @NomeIndiceCluster	= 'ixCluster'+REPLACE(CONVERT(varchar(max),NEWID()),'-','');
SET @DataSpace			= 'pSchema(c)';


;WITH DadosIndices AS
(
	SELECT
		 QUOTENAME(OBJECT_SCHEMA_NAME(I.object_id))+'.'+QUOTENAME(OBJECT_NAME(I.object_id)) AS NomeTabelaFull
		,I.name		AS NomeIndice
		,I.type		AS TipoIndice
		,C.name		AS ColunaMenorTam
		,DS.name + ISNULL(QUOTENAME(PC.name,'('),'')	AS DataSpaceAtual
	FROM
		sys.indexes I 
		CROSS APPLY
		(
			SELECT TOP 1
				*
			FROM
				sys.columns C
			WHERE
				C.object_id = I.object_id
				AND
				C.max_length > 0
			ORDER BY
				C.max_length
		) C
		OUTER APPLY
		(
			SELECT TOP 1
				C.name
			FROM
				sys.index_columns IC
				INNER JOIN
				sys.columns CI 
					ON CI.column_id = IC.column_id
			WHERE
				IC.object_id = I.object_id
				AND
				IC.partition_ordinal = 1
				AND
				IC.index_id	= I.index_id
		) PC
		CROSS APPLY
		(
				SELECT DISTINCT TOP 1
					 P.object_id
					,P.index_id
					,AU.data_space_id
				FROM
					sys.partitions P
					JOIN
					sys.allocation_units AU
						ON AU.container_id = P.hobt_id
				WHERE
					AU.type in (1,3)
					AND P.object_id = I.object_id
					AND P.index_id = I.index_id
					
				UNION ALL
				
				SELECT DISTINCT TOP 1
					 P.object_id
					,P.index_id
					,AU.data_space_id
				FROM
					sys.partitions P
					JOIN
					sys.allocation_units AU
						ON AU.container_id = P.partition_id
				WHERE
					AU.type in (2)
					AND P.object_id = I.object_id
					AND P.index_id = I.index_id
			) P
			INNER JOIN
			sys.data_spaces DS
				ON DS.data_space_id = P.data_space_id
	WHERE
		--> Muda o filtro de acordo com as tabelas que voce quer!!!!!!
		OBJECTPROPERTY(I.object_id,'IsMsShipped') = 0
)
SELECT
	 DI.NomeTabelaFull
	,DI.NomeIndice
	,CASE DI.TipoIndice
		WHEN 0 THEN 
				'CREATE CLUSTERED INDEX '+@NomeIndiceCluster+' ON '+DI.NomeTabelaFull + QUOTENAME(ColunaMenorTam,'(') + ' ON '+@DataSpace
		ELSE dbo.fnGeraCreateIndice2005(DI.NomeTabelaFull,DI.NomeIndice,'OFF','OFF','OFF','0',@DataSpace) 
	END as TSQLMoverPraNovo
	,CASE DI.TipoIndice
		WHEN 0 THEN 
				'DROP INDEX '+@NomeIndiceCluster+' ON '+DI.NomeTabelaFull+' WITH (MOVE TO '+DI.DataSpaceAtual+' )'
		ELSE dbo.fnGeraCreateIndice2005(DI.NomeTabelaFull,DI.NomeIndice,'OFF','OFF','OFF','0',DI.DataSpaceAtual) 
	END as TSQLMoverDeVolta
FROM
	DadosIndices DI
	
