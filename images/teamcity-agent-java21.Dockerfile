FROM jetbrains/teamcity-agent:2024.12.3
USER root
RUN apt update && apt install -y openjdk-21-jdk-headless
