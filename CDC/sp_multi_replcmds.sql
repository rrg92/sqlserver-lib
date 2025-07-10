/*#info 

	# Autor 
		Rodrigo Ribeiro Gomes 
		
	# Detalhes 
		Eu não lembro exatamente o porquê criei isso, mas vagas memórias me remetem a tentar ler o log de diferentes bancos em paralelo, para algum teste.
		Deixei o script apenas para referência, não me lembro se tem algum uso prático em ambientes de prod.
		
		
*/
ALTER PROCEDURE
	sp_multi_replcmds
	(
		@WaitNextTime  int = null
		,@MaxRepeats int = 1000	
	)	
AS

DECLARE
	@GlobalRID varchar(255)
	,@DB sysname
	,@RID_Using varchar(500)
	,@RID_isUsing bit
	,@Comando nvarchar(max)


SELECT
	@GlobalRID = ISNULL(OBJECT_NAME(ST.objectid,ST.dbid),'')
FROM
	sys.dm_exec_requests R
	CROSS APPLY
	sys.dm_exec_sql_text(R.sql_handle) ST
WHERE
	R.session_id = @@SPID

SET @RID_Using = '-- #REUSING: THIS RESOURCE IS USING FOR: '+@GlobalRID

DECLARE @RID_GetR varchar(100)
SET @RID_GetR = @GlobalRID +':BANCO_EXEC';

GET_RESOURCE: 
	SET @Comando = NULL
	SET @DB = NULL
	EXEC sp_getapplock @RID_GetR,'EXCLUSIVE','SESSION';

		SELECT 
			@DB = name
		FROM
		(
			SELECT TOP 1
				 D.name
			FROM
				sys.databases D
			WHERE
				D.is_cdc_enabled = 1
				AND
				D.database_id NOT IN (

					SELECT
						R.database_id
					FROM
						sys.dm_exec_requests R
						CROSS APPLY
						sys.dm_exec_sql_text(R.sql_handle) ST
					WHERE
						OBJECT_NAME(ST.objectid,ST.dbid) = 'sp_replcmds'
				)
			) T

		IF @DB IS NOT NULL
		BEGIN
	
			SET @Comando = 'EXEC '+QUOTENAME(@DB)+'..sp_replcmds; exec sp_repldone null,null,1,0,1';
			print @comando;
			
			-- Tentando obter o lock para a base específica...
			DECLARE @RID_ExecR varchar(100)
			SET @RID_ExecR = @GlobalRID+':DB:'+@DB

			BEGIN TRY
				EXEC sp_getapplock @RID_ExecR,'EXCLUSIVE','SESSION',@LockTimeout = 500;
				SET @RID_isUsing = 1;
			END TRY
			BEGIN CATCH	
				SET @RID_isUsing = 0;

				IF ERROR_NUMBER() = 1222
				BEGIN
					GOTO GET_RESOURCE;
				END ELSE BEGIN

					EXEC  sp_releaseapplock @RID_GetR,'SESSION';
					print ERROR_NUMBER()
					print ERROR_MESSAGE()
					RAISERROR('Houve um erro.',16,1);

				END
			END CATCH

		END

	EXEC  sp_releaseapplock @RID_GetR,'SESSION';


	IF @Comando IS NULL
		RAISERROR('Não há comando para executar: %d',16,1,@@SPID);
	ELSE
		EXEC(@Comando)
	;

	EXEC sp_releaseapplock @RID_ExecR,'SESSION'

