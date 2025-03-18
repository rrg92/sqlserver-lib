/*#info 

	# Autor 
		Rodrigo Ribeiro Gomes 
		
	# Detalhes 
		Script simple para obter o ultimo restore de cada banco registrado na tabela de restores


*/

USE MSDB
GO

SELECT
	 RH.DESTINATION_DATABASE_NAME	as Banco
	,rh.restore_type				as Tipo
	,MAX(rh.restore_date)			as Data
FROM
	msdb..restorehistory rh
WHERE
	rh.restore_type = 'D'
GROUP BY
	 RH.DESTINATION_DATABASE_NAME
	,rh.restore_type
HAVING
	MAX(rh.restore_date) < DATEADD(d,-1,getDate()) 
ORDER BY
	 Banco
	,Tipo