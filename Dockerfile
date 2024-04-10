FROM golang:1.21 as op

WORKDIR /app

#ENV REPO=https://github.com/ethereum-optimism/optimism.git
ENV REPO=https://github.com/tothemoon999/optimism.git
ENV VERSION=v1.7.1
# for verification:
ENV COMMIT=c87a469d7d679e8a4efbace56c3646b925bcc009

#RUN git clone $REPO --branch op-node/$VERSION --single-branch . && \
#    git switch -c branch-$VERSION && \
#    bash -c '[ "$(git rev-parse HEAD)" = "$COMMIT" ]'
ARG CACHEBUST=6
RUN git clone $REPO

WORKDIR /app/optimism
RUN git pull $REPO



RUN cd /app/optimism/op-node && \
    make VERSION=$VERSION op-node

FROM golang:1.21 as geth

WORKDIR /app

#ENV REPO=https://github.com/ethereum-optimism/op-geth.git
ENV REPO=https://github.com/tothemoon999/op-geth.git
ENV VERSION=v1.101308.2
# for verification:
ENV COMMIT=0402d543c3d0cff3a3d344c0f4f83809edb44f10

# avoid depth=1, so the geth build can read tags
#RUN git clone $REPO --branch $VERSION --single-branch . && \
#    git switch -c branch-$VERSION && \
#    bash -c '[ "$(git rev-parse HEAD)" = "$COMMIT" ]'
ARG CACHEBUST=6
RUN git clone $REPO
#RUN cd /app/op-geth && \
#    git pull $REPO
# RUN cd /app/op-geth
WORKDIR /app/op-geth
RUN git pull $REPO

RUN go mod download

RUN go run ./build/ci.go install -static ./cmd/geth

FROM golang:1.21

RUN apt-get update && \
    apt-get install -y jq curl supervisor && \
    rm -rf /var/lib/apt/lists
RUN mkdir -p /var/log/supervisor

WORKDIR /app

COPY --from=op /app/optimism/op-node/bin/op-node ./
COPY --from=geth /app/op-geth/build/bin/geth ./
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY geth-entrypoint .
COPY op-node-entrypoint .
COPY sepolia ./sepolia
COPY mainnet ./mainnet

CMD ["/usr/bin/supervisord"]
