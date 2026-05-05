# ─── Stage 1: Build ───────────────────────────────────────────────────────────
FROM maven:3.9.5-eclipse-temurin-17 AS builder

WORKDIR /app

# Cache dependencies layer separately (only re-downloads when pom.xml changes)
COPY pom.xml .
RUN mvn dependency:go-offline -q

# Copy source and build
COPY src ./src
RUN mvn clean package -DskipTests -q

# ─── Stage 2: Runtime (distroless — no shell, no package manager) ─────────────
FROM gcr.io/distroless/java17-debian12:nonroot

WORKDIR /app

# Copy only the fat JAR
COPY --from=builder /app/target/order-service-*.jar app.jar

# Expose app + actuator port
EXPOSE 8080

# Non-root user (distroless nonroot image defaults to uid 65532)
USER nonroot

ENTRYPOINT ["java", \
  "-XX:+UseContainerSupport", \
  "-XX:MaxRAMPercentage=75.0", \
  "-XX:+ExitOnOutOfMemoryError", \
  "-Djava.security.egd=file:/dev/./urandom", \
  "-jar", "app.jar"]
