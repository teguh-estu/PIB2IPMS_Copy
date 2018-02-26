package id.co.toyota.ipm.pib;

import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.lang.reflect.Type;
import java.sql.CallableStatement;
import java.sql.Connection;
import java.sql.Date;
import java.sql.DriverManager;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.ResultSetMetaData;
import java.sql.SQLException;
import java.sql.Statement;
import java.sql.Types;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import org.apache.commons.logging.Log;
import org.apache.commons.logging.LogFactory;

import com.google.gson.Gson;
import com.google.gson.reflect.TypeToken;


public class Base {

	 static Log log = LogFactory.getLog(Base.class);
	 
	 @SuppressWarnings("unchecked")
	    public void doImport() {
		    log.info("Start processing: Import Declaration Response from MDB");
	    	Connection srcConn = null;
	    	Connection destConn = null;
	        try {
	        	
	        	log.info("Read configuration file importconfig.json");
	            Map<String, Object> config = getConfig();

	            Map<String, String> srcConnMap = (Map<String, String>) config.get("sourceConnection");
	            String srcDriver = srcConnMap.get("driver");
	            String srcUrl = srcConnMap.get("url");
	            String srcUser = srcConnMap.get("user");
	            String srcPassword = srcConnMap.get("password");

	            log.info("Connect and load MDB file");
	            srcConn = getConnection(srcDriver, srcUrl, srcUser, srcPassword);
	            log.info("Connect and load MDB file: success");
	            
	            Map<String, String> destConnMap = (Map<String, String>) config.get("destinationConnection");
	            String destDriver = destConnMap.get("driver");
	            String destUrl = destConnMap.get("url");
	            String destUser = destConnMap.get("user");
	            String destPassword = destConnMap.get("password");
	            
	            log.info("Connect to IPMS database");
	            destConn = getConnection(destDriver, destUrl, destUser, destPassword);
	            destConn.setAutoCommit(false);
	            log.info("Connect to IPMS  success");
	            
	            List<Map> importList = (List<Map>)config.get("import");
	            String processId = getProcessId(destConn);
	            log.info("Get process Id from IPMS: " + processId);
	            for (Map tableMap: importList) {
	            	
	                String name = (String) tableMap.get("name");
	                boolean active = (Boolean) tableMap.get("active");
	                boolean useProcessId = true;
	                if (tableMap.get("processId") != null) {
	                	useProcessId = (Boolean) tableMap.get("processId");
	                }
	                if (active) {
	                	log.info("Processing import for: " + name);
		                Map source = (Map) tableMap.get("source");
		                String srcTable = (String) source.get("table");
		                String srcQuery = (String) source.get("query");
		
		                Map destination = (Map) tableMap.get("destination");
		                String destTable = (String) destination.get("table");
		
		                //Map fields = (Map) tableMap.get("field");
		                //List includes = (List) fields.get("includes");
		                //List excludes = (List) fields.get("excludes");
		                List<Map> mappings = (List) tableMap.get("mapping");
		
		                Map<String, String> columnMap = new HashMap<String, String>();
		                for (Map mapping: mappings) {
		                    String srcColumn = (String) mapping.get("sourceColumn");
		                    String destColumn = (String) mapping.get("destinationColumn");
		                    columnMap.put(destColumn, srcColumn);
		                }
		
		                String completeQuery = srcQuery == null || "".equals(srcQuery.trim()) ? "select * from " + srcTable: srcQuery;
		                log.info("Source query:" + completeQuery);
		
		                Statement srcStatement = srcConn.createStatement();
		                ResultSet srcRs = srcStatement.executeQuery(completeQuery);
		
		                Map<String, Integer> sourceColumnType = getSourceColumnTypes(srcRs);
		                
		                Statement destStatement = destConn.createStatement();
		                ResultSet destRs = destStatement.executeQuery("select * from "+ destTable);
		                
		                
		                Map<String, Integer> destColumnType = getSourceColumnTypes(destRs);
		
		                destRs.close();
		                destStatement.close();
		                
		                StringBuilder insertQuery = new StringBuilder("insert into " + destTable + "( ");
		                for(String key: columnMap.keySet()) {
		                	insertQuery.append(key +",");
		                }
		               // insertQuery = new StringBuilder(insertQuery.substring(0, insertQuery.length() - 1));
		                if (useProcessId) {
		                	insertQuery.append("PROCESS_ID,");
		                }
		                insertQuery.append(" CREATED_BY, CREATED_DT) values (");
		                for(String key: columnMap.keySet()) {
		                	insertQuery.append("?,");
		                }
		                
		                //insertQuery = new StringBuilder(insertQuery.substring(0, insertQuery.length() - 1));
		             // insertQuery = new StringBuilder(insertQuery.substring(0, insertQuery.length() - 1));
		                if (useProcessId) {
		                	 insertQuery.append("?,");
		                }
		                insertQuery.append("'PIB_RES', sysdate)");
		                
		                log.info("Destination Query: "+ insertQuery.toString());
		                
		                PreparedStatement destPs = destConn.prepareStatement(insertQuery.toString());
		                
		                while(srcRs.next()) {
		                	int i = 1;
		                	for (String destColumn: columnMap.keySet()) {
		                        String sourceColumn = columnMap.get(destColumn);
		                        //    Object value = getValue(srcRs, sourceColumnType.get(sourceColumn).intValue(), sourceColumn);
		                        //    setPs(destPs, i, destColumn, destColumnType.get(destColumn), value);
		                        Object value = srcRs.getObject(sourceColumn);
		                        destPs.setObject(i, value);
		                            i++;
		                        
		                    }
		                	if (useProcessId) {
		                		destPs.setString(i, processId);
		                	}
		                	//System.out.println(srcRs.getString("SUBMISSION_CAR") + srcRs.getString("SERIAL"));
		                	destPs.executeUpdate();
		                }
		                
		                srcRs.close();
		                srcStatement.close();
		                destPs.close();
		                log.info("Finish Processing import for: " + name);
	                } else {
	                	log.info("Skip Processing import for: " + name +". Active: false");
	                }

	            }
	            
	            destConn.commit();
	            
	            log.info("Call stored procedure");
	            
	            call(destConn, processId);
	            
	            log.info("Send Mail");
	            
	            sendMail(destConn, processId);
	            
	            log.info("Finish processing: Import Declaration Response from MDB");
	        } catch (Exception e) {
	        	try {
	        		if (destConn != null)
					  destConn.rollback();
				} catch (SQLException e1) {
					e1.printStackTrace();
				}
	        	log.error(null, e);
	            e.printStackTrace();
	        } 
	        finally {
	        	if (srcConn != null) {
	        		try {
						srcConn.close();
					} catch (SQLException e) {
						// TODO Auto-generated catch block
						e.printStackTrace();
					}
	        	}
	        	
	        	if (destConn != null) {
	        		try {
						destConn.close();
					} catch (SQLException e) {
						// TODO Auto-generated catch block
						e.printStackTrace();
					}
	        	}
	        }


	    }

    protected Map<String, Integer> getSourceColumnTypes(ResultSet rs) throws SQLException {
        Map<String, Integer> columnTypes = new HashMap<String, Integer>();

        ResultSetMetaData rsmd = rs.getMetaData();
        for (int i = 1; i <= rsmd.getColumnCount(); i++) {
            columnTypes.put(rsmd.getColumnName(i), rsmd.getColumnType(i));
        }

        return columnTypes;
    }


    public Connection getConnection(String driverClass, String url, String user, String password) throws Exception {
    	Class.forName(driverClass);
        Connection conn=DriverManager.getConnection(url, user, password);
        
        return conn;

    }

    public Map<String, Object> getConfig() {
    	InputStream in = this.getClass().getClassLoader().getResourceAsStream("importconfig.json");
        BufferedReader bufferedReader = new BufferedReader(new InputStreamReader(in));

        Gson gson = new Gson();
        Type type = new TypeToken<Map<String, Object>>(){}.getType();
        Map<String, Object> json = gson.fromJson(bufferedReader, type);
        
        try {
			bufferedReader.close();
	        in.close();
		} catch (IOException e) {
			log.error(null, e);
		}

        return json;
    }

   
    
    private Object getValue(ResultSet rs, int columnType, String columnName) throws SQLException {
    	System.out.println(columnType);
        Object objField = null;
        switch (columnType) {
        case Types.DECIMAL:
    	case Types.DOUBLE:
        case Types.NUMERIC:
        case Types.SMALLINT:
        case Types.INTEGER:
            double dField = rs.getDouble(columnName);
            if (rs.wasNull()) {
                objField = null;
            } else {
                objField = new Double(dField);
            }
            break;
        case Types.VARCHAR:
            objField = rs.getString(columnName);
            break;
        case Types.DATE:

            objField = rs.getDate(columnName);
            break;
        case Types.TIMESTAMP:

            objField = rs.getDate(columnName);
            break;
        default:
            objField = rs.getString(columnName);
            break;
        }
        return objField;
    }
    
    private void setPs(PreparedStatement ps, int i, String destColumn, Integer columnType, Object value) throws Exception {
    	System.out.println(destColumn);
    	switch (columnType) {
    	case Types.DECIMAL:
    	case Types.DOUBLE:
        case Types.NUMERIC:
        case Types.SMALLINT:
        case Types.INTEGER:
            if (value == null) {
            	ps.setNull(i,Types.NUMERIC);
            } else {
            	
            	ps.setObject(i, (Double) value); 
            }
            break;
        case Types.VARCHAR:
        	if (value == null) {
            	ps.setNull(i,Types.VARCHAR);
            } else {
            	ps.setString(i, value.toString()); 
            }
            break;
        case Types.DATE:
        case Types.TIMESTAMP:
        	if (value == null) {
            	ps.setNull(i,Types.DATE);
            } else {
            	ps.setDate(i, (Date) value); 
            }
            break;
        default:
            ps.setObject(i, value);
        }
		
	}

    public String getProcessId(Connection conn) {
    	String processId = null;
		try {
			Statement st = conn.createStatement();
			ResultSet rs = st.executeQuery("SELECT TO_CHAR(SYSDATE, 'YYMMDD') || LPAD(SEQ_PROCESS_ID.NEXTVAL, 10, '0') FROM DUAL");
			if (rs.next()) 
				processId = rs.getString(1);
			
			rs.close();
			st.close();
		} catch(SQLException se) {
			se.printStackTrace();
			
		}finally{
 
		}
		return processId;
    }
    
    public int call(Connection conn, String processId) throws Exception {
    	int retVal = -1;
    	try {
    		CallableStatement smt = conn.prepareCall("{? = PKG_BIPMB471.fn_interface_import_response (?)}");
    		smt.registerOutParameter(1, Types.INTEGER);
    		smt.setString(2, processId);
    		smt.executeUpdate();
    		
    	    retVal = smt.getInt(1);
    	} catch (SQLException e) {
    		e.printStackTrace();
    		throw e;
    	}
    	
    	return retVal;
    }
    
    public void sendMail(Connection conn, String processId) throws Exception {
    	
            try {
            	MailConfig config = new MailConfig();
                String query = "select t.function_id,t.email_from, t.email_to, t.email_cc,t.email_bcc,t.email_subject, t.email_body_header,t.email_body_footer from tb_m_email_attr t where t.function_id = ?";
                PreparedStatement ps = conn.prepareStatement(query);
                ps.setString(1, "BIPMB471");
                ResultSet rs = ps.executeQuery();
                if (rs.next()) {
                	config.setSender(rs.getString(2));
                	config.setTo(rs.getString(3));
                	config.setCc(rs.getString(4));
                	config.setBcc(rs.getString(5));
                	config.setSubject(rs.getString(6));
                	config.setHeader(rs.getString(7));
                	config.setFooter(rs.getString(8));
                } else {
                	
                }
                
                rs.close();
                ps.close();
                
                String dataQuery = "select t.pib_no, to_char(t.pib_dt,'DD.MM.YYYY') as pib_dt_char, t.pi_no from tb_r_res_pibdok_email t where process_id = ?";
                ps = conn.prepareStatement(dataQuery);
                ps.setString(1, processId);
                rs = ps.executeQuery();
                
                boolean dataExist = false;
               
                
                StringBuilder content = new StringBuilder();
                content.append(config.getHeader());
                content.append("<table style=\"border:1px solid black\">");
                content.append("<tr style=\"border:1px solid black\"><td style=\"border:1px solid black\">No</td><td style=\"border:1px solid black\">PIB No</td><td style=\"border:1px solid black\">PIB Date</td><td style=\"border:1px solid black\">PI No </td><td style=\"border:1px solid black\"></td></tr>");
                int j = 1;
                while (rs.next()) {
                	dataExist = true;
                    content.append("<tr style=\"border:1px solid black\">");
                    content.append("<td style=\"border:1px solid black\">").append(String.valueOf(j++)).append("</td>");
                    content.append("<td style=\"border:1px solid black\">").append(rs.getString(1)).append("</td>");
                    content.append("<td style=\"border:1px solid black\">").append(rs.getString(2)).append("</td>");
                    content.append("<td style=\"border:1px solid black\">").append(rs.getString(3)).append("</td>");
                    content.append("</tr>");

                }
                content.append("</table>");
                content.append(config.getFooter());

                
                if(dataExist) {
                	Mailer.send(config, content.toString());
                }
            } catch (SQLException e) {
            	e.printStackTrace();
            	throw new Exception(e);
            }
    }

    
    
	public static void main (String[] args) {
    	Base base = new Base();
    	try {
			//Connection conn = base.getConnection("oracle.jdbc.driver.OracleDriver", "jdbc:oracle:thin:@localhost:1521:orcl", "IP0USER00", "IP0USER00");
			//base.sendMail(conn, "180200001");
			
			//conn.close();
    		base.doImport();
		} catch (Exception e) {
			// TODO Auto-generated catch block
			e.printStackTrace();
		}
    	
    }
}
