/**
 * v2 — WITH polymorphism.
 *
 * Each channel becomes a subclass that owns ALL of its behaviour: validation,
 * formatting, sending, and retry policy. The four abstract methods are the key
 * to the whole design — the compiler refuses to build a Channel subclass that
 * does not implement every one of them. The "forgot to add a case" bug from v1
 * is now impossible to write.
 *
 * deliver() is a template method: the delivery FLOW is identical for every
 * channel, while each STEP is dispatched dynamically to the concrete subclass.
 */
public abstract class Channel {

    public abstract String name();
    public abstract boolean validate(String recipient);
    public abstract String format(String message);
    public abstract void send(String recipient, String body);
    public abstract int retryDelaySeconds();

    /** Same flow for every channel; each step is a polymorphic call. */
    public final void deliver(String recipient, String message) {
        if (!validate(recipient)) {
            System.out.println("REJECT " + name() + " -> " + recipient + " (failed validation)");
            return;
        }
        send(recipient, format(message));
    }

    protected static String oneLine(String s) { return s.replace("\n", " "); }
}
