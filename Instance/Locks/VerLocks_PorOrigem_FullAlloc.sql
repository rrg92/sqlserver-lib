/*#info
	# autor 
		Rodrigo Ribeiro Gomes 

	# descricao 
		Cadeia de locks com os detalhes dos locks obtidos!
		Atencao: a sys.dm_tran_locks le diretamente de uma estrutura em memoria do SQL...
		E ela pode ser GIGANTE...Usar com muito cuidado isso!

*/


SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;


IF OBJECT_ID('tempdb..#BL') IS NOT NULL
	DROP TABLE #BL;
	
IF OBJECT_ID('tempdb..#LocksInfo') IS NOT NULL
	DROP TABLE #LocksInfo;
	
IF OBJECT_ID('tempdb..#AllLocks') IS NOT NULL
	DROP TABLE #AllLocks;

IF OBJECT_ID('tempdb..#Sessoes') IS NOT NULL
	DROP TABLE #Sessoes;

IF OBJECT_ID('tempdb..#Requests') IS NOT NULL
	DROP TABLE #Requests;


SELECT S.session_id,S.program_name INTO #Sessoes FROM sys.dm_exec_sessions S 
SELECT R.session_id,R.blocking_session_id,R.start_time INTO #Requests FROM sys.dm_exec_requests R;

CREATE CLUSTERED INDEX ixCover001 ON #Requests(blocking_session_id);

;WITH BlockingList AS
(
	SELECT
		S.session_id
		,S.session_id as Origem
		,CONVERT(int,NULL) AS BlockedBy
		,R.start_time
		,1 as Nivel
	FROM
		#Sessoes S 
		LEFT JOIN
		#Requests R
			ON R.session_id = S.session_id
	WHERE
		S.session_id > 50
		AND
		ISNULL(R.blocking_session_id,0) = 0
		
	UNION ALL
	
	SELECT
		R.session_id
		,BL.Origem
		,CONVERT(int,R.blocking_session_id) as BlockedBy
		,R.start_time
		,Nivel + 1
	FROM
		#Requests R
		INNER JOIN
		BlockingList BL
			ON BL.session_id = R.blocking_session_id
)
SELECT
	 BL.*
	 ,ROW_NUMBER() OVER(PARTITION BY Origem ORDER BY Nivel,ISNULL(BL.BlockedBy,0)  ) as Ordem
INTO
	#BL
FROM
	BlockingList BL
WHERE
	EXISTS (
		SELECT * FROM #Requests R WHERE R.blocking_session_id = BL.session_id
	)
	OR
	BL.BlockedBy IS NOT NULL
OPTION(MAXRECURSION 0)


SELECT * INTO #AllLocks FROM sys.dm_tran_locks WHERE request_session_id IN (SELECT #BL.session_id FROM #BL);

--> Agora vamos obter as informações de locks Começando pelo último até a raiz ...
;WITH LocksInfo AS
(
	/**
		Para cada grupo de sessão bloqueada, vamos obter a última.
		Nos vamos usar a coluna Origem como identificador do grupo de bloqueios.
	**/
	SELECT
		L.request_session_id
		,L.resource_type
		,L.resource_subtype
		,L.resource_description
		,L.resource_database_id 
		,L.resource_associated_entity_id
		,L.resource_lock_partition
		,L.request_mode
		,L.request_type
		,L.request_exec_context_id
		,L.request_status
		,BL.Ordem
		,BL.Origem
	FROM
		#AllLocks L 
		INNER JOIN (
			SELECT
				#BL.session_id
				,#BL.Ordem
				,#BL.Origem
				,ROW_NUMBER() OVER(PARTITION BY #BL.Origem ORDER BY #BL.Ordem DESC) Rn
			FROM
				#BL	
		) BL
			ON BL.session_id = L.request_session_id
	WHERE
		L.request_status <> 'GRANT'
		AND
		BL.Rn = 1
		
		
	UNION ALL
	
	SELECT
		L.request_session_id
		,L.resource_type
		,L.resource_subtype
		,L.resource_description
		,L.resource_database_id 
		,L.resource_associated_entity_id
		,L.resource_lock_partition
		,L.request_mode
		,L.request_type
		,L.request_exec_context_id
		,L.request_status
		,BL.NextOrdem as Ordem
		,BL.Origem
	FROM
		#AllLocks L 
		INNER JOIN
		(
			/**
				Nest select vamos obter a próxima session_id bloqueada, pegando por último ...
				Como eu não posso usar TOP e nem MAX na parte recursiva, eu apenas uso um JOIN e ROW_NUMBEr pra filtrar a próxima session_id da tabela #BL.
				A coluna ordem da CTE vai me dá a última ordem que eu li.
				Fazendo o JOIN podemos acessar os dados outed na iteraão anterior ...
			**/
			SELECT
				#BL.session_id as session_id
				,#BL.Ordem as NextOrdem
				,ROW_NUMBER() OVER(PARTITION BY #BL.Origem ORDER BY #BL.Ordem DESC) Rn
				,LI.*
			FROM
				#BL
				JOIN
				LocksInfo LI
					ON
						#BL.Ordem < LI.Ordem
						AND
						#BL.Origem  = LI.Origem
		) BL
			ON 
				(
					--> Quando for ordem > 1 apenas pega o recurso bloqueado pela sessão através do numero e do Status
					BL.NextOrdem > 1
					AND
					BL.session_id = L.request_session_id
					AND
					L.request_status <> 'GRANT'
				)
				OR
				(
					/**
						Quando for a raiz do bloqueio, pegamos o recurso bloqueado pelo tipo de lock e identificação/tipo do recurso
					**/
				
					BL.NextOrdem  = 1
					AND
					--> O que você quer ?
					L.request_type = BL.request_type
					--> No quê ?
					AND
					L.resource_database_id = BL.resource_database_id
					AND
					L.resource_lock_partition = BL.resource_lock_partition
					AND
					L.resource_description = BL.resource_description
					AND
					L.resource_associated_entity_id = BL.resource_associated_entity_id
					AND
					L.request_status = 'GRANT'
				)
	WHERE
		BL.Rn = 1
)
SELECT
	*
INTO
	#LocksInfo
FROM
	LocksInfo
OPTION(MAXRECURSION 0)

DECLARE
	@Versao int
	,@ServicePack int
	
IF OBJECT_ID('tempdb..#Objetos') IS NOT NULL
	DROP TABLE #Objetos;
	
CREATE TABLE #Objetos( database_id int, object_id int, object_name sysname, object_schema sysname );

EXEC sp_MSforeachdb '
	USE [?];
	
	IF NOT EXISTS(SELECT * FROM #LocksInfo WHERE resource_database_id = DB_ID())
		RETURN;
		
	INSERT INTO
		#Objetos(database_id,object_id,object_name,object_schema)
	SELECT
		 DB_ID()
		,O.object_id
		,O.name
		,S.name
	FROM
		sys.objects O
		INNER JOIN
		sys.schemas S 
			ON S.schema_id = O.schema_id
	WHERE
		EXISTS (
			SELECT
				*
			FROM
				#LocksInfo LI
			WHERE
				LI.resource_associated_entity_id = O.object_id
				AND
				LI.resource_database_id = DB_ID()
		)
'

SELECT
	 BL.session_id  as  [Sessão]
	,BL.BlockedBy	as  [Blocqueado por]
	,BL.Origem		as  [Sessao que Originou o bloqueio]
	,BL.start_time
	,LI.request_mode
	,LI.resource_type
	,LI.resource_subtype
	,LI.request_exec_context_id
	,LI.request_status
	,CASE
		WHEN LI.resource_type = 'OBJECT' THEN DB_NAME(LI.resource_database_id) +'.'+ O.object_schema  +'.'+ O.object_name
		WHEN LI.resource_type = 'OBJECT' THEN DB_NAME(LI.resource_database_id)
		ELSE LI.resource_description
	END AS IdentificaoResource
	,S.program_name
FROM
	#BL BL
	INNER JOIN
	#Sessoes S 
		ON S.session_id = BL.session_id
	LEFT JOIN
	#LocksInfo LI
		ON LI.request_session_id = BL.session_id
	LEFT JOIN
	#Objetos O
		ON O.database_id = LI.resource_database_id
		AND O.object_id = LI.resource_associated_entity_id
ORDER BY
	BL.Origem,BL.Ordem

