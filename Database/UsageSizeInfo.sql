/*#info 

	# Autor 
		Rodrigo Ribeiro Gomes 
		
	# Descrição 
		Traz o tamanho e o último acesso (ESTIMADO) de cada banco.

*/


IF OBJECT_ID('tempdb..#TamanhoBancos') IS NOT NULL
	DROP TABLE #TamanhoBancos;

CREATE TABLE
	#TamanhoBancos( Banco sysname, TamanhoTotalPag int, TamanhoUsadoPag int );
	
EXEC sp_MSforeachdb '
	USE [?];
	
	INSERT INTO #TamanhoBancos
	SELECT
	 db_name()
	 ,SUM(size) 
	 ,SUM(FILEPROPERTY(name,''SpaceUsed''))
	FROM
		sys.database_files
'

SELECT
	 Instancia = @@SERVERNAME
	,Banco
	,TamTotal = TamanhoTotalPag/128.0
	,DataCriacao = D.create_date
	,UltimoUso = LU.LastUse
FROM
	#TamanhoBancos TB
	JOIN
	sys.databases D
		ON D.name = TB.Banco COLLATE Latin1_General_CI_AI
	OUTER APPLY
	(
		SELECT 
			DBName = DB_NAME(IUS.database_id)
			,LastUse = MAX(I.LastUse)
		FROM
			sys.dm_db_index_usage_stats IUS
			CROSS APPLY
			(
				SELECT
					LastUse = MAX(U.LastUserOp)
				FROM
					(
						SELECT IUS.last_user_seek
						UNION ALL
						SELECT IUS.last_user_scan
						UNION ALL
						SELECT IUS.last_user_lookup
					) U(LastUserOp)
				WHERE
					U.LastUserOp is not null
			) I
		WHERE
			I.LastUse IS NOT NULL
			AND
			DB_NAME(IUS.database_id) = TB.Banco COLLATE Latin1_General_CI_AI
		GROUP BY
			IUS.database_id
	) LU