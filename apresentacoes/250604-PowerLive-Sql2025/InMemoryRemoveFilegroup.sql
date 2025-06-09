-- https://learn.microsoft.com/en-us/sql/relational-databases/in-memory-oltp/memory-optimized-container-filegroup-removal?view=sql-server-ver17
use master
go

if db_id('TestMem') is not null
	exec('alter database TestMem set read_only with rollback immediate; drop database TestMem')
go

create database TestMem
go

use TestMem
go

alter database TestMem add filegroup InMemTest contains MEMORY_OPTIMIZED_DATA
ALTER DATABASE TestMem 
ADD FILE (name='TestMem_1', 
filename='S:\mssql\A25\TestMem_1.ndf') TO FILEGROUP InMemTest

create table InMemData (
	id int identity primary key nonclustered
	,c1 varchar(100)
) with(memory_optimized = on, durability = schema_and_data)

insert into InMemData(c1) values('teste')

drop table InMemData


alter database 	TestMem remove file TestMem_1

-- em outra sessao!
/*
select * from  sys.dm_db_xtp_undeploy_status;
checkpoint -- 3 e 5
*/


alter database TestMem remove filegroup  InMemTest


