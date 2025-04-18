/*#info 

	# Autor 
		Rodrigo Ribeiro Gomes 
		
	# Descrição 
		Obtém informacoes dos jobs, cujo última execução foi falha.
		ATENÇÃO: Esse script pode demorar um pouco e dependendo da quantidade de histórico, pode causar alguma pressão no seu ambiente.
		Acredito que tenha um espaço para otimizações e não me lembro exatamente o porquê fiz usando row_number com partition.

*/
SELECT
	CONVERT(varchar(150),J.name) as NomeJOB
	,CONVERT(varchar(150),j.step_name) as NomeSTEP
	,CONVERT(datetime,j.DataStart) as DataStart
	,CONVERT(varchar(8),J.Duracao) as Duracao
	,CONVERT(varchar(500),STUFF(S.agendamentos,1,3,'')) as Agendamentos
	,CONVERT(int,J.run_status) as run_status
FROM
(
	SELECT
		*
		,ROW_NUMBER() OVER(PARTITION BY J.name ORDER BY J.DataStart DESC) Rn
	FROM
	(
		SELECT
			J.name
			,J.job_id
			,JH.step_name
			,CONVERT(DATETIME, CONVERT(CHAR(8), run_date, 112) + ' ' 
			+ STUFF(STUFF(RIGHT('000000' + CONVERT(VARCHAR(8), run_time), 6), 5, 0, ':'), 3, 0, ':'), 121 ) DataStart
			,STUFF(STUFF(RIGHT('000000'+CONVERT(varchar(8),JH.run_duration),6),3,0,':'),6,0,':') as Duracao
			,JH.message
			,JH.run_status
		FROM
			msdb.dbo.sysjobhistory JH
			INNER JOIN
			msdb.dbo.sysjobs J 
				ON J.job_id = JH.job_id
		WHERE
			JH.step_id <> 0
	) J 
) J 
	OUTER APPLY (
	
		SELECT
			' | '+S.name as 'data()'
		FROM
			msDb.dbo.sysjobschedules JS
			JOIN
			msdb.dbo.sysschedules S 
				ON S.schedule_id = JS.schedule_id
		WHERE
			JS.job_id = J.job_id
		FOR XML PATH('')
	) S(agendamentos)
	
WHERE
	J.Rn = 1
	AND
	J.run_status = 0
ORDER BY
	DataStart DESC