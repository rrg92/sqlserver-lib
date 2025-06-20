/*#info 

	# Autor 
		Rodrigo Ribeiro Gomes 
		
	# Detalhes 
	
		Não lembro o motivo de ter criado isso, mas deve ter sido algum teste pontual.
		De qualquer maneira, deixando ai pois tem algumas sintaxes e comandos que podem ser úteis algum dia (mesmo que pra lembrar rápido)
*/

/*
	Uses following select to estimamte
*/
select *,MaxRollover = TotalRequiredSizeMB/SingleFileMB from (
select *,TotalRequiredSizeMB = ((Lsec*RetentionTime*BytesPerL)/1024.00/1024.00)*1.3 from (
select 
	 Lsec  = (pc.cntr_value*1.00/datediff(ss,i.sqlserver_start_time,current_timestamp))*2
	,BytesPerL = 15*1024
	,RetentionTime = 3600*24*7 -- 7days
	,SingleFileMB = 100
from sys.dm_os_performance_counters pc
	cross join sys.dm_os_sys_info i
	where counter_name like '%logins%'
) T
) e


CREATE SERVER AUDIT
	AuditLogins
TO
	FILE (
		FILEPATH  = 'D:\Traces\Audit'
		,MAXSIZE  = 100MB
		,MAX_ROLLOVER_FILES  = 600
	)
WHERE
	server_principal_name != 'LOGIN_AUDIT'
	OR
	succeeded = 0



CREATE SERVER AUDIT SPECIFICATION AuditAllLogins
FOR SERVER AUDIT AuditLogins
	ADD (FAILED_LOGIN_GROUP)
	,ADD(SUCCESSFUL_LOGIN_GROUP)
with (state = on)

  
ALTER SERVER AUDIT AuditLogins WITH(STATE = on)


select * from sys.dm_server_audit_status
	
select server_principal_name,statement
,convert(xml,additional_information)
,*
from sys.fn_get_audit_file('D:\Traces\Audit\AuditLogins_*.sqlaudit',null,null) af
join sys.dm_audit_class_type_map tm
	on tm.class_type = af.class_type
order by event_time desc

select * from 
xp_cmdshell 'del /q D:\Traces\Audit\*'
sp_configure 'xp_cmdshell',1
reconfigure


	