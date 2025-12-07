/*#info
	# autor 
		Rodrigo Ribeiro Gomes 

	# descricao 
		Demo que construir para entender melhor algumas coisas sobre locks e hints de locks
		Eu fiz um pequeno teste novo e ajustei alguns comentários mas acho que da pra melhroar mais depois.
		Depois que construir os scritps passei a entender muito melhor algumas hints o porque do nome e comportamento!
*/

--> Criando o BD de teste ...
USE master
GO

IF DB_ID('TesteLockDB') IS NOT NULL 
	DROP DATABASE TesteLockDB;
GO

CREATE DATABASE TesteLockDB
GO

USE TesteLockDB
GO

--> Uma Tabelinha pra brincadeira ...
	IF object_id('TesteLock') IS NOT NULL
		DROP TABLE  TesteLock;
	GO
	CREATE TABLE TesteLock( numero int );
--> Alguns valores ...
	DECLARE
		@n int
	SET @n = 1
	WHILE @n <= 1000
	BEGIN
		INSERT INTO TesteLock VALUES(@n)
		SET @n = @n + 1
	END

--> Vendo a tabela
	SELECT * FROM TesteLock;

--> Vamos aos Locks ...

--> O mais simples ... Shared ... 
BEGIN TRAN
	--> Como o shared lock libera o bloquio assim que ler a linha, 
	-- então vamos forçá-lo a segurar até o fim da transação
	SELECT * FROM TesteLock WITH ( HOLDLOCK ); --> Ver em duas sessões (abrir duas sessoes e rodar esse begin tran e select)
	
	--> Ver o Lock em outra conexão usando sp_lock | sys.dm_tran_locks
	--> OBS.: A query abaixo é simplesmente pra vermos ... nada de fazer essa porcaria em producao hein...
	--> vou chamar ela de queryzinha
	/*
		USE TesteLockDB
		GO

		select 
			 tl.resource_type
			,tl.resource_subtype
			,tl.resource_description
			,tl.request_mode
			,tl.request_status
			,tl.request_session_id
			,tl.request_request_id
			,tl.resource_associated_entity_id
			,CASE 
				WHEN tl.resource_type in ('OBJECT') then OBJECT_NAME( tl.resource_associated_entity_id )
				ELSE object_name(p.object_id)
			END
		from 
			sys.dm_tran_locks	tl
			left join
			sys.allocation_units AU ON AU.allocation_unit_id = tl.resource_associated_entity_id	
			LEFT JOIN
			sys.partitions		p on	CASE 
										WHEN tl.resource_type in ('ALLOCATION_UNIT') THEN p.partition_id
											ELSE p.hobt_id
										END = 
										CASE 
										WHEN tl.resource_type in ('ALLOCATION_UNIT') THEN AU.container_id
											ELSE tl.resource_associated_entity_id	
										END
		where
				resource_type <> 'DATABASE'
				and db_name(resource_database_id)  = 'TesteLockDB'
				--and request_session_id = 52
		ORDER BY
				tl.resource_type
			,tl.resource_description

	*/

	--> De acordo com a query acima, as duas sessoes tao com um shared lock
	
	--> Comitando a segunda sessão ...
	--> Pelo script, sumiu  o lock ... :D
	--> Comitando Esta
	--> Sumiram...
COMMIT TRAN

--> Agora o EXCLUSIVE :D...
BEGIN TRAN
	UPDATE
		TesteLock
	SET
		numero = 100

	-- em outra sessao, rodar:
	--SELECT * FROM TesteLock where numero = 100

	
	--> O SELECT da segunda conexão tá demorado... porquê ?
	--> Vamos olhar a queryzinha ...
	
	--> Hum ... Muitas linhas ... muitos pedidos de bloqueios ... analisemos ...
	/*									Sessão( Vou trocar os ids, porque pode variar )
		PAGE		1:109	IX	GRANT	Esta
		PAGE		1:93	IS	GRANT	Outra
		PAGE		1:93	IX	GRANT	Esta
		
		Esta conseuiu um bloqueio IX na página 109, só ela está pedindo...
		Esta pediu um Intent Exclusive na 93 ...
		Outra pediu um Intent Shared na 93 e também consegiu, pois sao compativeis ( olhar a tabelinha )
		
		#### Tabelinha do MSDN: http://msdn.microsoft.com/en-us/library/ms186396(v=SQL.90).aspx
		
		Como esta disparou o lock primeiro, ela tem uma série de EXCLUSIVES nos RIDS ...
		E temos este trecho:
		
		RID		1:93:0	X	GRANT	Esta
		RID		1:93:0	S	WAIT	Outra
		
		Esta tem um Exclusive na linha 1:93:0 ...
		A outra tem que esperar por um shared, pois o S e o X são incompatíveis ... massaaa
		
		Curiosidade...
		Vamos usar hints e mecher com niveis de isolamento pra ver o comportamento
		da outra ...
		
		Cancelando a outra ...
		Vamos so ver a query dos locks pra ver o que aconteceu ...
		O Id da outra sessão nao está mais lá ...
		
		Já usamo uma hint que foi  HOLDLOCK ... Ela simplismente força o bloquei inteiro da tabela
		até enquanto a transação nao termina ...
		
		Vamos tentar ler usando NOLOCK ... troca:
			SELECT * FROM TesteLock with(nolock) where numero = 100

		Hum ... Agora não demorou ... e conseuigmos ler ...
		
		Na queryzinha nao apareceu nada ... pois usamos somente o NOLOCK...
		Vamos pedir pra ele segurar o lock tbm ... 
		nA OUTRA SESSÃO:
			begin tran
			SELECT * FROM TesteLock WITH ( HOLDLOCK, NOLOCK );
		
		Olha só ... 
		/*
			Msg 1047, Level 15, State 1, Line 2
			Conflicting locking hints specified.
		*/
		Usamos hints incompatíves ... 
		Como a gente quer segurar o lock, sendo que o NOLOCK é pra não fazer isso ...
		:s ...
		NOLOCK = READUNCOMMITTED
		
		Como é rápido ele pega shared, a gente nao consegue ver na query ...
		Ler página suja pode causar efeitos indesejáveis ...
		
		E se pudessemos pular as páginas sujas ?
		
		READPAST
		SELECT * FROM TesteLock WITH (READPAST);
		
		Olha ... Nenhuma linha ...
		READPAST não lê as linhas bloqueadas ...
		Como estamos atualizando tudo ... Não leu nenhuma ...
		Vamos ver se conseguimos ver que tipo de lock ele pegou colocando um HOLDLOCK
			SELECT * FROM TesteLock WITH (READPAST,HOLDLOCK);
		
			Msg 650, Level 16, State 1, Line 1
			You can only specify the READPAST lock in the READ COMMITTED or REPEATABLE READ isolation levels.
		
		Sem comentários... Já já tentaremos com esse tal de  REPEATABLE READ
		
		Pra demonstrar melhoor vamos "ROLLBACKizar" e refazer o UPDATE ...


		NA sessão atual:
			ROLLBACK
			BEGIN TRANSACTION
				UPDATE
					TesteLock
				SET
					numero = 100
				WHERE
					numero%2 = 0 --> Só os pares ( Jamais usar assim ... nao irá usar indices ... )
					
		Na outra:
				SELECT * FROM TesteLock WITH  ( READPAST );
				1,3,5,7 ... Só leus os ímpares ... bonito isso.
				
		Agora cancela tudo (pra voltar os valores originais)
				--Voltemos á transição anterior
			ROLLBACK
			
		-- Refaçamos o update com o BEGIN...
		-- Vamos ver o que acontece usando NIVEIS DE ISOLAÇÃO ...
		
		-- READ_COMMITED		- Padrão - Ler so o que foi comitado
		-- READ_UNCOMMITTED		- Causa o mesmo efeito do NOLOCK
	*/
ROLLBACK

--> Agora vamos ver um pouco do REPEATABLE READ ...
--> O nível de isolação e o hint faz a mesma coisa ...
--> PS: Nível de isolação afeta toda a transação e o hint só aquele comando ...


BEGIN TRAN
	
	-- va acompanhando na queryzinha!
	--> Rodar sem fazer o commit  (em outra sessao)
	SELECT * FROM TesteLock WITH( HOLDLOCK )


	--> Com o HOLDLOCK ele segura o lock na tabela ...
COMMIT


begin tran
	SELECT * FROM TesteLock WITH( REPEATABLEREAD )
	--> Hummm ... O REPEATABLEREAD tá mantendo o lock em cada linha ...
	--> Rodando a de baixo sem commitar ...
commit


begin tran
	--> Vamos ler uma faixa ...
	SELECT * FROM TesteLock  WITH ( HOLDLOCK ) WHERE numero BETWEEN 1 and 10

	-- aqui manteve o S na tabelainteira, mesmo lendo um afaixa!
commit 

begin tran
	SELECT * FROM TesteLock  WITH ( REPEATABLEREAD ) WHERE numero BETWEEN 1 and 10
	--> Hum ... Manteve o lock so nas 10 linhas ... lindo ...
COMMIT


	--> COMMIT
	--> Dúvida: Quando o UPDATE é em uma faixa,ele faz a mesma coisa que o REPEATABLE READ ?
begin tran
	UPDATE TesteLock  SET numero = numero WHERE numero BETWEEN 1 and 10

	--> veja na queryzinha

ROLLBACK
	--> R: SIM...


-- E se usar a hint ???
BEGIN TRAN
	UPDATE TesteLock WITH( REPEATABLEREAD )  SET numero = numero WHERE numero BETWEEN 1 and 10

		--> veja na queryzinha

ROLLBACK
	 -- mesma coisa!
	
--> DETALHE: Agora acho que podemos ver o tipo de lock quando usamos o READPAST
-- rodar em outra: 
begin tran
	UPDATE TesteLock SET numero = numero+8000 WHERE numero between 1 and 3
-- rollback
		
BEGIN TRAN
	SELECT * FROM TesteLock WITH ( READPAST,REPEATABLEREAD ) WHERE numero between 1 and 5
ROLLBACK
*/ --> Pela queryziniha ele pegou um shared .... legal .. voltemos ...
	
	
--> Brincadeira: Bloquear uma faixa e em outra conexao tentar usar o UPDATE em outra faixa ...
begin tran
	SELECT * FROM TesteLock  WITH ( REPEATABLEREAD ) WHERE numero BETWEEN 1 and 10

	--> Tentar o UPDATE em outras faixas :
	begin tran
		UPDATE TesteLock SET numero = numero+8000 WHERE numero between 11 and 12
	rollback
	/*
		Esta  - 1 a 10   
		Outra - 11 e 12
		Esta bloqueiou somente 1 a 10...
		A outra consegiu o lock na outra faixa ... A outra consegiu o lock entre 11 e 12
	*/
rollback
		

begin tran
		-- vamos agora confliar as faixas:
		SELECT * FROM TesteLock WITH ( REPEATABLEREAD ) WHERE numero BETWEEN 5 and 13
		
		
		--> Agora tenta um UPDATE entre 1 e 10, em outra conexao e volta aqui ...
		begin tran
			UPDATE TesteLock SET numero = numero+8000 WHERE numero between 1 and 10
		rollback

ROLLBACK

--> Utilidade do REPEATABLE READ:
BEGIN TRAN
	--> Vamos ler o que tem uma determinada faixa ...
	SELECT * FROM TesteLock WHERE numero BETWEEN 1 and 5



	--> Em outra conexao vamos atualizar o valor 5 para -100
	-- UPDATE TesteLock SET numero = -100 WHERE numero = 5



	--> E suponhamos que outro SELECT precisasse ser feito na mesma transação... e naum tivesse conhecimento do update
	SELECT * FROM TesteLock WHERE numero BETWEEN 1 and 5

	--> Se dependessemos do numero de linhas ou do valor 5 para esta transacao
	--> Teriamos inconsistencia e erros na nossa regra de negócio ...
commit;

	--> Como solucionar ???
begin tran;
	SELECT * FROM TesteLock WITH( REPEATABLEREAD ) WHERE numero BETWEEN 1 and 5
	--> Agora tenta atualizar o 3 ...
	UPDATE TesteLock SET numero = -100 WHERE numero = 3

	--> Tcharam ... Block ...
	SELECT * FROM TesteLock WITH( REPEATABLEREAD ) WHERE numero BETWEEN 1 and 5
	
	--> E se for feito um INSERT ???
	--> Outra conexão: INSERT INTO TesteLock VALUES( 1 )
	SELECT * FROM TesteLock WITH( REPEATABLEREAD ) WHERE numero BETWEEN 1 and 5
	--> Droga ... REPEATABLEREAD não previne INSERTS ...
ROLLBACK

--> E como a gente resolve os problemas de INSERT ????
BEGIN TRAN
	--> Vamos tentar com um HOLDLOCK
	SELECT * FROM TesteLock  WITH ( HOLDLOCK ) WHERE numero BETWEEN 1 and 10
	--> INSERT
	--> Funfou ^^ ... Mas tivemos que pegar um bloqueio inteiro da tabela ...
	--> Isso impede outros UPDATES em faixas que a gente nao esteja utilizando ...
	
	--> Merda ... como prevenir um INSERT numa faixa que a gente tá utilizando ????
	-- Humm ... NOLOCK ? claro que nao, esse ai que nao bloquia msm ...
	-- READ COMMITED ??? So afeta a leitura desta seção ...
	-- READ UNCOMMITED ? =NOLOCK esperto...
	
	--> Bom pra responder isso... vamos so ver que tipo de lock um delete pega ...
	DELETE FROM TesteLock WHERE numero = 1
	--> EX :D
	-- E o INSERT ??
	INSERT INTO TesteLock VALUES( 5888 )
	--> Exclusive na nova linha ...

ROLLBACK


	
	-- Nesse exemplo do INSERT, conhecemos a famosa leitura fantasma.
	-- Para prevenir INSERTs, usaremos o SERIALIZABLE ... hááá ... falei o nome do santo :d
begin tran
	SELECT * FROM TesteLock WITH(SERIALIZABLE )  WHERE numero BETWEEN 1 and 10
rollback
	--> Vix fez o mesmo que o HOLDLOCK ?????????????

	--> No BOL, depois de ler eu vi que SERIALIZABLE = HOLDLOCK ...
	--> Segundo o BOL, SERIALIZABLE coloca uma key-range somente quando em índice ...
	--> Deve ser por isso que ele ta colocando na tabela toda ...
	-- http://msdn.microsoft.com/en-us/library/ms191272.aspx
	CREATE NONCLUSTERED INDEX IxNC_TesteLock_Numero ON TesteLock(NUMERO ASC);



BEGIN TRAN
	--> RangeS-S ...
	SELECT * FROM TesteLock WITH( SERIALIZABLE )  WHERE numero BETWEEN 1 and 10
	
	--> Agora tenta o INSERT em oura sessao ...
	--> Block !!!!
	-- INSERT INTO TesteLock VALUES( 1 )
	
	--> Tente um INSERT fora da daixa
	-- INSERT INTO TesteLock VALUES( 11 )
	--> OK :D
ROLLBACK

begin tran;
	--> Curiosidade. Será que SERIALIZABLE = HOLDLOCK quando tem índice ???
	SELECT * FROM TesteLock WITH( HOLDLOCK )  WHERE numero BETWEEN 1 and 10

	-- hehe, sim!!!
rollback

--> ok ok ok
	DROP INDEX IxNC_TesteLock_Numero ON TesteLock;


--> SNAPSHOT ...
--> Vamos ao nível de isolação snapshot ( novo no SQL 2005 )
ALTER DATABASE TesteLockDB SET ALLOW_SNAPSHOT_ISOLATION ON;  --> Ativando o isolation SNAPSHOT
SET TRANSACTION ISOLATION LEVEL SNAPSHOT;
BEGIN TRAN
	--> Faz um BEGIN update em outra sessao
		begin tran 
			UPDATE TesteLock SET numero = numero+8000 WHERE numero = 10
		rollback
	
	SELECT * FROM TesteLock
	--> Humm ... ñ bloquiou ... Mas leu um dado antigo ...
	--> Ver os locks que estao sendo pegos ...
	-- E Se der um COMMIT na outra ? ele vai ler o novo ?
	SELECT * FROM TesteLock
	--> Nãoooo ... Vai ler o antigo até essa transação acabar ...
COMMIT
	-- tenta d novo..;
	SELECT * FROM TesteLock
	
	--> Onde os valores antigos ficam ??
	--> R.: Version Store.

--> row versioning em READ COMMITED
ALTER DATABASE TesteLockDB SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
ALTER DATABASE TesteLockDB SET READ_COMMITTED_SNAPSHOT ON;
ALTER DATABASE TesteLockDB SET MULTI_USER WITH ROLLBACK IMMEDIATE;
BEGIN TRAN
	SET TRANSACTION ISOLATION LEVEL READ COMMITTED

	--> Faz um update outra sessao: ...
		 BEGIN tran 
			UPDATE TesteLock SET numero = -1 WHERE numero = 1
		-- commit

	SELECT * FROM TesteLock --> Hum ... Read Commited usou o versionamento ...
	
	--> E se comitar ?
	
	SELECT * FROM TesteLock  --> Rárá ... Agora usou o valor comitado.
	
	--> READ COMMITED usa o ultimo comitado e muda a cada comando.
	--> SNAPSHOT usa o ultimo comitado desde o inicio da sessao, e o mantem na transação.
ROLLBACK

--> Vendo a Version Store ...
--> Vamos Bisuiar a Version Store ...
ALTER DATABASE TesteLockDB SET ALLOW_SNAPSHOT_ISOLATION ON;
BEGIN TRAN
	SET TRANSACTION ISOLATION LEVEL SNAPSHOT
	--> http://msdn.microsoft.com/en-us/library/ms188673.aspx
	SELECT * FROM TesteLock
	
	SELECT * FROM TesteLock
ROLLBACK


USE master
GO

ALTER DATABASE TesteLockDB SET SINGLE_USER WITH ROLLBACK IMMEDIATE;

DROP DATABASE TesteLockDB
GO