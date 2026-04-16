FROM amazonlinux:2023

# Set up working directories
RUN mkdir -p /opt/app
RUN mkdir -p /opt/app/build
RUN mkdir -p /opt/app/bin/

# Copy in the lambda source
WORKDIR /opt/app
COPY ./*.py /opt/app/
COPY requirements.txt /opt/app/requirements.txt

# Install packages
RUN dnf update -y && \
    dnf install -y cpio dnf-utils tar gzip zip python3-pip shadow-utils && \
    pip3 install -r requirements.txt && \
    rm -rf /root/.cache/pip

# Download libraries we need to run in lambda
WORKDIR /tmp

RUN yumdownloader -x \*i686 --archlist=x86_64,aarch64,noarch \
        clamav1.4 clamav1.4-lib clamav1.4-freshclam clamav1.4-filesystem clamav1.4-data

RUN rpm2cpio clamav1.4-1*.rpm | cpio -vimd && \
    rpm2cpio clamav1.4-lib*.rpm | cpio -vimd && \
    rpm2cpio clamav1.4-freshclam*.rpm | cpio -vimd && \
    rpm2cpio clamav1.4-data*.rpm | cpio -vimd && \
    rpm2cpio clamav1.4-filesystem*.rpm | cpio -vimd

# Copy over the binaries and libraries
RUN cp -rf /tmp/usr/bin/clamscan \
       /tmp/usr/bin/freshclam \
       /tmp/usr/lib64/* \
       /opt/app/bin/

# Fix the freshclam.conf settings
RUN echo "DatabaseMirror database.clamav.net" > /opt/app/bin/freshclam.conf && \
    echo "CompressLocalDatabase yes" >> /opt/app/bin/freshclam.conf && \
    echo "ScriptedUpdates no" >> /opt/app/bin/freshclam.conf && \
    echo "DatabaseDirectory /var/lib/clamav" >> /opt/app/bin/freshclam.conf

RUN groupadd clamav
RUN useradd -g clamav -s /bin/false -c "Clam Antivirus" clamav
RUN useradd -g clamav -s /bin/false -c "Clam Antivirus" clamupdate

ENV LD_LIBRARY_PATH=/opt/app/bin
RUN ldconfig

# Create the zip file
WORKDIR /opt/app
RUN zip -r9 --exclude="*test*" /opt/app/build/anti-virus.zip *.py bin

WORKDIR /usr/local/lib/python3.9/site-packages
RUN zip -r9 /opt/app/build/anti-virus.zip *

WORKDIR /opt/app
