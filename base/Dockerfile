FROM debian:jessie
ENV REFRESHED_AT 2014-07-05

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

RUN useradd -m -d /galaxy -p galaxy galaxy  # TODO actually use this

WORKDIR /galaxy

# Fetch the latest source tarball from galaxy-central's stable branch.
RUN apt-get install -y -q --no-install-recommends wget
RUN mkdir stable && \
    wget -qO- https://bitbucket.org/galaxy/galaxy-central/get/stable.tar.gz | \
    tar xvz --strip-components=1 -C stable

# Fire up a virtualenv to isolate Galaxy from system python.
RUN apt-get install -y -q python-pip
RUN pip install virtualenv
RUN virtualenv --no-site-packages galaxy-env && \
    . galaxy-env/bin/activate

WORKDIR /galaxy/stable

# No-nonsense configuration! But strip the comments first, for images
# using us as a base.
RUN egrep -v '^(#.*)?$' universe_wsgi.ini.sample > universe_wsgi.ini

# Fetch dependencies.
RUN python scripts/fetch_eggs.py

# Install and configure nginx to proxy requests.
RUN apt-get install -y -q --no-install-recommends nginx
ADD nginx.conf /etc/nginx/nginx.conf

# Uncomment this line if nginx shouldn't fork into the background
# (i.e. if startup.sh changes).
#RUN sed -i '1idaemon off;' /etc/nginx/nginx.conf

# Set debconf back to normal.
RUN echo 'debconf debconf/frontend select Dialog' | debconf-set-selections

ADD startup.sh /startup

EXPOSE 80

# Expose Galaxy's database directory.
VOLUME ["/galaxy/stable/database"]

CMD ["/startup"]
