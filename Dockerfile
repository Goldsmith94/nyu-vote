FROM lingz/meteor

MAINTAINER lingliangz@gmail.com

ADD . /srv/nyu-vote

EXPOSE 3000

CMD /srv/nyu-vote/run.sh