
import java.io.File;
import java.io.IOException;
import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.ResultSet;
import java.sql.Statement;

import com.healthmarketscience.jackcess.Database;
import com.healthmarketscience.jackcess.Database.FileFormat;
import com.healthmarketscience.jackcess.DatabaseBuilder;

public class UcaJoinTest {

    public static void main(String[] args) {
        /*String db1FileSpec = "C:/Users/Public/Prod_EN.accdb";
        String db1TableName = "Products";
        String db1LinkName = "Products_EN";
        String db2FileSpec = "C:/Users/Public/Prod_FR.accdb";
        String db2TableName = "Products";
        String db2LinkName = "Products_FR";

        File tempDbFile = null;
        try {
            tempDbFile = File.createTempFile("tmp", ".accdb");
        } catch (IOException e) {
            e.printStackTrace(System.err);
            System.exit(0);
        }
        tempDbFile.deleteOnExit();

        // create database file using Jackcess
        try (Database db = DatabaseBuilder.create(FileFormat.V2010, tempDbFile)) {
            db.createLinkedTable(db1LinkName, db1FileSpec, db1TableName);
            db.createLinkedTable(db2LinkName, db2FileSpec, db2TableName);
        } catch (Exception e) {
            e.printStackTrace(System.err);
            System.exit(0);
        }

        String connStr = String.format(
                "jdbc:ucanaccess://%s;singleConnection=true", 
                tempDbFile.getAbsolutePath());
        String sql = String.format( 
                "SELECT ID, t1.ProductName AS Name_EN, t2.ProductName AS Name_FR " +
                "FROM %s t1 INNER JOIN %s t2 ON t1.ID=t2.ID",
                db1LinkName,
                db2LinkName);
        try (
                Connection conn = DriverManager.getConnection(connStr);
                Statement st = conn.createStatement();
                ResultSet rs = st.executeQuery(sql)) {
            while (rs.next()) {
                System.out.printf(
                        "%s ==> %s\n", 
                        rs.getString("Name_EN"), 
                        rs.getString("Name_FR"));
            }
        } catch (Exception e) {
            e.printStackTrace(System.err);
            System.exit(0);
        }*/
    }

}
