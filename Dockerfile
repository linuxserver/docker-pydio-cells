FROM lsiobase/alpine:3.11 as buildstage

ARG BUILD_DATE
ARG VERSION
ARG CELLS_RELEASE

ENV GOPATH="/tmp"

RUN \
 echo "**** install build packages ****" && \
 apk add --no-cache --virtual=build-dependencies \
	curl \
	g++ \
	gcc \
	git \
	go \
	grep \
	tar && \
 echo "**** fetch source code ****" && \
 mkdir -p \
	/tmp/src/github.com/pydio/cells && \
 if [ -z ${CELLS_RELEASE+x} ]; then \
	CELLS_RELEASE=$(curl -sX GET "https://api.github.com/repos/pydio/cells/releases/latest" \
	| awk '/tag_name/{print $4;exit}' FS='[""]'); \
 fi && \
 curl -o \
	/tmp/cells-src.tar.gz -L \
	https://github.com/pydio/cells/archive/${CELLS_RELEASE}.tar.gz && \
 tar xf \
	/tmp/cells-src.tar.gz -C \
	/tmp/src/github.com/pydio/cells --strip-components=1 && \
 echo "**** compile cells  ****" && \
 go get -u github.com/pydio/packr/packr && \
 cd /tmp/src/github.com/pydio/cells && \
 find . -name *-packr.go | xargs rm -f && \
 grep -ri --exclude-dir=vendor/* --exclude-dir=frontend/front-srv/assets/* -l "packr.NewBox" */* | \
	while read -r line; do \
		if ! [ "$$line" = "vendor/github.com/ory/x/dbal/migrate.go" ]; then \
			cd `dirname "$$line"`; \
			echo "Run packr for $$line"; \
			${GOPATH}/bin/packr --compress --input=. ; \
			cd -; \
		fi; \
	done && \
 go build -a \
	-ldflags "-X github.com/pydio/cells/common.version=${CELLS_RELEASE:1} \
	-X github.com/pydio/cells/common.BuildStamp=${BUILD_DATE} \
	-X github.com/pydio/cells/common.BuildRevision=${VERSION} \
	-X github.com/pydio/cells/vendor/github.com/pydio/minio-srv/cmd.Version=${VERSION} \
	-X github.com/pydio/cells/vendor/github.com/pydio/minio-srv/cmd.ReleaseTag=${VERSION}" \
	-o /app/cells .

############## runtime stage ##############
FROM lsiobase/alpine:3.11

ARG BUILD_DATE
ARG VERSION
LABEL build_version="Linuxserver.io version:- ${VERSION} Build-date:- ${BUILD_DATE}"
LABEL maintainer="aptalca"

ENV HOME="/config" CELLS_WORKING_DIR="/config"

RUN \
 echo "**** install runtime packages ****" && \
 apk add --no-cache \
	curl \
	jq \
	openssl

COPY --from=buildstage /app/cells /app/cells

COPY root/ /