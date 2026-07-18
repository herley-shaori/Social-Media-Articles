/**
 * v1 — WITHOUT polymorphism.
 *
 * A notification is a dumb data holder. Its behaviour lives elsewhere, keyed
 * off the {@code channel} field by switch statements scattered across
 * {@link NotificationService}. This is the shape that polymorphism exists to
 * replace.
 */
public class Notification {

    public enum Channel { EMAIL, SMS, PUSH, WHATSAPP }

    public final Channel channel;
    public final String recipient;
    public final String message;

    public Notification(Channel channel, String recipient, String message) {
        this.channel = channel;
        this.recipient = recipient;
        this.message = message;
    }
}
