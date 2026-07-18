public class EmailChannel extends Channel {
    public String name() { return "EMAIL"; }
    public boolean validate(String recipient) { return recipient.contains("@"); }
    public String format(String message) { return "Subject: Notification\n\n" + message; }
    public void send(String recipient, String body) {
        System.out.println("[SMTP] -> " + recipient + " | " + oneLine(body));
    }
    public int retryDelaySeconds() { return 60; }
}
