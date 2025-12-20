/*
    # Author 
        Rodrigo Ribeiro gomes

    # descricao
        Lista os externals models criados na instancia e suas respectivas credentials.
        Útil se você quiser ter uma visão geral dos modelos criados1

        Importante: Notei que em algumas versoes do SSMS, quando você retorna um tipo json, ele pode deixar o SSMS lento.
        Se ocorer algum travamento estranho após rodar essa query (especialmente em ambientes cmo ssms antes do 21), considere converter a coluna Params, para nvarchar(max).  
        Creio que issoé um bug que deverá resolvido em breve! Mas fica o aviso.
*/

DROP TABLE IF EXISTS #AiModels;

CREATE TABLE #AiModels(
     DbName sysname
    ,Id int
    ,Name sysname
    ,Location nvarchar(1000)
    ,Api varchar(100)
    ,Type varchar(100)
    ,AiModel nvarchar(1000)
    ,Params json
    ,CredName sysname null
    ,CredHttp varchar(100)
    ,CredId int
)

EXEC sp_MSforeachdb N'
    USE [?]

    insert into #AiModels
    SELECT
         db_name()
        ,em.external_model_id
        ,em.name
        ,em.location
        ,em.api_format
        ,em.model_type_desc
        ,em.model
        ,em.parameters
        ,dc.name
        ,dc.credential_identity
        ,dc.credential_id
    FROM
        sys.external_models em
        left join
        sys.database_scoped_credentials dc
            on dc.credential_id  = em.credential_id
'


select
    *
from
    #AiModels

    

