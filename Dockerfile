FROM perl:5.34

ARG USERID
ARG GROUPID

ENV UID=$USERID
ENV GID=$GROUPID

RUN groupadd -g ${GID} spider && useradd -ms /bin/bash -u ${UID} -g ${GID} sysop

RUN curl -L https://cpanmin.us | perl - App::cpanminus
RUN cpanm EV Mojolicious JSON Curses Net::CIDR::Lite Date::Parse JSON::XS Data::Structure::Util Math::Round --force

RUN mkdir /spider

WORKDIR /spider

USER sysop

CMD [ "perl", "-w", "/spider/perl/cluster.pl" ]
