FROM bcclaywell/galaxy-base:testing
ENV REFRESHED_AT 2014-07-20

MAINTAINER Brian Claywell <bclaywel@fhcrc.org>

# Set debconf to noninteractive mode.
# https://github.com/phusion/baseimage-docker/issues/58#issuecomment-47995343
RUN echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections

RUN apt-get update -q

ADD startup.sh /startup

# Set debconf back to normal.
RUN echo 'debconf debconf/frontend select Dialog' | debconf-set-selections

CMD ["/startup"]
