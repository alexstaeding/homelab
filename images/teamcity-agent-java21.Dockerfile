FROM jetbrains/teamcity-agent:2024.03.2
USER root
RUN apt update && apt install -y openjdk-21-jdk-headless
