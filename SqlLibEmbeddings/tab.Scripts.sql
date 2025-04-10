-- For Azure SQL Database or SQL Server 2025+

-- drop table Scripts;
CREATE TABLE Scripts (
	 id int IDENTITY PRIMARY KEY WITH(DATA_COMPRESSION = PAGE)
	,RelPath varchar(1000) NOT NULL
	,ChunkNum int NOT NULL
	,ChunkContent nvarchar(max) NOT NULL
	,embeddings vector(1024)
)


