/*#info 

	# Autor 
		Rodrigo Ribeiro Gomes 
		
	# Descrição 
		Essa foi um tentativa de uma query para estimar o último uso de banco de dados.
		O segredo aqui é usar a DMV sys.dm_db_index_usage_stats que contém um log com a última desde o restart.
		Então, a informação não é 100% precisa, mas serve apenas como um norte rápido para uma base que é muito usada.

*/

SELECT
	CURRENT_TIMESTAMP		as CollectionTime
	,DI.*
	,SI.*
FROM
	(
		SELECT
			DB_NAME(US.database_id)	as DatabaseName
			,MAX(LACT.LastDate)		as LastUse
		FROM
			sys.dm_db_index_usage_stats US
			OUTER APPLY
			(
				SELECT
					MAX(ACT.ActionDate) as LastDate
				FROM
				(
					SELECT US.last_user_lookup as ActionDate
					UNION ALL
					SELECT US.last_user_scan
					UNION ALL
					SELECT US.last_user_seek
					UNION ALL
					SELECT US.last_user_update
				) ACT
			) LACT
		GROUP BY
			DB_NAME(US.database_id)
	) DI
	CROSS JOIN
	(
		SELECT
			(SELECT create_date FROM sys.databases D WHERE d.name = 'tempdb') as ServerStartTime
	) SI
