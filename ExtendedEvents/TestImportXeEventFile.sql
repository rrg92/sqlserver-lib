/*#info 

	# Autor 
		Rodrigo Ribeiro Gomes 
		
	# Detalhes 
		Teste da proc definida no arquivo .\ImportXEventFile.sql
		
		
*/

IF OBJECT_ID('tempdb..#XeDeadlock') IS NOT NULL
	DROP TABLE #XeDeadlock;

CREATE TABLE #XeDeadlock (_auto_ bit)


EXEC stpPowerAlert_ImportXEvent 
	'AllAtv'
	,'#XeDeadlock'
	,'

		<col name="DbId" type="int">
			<x>(event/data/value/deadlock/resource-list/pagelock/@dbid)[1]</x>
			<x>(event/data/value/deadlock/resource-list/ridlock/@dbid)[1]</x>
			<x>(event/data/value/deadlock/resource-list/keylock/@dbid)[1]</x>
			<x>(event/action[@name = "database_id"]/value)[1]</x>
		</col>

		<col name="ObjectName" type="nvarchar(300)">
			<x>(event/data/value/deadlock/resource-list/pagelock/@objectname)[1]</x>
			<x>(event/data/value/deadlock/resource-list/ridlock/@objectname)[1]</x>
			<x>(event/data/value/deadlock/resource-list/keylock/@objectname)[1]</x>
		</col>

		<col name="DeadLockEvent"  dest="DeadLockEvent" type="XML">
			<x>//event/data/value/deadlock</x>
		</col>

	'
	,@Debug = 1
	--,@IncludeEventData = 1
	--,@StopStart = 1

	SELECT * FROM #XeDeadlock


		