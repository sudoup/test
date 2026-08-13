FROM golang:1.26-alpine3.22 AS build
WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN go build -trimpath -ldflags="-s -w" -o /out/olcrtc ./cmd/olcrtc

FROM alpine:3.22
RUN apk add --no-cache ca-certificates
COPY --from=build /out/olcrtc /usr/local/bin/olcrtc
COPY scripts/railway/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]