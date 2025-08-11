# build stage
FROM maven:3.9.6-eclipse-temurin-17 AS build
WORKDIR /workspace
COPY pom.xml ./
# cache dependencies
RUN mvn -B -DskipTests dependency:go-offline
COPY . .
RUN mvn -B clean package -DskipTests -Pprod

# runtime stage
FROM eclipse-temurin:17-jre
# create non-root user
RUN addgroup --system appgroup && adduser --system --ingroup appgroup appuser
WORKDIR /app
# copy jar from build (exact name is safer if known)
COPY --from=build /workspace/target/birthday-tekken-api-*.jar app.jar

EXPOSE 8080

ENV JAVA_OPTS="-Xms256m -Xmx512m -Djava.security.egd=file:/dev/./urandom"

USER appuser

ENTRYPOINT ["sh","-c","exec java $JAVA_OPTS -jar /app/app.jar"]

