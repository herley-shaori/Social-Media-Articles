import java.util.List;

/**
 * v1 — WITHOUT polymorphism.
 *
 * Every per-channel decision is a switch on {@code n.channel}. There are FOUR
 * of them below: validate, format, send, and retryDelaySeconds. Adding a new
 * channel means finding and editing every one of them. Nothing forces you to.
 *
 * That is exactly the trap this version demonstrates: when WHATSAPP was added,
 * three of the four switches were updated and one — validate() — was not.
 * The code still compiles, and the miss only shows up at runtime as a bad
 * message going out instead of being rejected.
 */
public class NotificationService {

    // Switch #1 of 4 — validation rules per channel.
    boolean validate(Notification n) {
        switch (n.channel) {
            case EMAIL: return n.recipient.contains("@");
            case SMS:   return n.recipient.matches("\\+?\\d{8,15}");
            case PUSH:  return !n.recipient.isBlank();
            // >>> THE BUG <<<
            // WHATSAPP was added to the enum and to the other three switches,
            // but no case was added here. Execution falls to `default`, so a
            // WhatsApp notification is treated as always-valid — even when the
            // recipient is not a phone number at all.
            default:    return true;
        }
    }

    // Switch #2 of 4 — channel-specific formatting. (WHATSAPP was remembered here.)
    String format(Notification n) {
        switch (n.channel) {
            case EMAIL:    return "Subject: Notification\n\n" + n.message;
            case SMS:      return n.message.length() > 160 ? n.message.substring(0, 160) : n.message;
            case PUSH:     return "{\"title\":\"Notification\",\"body\":\"" + n.message + "\"}";
            case WHATSAPP: return "*Notification*\n" + n.message;
            default:       return n.message;
        }
    }

    // Switch #3 of 4 — how to send. (WHATSAPP was remembered here.)
    void send(Notification n, String body) {
        switch (n.channel) {
            case EMAIL:    System.out.println("[SMTP] -> " + n.recipient + " | " + oneLine(body)); break;
            case SMS:      System.out.println("[SMS]  -> " + n.recipient + " | " + oneLine(body)); break;
            case PUSH:     System.out.println("[PUSH] -> " + n.recipient + " | " + oneLine(body)); break;
            case WHATSAPP: System.out.println("[WA]   -> " + n.recipient + " | " + oneLine(body)); break;
            default:       throw new IllegalStateException("unknown channel: " + n.channel);
        }
    }

    // Switch #4 of 4 — retry backoff. (WHATSAPP was remembered here too.)
    int retryDelaySeconds(Notification n) {
        switch (n.channel) {
            case EMAIL:    return 60;
            case SMS:      return 30;
            case PUSH:     return 10;
            case WHATSAPP: return 20;
            default:       return 0;
        }
    }

    void process(List<Notification> batch) {
        for (Notification n : batch) {
            if (!validate(n)) {
                System.out.println("REJECT " + n.channel + " -> " + n.recipient + " (failed validation)");
                continue;
            }
            send(n, format(n));
        }
    }

    private static String oneLine(String s) { return s.replace("\n", " "); }
}
