/*#info 
	
	# Autor
		Rodrigo Ribeiro Gomes 

	# Descricao 
		Info rápida sobre o IO dos arquivos.
		Como é um valor acumulado, pode não refletir a realidade, mas é um ponto de partida pra identificar algo fora de um padrão.


*/

SELECT
	 DB_NAME(vf.database_id)
	,MF.physical_name
	,vf.num_of_reads
	,vf.num_of_bytes_read
	,vf.io_stall_read_ms
	,vf.sample_ms
	,vf.num_of_reads/(vf.io_stall_read_ms/1000.00) AvgReadsPerSec
	,vf.num_of_bytes_read/(vf.io_stall_read_ms/1000.00) AvgReadsBytesPerSec
	,(vf.io_stall_read_ms/1000.00)/vf.num_of_reads SecsPerRead
FROM
	sys.dm_io_virtual_file_stats(null,null) vf
	LEFT JOIN
	sys.master_files MF
		on MF.database_id = VF.database_id
		and MF.file_id = VF.file_id
ORDER BY
	SecsPerRead DESC
