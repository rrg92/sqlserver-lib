/*#info
	# autor 
		Rodrigo Ribeiro Gomes 

	# descricao 
		Lista a cadeia de bloqueios, pela sessao que originou o bloquei!
		USei muito antes de conhecer a sp_whoisactive @find_block_leaders = 1
		Mas ainda pode ser util se nao tem sp_whoisactive ou se vc precisar adaptar um script que faz isso!

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
	
IF OBJECT_ID('tempdb..#Connections') IS NOT NULL
	DROP TABLE #Connections;
	
IF OBJECT_ID('tempdb..#Requests') IS NOT NULL
	DROP TABLE #Requests;


SELECT S.session_id,S.program_name,S.host_name,S.status,S.login_name INTO #Sessoes FROM sys.dm_exec_sessions S 
SELECT C.session_id,C.client_net_address INTO #Connections FROM sys.dm_exec_connections C
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
	 ,ROW_NUMBER() OVER(PARTITION BY Origem ORDER BY Nivel,start_time  ) as Ordem
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

IF OBJECT_ID('tempdb..#BlockChain') IS NOT NULL
	DROP TABLE #BlockChain;


SELECT
	 BL.session_id  
	,BL.BlockedBy	
	,BL.Origem		
	,BL.start_time
	,BL.Ordem
	,BL.Nivel
	,S.status as SessionStatus
	,S.program_name
	,C.client_net_address
	,S.host_name
	,S.login_name
INTO	
	#BlockChain
FROM
	#BL BL
	INNER JOIN
	#Sessoes S 
		ON S.session_id = BL.session_id
	LEFT JOIN
	#Connections C
		ON C.session_id = BL.session_id
	--LEFT JOIN
	--#LocksInfo LI
	--	ON LI.request_session_id = BL.session_id
	--LEFT JOIN
	--#Objetos O
	--	ON O.database_id = LI.resource_database_id
	--	AND O.object_id = LI.resource_associated_entity_id

SELECT
	Origem
	,COUNT(DISTINCT session_id) AS BlockCount
FROM
	#BlockChain
GROUP BY
	Origem


SELECT
	*
FROM
	#BlockChain
ORDER BY
	Origem,Ordem

