/*#info 

	# Autor 
		Rodrigo Ribeiro Gomes

	# Detalhes 
		Antes de ir para a Power Tuning e ajudar a desenvolver o Power Alerts V3, essa era minha principal query para fazer troblshooting de CPU.
		Falou em CPU alta, eu ja copiava essa query e analisava o resultado... uns 90% dos casos em que usei, achei de cara quem estava consumindo cpu alta...
		Em poucos segundos...

		O motivo pelo qual eu reduzi o uso dela após ir Para a Power Tunig é simples: Adicionamos essa mesma lógica nos alertas de CPU!
		Mas, ainda eu uso ela em ambientes que não tenham e me ajudam em um monitormaneto realtime ali dentro do seridor...

		A sacada aqui é a seguinte: Tire um foto do consumo de cpu total das queries, aguarda 1 segundo, e tire uma novo foto!
		Então, compare o que mudou e ordena pelo resultado!

		Falou em CPU alta na sua instância do SQL, essa é a primeira coisa que eu quero olhar: quais queries estão consumindo quantos % da cpu?
		Esse script ajuda a responder isso!

		Lembrando que essa query não é perfeita e não pegará todos os casos precisamente... Mas te garanto que ela poderá dar um visão extremamente nova sobre
		o consumo de CPU e dar um norte para onde deve procurar mais!

		No final desse script eu deixei uma historinha legal sobre esta query e mais background técnico de como ela funciona.
		Movi para o final, pois me empolguei no texto e isso virou quase um blog post!
		Se quiser saber mais da lógica que usei aqui (E para o caso de querer me ajudar a melhorar), recomendo a leitura!
*/


--> Se você quiser ir guardando os resultados em uma tabela, coloque o nome dela aqui!
--> Com isso vê pode comparar depois! 
-- CURIOSIDADE: acredita que demorei anos para pensar nessa sacada simples de colocar isso?
--				Me ajudou bastante, pois tinha um histórico rápido dessas coletas!
DECLARE
	@InsertTable sysname = ''


------- DAQUI PRA BAIXO, NÃO PRECISA ALTERAR NADA! ----


IF OBJECT_ID('tempdb..#UsoCPUAnterior') IS NOT NULL
DROP TABLE #UsoCPUAnterior;


IF OBJECT_ID('tempdb..#UsoCPUAtual') IS NOT NULL
DROP TABLE #UsoCPUAtual;


--> Tabela temporária para guardar a foto!
IF OBJECT_ID('tempdb..#CPUtotal') IS NOT NULL
	DROP TABLE #CPUtotal;


--> Primeria foto dos requests;
SELECT
R.session_id
,R.request_id
,R.start_time
,R.cpu_time
,CURRENT_TIMESTAMP as DataColeta
,R.sql_handle
,R.total_elapsed_time
,R.statement_start_offset
,R.statement_end_offset
,R.command
,R.database_id
,R.reads
,R.writes
,R.logical_reads
INTO
#UsoCPUAnterior
FROM
sys.dm_exec_requests R
WHERE
R.session_id != @@SPID



WAITFOR DELAY '00:00:01.000'; --> Aguarda 1 segundo (intervalo de monitoramento)

--> Segunda foto!
SELECT
R.session_id
,R.request_id
,R.start_time
,R.cpu_time
,CURRENT_TIMESTAMP as DataColeta
,R.sql_handle
,R.total_elapsed_time
,R.statement_start_offset
,R.statement_end_offset
,R.command
,R.database_id
,R.reads
,R.writes
,R.logical_reads
INTO
#UsoCPUAtual
FROM
sys.dm_exec_requests R
WHERE
R.session_id != @@SPID


--> Pronto, nesse momento já temos uma amostra do que houve em 1 segundo!
--> Vamos calcular!


-- algumas colunas são auto-explicativas... vou comentas apenas o que não é comum das DMVs do sql
SELECT
	 R.session_id
	,R.request_id
	,R.start_time

	--> Este é o intervalo que se passou entre uma coelta e outra... Vai ser sempre próximo ao valor do WAITFOR acima.. Em millisegundos
	-- isto é, considerando o padrão de 1 segundo que deixo no script, será algo muito próximo e 1000 ms.
	--> Pq eu nao deixo o valor hard-coded?
	--> Simples: devido a pressão do ambiente, o tempo exato de coleta não vai ser o que eu espero!
	-- Por isso, eu uso isso para obter um tempo mais próximod a realidade e consideranod possíveis delays ocasionados por uma pressão de cpu do ambiente...
	-- isso não é perfeito, mas funcionava incrivelmente bem e já vi algumas boas diferenças!
	--> Portanto, se eu coloquei 1 segundo de intervalo, mas coletou, após 1.5, então eu vou usar 1.5 como base para calcula ros percentual de uso de CPU!
	,Intervalo = ISNULL(DATEDIFF(ms,U.DataColeta,R.DataColeta),R.total_elapsed_time)

	--> Esse é total de CPU que o request gastou nesse intervalo, em milissegundos.
	-- Pode ser que seja nulo, para o caso de sessões que apareceram DEPOIS da primeira coleta... Nesse caso, vamos assumir que o total de cpu é o usado!
	,CPUIntervalo = ISNULL(R.cpu_time-U.cpu_time,R.cpu_time)

	--> Aqui vamos calcular o quanto do Intervalo foi gasto usando CPU.
	-- Por exemplo, se a query usou 500ms de CPU, isso é 50% de 1 segundo.
	-- Se a query rodou com paralelismo, e usou 4 cpus, totalizando um gasto 2s de CPU, isso é 200% do intervalo!
	-- Mas Rodrigo, 200%? SIM, 200... Devido ao paralelismo, você pode ver um consumo acima de 100%...
	-- E a razão é que esse valor vista te mostrar o quanto você consumiu do intervalo de coleta, não do total possível de uso!
	,[%Intervalo] = ISNULL((R.cpu_time-U.cpu_time)*100/DATEDIFF(ms,U.DataColeta,R.DataColeta),ISNULL((R.cpu_time/NULLIF(R.total_elapsed_time,0))*100,0))

	--> Esta é a duração total da query
	,Duracao = R.total_elapsed_time

	--> Este é total de cpu consumindo pela query, na sua vida inteira!
	-- Uma query pode iniciar a execução, consumir cpu, parar, consumir mais um pouco, parar, etc.
	-- essa coluna sempre é um acumulado, e por isso, sozinha não te ajuda a debugar um problema que está acontecendo agora!
	--> na verdade, ela so´ajudaria se essa query está a vida inteira gastando cpu e nunca parou
	-- Mas, como nem sempre será esse cenário, não podemos contar com ela sozinha!
	,CPUTotal = R.cpu_time

	--> Este é um percentual que representa o percentual de CPU gasto a vida inteira!
	--> Suponha que uma query rodou por 1 horas (3600 segundos). Mas, desse tempo, ela ficou 55 minutos em lock, pq alguem esqueceu uma transacao aberta!
	--> E, quando liberaram a transacao, os ultmios 5 minutos (300 segundos) dela foi moendo a CPIU...
	--> Neste caso, o percentual de CPU da vida inteira é: 300/3600 = 8,3%.
	--> Em que essa informacao é útil?
	--> Queries cmo percentual baixo, geralmente não são o que estão moendo sua CPU agora (gerlamente tá? mas pode ser sim).
	--> Quanto mais próximo de 100%, mais você entende que aquela query não teve impeditivos, e passou a vida inteira dela moendo CPU...
	--> Isso te ajuda a traçar um perfil daquela query. Mas ainda sim, o %Intervalo aina é muito mais importante que esse!
	,[%Total] = CONVERT(bigint,(R.cpu_time*100./NULLIF(R.total_elapsed_time,0)))
	
	--> Nome da procedure, functions ou view em que essa query esta! Informativo pra facilitar achar!
	--> Se você visualizar a mesma procedure aparecendo em várias linhas, pode já te dá um norte de qual parte do sistema é até entender se é algo novo ou quais usuarios podem estar causando um possível consumo além do normal
	,ObjectName = ISNULL(OBJECT_NAME(EX.objectid,EX.dbid),R.command)
	
	--> Trecho da query, dentro da procedure, que está causando! É os statement, o comando Sql de fato!
	,Trecho = q.qx

	
	,DatabaseName = db_name(R.database_id)
	
	-- Aqui você verá o id dos schedulers usados pela sua query!
	--> Se sua quer roda em paralelo, vai ver vários números separados pelo espaço!
	,S.sched

	,R.logical_reads
	,R.reads
	,R.writes
	--> quantidade total de tasks. Queries paralelas terão valor > 1
	,SC.TaskCount
	--> Quantidade única de schedules sendo usadas!
	--> O degree of parallelism controla isso!
	,SC.UniqueSched
	,CN.client_net_address
	,Ts = GETDATE()
INTO
	#CPUtotal
FROM
	#UsoCPUAtual R
	LEFT JOIN
	#UsoCPUAnterior U
	ON R.session_id = U.session_id
	AND R.request_id = U.request_id
	AND R.start_time = U.start_time
	outer apply sys.dm_exec_sql_text( R.sql_handle ) as EX
	cross apply (
		select 
			S.scheduler_id as 'data()' 
		From sys.dm_os_tasks T join sys.dm_os_schedulers S on S.scheduler_id = T.scheduler_id
		WHERE T.session_id = R.session_id AND T.request_id = R.request_id
		FOR XML PATH('')
	) S(sched)
	cross apply (
		select
			TaskCount = count(DISTINCT T.task_address)
			,UniqueSched = COUNT(DISTINCT S.scheduler_id)
		From sys.dm_os_tasks T join sys.dm_os_schedulers S on S.scheduler_id = T.scheduler_id
		WHERE T.session_id = R.session_id AND T.request_id = R.request_id
	) SC
	left join sys.dm_exec_connections CN
		ON CN.session_id = R.session_id
	cross apply (
	select
		-- SIM! Se você já fuçou o código da whoisactive, deve ter visto isso lá, e foi de lá mesmo que eu peguei!
		-- Simplesmente pq isso aqui funciona bem pra extrair o trecho da procedure e converter pra um XML clicável no SSMS.
		[processing-instruction(q)] = (
		REPLACE
		(
		REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
		REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
		REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
		CONVERT
		(
		NVARCHAR(MAX),
		SUBSTRING(EX.text,R.statement_start_offset/2 + 1, ISNULL((NULLIF(R.statement_end_offset,-1) - R.statement_start_offset)/2 + 1,LEN(EX.text)) ) COLLATE Latin1_General_Bin2
		),
		NCHAR(31),N'?'),NCHAR(30),N'?'),NCHAR(29),N'?'),NCHAR(28),N'?'),NCHAR(27),N'?'),NCHAR(26),N'?'),NCHAR(25),N'?'),NCHAR(24),N'?'),NCHAR(23),N'?'),NCHAR(22),N'?'),
		NCHAR(21),N'?'),NCHAR(20),N'?'),NCHAR(19),N'?'),NCHAR(18),N'?'),NCHAR(17),N'?'),NCHAR(16),N'?'),NCHAR(15),N'?'),NCHAR(14),N'?'),NCHAR(12),N'?'),
		NCHAR(11),N'?'),NCHAR(8),N'?'),NCHAR(7),N'?'),NCHAR(6),N'?'),NCHAR(5),N'?'),NCHAR(4),N'?'),NCHAR(3),N'?'),NCHAR(2),N'?'),NCHAR(1),N'?'),
		NCHAR(0),
		N''
		)
		)
		for xml path(''),TYPE
	) q(qx)
WHERE
	--> Aqui estou tirando minha própria sessão do resultado, pois dificilmente essa query vai consumir algo significativo!
	--> Se você quiser comentar por desencargo, fique a vontade!
	R.session_id != @@SPID
	and
	S.sched IS NOT NULL



--> insere o resultado se foi solicitado!
--> É um simples insert dinamicl... Se voce mexeu na estrutura, recomendo renomear e deixar ele criar um nova!
if nullif(@InsertTable,'') is not null 
begin
	declare @sql nvarchar(max)
	IF OBJECT_ID(@InsertTable) IS NULL
	begin
	set @sql = 'SELECT * INTO '+@InsertTable+' FROM #CPUTotal'
	end
	ELSE
	set @sql = 'INSERT INTO '+@InsertTable+' SELECT * FROM #CPUTotal'

	exec(@sql)
end


--> Traz o resultado ordena pelo consumo de CPU no intervalo!
--> Note aqui como eu não considero o total da vida inteira, mas apenas o quanto foi gasto no intervao coletado...
--> Isso é a mágica que vai colocar as prováveis queries já nos primeiros resultados!
SELECT * FROM #CPUtotal
where CPUIntervalo > 0
ORDER BY
CPUIntervalo desc


--> E por fim, aqui vamos gerar uma pequena imitação do gerenciaro de tarefas!
--> Isso aqui foi uma curiosidade minha pra saber se ia bater com o task manager do windows, e acabei deixando!
--> As vezes bate, as vezes não... Tem muito mais variáveis envolvidas, mas deixei para complementar!
select 
	--> Tempo Médio de cpu, considerando o máximo de CPU possível que pode ser gasto!
	 AvgCpuPercent = c.TotalCPU*100/(si.cpu_count*1000)
	,TotalCPU
	,EstCpuCnt = TotalCPU/1000 --> Não lembro minha intenção qui, mas acho que era Uma estimativa de padaria, o quanto cada cpu estaria gastando...

	--> Esse é legal: Aqui é o limite maximo teórico que uma queyr pode consumir no intervalo coletado
	-- Exemplo: Se o intervalo da foto foi 1 segundo, e eu tenho 4 cpus, então o máximo que uma query pode consumir, considerando que ela pode rodar nas 4 ao mesmo tempo, seira 4000 ms
	--> Isto é, eu nunca veria um CPUIntervalo > MaxCPUTime
	,MaxCPUTime = (si.cpu_count*MaxIntervalo) 
	,TotalCpu = si.cpu_count
From ( SELECT TotalCPU = SUM(CPUIntervalo*1.), MaxIntervalo = MAX(Intervalo) from #CPUtotal )
c cross join sys.dm_os_sys_info si



/*#info 

MAIS SOBRE O CONSUMO DE CPU

		Por anos, eu aprendi que quando o 100% de CPU bate em um servidor SQL, é preocupanete!
		Meus primeiros anos como DBA foi respondendo a alertas do Nagios (ou Zabbkix) quando a CPU batia 100% por alguns minutos!
		Por anos, eu me perguntei: o que é o 100% de CPU?

		A resposta pra essa pergunta é esse script.
		Desvendar o que é o 100% mostrado no gerenciador de tarefas do Windows, e nesses alertas, me ajudou a entender como achar queries que estão causando problemas de CPU.

		O 100% de CPU é baseado em uma foto: Tire uma foto de tudo que tá na cpu agora, espere 1 segundo, e tire outra!
		Faça: Foto2 - Foto1, e você terá quais processos mais consumiram a CPU nesse intervalinho de 1 segundo.
		Isso é basicamente, o que o seu Gerenciador de Tarefas faz!

		Trazendo isso pra queries, se eu tirar um foto do que está rodando, esperar 1 segundo,e  tirar outra foto, consigo saber quais request estão consumindo CPU naquele momento.
		Isso é o que chamamos de "Delta": a diferença em um intervalo de tempo.

		Mas Rodrigo, porque não apenas usar a coluna cpu_time da sys.dm_exec_requests?
		Simples: Isso é um valor cumulativo! Seu request pode ter 1 milhão de segundos de CPU, mas pode ter gasto isso semana passada, e, 
		se a query está parada rodando até hoje, por mais que mostre 1 milhão de cpu, não é ela a culpada nesse momento.

		Isso é uma das maiores fontes de confusões e ao longo da minha carreira como DBA eu fui levado a APENAS confiar na cpu_time.  
		Eu digo apenas, pq ainda sim, ela é útil... Mas, se eu recebo um alerta de CPU agora, o que mais me interessa é o delta, pois é ele quem vai me ajudar a mostrar o cenário de agora.

		Essa query é isso: Captura as informações do request, aguarda 1 segundo, e captura novamente.
		Cada captura eu guardo em uma temp table.  Após isso, eu comparo as duas capturas e mostro uma série de informações!


		Isso é incrivelmente preciso com queries que rodam por mais de 1 segundo.

		Para ambientes em que a pressão vem de queries que rodam em menos de 1 segundo, este delta não vai pegar direto,
		pois as queries estão começando e terminando antes ou depois das coletas. Para estes casos, tem outros scripts nessa pasta, ou, você deve usar um
		Query Store, Profile, extended events...

		Mas, você vai conseguir matar uns 90% dos seus problemas de CPU com essa query e chegar na raiz do problema.
		Uma dica valiosa: se o seu sql está em 100% (confirmado no gerenciador de tarefas que é o processo dessa instancia mesmo), e essa query nao trouxe nada que justifique,
		então muito provavelmente você tem um caso que está sendo causado por uma alta demandas de queries pequenas...
		Então, pra pegar essas queries pequenas, vai precisar usar algo melhor, como um extened events ou query store.

		Há uma outra query nesse diretorio que também pode te ajudar, é uma query que consutla a sys.dm_exec_query_stats da query que rodou nos ultimos segundos.
		Ela pode ajudar, mas, depende do nível caótico do ambiente!
		Eu gosto de chamar esse cenários "otimização quântica", pois são geralmente muitas queries que rodam em uma escala de tempo muito pequena, mas, na soma, acabam impactando sua instância.
		São casos bem mais difíceis de pegar, mas são muito divertidos =)

		uma outra coisa importante que você deve tomar cuidaod é que em um cenário onde TODAS os schedulers estão ocupados, a execução desta query vai ser afetada.
		Então, isso também pode acabar influenciando um pouco nos números.
		nesses cenários, se possível, rode com um DAC, especialmente se essa query demorar muito pra retornar... pode ajudar!


		Revendo essa query lembrei de uma série posts em que falei um pouco mais sobre isso
		ESSA SÉRIE FICOU MUITO LEGAL (as imagens são bem bacanas!!!)
		https://thesqltimes.com/blog/2019/02/20/desempenho-do-processador-x-desempenho-do-sql-server-parte-1/

		eu já falei disso bastante em alguns SQL Saturdays e outras palestras e vou encontrar os materais para publicar depois!
*/