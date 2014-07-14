FROM debian:jessie
ENV REFRESHED_AT 2014-07-11

MAINTAINER Brian Claywell <bclaywel@fhcrc.org>

# Set debconf to noninteractive mode.
# https://github.com/phusion/baseimage-docker/issues/58#issuecomment-47995343
RUN echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections

RUN apt-get update -q

# Install all requirements that are recommended by the Galaxy project.
# (Keep an eye on them at https://wiki.galaxyproject.org/Admin/Config/ToolDependenciesList)
RUN apt-get install -y -q --no-install-recommends \
    autoconf \
    automake \
    build-essential \
    cmake \
    gfortran \
    git-core \
    libatlas-base-dev \
    libblas-dev \
    liblapack-dev \
    mercurial \
    openjdk-7-jre-headless \
    pkg-config \
    python-dev \
    python-setuptools \
    subversion

# Create an unprivileged user for Galaxy to run as (and its home directory).
RUN useradd -m -d /galaxy -p galaxy galaxy

RUN apt-get install -y -q --no-install-recommends wget
#RUN apt-get install -y -q --no-install-recommends python-pip && \
#    pip install virtualenv

# Do as much as work possible as the unprivileged galaxy user.
WORKDIR /galaxy
USER galaxy

RUN mkdir -p tools stable/database
VOLUME ["/galaxy/tools", "galaxy/stable/database"]

# Fetch the latest source tarball from galaxy-central's stable branch.
RUN wget -qO- https://bitbucket.org/galaxy/galaxy-central/get/stable.tar.gz | \
    tar xvpz --strip-components=1 -C stable

# Create a virtualenv to isolate Galaxy from system python.
#RUN virtualenv /galaxy/galaxy-env

WORKDIR /galaxy/stable

# No-nonsense configuration!
RUN cp universe_wsgi.ini.sample universe_wsgi.ini

# Fetch dependencies.
RUN python scripts/fetch_eggs.py

# Configure toolsheds. See https://wiki.galaxyproject.org/InstallingRepositoriesToGalaxy
RUN sed    's|\.\./shed_tools|../tools/shed_tools|' shed_tool_conf.xml.sample > shed_tool_conf.xml && \
    sed -i 's|^#\?tool_dependency_dir .*$|tool_dependency_dir = ../tools/tool_deps|' universe_wsgi.ini

# Ape the basic job_conf.xml.
RUN cp job_conf.xml.sample_basic job_conf.xml

# Explicitly set this so it won't look in /.python-eggs.
RUN mkdir /galaxy/.python-eggs
ENV PYTHON_EGG_CACHE /galaxy/.python-eggs

# Switch back to root for the rest of the configuration.
USER root

# Install and configure nginx to proxy requests.
RUN apt-get install -y -q --no-install-recommends nginx-light
ADD nginx.conf /etc/nginx/nginx.conf

# Offload uploads to nginx.
#RUN mkdir /galaxy/upload_store && \
#    chown galaxy:www-data /galaxy/upload_store && \
#    chmod 770 /galaxy/upload_store && \
#    sed -i 's|^#\?nginx_upload_store .*$|nginx_upload_store = /galaxy/upload_store|' universe_wsgi.ini && \
#    sed -i 's|^#\?nginx_upload_path .*$|nginx_upload_path = /_upload|' universe_wsgi.ini

# Offload downloads and compression to nginx.
RUN sed -i 's|^#\?nginx_x_accel_redirect_base .*$|nginx_x_accel_redirect_base = /_x_accel_redirect|' universe_wsgi.ini && \
    sed -i 's|^#\?nginx_x_archive_files_base .*$|nginx_x_archive_files_base = /_x_accel_redirect|' universe_wsgi.ini

# Uncomment this line if nginx shouldn't fork into the background.
# (i.e. if startup.sh changes).
#RUN sed -i '1idaemon off;' /etc/nginx/nginx.conf

# Add missing dependencies.
RUN apt-get install -y -q --no-install-recommends libz-dev

# Set debconf back to normal.
RUN echo 'debconf debconf/frontend select Dialog' | debconf-set-selections

ADD startup.sh /startup

EXPOSE 80

CMD ["/startup"]
