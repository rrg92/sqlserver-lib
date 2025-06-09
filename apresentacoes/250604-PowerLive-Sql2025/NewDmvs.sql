if exists(select * from sys.servers where name = 'b22')
	exec sp_dropserver 'b22'

-- exec sp_dropserver 'Fuckill'
EXEC sp_addlinkedserver @server = N'b22',@srvproduct=N''
					,@provider=N'SQLNCLI11',@datasrc='LOCALHOST\b22',@catalog=N'master'
exec sp_serveroption 'b22',N'rpc','true';
exec sp_serveroption 'b22',N'rpc out','true';
EXEC sp_addlinkedsrvlogin N'b22', @locallogin = NULL , @useself = N'True', @rmtuser = N''

drop table if exists #Dmv22;

create table #Dmv22(
	SchemaName nvarchar(100)
	,DmvName sysname
)
insert into #Dmv22
exec('
	select
		SchemaName = SCHEMA_NAME(schema_id)
		,name
	from
		sys.all_objects o
	WHERE
		is_ms_shipped = 1
		and
		o.name like ''dm_%''
') at b22



select
	 SCHEMA_NAME(schema_id)+'.'+name
	,type_desc
from
	sys.all_objects v25
WHERE
	is_ms_shipped = 1
	and v25.name like 'dm_%'
	and not exists (
		select 
			*
		from
			#Dmv22 v22
		where
			v22.DmvName =  v25.name 
			and v22.SchemaName = SCHEMA_NAME(v25.schema_id)
	)
/*
sys.dm_db_column_store_redirected_lobs
sys.dm_db_exec_cursors							   moo
select * from sys.dm_db_internal_auto_tuning_create_index_recommendations
select * from sys.dm_db_internal_auto_tuning_recommendation_impact_query_metrics
select * from sys.dm_db_internal_auto_tuning_recommendation_metrics
select * from sys.dm_db_internal_auto_tuning_workflows
select * from sys.dm_db_internal_automatic_tuning_version
select * from sys.dm_db_logical_index_corruptions
select * from sys.dm_db_xtp_undeploy_status
select * from sys.dm_exec_ce_feedback_cache
select * from sys.dm_exec_distributed_tasks
select * from sys.dm_external_governance_synchronizing_objects
select * from sys.dm_external_policy_excluded_role_members
select * from sys.dm_feature_switches
select * from sys.dm_hadr_internal_availability_groups
select * from sys.dm_hadr_internal_availability_replicas
select * from sys.dm_io_network_traffic_stats
select * from sys.dm_os_memory_allocations_filtered
select * from sys.dm_os_memory_health_history
select * from sys.dm_os_memory_nodes_processor_groups
select * from sys.dm_os_parent_block_descriptors
select * from sys.dm_pal_ring_buffers
select * from sys.dm_server_managed_identities
select * from sys.dm_database_backup_lineage
*/


--	https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-os-memory-health-history?view=azuresqldb-current
select * From sys.dm_os_memory_health_history

select * From sys.dm_io_network_traffic_stats

-- https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-db-exec-cursors-transact-sql?view=azuresqldb-current
select * from sys.dm_db_exec_cursors(77)

-- 	https://learn.microsoft.com/en-us/sql/relational-databases/errors-events/database-engine-events-and-errors-41400-to-49999?view=sql-server-ver17
select * from sys.dm_db_logical_index_corruptions

-- 
select * From sys.dm_os_memory_allocations_filtered

-- veremos
select * from sys.dm_db_xtp_undeploy_status

select * from sys.dm_feature_switches

select * from sys.dm_exec_ce_feedback_cache

select * From sys.dm_server_managed_identities

select * From sys.dm_hadr_internal_availability_groups


