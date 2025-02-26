/*#info 
	
	# autor 
		Rodrigo Ribeiro Gomes

	# Detalhes
		Isso script foi uma leve brinacadeira para responder o post do Erik Darlking
		Eu mantive ele aqui apenas pela ideia de você pode executar coisas no proprio servidor, em outra sessao, apenas com t-sql
		Nao me lembro onde isso possa ser útil no dia a dia, mas, vai que tem algum maluco ai!

		Post do Erik:
			https://www.linkedin.com/posts/erik-darling-data_mind-your-business-sql-activity-7300627709641015297-OCqo
*/

declare @Me varchar(10) = @@spid 
declare @killMe varchar(100) = 'kill '+@me;

-- exec sp_dropserver 'Fuckill'
EXEC sp_addlinkedserver @server = N'Fuckill',@srvproduct=N''
					,@provider=N'SQLNCLI11',@datasrc=@@SERVERNAME,@catalog=N'master'
exec sp_serveroption 'Fuckill',N'rpc','true';
exec sp_serveroption 'Fuckill',N'rpc out','true';
EXEC sp_addlinkedsrvlogin N'Fuckill', @locallogin = NULL , @useself = N'True', @rmtuser = N''

select @@spid
exec(@killMe) at Fuckill

