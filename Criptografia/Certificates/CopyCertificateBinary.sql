/*#info 

	# Autor 
		Rodrigo Ribeiro Gomes 
		
	# Descrição 
		Gera o comando para criar o certificado a partir do binário, em outro banco.
		Se o certificado for protegido por um password apenas , especifique a senha para incluir a private key.
		Se nao quiser incluir a private key, apenas deixe como string vazia.
		Se quiser incluir a private key, usando a key do banco, especifique NULL como cert password.
		
		Funcuona apenas no 2012+
		Baseadi em: https://learn.microsoft.com/en-us/sql/t-sql/functions/certencoded-transact-sql?view=sql-server-ver17#b-copying-a-certificate-to-another-database
*/


declare
	@CurrentCertPassword nvarchar(max) = ''

select
	'CREATE CERTIFICATE '+QUOTENAME(c.name)+' FROM BINARY = '+CONVERT(varchar(max),PublicKey,1)+CHAR(13)+CHAR(10)
	+ISNULL('WITH PRIVATE KEY( BINARY = '+CONVERT(varchar(max),PrivateKey,1)+', DECRYPTION BY PASSWORD = '''+DecryptPass+''' )','/* PRIVATE KEY NOT FOUND */')
from
	(
		select 
			DecryptPass = convert(Varchar(100),newid())
	) P
	cross apply
	(
		select 
			 PublicKey  = CERTENCODED(certificate_id)
			,PrivateKey = case when @CurrentCertPassword is null THEN CERTPRIVATEKEY(certificate_id,DecryptPass)
							else CERTPRIVATEKEY(certificate_id,DecryptPass,@CurrentCertPassword)
						  end 
			,c.name
		FROM	
			sys.certificates C
		WHERE
			C.name = '<NomeCertificado,,>'
	) C
