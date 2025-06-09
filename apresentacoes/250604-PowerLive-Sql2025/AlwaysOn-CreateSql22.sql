use master 
select @@servername -- sql1\i22
go



-- recria o ag!
if exists(select * from sys.availability_groups where name = 'Ag22')
	drop availability group Ag22

if db_id('Db22') is not null
	exec('Alter database Db22 set read_only with rollback immediate; drop database Db22')

-- Cria um banco e tab de testes!
	create database Db22;
	go
	use Db22;
	go
	create table tab1(id int identity primary key, c char(1), c2 char(7000))
	insert into tab1(c,c2) 
	select top (50000) choose(C.I,'A','B','C','D'),'teste' 
	from sys.all_columns a1,sys.all_columns a2 CROSS APPLY (VALUES(ABS(CHECKSUM(NEWID())%4)+1)) C(i)
	go 
	alter database Db22 set recovery full;
	backup database Db22 to disk = 'nul';


-- Cria um Ag!
USE master 
GO

	CREATE AVAILABILITY GROUP Ag22
	WITH (CLUSTER_TYPE = none)
	FOR 
	REPLICA ON N'SQL1\I22' WITH (
		 ENDPOINT_URL = N'TCP://sql1:7022'
		,FAILOVER_MODE = MANUAL
		,AVAILABILITY_MODE = SYNCHRONOUS_COMMIT
		,SEEDING_MODE = AUTOMATIC
		,PRIMARY_ROLE(ALLOW_CONNECTIONS = ALL)
		,SECONDARY_ROLE(ALLOW_CONNECTIOns = all)
	)

	-- grant for seeding
	ALTER AVAILABILITY GROUP Ag22 GRANT CREATE ANY DATABASE;

	-- Add sql 2
	ALTER AVAILABILITY GROUP Ag22 
	ADD REPLICA ON 'SQL2\i22' WITH (
		 ENDPOINT_URL = N'TCP://sql2:7022'
		,FAILOVER_MODE = MANUAL
		,AVAILABILITY_MODE = SYNCHRONOUS_COMMIT
		,SEEDING_MODE = AUTOMATIC
		,PRIMARY_ROLE(ALLOW_CONNECTIONS = ALL)
		,SECONDARY_ROLE(ALLOW_CONNECTIOns = all)
	)
	   
	-- adicionar banco Db1
	ALTER AVAILABILITY GROUP Ag22 ADD DATABASE Db22

	-- conectando no sql2\i22:
	/*
		SELECT @@servername -- sql2\i22
		
		if exists(select * from sys.availability_groups where name = 'Ag22')
			drop availability group Ag22

		-- drop db1 se existe!
		if db_id('Db22') is not null
		begin
			exec('Alter database Db22 set read_only with rollback immediate; drop database Db22')
			exec('drop database Db22') -- if restoring dropa...
		end

		ALTER AVAILABILITY GROUP Ag22 JOIN WITH(CLUSTER_TYPE = NONE)
		ALTER AVAILABILITY GROUP Ag22 GRANT CREATE ANY DATABASE;
	*/



	-- monitorar o seeding
	select * From sys.dm_hadr_automatic_seeding