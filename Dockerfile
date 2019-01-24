#FROM golang:1.8
#ADD . /go/src/github.com/previousnext/k8s-aws-efs
#WORKDIR /go/src/github.com/previousnext/k8s-aws-efs
#RUN go get github.com/mitchellh/gox
#RUN make build
#
#FROM alpine:latest
#RUN apk --no-cache add ca-certificates
#COPY --from=0 /go/src/github.com/previousnext/k8s-aws-efs/bin/k8s-aws-efs_linux_amd64 /usr/local/bin/k8s-aws-efs
#CMD ["k8s-aws-efs"]


###########################
# Build acl register
FROM golang:1.11.2

ENV PATH /go/bin:/usr/local/go/bin:$PATH
ENV GOPATH /go
ENV GO111MODULE=off

COPY . /go/src/github.com/CreditSenseAU/k8s-aws-efs

WORKDIR /go/src/github.com/CreditSenseAU/k8s-aws-efs

RUN set -x \
	&& make staticvendor \
	&& echo "Build complete."

###########################
# Create image
FROM alpine:3.8

RUN apk update && apk add ca-certificates
RUN adduser -D k8s-aws-efs

USER k8s-aws-efs

COPY --from=0 /go/src/github.com/CreditSenseAU/k8s-aws-efs/bin/k8s-aws-efs /usr/local/bin/k8s-aws-efs

CMD ["k8s-aws-efs"]