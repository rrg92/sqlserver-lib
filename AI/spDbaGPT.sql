create or alter procedure spDbaGPT (
 	@prompt nvarchar(max)
	,@credential nvarchar(1000)		= 'https://api.openai.com'
	,@max_tokens int				= 8196
	,@timeout int					= 120
	,@MaxLoop int					= 50
	,@RawResp bit					= 0
)
as


exec('
	/*~
		Obtém informacoes de uma sessao especifica
		---
		@SessionId: Id da sessao
	*/
	create or alter proc #toolGetSessionId(@SessionId int, @result nvarchar(max) OUTPUT)
	as
		set @result  = (
			select
				*
				,SqlText = st.text
			from
				sys.dm_exec_requests r
				outer apply
				sys.dm_exec_sql_text(r.sql_handle) st
			where
				r.session_id = @SessionId
			for json path
		)
')

exec('
	/*~
		Obtém informacoes de tudo o que está rodando no ambiente
		---
	*/
	create or alter proc #toolGetRequests(@result nvarchar(max) OUTPUT)
	as
		set @result  = (
			select
				r.*
				,s.program_name
				,s.login_name
				,s.login_time
			from
				sys.dm_exec_requests r
				inner join
				sys.dm_exec_sessions s 
					on s.session_id = r.session_id
			for json path
		)
')

exec('
	/*~
		Retorna diversas informacoes da instancia, como versao, data e hora atual, etc.
		---
	*/
	create or alter proc #toolsysInfo(@result nvarchar(max) OUTPUT)
	as
		set @result  = (
			select
				data = getdate()
				,versao = @@version
				,*
			from
				sys.dm_os_sys_info
			for json path
		)
')



	
drop table if exists #procs;
create table #procs(name sysname, id int, body varchar(8000), ProcName varchar(100));

insert into #Procs
EXEC tempdb..sp_executesql N'
	select
		name
		,object_id
		,convert(varchar(8000),OBJECT_DEFINITION(object_id))
		,ProcName
	from
		(
			select 
				*
				,ProcName = REGEXP_REPLACE(name,''_+[0-9A-F]+$'','''')
			from
				tempdb.sys.procedures
			where
				name like ''#tool%''
		) t
	where
		object_id(''tempdb..''+ProcName) is not null
'
	
declare @Tools nvarchar(max) = ( 
	select
		type = 'function'
		,JSON_QUERY(f.[function]) as [function]
	from
		#procs
		cross apply (													
			select 
				doc = REGEXP_SUBSTR(body,'/\*~(.+)\*/',1,1,'s',1)	
		)  d
		cross apply	(
			select 
				type = 'object'
				,JSON_OBJECT(ParamName:JSON_OBJECT('type':'string', 'description':ParamDescription))	as properties
			from
				(
					select 
						ParamName = JSON_VALUE(m.substring_matches,'$[0].value')
						,ParamDescription =  JSON_VALUE(m.substring_matches,'$[1].value')
					from
						REGEXP_MATCHES(d.doc,'\@(.+):(.+)') m
				) P
			for json path ,without_array_wrapper
		)  p(parameters)
		cross apply (
			select 
				name = replace(ProcName,'#tool','')
				,description = TRIM(REGEXP_SUBSTR(d.doc,'[\s]+(.+?)\-\-\-',1,1,'s',1))
				,parameters = JSON_QUERY(p.parameters)
			for json path  ,without_array_wrapper
		) f([function])
	for json path
)
	



declare
	@MessagesTable TABLE(role varchar(10), content varchar(max), tool_call_id varchar(100), tool_calls nvarchar(max))


insert into @MessagesTable(role,content) values('system','Você é um assistente que roda diretamente de um SQL Server. Responda a mensagem do usuario. Responda com JSON.');
insert into @MessagesTable(role,content) values('user',@prompt);





declare
	@body nvarchar(max) 
	,@url nvarchar(1000) = 'https://api.openai.com/v1/chat/completions'
	,@results nvarchar(max)
	,@FinishReason varchar(100)
	,@Message nvarchar(max)
	,@ToolScripts nvarchar(max)

drop table if exists #ToolCalls;
create table #ToolCalls (
	id varchar(100)
	,name varchar(100)
	,args varchar(max)
)
	
declare @i int = 1;

while @i <= @MaxLoop
begin
	set @i+=1;

	set @body = (
			SELECT 
				max_tokens = @max_tokens
				,model = 'gpt-4o-mini'
				,[messages] = (
						select 
							role,content,tool_call_id,JSON_QUERY(tool_calls) as tool_calls 
						From 
							@MessagesTable for json path
				)
				,tools = JSON_QUERY(@Tools)
				,response_format = json_query('
					{
						"type":"json_schema"
						,"json_schema":{
							  "name": "sql_answer"
							  ,"schema":{
								"type":"object"
								,"properties":{
									"lines":{
										"type":"array"
										,"items":{
											"type":"string"
											,"description":"Answer line"
										}
									}
								}
							  }
						}
					}
					
				')
			for json path,without_array_wrapper
		)

	raiserror('Sending request: %s',0,1,@body) with nowait;
	exec sp_invoke_external_rest_endpoint @url,@body,@credential = @credential,@timeout = @timeout, @response = @results OUTPUT;


	set @FinishReason = json_value(@results,'$.result.choices[0].finish_reason');
	set @Message = json_query(@results,'$.result.choices[0].message');

	if @FinishReason = 'tool_calls'
	begin
		truncate table #ToolCalls;

		insert into #ToolCalls
		select
			*
		from
			openjson(@Message,'$.tool_calls') with (
				id varchar(100)
				,name varchar(200) '$.function.name'
				,arguments nvarchar(max) '$.function.arguments'
			)


		drop table if exists #ToolResults;
		create table #ToolResults(id varchar(100), result nvarchar(max));

		

		select
			@ToolScripts = STRING_AGG('
				set @toolresult = null;
				EXEC #tool'+name+' @result = @toolresult OUTPUT '+isnull(','+a.params,'')+';
				insert into #ToolResults values('''+id+''',@toolresult);
			' 
			collate database_default
			,char(13)+char(10)
			)
		from
			#ToolCalls		
			cross apply (
				select 
					STRING_AGG( '@'+[Key]+' = '''+REPLACE(value,'''','''')+'''' , ',') 
				from
					openjson(args)
			) a(params)

		set @ToolScripts = 'declare @ToolResult nvarchar(max); ' + @ToolScripts;

		raiserror('INvoking tools: %s',0,1,@ToolScripts) with nowait;
		exec(@ToolScripts);
	
		
		insert into @MessagesTable(role,tool_calls)
		select 'assistant',JSON_QUERY(@Message,'$.tool_calls')

		insert into @MessagesTable(role,content,tool_call_id)
		select 'tool',result,id From #ToolResults

		continue;
	end



	break;
end


if @RawResp = 1
	select @results;

drop table if exists #results;

select
	*
into
	#results
from
	openjson(@results,'$.result')   with (
		 resposta nvarchar(max) '$.choices[0].message.content'
		 ,finish_reason varchar(10) '$.choices[0].finish_reason'
		 ,total_tokens int '$.usage.total_tokens'
		 ,prompt_tokens int '$.usage.prompt_tokens'
		 ,completion_tokens int '$.usage.completion_tokens'
	)


select 
	*
from 
	#results

select
	jr.value as resposta
from
	#results r
	cross apply
	openjson(resposta,'$.lines') jr






