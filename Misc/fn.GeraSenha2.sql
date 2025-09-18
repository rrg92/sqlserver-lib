/*#info 

	# Autor
		Dirceu Resende
		Rodrigo Ribeiro Gomes
		(adaptado desse post do Dirceu: https://dirceuresende.com/en/blog/como-criar-um-gerador-de-senhas-aleatorias-escrito-em-php-c-csharp-ou-transact-sql-t-sql/)
	
	# Descricao 
		Cria uma função scalar para gerar senhas.
		Essa função é uma versão alternativa e com algumas otimizações da função originada criada pelo Dirceu.
		Apesar de ser mais rapida, ela precisa ser chamada de forma diferente (Veja os exemplos abaixo).

		Apesar disso, ainda é função, e pode ser lento para centenas de milhares de linhas.
		Se você precisa muitas senhas de uma vez direto do SQL Server, considere essas alternativas:
			- proc do script sp.prcGerarSenha.sql (gere em uma tabela temporária a quantidade desejada, muito mais rápido)
			- usar CLR (Veja o post do Dirceu acima)

		COMO USAR
			--> Gera uma senha com 20 caracteres!
			select dbo.GerarSenha(newid(),20,default)

			select
				*
				,senha = dbo.GerarSenha(newid(),20,default)
			from
				usuarios 


		DETALHES DO ALGORTIMO
		
			O grande desafio em um gerador de senha é o fator aleatório.
			O algoritmo típico para gerar senha envolve basicamente escolher cada caracter da senha a partir de um valor aleatório.
			No SQL, existem algumas funções que geram valores "aleatórios" cada vez que executamos ela: RAND(), NEWID(), PWDDECRYPT()
			O grande problema é que dentro de função, você não consegue usar RAND() e NEWID().

			PWDENCRYPT() é uma função deprecated do sql que gera o hash de uma senha usando o algoritmo de hash de senhas do sql (que ele usa para armazenar os logins das senhas);
			A grande sacada, é que, a cada execução, mesmo passando o mesmo parâmetro, essa função retorna um hash diferente, devido ao algoritmo do sql (que provavelmente usa técnicas como salt, o que o valor faz ser aleatório).
			Porém, esta função pode ser mais lenta.

			Por isso, eu decidi tentar uma nova abordagem.
			Para gerar um valor aleatorio dentro de uma funcao, além de usar a PWDENCRYPT, eu poderia usar uma view, que retornasse a coluna newid() ou rand().
			Funcionaria bem, mas ai eu teria que manter 2 objetos (a função em si e a view).
			Então, eu movi a responsabilidade de gerar o valor aleatorio, para quem chama a função, criando o parâmetro @seed. 
			Você pode passar qualquer coisa que possa ser um sql_variant... O importante é ser unico para cada linha.
			Geralmente vai ser um newid(). Se você passar o mesmo valor para o @seed, ele gera sempre a mesma senha.

			Mantive o parâmetro @len, que é o tamanho da senha.
			E por fim, os parâmetros que especificam quais caracteres poderão ser usados, eu resolvi colocar em 1 único parâmetro, especificando com letras.
			Como o sql exige que você passe o valor dos parâmetros (Diferente das procs, que podem ser omitidos), eu quis adiciona menos parâmetros para você escrever na chamada.

			Verifique os comentários na função para saber como usar esses parâmetros.

			O algoritmo que eu escolhi para gerar a senha é muito parecido ao que o Dirceu já usava:
				- Gero uma string com todos os caracteres aceitaveis na senha
				- Em um loop, que vai iterar igual ao tamanho da senha desejada, calculo qual posicao da string devo pegar
				- A cada iteracao, pego o byte do seed equvialente, calculo um checksum com outros valores (para evitar duplicidade) e consigo calcular a posicao aleatoria que devo pegar
				- Com isso, a cada iteracao, eu pego sempre um novo caractere da string de caracteres aceitaveis

			A otimização aqui, em relacao a funcao original acontece nos seguintes pontos:
				- Antes, um valor aleatorio com PWDENCRYPT era gerado em cada iteracao do loop, o que consumia bastante para 1 única senha.
				- Agora, o valor aleatorio é gerado apenas 1x (o caller quem manda) e eu uso partes desse valor como seed

			Então, não somente a remoção de PWDENCRYPT, como deixo de chamá-la em cada caracter da senha. Por isso, há um aboa diferença.
			Comparativos:

				set statistics time,io on
				drop table if exists #pass		
				select top 10000 pass = dbo.fncGera_Senha(10,1,1,1,1) into #pass from sys.all_columns a1,sys.all_columns a2
				-- CPU time = 1312 ms,  elapsed time = 2057 ms (Server 2022 cu 20 16.0.4210.1, cpu i7-10750h 2.6Ghz)
				-- CPU time = 1750 ms,  elapsed time = 3044 ms (SQL Server 2019 cu 16 15.0.4223.1, amd epyc 7452 32-core, azure VM Azure Standard_E4as_v4)

				go
				drop table if exists #pass
				select top 10000 pass =  dbo.fnGeraSenha(newid(),10,default) into #pass from sys.all_columns a1,sys.all_columns a2
				-- CPU time = 719 ms,  elapsed time = 823 ms  (Server 2022 cu 20 16.0.4210.1, cpu i7-10750h 2.6Ghz)
				-- CPU time = 1125 ms,  elapsed time = 1272 ms (SQL Server 2019 cu 16 15.0.4223.1, azure VM Azure Standard_E4as_v4)	


				No SQL 2025, RC0, a PWDENCRYPT está muito lenta, demorando 125ms...
				Para gerar 1 senha usando os mesmos parâmetros acima:
						CPU time = 1312 ms,  elapsed time = 1306 ms.
				A função sem PWDENCRYPT (deste script, nos sql 2025), gerando 10000 senhas:
						CPU time = 969 ms,  elapsed time = 1009 ms.
				

*/
IF OBJECT_ID('dbo.fnGeraSenha','FN') IS NULL
	EXEC('CREATE FUNCTION dbo.fnGeraSenha() RETURNS varchar(max) AS BEGIN RETURN ''''; END')
GO

alter function dbo.fnGeraSenha (
	 @seed sql_variant			 -- Especifique o seed da senha. Vc pode usar a funcao newid() combinado com um cross apply, ou uma coluna unica na tabela.
	,@len int = 20
	,@chars nvarchar(max) = 'Aads' -- Especifique os caracteres ou grupo de caracteres. Formato: Grupo|Chars
								  -- Grupo é uma letra indicando o grupo. Grupos: a - letras minusculas, A - maiusculas, d - digitos, s - especiais
								  -- Chars é uma lista especifica.
								  -- Exemplo:
								  --	'aA|#$'		- gera senhas que contenham caracteres maiusculos, minusculos,# ou $.
								  --	'ds'		- gera senha que contem apenas digitos (d) ou especiais (s)
								  --	'|123abc'	- ger5a senhas que contem apenas os digitos 1 a 3 ou as letras minusculas a-c
								  --	'a||'		- gera senhas que contenham apenas letras minusculas (grupo = ), e o pipe (chars = |, segundo após o pipe separador)
)
returns nvarchar(max) 
AS
BEGIN

	-- adaptado de: https://dirceuresende.com/en/blog/como-criar-um-gerador-de-senhas-aleatorias-escrito-em-php-c-csharp-ou-transact-sql-t-sql/
	
	declare
		 @c int	= 0
		,@PassChars nvarchar(max) = ''
		,@Pass nvarchar(max) = ''
		,@pos int
		,@seedBin varbinary(max) = convert(varbinary(max),@seed)

		select 
			@PassChars =  ISNULL(LowerChars,'')
						+ISNULL(UpperChars,'')
 						+ISNULL(AddSpec,'')
						+ISNULL(Digits,'')
						+ISNULL(Specific,'')
		from
			(
				select 
					 AddSpec	= CASE WHEN CharOptions LIKE N'%s%' THEN N'"!@#$%&amp;*()_+-={}/\&lt;&gt;?§£¢¬|.,;:?' END
					,UpperChars	= CASE WHEN CharOptions LIKE N'%A%' THEN N'ABCDEFGHIJKLMNOPQRSTUVWXYZ' END
					,LowerChars	= CASE WHEN CharOptions LIKE N'%a%' THEN N'abcdefghijklmnopqrstuvwxyz' END
					,Digits		= CASE WHEN CharOptions LIKE N'%d%' THEN N'1234567890' END
					,Specific
					,CharOptions
				from (
					SELECT 
						 CharOptions	= LEFT(@chars,CHARINDEX('|',@chars+'|')-1)	collate Latin1_General_BIN
						,Specific		=  SUBSTRING(@chars,CHARINDEX('|',@chars)+1,LEN(@CHARS))  
				)  L
			) O
	
	declare @seedBinLen int, @PassLen int = len(@PassChars)

	set @seedBinLen = len(@seedBin) 

	while @c < @len
	begin
		set @c += 1;
		set @pos = abs(CHECKSUM(substring(@seedBin,@c%@seedBinLen,1)))%@PassLen	+ 1
		set @Pass += substring(@PassChars,@pos,1);
	end	

	return @Pass
END
GO
