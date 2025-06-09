use master
GO

-- select * From sys.dm_exec_sessions where login_name like 'dev%'
-- login apra testes
	IF SUSER_SID('DevJoao') IS NOT NULL
		DROP LOGIN DevJoao;
	CREATE LOGIN DevJoao WITH PASSWORD = '123456' , check_policy = off;

	IF SUSER_SID('DevBob') IS NOT NULL
		DROP LOGIN DevBob
	CREATE LOGIN DevBob WITH PASSWORD = '123456' , check_policy = off
	
	

if exists(select * from sys.resource_governor_workload_groups where name = 'TempdbLimitada')
	DROP WORKLOAD GROUP TempdbLimitada

CREATE WORKLOAD GROUP TempdbLimitada with (
	GROUP_MAX_TEMPDB_DATA_MB = 100
)
GO

-- classifier function!
	ALTER RESOURCE GOVERNOR WITH (CLASSIFIER_FUNCTION = NULL)
	ALTER RESOURCE GOVERNOR RECONFIGURE;
	GO

	CREATE OR ALTER FUNCTION dbo.Classifier()
	RETURNS sysname
	WITH SCHEMABINDING
	AS
	BEGIN

		DECLARE @WorkloadGroupName sysname = N'default';

		IF SUSER_NAME() like 'Dev%'
			SET @WorkloadGroupName = N'TempdbLimitada';

		RETURN @WorkloadGroupName;

	END;
	GO

	ALTER RESOURCE GOVERNOR WITH (CLASSIFIER_FUNCTION = dbo.Classifier);
	ALTER RESOURCE GOVERNOR RECONFIGURE;

	--habilitado?
	select * From sys.resource_governor_configuration

	-- logar com o DevJoao!
		-- query: .\TempdbResourceGovernor-QueryConsumo.sql
		-- confirmar que caiu na sessão!
		select 
			s.session_id
			,s.group_id
			,g.name
		from
			sys.dm_exec_sessions s
			join
			sys.resource_governor_workload_groups g
				on g.group_id = s.group_id
		where
			s.login_name like 'Dev%'

	-- rodar isso
	/*
		select 
			* 
		from 
			sys.dm_exec_sessions s
			join 
		where session_id = @@spid
	*/


	-- conferir comsumo atual!
	select
		wg.group_id
		,wg.name 
		,wg.tempdb_data_space_kb
		,wg.peak_tempdb_data_space_kb
		,wg.total_tempdb_data_limit_violation_count
	from
		sys.dm_resource_governor_workload_groups wg

	-- sessoes usando
	/*
		select 
			s.session_id
			,s.login_name
			,s.group_id
			,InternalMB = (su.internal_objects_alloc_page_count-su.internal_objects_dealloc_page_count)/128.00
			,UserMB = (su.user_objects_alloc_page_count-su.user_objects_dealloc_page_count)/128.00

			,Total = (su.internal_objects_alloc_page_count + su.user_objects_alloc_page_count)/128.
						-
					(su.internal_objects_dealloc_page_count + su.user_objects_dealloc_page_count)/128.
		from
			sys.dm_exec_sessions s
			join
			sys.dm_db_session_space_usage su
				on su.session_id = s.session_id
		where
				s.login_name like 'Dev%'

	*/