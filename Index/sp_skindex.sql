/*#info 

	# Autor 
		Paul Randal + Kimberly L. Tripp 
		
	# Detalhes 
	
		Este não é um script criado por mim, mas eu guardei na "maleta" para facilmente ter acesso.
		Quem criou foram os famosos Paul Randal e Kimberly Tripp...
		
		É uma versão melhorada da sp_helpindex. 
		Eu guardei aqui junto pois achei o método de instalação original deles um pouco complexo e difícil de achar.
		
		E outro ajuste que fiz foi renomear a proc pra sp_skindex (não lembro pq escolhi o sk ali, mas fica fácil).
		Assim, você, criando isso qui na master, de qualquer banco você pode rodar um :
		
			sp_skindex 'NomeTabela'.
		
		Isso vai trazer informações preciosas sobre os índices.
		LEMBRANDO: TODO O CRÉDITO DESSE SCRIPT É DO PESSOAL DA SQLSKILLS.com
		
		Links de referencia:
			https://www.sqlskills.com/blogs/kimberly/use-these-updates-to-sqlskills-index-procedures/
			https://www.sqlskills.com/blogs/kimberly/category/sp_helpindex-rewrites/

*/


/*============================================================================
  File:     sp_SQLskills_ExposeColsInIndexLevels

  Summary:  This procedure lists columns in the key vs. those in the leaf level
			of a nonclustered index. This is dependent on whether or not the 
			nonclustered is UNIQUE as well as whether or not the table has a 
			clustered index. It also changes based on whether or not the 
			clustering key is UNIQUE.
			
  Date:     May 2010

  Version:	SQL Server 2005/2008
------------------------------------------------------------------------------
  Written by Paul S. Randal and Kimberly L. Tripp, SQLskills.com

  For more scripts and sample code, check out 
    http://www.SQLskills.com

  This script is intended only as a supplement to demos and lectures
  given by SQLskills instructors.  
  
  THIS CODE AND INFORMATION ARE PROVIDED "AS IS" WITHOUT WARRANTY OF 
  ANY KIND, EITHER EXPRESSED OR IMPLIED, INCLUDING BUT NOT LIMITED 
  TO THE IMPLIED WARRANTIES OF MERCHANTABILITY AND/OR FITNESS FOR A
  PARTICULAR PURPOSE.
============================================================================*/]





USE master
go

if OBJECTPROPERTY(OBJECT_ID('sp_SQLskills_ExposeColsInIndexLevels'), 'IsProcedure') = 1
	drop procedure sp_SQLskills_ExposeColsInIndexLevels
go

create procedure sp_SQLskills_ExposeColsInIndexLevels 
(
	@object_id int,
	@index_id int,
	@ColsInTree nvarchar(2126) OUTPUT,
	@ColsInLeaf nvarchar(max) OUTPUT
)
AS
BEGIN
	declare @nonclus_uniq int
			, @column_id int
			, @column_name nvarchar(260)
			, @col_descending bit
			, @colstr	nvarchar (max);

	-- Get clustered index keys (id and name)
	select sic.column_id, QUOTENAME(sc.name, N']') AS column_name, is_descending_key
	into #clus_keys 
	from sys.index_columns AS sic
		JOIN sys.columns AS sc
			ON sic.column_id = sc.column_id AND sc.object_id = sic.object_id
	where sic.[object_id] = @object_id
	and [index_id] = 1;
	
	-- Get nonclustered index keys
	select sic.column_id, sic.is_included_column, QUOTENAME(sc.name, N']') AS column_name, is_descending_key
	into #nonclus_keys 
	from sys.index_columns AS sic
		JOIN sys.columns AS sc
			ON sic.column_id = sc.column_id 
				AND sc.object_id = sic.object_id
	where sic.[object_id] = @object_id
		and sic.[index_id] = @index_id;
		
	-- Is the nonclustered unique?
	select @nonclus_uniq = is_unique 
	from sys.indexes
	where [object_id] = @object_id
		and [index_id] = @index_id;

	if (@nonclus_uniq = 0)
	begin
		-- Case 1: nonunique nonclustered index

		-- cursor for nonclus columns not included and
		-- nonclus columns included but also clus keys
		declare mycursor cursor for
			select column_id, column_name, is_descending_key  
			from #nonclus_keys
			where is_included_column = 0
		open mycursor;
		fetch next from mycursor into @column_id, @column_name, @col_descending;
		WHILE @@FETCH_STATUS = 0
		begin
			select @colstr = ISNULL(@colstr, N'') + @column_name + CASE WHEN @col_descending = 1 THEN '(-)' ELSE N'' END + N', ';
			fetch next from mycursor into @column_id, @column_name, @col_descending;
		end
		close mycursor;
		deallocate mycursor;
		
		-- cursor over clus_keys if clustered
		declare mycursor cursor for
			select column_id, column_name, is_descending_key from #clus_keys
			where column_id not in (select column_id from #nonclus_keys
				where is_included_column = 0)
		open mycursor;
		fetch next from mycursor into @column_id, @column_name, @col_descending;
		WHILE @@FETCH_STATUS = 0
		begin
			select @colstr = ISNULL(@colstr, N'') + @column_name + CASE WHEN @col_descending = 1 THEN '(-)' ELSE N'' END + N', ';
			fetch next from mycursor into @column_id, @column_name, @col_descending;
		end
		close mycursor;
		deallocate mycursor;	
		
		select @ColsInTree = substring(@colstr, 1, LEN(@colstr) -1);
			
		-- find columns not in the nc and not in cl - that are still left to be included.
		declare mycursor cursor for
			select column_id, column_name, is_descending_key from #nonclus_keys
			where column_id not in (select column_id from #clus_keys UNION select column_id from #nonclus_keys where is_included_column = 0)
		open mycursor;
		fetch next from mycursor into @column_id, @column_name, @col_descending;
		WHILE @@FETCH_STATUS = 0
		begin
			select @colstr = ISNULL(@colstr, N'') + @column_name + CASE WHEN @col_descending = 1 THEN '(-)' ELSE N'' END + N', ';
			fetch next from mycursor into @column_id, @column_name, @col_descending;
		end
		close mycursor;
		deallocate mycursor;	
		
		select @ColsInLeaf = substring(@colstr, 1, LEN(@colstr) -1);
		
	end

	-- Case 2: unique nonclustered
	else
	begin
		-- cursor over nonclus_keys that are not includes
		select @colstr = ''
		declare mycursor cursor for
			select column_id, column_name, is_descending_key from #nonclus_keys
			where is_included_column = 0
		open mycursor;
		fetch next from mycursor into @column_id, @column_name, @col_descending;
		WHILE @@FETCH_STATUS = 0
		begin
			select @colstr = ISNULL(@colstr, N'') + @column_name + CASE WHEN @col_descending = 1 THEN '(-)' ELSE N'' END + N', ';
			fetch next from mycursor into @column_id, @column_name, @col_descending;
		end
		close mycursor;
		deallocate mycursor;
		
		select @ColsInTree = substring(@colstr, 1, LEN(@colstr) -1);
	
		-- start with the @ColsInTree and add remaining columns not present...
		declare mycursor cursor for
			select column_id, column_name, is_descending_key from #nonclus_keys 
			WHERE is_included_column = 1;
		open mycursor;
		fetch next from mycursor into @column_id, @column_name, @col_descending;
		WHILE @@FETCH_STATUS = 0
		begin
			select @colstr = ISNULL(@colstr, N'') + @column_name + CASE WHEN @col_descending = 1 THEN '(-)' ELSE N'' END + N', ';
			fetch next from mycursor into @column_id, @column_name, @col_descending;
		end
		close mycursor;
		deallocate mycursor;

		-- get remaining clustered column as long as they're not already in the nonclustered
		declare mycursor cursor for
			select column_id, column_name, is_descending_key from #clus_keys
			where column_id not in (select column_id from #nonclus_keys)
		open mycursor;
		fetch next from mycursor into @column_id, @column_name, @col_descending;
		WHILE @@FETCH_STATUS = 0
		begin
			select @colstr = ISNULL(@colstr, N'') + @column_name + CASE WHEN @col_descending = 1 THEN '(-)' ELSE N'' END + N', ';
			fetch next from mycursor into @column_id, @column_name, @col_descending;
		end
		close mycursor;
		deallocate mycursor;	

		select @ColsInLeaf = substring(@colstr, 1, LEN(@colstr) -1);
		select @colstr = ''
	
	end
	-- Cleanup
	drop table #clus_keys;
	drop table #nonclus_keys;
	
END;
GO

exec sys.sp_MS_marksystemobject 'sp_SQLskills_ExposeColsInIndexLevels'
go

/*============================================================================
  File:     sp_skindex.sql

  Summary:  So, what are the included columns?! Do you have a filter?
			This is a MODIFIED sp_helpindex script that includes:
               - Index IDs
               - INCLUDEd columns
               - Filtered index columns
               - Leaf/tree details for rowstore indexes
               - Columns defined for columnstore indexes
            Additional details:
               - whether or not the index is disabled
               - Index usage stats

  Date:     February 2016

  Version:  Works on 2008R2 - 2016 (requires: sp_SQLskills_ExposeColsInIndexLevels)
------------------------------------------------------------------------------
  Written by Kimberly L. Tripp, SYSolutions, Inc.

  For more scripts and sample code, check out 
    http://www.SQLskills.com

  This script is intended only as a supplement to demos and lectures
  given by SQLskills instructors.  
  
  THIS CODE AND INFORMATION ARE PROVIDED "AS IS" WITHOUT WARRANTY OF 
  ANY KIND, EITHER EXPRESSED OR IMPLIED, INCLUDING BUT NOT LIMITED 
  TO THE IMPLIED WARRANTIES OF MERCHANTABILITY AND/OR FITNESS FOR A
  PARTICULAR PURPOSE.
============================================================================*/

USE [master];
GO

IF OBJECTPROPERTY(OBJECT_ID(N'sp_skindex')
		, N'IsProcedure') = 1
	DROP PROCEDURE [dbo].[sp_skindex];
GO

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE PROCEDURE [dbo].[sp_skindex]
	@objname nvarchar(776)		-- the table to check for indexes
as

--     June 2016: Support for clustered columnstore as well as removing
--                errors around other index types (hekaton, XML, spatial, etc.)
--September 2013: Correct the output for columnstore indexes.
-- November 2010: Added a column to show if an index is disabled.
--      May 2010: Added tree/leaf columns to the output - this requires the 
--                stored procedure: sp_SQLskills_ExposeColsInIndexLevels
--    March 2010: Added index_id to the output (ordered by index_id as well)
--   August 2008: Fixed a bug (missing begin/end block) AND I found
--                a few other issues that people hadn't noticed (yikes!)!
--    April 2008: Updated to add included columns to the output. 


-- See my blog for updates and/or additional information
-- http://www.SQLskills.com/blogs/Kimberly (Kimberly L. Tripp)

	set nocount on

	declare @objid int,				-- the object id of the table
			@indid smallint,		-- the index id of an index
			@type tinyint,			-- the index type
			@groupid int,  			-- the filegroup id of an index
			@indname sysname,
			@groupname sysname,
			@status int,
			@keys nvarchar(2126),	--Length (16*max_identifierLength)+(15*2)+(16*3)
			@inc_columns nvarchar(max),
			@inc_Count smallint,
			@loop_inc_Count smallint,
			@dbname	sysname,
			@ignore_dup_key	bit,
			@is_unique bit,
			@is_hypothetical bit,
			@is_primary_key	bit,
			@is_unique_key bit,
			@is_disabled bit,
			@auto_created bit,
			@no_recompute bit,
			@filter_definition nvarchar(max),
			@ColsInTree nvarchar(2126),
			@ColsInLeaf nvarchar(max),
            @ExecStr nvarchar(max)

	-- Check to see that the object names are local to the current database.
	select @dbname = parsename(@objname,3)
	if @dbname is null
		select @dbname = db_name()
	else if @dbname <> db_name()
		begin
			raiserror(15250,-1,-1)
			return (1)
		end

	-- Check to see the the table exists and initialize @objid.
	select @objid = object_id(@objname)
	if @objid is NULL
	begin
		raiserror(15009,-1,-1,@objname,@dbname)
		return (1)
	end

	-- OPEN CURSOR OVER INDEXES (skip stats: bug shiloh_51196)
	declare ms_crs_ind cursor local static for
		select i.index_id, i.[type], i.data_space_id, QUOTENAME(i.name, N']') AS name,
			i.ignore_dup_key, i.is_unique, i.is_hypothetical, i.is_primary_key, i.is_unique_constraint,
			s.auto_created, s.no_recompute, i.filter_definition, i.is_disabled
		from sys.indexes as i 
			join sys.stats as s
				on i.object_id = s.object_id 
					and i.index_id = s.stats_id
		where i.object_id = @objid
	open ms_crs_ind
	fetch ms_crs_ind into @indid, @type, @groupid, @indname, @ignore_dup_key, @is_unique, @is_hypothetical,
			@is_primary_key, @is_unique_key, @auto_created, @no_recompute, @filter_definition, @is_disabled

	-- IF NO INDEX, QUIT
	if @@fetch_status < 0
	begin
		deallocate ms_crs_ind
		raiserror(15472,-1,-1,@objname) -- Object does not have any indexes.
		return (0)
	end

	-- create temp tables
	CREATE TABLE #spindtab
	(
		index_name			sysname	collate database_default NOT NULL,
		index_id			int,
		[type]				tinyint,
		ignore_dup_key		bit,
		is_unique			bit,
		is_hypothetical		bit,
		is_primary_key		bit,
		is_unique_key		bit,
		is_disabled         bit,
		auto_created		bit,
		no_recompute		bit,
		groupname			sysname collate database_default NULL,
		index_keys			nvarchar(2126)	collate database_default NULL, -- see @keys above for length descr
		filter_definition	nvarchar(max),
		inc_Count			smallint,
		inc_columns			nvarchar(max),
		cols_in_tree		nvarchar(2126),
		cols_in_leaf		nvarchar(max)
	)

	CREATE TABLE #IncludedColumns
	(	RowNumber	smallint,
		[Name]	nvarchar(128)
	)

	-- Now check out each index, figure out its type and keys and
	--	save the info in a temporary table that we'll print out at the end.
	while @@fetch_status >= 0
	begin
		-- First we'll figure out what the keys are.
		declare @i int, @thiskey nvarchar(131) -- 128+3

		select @keys = QUOTENAME(index_col(@objname, @indid, 1), N']'), @i = 2
		if (indexkey_property(@objid, @indid, 1, 'isdescending') = 1)
			select @keys = @keys  + '(-)'

		select @thiskey = QUOTENAME(index_col(@objname, @indid, @i), N']')
		if ((@thiskey is not null) and (indexkey_property(@objid, @indid, @i, 'isdescending') = 1))
			select @thiskey = @thiskey + '(-)'

		while (@thiskey is not null )
		begin
			select @keys = @keys + ', ' + @thiskey, @i = @i + 1
			select @thiskey = QUOTENAME(index_col(@objname, @indid, @i), N']')
			if ((@thiskey is not null) and (indexkey_property(@objid, @indid, @i, 'isdescending') = 1))
				select @thiskey = @thiskey + '(-)'
		end

		-- Second, we'll figure out what the included columns are.
		select @inc_columns = NULL
		
		SELECT @inc_Count = count(*)
		FROM sys.tables AS tbl
		INNER JOIN sys.indexes AS si 
			ON (si.index_id > 0 
				and si.is_hypothetical = 0) 
				AND (si.object_id=tbl.object_id)
		INNER JOIN sys.index_columns AS ic 
			ON (ic.column_id > 0 
				and (ic.key_ordinal > 0 or ic.partition_ordinal = 0 or ic.is_included_column != 0)) 
				AND (ic.index_id=CAST(si.index_id AS int) AND ic.object_id=si.object_id)
		INNER JOIN sys.columns AS clmns 
			ON clmns.object_id = ic.object_id 
			and clmns.column_id = ic.column_id
		WHERE ic.is_included_column = 1 and
			(si.index_id = @indid) and 
			(tbl.object_id= @objid)

		IF @inc_Count > 0
		BEGIN
			DELETE FROM #IncludedColumns
			INSERT #IncludedColumns
				SELECT ROW_NUMBER() OVER (ORDER BY clmns.column_id) 
				, clmns.name 
				FROM sys.tables AS tbl
				INNER JOIN sys.indexes AS si 
					ON (si.index_id > 0 
						AND si.is_hypothetical = 0) 
						AND (si.object_id=tbl.object_id)
				INNER JOIN sys.index_columns AS ic 
					ON (ic.column_id > 0 
						AND (ic.key_ordinal > 0 OR ic.partition_ordinal = 0 OR ic.is_included_column != 0)) 
						AND (ic.index_id=CAST(si.index_id AS int) AND ic.object_id=si.object_id)
				INNER JOIN sys.columns AS clmns 
					ON clmns.object_id = ic.object_id 
					AND clmns.column_id = ic.column_id
				WHERE ic.is_included_column = 1 AND
					(si.index_id = @indid) AND 
					(tbl.object_id= @objid)
			
			SELECT @inc_columns = QUOTENAME([Name], N']') 
            FROM #IncludedColumns 
            WHERE RowNumber = 1

			SET @loop_inc_Count = 1

			WHILE @loop_inc_Count < @inc_Count
			BEGIN
				SELECT @inc_columns = @inc_columns + ', ' + QUOTENAME([Name], N']') 
					FROM #IncludedColumns WHERE RowNumber = @loop_inc_Count + 1
				SET @loop_inc_Count = @loop_inc_Count + 1
			END
		END
	
		SELECT @groupname = null

		SELECT @groupname = name 
        FROM sys.data_spaces 
        WHERE data_space_id = @groupid

		-- Get the column list for the tree and leaf level, for all nonclustered indexes IF 
        -- the table has a clustered index

        -- Clustered index is non-unique
		IF @indid = 1 AND 
                (SELECT is_unique 
                    FROM sys.indexes 
                    WHERE index_id = 1 
                        AND object_id = @objid) = 0
			SELECT @ColsInTree = @keys + N', UNIQUIFIER', @ColsInLeaf = N'All columns "included" - the leaf level IS the data row, plus the UNIQUIFIER'
			
		-- Clustered index AND is unique
        IF @indid = 1 AND (SELECT is_unique FROM sys.indexes WHERE index_id = 1 AND object_id = @objid) = 1
			SELECT @ColsInTree = @keys, @ColsInLeaf = N'All columns "included" - the leaf level IS the data row.'
		
		-- Only run this for nonclustered indexes
        IF @indid > 1 
            EXEC [sp_SQLskills_ExposeColsInIndexLevels] @objid, @indid, @ColsInTree OUTPUT, @ColsInLeaf OUTPUT
		
		-- Nonclustered, non-unique index with non-unique clustered ROWSTORE (type = 1) index
        IF @indid > 1 AND @is_unique = 0 
                AND (SELECT is_unique 
                    FROM sys.indexes 
                    WHERE index_id = 1 AND type = 1
                        AND object_id = @objid) = 0 
			SELECT @ColsInTree = @ColsInTree + N', UNIQUIFIER', @ColsInLeaf = @ColsInLeaf + N', UNIQUIFIER'
		
		-- Nonclustered, unique index with non-unique clustered ROWSTORE (type = 1) index
        IF @indid > 1 AND @is_unique = 1 
            AND (SELECT is_unique 
                    FROM sys.indexes 
                    WHERE index_id = 1 AND type = 1
                        AND object_id = @objid) = 0 
			SELECT @ColsInLeaf = @ColsInLeaf + N', UNIQUIFIER'
		
        -- Nonclustered rowstore on a heap
        IF (@indid > 1 AND @type = 2) 
                AND (SELECT COUNT(*) 
                     FROM sys.indexes 
                     WHERE index_id = 1 
                        AND object_id = @objid) = 0 -- table is a HEAP
		BEGIN
            IF (@is_unique_key = 0)
				SELECT @ColsInTree = @keys + N', RID'
					, @ColsInLeaf = @keys + N', RID' + CASE WHEN @inc_columns IS NOT NULL THEN N', ' + @inc_columns ELSE N'' END
		
			IF (@is_unique_key = 1)
				SELECT @ColsInTree = @keys
					, @ColsInLeaf = @keys + N', RID' + CASE WHEN @inc_columns IS NOT NULL THEN N', ' + @inc_columns ELSE N'' END
		END

		-- INSERT ROW FOR INDEX
		
		insert into #spindtab values (@indname, @indid, @type, @ignore_dup_key, @is_unique, @is_hypothetical,
			@is_primary_key, @is_unique_key, @is_disabled, @auto_created, @no_recompute, @groupname, @keys, @filter_definition, @inc_Count, @inc_columns, @ColsInTree, @ColsInLeaf)

		-- Next index
    	fetch ms_crs_ind into @indid, @type, @groupid, @indname, @ignore_dup_key, @is_unique, @is_hypothetical,
			@is_primary_key, @is_unique_key, @auto_created, @no_recompute, @filter_definition, @is_disabled
	end
	deallocate ms_crs_ind

	-- DISPLAY THE RESULTS

-- Query by version
    IF CONVERT(smallint, SUBSTRING(CONVERT(varchar(50), SERVERPROPERTY('ProductVersion')), 1, 2)) < 16
    
        select @ExecStr = 
	
	        N'select '
		        + N'''index_id'' = index_id,              '
		        + N'''is_disabled'' = is_disabled,        '
		        + N'''index_name'' = index_name,          '
                + N'''index_description'' =               '
                    + N' convert(varchar(210), ' --bits 16 off, 1, 2, 16777216 on, located on group   '
				    + N'   case when index_id = 1 and type = 1 then ''clustered''                   ' 
                    + N'       when index_id = 1 and type = 5 then ''clustered, columnstore''       ' 
				    + N'       when index_id > 1 and type = 2 then ''nonclustered''    ' 
                    + N'       when index_id > 1 and type = 6 then ''nonclustered, columnstore''    ' 
                    + N'       when index_id > 1 and type = 7 then ''nonclustered, HASH''    ' 
			        + N'   else ''new index type'' end                                              '
				    + N'   + case when ignore_dup_key <>0 then '', ignore duplicate keys'' else '''' end '
				    + N'   + case when is_unique=1 then '', unique'' else '''' end                       '
				    + N'   + case when is_hypothetical <>0 then '', hypothetical'' else '''' end         '
				    + N'   + case when is_primary_key <>0 then '', primary key'' else '''' end           '
				    + N'   + case when is_unique_key <>0 then '', unique key'' else '''' end             '
				    + N'   + case when auto_created <>0 then '', auto create'' else '''' end             '
				    + N'   + case when no_recompute <>0 then '', stats no recompute'' else '''' end      '
                    + N'   + case when groupname IS NOT NULL then '' located on '' + groupname else '''' end),  '
		        + N'''index_keys'' = 
			          case when type IN (5, 6) then ''n/a, see columns_in_leaf for details''
			          else index_keys end,
		           ''included_columns'' = 
			          case when type IN (5, 6) then ''n/a, columnstore index''
                           when type = 7 then ''n/a, HASH''
			          else inc_columns end,
		           ''filter_definition'' = 
			          case when type IN (5, 6) then ''n/a, columnstore index''
                           when type = 7 then ''n/a, HASH''
			          else filter_definition end,
		           ''columns_in_tree'' = 
			          case when type IN (5, 6) then ''n/a, columnstore index''
                           when type = 7 then ''n/a, HASH''
			          else cols_in_tree end,
		           ''columns_in_leaf'' = 
			          case when type IN (5, 6) then ''Columns with columnstore index: '' + cols_in_leaf
                            when type = 7 then ''n/a, HASH''
			          else cols_in_leaf end 

	        from #spindtab
	        order by index_id '
            
    IF CONVERT(smallint, SUBSTRING(CONVERT(varchar(50), SERVERPROPERTY('ProductVersion')), 1, 2)) >= 16
        
        select @ExecStr = 
	
	        N'select '
		        + N'''index_id'' = index_id,              '
		        + N'''is_disabled'' = is_disabled,        '
		        + N'''index_name'' = index_name,          '
                + N'''index_description'' =               '
                    + N' convert(varchar(210), ' --bits 16 off, 1, 2, 16777216 on, located on group   '
				    + N'   case when index_id = 1 and type = 1 then ''clustered''                   ' 
                    + N'       when index_id = 1 and type = 5 then ''clustered, columnstore''       ' 
				    + N'       when index_id > 1 and type = 2 then ''nonclustered''    ' 
                    + N'       when index_id > 1 and type = 6 then ''nonclustered, columnstore''    ' 
                    + N'       when index_id > 1 and type = 7 then ''nonclustered, HASH''    ' 
			        + N'   else ''new index type'' end                                              '
                    + N'   + case when ignore_dup_key <>0 then '', ignore duplicate keys'' else '''' end '
				    + N'   + case when is_unique=1 then '', unique'' else '''' end                       '
				    + N'   + case when is_hypothetical <>0 then '', hypothetical'' else '''' end         '
				    + N'   + case when is_primary_key <>0 then '', primary key'' else '''' end           '
				    + N'   + case when is_unique_key <>0 then '', unique key'' else '''' end             '
				    + N'   + case when auto_created <>0 then '', auto create'' else '''' end             '
				    + N'   + case when no_recompute <>0 then '', stats no recompute'' else '''' end      '
                    + N'   + case when memory_optimized = 1 then '' located in MEMORY '' else '''' end   '
                    + N'   + case when groupname IS NOT NULL AND 
                                    (memory_optimized = 0 OR memory_optimized IS NULL) 
                                    then '' located on '' + groupname else '''' end),  '
		        + N'''index_keys'' = 
			          case when type IN (5, 6) then ''n/a, see columns_in_leaf for details''
			          else index_keys end,
		           ''included_columns'' = 
			          case when type IN (5, 6) then ''n/a, columnstore index''
                           when type = 7 then ''n/a, HASH''
			          else inc_columns end,
		           ''filter_definition'' = 
			          case when type IN (5, 6) then ''n/a, columnstore index''
                           when type = 7 then ''n/a, HASH''
			          else filter_definition end,
		           ''columns_in_tree'' = 
			          case when type IN (5, 6) then ''n/a, columnstore index''
                           when type = 7 then ''n/a, HASH''
			          else cols_in_tree end,
		           ''columns_in_leaf'' = 
			          case when type IN (5, 6) then ''Columns with columnstore index: '' + cols_in_leaf
                            when type = 7 then ''n/a, HASH''
			          else cols_in_leaf end 

	        from #spindtab
	        order by index_id '

    --SELECT (@ExecStr)
    EXEC (@ExecStr)

	return (0) -- sp_skindex
go

exec [sys].[sp_MS_marksystemobject] 'sp_skindex'
go