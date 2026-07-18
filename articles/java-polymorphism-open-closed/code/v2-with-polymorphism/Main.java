import java.util.List;

/**
 * v2 — WITH polymorphism.
 *
 * Exactly the same batch as v1. This time the WHATSAPP message with recipient
 * "hello world" is correctly REJECTED, because WhatsAppChannel.validate() is a
 * real method the compiler required — not a switch case anyone could forget.
 */
public class Main {
    public static void main(String[] args) {
        var service = new NotificationService();
        var batch = List.of(
            new NotificationService.Outbound(new EmailChannel(),    "alice@example.com", "Your invoice is ready"),
            new NotificationService.Outbound(new SmsChannel(),      "not-a-number",      "Your OTP is 123456"),
            new NotificationService.Outbound(new PushChannel(),     "device-token-abc",  "You have 3 new likes"),
            new NotificationService.Outbound(new WhatsAppChannel(), "hello world",       "Your order shipped")
        );

        System.out.println("== v2: polymorphic dispatch ==");
        service.process(batch);
    }
}
