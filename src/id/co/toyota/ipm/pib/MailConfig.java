package id.co.toyota.ipm.pib;

import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.lang.reflect.Type;
import java.util.Map;

import org.apache.commons.logging.Log;
import org.apache.commons.logging.LogFactory;

import com.google.gson.Gson;
import com.google.gson.reflect.TypeToken;

public class MailConfig {
	static Log log = LogFactory.getLog(MailConfig.class);
	 
	private String serverHost;
	private String serverIp;
	private String serverPort;
	private String serverUser;
	private String serverPassword;
	private String sender;
	private String attachmentFolder;

	private String subject;
    private String to;
    private String cc;
    private String bcc;
    private String[] attachments;

    private String header;
    private String footer;
    
    
    
    public MailConfig() {
    	initialize();
    }
    
    private void initialize() {
    	
    	InputStream in = this.getClass().getClassLoader().getResourceAsStream("mailconfig.json");
        BufferedReader bufferedReader = new BufferedReader(new InputStreamReader(in));

        Gson gson = new Gson();
        Type type = new TypeToken<Map<String, Object>>(){}.getType();
        Map<String, String> json = gson.fromJson(bufferedReader, type);
        
        try {
			bufferedReader.close();
	        in.close();
		} catch (IOException e) {
			log.error(null, e);
		}
        
        this.serverHost = json.get("serverHost");
        this.serverIp = json.get("serverIp");
        this.serverPort = json.get("serverPort");
        this.serverUser = json.get("serverUser");
        this.serverPassword = json.get("serverPassword");
        this.sender = json.get("sender");
        this.attachmentFolder = json.get("attachmentFolder");
        this.subject = json.get("subject");
        this.to = json.get("to");
        this.cc = json.get("cc");
        this.bcc = json.get("bcc");
        //this.attachments = json.get("attachments");

        this.header = json.get("header");
        this.footer = json.get("footer");
        
    }
	public String getServerHost() {
		return serverHost;
	}
	public void setServerHost(String serverHost) {
		this.serverHost = serverHost;
	}
	public String getServerIp() {
		return serverIp;
	}
	public void setServerIp(String serverIp) {
		this.serverIp = serverIp;
	}
	public String getServerPort() {
		return serverPort;
	}
	public void setServerPort(String serverPort) {
		this.serverPort = serverPort;
	}
	public String getServerUser() {
		return serverUser;
	}
	public void setServerUser(String serverUser) {
		this.serverUser = serverUser;
	}
	public String getServerPassword() {
		return serverPassword;
	}
	public void setServerPassword(String serverPassword) {
		this.serverPassword = serverPassword;
	}
	public String getSender() {
		return sender;
	}
	public void setSender(String sender) {
		this.sender = sender;
	}
	public String getAttachmentFolder() {
		return attachmentFolder;
	}
	public void setAttachmentFolder(String attachmentFolder) {
		this.attachmentFolder = attachmentFolder;
	}
	public String getSubject() {
		return subject;
	}
	public void setSubject(String subject) {
		this.subject = subject;
	}
	public String getTo() {
		return to;
	}
	public void setTo(String to) {
		this.to = to;
	}
	public String getCc() {
		return cc;
	}
	public void setCc(String cc) {
		this.cc = cc;
	}
	public String getBcc() {
		return bcc;
	}
	public void setBcc(String bcc) {
		this.bcc = bcc;
	}
	public String[] getAttachments() {
		return attachments;
	}
	public void setAttachments(String[] attachments) {
		this.attachments = attachments;
	}
	public String getHeader() {
		return header;
	}
	public void setHeader(String header) {
		this.header = header;
	}
	public String getFooter() {
		return footer;
	}
	public void setFooter(String footer) {
		this.footer = footer;
	}
    
}
