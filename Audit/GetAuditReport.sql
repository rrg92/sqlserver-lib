/*#info 

	# Autor 
		Rodrigo Ribeiro Gomes 
		
	# Detalhes 
		Um exemplo de query para consultar o audit de login
*/

USE master
GO

IF OBJECT_ID('tempdb..#AuditInfo') IS NOT NULL
	DROP TABLE #AuditInfo

;WITH XMLNAMESPACES(DEFAULT 'http://schemas.microsoft.com/sqlserver/2008/sqlaudit_data')
SELECT 
	*
INTO
	#AuditInfo
FROM (
	SELECT
		 Login = server_principal_name
		,[IP] = CONVERT(xml,additional_information).value('(action_info/address)[1]','varchar(100)')
		,Data = DATEADD(hh,-3,event_time)
		,Resultado = succeeded
		,Banco = isnull(nullif(database_name,''),p.default_database_name)
		,Msg = statement
	FROM 
		(
			select 
				pat = log_file_path+name+'*.sqlaudit' 
			From sys.server_file_audits
			WHERE name = 'AuditLogins'
		) AFP
		CROSS APPLY
		sys.fn_get_audit_file(AFP.pat,null,null) af
		join 
		sys.dm_audit_class_type_map tm
			ON tm.class_type = af.class_type 
		left join sys.server_principals p on p.name = server_principal_name
) V


select Login,IP,Banco
,Sucessos = count(case when Resultado = 1 then Data end) 
,Falhas = count(case when Resultado = 0 then Data end) 
from #AuditInfo ai
where Login  != ''
group by Login,IP,Banco

select Login,IP,Banco,Data,Msg 
from #AuditInfo ai
where Resultado = 0
ORDER BY Data