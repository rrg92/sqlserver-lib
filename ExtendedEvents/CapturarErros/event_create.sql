/*#info 

	# Autor 
		Rodrigo Ribeiro Gomes 
		
	# Detalhes 
		EXtended events para capturar erros.
		Acho que foi um dos primeiros que criei, na epoca do 2008 ainda
		Por isso vários selects em algumas dmvs, estava descobrindo algumas infos.
*/

-- Vamos criar uma Event Session para capturar o eventos relacionados a erros que ocorrem no ambiente...

CREATE EVENT SESSION
    SQLServerErros
ON SERVER
	ADD 
		EVENT 
			sqlserver.error_reported
			(
				ACTION ( sqlserver.sql_text
						,sqlserver.tsql_stack 
						,sqlserver.database_id
						,sqlserver.username
						,sqlserver.client_hostname
				)
			
				WHERE (
					severity > 10  --> Somente erros com severidace acima 10!
					AND
					sqlserver.database_id = 58
				)
			)
	ADD
		TARGET
			package0.ring_buffer
			(
				SET 
					max_memory = 1000

			)
			

select * from sys.dm_xe_packages where guid = '655FD93F-3364-40D5-B2BA-330F7FFB6491'
select * from sys.dm_Xe_objects where name like '%error_reported%'
select * from sys.dm_xe_object_columns where object_name like '%error_reported%'
--select name,description,(select p.name from sys.dm_xe_packages p where guid = package_guid) from sys.dm_xe_objects where object_type = 'target'
--select * from sys.dm_xe_object_columns where object_name = 'ring_buffer'

--ADD TARGET package0.asynchronous_file_target
--(set filename = 'c:\erros.xel' ,
--    metadatafile = 'c:\erros.xem',
--    max_file_size = 5,
--    max_rollover_files = 5)
--WITH (MAX_DISPATCH_LATENCY = 5SECONDS)
GO

ALTER EVENT SESSION SQLServerErros
    ON SERVER STATE = start
GO


-- Stop your Extended Events session
ALTER EVENT SESSION SQLServerErros ON SERVER
STATE = STOP;
GO
 
-- Clean up your session from the server
DROP EVENT SESSION SQLServerErros ON SERVER;
GO
