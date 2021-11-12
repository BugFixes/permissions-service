# Build
FROM golang:1.17 AS builder

RUN mkdir -p /home/builder
WORKDIR /home/builder

## Download dependencies
COPY go.mod .
COPY go.sum .
RUN go mod download

## Copy files
COPY . .
ARG build
ARG version

RUN CGO_ENABLED=0 go build -ldflags "-w -s -X github.com/bugfixes/permissions/app.version=$(version) -X github.com/bugfixes/permissions/app.build=$(build)" -o ./bin/permissions -v ./cmd/permissions.go
RUN cp ./bin/permissions /

# Runner
FROM alpine AS Runner
RUN apk update
RUN apk upgrade
RUN apk add ca-certificates && update-ca-certificates
RUN apk add --update tzdata
RUN rm -rf /var/cache/apk/*

COPY --from=builder /permissions /home/

## Set the timezone
ENV TZ=Europe/London

WORKDIR /home

## Set the entrypoint
RUN echo "#!/bin/bash" >> ./entrypoint.sh
RUN echo "./permissions" >> ./entrypoint.sh
RUN chmod +x ./entrypoint.sh
ENTRYPOINT ["sh", "./entrypoint.sh"]

## Healthcheck to keep system alive
HEALTHCHECK --interval=5s --timeout=2s --retries=12 CMD curl --silent --fail localhost/probe || exit 1

## Expose the main ports
EXPOSE 80 3000
