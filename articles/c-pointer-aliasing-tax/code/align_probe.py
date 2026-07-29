#!/usr/bin/env python3
"""Report, for each kernel in a binary, whether its hot loop straddles a
32-byte instruction-fetch boundary.

The loop head is taken to be the target of the backward `jne` that closes the
loop; the loop body is measured from that head to the `jne` itself. A body
that starts and ends inside the same aligned 32-byte window is fetched in one
go; one that crosses the boundary needs two fetches, and on Intel cores that
alone is worth a double-digit percentage on a short loop.

Usage: align_probe.py <binary> [<binary> ...]
Prints `key=value` lines for run.sh to collect.
"""

import re
import subprocess
import sys

FUNC = re.compile(r"^[0-9a-f]+ <(\w+)>:")
JNE = re.compile(r"^\s*([0-9a-f]+):\s+jne\s+([0-9a-f]+)")


def probe(binary):
    out = subprocess.run(
        ["objdump", "-d", "--no-show-raw-insn", binary],
        capture_output=True, text=True, check=True,
    ).stdout

    current = None
    seen = set()
    rows = []

    for line in out.splitlines():
        m = FUNC.match(line)
        if m:
            current = m.group(1)
            continue
        m = JNE.match(line)
        if not m or not current or current in seen:
            continue
        jne_addr = int(m.group(1), 16)
        head = int(m.group(2), 16)
        if head >= jne_addr:          # forward jump: not a loop-closing branch
            continue
        seen.add(current)
        # body spans [head, jne_addr]; the jne itself is 2 bytes
        end = jne_addr + 1
        rows.append((current, head, head % 32, (head // 32) != (end // 32)))

    return rows


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    for binary in sys.argv[1:]:
        tag = binary.split("/")[-1]
        for name, head, mod, crosses in probe(binary):
            if not name.startswith(("apply_", "isum_", "dsum_")):
                continue
            print(f"align.{tag}.{name}.head=0x{head:x}")
            print(f"align.{tag}.{name}.mod32={mod}")
            print(f"align.{tag}.{name}.crosses32={int(crosses)}")


if __name__ == "__main__":
    main()
