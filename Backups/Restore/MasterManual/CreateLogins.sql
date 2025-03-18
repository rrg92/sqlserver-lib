/*

	# Autor 
		Rodrigo Ribeiro Gomes 
		
	# Detalhes 
		Script para recuperar informações dos logins a partir de um banco master restautado.
		PAra usar, você deve obter o backup do banco do master e restautar com o nome OldMaster (se mudar, ajuste no script).
		Exemplo:
			restore database OldMaster from disk = 'CaminhoBackup'
			with
				move 'master' to 'CaminhoRestore\OldMaster.mdf'
				,move 'mastlog' to  'CaminhoRestore\OldMaster.ldf'


		Conecte como DAC e rode esse script.
		Esse scriopt é bem útil em cenários de recuperação, onde você, por algum motivo, precisou remontar o servidor e não pode restauar a master.
		Com esse script, você tem mais chance de recuperar os logins SQL junsto com as senhas e configurações.
		Já me ajudou bem a minimizar o impacto e manter as apps fincionando com a mesma senha, mesmo quando ngm sabia.
*/


USE OldMaster
go

SELECT
	*
 	 ,'CREATE LOGIN '+QUOTENAME(name)
		+CASE 
			WHEN type in ('G','U') THEN ' FROM WINDOWS '
			WHEN type = 'S' THEN 
				+' WITH PASSWORD = '+CONVERT(varchar(max),pwdhash,1)+' HASHED, SID = '+convert(VARCHAR(MAX),p.sid,1)+' '
				+',CHECK_POLICY = '+CheckPolicy
				+',CHECK_EXPIRATION = '+CheckExpiration
				+isnull(',CREDENTIAL = '+CredentialName,'')
		END
		+',DEFAULT_DATABASE = '+quotename(dbname)
		+',DEFAULT_LANGUAGE = '+lang

	+CASE WHEN IsDisabled = 1 THEN ';ALTER LOGIN '+quotename(name)+' DISABLE' ELSE '' END
FROM
	(
		 select 
			  p.name
			 ,dbname
			 ,pwdhash
			 ,sid
			 ,lang
			 ,CheckPolicy		= CASE WHEN convert(bit, p.status & 0x10000) = 1 THEN 'ON' ELSE 'OFF' END
			 ,CheckExpiration	= CASE WHEN convert(bit, p.status & 0x20000) = 1 THEN 'ON' ELSE 'OFF' END
			 ,IsDisabled	= convert(bit, p.status & 0x80) 
			 ,CredentialName = co.name
			 ,p.type
		 from 
			sys.sysxlgns p  
			LEFT JOIN
			sys.syssingleobjrefs r ON r.depid = p.id AND r.class = 63 AND r.depsubid = 0 
			LEFT JOIN
			sys.sysclsobjs co  on co.id = r.indepid and co.class = 57and co.type=''
		 WHERE
			p.type IN ('U','G','S')
			AND NOT EXISTS (
				SELECT * FROM sys.server_principals SP WHERE SP.name = p.name
			)
	) P


