/*#info 
	# Autor 
		Rodrigo Ribeiro Gomes 
		
	# Descricao 
		Uma proc que criei no apssado para coletar informacoes de waits.
		NEssa epoca nem sonhava em ter uma ferramenta como o Power Alerts, que ja tem esse tipo de coisa.
		Mas fica ai como ideia original

*/

/********************************************************************************************************************************************
	Descrição
		Realiza a coleta dos dados da tabela 'sys.dm_os_wait_stats' em um intervado de tempos escolhido.
	Dependências
		Tabelas/Views
			#1 - sys.dm_os_wait_stats
		Funções/Procedures
			#1 - dbo.Split
		Referências
			Nenhuma
		Comandos
			Nenhuma
			
	Versões suportadas
		SQL Server 2005
		SQL Server 2008 (inclusive R2)
		
	Parâmetros
		@TempoDeColeta
			É o tempo em milisegundos de coleta. Esse tempo que a procedure ficará rodando realizando a coleta.
			Este tempo pode variar dependendo se alguma operação no servidor está causando algum lock.
			O padrão é 1000 milésimos (1 segundo).
			
		@IntervaloColeta
			Esse intervalor deve ser especificado no formato 'hh:mm:ss', e indica o tempo em que a procedure irá
			esperar para iniciar um nova coleta, se o tempo de coleta ainda não tiver sido atinigo.
			Padrão é 2 segundos.
			
		@ListaWaits
			A lista de waits que deverão ser incluídos, ou excluídos da coleta.
			Cada item da lista deve estar separado por ',' (vírgula).
			Para cada item, pode se especificar caracteres coringas, como '%'.
			Se um item começa com um '-' (traço), então este item será excluído da coleta. Os itens a serem excluídos tem uma precedência
			maior do que os itens que devems ser incluídos.
			Algumas variáveis são permitidas:
				$[TODOS]	- Indica que todos os waits irão ser incluídos.
				
			Se esta variável for NULL ou '', então estes waits serão excluídos:
				LAZYWRITER_SLEEP,RESOURCE_QUEUE,SLEEP_TASK,SLEEP_SYSTEMTASK,SQLTRACE_BUFFER_FLUSH,WAITFOR,LOGMGR_QUEUE,CHECKPOINT_QUEUE
				REQUEST_FOR_DEADLOCK_SEARCH,XE_TIMER_EVENT,BROKER_TO_FLUSH,BROKER_TASK_STOP,CLR_MANUAL_EVENT
				CLR_AUTO_EVENT,DISPATCHER_QUEUE_SEMAPHORE,FT_IFTS_SCHEDULER_IDLE_WAIT,XE_DISPATCHER_WAIT,XE_DISPATCHER_JOIN
				SQLTRACE_INCREMENTAL_FLUSH_SLEEP
				
			O padrão é NULL.
				
		@TabelaDeDestino
			É o objeto, onde os dados da coleta serão salvos. É possível especificar o objeto no formato banco.schema.tabela.
			Se o objeto não existir, ele será criado.
			Se este parâmetro for NULL ou for '', então os dados coletados serão exibidos.
			O padrão é NULL.
			
		@DebugMode
			Exibe opções calculadas dentro da procedure para fins de debug.
			Nenhuma coleta é realizada.
			O padrão é 0 (desativado).
				

		HISTÓRICO
		Desenvolvedor				Abreviação			Data			Descrição
		Rodrigo Ribeiro Gomes			--				28/11/2011		Criação da FUNÇÃO.
********************************************************************************************************************************************/
IF OBJECT_ID('dbo.ColetarInfoWait') IS NOT NULL
	DROP PROCEDURE dbo.ColetarInfoWait;
GO

CREATE PROCEDURE dbo.ColetarInfoWait
(
	 @TempoDeColeta		int				= 1000
	,@IntervaloColeta	varchar(15)		= '00:00:02'
	,@ListaWaits		varchar(max)	= NULL
	,@TabelaDeDestino	varchar(200)	= NULL
	,@DebugMode			bit				= 0
)
AS
--> Parâmetros para teste
--DECLARE
--	 @TempoDeColeta		int
--	,@IntervaloColeta	varchar(15)
--	,@ListaWaits		varchar(max)
--	,@TabelaDeDestino	varchar(200)
--	,@DebugMode			bit
	
--SET @TempoDeColeta		= 10000;
--SET @IntervaloColeta	= '00:00:02'
--SET @ListaWaits			= '';
--SET @TabelaDeDestino	= 'tempdb.dbo.ColetaWaits'
--SET @DebugMode			= 0

IF OBJECT_ID('tempdb..#Waits') IS NOT NULL
	DROP TABLE #Waits;
	
DECLARE
	 @FiltroWaits TABLE(WaitType varchar(max))
;

DECLARE
	 @TempoIni		datetime
	,@TempoFinal	datetime
	,@SQLCmd		varchar(600)
;

SET NOCOUNT ON;

--> Validando os valores dos parâmetros.
IF @TempoDeColeta IS NULL OR @TempoDeColeta <= 0
	SET @TempoDeColeta = 1000;			--> Default de 1 Segundo.
IF @IntervaloColeta IS NULL
	SET @IntervaloColeta = '00:00:01';	--> Espera 1 segundo.
	
IF @ListaWaits IS NULL OR LEN(@ListaWaits) = 0
	SET @ListaWaits = '$[TODOS],-CLR_SEMAPHORE,-LAZYWRITER_SLEEP,-RESOURCE_QUEUE,-SLEEP_TASK,-SLEEP_SYSTEMTASK,-SQLTRACE_BUFFER_FLUSH,-WAITFOR,-LOGMGR_QUEUE,-CHECKPOINT_QUEUE'+
					',-REQUEST_FOR_DEADLOCK_SEARCH,-XE_TIMER_EVENT,-BROKER_TO_FLUSH,-BROKER_TASK_STOP,-CLR_MANUAL_EVENT'+
					',-CLR_AUTO_EVENT,-DISPATCHER_QUEUE_SEMAPHORE,-FT_IFTS_SCHEDULER_IDLE_WAIT,-XE_DISPATCHER_WAIT,-XE_DISPATCHER_JOIN,-SQLTRACE_INCREMENTAL_FLUSH_SLEEP'
;

/**
	Este trecho é responsável por incluir os waits que atende aos filtros da lista informada pelo usuário.
	Ele utiliza função Split para converter cada item da lista, em uma linha, para facilitar as operações com os itens.
**/
WITH FiltrosWaits AS
(
	--> Convertendo a string em lista!
	SELECT
		RTRIM(LTRIM(S.Item)) as WaitType
	FROM
		dbo.Split(@ListaWaits,',') S
)
,WaitsIncluir AS (
	--> Incluindo os waits que satistafazem os criterios.
	SELECT DISTINCT
		WS.wait_type as WaitType
	FROM
		sys.dm_os_wait_stats WS WITH(NOLOCK)
	WHERE
		EXISTS(SELECT 
					* 
				FROM 
					FiltrosWaits FW 
				WHERE 
					FW.WaitType = '$[TODOS]'
					OR
					WS.wait_type like FW.WaitType 
			)
)
INSERT INTO
	@FiltroWaits(WaitType)
SELECT
	WI.WaitType
FROM
	WaitsIncluir WI
WHERE
	--> Elimina os waits que passam no critério de exclusão.
	NOT EXISTS (SELECT * FROM FiltrosWaits FW WHERE LEFT(FW.WaitType,1) = '-' AND WI.WaitType LIKE RIGHT(FW.WaitType,LEN(FW.WaitType)-1) )

--> Criando a estrutura da tabela temporária com os waits a serem coletados.
SELECT
	*,GETDATE() as DataColeta
INTO
	#Waits
FROM
	sys.dm_os_wait_stats WS
WHERE
	1 = 2
	
SET @TempoIni = CURRENT_TIMESTAMP;
--> A data obtida aqui é data em que o loop deverá encerrar. Totalizando o tempo escolhido pelo usuário
SET @TempoFinal	= DATEADD(ms,@TempoDeColeta,@TempoIni);

IF @DebugMode = 1 BEGIN
	SELECT 'DEBUG ATIVO'

	SELECT * FROM @FiltroWaits ORDER BY WaitType;
	
	SELECT 'Delay',CONVERT(sql_variant,@IntervaloColeta)
	UNION ALL
	SELECT 'Tempo final',CONVERT(sql_variant,@TempoFinal)
	UNION ALL
	SELECT 'Tempo inicial',CONVERT(sql_variant,@TempoIni)
	UNION ALL
	SELECT 'Tempo total em milisegundos',CONVERT(sql_variant,DATEDIFF(ms,@TempoIni,@TempoFinal))
	
	RETURN;
END
	
--> Enquanto o tempo decorrido for menor ou igual ao tempo especificado...
WHILE CURRENT_TIMESTAMP <= @TempoFinal
BEGIN

	RAISERROR('Inserindo dados... ',0,0) WITH NOWAIT;

	INSERT INTO
		#Waits
	SELECT DISTINCT
		 *
		,getDate()
	FROM
		sys.dm_os_wait_stats WS WITH(NOLOCK)
	WHERE
		WS.wait_type IN (SELECT FW.WaitType FROM @FiltroWaits FW)
		
	RAISERROR('Inserido %d linhas',0,0,@@ROWCOUNT) WITH NOWAIT;
	RAISERROR('Aguardando delay de "%s"... ',0,0,@IntervaloColeta) WITH NOWAIT;
	--> Esperando o tempo de coleta.
	WAITFOR DELAY @IntervaloColeta;
END


IF @TabelaDeDestino IS NULL OR (RTRIM(LTRIM(@TabelaDeDestino))) = ''
		SELECT * FROM #Waits ORDER BY wait_type
ELSE BEGIN
	SET @SQLCmd = '
	
		IF OBJECT_ID('+QUOTENAME(@TabelaDeDestino,CHAR(0x27))+') IS NULL BEGIN
			PRINT '+QUOTENAME('A tabela "'+@TabelaDeDestino+'" não existia e foi criada!',CHAR(0x27))+'
		
			SELECT 
				*
			INTO
				'+@TabelaDeDestino+' 
			FROM 
				#Waits 	
		END ELSE
			INSERT INTO
				'+@TabelaDeDestino+'
			SELECT 
				* 
			FROM 
				#Waits
	'
	
	EXEC(@SQLCmd)
END
GO