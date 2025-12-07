/*#info 

	# Autor 
		Rodrigo Ribeiro Gomes 
		
	# Descrição 
		Retorna informações sobre as transações que estão consumindo log em cada banco de dados.
		Script bem útil para identificar o porque um log de um banco ta em uso nesse momento e de qual transação vem.
*/


select 
	 ST.transaction_id
	,dt.database_id
	,NomeBanco = db_name(dt.database_id)
	,log_reuse_wait_desc
	,transaction_begin_time
	,database_transaction_begin_time
	,KBUsed = database_transaction_log_bytes_used/1024
	,LogCount = database_transaction_log_record_count
	,t.name
	,t.transaction_begin_time
	,st.session_id
from sys.dm_tran_database_transactions DT
JOIN
sys.dm_tran_session_transactions ST
	ON ST.transaction_id = DT.transaction_id
join
sys.dm_tran_active_transactions t
	on t.transaction_id = st.transaction_id
left join
sys.databases d
	on d.database_id = dt.database_id
