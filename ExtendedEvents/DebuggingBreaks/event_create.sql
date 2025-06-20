/*#info 

	# Autor 
		Rodrigo Ribeiro Gomes 
		
	# Detalhes 
		XE que faz o SQL parar no debugger. 
		Eu uso esse quando quero estudar algo internals do SQL...
		Você pode adaptar, trocando o evento...
		
		a ideia é ver a callstack, ou o ponto em que o sql está, qnd determinado evento ocorre.
		Eu filtro pela context_info tendo um valor especifico, assi eu controle em qual sessão vou parar no debugger.
		
		Obviamente, você deve ter o windbg plugado na instância.
		Quando o evento ocorre,o sql dispara a exception com o codigo c0730003 (checado até o sql 2025).
		
		
		Mas, o melhor jeito de saber é attachr o windbg no processo da usa instância, deixar ele rodar (comando g), criar o xe abaixo e executar esse comando em uma nova sessão:
			set context_info 0xDeadC0de;
			select 1
			
		Com isso, você vai ver na tela do seu windbg uma mensagem parecida com essa:
			Unknown exception - code c0730003 (first chance)
		
			Pegueo valor na frente de "code", e crie um breakpoint nela:
			
			sxe c0730003
		
		Pronto, com isso, da próxiam vez que rodar algo na sessão onde ativou o context 0xDeadC0de, ele vai parar no windbg!
		
		NEM PRECISO AVISAR QUE VOCÊ NUNCA DEVE FAZER ISSO EM PRODUÇÃO, NÉ?
*/


-- alter event session [Debugging-BatchStarting] on server state = start

CREATE EVENT SESSION 
	[Debugging-BatchStarting] 
ON 
	SERVER 
ADD EVENT sqlserver.sql_batch_starting(

		ACTION(
			package0.debug_break
		)
		WHERE (
				-- Compares the session context_info!
				package0.equal_binary_data(sqlserver.context_info, 0xDeadC0de )
			)
	)

WITH (
	MAX_MEMORY=4096 KB
	,EVENT_RETENTION_MODE=ALLOW_SINGLE_EVENT_LOSS
	,MAX_DISPATCH_LATENCY=30 SECONDS
	,MAX_EVENT_SIZE=0 KB
	,MEMORY_PARTITION_MODE=NONE
	,TRACK_CAUSALITY=OFF
	,STARTUP_STATE=OFF
)