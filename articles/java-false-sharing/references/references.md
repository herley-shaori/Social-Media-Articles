# References

[1] U. Drepper. "What Every Programmer Should Know About Memory," 2007. https://people.freebsd.org/~lstewart/articles/cpumemory.pdf

[2] OpenJDK. `java.util.concurrent.atomic.LongAdder` / `Striped64` source (the `@Contended` cells). https://github.com/openjdk/jdk/blob/master/src/java.base/share/classes/java/util/concurrent/atomic/Striped64.java

[3] OpenJDK JMH. Sample 22 — False Sharing. https://github.com/openjdk/jmh/blob/master/jmh-samples/src/main/java/org/openjdk/jmh/samples/JMHSample_22_FalseSharing.java

[4] OpenJDK. `jdk.internal.vm.annotation.Contended` and `-XX:ContendedPaddingWidth`. https://openjdk.org/

[5] M. Thompson. "False Sharing," Mechanical Sympathy. https://mechanical-sympathy.blogspot.com/2011/07/false-sharing.html
