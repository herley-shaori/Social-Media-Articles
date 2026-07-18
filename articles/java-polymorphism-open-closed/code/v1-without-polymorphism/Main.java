import java.util.List;

/**
 * v1 — WITHOUT polymorphism.
 *
 * The same batch is used by both versions. Watch the WHATSAPP line: its
 * recipient ("hello world") is not a phone number, so it SHOULD be rejected —
 * but v1's validate() has no WHATSAPP case, so it is sent anyway.
 */
public class Main {
    public static void main(String[] args) {
        var service = new NotificationService();
        var batch = List.of(
            new Notification(Notification.Channel.EMAIL,    "alice@example.com", "Your invoice is ready"),
            new Notification(Notification.Channel.SMS,      "not-a-number",      "Your OTP is 123456"),
            new Notification(Notification.Channel.PUSH,     "device-token-abc",  "You have 3 new likes"),
            new Notification(Notification.Channel.WHATSAPP, "hello world",       "Your order shipped")
        );

        System.out.println("== v1: switch-on-type ==");
        service.process(batch);
    }
}
