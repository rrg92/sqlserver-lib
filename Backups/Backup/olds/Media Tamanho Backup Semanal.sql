/*#info 

	# Autor 
		Rodrigo Ribeiro Gomes 
		
	# Detalhes 
		Script para ter uma visão do total e tamanho de backups da semana


*/

select
	avg(soma) as MediaSemanal
from
(
SELECT
	 faixas.maiorigualque    miq
	,faixas.menorque	    mq
	,sum(bs.backup_size)  Soma
from
(
SELECT DISTINCT
	DATEADD(DAY,-6,cast( CONVERT(VARCHAR(10),backup_finish_date,103) AS DATETIME))  as maiorigualque
	,DATEADD( DAY,1,cast( CONVERT(VARCHAR(10),backup_finish_date,103) AS DATETIME)) as menorque
FROM 
	msdb..backupset
WHERE
DATEPART(weekday,backup_finish_date) = 1
) as faixas
inner join msdb..backupset bs on bs.backup_finish_date >= faixas.maiorigualque and bs.backup_finish_date < faixas.menorque
group by
	 faixas.maiorigualque
	,faixas.menorque
	
) as somatoria


--order by
--bs.backup_finish_date
--ORDER BY
--	DATEADD( DAY,1,cast( CONVERT(VARCHAR(10),backup_finish_date,103) AS DATETIME))



--ORDER BY
--	YEAR(backup_finish_date)
--backup_start_date
--backup_finish_date
--print @@datefirst
--SELECT (dw, GETDATE())
--SELECT DISTINCT  backup_finish_date,DATEPART(weekday,backup_finish_date)  FROM msdb..backupset order by backup_finish_date