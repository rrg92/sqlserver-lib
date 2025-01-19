/*#info 

	# Autor 
		Rodrigo Ribeiro Gomes 
		
	# Detalhes 
	
		Obtém informações sobre erros que ocorreram no banco!
		O Power Alerts coleta os erros periodicamente.
		O Job é o 'PowerRoutine - Load XEvent Database Error'
		Se o erro que você está procurando ocorreu recentemente, importante rodar o job para garantir que ele coletou o mais recente.  
		Por padrao, esse job roda somente na madrugada para minimizar impactos. 
		Ao rodar no meio de expediente, monitore a execucao para garantir que ele nao estej atrapalhando algum outro processo, pois, 
		dependendo da quantidade de erros gerados, ele pode consumir um recurso de cpu significativo.

*/
USE Traces  --> Geralmente o Power Alerts é instalado num banco chamado Traces
GO

--> Primeiro identifica o id (LogId) do erro
SELECT
	*
FROM
	PowerRoutine_Log_DB_Error
where
	err_timestamp >= DATEADD(HH,-24,GETDATE()) --> Ajuste o filtro conforme queria
	
--> Traduz a stack de um erro (se aconteceu em procedure, que está de outras, etc.)
-- isso aqui traz exatamente onde ocorreu (incluindo a linha na proc ou batch original)!
select
	Query = Stmt
	,ProcName 
	,NumLinha = FrameLine
from
	vwPowerRoutine_DbErrorFrames
where
	LogId = 4725078 --> Obter o LogId da query acima!
order by
	LogId,FrameLevel desc