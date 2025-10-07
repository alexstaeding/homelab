FROM jetbrains/teamcity-agent:2025.07.2
USER root
RUN apt update && apt install -y openjdk-21-jdk-headless
