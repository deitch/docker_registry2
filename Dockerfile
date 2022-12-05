# build container
ARG IMG=ruby:3.1.1-alpine
FROM ${IMG} AS build

RUN apk --update add make

WORKDIR /src

COPY Gemfile* ./

COPY . .

RUN make build BUILD=local

# test container
FROM ${IMG} AS test

# need gcc/g++ for one of the rest-client dependencies
RUN apk --update add make gcc g++
WORKDIR /src
COPY --from=build /src /src

ARG registry
ARG cachebuster

RUN BUILD=local TEST_REGISTRY=${registry} ./test.sh testonly

# deploy container
FROM ${IMG} AS deploy

RUN apk --update add make gcc g++
WORKDIR /src
COPY --from=build /src /src

RUN make push BUILD=local
