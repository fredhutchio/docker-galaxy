FROM ubuntu:14.04
ENV REFRESHED_AT 2014-11-04

MAINTAINER Brian Claywell <bclaywel@fhcrc.org>

# Set debconf to noninteractive mode.
# https://github.com/phusion/baseimage-docker/issues/58#issuecomment-47995343
RUN echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections

# Install all requirements that are recommended by the Galaxy project.
# (Keep an eye on them at https://wiki.galaxyproject.org/Admin/Config/ToolDependenciesList)
RUN apt-get update -q && \
    apt-get install -y -q --no-install-recommends \
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
    subversion \
    wget \
    nginx-light \
    libxml2-dev \
    libz-dev \
    openssh-client && \
    apt-get clean -q

# Create an unprivileged user for Galaxy to run as (and its home
# directory). From man 8 useradd, "System users will be created with
# no aging information in /etc/shadow, and their numeric identifiers
# are chosen in the SYS_UID_MIN-SYS_UID_MAX range, defined in
# /etc/login.defs, instead of UID_MIN-UID_MAX (and their GID
# counterparts for the creation of groups)."
RUN useradd --system -m -d /galaxy -p galaxy galaxy

# Do as much as work possible as the unprivileged galaxy user.
WORKDIR /galaxy
USER galaxy
ENV HOME /galaxy

# Set up /galaxy.
RUN mkdir shed_tools tool_deps

RUN mkdir stable
WORKDIR /galaxy/stable

# Set up /galaxy/stable.
RUN mkdir database static tool-data

# Fetch the latest source tarball from galaxy-central's stable branch.
RUN wget -qO- https://bitbucket.org/galaxy/galaxy-central/get/stable.tar.gz | \
    tar xvpz --strip-components=1 --exclude test-data

# No-nonsense configuration!
RUN cp -a config/galaxy.ini.sample config/galaxy.ini

# Fetch dependencies.
RUN python scripts/fetch_eggs.py

# Configure toolsheds. See https://wiki.galaxyproject.org/InstallingRepositoriesToGalaxy
RUN cp -a config/shed_tool_conf.xml.sample shed_tool_conf.xml
RUN sed -i 's|^#\?\(tool_config_file\) = .*$|\1 = config/tool_conf.xml,shed_tool_conf.xml|' config/galaxy.ini && \
    sed -i 's|^#\?\(tool_dependency_dir\) = .*$|\1 = ../tool_deps|' config/galaxy.ini && \
    sed -i 's|^#\?\(check_migrate_tools\) = .*$|\1 = False|' config/galaxy.ini

# Ape the basic job_conf.xml.
RUN cp -a config/job_conf.xml.sample_basic config/job_conf.xml

# Configure nginx to proxy requests.
COPY nginx.conf /etc/nginx/nginx.conf

# Static content will be handled by nginx, so disable it in Galaxy.
RUN sed -i 's|^#\?\(static_enabled\) = .*$|\1 = False|' config/galaxy.ini

# Offload downloads and compression to nginx.
RUN sed -i 's|^#\?\(nginx_x_accel_redirect_base\) = .*$|\1 = /_x_accel_redirect|' config/galaxy.ini && \
    sed -i 's|^#\?\(nginx_x_archive_files_base\) = .*$|\1 = /_x_accel_redirect|' config/galaxy.ini

# Install galaxy-rstudio visualization app.
RUN git clone https://github.com/fhcrcio/galaxy-rstudio.git config/plugins/visualizations/rstudio

# Switch back to root for the rest of the configuration.
USER root

# Uncomment this line if nginx shouldn't fork into the background.
# (i.e. if startup.sh changes).
#RUN sed -i '1idaemon off;' /etc/nginx/nginx.conf

RUN apt-get install -y -q --no-install-recommends \
    net-tools

# Set debconf back to normal.
RUN echo 'debconf debconf/frontend select Dialog' | debconf-set-selections

# Add entrypoint script.
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint
COPY docker-link-exports.sh /usr/local/bin/docker-link-exports

# Add startup scripts.
COPY startup.sh /usr/local/bin/startup
RUN chmod +x /usr/local/bin/startup

# Add private data for the runtime scripts to configure/use.
# This should only be uncommented for custom builds.
#ADD private /root/private

EXPOSE 80

# Set the entrypoint, which performs some common configuration steps
# before yielding to CMD.
ENTRYPOINT ["/usr/local/bin/docker-entrypoint"]

# Start the basic server by default.
CMD ["/usr/local/bin/startup"]
