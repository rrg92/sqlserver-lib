CREATE TABLE [cmsprops].[CMSProperties](
	 [propName] [nvarchar](300) NOT NULL
	,[propDescription] [varchar](8000) NULL
	,CONSTRAINT [pkCMSProperties] PRIMARY KEY CLUSTERED ([propName] ASC)
)