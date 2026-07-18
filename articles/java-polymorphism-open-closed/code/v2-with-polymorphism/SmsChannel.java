public class SmsChannel extends Channel {
    public String name() { return "SMS"; }
    public boolean validate(String recipient) { return recipient.matches("\\+?\\d{8,15}"); }
    public String format(String message) {
        return message.length() > 160 ? message.substring(0, 160) : message;
    }
    public void send(String recipient, String body) {
        System.out.println("[SMS]  -> " + recipient + " | " + oneLine(body));
    }
    public int retryDelaySeconds() { return 30; }
}
