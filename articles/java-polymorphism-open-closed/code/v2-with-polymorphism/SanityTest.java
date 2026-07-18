/**
 * Sanity checks. Run with assertions enabled:  java -ea SanityTest
 *
 * The decisive assertion is the WhatsApp one: it is exactly the case v1 got
 * wrong. Here it passes, because validate() is a required method on every
 * channel, not an optional switch branch.
 */
public class SanityTest {
    public static void main(String[] args) {
        assert new EmailChannel().validate("a@b.com")        : "valid email rejected";
        assert !new EmailChannel().validate("no-at-sign")    : "invalid email accepted";
        assert new SmsChannel().validate("+6281234567")      : "valid phone rejected";
        assert !new SmsChannel().validate("not-a-number")    : "invalid phone accepted";
        assert new WhatsAppChannel().validate("+6281234567") : "valid WhatsApp rejected";
        assert !new WhatsAppChannel().validate("hello world"): "invalid WhatsApp accepted (the v1 bug)";
        assert new PushChannel().validate("token")           : "valid push rejected";

        System.out.println("all sanity checks passed");
    }
}
