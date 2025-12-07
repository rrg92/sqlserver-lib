/*#info 

	# Autor 
		Rodrigo Ribeiro Gomes 

	# Descrição 
		Esse provavelmente foi um dos scritps que mais usei em toda a minha história...
		problema muito comum nos ambientes SQL: Sessões sleeping com transação ativa...
		Clássico problema que causa locks, travamentos...

		Muitos pensam que isso é um probelma do SQL... Mas, é mais comum ser a falta de conhecimento de como o controle tranacional no sql funciona...
		Muito código de app que deixa a transação aberta, por algum erro que coorreu, falha de lógica, processamento que está sendo feito em outro serviço, etc...

		Esse script te ajuda a encontrar as sessões que estão com transações abertas, mas que não estão fazenod absolutamente nada...
		Por exemplo, em um new query faça isso:	
			BEGIN TRAN

		E ele vai aparecer no resultado desse select...
		E o legal é que o script traz se tem alguma sessão sendo bloqueada por essa que você abri... (nesse exemplo simpes que você fez, vai ser 0)...
		Ele também já traz o comando de kill pra você matar a sessão...

		Mas, sabe qual é a verdade? Ficar usando kill pra resolver, você não está resolvendo nada... Só mitigando... esse problema vai virar algo maior um dia...
		Pode estar causando outras dores pros seus usuários... 
		Pode estar fazendo alguém ai do seu sistema perder dados, e ter que refazer trabalho, causando incosistências que você não consegue explicar (confirmou na tela, mas no banco sumiu)...

		Como resolver isso de vez?
			- Junta com o seu time de dev, isola essa sessões, e descobre o porque as transações estão ficando abertas...
				- Pode ser que esteja dando um erro de chave, e a aplicação recebe o exception, e não fecha a conexão... e deixa a transação aberta...
				- Pode ser que a app esteja modficando algo, e antes de comitar no banco, foi lá em outro serviço externo, que está demorando pra responder e enquanto isso segurando a transação ativa no banco!
			
			- Isso pode ser um probelma no seu SQL SErver?
				Provavelmente não, já que uma sessão sleeping significa que o sql não tá fazneod mais nada e só aguardando sua app fazer o commit ou rollback...
				Mas não significa que o sql pode não ter alguma culpa...
				Pode ser que ele esteja dando algum erro (permissão, chave, etc.) e sua aplicação não trata o erro direito e esquece a conexão aberta...
					Culpa do sql + culpa da lógica errada na sua app quando o banco dá algum erro...

				Pode ser que o sql esteja lento, sua aplicação deu timeout, e ai com o erro de timeout, não tratou o erro e esqueceu a conexão aberta...
					2 problemas aqui:
						1 - sua aplicação não ta tratando a lógica de erro correta.
						2 - sql lento fazendo sua aplicação dá erro.

					Precisa resolver os 2... Se resolver o 1, o erro 2 vai aparecer depois.


				na maioria dos casos que peguei isso, era problema na app...
				foi um caso ou ouro com essa culpa compartilhada.

				Em todo o caso, esquecer uma transação aberta não tem muito que fazer do lado do nbanco a não ser o kill...
				Mas isso é um problema pra você e pro seu negócio... fazer kill em sessão = rollback de tudo que ela fez.
				Se suia aplicação ta esquecendo a sessã aberta e o DBa tiver que resolver com kill, você ta perdendo algum trabalho que pode ter sido feito legitiamente...



	DITO TUDO ISSO, use esse script com responsabilidade... mitigação apenas e vá atrás do problema na raiz!
	Precisa de ajuda com isso? comercial@powertuning.com.br --> Muitos DBAs SQL disponíveis pra te ajudar com isso.
*/



SELECT
	 'KILL '+CONVERT(varchar(30),s.session_id) as ComandoKill
	,S.session_id
	,S.login_name
	,S.program_name
	,S.host_name
	,S.last_request_start_time
	,DATEDIFF(ss,last_request_start_time,CURRENT_TIMESTAMP) as Tempo
	,CONVERT(bit,B.Total) as TemSessaoBloqueada
	,TST.transaction_id
FROM
	sys.dm_exec_sessions S 
	INNER JOIN
	sys.dm_tran_session_transactions TST
		ON TST.session_id = s.session_id
	OUTER APPLY
	(
		select COUNT(*) as Total from sys.dm_exec_requests R WHERE R.blocking_session_id = S.session_id
	) AS B
WHERE
	S.status = 'sleeping'

ORDER BY
	TemSessaoBloqueada DESC