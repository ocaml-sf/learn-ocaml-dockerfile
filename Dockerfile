FROM ocamlsf/learn-ocaml:0.12

USER root
RUN apk add dumb-init py3-pip zip unzip \
            python3-dev gcc musl-dev linux-headers \
 && pip3 install --upgrade pip python-keystoneclient python-swiftclient \
 && apk del python3-dev gcc musl-dev linux-headers

ADD --chown=learn-ocaml:learn-ocaml program.sh /home/learn-ocaml/
RUN chmod u+x /home/learn-ocaml/program.sh

USER learn-ocaml
ENTRYPOINT ["dumb-init", "./program.sh"]
