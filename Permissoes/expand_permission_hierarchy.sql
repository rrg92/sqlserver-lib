/*#info 

	# Autor 
		Rodrigo Ribeiro Gomes 
		
	# Descricao 
		Esse script ajuda a ter uma visao da hierarquia de permissões no SQL Server...
		O permissionamento do SQL Server segue uma hierarquia (grant ou deny em permissao de hierarquia superior pode afetar hierarquias inferiores...)
		começa aqui: https://learn.microsoft.com/lb-lu/%20sql/relational-databases/security/permissions-hierarchy-database-engine?view=sql-server-ver17
		

*/


DECLARE @AllClasses TABLE( 
		name varchar(200) COLLATE Latin1_General_CI_AI
		,parent varchar(200) COLLATE Latin1_General_CI_AI
		,permission_name varchar(200) COLLATE Latin1_General_CI_AI
		,covering_permission_name varchar(200) COLLATE Latin1_General_CI_AI
		,parent_covering_permission_name varchar(200) COLLATE Latin1_General_CI_AI
	);

INSERT INTO 
	@AllClasses
SELECT 
	class_Desc
	,parent_class_desc 
	,permission_name
	,covering_permission_name
	,parent_covering_permission_name
FROM 
	sys.fn_builtin_permissions(DEFAULT)

/*
	This part get the permission hierarchy of SQL Server then expands it.
	The following query get each class/permission part and generate a line for each covering permission on itself or your parent class.
	The parent of parent, and so, also is generated. For example, consider OBJECT class and EXECUTE permission:
		GRANT Execute To UserA ON mySchema.myProc;
	
	User A have explicit GRANT on mySchema.myProc (Suppose that are in database MyDB,at instance myServer\myInstance). But, SQL Server permission hierarchy may cancel this GRANT if:

		UserA have a DENY CONTROL on OBJECT mySchema.myProc
		or
		UserA have a DENY EXECUTE ON SCHEMA schema
		or
		UserA have a DENY EXECUTE ON DATABASE MyDB
		or
		UserA have a DENY CONTROL on SCHEMA mySchema
		or
		UserA have a DENY CONTROL on DATABASE MyDB
		or
		UserA have a DENY CONTROL SERVER on SERVER myServer\myInstance

	This is just the permission hierarchy of SQL Server and is valid for GRANTs also (GRANTs are implicit acquired using same concepts above).
	
	The query below just expand the hierarchy table (fn_builtin_permissions) providing data like this:

			Permission/Class		Where to Check
			EXECUTE on OBJECT	--> EXECUTE ON OBJECT
			EXECUTE on OBJECT	--> CONTROL ON OBJECT
			EXECUTE on OBJECT	--> EXECUTE ON SCHEMA
			EXECUTE on OBJECT	--> EXECUTE ON DATABASE
			EXECUTE on OBJECT	--> CONTROL ON SCHEMA
			EXECUTE on OBJECT	--> CONTROL ON DATABASE
			EXECUTE on OBJECT	--> CONTROL SERVER ON SERVER

*/
;WITH Expanded AS
(
	SELECT
		AC.name				
		,AC.permission_name					AS P
		,AC.covering_permission_name		AS C
		,AC.parent							AS PARENT	
		,AC.parent_covering_permission_name	as PARENT_P
		,CONVERT(int,1)						as Deeping
		,CONVERT(varchar(8000),AC.name)+'['+AC.permission_name+']' COLLATE Latin1_General_CI_AI		as Seed
		,AC.name as RootClass
		,AC.permission_name as RootPermission
		,CONVERT(int,1)						as HierarchyLevel
	FROM
		@AllClasses AC

	UNION ALL

	SELECT
		N.name
		,N.permission_name
		,N.covering_permission_name
		,N.parent
		,N.parent_covering_permission_name
		,E.Deeping + 1
		,CONVERT(varchar(8000),
		
			--> For debug only, just show the source of this line in this format:
			--			CURRENT_CLASS ( [C|P] = DeepingNumber SOURCE_CLASS  )[PERMISSION_NAME]
			CASE
				WHEN N.name = E.name THEN N.name+'(C = '+CONVERT(varchar(10),E.Deeping)+' '+E.name+')['+N.permission_name+']'
				WHEN  N.name = E.PARENT THEN N.name+'(P = '+CONVERT(varchar(10),E.Deeping)+' '+E.name+')['+N.permission_name+']'
			END
			
		) COLLATE Latin1_General_CI_AI
		,E.RootClass 
		,E.RootPermission
		,CASE
			WHEN N.name = E.name THEN E.HierarchyLevel
			WHEN N.name = E.PARENT THEN E.HierarchyLevel + 1
		END
	FROM
		Expanded E
		INNER JOIN
		@AllClasses N
			ON
				--> Get the in the same CLASS, the covering permission
				( N.name = E.name AND N.permission_name = E.C )
				OR
				--> Get the parent class, the parent covering permission
				( N.name = E.PARENT AND N.permission_name = E.PARENT_P )
)
SELECT
	*
FROM
(
	SELECT DISTINCT
		RootClass
		,RootPermission
		,name
		,p
		,HierarchyLevel
	FROM
		Expanded E
	WHERE
		E.RootPermission like '%CREATE%PROCEDURE%'


) PH
ORDER BY
	RootClass
	,RootPermission
	,HierarchyLevel
	,CASE WHEN RootPermission = P THEN 0 ELSE 1 END

