/*#info 
	# Autor
		Rodrigo Ribeiro Gomes 
		
	# Detalhes 
		Criptografia no SQL Server sempre foi um assunto bem "chato".
		Eu confesso que demorei pra começar a assimilar as coisas!
		
		Esse foi um dos primeiro scripts que criei para começar a entender como funcionava...
		Eu acredito até que tenha alguns pequenos equívicos, mas, ele é bem prático para aprender um pouco como usar algumas funções e comandos!
		
		Considere esse script como um pequeno Hello World de criptografia no SQL Sever...
		E na época que eu criei, nem existia AlwaysEncrypted ainda...
		

*/

--> Desmistificando a criptografia do SQL :D
USE master
GO

IF DB_ID('CriptoDB') IS NOT NULL
	DROP DATABASE CriptoDB;
GO

CREATE DATABASE
	CriptoDB
GO

USE CriptoDB
GO


--> Uma Tabelinha Para Exemplos ...
CREATE TABLE CriptTB( Codigo int identity primary key,Numero int,Secreto varchar(5) );


--> Alguns Usuários para a brincadeira...
CREATE LOGIN Ag007		WITH PASSWORD = 'agente';
CREATE LOGIN Intruso	WITH PASSWORD = 'intruso';

CREATE USER Ag007	FROM LOGIN Ag007;
CREATE USER Intruso	FROM LOGIN Intruso;

--> Algumas permissões
GRANT INSERT,SELECT,DELETE,UPDATE,ALTER ANY SCHEMA TO Ag007
GRANT SELECT TO Intruso;

--> Vamos logar com o Ag007
EXECUTE AS LOGIN = 'Ag007'
--> Ele precisa Inserir informações confidenciais ...
INSERT INTO CriptTB VALUES( 1, 'oi' );
SELECT * FROM CriptTB; --> Beleza ele consegegue ver os dados ...
REVERT

--> E um intruso ????
EXECUTE AS LOGIN = 'Intruso';
SELECT * FROM CriptTB; --> Merda ... ele também consegue ver os dados.
REVERT

--> Como resvolver ????
--> Considerando que Intruso consegiu a permissao de SELECT, ou tenha que ter esta...
--> CRIPTOGRAFIA ...


--> Inserindo os dados criptografados ...
--> EncryptByPassPhrase --> Simétrica, e usa um password.
EXECUTE AS LOGIN = 'Ag007' 
--> Demonstração ... precisa ser texto.
DECLARE
	@Codigo int
SET @Codigo  = 10000
print EncryptByPassPhrase('Palavra Secreta',CAST(@Codigo as varchar(max)))
--> Vamos alterar ...
UPDATE CriptTB SET Secreto = EncryptByPassPhrase('texto$forte',Secreto)
-- String or binary data would be truncated.
--O campo é pequeno demais ... Vamos alterar pra varbinary, e maior
ALTER TABLE CriptTB ALTER COLUMN Secreto varbinary(500)
--Implicit conversion from data type varchar to varbinary is not allowed. Use the CONVERT function to run this query.
--Opa, temos um grande problema de tipo de dados ...
--> Vamos criar outra coluna ...
ALTER TABLE CriptTB ADD SecretoVB varbinary(500)
--> Agora é so rodar o update, só que usando a coluna criada  ...
UPDATE CriptTB SET SecretoVB = EncryptByPassPhrase('texto$forte',Secreto)
--> Como está a tabela ?
SELECT * FROM CriptTB
--> Legal, agora é so sumir com a coluna Secreto e renomear a coluna CriptTB...
ALTER TABLE CriptTB DROP COLUMN Secreto;
EXEC sp_rename 'CriptTB.SecretoVB','Secreto','COLUMN'
--> Resultado 
SELECT * FROM CriptTB
--> Inserindo mais alguns dados ...
INSERT INTO CriptTB VALUES( 1, 'oi' );
--> Beleza, erro de conversao implicita, pois estamos tentando inserir texto em coluna binaria ...
--> Vamos inserir criptografado
INSERT INTO CriptTB VALUES( 14, EncryptByPassPhrase('texto$forte','oi') );
--> 1 row affected ...
SELECT * FROM CriptTB
--> E como descriptografar ???
SELECT Codigo,CAST( DecryptByPassPhrase('texto$forte',Secreto) AS varchar(max) ) FROM CriptTB
--> Resumo: Usar DecryptByPassPhrase,fornecer senha e converter ^^^)
--> E o intruso ??
REVERT

EXECUTE AS LOGIN = 'Intruso';
SELECT * FROM CriptTB; --> Agora ele n consegue ver  ...
--> Mas se ele descobrir a frase secreta poderá ver ??
SELECT Codigo,CAST( DecryptByPassPhrase('texto$forte',Secreto) AS varchar(max) ) FROM CriptTB
--> Resposta : SIMMMMM....
REVERT

--> Tirar a permissão ???
DENY EXECUTE ON DecryptByPassPhrase TO Intruso
--Cannot find the object 'DecryptByPassPhrase', because it does not exist or you do not have permission.
--> Usando outro método de permissão ... Objetos de Criptografia ...

--> EncryptByKey 
--> http://msdn.microsoft.com/en-us/library/ms174361(v=SQL.90).aspx
--> KEY_GUID ... Primeiro parâmetro da função ... onde conseguir ???
--> Temos que da permissao de criar chaves antes ...
GRANT ALTER ANY SYMMETRIC KEY TO Ag007
EXECUTE AS LOGIN = 'Ag007';
CREATE SYMMETRIC KEY --> Criamos um objeto que conterá as chaves simétrica necessárioas para a criptografia ...
	simk_ChaveSimetrica
AUTHORIZATION 
	Ag007 
WITH
	ALGORITHM = TRIPLE_DES 
ENCRYPTION BY PASSWORD = 'texto$forte'

-- Vamos ver o KEY_GUID
print Key_GUID('simk_ChaveSimetrica')
--> Beleza agora que temos um GUID ... vamos criptografar usando essa chave ...
UPDATE CriptTB SET Secreto = EncryptByKey(Key_GUID('simk_ChaveSimetrica'),Secreto)
--> Beleza, tudo criptografado :D
SELECT * FROM CriptTB
--> NULL ???????????????????????????????????????
--> Se a chave nao estiver sido aberta, então a função retornará NULL ... muito cuiado ...
print EncryptByKey(Key_GUID('simk_ChaveSimetrica'),'aaa')
--> Vamos abrir a chave ...
OPEN SYMMETRIC KEY simk_ChaveSimetrica DECRYPTION BY PASSWORD = 'texto$forte'
UPDATE CriptTB SET Secreto = EncryptByKey(Key_GUID('simk_ChaveSimetrica'),'oi')
--> Fechando a chave ...
CLOSE SYMMETRIC KEY simk_ChaveSimetrica
--> Pra ver as chaves abertas 
-- select * from sys.openkeys
--> E agora ??
SELECT * FROM CriptTB
--> Criptografados ...
--> Para ver os dados...
SELECT Codigo,DecryptByKey(Secreto) FROM CriptTB
--> NULL ?? Abra ...
OPEN SYMMETRIC KEY simk_ChaveSimetrica DECRYPTION BY PASSWORD = 'texto$forte'
SELECT Codigo,CAST( DecryptByKey(Secreto) AS varchar(300)) FROM CriptTB
--> Fechando a chave ...
CLOSE SYMMETRIC KEY simk_ChaveSimetrica
REVERT


-- E pra resolver o problema do Intruso, basta que essa nao tenha permissao para abrir a chave ...
--> Assim, mesmo conhecendo a senha, ele nao conseguirá abrir a chave, pois n tem permissão.
EXECUTE AS LOGIN = 'Intruso'
--> Vendo que está criptografado ...
SELECT Codigo,Secreto FROM CriptTB
--> Tentando abrir a chave
OPEN SYMMETRIC KEY simk_ChaveSimetrica DECRYPTION BY PASSWORD = 'texto$forte'
-- Cannot find the symmetric key 'simk_ChaveSimetrica', because it does not exist or you do not have permission.
SELECT Codigo,CAST( DecryptByKey(Secreto) AS varchar(300)) FROM CriptTB
REVERT



USE master
GO

DROP DATABASE
	CriptoDB
GO

