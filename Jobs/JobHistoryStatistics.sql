/*#info 

	# Autor 
		Rodrigo Ribeiro Gomes 
		
	# Descrição 
		Obtém a quantidade de histórico (em linhas) por job!
		Já usei para achar qual job estava mais ocupando espaço nos logs

*/
SELECT
	JH.name
	,JHS.*
FROM
	(
		SELECT 
			job_id
			,LogCount = count(*) 
		FROM 
			msdb..sysjobhistory 
		GROUP BY
			job_id
	) JHS
	INNER JOIN
	msdb..sysjobs JH
		ON JH.job_id = JHS.job_id
ORDER BY 
	LogCount desc