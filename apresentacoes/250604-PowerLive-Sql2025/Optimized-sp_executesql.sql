-- ATUALIZAR: Abort quer Hint: https://learn.microsoft.com/en-us/sql/relational-databases/performance/query-store-hints-best-practices?view=sql-server-ver17#block-future-execution-of-problematic-queries 
use master 
go

 -- sql local?
 select @@servername


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

use Db1
go 

-- limpar o cache
dbcc freeproccache
set statistics io,time on


-- dbcc freeproccache
SET STATISTICS TIME ON

-- Tks Fabiano Amorim
-- https://github.com/rrg92/sqlserver-lib/blob/main/Misc/HighQueryCompilationTime.sql
-- dbcc freeproccache
exec sp_executesql N'
	;WITH cte AS
	(
	  SELECT objects.* 
		FROM sys.objects
	   INNER JOIN sys.indexes
		  ON indexes.object_id = objects.object_id
	   INNER JOIN sys.index_columns
		  ON index_columns.object_id = indexes.object_id
		 AND index_columns.index_id = indexes.index_id
	   INNER JOIN sys.columns
		  ON columns.object_id = index_columns.object_id
		 AND columns.column_id = index_columns.column_id
	)
	SELECT TOP 100 *
	FROM sys.objects
	INNER JOIN cte AS cte1 ON objects.name = cte1.name /* compile time = 41ms */
	INNER JOIN cte AS cte2 ON objects.name = cte2.name /* compile time = 125ms */ 
	INNER JOIN cte AS cte3 ON objects.name = cte3.name /* compile time = 375ms */
	INNER JOIN cte AS cte4 ON objects.name = cte4.name /* compile time = 1091ms */
	INNER JOIN cte AS cte5 ON objects.name = cte5.name /* compile time = 3630ms */
'



-- query stress: 5 iterations, 100 threads (sem connection pool = mais rapido o teste)!
	dbcc freeproccache 


-- conectar como DAC se nao conseguir ver!
select
	r.session_id
	,r.wait_type
	,r.wait_time
from
	sys.dm_exec_requests r
	join
	sys.dm_exec_sessions s
		on s.session_id = r.session_id
where
	s.program_name like '%Stress%'

-- rodar de novo depois do cache! 

-- Aplicar optimized sp_Executesql!
	use Db1; alter database scoped configuration set  OPTIMIZED_SP_EXECUTESQL = on
	-- use Db1; alter database scoped configuration set  OPTIMIZED_SP_EXECUTESQL = off
	dbcc freeproccache

-- copia?
select
	*
from
	sys.dm_exec_query_stats qs
where
	qs.query_hash = 0x2AEF80A2A805D535



