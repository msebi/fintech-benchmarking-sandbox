# profile-microservice/Dockerfile
FROM eclipse-temurin:21-jre-alpine
RUN addgroup -S spring && adduser -S spring -G spring
USER spring:spring
ARG JAR_FILE=target/*.jar
COPY ${JAR_FILE} app.jar
ENV JAVA_OPTS="-Xmx256m -Xss1m -XX:MaxMetaspaceSize=128m -XX:+UseG1GC"
ENTRYPOINT ["sh", "-c", "java ${JAVA_OPTS} -jar /app.jar"]


