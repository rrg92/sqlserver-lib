 /*#info 

	# Autor 
		Rodrigo Ribeiro Gomes 
		
	# Descrição 
		Lista as transacoes abertas há mais de um determinado periodo, em segundos.
*/

DECLARE
	@Data	datetime
;
SET @Data	= DATEADD(ss,-120,getDate()) --> Transacoes aberta há mais de 120s por padrao (2min)
 
SELECT
	 tst.session_id
	,tst.transaction_id
	,tat.transaction_begin_time	
	,DATEDIFF(ss,tat.transaction_begin_time,@Data) as SegsExec
	,s.host_name 
FROM
sys.dm_tran_session_transactions	tst
join
sys.dm_tran_active_transactions		tat ON tat.transaction_id = tst.transaction_id
left join sys.dm_exec_sessions s    on s.session_id = tst.session_id 
WHERE
	tat.transaction_begin_time <= @Data
