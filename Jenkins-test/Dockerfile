FROM ubuntu:latest
ENV TZ Asia/Singapore
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone
RUN apt-get update
RUN apt-get install curl -y
RUN apt-get install libasound-dev -y
RUN apt-get install portaudio19-dev -y
RUN apt-get install libportaudio2 -y
RUN apt-get install libportaudiocpp0 -y
RUN apt-get install python3.8 python3.8-dev python3-pip -y
RUN python3.8 -m pip install pyaudio==0.2.11
RUN python3.8 -m pip install install ws4py
RUN curl -LO https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl
RUN chmod +x ./kubectl
RUN mv ./kubectl /usr/local/bin