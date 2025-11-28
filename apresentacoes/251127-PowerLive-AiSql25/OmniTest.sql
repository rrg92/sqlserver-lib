alter PROCEDURE spOmniGetDate
AS
/*omni
description: Obtem a data atual!
*/

SELECT GETDATE()
go

alter PROCEDURE spOmniGetServerInfo
AS
/*omni
description: Obtem informacoes do servidor!
*/
SELECT 
	ServerName = @@SERVERNAME
	,Versao = @@VERSION
	,Ipserver = local_net_address
	,NomeMaquina = SERVERPROPERTY('ComputerNamePhysicalNetBios')
FROM
	sys.dm_exec_connections c
where
	c.session_id = @@SPID