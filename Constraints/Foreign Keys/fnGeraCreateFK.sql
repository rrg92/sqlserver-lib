/*#info 

	# Autor 
		Rodrigo Ribeiro Gomes 

	# Detalhes 
		Gera o create de foreign keys.

	
*/

IF object_id('dbo.fnGeraCreateFK') IS NULL
	EXEC('CREATE FUNCTION dbo.fnGeraCreateFK() RETURNS varchar(max) AS BEGIN RETURN 0 END')
GO

ALTER FUNCTION dbo.fnGeraCreateFK
(
	  @NomeDaFK varchar(500)
	 ,@Checar	bit
)
RETURNS VARCHAR(MAX)
AS
BEGIN
	DECLARE
		 @tSQLIni	varchar(max)
		,@ColunasQr varchar(max)
		,@ColunasR varchar(max)
		,@tSQLfim	varchar(max)
		,@tSQL		varchar(max)
	;
	
	SET @tSQLIni	= '';
	SET @ColunasQr	= '';
	SET @ColunasR	= '';

	WITH FKs AS --> Usando CTe para montar uma tabela com nomes de colunas fáceis
	(
		SELECT DISTINCT
			 fk.object_id							fkID
			,fk.name								NomeDaFK
			,object_name(fk.parent_object_id)		ObjetoQReferencia
			,c.name									ColunaQReferencia
			,object_name(fk.referenced_object_id)	ObjetoReferenciado
			,c2.name								ColunaReferenciada
			,fkc.constraint_column_id				Ordem
			,CASE delete_referential_action
				WHEN 0 THEN 'NO ACTION'
				WHEN 1 THEN 'CASCADE'
				WHEN 2 THEN 'SET NULL'
				WHEN 3 THEN 'SET DEFAULT'
			END										OnDelete
			,CASE update_referential_action
				WHEN 0 THEN 'NO ACTION'
				WHEN 1 THEN 'CASCADE'
				WHEN 2 THEN 'SET NULL'
				WHEN 3 THEN 'SET DEFAULT'
			END										OnUpdate
			,CASE is_not_for_replication
				WHEN 1 THEN 'NOT FOR REPLICATION'
				ELSE ''
			 END									NotForReplication
		FROM 
						sys.foreign_keys			fk
			INNER JOIN	sys.foreign_key_columns		fkc on	fkc.constraint_object_id	= fk.object_id
			INNER JOIN	sys.columns					c	on	c.column_id					= fkc.parent_column_id
														and	c.object_id					= fk.parent_object_id
			INNER JOIN	sys.columns					c2	on	c2.column_id				= fkc.referenced_column_id
														and c2.object_id				= fk.referenced_object_id
		WHERE 
			fk.object_id = object_id(@NomeDaFk)
	)
	--> Percorrendo cada linha usando o SELECT
	SELECT
		@tSQLIni = @tSQLIni 
		+
		
		CASE @tSQLIni --> Verificando o valor da variável, e caso seja vazio add o cabeçalho ...
			WHEN  '' THEN 'ALTER TABLE '+ObjetoQReferencia+
				CASE --> Verificando a opção de checagem
					WHEN @Checar IS NULL THEN ''
					WHEN @Checar = 1	 THEN ' WITH CHECK '
					WHEN @Checar = 0	 THEN ' WITH NOCHECK '
				END
				+' ADD CONSTRAINT '+NomeDaFK
			ELSE ''
		END 
		
		,@ColunasQr = @ColunasQr + --> Se for vazio, então adiciona a cláusula para as colunas que referenciam.
			CASE @ColunasQr
				WHEN '' THEN ' FOREIGN KEY('
				ELSE ''
			END 
			+
			ColunaQReferencia + ',' --> Concatena cada coluna que referencia separando-as por vírgula
			
		,@ColunasR = @ColunasR +
			CASE @ColunasR --> Se for vazio, então adiciona a clausula para as colunas referenciadas
				WHEN '' THEN ' REFERENCES '+ObjetoReferenciado+'('
				ELSE ''
			END
			+
			ColunaReferenciada + ',' --> Concatena cada coluna referenciada separando por vírgula
			
		--> Gerando a clausula final para constraints...	
		,@tSQLfim = 'ON DELETE '+OnDelete+' ON UPDATE '+OnUpdate+' '+NotForReplication
	FROM
		FKs
	ORDER BY
		 fkID
		,Ordem
		
	-- Deleta a vírgula no final e coloca um parênteses
	SET @ColunasQR = STUFF( @ColunasQR, LEN(@ColunasQR),1,')' );
	SET @ColunasR = STUFF( @ColunasR, LEN(@ColunasR),1,')' );

	--> Gera o código final de acordo com as configurações, gerando o create.
	SET @tSQL = @tSQLIni + @ColunasQR + @ColunasR + @tSQLfim
		
	RETURN @tSQL
END
GO