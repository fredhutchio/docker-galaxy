FROM debian:jessie
ENV REFRESHED_AT 2014-07-20

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
    subversion

# Install additional tools needed for installation.
RUN apt-get install -y -q --no-install-recommends wget

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

# Explicitly set this so it won't look in /.python-eggs.
RUN mkdir .python-eggs
ENV PYTHON_EGG_CACHE /galaxy/.python-eggs

# Set up /galaxy.
RUN mkdir tools

RUN mkdir stable
WORKDIR /galaxy/stable

# Set up /galaxy/stable.
RUN mkdir database static tool-data

# Fetch the latest source tarball from galaxy-central's stable branch.
RUN wget -qO- https://bitbucket.org/galaxy/galaxy-central/get/stable.tar.gz | \
    tar xvpz --strip-components=1

# No-nonsense configuration!
RUN cp universe_wsgi.ini.sample universe_wsgi.ini

# Fetch dependencies.
RUN python scripts/fetch_eggs.py

# Configure toolsheds. See https://wiki.galaxyproject.org/InstallingRepositoriesToGalaxy
# We'll fix ownership of these below, after switching back to root.
ADD shed_tool_conf.xml /galaxy/tools/shed_tool_conf.xml
ADD shed_tool_data_table_conf.xml /galaxy/tools/shed_tool_data_table_conf.xml
RUN mkdir tools/shed_tools tools/tool_deps && \
    touch tools/shed_tools/.keep tools/tool_deps/.keep
RUN sed -i 's|^#\?\(tool_config_file\) = .*$|\1 = tool_conf.xml,../tools/shed_tool_conf.xml|' universe_wsgi.ini && \
    sed -i 's|^#\?\(tool_dependency_dir\) = .*$|\1 = ../tools/tool_deps|' universe_wsgi.ini && \
    sed -i 's|^#\?\(check_migrate_tools\) = .*$|\1 = False|' universe_wsgi.ini

# Ape the basic job_conf.xml.
RUN cp job_conf.xml.sample_basic job_conf.xml

# Switch back to root for the rest of the configuration.
USER root

# Fix ownership of/in /galaxy/tools.
RUN chown -R galaxy:galaxy /galaxy/tools

# Tar up directory skeletons for bootstrapping empty volumes.
RUN tar cvzpf tools_skel.tar.gz ../tools && \
    tar cvzpf database_skel.tar.gz database && \
    tar cvzpf static_skel.tar.gz static && \
    tar cvzpf tool-data_skel.tar.gz tool-data

# Install and configure nginx to proxy requests.
RUN apt-get install -y -q --no-install-recommends nginx-light
ADD nginx.conf /etc/nginx/nginx.conf

# Static content will be handled by nginx, so disable it in Galaxy.
RUN sed -i 's|^#\?\(static_enabled\) = .*$|\1 = False|' universe_wsgi.ini

# Offload downloads and compression to nginx.
RUN sed -i 's|^#\?\(nginx_x_accel_redirect_base\) = .*$|\1 = /_x_accel_redirect|' universe_wsgi.ini && \
    sed -i 's|^#\?\(nginx_x_archive_files_base\) = .*$|\1 = /_x_accel_redirect|' universe_wsgi.ini

# Uncomment this line if nginx shouldn't fork into the background.
# (i.e. if startup.sh changes).
#RUN sed -i '1idaemon off;' /etc/nginx/nginx.conf

# Add in additional dependencies as we come across them.
RUN apt-get install -y -q --no-install-recommends \
    libxml2-dev \
    libz-dev

# Set debconf back to normal.
RUN echo 'debconf debconf/frontend select Dialog' | debconf-set-selections

ADD startup.sh /startup

VOLUME /galaxy/tools
VOLUME /galaxy/stable/database
VOLUME /galaxy/stable/static
VOLUME /galaxy/stable/tool-data

EXPOSE 80

CMD ["/startup"]
