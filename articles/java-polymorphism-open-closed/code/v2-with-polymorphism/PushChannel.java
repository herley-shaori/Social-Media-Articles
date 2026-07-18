public class PushChannel extends Channel {
    public String name() { return "PUSH"; }
    public boolean validate(String recipient) { return !recipient.isBlank(); }
    public String format(String message) {
        return "{\"title\":\"Notification\",\"body\":\"" + message + "\"}";
    }
    public void send(String recipient, String body) {
        System.out.println("[PUSH] -> " + recipient + " | " + oneLine(body));
    }
    public int retryDelaySeconds() { return 10; }
}
