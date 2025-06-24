/** DEMO
		DELETE SEM WHERE, SEM BACKUP, RECOVERY SIMPLE, ANTES DO CHECKPOINT (usando Recover_Deleted_Data_Proc)
	Objetivo
		Mostrar como é possível recuperar dados em uma situação extremamente emergencial, usando a proc Recover_Deleted_Data_Proc.

		-- Um cara chamado Muhammad Imran fez uma proc incrível que faz todo este procedimento automaticamente!
		-- O link para o artigo é: http://raresql.com/2012/10/10/how-to-recover-the-deleted-records-from-sql-server/
		-- Abrir o Arquivo Recover_Deleted_Data para simular!

	Autores:
		Gustavo Maia Aguiar
		Rodrigo Ribeiro Gomes
		Muhammad Imran ( http://raresql.com )
**/


-- Restaurando a base ORIGINAL!!
	USE master 
	GO
	IF DB_ID('DbCorrupt') IS NOT NULL
	BEGIN
		EXEC('ALTER DATABASE DbCorrupt SET READ_ONLY WITH ROLLBACK IMMEDIATE')
		EXEC('DROP DATABASE DbCorrupt')
	END

	RESTORE DATABASE DBCorrupt
	FROM DISK = 'T:\DbCorrupt.bak'
	WITH
		REPLACE
		,STATS = 10
		--,MOVE 'DBCorrupt' TO 'C:\temp\DBCorrupt.mdf'
		--,MOVE 'DBCorrupt_log' TO 'C:\temp\DBCorrupt.ldf'

	USE DBCorrupt
	GO

	--Base em recovery SIMPLE!
	ALTER DATABASE DBCorrupt SET RECOVERY SIMPLE;


 -- E a proc: .\CreateRecoverProc.sql (https://raresql.com/2011/10/22/how-to-recover-deleted-data-from-sql-sever/)



--E então, um DELETE acidental!!! (REPARE O NÚMERO DE REGISTROS DELETADOS)
DELETE TOP(1000) FROM DBCorrupt.dbo.Lancamentos WHERE NumConta = 14325
 

USE DBCorrupt;
GO
Recover_Deleted_Data_Proc 'DBCorrupt','dbo.Lancamentos'
GO