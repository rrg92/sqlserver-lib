-- bBackup Full AlwaysON
use master 
go

-- conectado no sql1?
select @@Servername 

-- recria o ag!
if exists(select * from sys.availability_groups where name = 'Ag1')
	drop availability group Ag1

if db_id('Db1') is not null
	exec('Alter database Db1 set read_only with rollback immediate; drop database Db1')

-- Cria um banco e tab de testes!
	create database Db1;
	go
	use Db1;
	go
	create table tab1(id int identity primary key, c char(1), c2 char(7000))
	insert into tab1(c,c2) 
	select top (50000) choose(C.I,'A','B','C','D'),'teste' 
	from sys.all_columns a1,sys.all_columns a2 CROSS APPLY (VALUES(ABS(CHECKSUM(NEWID())%4)+1)) C(i)
	go 
	alter database Db1 set recovery full;
	backup database Db1 to disk = 'nul';


-- Cria um Ag!
USE master 
GO

	-- Endpoints Mirroring já configurados!

	CREATE AVAILABILITY GROUP Ag1
	WITH (CLUSTER_TYPE = none)
	FOR 
	REPLICA ON N'SQL1' WITH (
		 ENDPOINT_URL = N'TCP://sql1:5022'
		,FAILOVER_MODE = MANUAL
		,AVAILABILITY_MODE = SYNCHRONOUS_COMMIT
		,SEEDING_MODE = AUTOMATIC
		,PRIMARY_ROLE(ALLOW_CONNECTIONS = ALL)
		,SECONDARY_ROLE(ALLOW_CONNECTIOns = all)
	)

	-- grant for seeding
	ALTER AVAILABILITY GROUP Ag1 GRANT CREATE ANY DATABASE;

	-- Add sql 2
	ALTER AVAILABILITY GROUP Ag1 
	ADD REPLICA ON 'SQL2' WITH (
		 ENDPOINT_URL = N'TCP://sql2:5022'
		,FAILOVER_MODE = MANUAL
		,AVAILABILITY_MODE = SYNCHRONOUS_COMMIT
		,SEEDING_MODE = AUTOMATIC
		,PRIMARY_ROLE(ALLOW_CONNECTIONS = ALL)
		,SECONDARY_ROLE(ALLOW_CONNECTIOns = all)
	)
	   

	-- adicionar banco Db1
	ALTER AVAILABILITY GROUP Ag1 ADD DATABASE Db1

	-- conectando no 2:
	/*
		SELECT @@servername -- sql2

		use master 
		go 


		-- drop ag!
		if exists(select * from sys.availability_groups where name = 'Ag1')
			drop availability group Ag1

		-- drop db1 se existe!
		if db_id('Db1') is not null
		begin
			exec('Alter database Db1 set read_only with rollback immediate; drop database Db1')
			exec('drop database Db1') -- if restoring dropa...
		end

	
		ALTER AVAILABILITY GROUP Ag1 JOIN WITH(CLUSTER_TYPE = NONE)
		ALTER AVAILABILITY GROUP Ag1 GRANT CREATE ANY DATABASE; -- aguardar auto seeding depois de rodar!
	*/


	-- monitorar o seeding
	-- truncate table msdb.dbo.dm_hadr_automatic_seeding_history  
	select * From sys.dm_hadr_automatic_seeding
	



-- Backup na secondary
/*
	-- conecta na secundaria!
	-- https://learn.microsoft.com/en-us/sql/database-engine/availability-groups/windows/active-secondaries-backup-on-secondary-replicas-always-on-availability-groups?view=sql-server-ver17#new-for-sql-server-2025
	select @@servername -- sql2

	-- dbcc tracestatus
	-- dbcc traceoff(3261, -1); dbcc traceoff(3262,-1)

	-- backup database (nao funciona) 
	backup database Db1 to disk = 'nul'
	backup database Db1 to disk = 'nul' with copy_only -- funciona

	-- nao funciona
	backup database Db1 to disk = 'nul'	with differential
	backup database Db1 to disk = 'nul'	with differential,copy_only

	-- trace flag 3261: diff!
	dbcc traceon(3261,-1)  -- repetir!

	-- trace flag 3262: full!
	dbcc traceon(3262,-1)	 -- repetir!

	- historico msdb...
	select backup_finish_date,database_name,server_name from msdb..backupset order by backup_finish_date desc

	-- 2022 nao funcionava...
	/*
		dbcc tracestatus
		backup database Db22 to disk = 'nul' with copy_only
		dbcc traceon(3262,-1);
		backup database Db22 to disk = 'nul'
	*/

	
*/

-- persisted statistics!
	-- https://learn.microsoft.com/en-us/sql/relational-databases/performance/persisted-stats-secondary-replicas?view=sql-server-ver17
	-- conectar na primary 
	select @@servername -- sql1

	-- Habilitar query store
	-- Habiltia com all para pegar tudo!
	ALTER DATABASE Db1 SET QUERY_STORE = ON ( OPERATION_MODE  = READ_WRITE, QUERY_CAPTURE_MODE  = ALL )

	-- Habilita query store para secondaries!
	-- antes do 2025, tinha que usar a tf 12606 
	ALTER DATABASE Db1 FOR SECONDARY SET QUERY_STORE = ON (OPERATION_MODE = READ_WRITE, QUERY_CAPTURE_MODE  = ALL );

		-- 	ALTER DATABASE Db1 SET QUERY_STORE clear

	-- confirma
	Use Db1
	select * from sys.database_query_store_options


	-- teste!
	select count(*) from tab1  



	-- confirmar que está caputrando! sp_query_store_flush_db
	select 
		qt.query_text_id
		,qt.query_sql_text
		,q.query_id
		,q.query_hash
		,q.count_compiles
		,LastLocalExec = SWITCHOFFSET( q.last_execution_time, '-03:00')
		,LastRun = SWITCHOFFSET( r.last_execution_time, '-03:00' )
		,r.count_executions
		,r.runtime_stats_interval_id
		,r.plan_id
		,r.replica_group_id
	from
		sys.query_store_query_text qt
		join
		sys.query_store_query q
			on q.query_text_id = qt.query_text_id
		outer apply (
			select top 1 rs.*
			from  sys.query_store_runtime_stats rs
				join sys.query_store_plan qp on qp.plan_id = rs.plan_id
			where qp.query_id = q.query_id
			order by rs.last_execution_time desc
		) r
	where
		q.query_hash in (0x55E891266A8E0AB7, 0xACE2CDF6D4FC0757)
		-- 55e = select count(*)
		-- 0xace = select top 1 id%X = 0


	-- conectar no sql 2 (copiar query acima para olhar)
	/*
		select @@servername 
		USE Db1

		-- verificar query_store!
		 select * from sys.database_query_store_options

		 -- test! checar se query store está pegando
		 select top 1 * from tab1 where id%10000 = 0

		 -- sp_query_store_flush_db  -- forçar flush/envio (Rodar sec/prim)
	*/


	-- novas colunas:  replica_role_id
	select 
		object_id
		,stats_id
		,name 
		,auto_created
		,replica_role_id
		,replica_role_desc
		,replica_name
	from
		sys.stats


	-- executar no sql 2
	/*
		use Db1
		select @@servername --sql2

		-- confirmar tf
		dbcc tracestatus -- 

		-- ver plano
		select count(*) from tab1 where c = 'A'

		-- ver stats!
		select * From sys.stats	where object_id = object_id('tab1')

	*/

	-- 		dbcc tracestatus
	-- não existe!
	select * From sys.stats	where object_id = object_id('tab1')



	-- aplicar tf 15608	nas 2 instancias!
	-- reiniciar e repetir os testes!
	-- confirmar:
	-- dbcc tracestatus
	update statistics tab1 _WA_Sys_00000002_35BCFE0A with fullscan







-- query store hint funciona?

	-- query:
	-- select top 1 * from tab1 where id%10000 = 0

	-- aplica hint! (rodar na secundaria?)
	EXEC sys.sp_query_store_set_hints
		@query_id = 4,
		@query_hints = N'OPTION (USE HINT (''ABORT_QUERY_EXECUTION''))';

	-- hitns
	select * From sys.query_store_query_hints


	
	
	-- parametro: query_hint_scope
	EXEC sys.sp_query_store_set_hints
		@query_id = 4,
		@query_hints = N'OPTION (USE HINT (''ABORT_QUERY_EXECUTION''))'
		,@query_hint_scope  = 2
		;