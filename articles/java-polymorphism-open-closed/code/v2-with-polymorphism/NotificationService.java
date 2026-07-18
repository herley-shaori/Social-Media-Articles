import java.util.List;

/**
 * v2 — WITH polymorphism.
 *
 * Notice what is NOT here: no switch, no enum, no per-channel branching. The
 * service does not know or care how many channels exist. It just calls
 * deliver() and lets dynamic dispatch route each step to the right subclass.
 * A new channel never touches this file.
 */
public class NotificationService {

    /** An outbound message paired with the channel that will carry it. */
    public record Outbound(Channel channel, String recipient, String message) {}

    public void process(List<Outbound> batch) {
        for (Outbound o : batch) {
            o.channel().deliver(o.recipient(), o.message());
        }
    }
}
