FROM jetbrains/teamcity-agent:2025.11.7
USER root
RUN apt update && apt install -y openjdk-21-jdk-headless
