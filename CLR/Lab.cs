using Microsoft.SqlServer.Server;
using System.Data.SqlClient;
using System.Threading;
using System.Data;
using System.Data.SqlTypes;


public class SqlLab {
	
	public static int Sleep(int ms, int rnd){
		Thread.Sleep(ms);
		return ms;
	}	
	
	
	[SqlFunction(DataAccess = DataAccessKind.Read)] 
	public static int SelectTable(string sql){
		
		SqlDataReader r;
		DataSet ds = new DataSet();
		
		using (SqlConnection c   = new SqlConnection("context connection=true"))  
        {  
            c.Open();  
            SqlCommand cmd = new SqlCommand(sql, c);  
			
			r = cmd.ExecuteReader();
			
			while(!r.IsClosed)
				ds.Tables.Add().Load(r);
			
			return (int)ds.Tables[0].Rows[0].ItemArray[0];
        }  
	}	
	
	[SqlProcedure] 
	public static void ResultAsXml(string sql,out SqlString result){
		
		SqlDataReader r;
		DataSet ds = new DataSet();
		
		using (SqlConnection c   = new SqlConnection("context connection=true"))  
        {  
            c.Open();  
            SqlCommand cmd = new SqlCommand(sql, c);  
			
			r = cmd.ExecuteReader();
			
			while(!r.IsClosed)
				ds.Tables.Add().Load(r);
        } 
		
		
		DataTable t = ds.Tables[0];
		System.IO.StringWriter writer = new System.IO.StringWriter();
		
		t.WriteXml(writer, XmlWriteMode.IgnoreSchema, false);
		result = writer.ToString();
	}	
	
}