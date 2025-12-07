/*#info 
	
	# autor 
		Rodrigo ribeiro Gomes 

	# descricao 

		Alguma query que devo ter usada uma ou outra vez pra obter os buckets de alguns caches.
		Query simples, mas mantive aqui para deixar a referência para a dmv de hash_tables que pode ser útil para alguma investigação relacionada ao uso do plan cache.


*/
SELECT DISTINCT
	 cht.cache_address
	,cht.name
	,cht.type
	,cht.buckets_count
FROM
	sys.dm_os_memory_cache_hash_tables cht
WHERE
	type IN ( 'CACHESTORE_OBJCP','CACHESTORE_SQLCP','CACHESTORE_PHDR','CACHESTORE_XPROC' )

