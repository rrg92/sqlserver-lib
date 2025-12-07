/*#info
	# autor 
		Rodrigo Ribeiro Gomes 

	# descricao 
		DMV dos memoru clerks.
		Cada clerk geralmente é um componente do sql que está aloando memória roubada do buffer pool ou direto do Windows!
		Os clerks que alocam memoria direto do Window, vão ter o valor nas colunas virtual_memory_*
		Os clerks que roubam da memoria do buffer pool, vão ter valor em pages_kb
		Os clerks que alocam usando o AWE, nas colunas awe_*

		Com isso vc consegue mapear e encontrar possiveis responsaveis por reduzir o cache de pginas do sql, ou identificar quem pode estar causando pressao alocanod "por fora" (Direto no sql)

*/

SELECT
	*
FROM
	sys.dm_os_memory_clerks mc