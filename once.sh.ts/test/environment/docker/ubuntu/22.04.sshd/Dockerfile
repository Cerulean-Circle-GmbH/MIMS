# Use an official Python runtime as a parent image
FROM ubuntu:22.04
# ENV DEBUG ON
# Define environment variable
#ENV NAME DockerWorkspace
#ENV DOCKERWORKSPACE $NAME
#ENV USERNAME freemiumUser
#ENV WORKDIR /home/$USERNAME/$NAME
ENV DEBIAN_FRONTEND noninteractive
ENV WORKDIR /root/
#ENV PATH /usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# Set the working directory to /app
WORKDIR $WORKDIR
#ADD entrypoint/start.sh entrypoint/start.sh
ADD entrypoint entrypoint

# Copy the current directory contents into the container at /app
# COPY . /home/$USERNAME/$NAME
#RUN chmod +x /home/$USERNAME/$NAME/install.eamd.sh 
RUN export PATH=.:$PATH
#RUN bash /home/$USERNAME/$NAME/install.eamd.sh .

# Make port 80 available to the world outside this container
#EXPOSE 80


RUN apt update && apt install  net-tools wget openssh-server sudo -y
RUN useradd -rm -d /home/ubuntu -s /bin/bash -g root -G sudo -u 1000 test 
RUN  echo 'test:test' | chpasswd
RUN service ssh start

# generate server keys
RUN ssh-keygen -A
#RUN ssh-keygen -t dsa -N "my passphrase" -C "test key" -f mykey
RUN ssh-keygen -t rsa -q -f "$HOME/.ssh/id_rsa" -N ""

# allow root to login
RUN sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/g' /etc/ssh/sshd_config
RUN sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/g' /etc/ssh/sshd_config


# Run app.py when the container launches
#CMD ["python", "app.py"]
EXPOSE 22
ENTRYPOINT ["entrypoint/start.sh"]
#CMD ["/usr/bin/sudo", "/usr/sbin/sshd", "-D", "-o", "ListenAddress=0.0.0.0"]
