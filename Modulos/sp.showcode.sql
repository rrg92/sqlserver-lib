/*#info 
	
	# Autor 
		Rodrigo Ribeiro Gomes

	# Descricao
		Uma versão melhorada da sp_helptext, permitindo maior flexibilidade... 
		Features:
			- Pode usar o % para procurar o objeto (isso me faz muito falta, ja que a original só aceita o nome exato)
			- Pode especificar múltiplas opções de busca, incluindo negação.
			- Procura em qualquer banco (prioridade é o atual, mas com pouco ajuste, vc pode procurar em outros)
			- Já faz o print direto em texto, para facilitar a cópia, ou em XML, igual a sp_whoisactive faz	 (NOSSSA, isso agiliza muito)
			- Permite filtrar por tipo
			- Descriptografa as procs criptografadas se tiver conectado como DAC (POUPA MUITO TEMPO ISSO)


		Originalmente, a sp_helptext precisa que você passe o nome exato do objeto!

		As vezes, você lembra só uma parte do nome, não lembra o banco exato, etc.
		Com a sp_showcode você pode buscar város procs, exibir o codigo original (no modo sp_helptext) ou até retornar um XML (que fica clicável no SSMS)

		Eu deixei a doc original em inglês (péssimo inglês, aceito revisões), pois acredito que essa proc possa ser útil no mundo inteiro.
		Mas aqui segue alguns exemplos de uso em português:

			Exemplos:
				> sp_showcode MinhaProc
					Exibe o texto da proc MinhaProc (ali na aba messages) do banco atual.
					A principal diferença aqui com a original é a forma que eu uso para fazer o print.
					A sp_helptext original retornaria como um resultset (que perde a formatação quando você copia no SSMS)
		
				> sp_showcode '%.%.MinhaProc'
					Aqui, evoluimos o nível, fazendo ele procurar em todos os bancos e esquemas.
					Se achar mais de 1 objeto com esse nome, ele vai exibir uma lista pra você refinar.
					Se achar só 1, printa direto.
					Note que, por padrão, ele não procura em todos os bancos. Você deve explicitamente solicitar isso usando o wildcard.
					O formato é Banco.Esquema.Objeto, onde cada parte pode conter o wildcard como se você estiver filtrando com um LIKE.

				> sp_showcode '%.%.MinhaProc', @all = 1
					A diferença desse pro anterior é que você está forçando a printar tudo que encontrar... 
					Tenha cuidado ao usar isso, pois se retornar 20 procs grandes, ele vai printar isso pro teu client

				> sp_showcode '%.%.MinhaProc','xml', @all = 1
					Aqui trocamos o modo pra XML. Ao invés de printar, ele vai retornar um resultset com os objetos como XML igual a sp_whoisactive faz.
					Aí fica clicável no SSMS e já abre em outra aba.
				
				>  sp_showcode '%.%.MinhaProc','xml', @all = 1, @top = 100
					Por padrão, ela traz somente os 50 primeiros objetos encontrados.
					Você pode aumentar o limite usando o parâmetro @top. Se colocar o valor 0, então ele traz tudo.

				> sp_showcode '%ven%'
					Aqui ele vai procurar o objeto que tem ven no nome.
					Como um filtro de schema não foi explicitamente definido, ele vai ignorar os schemas sys e INFORMATION_SCHEMA.
				
				> sp_showcode '%.%ven%'
					Aqui é a mesma coisa, mas agora ele vai procurar no esquemas de sistema, pq um filtro de esquema (%) foi explicitamente definido.
		
				> sp_showcode 'Loja12%..vwNotasFiscais',@all = 1
					Aqui é mais um exemplo de um filtro elaborado...
					No caso, ele vai procurar e exibir o objeto chamado vwNotasFiscais em todos os bancos que começam com Loja12 , em todos os schemas

				> sp_showcode 'Vendas..%','xml', @types = 'function'
					Aqui é um exemplo do parâmetro @types. Você pode especificar um tipo da sys.objects.type ou type_desc.
					Ou mesmo um trecho, como no exemplo acima, onde function irá corresponder a todos os tipos de função.
					Neste caso, vai listar todas as functions no banco vendas. Se colocar @all = 1, printa tudo!

				> sp_showcode 'chamados/isAberto','xml'
					Aqui vê está procurando por colunas computadas. Ao incluir uma barra (/), o valor após a barra se torna um filtro de coluna.
					Você pode usar % para filtrar várias colunas.

				> sp_showcode '%..%/is%',@all = 1
					Aqui por exemplo, estamos buscando todas as colunas computadas em todos os bancos e todas as tabelas que comecem com is.
					A definição de todas elas sera printada como mensagem

				> sp_showcode 'prcVenda,prcSales'
					Aqui usamos um recurso mais avançado, que são múltiplas opções.
					NEsse caso, ele vai procurar todos os objetos de usuário que contenha ven ou sal. Encontraria, por exemplo, prcVendas e prcSales.


		Cuidados e considerações:
			- A proc usa tabelas temporárias para carregar as procs e depois printar.
				Logo, se tiver muita proc grande que o seu filtro atende, isso pode usar bastante da tempdb.
			- No modo padrão, a proc usa o comando print para jogar o conteúdo 
				Esse comando tem um limite de 4000 caracteres unicodes que podem ser printados de uma vez, o que siginfica na prática, um limite de 4000 chars por linha.
				É muita coisa e acho que dificilmente você terá casos assim.
				Mas, se tiver, a proc irá quebrar a linha em várias outras e isso pode deixar o corpo da proc semanticamente incorreto, se comparado a original.
				Nesses casos, considere usar XML para exibir.
			- A sp_showcode foi criada pensando no seu uso primariamente com o SSMS, para o dia a dia o DBA.
				Mas, se você precisar exportar (usando linha de comando, por exemplo), recomendo usar o modo export, que vai ajustar os parâmetros corretamente para que você possa escrever, em um arquivo, por exemplo.


			

*/

USE master 
GO

-- for rc4 decryption (used for encrypted procs)
-- Based on Paul White (https://sqlperformance.com/2016/05/sql-performance/the-internals-of-with-encryption)
IF OBJECT_ID('dbo.sp_showcode_rc4decode','P') IS NULL
	EXEC('CREATE PROC dbo.sp_showcode_rc4decode AS')
GO

ALTER PROCEDURE dbo.sp_showcode_rc4decode
(
     @Pwd varbinary(256)
    ,@Text varbinary(MAX)
	,@Decrypted nvarchar(max) OUTPUT
)
AS
BEGIN
    DECLARE @Key table (i tinyint PRIMARY KEY,v tinyint NOT NULL);
	DECLARE @Box table (i tinyint PRIMARY KEY, v tinyint NOT NULL);
	DECLARE @nums TABLE(i tinyint);
    DECLARE
        @PwdLen tinyint = DATALENGTH(@Pwd);

	;WITH n as ( select * from (values(1),(2),(3),(4),(5),(6),(7)) v(n) )
	insert into @Key(i,v)
	select 
		N.n
		,CONVERT(tinyint, SUBSTRING(@Pwd, N.n % @PwdLen + 1, 1))
	from (
		select top(256)
			n = row_number() over(order by (select null))-1 
		from n,n n2,n n3,n n4
	) N

	insert into @Box(i,v) select i,i from @key;



    DECLARE
        @Index int = 0,
        @i smallint = 0,
        @j smallint = 0,
        @t tinyint = NULL,
		@b smallint = 0,
        @k smallint = NULL,
        @CipherBy tinyint = NULL,
        @Cipher varbinary(MAX) = 0x;
 
    WHILE @Index <= 255
    BEGIN
        SELECT @b = (@b + b.v + k.v) % 256
        FROM @Box AS b
        JOIN @Key AS k
            ON k.i = b.i
        WHERE b.i = @Index;
 
        SELECT @t = b.v
        FROM @Box AS b
        WHERE b.i = @Index;
 
        UPDATE b1 SET b1.v = (SELECT b2.v FROM @Box AS b2 WHERE b2.i = @b)
        FROM @Box AS b1 WHERE b1.i = @Index;
 
        UPDATE @Box SET v = @t  WHERE i = @b;
 
        SET @Index += 1;
    END;


	select 
		@Index = 1
	
 
    WHILE @Index <= DATALENGTH(@Text)
    BEGIN
        SET @i = (@i + 1) % 256;
 
        SELECT
            @j = (@j + b.v) % 256,
            @t = b.v
        FROM @Box AS b
        WHERE b.i = @i;
 
        UPDATE b
        SET b.v = (SELECT w.v FROM @Box AS w WHERE w.i = @j)
        FROM @Box AS b
        WHERE b.i = @i;
 
        UPDATE @Box
        SET v = @t
        WHERE i = @j;
 
        SELECT @k = b.v
        FROM @Box AS b
        WHERE b.i = @i;
 
        SELECT @k = (@k + b.v) % 256
        FROM @Box AS b
        WHERE b.i = @j;
 
        SELECT @k = b.v
        FROM @Box AS b
        WHERE b.i = @k;
 
        SELECT
            @CipherBy = CONVERT(tinyint, SUBSTRING(@Text, @Index, 1)) ^ @k,
            @Cipher = @Cipher + CONVERT(binary(1), @CipherBy);
 
        SET @Index += 1;
    END;
 
    SET @Decrypted = CONVERT(nvarchar(max),@Cipher);
END;
GO


IF OBJECT_ID('dbo.sp_showcode','P') IS NULL
	EXEC('CREATE PROC sp_showcode AS SELECT StubVersion = 1')
GO


ALTER PROC sp_showcode (
	 -- Specify the object name in format Db.Schema.ObjectName or Schema.ObjectName or ObjectName
	 -- You can add column filters, for search by computed columns, using syntax /ColumnName in ObjectName
	 -- you can specify multile options using comma and prefix with '-' to specify as "not".
	 -- You can use wildcards in any part, for example, sp_help%, ou Test_.%.vw%
	 -- By default, search only in current db, but using '%.%.%search%' will force search on all db and schema!
	 -- If want force search in current db, preped and dot, example: .SomeObject%
	 -- If no explicit schema filter is specified, proc will add implicit filters excluding sys and INFORMATION_SCHEMA, causing search happens only in user objects.
	 -- Check examples bellow
	 @text sysname

	,-- Specify the output mode.
	 -- Values can be (pipe mean alternative values):
	 --		sp_helptext|1	- Use the sp_helptext to print 
	 --		xml|2			- Return an XML, like sp_whoisactive do. Useful for click in SSMS.
							-- We try remove invalid XML chars to avoid xml conversion errors
	 --		text|3			-- Print directly output. With that, it is easy copy and bypass SSMS output limits due fact that it breaks into lines and issue many prints.
								-- Can be more slow in some cases due to line ending checks and splitting
								-- due fact we use print to output lines, max line size is 4000 chars, due print limit
								-- If a line is grather that this size, proc will split a line in multiple lines
								-- The disvantange that is the object code can be incorrect (for example, if line was part of literal string) or is break in middle of some statement
								-- But, for no code be hidden, we prefer this default behavior.
								-- If objects you are searching contains lines above that limit, consider using another mode, like XML or sp_helptext.
								-- You can lower the max using @MaxLineSize
	--		trunc|4			-- Same as text, but if a line exceed max print size, just show the a BIG LINE WARNING and truncate line.
	--		export|5		-- Return dafinitions safe to be exported, when you running this proc in some commandline or custom app that will handle by its own the result.
							-- no headers, GO statements are returned, just raw defintion, what is it useful for expor
							-- Will return one defintion per line.
	--		exportgo|6		-- Same as export, but include headers and GO statements to delimiter object end start and end!
	 @mode varchar(100) = 'text'

	,-- By default, proc only prints if just extacly one object is found.
	 -- If multiple matches are found, then proc will return a list of found objects you help refine your search
	 -- Specify @all = 1, force proc print all bodies of all objects found. Use with caution, because this can generate lot of processing
	 -- @all is automatically set to 1 if specify multiple expressions in @text, all with no wildcards;
	 @all bit = 0


	,-- specify object types to filter. By default accept all.
	 -- separate each type by comma. Same of type from sys.objects
	 @type varchar(100) = '%%%%'

	,-- limit the top first object found
	 -- 0 means no limit.
	 @top int = 50


	,-- set how proc will handle system object
	 -- when 0, only first occurrence of system object is returned
	 -- when 1, all occurence is returned
	 @sysall bit = 0

	,-- max line size for text or trunc modes. The maximum value for this is 4000, due print limit.
	 @MaxLineSize smallint = 4000

	,-- include GO statements between headers and at end of proc. Not used when mode ir xml or sp_helptext
	 @go bit = 1

	,-- include descriptive headers. NOt used when mode is sp_helptext and xml.
	 @headers bit = 1

	-- Enable some messages for debugging.
	,@Debug bit = 0
)
/*
	Author: Rodrigo Ribeiro Gomes (thesqltimes.com)
	Description: 
		Advanced and flexible version of sp_helptext, to help find proc and its body.
		Allow you search and print body of objects with some definition (like procs, functions and views) to easy copy
		IF procs is encrypted and you are connect as DAC, the procedure automatically tries decrypts procs.

		Compatibility = sql server 2008+

		TODO:
			- Add jobs

	Examples:
		> sp_showcode MyProcName
			Search in current db only and Print the body of object MyProcName if found. 
		
		> sp_showcode '%.MyProcName'
			Print the body of proc MyProcName if exists just one.
			If multiple is found present the list to you choose.

		> sp_showcode '%.%.MyProcName', @all = 1
			Print the body of all object called MyProcName in instance

		> sp_showcode '%..MyProcName', @all = 1, @top = 100
			By default, only first 50 objects are returned. @top allows controls this. If 0, means unlimited.

		> sp_showcode '%..MyProcName','xml'
			Return the body of all MyProcName found in instance as XML, to be clicable in SSMS.
		
		> sp_showcode 'Test_%..proc1',@all = 1
			Print all body of objects with name proc1 found in every db, user schema only, which name start with Test_
			
		> sp_showcode 'Sales..%','xml', @types = 'proc'
			Return body of all user procedures in database called Sales, as a XML.	

		> sp_showcode '%.%test%','xml', @type = 'proc'
			Return all procedures, including system schemas, containing test in name.

		> sp_showcode '%..test/%','xml', @all = 1
			Return all user computed columns of table test in all dbs1
			
		> sp_showcode '%,-%test%','xml', @all = 1
			Return top user objects with text, except which contains test in name
			

		> sp_showcode 'sp_help,sp_helptrigger','xml'
			Return text of both sp_help and sp_helptrigger, as XML
			Note that dont need set @all = 1, because multiple options without wildcard was passed in first param.


*/
AS

SET NOCOUNT ON; 

DECLARE
	@IsWild sysname = 0

IF NOT @MaxLineSize BETWEEN 2 AND 4000
BEGIN
	RAISERROR('@MaxLineSize must be between 2 and 4000',16,1);
	return;
END

IF CHARINDEX('%',@text)	 > 0
	SET @IsWild = 1

-- Parse!
DECLARE
	 @i int = 0
	,@TextLen int = len(@text)
	,@CurrentChar nvarchar(1), @NextChar nvarchar(1)
	,@buff nvarchar(max) = ''
	,@UserFilterCount int

IF OBJECT_ID('tempdb..#sp_showcode_filters') IS NOT NULL
	DROP TABLE #sp_showcode_filters;

CREATE TABLE #sp_showcode_filters (
	ord int identity not null
	,expr nvarchar(max)
	,IsNeg bit
	,FilterDb nvarchar(4000)
	,FilterSchema nvarchar(4000)
	,FilterObject nvarchar(4000)
	,FilterColumn nvarchar(4000)
	,ExprReal nvarchar(max)
	,IsWild as convert(bit,case when charindex('%',exprreal) > 0 then 1 else 0 end)
);

while @i <=	@TextLen 
begin
	set @i += 1;
	set @CurrentChar = substring(@text+',',@i,1)
	set @NextChar = substring(@text,@i+1,1)

	if @CurrentChar = N'\' and @NextChar in (N'\',N',')
		select @buff += @NextChar, @i += 1;
	else if @CurrentChar = N',' 
	begin
	   insert into #sp_showcode_filters(expr) values(@buff)
	   set @buff = '';
	end else
		set @buff += @CurrentChar
end


update f 
set 
	 FilterDb	= PF.FilterDb
	,FilterSchema = PF.FilterSchema
	,FilterObject = PF.FilterObject
	,FilterColumn = PF.FilterColumn
	,IsNeg = E.IsNeg
	,ExprReal = e.ExprReal
from
	#sp_showcode_filters f
	cross apply (
		SELECT 
			IsNeg = CASE
						WHEN left(expr,1) = '-' THEN 1
						ELSE 0 
					END
			,ExprReal = CASE
							WHEN left(expr,1) = '-' THEN STUFF(F.expr,1,1,'')
							ELSE expr 
					END 
	) E
	cross apply (
		SELECT 
			BF.FilterDb
			,BF.FilterSchema
			,FilterObject = CASE 
								WHEN ColSepIndex > 0 THEN LEFT(BF.FilterObject,ColSepIndex-1)
								ELSE BF.FilterObject
							END
			,FilterColumn = CASE 
								WHEN ColSepIndex > 0 THEN SUBSTRING(BF.FilterObject,ColSepIndex+1,4000)
								ELSE '%'
							END
		FROM (
		   SELECT 
				 FilterDb		= isnull(parsename(E.ExprReal,3),db_name())
				,FilterSchema	= parsename(E.ExprReal,2)
				,FilterObject	= parsename(E.ExprReal,1)
				,ColSepIndex	= CHARINDEX('/',parsename(E.ExprReal,1))
		) BF
		
	) PF
WHERE
	PF.FilterObject IS NOT NULL

SET @UserFilterCount = @@ROWCOUNT


-- if not explicit positive schema filter
if not exists(select * from #sp_showcode_filters where IsNeg = 0 and FilterSchema is not null) and @IsWild = 1
begin
	insert into #sp_showcode_filters(IsNeg,FilterDb,FilterSchema,FilterObject,FilterColumn)
	values
		(1,'%','sys','%','%')
		,(1,'%','INFORMATION_SCHEMA','%','%')
end

-- 
UPDATE #sp_showcode_filters
SET
	FilterSchema = ISNULL(FilterSchema,'%')


IF @Debug = 1
	SELECT * FROM #sp_showcode_filters f;

if @UserFilterCount = 0
begin
	raiserror('@text must be in format {[-][DbFilter.][SchemaFilter.]ObjectFilter[/column]}[,...n]',16,1)
	return;
end

 -- If user specified only non wild filter!
if @UserFilterCount = (select count(*) from #sp_showcode_filters where IsWild = 0 and expr is not null)
begin
	set @all = 1;
	if @Debug  = 1 raiserror('Changed @all to 1 due user explicit multiple filter.',0,1) with nowait;
end

		
if object_id('tempdb..#sp_showcode_FilterTypes') IS NOT NULL
	DROP TABLE #sp_showcode_FilterTypes

DECLARE
	@TypesXML XML = '<t>'+REPLACE(@type,',','</t><t>')+'</t>'


select
	ot.TypeAb as TypeName
INTO
	#sp_showcode_FilterTypes
from
	(
		SELECT
			TypeFilter = UPPER(t.x.value('.','varchar(20)'))
		FROM
			@TypesXML.nodes('//t') t(x)
	) TF
	CROSS APPLY (
		SELECT 
			*
		FROM
			(
				values 
					('P','SQL_STORED_PROCEDURE'),('V','VIEW'),('TR','SQL_TRIGGER')
					,('FN','SQL_SCALAR_FUNCTION'),('IF','SQL_INLINE_TABLE_VALUED_FUNCTION'),('TF','SQL_TABLE_VALUED_FUNCTION')

					-- This dont exists officially. Created just for separate in filters!
					,('TRS','SERVER_DDL_TRIGGER')	
					,('TRD','DATABASE_DDL_TRIGGER')
					,('CCC','COMPUTED_COLUMN')
			)  ot(TypeAb,TypeDesc) 
		WHERE
			TypeAb = TF.TypeFilter		-- Filter exactly types (two chars)
			OR
			TypeDesc = TF.TypeFilter	-- exactly type-desc
			OR
			-- other type desc based on part of word that dont match previous.  
			-- for example, if user want filter all functions, just provide "function" as value.
			-- Chose len = 3, due to custom types I created to represent other objects that dont exists in sys.objects (like server triggers, jobs, etc)
			(TypeDesc like '%'+TF.TypeFilter+'%' AND LEN(TF.TypeFilter) > 3 AND TypeDesc != TF.TypeFilter)

	) ot

IF @Debug = 1
	select * from #sp_showcode_FilterTypes

-- validate mode!
SET @mode = CASE @mode
				WHEN '1' THEN 'sp_helptext'
				WHEN '2' THEN 'xml'
				WHEN '3' THEN 'text'
				WHEN '4' THEN 'trunc'
				WHEN '5' THEN 'export'
				WHEN '6' THEN 'exportgo'
				ELSE @mode
			END

IF @Debug = 1
	RAISERROR('Output mode = %s',0,1,@mode) with nowait;


IF @mode NOT IN ('sp_helptext','xml','text','trunc','export','exportgo')
BEGIN
	RAISERROR('Invalid @mode: %s',16,1,@mode);
	return;
END

DECLARE @DbList TABLE(Seq int, DbName sysname);

INSERT INTO @DbList(Seq,DBName)
SELECT
	ROW_NUMBER() OVER(ORDER BY IsCurrentDB DESC, database_id)
	,name
FROM
	sys.databases d 
	CROSS APPLY (
		SELECT 
			IsCurrentDb = CASE WHEN DB_NAME()  = name THEN 1 ELSE 0 END
	) c
WHERE
	-- an explicit db must be select with a positive filter
	-- Negative filters can remove this db, but anyway, before remove, we must be able to have something to select
	-- So, this step, we just intereseted include filters, because it determines which dbs we must look on.
	-- If user specify just negative filter, this dont intereset in this part, because by default, no db is selected unless user explicity filter
	-- FOr example, if @text is '-DbX.%sys.%', because no positive filter exists, then nothing is select.
	-- The intent of negative filters is a "second chance" over positives, because, by default, nothing is selected, unless positive filter select it.
	-- Due that, at this point, we just select dbs in positive filters.
	exists ( 
		select
			*
		from
			#sp_showcode_filters f
		where
			d.name like f.FilterDb
			and
			f.IsNeg = 0
	)

IF @Debug = 1
	SELECT * FROM @DbList

DECLARE @FoundObjects TABLE (
	 Id int not null identity primary key
	,DbName sysname 
	,ObjectName sysname 
	,ObjectSchema sysname
	,ColName sysname null
	,ObjectId int
	,ObjectDefinition nvarchar(max)
	,IsEncrypted bit 
	,ObjType varchar(10)
	,TypeDesc varchar(200)
	,IsInSysComments bit
	,IsInMasterComments bit
	,FullName as QUOTENAME(DbName)+'.'+QUOTENAME(ObjectSchema)+'.'+QUOTENAME(ObjectName)
)

DECLARE
	@Seq int = 0
	,@DbName sysname
	,@spsql sysname
	,@FoundCount int
	,@TotalFound int = 0
	,@NeedsDefinition bit = 0
	,@sql nvarchar(max)
	,@LeftLimit int = @top
	,@StartId int = 0

IF @mode IN ('xml','text','trunc')
	SET @NeedsDefinition = 1

if @LeftLimit = 0
	set @LeftLimit = NULL

-- contians found systemprocs, to prevent load duplicates
if object_id('tempdb..#sp_showcode_SystemProcs') IS NOT NULL
	DROP TABLE #sp_showcode_SystemProcs

create table #sp_showcode_SystemProcs(
	 SchemaName sysname
	 ,ObjectName sysname
)
create unique index IxSystemProcs ON #sp_showcode_SystemProcs(SchemaName,ObjectName);

WHILE 1 = 1
BEGIN
	SELECT TOP 1 
		@Seq = Seq
		,@DbName = DbName
	FROM
		@DbList
	WHERE
		Seq > @Seq
	ORDER BY
		Seq 
	IF @@ROWCOUNT = 0
		BREAK

	set @spsql = @DbName+'.sys.sp_executesql'

	IF @Debug = 1
		RAISERROR('Searching in db %s',0,1,@DbName) with nowait;

	
	set @sql = '
		SELECT '+ISNULL('TOP('+CONVERT(varchar(10),@LeftLimit)+')','')+'
			 DB_NAME()
			,O.name 
			,S.name
			,ColName
			,O.object_id
			,OBJECTPROPERTY(O.object_id, ''IsEncrypted'')
			,O.type
			,O.type_desc
			,InSysComments
			,IsInMasterSysComments
		FROM
			(
				select
					name,object_id,type = CONVERT(varchar(3),type),type_desc ,schema_id
					,ColName = CONVERT(sysname,NULL)
				from
					sys.all_objects O 

				union all 

				select 
					name COLLATE DATABASE_DEFAULT,object_id,''TRS'',''SERVER_DDL_TRIGGER'',1,NULL
				from
					sys.server_triggers
				WHERE
					DB_ID() = 1

				union all 

				select 
					name COLLATE DATABASE_DEFAULT,object_id,''TRD'',''DATABASE_DDL_TRIGGER'',1,NULL
				from
					sys.triggers
				WHERE
					parent_class_desc = ''DATABASE''

				union all 

				select
					 OBJECT_NAME(C.object_id)
					,C.object_id
					,''CCC'',''COMPUTED_COLUMN''
					,O.schema_id
					,C.name
				from
					sys.computed_columns  C
					JOIN
					sys.all_objects O
						ON O.object_id = C.object_id
			) O
			JOIN
			sys.schemas	S
				ON S.schema_id = O.schema_id
			cross apply (
				SELECT 
					I.*
				FROM
				(
					SELECT 
						InSysComments = CASE WHEN EXISTS (
														SELECT * FROM sys.syscomments C
														WHERE C.id = O.object_id
													) THEN 1 
											ELSE 0 
										END
						,IsInMasterSysComments = CASE WHEN EXISTS (
														SELECT * FROM master.sys.syscomments C
														WHERE C.id = O.object_id
													) THEN 1 
											ELSE 0 
										END
				) I
			) A
		WHERE
			0 = (
				SELECT 
					max(convert(int,IsNeg))
				FROM
					#sp_showcode_filters F
				WHERE
					O.name LIKE F.FilterObject COLLATE DATABASE_DEFAULT
					AND
					S.name LIKE F.FilterSchema COLLATE DATABASE_DEFAULT
					AND
					DB_NAME() LIKE F.FilterDb COLLATE DATABASE_DEFAULT
					AND
					isnull(O.ColName,'''') LIKE F.FilterColumn COLLATE DATABASE_DEFAULT

			)

			AND 
			(
				(
					O.type in (''P'',''FN'',''IF'',''TF'',''V'',''TR'')
					AND
					(InSysComments = 1 OR IsInMasterSysComments = 1 OR O.object_id < 0)
				)
				OR
				O.type IN (''TRS'',''TRD'',''CCC'')
			)
			AND
			O.type IN (SELECT TypeName COLLATE DATABASE_DEFAULT FROM #sp_showcode_FilterTypes)
			AND NOT EXISTS (
				SELECT * FROM #sp_showcode_SystemProcs
				WHERE SchemaName = S.name COLLATE DATABASE_DEFAULT 
				and Objectname = O.name COLLATE DATABASE_DEFAULT
			)
	'
	
	
	select @StartId = max(id) from @FoundObjects
	INSERT INTO @FoundObjects(DbName,ObjectName,ObjectSchema,ColName,ObjectId,IsEncrypted,ObjType,TypeDesc,IsInSysComments,IsInMasterComments)
	exec @spsql @sql,N''
	set @FoundCount = @@ROWCOUNT;
	set @TotalFound += @FoundCount
	
	if @top > 0
		SET @LeftLimit -= @FoundCount;

	IF @Debug = 1
		RAISERROR('	Found: %d objects (total = %d), Top: %d, LeftLimit: %d. StartId: %d',0,1,@FoundCount,@TotalFound,@top,@LeftLimit,@StartId) with nowait;

	-- If user specified just 1 filter, without wildcards, and we found somehting, we assume it searching extactly object name!
	IF @Seq = 1 AND @IsWild = 0	and @FoundCount > 0 AND @UserFilterCount = 1
		break;

	-- if top enabled and no more 
	if @top > 0 and @LeftLimit <= 0
		break;

	-- add systemprocs!
	-- if sysall disable, keep that table empty, so it dont affect not exists filter!
	IF @sysall = 0 AND @FoundCount >= 1
		insert into #sp_showcode_SystemProcs
		select distinct ObjectSchema,ObjectName from @FoundObjects
		where 
			ObjectId < 0 
			and 
			ObjectSchema = 'sys' 
			and 
			(
				(IsInSysComments = 0 and IsInMasterComments = 1)
				or
				DbName = 'master'
			)
			and
			Id > @StartId

END



if @TotalFound > 1 and @all = 0
begin
	select * from @FoundObjects;
	select 'Multiple options found. Refine search and try again or use @all = 1'
	return;
end

IF @Debug = 1
BEGIN
	SELECT * FROM @FoundObjects
END




-- iterate over each proc and run original sp_helptext!
declare
	@id int  = 0
	,@SchemaObject sysname
	,@sphelptext sysname
	,@ObjectDefinition nvarchar(max)
	,@NextLineIndex int
	,@LineLength int
	,@len int
	,@start int
	,@IsEncrypted bit
	,@IsDac int 
	,@ImageVal varbinary(Max)
	,@ObjectId int
	,@SubObjectId int
	,@Rc4Key varbinary(256)
	,@ObjectType varchar(10)
	,@ColName sysname
	,@LineNum int
	,@WarningLines varchar(max)
	,@buffer nvarchar(max)
	,@line nvarchar(max) 

select 
	@IsDac = Ep.is_admin_endpoint
from
	sys.dm_exec_sessions S
	JOIN
	sys.endpoints EP
		ON EP.endpoint_id = S.endpoint_id
WHERE
	S.session_id = @@SPID	


while 1 = 1
begin
 	SELECT TOP 1 
		 @id = id
		,@DbName = DbName
		,@SchemaObject = QUOTENAME(ObjectSchema)+'.'+QUOTENAME(ObjectName)
		,@IsEncrypted = IsEncrypted
		,@ObjectId = ObjectId
		,@ObjectType = ObjType
		,@ColName = ColName
	FROM
		@FoundObjects
	WHERE
		Id > @id
	ORDER BY
		ID 
	IF @@ROWCOUNT = 0
		BREAK

	set @sphelptext = @DbName+'..sp_helptext';
	set @spsql = @DbName+'..sp_executesql';
	set @ObjectDefinition = null

	if @IsEncrypted = 1
	begin
		IF @IsDac != 1
		BEGIN
			raiserror('-- Object %s is encrypted. To view, connect as DAC!',0,1,@SchemaObject) with nowait;
			continue;
		END	

		IF @Debug = 1 RAISERROR('Object %s i encrypted and we are connected via DAC. Trying decrypt...',0,1) WITH NOWAIT;

		-- first lets get the encrypted value!
		EXEC @spsql N'
			select @val = imageval, @sub = OV.subobjid 
			from sys.sysobjvalues OV
			WHERE OV.objid = @ObjectId
			AND OV.valclass = 1
		',N'@ObjectId int,@val varbinary(max) OUTPUT, @sub int OUTPUT',@ObjectId,@ImageVal OUTPUT, @SubObjectId OUTPUT;

		IF @ImageVal IS NULL
		BEGIN
			raiserror('-- Object %s is encrypted we are in DAC but encrypted source not found. Submit a bug report.',0,1,@SchemaObject) with nowait;
			continue;
		END	

		-- Now we have the encrypted code, lets build the key!
		SELECT 
			@Rc4Key = CONVERT(binary(20),HASHBYTES('SHA1', DBGuid + ObjectID + SubID))
		FROM
			(
				SELECT
					DBGuid			= convert(binary(16),convert(uniqueidentifier,DRS.family_guid))
					,ObjectID		= convert(binary(4),reverse(convert(binary(4),@ObjectId)))
					,SubID			= convert(binary(2),reverse(convert(binary(2),@SubObjectId)))
					,EncryptedDef	= @ImageVal
				FROM
					sys.database_recovery_status DRS
				WHERE
					DRS.database_id = DB_ID(@DbName)
			) D 


		IF @Debug = 1 RAISERROR('Invoking Rc4 decrypt...',0,1) WITH NOWAIT;
		exec sp_showcode_rc4decode @Rc4Key,@ImageVal,@ObjectDefinition OUTPUT
		IF @Debug = 1 RAISERROR('	Decrypted!',0,1) WITH NOWAIT;
	end	else begin
		
		set @sql = '
			select 
				@definition = OBJECT_DEFINITION(@ObjectId)
		'

		if @ObjectType = 'CCC'
			SET @sql = '
				SELECT 
					@definition = definition 
				FROM 
					sys.computed_columns C
				WHERE
					C.object_id = @ObjectID
					AND
					C.name = @column
			'


		-- get object definition!
		IF @Debug = 1 RAISERROR('Getting object defintion',0,1) with nowait;
		exec @spsql @sql,N'@ObjectId int,@definition nvarchar(max) OUTPUT,@column sysname',@ObjectId,@ObjectDefinition OUTPUT,@ColName
		IF @Debug = 1 RAISERROR('	Done!',0,1) with nowait;
	end

	if @ObjectDefinition is null  -- must exists some definition. Dont exists due some bug in prev code or permissions. Likely permission.
	begin
		RAISERROR('Definition not found for [%s].%s. Check permissions or try with DAC. ObjectId: %d',0,1,@DbName,@SchemaObject, @ObjectId) with nowait;
		update @FoundObjects
		set ObjectDefinition = '/* Cannot determine %s definition. Check your permissions or try with DAC if it is internal object */'
		where id = @id
		continue;
	end
	
	if @mode in ('xml','export','exportgo')
	begin
		if @ObjectDefinition is not null
			update @FoundObjects 
			set ObjectDefinition = @ObjectDefinition, IsEncrypted = 0
			where  ObjectDefinition IS NULL
			and Id = @id

		continue -- useful just for check for encryptions!
	end
		

	if @mode = 'sp_helptext'
	begin
		exec @sphelptext @SchemaObject,@columnname = @ColName
		continue;
	end

	if @mode in ('text','trunc')
	begin
		set @len = len(@ObjectDefinition)
		set @i = 0;

		IF @headers = 1
		BEGIN
			raiserror('-- Generated by sp_showcode',0,1);
			raiserror('-- Object: [%s].%s',0,1,@DbName,@SchemaObject)
		
			IF @ObjectType = 'CCC' -- column
			BEGIN
			   raiserror('-- Column: [%s]',0,1,@ColName)
			   PRINT '-- '+@ObjectDefinition;
			END

			raiserror('',0,1) with nowait; -- try force a flush!

			if @go = 1
				print 'GO'
		END

		

		if @ObjectType = 'CCC'
			CONTINUE;



		-- force always have a last line break!
		if right(@ObjectDefinition,1) != NCHAR(10)
			SET @ObjectDefinition += NCHAR(10)
		
		-- iterative over chars 
		-- IF line break found, print it and starts again.
		set @LineNum = 0;
		set @buffer = '';
		WHILE @i < @len
		BEGIN
			-- Find next linebreak! 
			set @NextLineIndex = CHARINDEX(NCHAR(10),@ObjectDefinition,@i)

			IF @Debug = 1 RAISERROR('	-- NextLineIndex: %d',0,1,@NextLineIndex) with nowait;

			IF @NextLineIndex > 0
			begin
				set @LineNum += 1;
				-- print entire line!
				set @LineLength = @NextLineIndex-@i
				
				-- if prev char is Lf, skip it!
				if @NextLineIndex >= 2 AND unicode(substring(@ObjectDefinition,@NextLineIndex-1,1)) = 13
					set @LineLength -= 1;
					
				set @start = @i;
				set @i = @NextLineIndex + 1;

				IF @Debug = 1 RAISERROR('	--	LineNum:%d, Length: %d',0,1,@LineNum,@LineLength) with nowait;

				-- if current line overflows the limit, then we print just the limi, and next loop we check the rest.
				if @mode = 'text'
					if @LineLength > @MaxLineSize
					begin
						set @LineLength =  @MaxLineSize
						set @i = @start+@LineLength;
					end

			    if @LineLength <= 0
					set @LineLength = 0;

				set @line = substring(@ObjectDefinition,@start,@LineLength)	+ nchar(13)+nchar(10)

				-- we will bufferize max as possible to avoid lot of writes to client, optimizing performance
				-- because print limit of 4000, if current line dont fit in buffer, then we flush them to client.
				if len(@buffer) + len(@line) > 4000
				begin 
					if len(@buffer) > 0 -- security for void print if buffer is empty and line is already grather than 4k
						print @buffer;
					set @buffer = '';
				end
				
				set @buffer += @line; -- here, our buffer is ready to acept line!
									
				if @LineLength >  @MaxLineSize -- print limit
				begin
				   raiserror('-- BIG LINE WARNING: previous line can be incomplete due be grather than %d chars. Use XML output. Length: %d. LineNum: %d',0,1, @MaxLineSize,@LineLength,@LineNum) with nowait;
				end

			end else 
				break

			
		END

		-- if buffer contains something, print!
		if len(@buffer) > 0
			print @buffer;

		IF @go = 1
			print 'GO'

		print ''



	end

end



-- for each object, run original sp_helptext!
if @mode = 'xml'
begin
	select 
		 FullName = QUOTENAME(DbName)+'.'+QUOTENAME(ObjectSchema)+'.'+QUOTENAME(ObjectName)
		,ObjType
		,TypeDesc
		,ObjectDefinition = (
			select
				'-- ',
				[processing-instruction(q)] = case 
							when IsEncrypted = 1 then 'ENCRYPTED: Object definition encrypted. Connect as DAC to decrypt!'
							else 'generated by sp_showcode. you can copy and paste in new ssms tab to better visualize'+NCHAR(13)+NCHAR(10)
								+CleanObjectDefinition
								+nchar(13)+nchar(10)+'-- '
						end
					
					
			FOR XML PATH(''),TYPE
		)
	from
		@FoundObjects
		CROSS APPLY (
			SELECT -- Clean the object definition XMl chars! Tks from sp_whoisactive (https://github.com/amachanic/sp_whoisactive/blob/4e656dda2dc1d62b84eb92d443fadfc2c5625ae3/sp_WhoIsActive.sql#L4042)
				CleanObjectDefinition = REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
                                    REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
                                    REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
									ObjectDefinition COLLATE Latin1_General_Bin2
									,NCHAR(31),N'?'),NCHAR(30),N'?'),NCHAR(29),N'?'),NCHAR(28),N'?'),NCHAR(27),N'?'),NCHAR(26),N'?'),NCHAR(25),N'?'),NCHAR(24),N'?'),NCHAR(23),N'?'),NCHAR(22),N'?'),
                                        NCHAR(21),N'?'),NCHAR(20),N'?'),NCHAR(19),N'?'),NCHAR(18),N'?'),NCHAR(17),N'?'),NCHAR(16),N'?'),NCHAR(15),N'?'),NCHAR(14),N'?'),NCHAR(12),N'?'),
                                        NCHAR(11),N'?'),NCHAR(8),N'?'),NCHAR(7),N'?'),NCHAR(6),N'?'),NCHAR(5),N'?'),NCHAR(4),N'?'),NCHAR(3),N'?'),NCHAR(2),N'?'),NCHAR(1),N'?'),
                                    NCHAR(0),N'')
		) A	

	return;
end

if @mode in ('export','exportgo')
BEGIN
	

	IF @mode = 'export'
		select 
			@go = 0, @headers = 0

	SELECT
		[text] = 
		+case when @headers = 1 THEN 
		+CrLf+'-- Generated by sp_showcode '+F.FullName
		+CrLf+'-- Object: '+F.FullName
		+ISNULL(CrLf+'-- Column: '+F.ColName,'')
		+CrLf
		+case when @go = 1 then 'GO' else '' end
		ELSE '' END
		+CrLf
		+CrLf

		+ObjectDefinition
		
		+case when @go = 1 THEN 
		+CrLf
		+'GO'
		+CrLf
		ELSE '' END
		+CrLf
		+CrLf
	FROM
		@FoundObjects F
		CROSS JOIN (
			SELECT 
				CrLf = NCHAR(13)+NCHAR(10)
		) V
END	


GO

EXEC sp_ms_marksystemobject sp_showcode
GO
EXEC sp_ms_marksystemobject sp_showcode_rc4decode
GO