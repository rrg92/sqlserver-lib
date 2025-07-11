/*#info 

	# Autor 
		Luciano Caixeta Moreira (luti)
		
	# Detalhes 
		Testes da proc prcColetarInfoFragmentacao
		
		
*/

/**
	Testes 1 - Parâmetros da procedure.
**/

-- Coletando dados de todos os bancos, todos os esquemas, e todos os objetos. Modo LIMITED.
EXEC proc_ColetarInfoFragmentacao;

-- Coletando dados somente do banco AdventureWorks.
EXEC proc_ColetarInfoFragmentacao
		@BancoDados = 'AdventureWorks'
;

-- Coletando dados somente do banco AdventureWorks, esquema Sales. Modo LIMITED.
EXEC proc_ColetarInfoFragmentacao
		 @BancoDados = 'AdventureWorks'
		,@NomeEsquema = 'Sales'
;


-- Coletando dados somente do banco AdventureWorks, esquema Sales, tabela SalesOrderHeader. Modo LIMITED.
EXEC proc_ColetarInfoFragmentacao
		 @BancoDados = 'AdventureWorks'
		,@NomeEsquema = 'Sales'
		,@NomeObjeto = 'SalesOrderHeader'
;

-- Coletando dados somente do banco AdventureWorks, esquema Sales, tabela SalesOrderHeader, indice cluster. Modo LIMITED.
EXEC proc_ColetarInfoFragmentacao
		 @BancoDados = 'AdventureWorks'
		,@NomeEsquema = 'Sales'
		,@NomeObjeto = 'SalesOrderHeader'
		,@IndexId = 1
;

-- Coletando dados somente do banco AdventureWorks, esquema Sales, tabela SalesOrderHeader, indice cluster, partição 1. Modo LIMITED.
EXEC proc_ColetarInfoFragmentacao
		 @BancoDados = 'AdventureWorks'
		,@NomeEsquema = 'Sales'
		,@NomeObjeto = 'SalesOrderHeader'
		,@IndexId = 1
		,@PartitionNumber = 1
;

-- Coletando dados sobre fragmentacao, e armazenando em uma tabela não existente.
EXEC proc_ColetarInfoFragmentacao
		 @BancoDados = 'AdventureWorks'
		,@TabelaDestino = 'tempdb.dbo.TabelaComDadosFrag'
		,@NomeEsquema = 'Sales'
		,@NomeObjeto = 'SalesOrderHeader'
		,@IndexId = 1
		,@PartitionNumber = 1
;

-- Coletando dados sobre a fragmentacao,e  armazendo na tabela existente. Modo DETAILED.
EXEC proc_ColetarInfoFragmentacao
		 @BancoDados = 'AdventureWorks'
		,@TabelaDestino = 'tempdb.dbo.TabelaComDadosFrag'
		,@NomeEsquema = 'Sales'
		,@NomeObjeto = 'SalesOrderHeader'
		,@IndexId = 1
		,@PartitionNumber = 1
		,@modo = 'DETAILED'
;

--> Coletando dados a partir de outra fonte de dados! (A tabela usada no exemplo pode nao conter dados)
EXEC proc_ColetarInfoFragmentacao
		 @BancoDados = 'AdventureWorks'
		,@TabelaDestino = 'tempdb.dbo.TabelaComDadosFrag'
		,@NomeEsquema = 'Sales'
		,@NomeObjeto = 'SalesOrderHeader'
		,@IndexId = 1
		,@PartitionNumber = 1
		,@modo = 'DETAILED'
		,@FonteInfoTabelas = '(SELECT  DISTINCT
	MI.ID			as DatabaseID
	,MI.ObjectID
	,MI.ObjectName	as NomeTabela
	,MI.SchemaName
	,MI.IndexID
	,MI.PartitionNumber
FROM ScriptUtil.ManutencaoIndices MI) Fonte'
;
