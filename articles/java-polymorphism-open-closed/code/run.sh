#!/usr/bin/env bash
# Compile and run both versions, plus the sanity test, capturing everything
# into output.txt. Requires a JDK (tested on OpenJDK 25). No build tool needed.
set -euo pipefail
cd "$(dirname "$0")"

OUT=output.txt
: > "$OUT"

run() { echo "$@" | tee -a "$OUT"; "$@" 2>&1 | tee -a "$OUT"; echo | tee -a "$OUT"; }

echo "### Compiling ..." | tee -a "$OUT"
rm -rf build && mkdir -p build/v1 build/v2
javac -d build/v1 v1-without-polymorphism/*.java
javac -d build/v2 v2-with-polymorphism/*.java
echo "compiled OK (both versions build — the v1 bug is NOT a compile error)" | tee -a "$OUT"
echo | tee -a "$OUT"

echo "### v1 — without polymorphism (watch the WHATSAPP line)" | tee -a "$OUT"
( cd build/v1 && java Main ) | tee -a "$OUT"
echo | tee -a "$OUT"

echo "### v2 — with polymorphism (same input, WhatsApp now rejected)" | tee -a "$OUT"
( cd build/v2 && java Main ) | tee -a "$OUT"
echo | tee -a "$OUT"

echo "### sanity test (assertions enabled)" | tee -a "$OUT"
( cd build/v2 && java -ea SanityTest ) | tee -a "$OUT"
echo | tee -a "$OUT"

echo "### compiler enforcement: a v2 channel that forgets validate() will NOT compile" | tee -a "$OUT"
cat > build/BrokenChannel.java <<'JAVA'
// Deliberately incomplete: extends Channel but omits validate().
// In v1 the equivalent mistake compiled fine. In v2 it cannot.
public class BrokenChannel extends Channel {
    public String name() { return "BROKEN"; }
    public String format(String message) { return message; }
    public void send(String recipient, String body) { System.out.println(body); }
    public int retryDelaySeconds() { return 5; }
    // no validate(...) on purpose
}
JAVA
if javac -cp build/v2 -d build build/BrokenChannel.java 2> build/err.txt; then
  echo "UNEXPECTED: it compiled" | tee -a "$OUT"
else
  echo "javac rejected it (as intended):" | tee -a "$OUT"
  grep -E "abstract|validate" build/err.txt | head -2 | tee -a "$OUT"
fi

rm -rf build
echo | tee -a "$OUT"
echo "done." | tee -a "$OUT"
