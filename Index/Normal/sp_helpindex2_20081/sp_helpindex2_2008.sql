/*#info 

	# Autor 
		Kimberly L. Tripp (SQLSkills) 
		
	# Detalhes 
		Uma das primeiras versões da sp_helpindex2. Usei muito. Hoje em dia prefiroa  sp_skindex.
		
		
*/

/*============================================================================
  File:     sp_helpindex2.sql

  Summary:  So, what are the included columns?!
			This is a MODIFIED sp_helpindex script that includes INCLUDEd
			columns AND filtered index columns.
  
  Date:     August 2008

  SQL Server *2008* Version: 10.00.1600.22 (SQL Server 2008 RTM)
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

USE master
go

create procedure sp_helpindex2
	@objname nvarchar(776)		-- the table to check for indexes
as

-- April 2008: Updated to add included columns to the output. 

-- August 2008: Fixed a bug (missing begin/end block) AND I found
-- a few other issues that people hadn't noticed (yikes!)!

-- See Kimberly's blog for updates and/or additional information
-- http://www.SQLskills.com/blogs/Kimberly

	-- PRELIM
	set nocount on

	declare @objid int,			-- the object id of the table
			@indid smallint,	-- the index id of an index
			@groupid int,  		-- the filegroup id of an index
			@indname sysname,
			@groupname sysname,
			@status int,
			@keys nvarchar(2126),	--Length (16*max_identifierLength)+(15*2)+(16*3)
			@inc_columns	nvarchar(max),
			@inc_Count		smallint,
			@loop_inc_Count		smallint,
			@dbname	sysname,
			@ignore_dup_key	bit,
			@is_unique		bit,
			@is_hypothetical	bit,
			@is_primary_key	bit,
			@is_unique_key 	bit,
			@auto_created	bit,
			@no_recompute	bit,
			@filter_definition	nvarchar(max)

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
		select i.index_id, i.data_space_id, i.name,
			i.ignore_dup_key, i.is_unique, i.is_hypothetical, i.is_primary_key, i.is_unique_constraint,
			s.auto_created, s.no_recompute, i.filter_definition
		from sys.indexes i join sys.stats s
			on i.object_id = s.object_id and i.index_id = s.stats_id
		where i.object_id = @objid
	open ms_crs_ind
	fetch ms_crs_ind into @indid, @groupid, @indname, @ignore_dup_key, @is_unique, @is_hypothetical,
			@is_primary_key, @is_unique_key, @auto_created, @no_recompute, @filter_definition

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
		ignore_dup_key		bit,
		is_unique			bit,
		is_hypothetical		bit,
		is_primary_key		bit,
		is_unique_key		bit,
		auto_created		bit,
		no_recompute		bit,
		groupname			sysname collate database_default NULL,
		index_keys			nvarchar(2126)	collate database_default NOT NULL, -- see @keys above for length descr
		filter_definition	nvarchar(max),
		inc_Count			smallint,
		inc_columns			nvarchar(max)
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

		select @keys = index_col(@objname, @indid, 1), @i = 2
		if (indexkey_property(@objid, @indid, 1, 'isdescending') = 1)
			select @keys = @keys  + '(-)'

		select @thiskey = index_col(@objname, @indid, @i)
		if ((@thiskey is not null) and (indexkey_property(@objid, @indid, @i, 'isdescending') = 1))
			select @thiskey = @thiskey + '(-)'

		while (@thiskey is not null )
		begin
			select @keys = @keys + ', ' + @thiskey, @i = @i + 1
			select @thiskey = index_col(@objname, @indid, @i)
			if ((@thiskey is not null) and (indexkey_property(@objid, @indid, @i, 'isdescending') = 1))
				select @thiskey = @thiskey + '(-)'
		end

		-- Second, we'll figure out what the included columns are.
		SELECT @inc_Count = count(*)
		FROM
		sys.tables AS tbl
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
			FROM
			sys.tables AS tbl
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
			
			SELECT @inc_columns = [Name] FROM #IncludedColumns WHERE RowNumber = 1

			SET @loop_inc_Count = 1

			WHILE @loop_inc_Count < @inc_Count
			BEGIN
				SELECT @inc_columns = @inc_columns + ', ' + [Name] 
					FROM #IncludedColumns WHERE RowNumber = @loop_inc_Count + 1
				SET @loop_inc_Count = @loop_inc_Count + 1
			END
		END
	
		select @groupname = null
		select @groupname = name from sys.data_spaces where data_space_id = @groupid

		-- INSERT ROW FOR INDEX
		insert into #spindtab values (@indname, @indid, @ignore_dup_key, @is_unique, @is_hypothetical,
			@is_primary_key, @is_unique_key, @auto_created, @no_recompute, @groupname, @keys, @filter_definition, @inc_Count, @inc_columns)

		-- Next index
		fetch ms_crs_ind into @indid, @groupid, @indname, @ignore_dup_key, @is_unique, @is_hypothetical,
			@is_primary_key, @is_unique_key, @auto_created, @no_recompute, @filter_definition
	end
	deallocate ms_crs_ind

	-- DISPLAY THE RESULTS
	select
		'index_name' = index_name,
		'index_description' = convert(varchar(210), --bits 16 off, 1, 2, 16777216 on, located on group
				case when index_id = 1 then 'clustered' else 'nonclustered' end
				+ case when ignore_dup_key <>0 then ', ignore duplicate keys' else '' end
				+ case when is_unique <>0 then ', unique' else '' end
				+ case when is_hypothetical <>0 then ', hypothetical' else '' end
				+ case when is_primary_key <>0 then ', primary key' else '' end
				+ case when is_unique_key <>0 then ', unique key' else '' end
				+ case when auto_created <>0 then ', auto create' else '' end
				+ case when no_recompute <>0 then ', stats no recompute' else '' end
				+ ' located on ' + groupname),
		'index_keys' = index_keys,
		--'num_included_columns' = inc_Count,
		'included_columns' = inc_columns,
		'filter_definition' = filter_definition
	from #spindtab
	order by index_name

	return (0) -- sp_helpindexwinc2
go

exec sys.sp_MS_marksystemobject 'sp_helpindex2'