FROM dart:stable AS build

WORKDIR /app
COPY server/pubspec.yaml server/pubspec.lock ./
RUN dart pub get

COPY server/bin ./bin
COPY server/lib ./lib
RUN dart compile exe bin/server.dart -o bin/scenora-server

FROM debian:bookworm-slim
RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY --from=build /app/bin/scenora-server /app/scenora-server

ENV PORT=10000
EXPOSE 10000
CMD ["/app/scenora-server"]
