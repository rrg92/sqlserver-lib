-- Abort quer Hint: https://learn.microsoft.com/en-us/sql/relational-databases/performance/query-store-hints-best-practices?view=sql-server-ver17#block-future-execution-of-problematic-queries 
use master 
go


if db_id('Db1') is not null
	exec('Alter database Db1 set read_only with rollback immediate; drop database Db1')

-- Cria um banco e tab de testes!
	create database Db1;
	go
	use Db1;
	go
	create table tab1(id int identity primary key, c char(1), c2 char(7000))
	insert into tab1(c,c2) 
	select top (10000) choose(C.I,'A','B','C','D'),'teste' 
	from sys.all_columns a1,sys.all_columns a2 CROSS APPLY (VALUES(ABS(CHECKSUM(NEWID())%4)+1)) C(i)
	go 

-- Nova querHint:

	select count(*) from tab1 
	option(use hint('ABORT_QUERY_EXECUTION'))

-- Util com Query Store
	ALTER DATABASE Db1 SET 
	QUERY_STORE = ON ( OPERATION_MODE  = READ_WRITE, QUERY_CAPTURE_MODE  = ALL )


-- confirma
	Use Db1
	select * from sys.database_query_store_options


	-- teste!
	select count(*) from tab1  

	-- query
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
		q.query_hash in (0x55E891266A8E0AB7)



	-- aplica hint! REPETE A QUERY!
	EXEC sys.sp_query_store_set_hints
		@query_id = 4,
		@query_hints = N'OPTION (USE HINT (''ABORT_QUERY_EXECUTION''))';

	-- hitns
	select * From sys.query_store_query_hints

	-- como remover?
	exec sp_query_store_clear_hints 4 