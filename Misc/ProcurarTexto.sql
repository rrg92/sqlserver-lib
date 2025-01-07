/*#info

	# Autor
		Rodrigo Ribeiro Gomes 
		
	# Detalhes
		Procura uma string em todas as colunas de texto do banco atual.  
		IMPORTANTE: Conecte-se como DAC, pois ele irá buscar em tabelas internas acessíveis apenas como DAC!
		IMPORANTE 2: O script pode causar uma enorme pressão e tablescan. 
		
		Eu uso bastante esse script para descorbir onde o SQL Server pode guardar alguma informação de metadado.  
		E também já usei pra ajudar clientes a descobriem em qual tabela um determinado valor está.  
		O mais seguro é rodar em backup em um ambiente de testes, mas eu já rodei em produção, sabendo dos riscos e monitorando.  
		Cada caso é um caso, e eu só recomendo você rodar em produção se tiver experência e conhecimento do ambiente.
*/
DECLARE
	@PalavraProcurar nvarchar(max) = '' --> COLOQUE AQUI O TRECHO DA STRING QUE DESJA PESQUISAR
DECLARE
	@CMD NVARCHAR(MAX);

SELECT
	@CMD = REPLACE('$'+dado,'$UNION ALL','')
FROM
(
SELECT
	'UNION ALL SELECT top 1 convert(varchar(8000),'+quotename(C.NAME)+') collate LATIN1_GENERAL_CI_AI AS Valor '+
	 ',convert(VARCHAR(500),'+QUOTENAME(C.name,'''')+' ) collate LATIN1_GENERAL_CI_AI AS coluna '+
	 ',convert(VARCHAR(500),'+QUOTENAME(object_schema_name(C.object_id)+'.'+object_name(C.object_id),'''')+' ) collate LATIN1_GENERAL_CI_AI AS tabela '+
	 ',DB_NAME() collate LATIN1_GENERAL_CI_AI AS banco '+
	 
	 'FROM '+quotename(object_schema_name(C.object_id))+'.'+quotename(object_name(C.object_id))+
	' WHERE CONVERT(nvarchar(max),'+quotename(C.name)+') collate LATIN1_GENERAL_CI_AI like '+quotename('%'+@PalavraProcurar+'%','''')+' collate LATIN1_GENERAL_CI_AI ' as 'text()'
FROM
	sys.all_columns C
	inner join
	sys.all_objects T
		on T.object_id = C.object_id
		and T.type_desc IN ('USER_TABLE','SYSTEM_TABLE','INTERNAL_TABLE')
WHERE
	type_name(C.system_type_id) IN ('char','text','nvarchar','varchar','ntext','sql_variant')
for xml path('')
) T(dado)

print @cmd
exec(@CMD)