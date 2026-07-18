/**
 * Adding WhatsApp in v2 is THIS ONE FILE. No existing file changes.
 *
 * Because Channel declares validate() abstract, the compiler forces this class
 * to provide it — the v1 bug (forgetting the WHATSAPP validation case) simply
 * cannot happen here. This is the Open/Closed principle in practice: open for
 * extension (add a subclass), closed for modification (touch nothing else).
 */
public class WhatsAppChannel extends Channel {
    public String name() { return "WHATSAPP"; }
    public boolean validate(String recipient) { return recipient.matches("\\+?\\d{8,15}"); }
    public String format(String message) { return "*Notification*\n" + message; }
    public void send(String recipient, String body) {
        System.out.println("[WA]   -> " + recipient + " | " + oneLine(body));
    }
    public int retryDelaySeconds() { return 20; }
}
