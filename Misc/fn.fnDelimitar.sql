/*#info
	# autor
		Rodrigo Ribeiro Gomes 

	# descricao 
		Uma funcao auxiliar que, dado uma string com separadores, adiciona delimitadores. Veja a doc da funcao e comentarios.
		Criei em 2011 e deixei originalmente para manter a minha lógica original (e que pode ser melhorada muitoa inda).
*/

USE model
GO

IF OBJECT_ID('dbo.fnDelimitar') IS NULL
	EXEC('CREATE FUNCTION dbo.fnDelimitar() RETURNS nvarchar(max) AS BEGIN RETURN 0; END')
GO


ALTER FUNCTION dbo.fnDelimitar
(
	 @str				NVARCHAR(MAX)
	,@DelimE			NVARCHAR(MAX)	= ''''
	,@DelimD			NVARCHAR(MAX)	= ''''	
	,@SeparadorDados	NVARCHAR(MAX)	= ','
	,@ManterSeparador	BIT				= 1
)
/***************************************************************************************
Descrição	:	Adiciona delimitadores no início e fim dos dados de uma string.
				Os dados sçao determinados pelo separador, isto é, a cada separador encontrado
				considera-se o fim do dado anterior,e início do proximo, se houver.
Parâmetros	:	@str			--> Texto a ser delimitado
				@DelimE			--> Contém o delimitador da esquerda de cada dado.
				@DelimD			--> Contém o delimitador da direita de cada dado.
				@SeparadorDados	--> Contém o separador dos dados.
				@ManterSeparador--> Se 1, então o separador será mantido na subsituição dos delimitadores.
									Caso contrário, o separador nao será mantido.
BANCO		:	Todos

HISTÓRICO
Desenvolvedor		Data				Abreviação			Descrição
Rodrigo Ribeiro		15/08/2011	16:54	--					Criação da FUNÇÃO.
Rodrigo Ribeiro		25/08/2011	09:39	RRG01-25082011		Adicionado o parâmetro @ManterSeparador.
**************************************************************************************/
RETURNS NVARCHAR(MAX)
AS
BEGIN

	DECLARE
		 @strDelim nvarchar(max)
		,@SeparadorSubst nvarchar(max) --> RRG01-25082011

	IF @DelimE IS NULL
		SET @DelimE = CHAR(0x27) --Aspas simples
	IF @DelimD IS NULL
		SET @DelimD = CHAR(0x27) --Aspa simples
	IF @SeparadorDados IS NULL
		SET @SeparadorDados = ','
		
	IF @ManterSeparador = 1
		SET @SeparadorSubst = @SeparadorDados;
	ELSE
		SET @SeparadorSubst = '';
		
	/*
		Passos:
			Como no inicio e no fim da string não não ha separadores, insere os delimitodres correspondentes em cada ponta,
			fazendo com o primeiro e último dados contenha os seus delimitadores corretos.
			Para cada separador encontrado, será substituido por um delimitador da direita (fechadno os limites do dado antes do separador)
			concatenado com o proprio separador e um delimitador da esquerda(Dando inicio ao limite do outro dado)
	*/
	SET @strDelim =	@DelimE
						+
					REPLACE( @str
							,@SeparadorDados
							,@DelimD
								+
							 @SeparadorSubst --> RRG01-25082011
								+
							 @DelimE
							)
						+
					@DelimD -- Abre o Delim da Esqerda e Fecha com o da direita
	
	RETURN @strDelim
END
