package id.co.toyota.ipm.pib;

import java.util.Date;
import java.util.Properties;

import javax.activation.DataHandler;
import javax.activation.FileDataSource;
import javax.mail.Message;
import javax.mail.Multipart;
import javax.mail.Session;
import javax.mail.Transport;
import javax.mail.internet.InternetAddress;
import javax.mail.internet.MimeBodyPart;
import javax.mail.internet.MimeMessage;
import javax.mail.internet.MimeMultipart;

public class Mailer {
	public static void send(MailConfig emailConfig, String txtMessage) throws Exception {
        Properties props = new Properties();
        props.setProperty("mail.transport.protocol", "smtp");
        props.setProperty("mail.host", emailConfig.getServerHost());
        props.setProperty("mail.user", emailConfig.getSender());
        props.setProperty("mail.sender", emailConfig.getSender());
        props.setProperty("mail.password", emailConfig.getServerPassword());

        Session mailSession = Session.getDefaultInstance(props, null);
        Transport transport = mailSession.getTransport();


        MimeMessage msg = new MimeMessage(mailSession);
        msg.setSubject(emailConfig.getSubject());

        String[] to = emailConfig.getTo().split(";");

        for (int i = 0; i < to.length; i++) {
            msg.addRecipient(Message.RecipientType.TO, new InternetAddress(to[i]));
        }
        String ccs = emailConfig.getCc();
        if (ccs != null && ccs.length() > 0) {
            String[] cc = ccs.split(";");
            for (int i = 0; i < cc.length; i++) {
                msg.addRecipient(Message.RecipientType.CC, new InternetAddress(cc[i]));
            }
        }
        String bccs = emailConfig.getBcc();
        if (bccs != null && bccs.length() > 0) {
            String[] bcc = bccs.split(";");
            for (int i = 0; i < bcc.length; i++) {
                msg.addRecipient(Message.RecipientType.BCC, new InternetAddress(bcc[i]));
            }
        }
        // create and fill the first message part
        MimeBodyPart mbp1 = new MimeBodyPart();
        mbp1.setContent(txtMessage, "text/html");

        // create the Multipart and add its parts to it
        Multipart mp = new MimeMultipart();
        mp.addBodyPart(mbp1);

        String[] attachments = emailConfig.getAttachments();

        if (attachments != null && attachments.length > 0) {
            for (int i = 0; i < attachments.length; i++) {
                FileDataSource fds = new FileDataSource(attachments[i]);

                MimeBodyPart mbp2 = new MimeBodyPart();
                mbp2.setDataHandler(new DataHandler(fds));
                mbp2.setFileName(fds.getName());
                mp.addBodyPart(mbp2);

            }
        }

        // add the Multipart to the message
        msg.setContent(mp);

        // set the Date: header
        msg.setSentDate(new Date());

        transport.connect();
        transport.sendMessage(msg, msg.getRecipients(Message.RecipientType.TO));

        try {
            transport.sendMessage(msg, msg.getRecipients(Message.RecipientType.CC));
        } catch (Exception e) {
            e.printStackTrace();
        }

        try {
            transport.sendMessage(msg, msg.getRecipients(Message.RecipientType.BCC));
        } catch (Exception e) {
            e.printStackTrace();
        }

        transport.close();
    }
}
