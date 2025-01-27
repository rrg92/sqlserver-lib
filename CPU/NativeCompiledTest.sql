/*#info 

	# Autor 
		Rodrigo Ribeiro Gomes

	# Detalhes 
		Uns testes malucos com procs native compiled...
		Fui testar no sql mais recente, e não funcionou... 
		Mas mantendo para um dia revisar isso aqui...
*/

-- create database CpuStress
-- ALTER DATABASE CpuStress ADD FILEGROUP inmemory CONTAINS MEMORY_OPTIMIZED_DATA  
-- select replace(physical_name,'CpuStress.mdf','CpuStress.ndf') from CpuStress.sys.database_files where type_desc = 'ROWS'
-- ALTER DATABASE CpuStress ADD FILE (name='inmemory', filename='S:\mssql\a19\MSSQL15.A19\MSSQL\DATA\CpuStress.ndf') TO FILEGROUP inmemory



USE CpuStress
GO

CREATE OR ALTER PROCEDURE dbo.spCpuStressNative (@i bigint) 
WITH NATIVE_COMPILATION, SCHEMABINDING  
AS BEGIN ATOMIC WITH  
(  
 TRANSACTION ISOLATION LEVEL = SNAPSHOT, LANGUAGE = N'us_english'  
)  
declare @start_cpu datetime = getdate(), @starti bigint = @i;
while @i > 0 set @i -= 1;
select UsedCPU = datediff(ms,@start_cpu, getdate()) , Loops = @starti
END
GO  

CREATE OR ALTER PROCEDURE dbo.spCpuStress (@i bigint) 
AS 
set nocount on;
declare @start_cpu datetime = getdate(), @starti bigint = @i;
while @i > 0 set @i -= 1;
select UsedCPU = datediff(ms,@start_cpu, getdate()), Loops = @starti
GO  

/*
set nocount on;
declare @s bigint
select @s = cpu_time from sys.dm_exec_requests where session_id = @@SPID
exec spCpuStressNative 1
select NativeCompiledCpu = cpu_time  - @s  from sys.dm_exec_requests where session_id = @@SPID
go


set nocount on;
declare @s bigint
select @s = cpu_time from sys.dm_exec_requests where session_id = @@SPID
exec spCpuStress 10000000
select NormalCpu = cpu_time  - @s  from sys.dm_exec_requests where session_id = @@SPID
*/