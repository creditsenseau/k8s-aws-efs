# Setup name variables for the package/tool
NAME := k8s-aws-efs
PKG := github.com/CreditSenseAU/$(NAME)

CGO_ENABLED := 0

# Set any default go build tags.
BUILDTAGS :=

include basic.mk

.PHONY: prebuild
prebuild: