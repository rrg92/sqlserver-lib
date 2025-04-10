/*#info 

	# Autor 
		Rodrigo Ribeiro Gomes 
		
	# Descrição 
		Script para testar o envio de mail usando database mail.
		O teste é um simples envio. Ajuste o nome do profile e o email nos parâmetros abaixo.
		

*/

IF OBJECT_ID('msdb.dbo.sp_send_dbmail') IS  NULL
	RETURN;
	
DECLARE @HtmlFinal nvarchar(4000);

SET @HtmlFinal = N'
	Este email foi enviado como um teste do servidor: <b>'+CONVERT(nvarchar(500),@@SERVERNAME)+',</b>
'

EXEC msdb.dbo.sp_send_dbmail
	 @profile_name = 'Nome do profile'
	,@recipients = 'COLOQUE O EMAIL DE DESTINO AQUI'
	,@subject = N'TESTE DATABASE MAIL'
	,@body = @HtmlFinal
	,@body_format = 'HTML'


