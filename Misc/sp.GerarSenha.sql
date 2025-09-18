/*#info 

	# Autor
		Dirceu Resende
		Rodrigo Ribeiro Gomes
		(adaptado desse post do Dirceu: https://dirceuresende.com/en/blog/como-criar-um-gerador-de-senhas-aleatorias-escrito-em-php-c-csharp-ou-transact-sql-t-sql/)
	
	# Descricao 
		Procedure para gerar muitas senhas eficientemente.
		É uma evolução das funcões criadas originalmente pelo Dirceu (vide blog acima).

		A ideia da procedure é você pode usar em cenários quer gerar dezenas de milhares de senhas, o que pode ser muito lento usando as funções.
		Com esta proc, você pode gerar as senhas e guardar em uma tabela e usar posteriormente, por exemplo, o script abaixoi gera 100 mil senhas:

			drop table if exists #senhas;
			create table #senhas(senha varchar(max));

			insert into #senhas
			exec sp_gerasenha @total = 100000,@len = 10

			select
				*
			from
				#senhas

		
		O codigo acima rodou em 2.3 segundos, e o equivalente usando a função original, rodou em 14s:
			drop table if exists #pass;
			select top 100000 pass =  dbo.fncGera_Senha(10,1,1,1,1) into #pass from sys.all_columns a1,sys.all_columns a2


		Portanto, você pode usar a proc quando precisar de mais performance.

		LÓGICA DA PROC:
			A lógica da proc gira em torno de usar expressões SUBSTRING para gerar a senha.
			Basicamente, geramos uma tabela com os números de linhas desejado,e, para cada linha, vamos gerar a expressão que vai gerar a senha.
			Por padrão, cada expressão gera 1 caracter de cada senha, mas você pode controlar isso usando o parâmetro @batch, que pode gerar mais de 1 caracter por vez.
			Cmo isso, menos expressoes são necessárias, e mais rapido o código roda (mais percetível em grandes quantidades de linhas).
			O efeito negativo é que, mais senhas tem mais chances de serem duplicadas, ou ter partes parecidas:
			
				Efeitos do parâmetro batch:

					drop table if exists #senhas;
					create table #senhas(senha varchar(max));

					insert into #senhas
					exec sp_gerasenha @total = 100000,@len = 10, @batch = 2

					-- Cai para 1.6 segundos, 99.991 senhas unicas.
					-- @batch = 3 , 1.5 segundos, 99.969 senhas
					-- @batch = 4, 1.3 segundos, 91.517 senhas unicas
					-- @batch = 5, 1.2 segundos, 16.228 senhas unicas
					-- @batch = 5, @len = 20, 1.6 segundos, 99.741 senhas unicas.

*/


IF OBJECT_ID('dbo.sp_gerasenha','P') IS NULL
	EXEC('CREATE PROCEDURE sp_gerasenha AS')
GO

ALTER PROC dbo.sp_gerasenha(
	  @len int = 20
	 ,@chars nvarchar(max) = 'Aads' -- Especifique os caracteres ou grupo de caracteres. Formato: Grupo|Chars
								  -- Grupo é uma letra indicando o grupo. Grupos: a - letras minusculas, A - maiusculas, d - digitos, s - especiais
								  -- Chars é uma lista especifica.
								  -- Exemplo:
								  --	'aA|#$'		- gera senhas que contenham caracteres maiusculos, minusculos,# ou $.
								  --	'ds'		- gera senha que contem apenas digitos (d) ou especiais (s)
								  --	'|123abc'	- ger5a senhas que contem apenas os digitos 1 a 3 ou as letras minusculas a-c
								  --	'a||'		- gera senhas que contenham apenas letras minusculas (grupo = ), e o pipe (chars = |, segundo após o pipe separador			
	,@total int = 1
	,@batch int = 1				  -- quantos caracteres por vez podem ser gerados. 1 por vez significa menos repeticoes, mas pode ser mais lento para quantidades grandes de senhas
	,@debug bit = 0
)
AS

	DECLARE
		@sql nvarchar(max)
		,@concats nvarchar(max) = ''
		,@expressions nvarchar(max) = ''
		,@i int = 0
		,@PassCharsStatic nvarchar(max) = ''
		,@LenPassCharsStatic int

	select 
		@PassCharsStatic =  ISNULL(LowerChars,'')
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

	set @LenPassCharsStatic = len(@PassCharsStatic);

	-- reorder pass chars!
	declare @PassChars nvarchar(max) = @PassCharsStatic
	declare @TotalPassChars int = 10;
	declare @TotalPassCharLen int = len(@PassCharsStatic) * @TotalPassChars
	
	if object_id('#sp_gerarsenha_nums') is not null
		drop table 	#sp_gerarsenha_nums;

	create table #sp_gerarsenha_nums(n int primary key);

	

	; With nx as (
		select  * from (values(1),(2),(3),(4),(5),(6),(7),(8)) v(n)
	), n as (
		select top (@total+@len+@TotalPassChars) rn = row_number() over(order by (select null))
		from nx n1,nx n2,nx n3,nx n4,nx n5,nx n6,nx n7, nx n8
	)
	insert into #sp_gerarsenha_nums 
	select * from n



	set @PassChars = (
		select 
			substring(@PassCharsStatic,n,1)
		from
			#sp_gerarsenha_nums
		where
			n <= @TotalPassCharLen
		order by
			checksum(newid())
		for xml path('')
	)

	declare @ColExpressions table(ColName varchar(100), Expression varchar(1000));
	

	insert into @ColExpressions
	select
		ColName = 'p'+convert(varchar,n)
		,Expression = 'SUBSTRING(PassChars,abs(checksum(newid()))%LEN(@PassChars)+1,'+convert(varchar,@batch)+')'
	from
		#sp_gerarsenha_nums
	where
		n <= ceiling(@len*1.00/@batch)


	set @expressions = (
		select
			','+ColName+' = '+Expression
		from
			@ColExpressions
		for xml path(''),type
	).value('.','nvarchar(max)');

	set @concats = (
		select
			' + '+ColName
		from
			@ColExpressions
		for xml path('')
	)


	set @sql = '
		select 
			'+case when @debug = 1 then 'debug = 1,*,TamSenha = len(s.senha)' else 's.senha' end+'
		from
			#sp_gerarsenha_nums
			cross apply (
			   select
					*
					,PassChars = substring(@PassChars,PassCharNum,@LenPassCharsStatic)
					,TotalPassChars = @TotalPassChars
					,RawPAssChars = @PassChars
				from (
					select 
						PassCharNum =  abs(checksum(newid()))%@TotalPassChars+1
				) pc
			) p
			cross apply (
				select 
					senha = left('+@concats+'+left(PassChars,@len),@len)
					,*
				from (
					select 
						b.*
						'+@expressions+'
					from (
						select 
							LenPassChars = @LenPassCharsStatic
					) b
				) p
			) s
		where
			n <= @total
	'
	
	if @debug = 1
		print @sql;

	exec sp_executesql 
		@sql
		,N'@PassChars nvarchar(max),@total int, @batch int,@len int, @LenPassCharsStatic int, @TotalPassChars int'
	
		,@PassChars,@total,@batch,@len,@LenPassCharsStatic, @TotalPassChars

