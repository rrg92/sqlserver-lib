/*#info 

	# Autor 
		Jesse Roberge - YeshuaAgapao@Yahoo.com
		
	# Detalhes 
		Proc que Lista os missing indexes.
		Não lembro se cheguei a usar, mas guardei aqui caso precisasse.
		
		
*/


SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
SET ANSI_PADDING ON
GO

IF OBJECT_ID('dbo.sp_Util_MissingIndexes', 'P') IS NOT NULL DROP PROCEDURE dbo.sp_Util_MissingIndexes
GO

/**
*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=
Util_MissingIndexes
By Jesse Roberge - YeshuaAgapao@Yahoo.com
Update 1:
	Fixed broken order by (data tyep conversion error) for @Sort=3, 4, and 5
Update 2:
	Added a missing 'sys.' name-part in the join to sys.dm_db_missing_index_details.  Was causing the proc to return no results on some peoples' systems.
	Also updated the description with the permission requirements and the effect of running without sufficient permissions.
Update 3 2009-01-14:
	Fixed Rows Output - Was being erroneously multiplied by (1+#NonClusteredIndexes)
		SUM(Rows) Should be SUM(CASE WHEN index_id BETWEEN 0 AND 1 THEN row_count ELSE 0 END)
	Added 'Last xxx' datetime columns to the result set
	Added @Delimiter parameter for the column listing output (Defaults to ,) for accomodating export to csv files.

Reports stats on what the query optimizer records in the DMVs as missing indexes and what it says the cost savings will be if they were present. Can limit by table / schema name patterns.
Requires the 'VIEW SERVER STATE' permission.  The sysadmin fixed server role has this permission.  dbo (datase owner) gives 'VIEW DATABASE STATE', which is not sufficient.  If you run this without sufficent permissions, you will get a empty result set.

Required Input Parameters
	none

Optional Input Parameters
	@SchemaName sysname=''		Filters schemas.  All schemas if blank.  Accepts LIKE Wildcards.
	@TableName sysname=''		Filters tables.  All tables if blank.  Accepts LIKE Wildcards.
	@Sort Tinyint=1				Determines what to sort the results by:
									Value	Sort Columns
									1		Score DESC, user_seeks DESC, avg_total_user_cost DESC
									2		Score ASC, user_seeks ASC, equality_columns ASC
									3		SchemaName ASC, TableName ASC, SeekColumns ASC
									4		SchemaName ASC, TableName ASC, Score DESC
									5		SchemaName ASC, TableName ASC, Score ASC

Usage:
	EXECUTE Util_MissingIndexes 'dbo', 'visit%', 1

Copyright:
	Licensed under the L-GPL - a weak copyleft license - you are permitted to use this as a component of a proprietary database and call this from proprietary software.
	Copyleft lets you do anything you want except plagarize, conceal the source, proprietarize modifications, or prohibit copying & re-distribution of this script/proc.

	This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU Lesser General Public License as
    published by the Free Software Foundation, either version 3 of the
    License, or (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU Lesser General Public License for more details.

    see <http://www.fsf.org/licensing/licenses/lgpl.html> for the license text.

*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=
**/

CREATE PROCEDURE dbo.sp_Util_MissingIndexes
	@SchemeName sysname='',
	@TableName sysname='',
	@Sort Tinyint=1,
	@Delimiter VarChar(1)=','
AS

SELECT
	sys.schemas.schema_id, sys.schemas.name AS schema_name,
	sys.objects.object_id, sys.objects.name AS object_name, sys.objects.type,
	partitions.Rows, partitions.SizeMB,
	CASE WHEN @Delimiter=',' THEN sys.dm_db_missing_index_details.equality_columns ELSE REPLACE(sys.dm_db_missing_index_details.equality_columns, ',', @Delimiter) END AS equality_columns,
	CASE WHEN @Delimiter=',' THEN sys.dm_db_missing_index_details.inequality_columns ELSE REPLACE(sys.dm_db_missing_index_details.inequality_columns, ',', @Delimiter) END AS inequality_columns,
	CASE WHEN @Delimiter=',' THEN sys.dm_db_missing_index_details.included_columns ELSE REPLACE(sys.dm_db_missing_index_details.included_columns, ',', @Delimiter) END AS included_columns,
	sys.dm_db_missing_index_group_stats.unique_compiles,
	sys.dm_db_missing_index_group_stats.user_seeks, sys.dm_db_missing_index_group_stats.user_scans,
	sys.dm_db_missing_index_group_stats.avg_total_user_cost, sys.dm_db_missing_index_group_stats.avg_user_impact,
	sys.dm_db_missing_index_group_stats.last_user_seek, sys.dm_db_missing_index_group_stats.last_user_scan,
	sys.dm_db_missing_index_group_stats.system_seeks, sys.dm_db_missing_index_group_stats.system_scans,
	sys.dm_db_missing_index_group_stats.avg_total_system_cost, sys.dm_db_missing_index_group_stats.avg_system_impact,
	sys.dm_db_missing_index_group_stats.last_system_seek, sys.dm_db_missing_index_group_stats.last_system_scan,
	(CONVERT(Numeric(19,6), sys.dm_db_missing_index_group_stats.user_seeks)+CONVERT(Numeric(19,6), sys.dm_db_missing_index_group_stats.unique_compiles))*CONVERT(Numeric(19,6), sys.dm_db_missing_index_group_stats.avg_total_user_cost)*CONVERT(Numeric(19,6), sys.dm_db_missing_index_group_stats.avg_user_impact/100.0) AS Score
FROM
	sys.objects
	JOIN (
		SELECT
			object_id, SUM(CASE WHEN index_id BETWEEN 0 AND 1 THEN row_count ELSE 0 END) AS Rows,
			CONVERT(numeric(19,3), CONVERT(numeric(19,3), SUM(in_row_reserved_page_count+lob_reserved_page_count+row_overflow_reserved_page_count))/CONVERT(numeric(19,3), 128)) AS SizeMB
		FROM sys.dm_db_partition_stats
		WHERE sys.dm_db_partition_stats.index_id BETWEEN 0 AND 1 --0=Heap; 1=Clustered; only 1 per table
		GROUP BY object_id
	) AS partitions ON sys.objects.object_id=partitions.object_id
	JOIN sys.schemas ON sys.objects.schema_id=sys.schemas.schema_id
	JOIN sys.dm_db_missing_index_details ON sys.objects.object_id=dm_db_missing_index_details.object_id
	JOIN sys.dm_db_missing_index_groups ON sys.dm_db_missing_index_details.index_handle=sys.dm_db_missing_index_groups.index_handle
	JOIN sys.dm_db_missing_index_group_stats ON sys.dm_db_missing_index_groups.index_group_handle=sys.dm_db_missing_index_group_stats.group_handle
WHERE
	sys.dm_db_missing_index_details.database_id=DB_ID()
	AND sys.schemas.name LIKE CASE WHEN @SchemeName='' THEN sys.schemas.name ELSE @SchemeName END
	AND sys.objects.name LIKE CASE WHEN @TableName='' THEN sys.objects.name ELSE @TableName END
ORDER BY
	CASE @Sort
		WHEN 1 THEN
			(CONVERT(Numeric(19,6), sys.dm_db_missing_index_group_stats.user_seeks)+CONVERT(Numeric(19,6), sys.dm_db_missing_index_group_stats.unique_compiles))*CONVERT(Numeric(19,6), sys.dm_db_missing_index_group_stats.avg_total_user_cost)*CONVERT(Numeric(19,6), sys.dm_db_missing_index_group_stats.avg_user_impact/100.0)*-1
		WHEN 2 THEN
			(CONVERT(Numeric(19,6), sys.dm_db_missing_index_group_stats.user_seeks)+CONVERT(Numeric(19,6), sys.dm_db_missing_index_group_stats.unique_compiles))*CONVERT(Numeric(19,6), sys.dm_db_missing_index_group_stats.avg_total_user_cost)*CONVERT(Numeric(19,6), sys.dm_db_missing_index_group_stats.avg_user_impact/100.0)
		ELSE NULL
	END,
	CASE @Sort
		WHEN 3 THEN sys.schemas.name
		WHEN 4 THEN sys.schemas.name
		WHEN 5 THEN sys.schemas.name
		ELSE NULL
	END,
	CASE @Sort
		WHEN 1 THEN sys.dm_db_missing_index_group_stats.user_seeks*-1
		WHEN 2 THEN sys.dm_db_missing_index_group_stats.user_seeks
	END,
	CASE @Sort
		WHEN 3 THEN sys.objects.name
		WHEN 4 THEN sys.objects.name
		WHEN 5 THEN sys.objects.name
		ELSE NULL
	END,
	CASE @Sort
		WHEN 1 THEN sys.dm_db_missing_index_group_stats.avg_total_user_cost*-1
		WHEN 2 THEN sys.dm_db_missing_index_group_stats.avg_total_user_cost
		WHEN 4 THEN
			(CONVERT(Numeric(19,6), sys.dm_db_missing_index_group_stats.user_seeks)+CONVERT(Numeric(19,6), sys.dm_db_missing_index_group_stats.unique_compiles))*CONVERT(Numeric(19,6), sys.dm_db_missing_index_group_stats.avg_total_user_cost)*CONVERT(Numeric(19,6), sys.dm_db_missing_index_group_stats.avg_user_impact/100.0)*-1
		WHEN 5 THEN
			(CONVERT(Numeric(19,6), sys.dm_db_missing_index_group_stats.user_seeks)+CONVERT(Numeric(19,6), sys.dm_db_missing_index_group_stats.unique_compiles))*CONVERT(Numeric(19,6), sys.dm_db_missing_index_group_stats.avg_total_user_cost)*CONVERT(Numeric(19,6), sys.dm_db_missing_index_group_stats.avg_user_impact/100.0)
		ELSE NULL
	END,
	CASE @Sort
		WHEN 3 THEN sys.dm_db_missing_index_details.equality_columns
		ELSE NULL
	END
GO
--*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=
GO

sp_ms_marksystemobject sp_Util_MissingIndexes