# Why Polymorphism Exists: Killing the Type Switch — Code

> **Published:** the full article has been published on LinkedIn / Medium.
> This repository holds only the runnable code the article references.

A minimal, runnable Java demonstration of *why* polymorphism exists: it removes
the repeated `switch (type)` that scatters one decision across many methods and
lets a missing case ship as a silent runtime bug.

The domain is a multi-channel notification sender (Email / SMS / Push, then a
new WhatsApp channel).

## Layout

| Path | What it shows |
|------|----------------|
| `v1-without-polymorphism/` | `NotificationService` with **four** `switch(channel)` blocks. Adding WhatsApp updated three of them; `validate()` was missed. It still compiles, and an invalid WhatsApp recipient is sent anyway. |
| `v2-with-polymorphism/` | An abstract `Channel` with subclasses that each own their behaviour. Adding `WhatsAppChannel` is one new file; because `validate()` is abstract, forgetting it is a **compile error**. |
| `run.sh` | Compiles and runs both versions, the sanity test, and a demo proving the incomplete v2 channel will not compile. |
| `output.txt` | Captured output of `run.sh` (also rendered to `images/run-output.png`). |

## Running

```sh
./run.sh
```

Requires a JDK (tested on OpenJDK 25). No build tool needed.

## The one line that matters

In `v1-without-polymorphism/NotificationService.java`, `validate()` has no
`case WHATSAPP:` — execution falls to `default: return true`, so a WhatsApp
message with a non-phone recipient passes validation and is delivered. The
polymorphic version in `v2-with-polymorphism/` makes that mistake impossible:
`Channel.validate(...)` is abstract, so every channel must implement it.
