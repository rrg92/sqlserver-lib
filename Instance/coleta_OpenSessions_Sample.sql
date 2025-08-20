/*#info 
	
	# Autor
		Rodrigo Ribeiro Gomes 

	# Descricao 
		Uma query simple para coletar, a cada 1 segundo, o total de linhas na sysprocessos
		Basicamente, é para quando você quer ver se durante um certo intervalo de tempo algo aumenta mais do que o normal.
		Por padrão, faz a coleta por 5 segundos, mas você pode ajustar isso ali no loop!


*/

IF OBJECT_ID('tempdb..#OpenSessions') IS NOT NULL
	DROP TABLE #OpenSessions;

create table #OpenSessions(ts datetime, banco sysname, conexoes int);

DECLARE @START DATETIME
SET @START = CURRENT_TIMESTAMP

WHILE DATEDIFF(SS,@START,CURRENT_TIMESTAMP) <= 5
BEGIN
	INSERT INTO #OpenSessions select CURRENT_TIMESTAMP,DB_NAME(dbid),count(*) from master..sysprocesses 
	where 
		1 =1 -- filtrar o que quiser
	group by dbid
	WAITFOR DELAY '00:00:01.000';
END

select * from #OpenSessions