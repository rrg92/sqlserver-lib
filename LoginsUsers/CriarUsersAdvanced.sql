/*#info 

	# Autor 
		Rodrigo Ribeiro Gomes 
		
	# Detalhes 
		Cria users associado com logins no banco atual e adiciona no role db_owner.
		
		
*/


SET NOCOUNT ON;

IF OBJECT_ID('tempdb..#LoginsAllowed') IS NOT NULL
	DROP TABLE #LoginsAllowed;
CREATE TABLE #LoginsAllowed(LoginName sysname);
INSERT INTO #LoginsAllowed VALUES('NomeLogin');

DECLARE
	@col_LoginName varchar(1000)
	,@userName sysname
	,@LoginSID varbinary(100)
	,@UserSID varbinary(100)
	,@tsql nvarchar(4000)
;

DECLARE curLoginsAllow CURSOR LOCAL FAST_FORWARD
FOR
	SELECT * FROM #LoginsAllowed;


OPEN curLoginsAllow;

	FETCH NEXT FROM curLoginsAllow INTO @col_LoginName;

	While @@FETCH_STATUS = 0
	BEGIN

		--> Check if login exists
		IF SUSER_ID(@col_LoginName) IS NULL
		BEGIN
			RAISERROR('Login %s não existe. Favor criar e re-executar este script.',0,1,@col_LoginName);
			GOTO FETCH_NEXT;
		END

		SET @LoginSID = SUSER_SID(@col_LoginName);
		SET @userName = NULL;
		SET @UserSID = NULL;

		--> Try get user name and possible mapped login sid...
		SELECT 
			@userName = DP.name
			,@UserSID = ISNULL(SP.sid,DP.sid)
		FROM 
			sys.database_principals DP 
			LEFT JOIN
			sys.server_principals SP
				ON SP.sid = DP.sid
		WHERE 
			DP.name = @col_LoginName

		IF @userName IS NULL --> If user name not found... Try get by login sid...
			SELECT 
				@userName = DP.name
			FROM 
				sys.database_principals DP 
			WHERE 
				DP.name = SUSER_SID(@col_LoginName)

		-- Possible cenarios
		-- User dont exists
		-- User exists, different login
		-- User exists, no mapping
		-- User exists, but mapped with different name
		-- User exists

		SET @tsql = NULL;
		IF @userName IS NULL --> User Dont Exists and Login dont have mapped users...

		BEGIN
			SET @userName = @col_LoginName;
			SET @tsql = 'CREATE USER '+QUOTENAME(@col_LoginName)+' FROM LOGIN  '+QUOTENAME(@col_LoginName);
		END

		ELSE IF @userName IS NOT NULL AND @UserSID IS NULL -- User exists, no mapping
		BEGIN
			-- Remap user...
			SET @tsql = 'ALTER USER '+QUOTENAME(@userName)+' WITH LOGIN = '+QUOTENAME(@col_LoginName,'''');
		END

		ELSE IF @userName IS NOT NULL AND @UserSID != SUSER_SID(@col_LoginName) AND @UserSID IS NOT NULL --> User exists, different login
		BEGIN
			--Generate new user name...
			SET @userName = @col_LoginName+CONVERT(varchar(25),ABS(CHECKSUM(NEWID())))
			SET @tsql = 'CREATE USER '+QUOTENAME(@userName)+' FROM LOGIN  '+QUOTENAME(@col_LoginName);
		END



		-- All other cases, the user already exists and @userName must contain correct username 
		IF @tsql IS NOT NULL
		BEGIN
			RAISERROR('Executando (Login: %s): %s',0,1,@col_LoginName,@tsql);
			EXEC(@tsql);
		END

		IF USER_ID(@userName) IS NOT NULL
		BEGIN
			RAISERROR('Granting role membership: %s',0,1,@userName);
			EXEC sp_addrolemember 'db_owner',@userName;
		END

		FETCH_NEXT:
			FETCH NEXT FROM curLoginsAllow INTO @col_LoginName;
	END

CLOSE curLoginsAllow;
DEALLOCATE curLoginsAllow;